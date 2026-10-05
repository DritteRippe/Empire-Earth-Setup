[Code]
// Pure helpers of the suite installer (suite.iss, ADR 0013): they compute something from their
// arguments and touch no wizard page, so ci/tests/suite_tests.iss tests them (run by
// ci/tests/unit_tests.iss). Only SuiteFindSliceProblems reads the file system (file sizes); the
// tests give it files of their own temporary folder.
// Requires: nothing (no define, no other script). Included before every other [Code] part of the suite.

const
  // Exit codes of the suite when one of its own prechecks stops it, in InitializeSetup and before the
  // first product setup runs. Inno Setup's own codes 0 to 8 keep their meaning; 3 is a damaged slice
  // ("The source file is corrupted", proven by the WP0 spike, ADR 0013 Evidence), 5 a cancelled
  // wizard, 7 a PrepareToInstall message in a silent run. Every code comes with a log line and, unless
  // the run is silent, a message. docs/TEST-PLAN.de.md and the README name them.
  SuiteExitSilentArguments = 10;   // silent run without a valid /PRODUCTS or without the decision on neoee_cdkeys
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

// Item Index (1 is the first) of a comma separated list of sizes; -1 if there is no such item or it
// is not a number (a size is never negative)
function SuiteListedSize(const List: String; Index: Integer): Int64;
var
  Rest, Item: String;
  P, N: Integer;
begin
  Result := -1;
  Rest := List;
  N := 1;
  while True do
  begin
    P := Pos(',', Rest);
    if P > 0 then
      Item := Copy(Rest, 1, P - 1)
    else
      Item := Rest;
    if N = Index then
    begin
      Result := StrToInt64Def(Trim(Item), -1);
      if Result < 0 then
        Result := -1;
      Exit;
    end;
    if P = 0 then
      Exit;
    Rest := Copy(Rest, P + 1, Length(Rest));
    N := N + 1;
  end;
end;

// Compares a slice with what the build recorded: 0 = fine, 1 = missing, 2 = another size
function SuiteSliceState(Exists: Boolean; const ActualSize, ExpectedSize: Int64): Integer;
begin
  if not Exists then
    Result := 1
  else if ActualSize <> ExpectedSize then
    Result := 2
  else
    Result := 0;
end;

// The slices of the package in Dir (<BaseName>-1.bin ... -Count.bin) against the sizes the build
// recorded (Sizes: Count comma separated numbers). Returns '' if every slice is there with exactly
// its size, else one line per problem (at most MaxLines, then "... and n more"), separated by CRLF.
// Count = 0 means the build recorded no slices (first pass of the two-pass build): nothing to check.
// A list that does not have Count numbers is a build error and reported as such.
function SuiteFindSliceProblems(const Dir, BaseName, Sizes: String; Count, MaxLines: Integer): String;
var
  I, Found, State: Integer;
  Path: String;
  Expected, Actual: Int64;
  Line: String;
begin
  Result := '';
  if Count <= 0 then
    Exit;
  if SuiteListedCount(Sizes) <> Count then
  begin
    Result := 'The setup was built with ' + IntToStr(Count) + ' slices but ' + IntToStr(SuiteListedCount(Sizes)) + ' sizes (build error)';
    Exit;
  end;
  Found := 0;
  for I := 1 to Count do
  begin
    Path := AddBackslash(Dir) + SuiteSliceFileName(BaseName, I);
    Expected := SuiteListedSize(Sizes, I);
    Actual := 0;
    State := 0;
    if not FileExists(Path) then
      State := 1
    else if not FileSize64(Path, Actual) then
      State := 1
    else
      State := SuiteSliceState(True, Actual, Expected);
    if State <> 0 then
    begin
      Found := Found + 1;
      if Found <= MaxLines then
      begin
        if State = 1 then
          Line := SuiteSliceFileName(BaseName, I) + ' (missing)'
        else
          Line := SuiteSliceFileName(BaseName, I) + ' (' + IntToStr(Actual) + ' bytes, expected ' + IntToStr(Expected) + ')';
        if Result <> '' then
          Result := Result + #13#10;
        Result := Result + Line;
      end;
    end;
  end;
  if Found > MaxLines then
    Result := Result + #13#10 + '... and ' + IntToStr(Found - MaxLines) + ' more';
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
