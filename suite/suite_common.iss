[Code]
// Pure helpers of the suite installer (suite.iss, ADR 0013): they compute something from their
// arguments and touch no wizard page, so ci/tests/suite_tests.iss tests them (run by
// ci/tests/unit_tests.iss). Only SuiteFindSliceProblems and SuiteIsBehindLink read the file system (file
// sizes, folder attributes); the tests give them files and folders of their own temporary folder.
// Requires: nothing (no define, no other script). Included before every other [Code] part of the suite.

const
  // Exit codes of the suite when one of its own prechecks stops it, in InitializeSetup and before the
  // first product setup runs. Inno Setup's own codes 0 to 8 keep their meaning; 3 is a damaged slice
  // ("The source file is corrupted", proven by the WP0 spike, ADR 0013 Evidence), 5 a cancelled
  // wizard, 7 a PrepareToInstall message in a silent run. Every code comes with a log line and, unless
  // the run is silent, a message. docs/TEST-PLAN.de.md and the README name them.
  SuiteExitSilentArguments = 10;   // silent run without a valid /PRODUCTS or without the decision on neoee_cdkeys; also not in the admin install mode
  SuiteExitSlices = 11;            // a slice (Empire Earth Community Setup-N.bin) is missing or has another size
  SuiteExitZipView = 12;           // as 11, and the setup was started from a temporary folder or from the ZIP view
  SuiteExitDiskSpace = 13;         // not enough free space on the drive of %TEMP% or of the installation folder
  SuiteExitRunning = 14;           // a game or the launcher is running
  SuiteExitProductSetup = 15;      // an embedded product setup does not match its pin (SHA-256, size): nothing was run

  // Free space beyond the files themselves: the setup log, the product logs, the extraction
  SuiteSpaceMargin = 268435456;    // 256 MiB

  // .NET Framework 4.8 or later: Release in HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full
  // (4.8 is 528040 on Windows 10 May 2019 Update, 528049 on the others, 533320 and more on 4.8.1)
  SuiteDotNet48Release = 528040;

  // The two product ids of the suite, in the order they are installed
  SuiteProductEE = 'EE';
  SuiteProductNeoEE = 'NeoEE';

// Name of slice Index (1, 2, ...) of the disk-spanned setup: <OutputBaseFilename>-<Index>.bin
function SuiteSliceFileName(const BaseName: String; Index: Integer): String;
begin
  Result := BaseName + '-' + IntToStr(Index) + '.bin';
end;

// Number of items of a comma separated list of sizes (an empty list has none)
function SuiteListedCount(const List: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  if Trim(List) = '' then
    Exit;
  Result := 1;
  for I := 1 to Length(List) do
    if List[I] = ',' then
      Result := Result + 1;
end;

// Checks a slice: 0 = fine, 1 = missing, 2 = empty or larger than a slice may be (DiskSliceSize)
function SuiteSliceState(Exists: Boolean; const ActualSize, MaxSize: Int64): Integer;
begin
  if not Exists then
    Result := 1
  else if (ActualSize <= 0) or (ActualSize > MaxSize) then
    Result := 2
  else
    Result := 0;
end;

// The slices of the package in Dir (<BaseName>-1.bin ... -Count.bin) against what the build recorded:
// every slice is there, none is empty or larger than MaxSize (DiskSliceSize), and all together have
// exactly Total bytes. The single sizes are not recorded: slice 1 is DiskSliceSize minus the size of
// setup.exe, and compiling its digits into setup.exe changed it (the build never became stable); the
// total does not depend on setup.exe. A truncated or replaced slice changes the total, but then the
// problem has no file name. Returns '' if all is fine, else one line per problem (at most MaxLines, then
// "... and n more"), separated by CRLF. Count = 0 means the build recorded no slices (first pass of the
// two-pass build, which is never shipped): nothing to check.
function SuiteFindSliceProblems(const Dir, BaseName: String; Count: Integer; const MaxSize, Total: Int64; MaxLines: Integer): String;
var
  I, Found, State: Integer;
  Path, Line: String;
  Actual, Sum: Int64;
begin
  Result := '';
  if Count <= 0 then
    Exit;
  Found := 0;
  Sum := 0;
  for I := 1 to Count do
  begin
    Path := AddBackslash(Dir) + SuiteSliceFileName(BaseName, I);
    Actual := 0;
    if not FileExists(Path) then
      State := 1
    else if not FileSize64(Path, Actual) then
      State := 1
    else
      State := SuiteSliceState(True, Actual, MaxSize);
    if State = 0 then
      Sum := Sum + Actual;
    if State <> 0 then
    begin
      Found := Found + 1;
      if Found <= MaxLines then
      begin
        if State = 1 then
          Line := SuiteSliceFileName(BaseName, I) + ' (missing)'
        else
          Line := SuiteSliceFileName(BaseName, I) + ' (' + IntToStr(Actual) + ' bytes, at most ' + IntToStr(MaxSize) + ' and not empty expected)';
        if Result <> '' then
          Result := Result + #13#10;
        Result := Result + Line;
      end;
    end;
  end;
  if Found > MaxLines then
    Result := Result + #13#10 + '... and ' + IntToStr(Found - MaxLines) + ' more'
  else if (Found = 0) and (Sum <> Total) then
    Result := SuiteSliceFileName(BaseName, 1) + ' to ' + SuiteSliceFileName(BaseName, Count) + ' together have ' + IntToStr(Sum) +
      ' bytes, expected ' + IntToStr(Total) + ' (a slice is damaged or from another build)';
end;

// Folder name without trailing backslashes, in upper case, for comparisons
function SuiteNormalizedPath(const Path: String): String;
begin
  Result := UpperCase(Trim(Path));
  while (Length(Result) > 0) and (Result[Length(Result)] = '\') do
    Delete(Result, Length(Result), 1);
end;

// True if Path is Folder or lies below it (a folder named like the start of Folder does not count)
function SuiteIsSameOrInside(const Path, Folder: String): Boolean;
var
  P, F: String;
begin
  P := SuiteNormalizedPath(Path);
  F := SuiteNormalizedPath(Folder);
  Result := (F <> '') and ((P = F) or (Copy(P, 1, Length(F) + 1) = F + '\'));
end;

// The heuristic for "started from the ZIP view or from a temporary folder": Windows Explorer runs
// a program from a ZIP archive after copying only that file to <Temp>\Temp<n>_<name>.zip, so the
// slices next to it are missing. True if the folder of the setup (Src) is the temporary folder or
// below it, or a folder whose name ends in ".zip" lies on its path.
function SuiteIsZipViewPath(const Src, TempDir: String): Boolean;
begin
  Result := SuiteIsSameOrInside(Src, TempDir)
    or (Pos('.ZIP\', SuiteNormalizedPath(Src) + '\') > 0);
end;

// Drive (or \\server\share) of a path in upper case, '' for a relative path
function SuiteDriveOf(const Path: String): String;
begin
  Result := UpperCase(ExtractFileDrive(Trim(Path)));
end;

// Free space needed on the drive of the temporary folder: the setups are extracted one after the
// other and deleted, so the largest selected one counts
function SuiteRequiredTempBytes(const EESetupBytes, NeoEESetupBytes: Int64; WantEE, WantNeoEE: Boolean): Int64;
begin
  Result := 0;
  if WantEE and (EESetupBytes > Result) then
    Result := EESetupBytes;
  if WantNeoEE and (NeoEESetupBytes > Result) then
    Result := NeoEESetupBytes;
  Result := Result + SuiteSpaceMargin;
end;

// Free space needed on the drive of the installation folders: every selected product plus the launcher
function SuiteRequiredTargetBytes(const EEInstallBytes, NeoEEInstallBytes, LauncherBytes: Int64; WantEE, WantNeoEE: Boolean): Int64;
begin
  Result := LauncherBytes + SuiteSpaceMargin;
  if WantEE then
    Result := Result + EEInstallBytes;
  if WantNeoEE then
    Result := Result + NeoEEInstallBytes;
end;

// 0 = enough space, 1 = the drive of the temporary folder is too small, 2 = the drive of the
// installation folders is too small. If both are one drive the extraction and the installation
// need their space at the same time, so the sum is compared with what is free there.
function SuiteSpaceProblem(const TempFree, TempNeeded, TargetFree, TargetNeeded: Int64; SameDrive: Boolean): Integer;
begin
  Result := 0;
  if SameDrive then
  begin
    if TargetFree < TempNeeded + TargetNeeded then
      Result := 2;
  end
  else if TempFree < TempNeeded then
    Result := 1
  else if TargetFree < TargetNeeded then
    Result := 2;
end;

// A size for a message in whole megabytes (1 MB = 1048576 bytes), rounded up
function SuiteFormatMegabytes(const Bytes: Int64): String;
begin
  Result := IntToStr((Bytes + 1048575) div 1048576) + ' MB';
end;

// .NET Framework 4.8 or later from the Release value; 0 means the value is not there
function SuiteIsDotNet48Release(const Release: Cardinal): Boolean;
begin
  Result := Release >= SuiteDotNet48Release;
end;

// True if the comma separated list has the item (compared without case, items trimmed)
function SuiteListHasItem(const List, Item: String): Boolean;
var
  Rest, Current: String;
  P: Integer;
begin
  Result := False;
  Rest := List;
  while True do
  begin
    P := Pos(',', Rest);
    if P > 0 then
      Current := Copy(Rest, 1, P - 1)
    else
      Current := Rest;
    if (Trim(Item) <> '') and (CompareText(Trim(Current), Trim(Item)) = 0) then
    begin
      Result := True;
      Exit;
    end;
    if P = 0 then
      Exit;
    Rest := Copy(Rest, P + 1, Length(Rest));
  end;
end;

// Product ids of two comma separated lists as one list: EE before NeoEE, every id once, anything
// else dropped. The suite record lists the products of this run and of earlier runs this way
// (contract 1.6).
function SuiteMergeProducts(const First, Second: String): String;
begin
  Result := '';
  if SuiteListHasItem(First, SuiteProductEE) or SuiteListHasItem(Second, SuiteProductEE) then
    Result := SuiteProductEE;
  if SuiteListHasItem(First, SuiteProductNeoEE) or SuiteListHasItem(Second, SuiteProductNeoEE) then
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + SuiteProductNeoEE;
  end;
end;

// True if the list names at least one product and nothing but EE and NeoEE (each at most once)
function SuiteIsValidProductList(const List: String): Boolean;
var
  Rest, Current: String;
  P, Count: Integer;
begin
  Result := False;
  Count := 0;
  Rest := List;
  while True do
  begin
    P := Pos(',', Rest);
    if P > 0 then
      Current := Copy(Rest, 1, P - 1)
    else
      Current := Rest;
    if (CompareText(Trim(Current), SuiteProductEE) <> 0) and (CompareText(Trim(Current), SuiteProductNeoEE) <> 0) then
      Exit;
    Count := Count + 1;
    if P = 0 then
      Break;
    Rest := Copy(Rest, P + 1, Length(Rest));
  end;
  // two items of the list are two different products
  Result := (Count <= 2) and (Count = SuiteListedCount(SuiteMergeProducts(List, '')));
end;

// True if Args (the arguments for a product setup, e.g. /TASKS=full,neoee_cdkeys) names Task as a whole
// word: after "=", "," or "!" and before "," or the end or a blank or a quote. "!neoee_cdkeys" in
// /MERGETASKS counts: it is a decision too.
function SuiteArgumentsNameTask(const Args, Task: String): Boolean;
var
  Text, Wanted: String;
  P, Start, After: Integer;
  Before, Next: String;
begin
  Result := False;
  Text := LowerCase(Args);
  Wanted := LowerCase(Task);
  Start := 1;
  while Start <= Length(Text) do
  begin
    P := Pos(Wanted, Copy(Text, Start, Length(Text)));
    if P = 0 then
      Exit;
    P := Start + P - 1;
    Before := '';
    if P > 1 then
      Before := Copy(Text, P - 1, 1);
    After := P + Length(Wanted);
    Next := '';
    if After <= Length(Text) then
      Next := Copy(Text, After, 1);
    if ((Before = '=') or (Before = ',') or (Before = '!'))
      and ((Next = '') or (Next = ',') or (Next = ' ') or (Next = '"')) then
    begin
      Result := True;
      Exit;
    end;
    Start := P + 1;
  end;
end;

// What a silent run of the suite needs (contract 1.7 point 3): the products to install (/PRODUCTS=EE,NeoEE)
// and, if NeoEE is among them, a decision about the CD key registration in the arguments for the NeoEE
// setup (/NeoEEArgs=...): the task neoee_cdkeys named in /TASKS or /MERGETASKS ("!neoee_cdkeys" for
// not registering). Without it a test run could contact the CD key server unasked.
// 0 = fine, 1 = no valid /PRODUCTS, 2 = NeoEE without a decision on neoee_cdkeys
function SuiteSilentArgumentsProblem(const Products, NeoEEArgs: String): Integer;
begin
  Result := 0;
  if not SuiteIsValidProductList(Products) then
    Result := 1
  else if SuiteListHasItem(Products, SuiteProductNeoEE) and not SuiteArgumentsNameTask(NeoEEArgs, 'neoee_cdkeys') then
    Result := 2;
end;

// Registry key of the uninstall entry of a product setup: <AppId>_is1 below the Uninstall key
// (AppId without braces), as Inno Setup names it
function SuiteUninstallKey(const AppIdWithoutBraces: String): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{' + AppIdWithoutBraces + '}_is1';
end;

// ---- the wizard pages (suite_pages.iss) --------------------------------------------------------

const
  // How a product setup is installed on this computer (SuiteProductState)
  SuiteStateNone = 0;              // no uninstall entry
  SuiteStateMachine = 1;           // installed for all users (HKLM, the mode of the suite)
  SuiteStateUserOnly = 2;          // installed for one user only (HKCU, and not in HKLM): the suite skips it

  // What became of one item of the installation (SuiteItemResult), for the last page
  SuiteResultNotSelected = 0;
  SuiteResultOk = 1;
  SuiteResultFailed = 2;
  SuiteResultSkippedUser = 3;

  // The answer of the NeoEE CD key registration (SuiteCdKeyKind), from "CD Keys generation result: <n>"
  SuiteCdKeyRegistered = 0;
  SuiteCdKeyNotRegistered = 1;
  SuiteCdKeyUnknown = 2;

// The state of a product from its uninstall entries: for all users wins over for one user
function SuiteProductState(InMachineKey, InUserKey: Boolean): Integer;
begin
  if InMachineKey then
    Result := SuiteStateMachine
  else if InUserKey then
    Result := SuiteStateUserOnly
  else
    Result := SuiteStateNone;
end;

// True if a product of this state can be installed by the suite (not one that is for one user only)
function SuiteCanInstall(State: Integer): Boolean;
begin
  Result := State <> SuiteStateUserOnly;
end;

// The products the suite installs from the ticks of the user: ticked, and not for one user only
// (comma separated, EE before NeoEE)
function SuiteSelectedProducts(TickEE, TickNeoEE: Boolean; StateEE, StateNeoEE: Integer): String;
begin
  Result := '';
  if TickEE and SuiteCanInstall(StateEE) then
    Result := SuiteProductEE;
  if TickNeoEE and SuiteCanInstall(StateNeoEE) then
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + SuiteProductNeoEE;
  end;
end;

// True if the user has to answer the legal question: only when neither product is installed
// (installed for one user only counts as installed: the user had the game before)
function SuiteLegalAnswerRequired(StateEE, StateNeoEE: Integer): Boolean;
begin
  Result := (StateEE = SuiteStateNone) and (StateNeoEE = SuiteStateNone);
end;

// True if the legal page may be left: the question is answered with yes, or not asked
function SuiteLegalPageDone(Required, Answered: Boolean): Boolean;
begin
  Result := (not Required) or Answered;
end;

// The name of a button without the accelerator and the arrows of its caption ("&Next >" is "Next")
function SuiteButtonName(const Caption: String): String;
begin
  Result := Caption;
  StringChangeEx(Result, '&', '', True);
  StringChangeEx(Result, '<', '', True);
  StringChangeEx(Result, '>', '', True);
  Result := Trim(Result);
end;

// What became of an item: it succeeded, or it was selected and failed, or it was skipped because it is
// installed for one user only, or it was not selected
function SuiteItemResult(Succeeded, Selected: Boolean; State: Integer): Integer;
begin
  if Succeeded then
    Result := SuiteResultOk
  else if not SuiteCanInstall(State) then
    Result := SuiteResultSkippedUser
  else if Selected then
    Result := SuiteResultFailed
  else
    Result := SuiteResultNotSelected;
end;

// What to tell about the CD key registration of NeoEE from the number the NeoEE setup logged
// ("CD Keys generation result: <n>", 0 = registered); an empty or no number is unknown
function SuiteCdKeyKind(const ResultText: String): Integer;
var
  N: Integer;
begin
  N := StrToIntDef(Trim(ResultText), -1);
  if N = 0 then
    Result := SuiteCdKeyRegistered
  else if N > 0 then
    Result := SuiteCdKeyNotRegistered
  else
    Result := SuiteCdKeyUnknown;
end;

// ---- the product runner (suite_run.iss) --------------------------------------------------------

const
  // What the product runner makes of the exit code of a product setup (SuiteChildExitKind)
  SuiteChildOk = 0;                // 0
  SuiteChildNotStarted = 1;        // 1: Setup did not start, in the WP0 spike a game mutex that was held
  SuiteChildCancelled = 2;         // 2 and 5: cancelled by the user (the advanced mode shows the wizard)
  SuiteChildFatal = 3;             // 3, 4 and 6: a fatal error while preparing, installing, or Setup was killed
  SuiteChildPrecondition = 4;      // 7 and 8: the preparation found that the installation cannot go on
  SuiteChildOther = 5;             // any other exit code

  // How many old shortcut files of a product setup the suite deletes (SuiteLegacyShortcutPath)
  SuiteLegacyShortcutCount = 5;

// The product setup's AppName, the name its own shortcuts have (config_ee.iss and config_neoee.iss: MyAppName)
function SuiteProductAppName(const Product: String): String;
begin
  if CompareText(Product, SuiteProductEE) = 0 then
    Result := 'Empire Earth'
  else if CompareText(Product, SuiteProductNeoEE) = 0 then
    Result := 'NeoEE'
  else
    Result := '';
end;

// The old shortcut files that earlier standalone runs of a product setup left (contract 1.7 point 7),
// exactly these and no others: Index 1 to SuiteLegacyShortcutCount, '' for any other number or product.
// DesktopDir is {autodesktop}, GroupDir the start menu folder of the products ({autoprograms}\Empire Earth).
function SuiteLegacyShortcutPath(const Product: String; Index: Integer; const DesktopDir, GroupDir: String): String;
var
  Name: String;
begin
  Result := '';
  Name := SuiteProductAppName(Product);
  if Name = '' then
    Exit;
  case Index of
    1: Result := AddBackslash(DesktopDir) + Name + '.lnk';
    2: Result := AddBackslash(DesktopDir) + Name + ' - AoC.lnk';
    3: Result := AddBackslash(GroupDir) + Name + '.lnk';
    4: Result := AddBackslash(GroupDir) + Name + ' - AoC.lnk';
    5: Result := AddBackslash(GroupDir) + Name + ' Diagnostic.lnk';
  end;
end;

// A value for the command line of a product setup: inside quotes, without a quote character of its own
// (no Windows path has one), and a trailing backslash doubled so that it cannot escape the closing quote
function SuiteQuoteArgument(const Value: String): String;
var
  Text: String;
begin
  Text := Value;
  StringChangeEx(Text, '"', '', True);
  if (Length(Text) > 0) and (Text[Length(Text)] = '\') then
    Text := Text + '\';
  Result := '"' + Text + '"';
end;

// The language name for /LANG of a product setup: letters, digits and the underscore of the language
// names of the products (en, de, fr, pt_BR, ...); anything else is English
function SuiteLanguageArgument(const Language: String): String;
var
  I: Integer;
  C: Char;
begin
  Result := Language;
  for I := 1 to Length(Result) do
  begin
    C := Result[I];
    if not (((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '_')) then
    begin
      Result := 'en';
      Exit;
    end;
  end;
  if Result = '' then
    Result := 'en';
end;

// Removes every switch "<Switch>value" or "<Switch>"value"" (Switch like '/MERGETASKS=', compared without
// case, only at the start of Args or after a blank) with one blank from Args and returns the values, comma separated
function SuiteTakeSwitchValues(var Args: String; const Switch: String): String;
var
  Wanted, Value: String;
  Offset, P, Start, Stop, After: Integer;
begin
  Result := '';
  Wanted := LowerCase(Switch);
  Offset := 1;
  while Offset <= Length(Args) do
  begin
    P := Pos(Wanted, Copy(LowerCase(Args), Offset, Length(Args)));
    if P = 0 then
      Exit;
    P := Offset + P - 1;
    if (P > 1) and (Args[P - 1] <> ' ') then
    begin
      Offset := P + 1;
      Continue;
    end;
    Start := P + Length(Switch);
    if (Start <= Length(Args)) and (Args[Start] = '"') then
    begin
      Stop := Start + 1;
      while (Stop <= Length(Args)) and (Args[Stop] <> '"') do
        Stop := Stop + 1;
      Value := Copy(Args, Start + 1, Stop - Start - 1);
      After := Stop + 1;
    end
    else
    begin
      Stop := Start;
      while (Stop <= Length(Args)) and (Args[Stop] <> ' ') do
        Stop := Stop + 1;
      Value := Copy(Args, Start, Stop - Start);
      After := Stop;
    end;
    // the switch goes with one of its blanks, so that no double blank is left
    if P > 1 then
    begin
      Delete(Args, P - 1, After - P + 1);
      Offset := P - 1;
    end
    else
    begin
      if (After <= Length(Args)) and (Args[After] = ' ') then
        After := After + 1;
      Delete(Args, P, After - P);
      Offset := 1;
    end;
    if Value <> '' then
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + Value;
    end;
  end;
end;

// The command line of a product setup (contract 1.7 point 3).
//   default:  /SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=<Lang> /NOICONS /MERGETASKS="!desktopicon"
//             /LOG="<LogFile>", and /TYPE=full for the first installation of the product only: a repair or an
//             update passes neither /TYPE nor /DIR, so the product keeps its folder, its components and its tasks
//   advanced: /LANG /NOICONS /MERGETASKS /LOG only, the product setup shows its full wizard
// ExtraArgs (the CI pass-through /EEArgs, /NeoEEArgs) is appended last. Its /MERGETASKS is merged into ours:
// a second /MERGETASKS would leave open which of the two a product setup reads, and a lost "!neoee_cdkeys"
// would let a test run register the CD keys. A /TYPE in ExtraArgs replaces /TYPE=full.
function SuiteProductArguments(FirstInstall, Advanced: Boolean; const Lang, LogFile, ExtraArgs: String): String;
var
  Extra, Tasks, Merged: String;
begin
  Extra := Trim(ExtraArgs);
  Tasks := SuiteTakeSwitchValues(Extra, '/MERGETASKS=');
  Extra := Trim(Extra);
  Merged := '!desktopicon';
  if Tasks <> '' then
    Merged := Merged + ',' + Tasks;
  if Advanced then
    Result := '/LANG=' + SuiteLanguageArgument(Lang) + ' /NOICONS'
  else
    Result := '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=' + SuiteLanguageArgument(Lang) + ' /NOICONS';
  Result := Result + ' /MERGETASKS=' + SuiteQuoteArgument(Merged) + ' /LOG=' + SuiteQuoteArgument(LogFile);
  if FirstInstall and not Advanced and (Pos('/type=', LowerCase(Extra)) = 0) then
    Result := Result + ' /TYPE=full';
  if Extra <> '' then
    Result := Result + ' ' + Extra;
end;

// True if the product has no uninstall entry yet, so its setup is a first installation
function SuiteIsFirstInstall(State: Integer): Boolean;
begin
  Result := State = SuiteStateNone;
end;

// The file name of the log of a product setup: <Product>-<Stamp>.log (Stamp: yyyyMMdd-HHmm)
function SuiteChildLogName(const Product, Stamp: String): String;
begin
  Result := Product + '-' + Stamp + '.log';
end;

// What an exit code of a product setup means (Inno Setup's documented codes): 0 success, 1 Setup failed to
// initialize (the game mutex of the product setup), 2 and 5 cancelled, 3, 4 and 6 fatal error or killed,
// 7 and 8 the installation cannot go on; anything else is another failure (e.g. a crash)
function SuiteChildExitKind(ExitCode: Integer): Integer;
begin
  case ExitCode of
    0: Result := SuiteChildOk;
    1: Result := SuiteChildNotStarted;
    2, 5: Result := SuiteChildCancelled;
    3, 4, 6: Result := SuiteChildFatal;
    7, 8: Result := SuiteChildPrecondition;
  else
    Result := SuiteChildOther;
  end;
end;

// A product succeeded if its setup was started and ended with exit code 0 AND its uninstall entry is
// there (contract 1.7 point 5)
function SuiteRunSucceeded(Started: Boolean; ExitCode: Integer; UninstallEntryPresent: Boolean): Boolean;
begin
  Result := Started and (ExitCode = 0) and UninstallEntryPresent;
end;

// True if an extracted product setup is the one the build recorded: same size and same SHA-256 (hex digits,
// compared without case). An empty hash never matches.
function SuitePinMatches(const ActualHash, ExpectedHash: String; const ActualSize, ExpectedSize: Int64): Boolean;
begin
  Result := (ExpectedHash <> '') and (CompareText(Trim(ActualHash), Trim(ExpectedHash)) = 0) and (ActualSize = ExpectedSize);
end;

// The number of the last line "CD Keys generation result: <n>" in the text of a product's log (setup_is6.iss
// logs it, contract 1.7 point 5); '' if there is none. Tolerant: any prefix on the line (the time stamp), upper
// and lower case, blanks after the colon, text after the number; a line without a number is ignored. Only reads.
function SuiteParseCdKeyResult(const LogText: String): String;
var
  Lower, Number: String;
  Marker: String;
  Start, P, I: Integer;
begin
  Result := '';
  Marker := 'cd keys generation result:';
  Lower := LowerCase(LogText);
  Start := 1;
  while Start <= Length(Lower) do
  begin
    P := Pos(Marker, Copy(Lower, Start, Length(Lower)));
    if P = 0 then
      Exit;
    I := Start + P - 1 + Length(Marker);
    Start := I;
    while (I <= Length(Lower)) and ((Lower[I] = ' ') or (Lower[I] = #9)) do
      I := I + 1;
    Number := '';
    if (I <= Length(Lower)) and (Lower[I] = '-') then
    begin
      Number := '-';
      I := I + 1;
    end;
    while (I <= Length(Lower)) and (Lower[I] >= '0') and (Lower[I] <= '9') and (Length(Number) < 9) do
    begin
      Number := Number + Lower[I];
      I := I + 1;
    end;
    if (Number <> '') and (Number <> '-') then
      Result := Number;
  end;
end;

// ---- the uninstaller (suite_uninstall.iss) -------------------------------------------------------

const
  // How long the suite waits for a product uninstaller: its first process only starts a copy of itself in
  // %TEMP% and ends (WP0 spike, ADR 0013 Evidence), so the suite polls the uninstall key and the program
  // file. A game of several GB takes minutes on a slow disk, hence 10 minutes for both: Inno Setup removes
  // the uninstall key early and the program file only at the very end, after all the game files, so the
  // suite waits for the file as long as for the key.
  SuiteUninstallTimeoutMs = 600000;
  SuiteUninstallPollMs = 1000;
  // SuiteUninstallWaitState
  SuiteWaitKeep = 0;               // keep polling
  SuiteWaitDone = 1;               // the uninstall key and the program file are gone
  SuiteWaitDoneExeLeft = 2;        // the uninstall key is gone, the program file is still there after the timeout: done, with a log line
  SuiteWaitTimedOut = 3;           // the uninstall key is still there after the timeout
  // SuiteUninstallOutcome
  SuiteRemoveOk = 0;
  SuiteRemoveGone = 1;             // not installed any more (removed through its own Apps entry): skipped silently
  SuiteRemoveNotStarted = 2;       // the uninstaller of the product could not be started (or is no uninstaller)
  SuiteRemoveTimedOut = 3;         // it did not finish in time
  // The exact folders below a product root and below the launcher's data folder (see SuiteDataFolder, ...)
  SuiteDataFolderCount = 4;
  SuiteEmptyFolderCount = 5;
  SuiteLauncherFileCount = 2;
  SuiteLauncherFolderCount = 2;
  SuiteGameFolder = 'Empire Earth';
  SuiteAoCFolder = 'Empire Earth - The Art of Conquest';

// What to do after one look at a product uninstaller: KeyPresent = the uninstall key {<AppId>}_is1 exists,
// ExeExists = its unins000.exe exists, ElapsedMs = time since Exec returned. Done means the key and the
// file are gone; until the timeout the suite keeps waiting while either is there (the next product
// uninstaller or the question about the data folders must not start while the first still deletes). The
// exit code of the first process is no input: it ends before the real uninstall does.
function SuiteUninstallWaitState(KeyPresent, ExeExists: Boolean; ElapsedMs: Integer): Integer;
begin
  if KeyPresent then
  begin
    if ElapsedMs >= SuiteUninstallTimeoutMs then
      Result := SuiteWaitTimedOut
    else
      Result := SuiteWaitKeep;
  end
  else if not ExeExists then
    Result := SuiteWaitDone
  else if ElapsedMs >= SuiteUninstallTimeoutMs then
    Result := SuiteWaitDoneExeLeft
  else
    Result := SuiteWaitKeep;
end;

// The outcome of the removal of one product: Started = Exec started the uninstaller, WaitState = the last
// SuiteUninstallWaitState
function SuiteUninstallOutcome(Started: Boolean; WaitState: Integer): Integer;
begin
  if not Started then
    Result := SuiteRemoveNotStarted
  else if (WaitState = SuiteWaitDone) or (WaitState = SuiteWaitDoneExeLeft) then
    Result := SuiteRemoveOk
  else
    Result := SuiteRemoveTimedOut;
end;

// The product the Index-th removal handles (1, 2): NeoEE before EE, the reverse of the installation; '' otherwise
function SuiteUninstallProduct(Index: Integer): String;
begin
  case Index of
    1: Result := SuiteProductNeoEE;
    2: Result := SuiteProductEE;
  else
    Result := '';
  end;
end;

// The program file of an uninstall entry: the value UninstallString is the path of unins000.exe in quotes
// (Inno Setup writes it so); without quotes the whole text counts. '' for an empty value.
function SuiteUninstallExe(const UninstallString: String): String;
var
  S: String;
  P: Integer;
begin
  S := Trim(UninstallString);
  if (S <> '') and (S[1] = '"') then
  begin
    Delete(S, 1, 1);
    P := Pos('"', S);
    if P > 0 then
      S := Copy(S, 1, P - 1);
  end;
  Result := Trim(S);
end;

// True if Exe is an uninstaller of Inno Setup (unins*.exe) inside the install root of the product: the suite
// runs nothing else from the registry value of an uninstall entry.
function SuiteIsProductUninstaller(const Exe, Root: String): Boolean;
var
  Name: String;
begin
  Name := LowerCase(ExtractFileName(Exe));
  Result := SuiteIsSameOrInside(Exe, Root) and (Pos('..', Exe) = 0) and (Copy(Name, 1, 5) = 'unins') and (Copy(Name, Length(Name) - 3, 4) = '.exe');
end;

// True if Path is a junction, a symbolic link or another reparse point (FILE_ATTRIBUTE_REPARSE_POINT of
// FindFirst); False if it does not exist
function SuiteIsReparsePoint(const Path: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(RemoveBackslash(Path), FindRec) then
  try
    Result := (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
  finally
    FindClose(FindRec);
  end;
end;

// True if Folder or a folder above it, up to and including Root, is a reparse point: DelTree skips links
// inside a folder but follows a link that is the folder itself or one of its parents (a saved games
// folder redirected to Documents or OneDrive would lose the content of its target). The same protection
// the product setups have (IsLinkGuardedFolder, ADR 0009). A Folder outside Root is checked up to its drive.
function SuiteIsBehindLink(const Folder, Root: String): Boolean;
var
  P, Parent: String;
  Last: Boolean;
begin
  Result := False;
  P := RemoveBackslash(Trim(Folder));
  Last := False;
  while (Length(P) > 3) and not Last do
  begin
    if SuiteIsReparsePoint(P) then
    begin
      Result := True;
      Exit;
    end;
    Last := SuiteNormalizedPath(P) = SuiteNormalizedPath(Root);
    Parent := RemoveBackslash(ExtractFileDir(P));
    if Length(Parent) >= Length(P) then
      Exit;
    P := Parent;
  end;
end;

// True if the content of a shortcut file (.lnk, read as a text without its NUL characters, so the
// path is found in its ANSI and in its Unicode form) names the file FileName. A heuristic that needs no COM
// call: the uninstaller removes a game shortcut of a product that stays installed only if it starts the launcher.
function SuiteLinkTextNamesFile(const Content, FileName: String): Boolean;
var
  Nul, Text: String;
begin
  Nul := #0;
  Text := Content;
  StringChangeEx(Text, Nul, '', True);
  Result := (FileName <> '') and (Pos(UpperCase(FileName), UpperCase(Text)) > 0);
end;

// A folder the uninstaller may work below: a full path with a drive, at least one folder deep, without ".."
function SuiteIsUsableRoot(const Root: String): Boolean;
var
  R: String;
begin
  R := SuiteNormalizedPath(Root);
  Result := (Length(R) > 3) and (R[2] = ':') and (R[3] = '\') and (Pos('..', R) = 0);
end;

// The folders of the user data of a product: the profiles (Users) and the saved games of Empire Earth and of
// The Art of Conquest. Index 1 to SuiteDataFolderCount; '' for another index or an unusable root. The
// uninstaller deletes these folders (with their content) only after the explicit answer "Delete", never more.
function SuiteDataFolder(const Root: String; Index: Integer): String;
var
  R: String;
begin
  Result := '';
  if not SuiteIsUsableRoot(Root) then
    Exit;
  R := RemoveBackslash(Trim(Root));
  case Index of
    1: Result := R + '\' + SuiteGameFolder + '\Users';
    2: Result := R + '\' + SuiteGameFolder + '\Data\Saved Games';
    3: Result := R + '\' + SuiteAoCFolder + '\Users';
    4: Result := R + '\' + SuiteAoCFolder + '\Data\Saved Games';
  end;
end;

// The folders that the uninstaller removes with RemoveDir (which never removes a folder with content) after
// the product is gone, from the inside out: Data and the game folder of Empire Earth and of The Art of
// Conquest, then the install root. Index 1 to SuiteEmptyFolderCount; '' otherwise.
function SuiteEmptyFolder(const Root: String; Index: Integer): String;
var
  R: String;
begin
  Result := '';
  if not SuiteIsUsableRoot(Root) then
    Exit;
  R := RemoveBackslash(Trim(Root));
  case Index of
    1: Result := R + '\' + SuiteGameFolder + '\Data';
    2: Result := R + '\' + SuiteGameFolder;
    3: Result := R + '\' + SuiteAoCFolder + '\Data';
    4: Result := R + '\' + SuiteAoCFolder;
    5: Result := R;
  end;
end;

// The data folder of the launcher below the local application data folder of the account that uninstalls
function SuiteLauncherDataDir(const LocalAppData: String): String;
begin
  if SuiteIsUsableRoot(LocalAppData) then
    Result := RemoveBackslash(Trim(LocalAppData)) + '\Empire Earth Launcher'
  else
    Result := '';
end;

// The files of the launcher's data folder that the uninstaller always deletes: its settings and its log
function SuiteLauncherDataFile(const LocalAppData: String; Index: Integer): String;
begin
  Result := SuiteLauncherDataDir(LocalAppData);
  if Result <> '' then
    case Index of
      1: Result := Result + '\settings.json';
      2: Result := Result + '\log.txt';
    else
      Result := '';
    end;
end;

// The sub-folders of the launcher's data folder that the uninstaller deletes only after the answer "Delete":
// the backups of the registry and of files, and the packages of the Mod Creator
function SuiteLauncherDataFolder(const LocalAppData: String; Index: Integer): String;
begin
  Result := SuiteLauncherDataDir(LocalAppData);
  if Result <> '' then
    case Index of
      1: Result := Result + '\Backups';
      2: Result := Result + '\Mod Creator';
    else
      Result := '';
    end;
end;
