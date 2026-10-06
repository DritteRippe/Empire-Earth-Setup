[Code]
// The product runner (contract 1.7 points 1 to 7, ADR 0013): at ssInstall the suite runs the setups of the
// products the user selected, EE before NeoEE, each one unchanged and byte for byte as it was built into the
// package. Before anything runs, PrepareToInstall extracts every selected setup once and compares its
// SHA-256 and size with the pins of the build (exit code 15, nothing installed); right before each start the
// runner compares again. The suite record and the suite shortcuts are written afterwards, at ssPostInstall,
// by suite.iss, only from what this runner reports in SuiteProductsOk (spike decision, ADR 0013 Evidence).
// The runner never starts anything but the embedded product setups, never touches the CD key registration
// of NeoEE (the NeoEE setup does it; the runner only reads the number the setup logged), and deletes only
// its own extracted setup, the log of the product setup it is about to write, and the old shortcut files of
// contract 1.7 point 7.
// A product setup is started with CreateProcessW instead of Exec, which gives no process handle (suite 1.1.0, ADR 0013,
// amendment of the runner): the wait loop keeps the window of Setup alive, reads the product log for the phase, honors
// Cancel before the product setup installed anything (and only then), and stops one that shows no sign of life or
// runs far too long. The exit code, the mapping to SuiteChildExitKind and the success rule are those of Exec.
// Requires: suite_common.iss, suite.iss (the pins, SuiteMutexes, SuiteStop and the globals of the products).

var
  // Set when an embedded setup does not match its pin during the run: no further product setup is started
  SuiteRunStopped: Boolean;
  // The step the status text of the installation page names
  SuiteRunStep, SuiteRunSteps: Integer;

function SuiteProductSetupFile(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteEEFile
  else
    Result := SuiteNeoEEFile;
end;

function SuiteProductSetupSHA256(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteEESHA256
  else
    Result := SuiteNeoEESHA256;
end;

function SuiteProductSetupSize(const Product: String): Int64;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteEESize
  else
    Result := SuiteNeoEESize;
end;

function SuiteProductAppIdOf(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteEEAppId
  else
    Result := SuiteNeoEEAppId;
end;

function SuiteProductTitle(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := CustomMessage('SuiteProductEE')
  else
    Result := CustomMessage('SuiteProductNeoEE');
end;

function SuiteStateOf(const Product: String): Integer;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteStateEE
  else
    Result := SuiteStateNeoEE;
end;

// The CI pass-through for the setup of the product: /EEArgs=... or /NeoEEArgs=... of the command line of the suite
function SuiteExtraArgs(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := ExpandConstant('{param:EEArgs|}')
  else
    Result := ExpandConstant('{param:NeoEEArgs|}');
end;

// The product of step Number (1 = EE, 2 = NeoEE): the order in which the products run
function SuiteProductOfNumber(Number: Integer): String;
begin
  if Number = 1 then
    Result := SuiteProductEE
  else
    Result := SuiteProductNeoEE;
end;

// The product is part of this run: selected, and not installed for one user only
function SuiteRunsProduct(const Product: String): Boolean;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := SuiteWantEE and SuiteCanInstall(SuiteStateEE)
  else
    Result := SuiteWantNeoEE and SuiteCanInstall(SuiteStateNeoEE);
end;

// Extracts the embedded setup of the product to {tmp} and compares its size and SHA-256 with the pins of the
// build. True if they match; the file stays for the caller. Otherwise Reason (a log text) says what is wrong and
// Mismatch whether the file was read but is not the one of the build (False: it could not be extracted or read).
// Lock is a handle that keeps the extracted file open for reading and denies writing from before the hash is
// computed: %TEMP% belongs to the user, who without elevation (split token) can write there, so without the lock
// a process of the user could replace the file between the comparison and Exec. The caller frees it (nil if the
// function did not get that far) after the file is deleted or the product setup has ended; reading and starting
// the file stay possible.
function SuiteExtractAndCheck(const Product: String; var Reason: String; var Mismatch: Boolean; var Lock: TFileStream): Boolean;
var
  Exe, Hash: String;
  Size: Int64;
begin
  Result := False;
  Reason := '';
  Mismatch := False;
  Lock := nil;
  Exe := ExpandConstant('{tmp}\') + SuiteProductSetupFile(Product);
  try
    ExtractTemporaryFile(SuiteProductSetupFile(Product));
  except
    Reason := 'extraction failed: ' + GetExceptionMessage;
    Exit;
  end;
  try
    Lock := TFileStream.Create(Exe, fmOpenRead or fmShareDenyWrite);
  except
    Reason := 'the extracted file cannot be locked against writing: ' + GetExceptionMessage;
    Exit;
  end;
  Size := -1;
  if not FileSize64(Exe, Size) then
  begin
    Reason := 'size of the extracted file not readable';
    Exit;
  end;
  Hash := '';
  try
    Hash := GetSHA256OfFile(Exe);
  except
    Reason := 'SHA-256 of the extracted file not readable: ' + GetExceptionMessage;
    Exit;
  end;
  if not SuitePinMatches(Hash, SuiteProductSetupSHA256(Product), Size, SuiteProductSetupSize(Product)) then
  begin
    Mismatch := True;
    Reason := 'size ' + IntToStr(Size) + ' (expected ' + IntToStr(SuiteProductSetupSize(Product)) + '), SHA-256 ' + Hash +
      ' (expected ' + SuiteProductSetupSHA256(Product) + ')';
    Exit;
  end;
  Result := True;
end;

// Before the installation starts: every selected product setup is extracted once, compared with its pin and
// deleted again (only one of them in {tmp} at a time). A mismatch stops the suite with exit code 15 before
// any product setup runs; nothing is installed at this point.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  I: Integer;
  Product, Reason: String;
  Mismatch, Matches: Boolean;
  Lock: TFileStream;
begin
  Result := '';
  for I := 1 to 2 do
  begin
    Product := SuiteProductOfNumber(I);
    if SuiteRunsProduct(Product) then
    begin
      Matches := SuiteExtractAndCheck(Product, Reason, Mismatch, Lock);
      if Lock <> nil then
        Lock.Free;
      DeleteFile(ExpandConstant('{tmp}\') + SuiteProductSetupFile(Product));
      // a mismatch is a file that is not the one of the build; the extraction itself failing is what a damaged
      // slice looks like (Setup raises "the source file is corrupted"): exit code 15 too, with its own text
      if not Matches and Mismatch then
        SuiteStop(SuiteExitProductSetup, 'the ' + Product + ' setup does not match its pin: ' + Reason,
          FmtMessage(CustomMessage('SuiteProductDamaged'), [SuiteProductTitle(Product)]))
      else if not Matches then
        SuiteStop(SuiteExitProductSetup, 'the ' + Product + ' setup could not be extracted or read (damaged slice?): ' + Reason,
          FmtMessage(CustomMessage('SuiteProductUnreadable'), [SuiteProductTitle(Product)]));
      Log('Pin check of the ' + Product + ' setup: ' + SuiteProductSetupFile(Product) + ' matches (size, SHA-256)');
    end;
  end;
end;

// True if the uninstall entry of the product setup is in HKLM (the 64-bit view in the suite's install mode)
// with an UninstallString (contract 1.3, 1.7 point 5)
function SuiteUninstallEntryPresent(const Product: String): Boolean;
var
  Value: String;
begin
  Value := '';
  Result := RegQueryStringValue(HKLM, SuiteUninstallKey(SuiteProductAppIdOf(Product)), 'UninstallString', Value) and (Value <> '');
end;

// Deletes the old shortcut files that earlier standalone runs of the product setup left, exactly the paths of
// contract 1.7 point 7 (SuiteLegacyShortcutPath), each deletion logged, then the start menu folder of the
// products if it is empty (RemoveDir does not remove a folder with content). Runs after the product setup
// succeeded and before the suite creates its own shortcuts at ssPostInstall: the suite shortcut of EE has the
// name of the old one.
procedure SuiteRemoveLegacyShortcuts(const Product: String);
var
  I: Integer;
  Path, Desktop, Group: String;
begin
  Desktop := ExpandConstant('{autodesktop}');
  Group := ExpandConstant('{autoprograms}\Empire Earth');
  for I := 1 to SuiteLegacyShortcutCount do
  begin
    Path := SuiteLegacyShortcutPath(Product, I, Desktop, Group);
    if (Path <> '') and FileExists(Path) then
    begin
      if DeleteFile(Path) then
        Log('Old shortcut of the ' + Product + ' setup removed: ' + Path)
      else
        Log('Old shortcut of the ' + Product + ' setup could not be removed: ' + Path);
    end;
  end;
  if DirExists(Group) then
    if RemoveDir(Group) then
      Log('Empty start menu folder removed: ' + Group);
end;

// The number of the line "CD Keys generation result: <n>" in the log of the NeoEE setup, '' if the log is
// missing, too large (more than 64 MiB) or has no such line. Read-only.
function SuiteReadCdKeyResult(const LogFile: String): String;
var
  Size: Int64;
  Text: AnsiString;
begin
  Result := '';
  if not FileExists(LogFile) then
    Exit;
  Size := 0;
  if not FileSize64(LogFile, Size) or (Size > 67108864) then
    Exit;
  if LoadStringFromFile(LogFile, Text) then
    Result := SuiteParseCdKeyResult(Text);
end;

// ---- the product setup as a process: start, Cancel, wait, limits (ADR 0013, amendment of S2) ------------

var
  // The product setup that runs: its process handle and its job (0 = none), the product, and what its log has
  // told so far. CancelButtonClick reads them while SuiteWaitForProduct pumps the messages.
  SuiteChildProc, SuiteChildJob: THandle;
  SuiteChildProduct: String;
  SuiteChildProgress: TSuiteProgress;
  // The cancel question is open (no second one), the user answered it with Yes (the wait stops the product setup
  // after it looked at the log once more), the run was cancelled (no further product, Setup ends)
  SuiteCancelAsking, SuiteCancelRequested, SuiteRunCancelled: Boolean;
  // /TestCancel of the command line (CI scenario S11): the first product setup is cancelled as soon as its real setup
  // has opened its log, as if the user had answered the question with Yes. Without it nobody can click Cancel in a
  // silent run.
  SuiteTestCancel: Boolean;

// The text for the user and the log for a failed product setup (exit code or reason), the log line in English
function SuiteReasonText(Kind: Integer): String;
begin
  case Kind of
    SuiteChildFatal: Result := CustomMessage('SuiteReasonFatal');
    SuiteChildPrecondition: Result := CustomMessage('SuiteReasonPrecondition');
    SuiteChildTimeout:
      begin
        if SuiteProgressInstalling(SuiteChildProgress) then
          Result := CustomMessage('SuiteReasonTimeoutInstalling')
        else
          Result := CustomMessage('SuiteReasonTimeout');
      end;
  else
    Result := CustomMessage('SuiteReasonOther');
  end;
end;

// A message at the end of a failed product setup; never in a silent run (SuppressibleMsgBox answers nothing
// there, the log and the last page tell)
procedure SuiteRunMessage(const Text: String);
begin
  if not SuiteSilent then
    SuppressibleMsgBox(Text, mbError, MB_OK, IDOK);
end;

// The Cancel button and the reason below the status line for what the Cancel button does now (SuiteCancelMode):
// on while the question may be asked, off with the reason otherwise. In a /VERYSILENT run the window is not shown.
procedure SuiteShowCancelMode(Mode: Integer);
begin
  WizardForm.CancelButton.Enabled := Mode = SuiteCancelAsk;
  case Mode of
    SuiteCancelInstalling: WizardForm.FilenameLabel.Caption := CustomMessage('SuiteCancelNotNow');
    SuiteCancelOwnWizard: WizardForm.FilenameLabel.Caption := CustomMessage('SuiteCancelOwnSetup');
    SuiteCancelNoJob: WizardForm.FilenameLabel.Caption := CustomMessage('SuiteCancelUnavailable');
  end;
end;

// The product of the run that is installed already (the one the question says stays installed), '' if none
function SuiteFinishedProduct: String;
begin
  Result := '';
  if SuiteProductSucceeded(SuiteProductEE) then
    Result := SuiteProductEE
  else if SuiteProductSucceeded(SuiteProductNeoEE) then
    Result := SuiteProductNeoEE;
end;

// The question of the Cancel button before the product setup installed anything. Yes only sets the request: the
// wait loop looks at the log once more, because the product setup went on while the question was open.
procedure SuiteAskCancel;
var
  Done: String;
begin
  SuiteCancelAsking := True;
  try
    Done := SuiteFinishedProduct;
    if Done <> '' then
    begin
      if SuppressibleMsgBox(FmtMessage(CustomMessage('SuiteCancelQuestionKept'), [SuiteProductTitle(SuiteChildProduct),
        SuiteProductTitle(Done)]), mbConfirmation, MB_YESNO, IDNO) = IDYES then
        SuiteCancelRequested := True;
    end
    else if SuppressibleMsgBox(FmtMessage(CustomMessage('SuiteCancelQuestion'), [SuiteProductTitle(SuiteChildProduct)]),
      mbConfirmation, MB_YESNO, IDNO) = IDYES then
      SuiteCancelRequested := True;
  finally
    SuiteCancelAsking := False;
  end;
end;

// The Cancel button and the close button of the window. While no product setup runs, Setup does what it always
// did. While one runs, Setup alone would honor the click only after the products (it sets a flag that is read
// after the installation step), so the suite answers: before the product setup installed anything the user is
// asked and a Yes stops it; after that there is no way back (SuiteCancelMode).
procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if SuiteChildProc = 0 then
    Exit;
  Cancel := False;
  Confirm := False;
  if SuiteCancelAsking or SuiteCancelRequested then
    Exit;
  case SuiteCancelMode(SuiteAdvanced, SuiteChildJob <> 0, SuiteProgressInstalling(SuiteChildProgress)) of
    SuiteCancelAsk: SuiteAskCancel;
    SuiteCancelInstalling:
      if not SuiteSilent then
        SuppressibleMsgBox(CustomMessage('SuiteCancelNotNow'), mbInformation, MB_OK, IDOK);
  end;
end;

// The question after a product setup showed no sign of life: True if the user wants to stop it. Default and
// answer of a suppressed box: keep waiting.
function SuiteAskStop(const Product: String): Boolean;
var
  Text: String;
begin
  SuiteCancelAsking := True;
  try
    if SuiteProgressInstalling(SuiteChildProgress) then
      Text := CustomMessage('SuiteStallQuestionInstalling')
    else
      Text := CustomMessage('SuiteStallQuestion');
    Result := SuppressibleMsgBox(FmtMessage(Text, [SuiteProductTitle(Product), IntToStr(SuiteStallMs div 60000)]),
      mbConfirmation, MB_YESNO, IDYES) = IDNO;
  finally
    SuiteCancelAsking := False;
  end;
end;

// Looks into the log of the product setup (not in the advanced mode: its wizard is the display) and writes a line
// to the log of the suite when the phase changes. True if the log grew.
function SuiteLookAtLog(const Product, LogFile: String; var Phase: Integer): Boolean;
begin
  Result := False;
  if SuiteAdvanced then
    Exit;
  Result := SuiteTailLog(LogFile, SuiteChildProgress);
  if SuiteChildProgress.Phase <> Phase then
  begin
    Phase := SuiteChildProgress.Phase;
    Log('Product ' + Product + ' phase: ' + SuitePhaseName(Phase) + ' (' + IntToStr(SuiteProgressPermille(SuiteChildProgress)) + ' of 1000)');
  end;
end;

// Stops the product setup and its job, waits up to SuiteKillWaitMs for it to be gone, and logs what became of it
procedure SuiteStopProduct(const Product, Why: String);
begin
  Log('Product ' + Product + ': ' + Why + ', stopping its setup and everything it started');
  SuiteKillProduct(SuiteChildProc, SuiteChildJob);
  if SuiteWaitEnd(SuiteChildProc, SuiteKillWaitMs) then
    Log('Product ' + Product + ': its setup is gone')
  else
    Log('Product ' + Product + ': its setup did not end within ' + IntToStr(SuiteKillWaitMs) + ' ms after it was stopped');
end;

// Waits for the product setup (SuiteChildProc, started by SuiteStartProduct) and keeps the window of Setup alive
// meanwhile: every SuiteWaitSliceMs the messages are handled (a Cancel click opens its question inside that), every
// SuiteTailEveryMs the log is read, and the limits of SuiteTimeoutCheck are looked at. Ends with SuiteEndExited (Code:
// its exit code, -1 if there is none; 259 is no exit code), SuiteEndCancelled (the user confirmed the cancel and the log
// showed that nothing was installed yet: the whole job was stopped), SuiteEndTimedOut (stopped for the limits) or
// SuiteEndQuit (Setup itself is closing: the product setup keeps running, as it does if the suite is killed). Nothing
// is stopped without a job, because the loader killed alone would leave the real setup running (SuiteStartProduct).
function SuiteWaitForProduct(const Product, LogFile: String; var Code: Integer): Integer;
var
  Started, LastTail, LastGrowth, Tick: DWORD;
  Phase, Mode, Shown, Waited: Integer;
  StallDone, CapDone: Boolean;
begin
  Code := -1;
  Result := SuiteEndExited;
  Started := SuiteTickCount;
  LastTail := Started;
  LastGrowth := Started;
  StallDone := False;
  CapDone := False;
  Phase := SuiteChildProgress.Phase;
  Shown := -1;
  repeat
    Mode := SuiteCancelMode(SuiteAdvanced, SuiteChildJob <> 0, SuiteProgressInstalling(SuiteChildProgress));
    if Mode <> Shown then
    begin
      SuiteShowCancelMode(Mode);
      Shown := Mode;
    end;
    if SuiteTestCancel and (Mode = SuiteCancelAsk) then
    begin
      // as soon as the real setup of the product (not only its loader) has opened its log
      SuiteLookAtLog(Product, LogFile, Phase);
      if SuiteChildProgress.TailOffset > 0 then
      begin
        SuiteTestCancel := False;
        Log('Product ' + Product + ': /TestCancel, the cancel is requested as if the user had answered the question with Yes');
        SuiteCancelRequested := True;
      end;
    end;
    if not SuitePumpMessages or Terminated then
    begin
      Log('Product ' + Product + ': Setup is closing, the wait for its setup ends (it keeps running)');
      Result := SuiteEndQuit;
      Exit;
    end;
    Waited := SuiteWaitObject(SuiteChildProc, SuiteWaitSliceMs);
    if Waited <> SuiteWaitTimeout then
    begin
      // the process ended (SuiteWaitObject0), or the wait itself failed (-1): the exit code tells what it can
      if Waited <> SuiteWaitObject0 then
        Log('Product ' + Product + ': the wait for its setup failed (' + SysErrorMessage(DLLGetLastError) + ')');
      if not SuiteProcessExitCode(SuiteChildProc, Code) then
        Log('Product ' + Product + ': no exit code of its setup');
      if SuiteCancelRequested then
      begin
        SuiteCancelRequested := False;
        Log('Product ' + Product + ': the cancel came too late, its setup had ended already');
      end;
      SuiteLookAtLog(Product, LogFile, Phase);
      Exit;
    end;
    Tick := SuiteTickCount;
    if SuiteTicksBetween(LastTail, Tick) >= SuiteTailEveryMs then
    begin
      LastTail := Tick;
      if SuiteLookAtLog(Product, LogFile, Phase) then
        LastGrowth := Tick;
    end;
    if SuiteCancelRequested then
    begin
      // the question may have been open for a while: the product setup went on, so look at the log again
      SuiteCancelRequested := False;
      LastTail := Tick;
      if SuiteLookAtLog(Product, LogFile, Phase) then
        LastGrowth := Tick;
      if SuiteProgressInstalling(SuiteChildProgress) then
      begin
        Log('Product ' + Product + ': the cancel came too late, its setup has started to install the game files');
        if not SuiteSilent then
          SuppressibleMsgBox(CustomMessage('SuiteCancelNotNow'), mbInformation, MB_OK, IDOK);
      end
      else
      begin
        SuiteStopProduct(Product, 'cancelled by the user before it installed anything');
        Result := SuiteEndCancelled;
        Exit;
      end;
    end;
    case SuiteTimeoutCheck(SuiteTicksBetween(Started, Tick), SuiteTicksBetween(LastGrowth, Tick), SuiteAdvanced,
        StallDone, CapDone) of
      SuiteTimeoutStall:
        begin
          StallDone := True;
          Log('Product ' + Product + ': no new line in its log for ' + IntToStr(SuiteStallMs div 60000) + ' minutes');
          if (SuiteChildJob <> 0) and not SuiteSilent then
            if SuiteAskStop(Product) then
            begin
              SuiteStopProduct(Product, 'stopped by the user after it showed no sign of life');
              Result := SuiteEndTimedOut;
              Exit;
            end;
        end;
      SuiteTimeoutCap:
        begin
          CapDone := True;
          if SuiteChildJob <> 0 then
          begin
            SuiteStopProduct(Product, 'runs for more than ' + IntToStr(SuiteProductCapMs div 60000) + ' minutes');
            Result := SuiteEndTimedOut;
            Exit;
          end;
          Log('Product ' + Product + ': runs for more than ' + IntToStr(SuiteProductCapMs div 60000) +
            ' minutes and cannot be stopped from here (not in a job object), waiting on');
        end;
    end;
  until False;
end;

// Runs the setup of one product. True if it succeeded: exit code 0 and its uninstall entry. Every other
// outcome is logged, told to the user (not in a silent run) and False; the caller goes on with the next product.
function SuiteRunProduct(const Product: String): Boolean;
var
  Exe, LogFile, Params, Reason: String;
  Code, Kind, Outcome, Err: Integer;
  Started, Failed, Mismatch, TasksKnown: Boolean;
  Lock: TFileStream;
  Tasks: String;
  Proc, Job: THandle;
begin
  Result := False;
  SuiteRunStep := SuiteRunStep + 1;
  LogFile := ExpandConstant('{app}\Logs\') + SuiteChildLogName(Product, GetDateTimeString('yyyymmdd-hhnn', #0, #0));

  // (a) no game and no launcher running (the product setup would refuse to start, too)
  if CheckForMutexes(SuiteMutexes) then
  begin
    Log('Product ' + Product + ' not run: a game or the launcher is running (mutex of ' + SuiteMutexes + ')');
    SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunGameRunning'), [SuiteProductTitle(Product)]));
    Exit;
  end;

  // (b) the setup, extracted, and (c) compared with its pin: a mismatch means no Exec, here or later
  Exe := ExpandConstant('{tmp}\') + SuiteProductSetupFile(Product);
  if not SuiteExtractAndCheck(Product, Reason, Mismatch, Lock) then
  begin
    if Lock <> nil then
      Lock.Free;
    DeleteFile(Exe);
    if Mismatch then
    begin
      // damaged or changed after PrepareToInstall: no product setup is started any more
      SuiteRunStopped := True;
      Log('Product ' + Product + ' not run, the setup does not match its pin: ' + Reason);
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunDamaged'), [SuiteProductTitle(Product)]));
    end
    else
    begin
      Log('Product ' + Product + ' not run: ' + Reason);
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product),
        FmtMessage(CustomMessage('SuiteReasonNotStarted'), [Reason]), LogFile]));
    end;
    Exit;
  end;

  // (d) the command line, the status text, the run
  Params := SuiteProductArguments(SuiteIsFirstInstall(SuiteStateOf(Product)), SuiteAdvanced,
    ActiveLanguage, LogFile, SuiteExtraArgs(Product));
  DeleteFile(LogFile);
  if SuiteAdvanced then
    WizardForm.StatusLabel.Caption := FmtMessage(CustomMessage('SuiteStepAdvanced'), [IntToStr(SuiteRunStep),
      IntToStr(SuiteRunSteps), SuiteProductTitle(Product)])
  else
    WizardForm.StatusLabel.Caption := FmtMessage(CustomMessage('SuiteStepRun'), [IntToStr(SuiteRunStep),
      IntToStr(SuiteRunSteps), SuiteProductTitle(Product)]);
  WizardForm.FilenameLabel.Caption := '';
  Log('Product ' + Product + ' (step ' + IntToStr(SuiteRunStep) + ' of ' + IntToStr(SuiteRunSteps) + ', state ' +
    IntToStr(SuiteStateOf(Product)) + '): ' + Exe + ' ' + Params);
  Code := -1;
  Outcome := SuiteEndExited;
  SuiteProgressInit(SuiteChildProgress, Product);
  SuiteCancelRequested := False;
  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);
  if Started then
  begin
    SuiteChildProduct := Product;
    SuiteChildProc := Proc;
    SuiteChildJob := Job;
    try
      Outcome := SuiteWaitForProduct(Product, LogFile, Code);
    finally
      // from here on a click on Cancel is Setup's again; the job and the process handles are only handles, closing
      // them stops nothing
      SuiteChildProc := 0;
      SuiteChildJob := 0;
      WizardForm.CancelButton.Enabled := True;
      SuiteCloseHandle(Proc);
      if Job <> 0 then
        SuiteCloseHandle(Job);
    end;
  end
  else
    Code := Err;
  Lock.Free;

  // (e) the extracted setup is deleted whatever happened
  if not DeleteFile(Exe) then
    Log('Extracted setup of ' + Product + ' not deleted (Setup removes {tmp} at the end): ' + Exe);

  // success = exit code 0 and the uninstall entry (contract 1.7 point 5)
  Failed := True;
  if not Started then
  begin
    Log('Product ' + Product + ' failed: the setup could not be started (' + SysErrorMessage(Code) + ', error ' + IntToStr(Code) + ')');
    SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product),
      FmtMessage(CustomMessage('SuiteReasonNotStarted'), [SysErrorMessage(Code)]), LogFile]));
  end
  else if Outcome = SuiteEndCancelled then
  begin
    // the question said that a product that was finished before stays installed; the suite ends, Setup rolls back
    // its own part, which is nothing yet (the suite writes its files after this step)
    SuiteRunCancelled := True;
    Log('Product ' + Product + ' was cancelled by the user before it installed anything');
  end
  else if Outcome = SuiteEndQuit then
  begin
    SuiteRunStopped := True;
    Log('Product ' + Product + ': Setup is closing, no further product setup is started');
  end
  else
  begin
    Kind := SuiteChildKind(Outcome = SuiteEndTimedOut, Code);
    if Kind = SuiteChildTimeout then
      Log('Product ' + Product + ': the setup was stopped by the suite (kind ' + IntToStr(Kind) + '), installing started ' +
        IntToStr(Ord(SuiteProgressInstalling(SuiteChildProgress))))
    else
      Log('Product ' + Product + ': the setup ended with exit code ' + IntToStr(Code) + ' (kind ' + IntToStr(Kind) + '), uninstall entry ' +
        IntToStr(Ord(SuiteUninstallEntryPresent(Product))));
    if (Outcome = SuiteEndExited) and SuiteRunSucceeded(Started, Code, SuiteUninstallEntryPresent(Product)) then
      Failed := False
    else if Kind = SuiteChildNotStarted then
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunGameRunning'), [SuiteProductTitle(Product)]))
    else if Kind = SuiteChildCancelled then
      Log('Product ' + Product + ' was cancelled in its setup')
    else if Kind = SuiteChildOk then
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product),
        CustomMessage('SuiteReasonNoEntry'), LogFile]))
    else if Kind = SuiteChildTimeout then
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product), SuiteReasonText(Kind), LogFile]))
    else
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product),
        FmtMessage(CustomMessage('SuiteReasonCode'), [IntToStr(Code), SuiteReasonText(Kind)]), LogFile]));
  end;
  if Failed then
    Exit;

  Result := True;
  SuiteProductsOk := SuiteMergeProducts(SuiteProductsOk, Product);
  // the old shortcuts of earlier standalone runs go before the suite creates its own (at ssPostInstall)
  SuiteRemoveLegacyShortcuts(Product);
  if CompareText(Product, SuiteProductNeoEE) = 0 then
  begin
    SuiteCdKeyResult := SuiteReadCdKeyResult(LogFile);
    Log('NeoEE CD key result from its log: "' + SuiteCdKeyResult + '" (empty: no such line)');
    // no such line is no failure if the task was not selected: the uninstall entry lists the tasks of the run
    // (read only; the registration itself is the business of the NeoEE setup alone)
    Tasks := '';
    TasksKnown := RegQueryStringValue(HKLM, SuiteUninstallKey(SuiteProductAppIdOf(Product)), 'Inno Setup: Selected Tasks', Tasks);
    SuiteCdKeyNotChosenFlag := SuiteCdKeyNotChosen(SuiteCdKeyResult, TasksKnown, Tasks);
    if SuiteCdKeyNotChosenFlag then
      Log('NeoEE setup ran without the task neoee_cdkeys (tasks of the run: "' + Tasks + '"): no registration was chosen');
  end;
end;

// The installation step: the selected products, EE before NeoEE. The folder of the logs {app}\Logs is created
// first. A product that fails does not stop the next one (the damaged-setup case does).
procedure SuiteRunProducts;
var
  I: Integer;
begin
  SuiteRunStopped := False;
  SuiteRunCancelled := False;
  SuiteRunStep := 0;
  SuiteRunSteps := 0;
  SuiteTestCancel := SuiteHasParam('/TestCancel') and not SuiteAdvanced;
  for I := 1 to 2 do
    if SuiteRunsProduct(SuiteProductOfNumber(I)) then
      SuiteRunSteps := SuiteRunSteps + 1;
  if SuiteRunSteps = 0 then
  begin
    Log('No product setup to run');
    Exit;
  end;
  if not ForceDirectories(ExpandConstant('{app}\Logs')) then
    Log('The folder of the logs could not be created: ' + ExpandConstant('{app}\Logs'));
  WizardForm.ProgressGauge.Style := npbstMarquee;
  try
    for I := 1 to 2 do
      if SuiteRunsProduct(SuiteProductOfNumber(I)) and not SuiteRunStopped and not SuiteRunCancelled then
        SuiteRunProduct(SuiteProductOfNumber(I));
  finally
    WizardForm.ProgressGauge.Style := npbstNormal;
  end;
  Log('Products that succeeded in this run: "' + SuiteProductsOk + '"');
  if SuiteRunCancelled then
  begin
    // Abort in this step ends Setup with exit code 3 and no message of its own; a product that finished before
    // stays installed, and the next run of the suite adopts it. The files and the record of the suite are written
    // after this step, so there is nothing of the suite to roll back.
    Log('The installation was cancelled by the user: no further product setup is started, Setup ends');
    Abort;
  end;
end;
