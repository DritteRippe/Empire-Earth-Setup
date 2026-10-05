[Code]
// The product runner (contract 1.7 points 1 to 7, ADR 0013): at ssInstall the suite runs the setups of the
// products the user selected, EE before NeoEE, each one unchanged and byte for byte as it was built into the
// package. Before anything runs, PrepareToInstall extracts every selected setup once and compares its
// SHA-256 and size with the pins of the build (exit code 15, nothing installed); right before each Exec the
// runner compares again. The suite record and the suite shortcuts are written afterwards, at ssPostInstall,
// by suite.iss, only from what this runner reports in SuiteProductsOk (spike decision, ADR 0013 Evidence).
// The runner never starts anything but the embedded product setups, never touches the CD key registration
// of NeoEE (the NeoEE setup does it; the runner only reads the number the setup logged), and deletes only
// its own extracted setup, the log of the product setup it is about to write, and the old shortcut files of
// contract 1.7 point 7.
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
function SuiteExtractAndCheck(const Product: String; var Reason: String; var Mismatch: Boolean): Boolean;
var
  Exe, Hash: String;
  Size: Int64;
begin
  Result := False;
  Reason := '';
  Mismatch := False;
  Exe := ExpandConstant('{tmp}\') + SuiteProductSetupFile(Product);
  try
    ExtractTemporaryFile(SuiteProductSetupFile(Product));
  except
    Reason := 'extraction failed: ' + GetExceptionMessage;
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
begin
  Result := '';
  for I := 1 to 2 do
  begin
    Product := SuiteProductOfNumber(I);
    if SuiteRunsProduct(Product) then
    begin
      Matches := SuiteExtractAndCheck(Product, Reason, Mismatch);
      DeleteFile(ExpandConstant('{tmp}\') + SuiteProductSetupFile(Product));
      if not Matches then
        SuiteStop(SuiteExitProductSetup, 'the ' + Product + ' setup does not match its pin: ' + Reason,
          FmtMessage(CustomMessage('SuiteProductDamaged'), [SuiteProductTitle(Product)]));
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

// The text for the user and the log for a failed product setup (exit code or reason), the log line in English
function SuiteReasonText(Kind: Integer): String;
begin
  case Kind of
    SuiteChildFatal: Result := CustomMessage('SuiteReasonFatal');
    SuiteChildPrecondition: Result := CustomMessage('SuiteReasonPrecondition');
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

// Runs the setup of one product. True if it succeeded: exit code 0 and its uninstall entry. Every other
// outcome is logged, told to the user (not in a silent run) and False; the caller goes on with the next product.
function SuiteRunProduct(const Product: String): Boolean;
var
  Exe, LogFile, Params, Reason: String;
  Code, Kind: Integer;
  Started, Failed, Mismatch: Boolean;
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
  if not SuiteExtractAndCheck(Product, Reason, Mismatch) then
  begin
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
  Started := Exec(Exe, Params, ExpandConstant('{tmp}'), SW_SHOWNORMAL, ewWaitUntilTerminated, Code);

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
  else
  begin
    Kind := SuiteChildExitKind(Code);
    Log('Product ' + Product + ': the setup ended with exit code ' + IntToStr(Code) + ' (kind ' + IntToStr(Kind) + '), uninstall entry ' +
      IntToStr(Ord(SuiteUninstallEntryPresent(Product))));
    if SuiteRunSucceeded(Started, Code, SuiteUninstallEntryPresent(Product)) then
      Failed := False
    else if Kind = SuiteChildNotStarted then
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunGameRunning'), [SuiteProductTitle(Product)]))
    else if Kind = SuiteChildCancelled then
      Log('Product ' + Product + ' was cancelled in its setup')
    else if Kind = SuiteChildOk then
      SuiteRunMessage(FmtMessage(CustomMessage('SuiteRunFailed'), [SuiteProductTitle(Product),
        CustomMessage('SuiteReasonNoEntry'), LogFile]))
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
  end;
end;

// The installation step: the selected products, EE before NeoEE. The folder of the logs {app}\Logs is created
// first. A product that fails does not stop the next one (the damaged-setup case does).
procedure SuiteRunProducts;
var
  I: Integer;
begin
  SuiteRunStopped := False;
  SuiteRunStep := 0;
  SuiteRunSteps := 0;
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
      if SuiteRunsProduct(SuiteProductOfNumber(I)) and not SuiteRunStopped then
        SuiteRunProduct(SuiteProductOfNumber(I));
  finally
    WizardForm.ProgressGauge.Style := npbstNormal;
  end;
  Log('Products that succeeded in this run: "' + SuiteProductsOk + '"');
end;
