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
// The same wait loop shows what the product setup does (suite 1.1.0, S4): the status line names the step and what the
// log says is going on, the line between the status line and the bar the file, the bar the whole run, and a list the steps that are done
// (SuiteShowProgress; the log is only ever read, success stays the exit code and the uninstall entry). The advanced mode
// shows its own wizard and keeps the status line "the setup is open".
// Requires: suite_common.iss, suite.iss (the pins, SuiteMutexes, SuiteStop and the globals of the products).

var
  // Set when an embedded setup does not match its pin during the run: no further product setup is started
  SuiteRunStopped: Boolean;
  // The step the status text of the installation page names
  SuiteRunStep, SuiteRunSteps: Integer;
  // What the installation page shows of the running product setup, to change a control only when its text changes
  // (no flicker): the status line, the file line, the bar, and the steps of the game that are in the list already (one
  // bit per stage, 1 shl SuiteStage*). The display failed once (SuiteShowProgress): it is left as it is.
  SuiteShownStatus, SuiteShownFile: String;
  SuiteShownPosition, SuiteStagesShown: Integer;
  SuiteProgressBroken: Boolean;

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
// succeeded and before the suite deletes the shortcuts of suite 1.0.0 and creates its own at ssPostInstall (the
// desktop shortcut of the EE setup has the name that suite 1.0.0 used for its EE shortcut).
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
  // /TestCancel of the command line (CI scenario S11, S13): the first product setup is cancelled as soon as its real setup
  // has opened its log, as if the user had answered the question with Yes; /TestCancelNeoEE (S12) does the same for the
  // NeoEE setup, the second one. Without them nobody can click Cancel in a silent run. SuiteTestCancelProduct is the
  // product whose setup is cancelled.
  SuiteTestCancel: Boolean;
  SuiteTestCancelProduct: String;

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

// The Cancel button and the reason below the bar for what the Cancel button does now (SuiteCancelMode):
// on while the question may be asked, off with the reason otherwise. In a /VERYSILENT run the window is not shown.
procedure SuiteShowCancelMode(Mode: Integer);
begin
  WizardForm.CancelButton.Enabled := Mode = SuiteCancelAsk;
  case Mode of
    SuiteCancelInstalling: SuiteCancelLabel.Caption := CustomMessage('SuiteCancelNotNow');
    SuiteCancelOwnWizard: SuiteCancelLabel.Caption := CustomMessage('SuiteCancelOwnSetup');
    SuiteCancelNoJob: SuiteCancelLabel.Caption := CustomMessage('SuiteCancelUnavailable');
  else
    SuiteCancelLabel.Caption := '';
  end;
  // the label wraps and takes the lines it needs: the list of the steps moves below it (finding 7 of the review)
  SuiteLayoutProgressControls;
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

// The text of the question of the Cancel button (SuiteAskCancel), by what stays: a game that is installed already and
// is repaired or updated (Installed) stays exactly as it is, a game that this run finished before (Done <> '') stays
// installed and the suite then finishes without the cancelled game. Every text names the temporary folder of the product
// setup, which a stopped setup leaves with what it had downloaded.
function SuiteCancelQuestionText(const Product, Done: String; Installed: Boolean): String;
begin
  if Installed and (Done <> '') then
    Result := FmtMessage(CustomMessage('SuiteCancelQuestionInstalledKept'), [SuiteProductTitle(Product), SuiteProductTitle(Done)])
  else if Installed then
    Result := FmtMessage(CustomMessage('SuiteCancelQuestionInstalled'), [SuiteProductTitle(Product)])
  else if Done <> '' then
    Result := FmtMessage(CustomMessage('SuiteCancelQuestionKept'), [SuiteProductTitle(Product), SuiteProductTitle(Done)])
  else
    Result := FmtMessage(CustomMessage('SuiteCancelQuestion'), [SuiteProductTitle(Product)]);
end;

// The question of the Cancel button before the product setup changed the game folder. Yes only sets the request: the
// wait loop looks at the log once more, because the product setup went on while the question was open.
procedure SuiteAskCancel;
begin
  SuiteCancelAsking := True;
  try
    if SuppressibleMsgBox(SuiteCancelQuestionText(SuiteChildProduct, SuiteFinishedProduct,
      SuiteStateOf(SuiteChildProduct) = SuiteStateMachine), mbConfirmation, MB_YESNO, IDNO) = IDYES then
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

// The short name of the game for the status line
function SuiteProductShort(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := CustomMessage('SuiteShortEE')
  else
    Result := CustomMessage('SuiteShortNeoEE');
end;

// The status line for what the log of the product setup says it does: the number of the step and the game, then the
// phase (SuiteStatusKind); the line of the start is the one that names the game with its whole title
function SuiteStatusText(const Product: String; const P: TSuiteProgress): String;
var
  Step, Steps, Name: String;
begin
  Step := IntToStr(SuiteRunStep);
  Steps := IntToStr(SuiteRunSteps);
  Name := SuiteProductShort(Product);
  case SuiteStatusKind(P) of
    SuiteStatusProbe: Result := FmtMessage(CustomMessage('SuiteStepProbe'), [Step, Steps, Name]);
    SuiteStatusDownload: Result := FmtMessage(CustomMessage('SuiteStepDownload'), [Step, Steps, Name,
      IntToStr(SuiteDownloadIndex(P)), IntToStr(P.DownloadFiles)]);
    SuiteStatusVerify: Result := FmtMessage(CustomMessage('SuiteStepVerify'), [Step, Steps, Name]);
    SuiteStatusInstall: Result := FmtMessage(CustomMessage('SuiteStepInstall'), [Step, Steps, Name]);
    SuiteStatusCdKeys: Result := FmtMessage(CustomMessage('SuiteStepCdKeys'), [Step, Steps, Name]);
    SuiteStatusFinish: Result := FmtMessage(CustomMessage('SuiteStepFinish'), [Step, Steps, Name]);
  else
    Result := FmtMessage(CustomMessage('SuiteStepRun'), [Step, Steps, SuiteProductTitle(Product)]);
  end;
end;

// The line under the status line: the online file being downloaded with the part of it that has arrived, or the game file
// being installed; '' otherwise
function SuiteFileText(const P: TSuiteProgress): String;
var
  DoneText, TotalText: String;
begin
  Result := '';
  if P.Phase = SuitePhaseDownload then
  begin
    Result := P.CurrentFile;
    if (Result <> '') and (P.CurrentTotal > 0) then
    begin
      SuiteBytesTexts(P.CurrentBytes, P.CurrentTotal, ActiveLanguage, DoneText, TotalText);
      Result := FmtMessage(CustomMessage('SuiteFileProgress'), [Result, DoneText, TotalText]);
    end;
  end
  else if P.Phase = SuitePhaseInstall then
    Result := P.InstallFile;
end;

// Puts the bar at Permille of the whole run (Max of the bar is 1000), if it is not there already
procedure SuiteSetPosition(Permille: Integer);
begin
  if Permille <> SuiteShownPosition then
  begin
    SuiteShownPosition := Permille;
    WizardForm.ProgressGauge.Position := Permille;
  end;
end;

// Adds a step of the game to the list once (Stage is one of SuiteStage*)
procedure SuiteAddStage(Stage: Integer; const Text: String; Ticked: Boolean);
begin
  SuiteStagesShown := SuiteStagesShown or (1 shl Stage);
  SuiteStageAdd(Text, Ticked);
end;

// Adds the steps of the game that are done now to the list, each once, in the order of the log
procedure SuiteShowStages(const P: TSuiteProgress);
var
  Got, Total: Integer;
begin
  if ((SuiteStagesShown and (1 shl SuiteStageDownload)) = 0) and SuiteStageReached(P, SuiteStageDownload) then
  begin
    if SuiteOnlineCounts(P, Got, Total) then
      SuiteAddStage(SuiteStageDownload, FmtMessage(CustomMessage('SuiteStageDownloaded'), [IntToStr(Got), IntToStr(Total)]), True)
    else
      SuiteAddStage(SuiteStageDownload, CustomMessage('SuiteStageNoDownload'), True);
  end;
  if ((SuiteStagesShown and (1 shl SuiteStageInstall)) = 0) and SuiteStageReached(P, SuiteStageInstall) then
    SuiteAddStage(SuiteStageInstall, CustomMessage('SuiteStageInstalled'), True);
  if ((SuiteStagesShown and (1 shl SuiteStageCdKeys)) = 0) and SuiteStageReached(P, SuiteStageCdKeys) then
  begin
    if SuiteCdKeyKind(P.CdKeyResult) = SuiteCdKeyRegistered then
      SuiteAddStage(SuiteStageCdKeys, CustomMessage('SuiteStageCdKeysOk'), True)
    else
      SuiteAddStage(SuiteStageCdKeys, FmtMessage(CustomMessage('SuiteStageCdKeysFailed'), [Trim(P.CdKeyResult)]), False);
  end;
  if ((SuiteStagesShown and (1 shl SuiteStageManifest)) = 0) and SuiteStageReached(P, SuiteStageManifest) then
    SuiteAddStage(SuiteStageManifest, CustomMessage('SuiteStageManifest'), True);
end;

// Shows what the log of the running product setup says in the window: the status line, the file, the bar and the steps
// that are done. Not in the advanced mode (its wizard is the display and its log is not read). The display is never a
// reason to stop an installation: if it fails once, that is logged and it stays as it is.
procedure SuiteShowProgress(const Product: String);
var
  Text: String;
begin
  if SuiteAdvanced or SuiteProgressBroken then
    Exit;
  try
    Text := SuiteStatusText(Product, SuiteChildProgress);
    if Text <> SuiteShownStatus then
    begin
      SuiteShownStatus := Text;
      WizardForm.StatusLabel.Caption := Text;
    end;
    Text := SuiteFileText(SuiteChildProgress);
    if Text <> SuiteShownFile then
    begin
      SuiteShownFile := Text;
      WizardForm.FilenameLabel.Caption := Text;
    end;
    SuiteSetPosition(SuiteOverallPermille(SuiteRunStep, SuiteRunSteps, SuiteRunningPermille(SuiteChildProgress)));
    SuiteShowStages(SuiteChildProgress);
  except
    SuiteProgressBroken := True;
    Log('The progress display failed and stays as it is: ' + GetExceptionMessage);
  end;
end;

// The line of the last page about the language files of a product whose setup succeeded, from what its log told; ''
// if it was not read to its end (the advanced mode)
function SuiteLangLine(const P: TSuiteProgress): String;
var
  Got, Total: Integer;
begin
  Result := '';
  if SuiteAdvanced or (P.Phase < SuitePhaseDone) then
    Exit;
  if not SuiteOnlineCounts(P, Got, Total) then
    Result := CustomMessage('SuiteFinishLangNone')
  else if Got >= Total then
    Result := FmtMessage(CustomMessage('SuiteFinishLangOk'), [IntToStr(Got), IntToStr(Total)])
  else
    Result := FmtMessage(CustomMessage('SuiteFinishLangMissing'), [IntToStr(Got), IntToStr(Total), IntToStr(Total - Got)]);
end;

// Looks into the log of the product setup (not in the advanced mode: its wizard is the display), shows what it says
// and writes a line to the log of the suite when the phase changes. True if the log grew.
function SuiteLookAtLog(const Product, LogFile: String; var Phase: Integer): Boolean;
var
  Detail: String;
begin
  Result := False;
  if SuiteAdvanced then
    Exit;
  Result := SuiteTailLog(LogFile, SuiteChildProgress);
  if SuiteChildProgress.Phase <> Phase then
  begin
    Phase := SuiteChildProgress.Phase;
    Detail := '';
    if (Phase = SuitePhaseDownload) and (SuiteChildProgress.DownloadFiles > 0) then
      Detail := ', ' + IntToStr(SuiteChildProgress.DownloadFiles) + ' files';
    Log('Product ' + Product + ' phase: ' + SuitePhaseName(Phase) + Detail + ' (' + IntToStr(SuiteProgressPermille(SuiteChildProgress)) + ' of 1000)');
  end;
  SuiteShowProgress(Product);
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

// True while the product setup has not ended
function SuiteProductRuns: Boolean;
begin
  Result := SuiteWaitObject(SuiteChildProc, 0) = SuiteWaitTimeout;
end;

// The product setup ended (Waited = SuiteWaitObject0), or the wait itself failed: its exit code if it has one, a request
// to cancel that came too late, and a last look at its log, which always sees "Log closed."
procedure SuiteProductEnded(const Product, LogFile: String; Waited: Integer; var Phase, Code: Integer);
begin
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
end;

// The stall question and what follows from the answer: True if the product setup is to be stopped. The question is
// modal and the product setup goes on meanwhile, so an answer "stop" is looked at again (finding 3 of the review): if the
// product setup ended while the box was open nothing is stopped (the loop takes its exit code), and if it started to
// change the game folder while the box was open, the user is asked again with the text for an installing setup, which
// says that a stopped game may be half installed (the first text said that no game files were installed yet).
function SuiteStallStopWanted(const Product, LogFile: String; var Phase: Integer): Boolean;
var
  WasInstalling: Boolean;
begin
  WasInstalling := SuiteProgressInstalling(SuiteChildProgress);
  Result := SuiteAskStop(Product);
  if not Result then
    Exit;
  if not SuiteProductRuns then
  begin
    Log('Product ' + Product + ': its setup ended while the question was open, it is not stopped');
    Result := False;
    Exit;
  end;
  SuiteLookAtLog(Product, LogFile, Phase);
  if not WasInstalling and SuiteProgressInstalling(SuiteChildProgress) then
  begin
    Log('Product ' + Product + ': its setup started to install while the question was open, asking again');
    Result := SuiteAskStop(Product);
    if Result and not SuiteProductRuns then
    begin
      Log('Product ' + Product + ': its setup ended while the question was open, it is not stopped');
      Result := False;
    end;
  end;
end;

// Waits for the product setup (SuiteChildProc, started by SuiteStartProduct) and keeps the window of Setup alive
// meanwhile: every SuiteWaitSliceMs the messages are handled (a Cancel click opens its question inside that), every
// SuiteTailEveryMs the log is read, and the limits of SuiteTimeoutCheck are looked at. Ends with SuiteEndExited (Code:
// its exit code, -1 if there is none; 259 is no exit code), SuiteEndCancelled (the user confirmed the cancel and the log
// showed that the product setup had not started to change the game folder: the whole job was stopped), SuiteEndTimedOut
// (stopped: the user answered the stall question with stop, or the cap was reached before it started to install) or
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
    if SuiteTestCancel and (Mode = SuiteCancelAsk) and (CompareText(Product, SuiteTestCancelProduct) = 0) then
    begin
      // as soon as the real setup of the product (not only its loader) has opened its log
      SuiteLookAtLog(Product, LogFile, Phase);
      if SuiteChildProgress.TailOffset > 0 then
      begin
        SuiteTestCancel := False;
        // a placeholder product that is already installing when its log is first read can no longer be cancelled: the
        // scenario S11 then fails on this line instead of testing a cancel that came too late
        if SuiteProgressInstalling(SuiteChildProgress) then
          Log('Product ' + Product + ': /TestCancel not requested, its setup has started to install already')
        else
        begin
          Log('Product ' + Product + ': /TestCancel, the cancel is requested as if the user had answered the question with Yes');
          SuiteCancelRequested := True;
        end;
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
      SuiteProductEnded(Product, LogFile, Waited, Phase, Code);
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
        SuiteProgressInstalling(SuiteChildProgress), StallDone, CapDone) of
      SuiteTimeoutStall:
        begin
          StallDone := True;
          Log('Product ' + Product + ': no new line in its log for ' + IntToStr(SuiteStallMs div 60000) + ' minutes');
          if (SuiteChildJob <> 0) and not SuiteSilent then
            if SuiteStallStopWanted(Product, LogFile, Phase) then
            begin
              SuiteStopProduct(Product, 'stopped by the user after it showed no sign of life');
              Result := SuiteEndTimedOut;
              Exit;
            end;
        end;
      SuiteTimeoutCap:
        begin
          CapDone := True;
          // the line the cap stands at may be a moment old: look once more before anything is stopped
          if SuiteLookAtLog(Product, LogFile, Phase) then
            LastGrowth := Tick;
          if SuiteProgressInstalling(SuiteChildProgress) then
            Log('Product ' + Product + ': runs for more than ' + IntToStr(SuiteProductCapMs div 60000) +
              ' minutes and has started to install, it is not stopped for its time, waiting on')
          else if SuiteChildJob <> 0 then
          begin
            SuiteStopProduct(Product, 'runs for more than ' + IntToStr(SuiteProductCapMs div 60000) + ' minutes before it installed anything');
            Result := SuiteEndTimedOut;
            Exit;
          end
          else
            Log('Product ' + Product + ': runs for more than ' + IntToStr(SuiteProductCapMs div 60000) +
              ' minutes and cannot be stopped from here (not in a job object), waiting on');
        end;
      SuiteTimeoutCapInstalling:
        begin
          CapDone := True;
          Log('Product ' + Product + ': runs for more than ' + IntToStr(SuiteProductCapMs div 60000) +
            ' minutes and has started to install, it is not stopped for its time, waiting on');
        end;
    end;
  until False;
end;

// One line in the log of the suite with what the log of the product setup told, to compare with the estimates of the
// bar and with the product log (not in the advanced mode, which reads none)
procedure SuiteLogProgressEnd(const Product: String);
var
  Got, Total: Integer;
begin
  if SuiteAdvanced then
    Exit;
  Got := 0;
  Total := 0;
  SuiteOnlineCounts(SuiteChildProgress, Got, Total);
  Log('Product ' + Product + ' log read: last phase ' + SuitePhaseName(SuiteChildProgress.Phase) + ', language files ' +
    IntToStr(Got) + ' of ' + IntToStr(Total) + ' (' + IntToStr(SuiteChildProgress.OnlineMissing) + ' missing), ' +
    IntToStr(SuiteChildProgress.InstallFiles) + ' file entries installed (estimate ' + IntToStr(SuiteChildProgress.InstallEstimate) +
    '), CD key result "' + SuiteChildProgress.CdKeyResult + '"');
end;

// The window before the setup of a product starts: its heading in the list, the display of the last product forgotten
// and the bar at the start of the step (not in the advanced mode: the bar keeps running without a position)
procedure SuiteBeginProductDisplay(const Product: String);
begin
  SuiteShownStatus := '';
  SuiteShownFile := '';
  SuiteShownPosition := -1;
  SuiteStagesShown := 0;
  try
    SuiteStageHeading(SuiteProductTitle(Product));
    if not SuiteAdvanced then
      SuiteSetPosition(SuiteOverallPermille(SuiteRunStep + 1, SuiteRunSteps, 0));
  except
    Log('The list of the steps could not be extended: ' + GetExceptionMessage);
  end;
end;

// The window after the setup of a product ended with its result (Ok: exit code 0 and the uninstall entry): the last
// line of its block in the list, and the bar at the end of the step, which the exit code now allows
procedure SuiteEndProductDisplay(Ok: Boolean);
begin
  try
    if Ok then
      SuiteStageAdd(CustomMessage('SuiteStageDone'), True)
    else
      SuiteStageAdd(CustomMessage('SuiteStageFailed'), False);
    if not SuiteAdvanced then
      SuiteSetPosition(SuiteOverallPermille(SuiteRunStep, SuiteRunSteps, 1000));
  except
    Log('The list of the steps could not be extended: ' + GetExceptionMessage);
  end;
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
      SuiteCancelLabel.Caption := '';
      SuiteLayoutProgressControls;
      SuiteCloseHandle(Proc);
      if Job <> 0 then
        SuiteCloseHandle(Job);
    end;
  end
  else
    Code := Err;
  Lock.Free;
  SuiteLogProgressEnd(Product);

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
    // the question said that a product that was finished before stays installed (SuiteRunProducts: the suite ends or
    // finishes its own part, whichever leaves nothing half done)
    SuiteRunCancelled := True;
    SuiteCancelledProduct := Product;
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
  if CompareText(Product, SuiteProductEE) = 0 then
    SuiteLangLineEE := SuiteLangLine(SuiteChildProgress)
  else
    SuiteLangLineNeoEE := SuiteLangLine(SuiteChildProgress);
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
  OldStyle: TNewProgressBarStyle;
  OldMax, OldPosition: Longint;
begin
  SuiteRunStopped := False;
  SuiteRunCancelled := False;
  SuiteCancelledProduct := '';
  SuiteRunStep := 0;
  SuiteRunSteps := 0;
  SuiteProgressBroken := False;
  SuiteLangLineEE := '';
  SuiteLangLineNeoEE := '';
  SuiteTestCancel := (SuiteHasParam('/TestCancel') or SuiteHasParam('/TestCancelNeoEE')) and not SuiteAdvanced;
  if SuiteHasParam('/TestCancelNeoEE') then
    SuiteTestCancelProduct := SuiteProductNeoEE
  else
    SuiteTestCancelProduct := SuiteProductEE;
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
  // The bar of the whole run (1000 steps, one product setup a step of 1000 / number of steps) runs from here to the
  // end of the last setup; the advanced mode has no log to read and keeps the running bar. What Setup had set for its own
  // installation of the files afterwards is put back.
  OldStyle := WizardForm.ProgressGauge.Style;
  OldMax := WizardForm.ProgressGauge.Max;
  OldPosition := WizardForm.ProgressGauge.Position;
  SuiteStageClear;
  SuiteLayoutProgressControls;
  SuiteStageList.Visible := True;
  if SuiteAdvanced then
    WizardForm.ProgressGauge.Style := npbstMarquee
  else
  begin
    WizardForm.ProgressGauge.Style := npbstNormal;
    WizardForm.ProgressGauge.Min := 0;
    WizardForm.ProgressGauge.Max := 1000;
    WizardForm.ProgressGauge.Position := 0;
  end;
  try
    for I := 1 to 2 do
      if SuiteRunsProduct(SuiteProductOfNumber(I)) and not SuiteRunStopped and not SuiteRunCancelled then
      begin
        SuiteBeginProductDisplay(SuiteProductOfNumber(I));
        if SuiteRunProduct(SuiteProductOfNumber(I)) then
          SuiteEndProductDisplay(True)
        else if not SuiteRunCancelled then
          SuiteEndProductDisplay(False);
      end;
  finally
    SuiteStageList.Visible := False;
    WizardForm.ProgressGauge.Style := OldStyle;
    WizardForm.ProgressGauge.Max := OldMax;
    WizardForm.ProgressGauge.Position := OldPosition;
  end;
  Log('Products that succeeded in this run: "' + SuiteProductsOk + '"');
  if SuiteRunCancelled then
  begin
    if SuiteProductsOk = '' then
    begin
      // nothing of this run is installed: Abort in this step ends Setup with exit code 3 and no message of its own. The
      // files and the record of the suite are written after this step, so there is nothing of the suite to roll back.
      Log('The installation was cancelled by the user: no further product setup is started, Setup ends');
      Abort;
    end;
    // A product finished before the cancel (the question said it stays installed): its old shortcuts are gone already
    // (SuiteRemoveLegacyShortcuts, /NOICONS), so ending here would leave it without a shortcut, the launcher and a record.
    // The run goes on to the launcher, the shortcuts and the record for the products that succeeded; the cancelled
    // product counts like one that failed, and the last page says that the user cancelled it (finding 5 of the review).
    Log('The installation of ' + SuiteCancelledProduct + ' was cancelled by the user: no further product setup is started, ' +
      'the suite finishes its own part for "' + SuiteProductsOk + '"');
  end;
end;
