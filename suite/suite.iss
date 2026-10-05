; Empire Earth Community, the suite installer: one setup that installs the Empire Earth Launcher and
; runs the unchanged EE and NeoEE setups (docs/adr/0013-suite-installer.md, docs/CONTRACT.md revision 4:
; "Suite and launcher", 1.6, 1.7, 4.2, 4.4). The two product setups are embedded byte for byte, so the
; package is large: the setup is disk-spanned into "Empire Earth Community Setup.exe" and
; "Empire Earth Community Setup-N.bin" slices of at most DiskSliceSize bytes (GitHub's limit is 100 MB).
;
; This file is the frame: [Setup], the payload ([Files]) and the prechecks of InitializeSetup. The
; other parts are in the files it includes (suite_common.iss: pure helpers; suite_messages.iss: texts;
; suite_shortcuts.iss, suite_record.iss: what the suite leaves besides its files). Never run a build
; of it on a machine that has the real game installed: the placeholder builds are for CI.
;
; Build (ISCC 6.2.2), every define is required unless a default is named:
;   /DSuiteAppID=<GUID>              AppId of the suite, without braces
;   /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID>
;                                    AppIds of the two product setups (the same /D the products are built with)
;   /DEESetupFile=<path> /DEESetupSHA256=<64 hex digits> /DEESetupSize=<bytes>
;   /DNeoEESetupFile=<path> /DNeoEESetupSHA256=<64 hex digits> /DNeoEESetupSize=<bytes>
;                                    the embedded product setups and the values the suite compares them with
;   /DLauncherDir=<folder>           Release output of the launcher (no .pdb): installed below {app}
;   /DModCreatorDir=<folder>         Release output of the Mod Creator: installed below {app}\Mod Creator
;   /DLicenseDir=<folder>            LICENSE, THIRD-PARTY-NOTICES.md, licenses\, Quellcode.txt: {app}\Lizenzen
;   /DSliceCount=<n> /DSliceSizes=<n1,n2,...>
;                                    number and exact sizes of the slices of a build of this script: the
;                                    suite checks them before it extracts anything (two-pass build, see below)
;   /DSlicePass1=1                   instead of the two /D above in the first pass of the two-pass build
;   /DSliceSize=<bytes>              DiskSliceSize (default 50000000); at least the size of the setup program
;   /DEEInstallSize=<bytes> /DNeoEEInstallSize=<bytes>
;                                    free space the installed product needs (default: twice the setup size)
;   /DTestID=<n>                     0 = release build (default), > 0 = test build
; Two-pass build: slice sizes and count are only known after a build, and they are compiled into the
; setup, so the build runs ISCC with /DSlicePass1=1, reads the slices, and runs it again with their
; sizes (repeating until the sizes no longer change, as the list is part of the setup program). Without
; the list a setup would start from a half package and ask for a disk (the WP0 spike: it hangs, even silent).
;
; Files are UTF-8 with BOM and CRLF (.editorconfig). The shortcuts and the suite record are created in
; code at ssPostInstall and removed by the uninstaller (ADR 0013 Evidence), not by [Icons] and [Registry].

#define SuiteName "Empire Earth Community"
#define SuiteVersion "1.0.0"
#define SuiteOutputName "Empire Earth Community Setup"
#define SuiteRecordKey "Software\Empire Earth Community\Suite"
#define LauncherExe "Empire Earth Launcher.exe"
; the version of docs/CONTRACT.md this script implements (the suite record carries it, contract 1.6)
#define ContractVersion 1
; contract 0 "Suite and launcher": the game mutexes and the launcher mutex (a running game or launcher stops the suite)
#define SuiteAppMutex "StainlessSteelStudiosPresentsEmpireEarth,MadDocSoftwarePresentsEmpireEarthExpansion,EmpireEarthCommunityLauncher"

; ---- build settings ---------------------------------------------------------------------------

; S without the characters of Chars (case-sensitive)
#define StripChars(str S, str Chars) Chars == "" ? S : StripChars(StringChange(S, Copy(Chars, 1, 1), ""), Copy(Chars, 2))
; A plain GUID: removing every hex digit leaves the four dashes (as setup_is6.iss checks the AppIds)
#define IsPlainGuid(str S) Len(S) == 36 && Copy(S, 9, 1) == "-" && Copy(S, 14, 1) == "-" && Copy(S, 19, 1) == "-" && Copy(S, 24, 1) == "-" && StripChars(LowerCase(S), "0123456789abcdef") == "----"
#define IsSha256(str S) Len(S) == 64 && StripChars(LowerCase(S), "0123456789abcdef") == ""

#ifndef SuiteAppID
  #define SuiteAppID ""
#endif
#ifndef EE_AppID
  #define EE_AppID ""
#endif
#ifndef NeoEE_AppID
  #define NeoEE_AppID ""
#endif
; The AppIds are empty in the repository: every build provides them (the real ones only the local
; real-data tooling, never a commit; CI uses dummy GUIDs)
#if SuiteAppID == "" || EE_AppID == "" || NeoEE_AppID == ""
  #error SuiteAppID, EE_AppID and NeoEE_AppID must be set: pass ISCC /DSuiteAppID=<GUID> /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID>
#endif
#if !IsPlainGuid(SuiteAppID)
  #pragma error "SuiteAppID '" + SuiteAppID + "' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
#endif
#if !IsPlainGuid(EE_AppID)
  #pragma error "EE_AppID '" + EE_AppID + "' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
#endif
#if !IsPlainGuid(NeoEE_AppID)
  #pragma error "NeoEE_AppID '" + NeoEE_AppID + "' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
#endif
#if EE_AppID == NeoEE_AppID || SuiteAppID == EE_AppID || SuiteAppID == NeoEE_AppID
  #error SuiteAppID, EE_AppID and NeoEE_AppID must differ: the suite and each product need an uninstall key of their own
#endif

; The embedded product setups: file, SHA-256 and size, which the suite compares with the extracted file
; before it runs anything (the build script computes them from the files; the pins are compiled in)
#ifndef EESetupFile
  #define EESetupFile ""
#endif
#ifndef NeoEESetupFile
  #define NeoEESetupFile ""
#endif
#ifndef EESetupSHA256
  #define EESetupSHA256 ""
#endif
#ifndef NeoEESetupSHA256
  #define NeoEESetupSHA256 ""
#endif
#ifndef EESetupSize
  #define EESetupSize ""
#endif
#ifndef NeoEESetupSize
  #define NeoEESetupSize ""
#endif
#if EESetupFile == "" || NeoEESetupFile == ""
  #error EESetupFile and NeoEESetupFile must be set: the product setups the suite embeds
#endif
#if !IsSha256(EESetupSHA256) || !IsSha256(NeoEESetupSHA256)
  #error EESetupSHA256 and NeoEESetupSHA256 must be 64 hex digits (the SHA-256 of the product setups)
#endif
; ISCC /D passes strings: convert the sizes (an invalid value becomes -1 and is rejected)
#if TypeOf(EESetupSize) != TYPE_INTEGER
  #define EESetupSize Int(EESetupSize, -1)
#endif
#if TypeOf(NeoEESetupSize) != TYPE_INTEGER
  #define NeoEESetupSize Int(NeoEESetupSize, -1)
#endif
#if EESetupSize <= 0 || NeoEESetupSize <= 0
  #error EESetupSize and NeoEESetupSize must be the sizes in bytes of the product setups (positive numbers)
#endif
; Free space the installed products need (default twice the setup: its data is compressed)
#ifndef EEInstallSize
  #define EEInstallSize 2 * EESetupSize
#endif
#ifndef NeoEEInstallSize
  #define NeoEEInstallSize 2 * NeoEESetupSize
#endif
#if TypeOf(EEInstallSize) != TYPE_INTEGER
  #define EEInstallSize Int(EEInstallSize, -1)
#endif
#if TypeOf(NeoEEInstallSize) != TYPE_INTEGER
  #define NeoEEInstallSize Int(NeoEEInstallSize, -1)
#endif
#if EEInstallSize <= 0 || NeoEEInstallSize <= 0
  #error EEInstallSize and NeoEEInstallSize must be positive numbers of bytes
#endif

; The files of the launcher, of the Mod Creator and of the licenses
#ifndef LauncherDir
  #define LauncherDir ""
#endif
#ifndef ModCreatorDir
  #define ModCreatorDir ""
#endif
#ifndef LicenseDir
  #define LicenseDir ""
#endif
#if LauncherDir == "" || ModCreatorDir == "" || LicenseDir == ""
  #error LauncherDir, ModCreatorDir and LicenseDir must be set: the folders with the launcher, the Mod Creator and the licenses
#endif

; Disk spanning: the size of a slice and the slices of the build (two-pass build, see the header)
#ifndef SliceSize
  #define SliceSize 50000000
#endif
#if TypeOf(SliceSize) != TYPE_INTEGER
  #define SliceSize Int(SliceSize, -1)
#endif
#if SliceSize <= 0
  #error SliceSize must be a positive number of bytes
#endif
#ifndef SlicePass1
  #define SlicePass1 0
#endif
#if TypeOf(SlicePass1) != TYPE_INTEGER
  #define SlicePass1 Int(SlicePass1, 0)
#endif
#if SlicePass1
  ; first pass: no slices known yet, the check of the slices stays off in this build
  #define SliceCount 0
  #define SliceSizes ""
#else
  #ifndef SliceCount
    #define SliceCount -1
  #endif
  #ifndef SliceSizes
    #define SliceSizes ""
  #endif
  #if TypeOf(SliceCount) != TYPE_INTEGER
    #define SliceCount Int(SliceCount, -1)
  #endif
  #if SliceCount <= 0
    #error SliceCount and SliceSizes must name the slices of an earlier build of this script (the second pass of the build); the first pass passes /DSlicePass1=1
  #endif
  #if StripChars(SliceSizes, "0123456789,") != "" || Len(SliceSizes) - Len(StringChange(SliceSizes, ",", "")) + 1 != SliceCount
    #pragma error "SliceSizes '" + SliceSizes + "' is not a list of " + Str(SliceCount) + " numbers separated by commas"
  #endif
#endif

; TestID (0 if release)
#ifndef TestID
  #define TestID 0
#endif
#if TypeOf(TestID) != TYPE_INTEGER
  #define TestID Int(TestID, -1)
#endif
#if TestID < 0
  #error TestID must be a non-negative integer (0 = release build)
#endif

; ---- the setup program --------------------------------------------------------------------------

[Setup]
AppId={{{#SuiteAppID}}
AppName={#SuiteName}
AppVersion={#SuiteVersion}
AppVerName={#SuiteName} {#SuiteVersion}
AppPublisher={#SuiteName}
AppPublisherURL=https://empireearth.eu/
AppSupportURL=https://empireearth.eu/
AppUpdatesURL=https://empireearth.eu/
VersionInfoVersion={#SuiteVersion}.0
VersionInfoProductVersion={#SuiteVersion}
VersionInfoCopyright={#SuiteName}
UninstallDisplayName=Empire Earth Community (Launcher, EE, NeoEE)
UninstallDisplayIcon={app}\{#LauncherExe}
; The suite is installed for all users, in the 64-bit mode like the products (its HKLM entries are in
; the 64-bit view, contract 1.6); a per-user or portable installation does not exist (contract 0)
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesInstallIn64BitMode=x64 arm64
; The same Windows range as the products and the launcher: Windows 7 SP1 to 11 (Inno Setup 6 setups need 6.1sp1)
MinVersion=6.1sp1
DefaultDirName={autopf}\{#SuiteName}
UsePreviousAppDir=yes
DefaultGroupName={#SuiteName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableWelcomePage=yes
; Disk spanning: slices of at most DiskSliceSize bytes next to the setup program, which the suite checks
; itself (InitializeSetup). DiskSliceSize must be at least the size of the setup program (the first
; slice also holds it; ISCC refuses less, ADR 0013 Evidence).
DiskSpanning=yes
DiskSliceSize={#SliceSize}
Compression=lzma2/max
SolidCompression=no
OutputDir=..\out\Suite
OutputBaseFilename={#SuiteOutputName}
; One suite at a time, and not while a game or the launcher runs (contract 0 "Suite and launcher", 4.2)
SetupMutex=EmpireEarthCommunity_Suite
AppMutex={#SuiteAppMutex}
CloseApplications=no
SetupLogging=yes
ShowLanguageDialog=no
WizardStyle=modern

; English first: the language of a Windows that is neither English, German nor French
[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\german.isl"
Name: "fr"; MessagesFile: "compiler:Languages\french.isl"

#include "suite_messages.iss"

; ---- the payload --------------------------------------------------------------------------------

[Files]
; The launcher, the Mod Creator and the license texts need .NET Framework 4.8: without it only the games
; are installed, and the game shortcuts start the game programs (contract 1.7 point 8). They lie outside
; both product roots, so no integrity manifest lists them (contract 2.3 unchanged).
Source: "{#LauncherDir}\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsDotNet48
Source: "{#ModCreatorDir}\*"; DestDir: "{app}\Mod Creator"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsDotNet48
Source: "{#LicenseDir}\*"; DestDir: "{app}\Lizenzen"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsDotNet48
; The product setups, byte for byte: extracted to {tmp} by the product runner when it runs them, never
; installed. nocompression: they are compressed already (lzma2) and the build must not touch their bytes.
Source: "{#EESetupFile}"; DestName: "EE_Setup.exe"; Flags: dontcopy nocompression
Source: "{#NeoEESetupFile}"; DestName: "NeoEE_Setup.exe"; Flags: dontcopy nocompression

#include "suite_common.iss"

[Code]
// The suite's main script: the globals, the prechecks of InitializeSetup and the steps in which the
// other parts take part. Requires: suite_common.iss (helpers, SuiteExit* codes), the messages of
// suite_messages.iss, the defines of the header.

const
  // The pins of the embedded product setups (compared with the extracted files before a product runs)
  SuiteEEFile = 'EE_Setup.exe';
  SuiteNeoEEFile = 'NeoEE_Setup.exe';
  SuiteEESHA256 = '{#EESetupSHA256}';
  SuiteNeoEESHA256 = '{#NeoEESetupSHA256}';
  SuiteEESize = {#EESetupSize};
  SuiteNeoEESize = {#NeoEESetupSize};
  // Free space the installed products need (bytes), and what the launcher with the Mod Creator needs
  SuiteEEInstallBytes = {#EEInstallSize};
  SuiteNeoEEInstallBytes = {#NeoEEInstallSize};
  SuiteLauncherBytes = 33554432;
  // AppIds of the product setups without braces (the suite record names them, contract 1.6)
  SuiteEEAppId = '{#EE_AppID}';
  SuiteNeoEEAppId = '{#NeoEE_AppID}';
  // The slices of this build: base name, number and sizes (SuiteFindSliceProblems)
  SuiteSetupBaseName = '{#SuiteOutputName}';
  SuiteSliceCount = {#SliceCount};
  SuiteSliceSizes = '{#SliceSizes}';
  // The game and launcher mutexes, as AppMutex (InitializeSetup checks them first, to exit with a code)
  SuiteMutexes = '{#SuiteAppMutex}';
  // 0 = release build
  SuiteTestID = {#TestID};

var
  // The product ids whose setup succeeded in this run, comma separated (EE before NeoEE): set by the
  // product runner, read by the shortcuts and the suite record (WP5)
  SuiteProductsOk: String;
  // The products the user selected; both until the wizard pages let the user choose (WP4)
  SuiteWantEE, SuiteWantNeoEE: Boolean;

procedure ExitProcess(ExitCode: Cardinal);
  external 'ExitProcess@kernel32.dll stdcall';

function SuiteHasParam(const Param: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Param) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

// A silent run (/SILENT or /VERYSILENT) shows no message and answers no question
function SuiteSilent: Boolean;
begin
  Result := WizardSilent or SuiteHasParam('/VERYSILENT');
end;

// .NET Framework 4.8 or later (HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full, Release): Check
// of the launcher files and of the shortcuts to the launcher. HKLM is the 64-bit view in 64-bit install mode.
function IsDotNet48: Boolean;
var
  Release: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release)
    and SuiteIsDotNet48Release(Release);
end;

// True if the product's setup ended with success in this run
function SuiteProductSucceeded(const Product: String): Boolean;
begin
  Result := SuiteListHasItem(SuiteProductsOk, Product);
end;

// Stops the suite with one of the exit codes SuiteExit* of suite_common.iss: the reason in the log,
// the text for the user in a message (never in a silent run, and SuppressibleMsgBox answers nothing
// with /SUPPRESSMSGBOXES), then the exit code. Inno Setup has no way to end with another code than its
// own, so this uses ExitProcess; the folder Setup extracted into %TEMP% stays (no program of the
// package was started, nothing was installed). Only SuppressibleMsgBox is used (ci/check_messages.py).
procedure SuiteStop(ExitCode: Integer; const LogText, UserText: String);
begin
  Log('Precheck failed, exit code ' + IntToStr(ExitCode) + ': ' + LogText);
  if (UserText <> '') and not SuiteSilent then
    SuppressibleMsgBox(UserText, mbCriticalError, MB_OK, IDOK);
  ExitProcess(ExitCode);
end;

#include "suite_shortcuts.iss"
#include "suite_record.iss"

// The prechecks, before anything is extracted or installed; the first problem stops the suite
// with its exit code. All of them are read-only. The order: arguments of a silent run, the slices of
// the package (and the ZIP view as the likely reason when they are missing), the running programs,
// the free space.
function InitializeSetup(): Boolean;
var
  Src, TempRoot, Problems, Drive: String;
  TempFree, TargetFree, Total: Int64;
  TempNeeded, TargetNeeded: Int64;
  Target: String;
  Problem: Integer;
begin
  Result := True;
  Src := RemoveBackslash(ExpandConstant('{src}'));
  TempRoot := ExtractFileDir(ExpandConstant('{tmp}'));
  SuiteProductsOk := '';
  SuiteWantEE := True;
  SuiteWantNeoEE := True;
  Log('Suite {#SuiteVersion} (contract {#ContractVersion}, test build ' + IntToStr(SuiteTestID) + '), started from ' + Src +
    ', temporary folder ' + TempRoot + ', silent ' + IntToStr(Ord(SuiteSilent)));

  // 1. A silent run names its products and decides about the CD key registration of NeoEE (exit code 10)
  if SuiteSilent then
  begin
    Problem := SuiteSilentArgumentsProblem(ExpandConstant('{param:PRODUCTS|}'), ExpandConstant('{param:NeoEEArgs|}'));
    if Problem = 1 then
      SuiteStop(SuiteExitSilentArguments, 'silent run without /PRODUCTS=EE, /PRODUCTS=NeoEE or /PRODUCTS=EE,NeoEE', '')
    else if Problem = 2 then
      SuiteStop(SuiteExitSilentArguments, 'silent run with NeoEE but /NeoEEArgs does not decide about neoee_cdkeys ' +
        '(name neoee_cdkeys in /TASKS or /MERGETASKS, "!neoee_cdkeys" for no registration)', '');
  end;

  // 2. Every slice next to the setup, with its exact size (exit code 11, or 12 if it looks like the ZIP view)
  Problems := SuiteFindSliceProblems(Src, SuiteSetupBaseName, SuiteSliceSizes, SuiteSliceCount, 6);
  if SuiteSliceCount <= 0 then
    Log('Slices: none recorded in this build (first pass of the two-pass build), not checked')
  else if Problems = '' then
    Log('Slices: ' + IntToStr(SuiteSliceCount) + ' checked, all present with their sizes')
  else if SuiteIsZipViewPath(Src, TempRoot) then
    SuiteStop(SuiteExitZipView, 'started from the ZIP view or a temporary folder, slices missing or wrong: ' + Problems,
      FmtMessage(CustomMessage('SuiteZipView'), [Problems]))
  else
    SuiteStop(SuiteExitSlices, 'slices missing or wrong: ' + Problems,
      FmtMessage(CustomMessage('SuiteSlicesMissing'), [Problems]));

  // 3. No game and no launcher running (exit code 14); Inno Setup's AppMutex check would only ask
  if CheckForMutexes(SuiteMutexes) then
    SuiteStop(SuiteExitRunning, 'a game or the launcher is running (mutex of ' + SuiteMutexes + ')', CustomMessage('SuiteRunning'));

  // 4. Free space for the extraction (drive of %TEMP%) and the installation (drive of the program
  // files folder of the products), exit code 13
  Target := ExpandConstant('{autopf32}');
  TempNeeded := SuiteRequiredTempBytes(SuiteEESize, SuiteNeoEESize, SuiteWantEE, SuiteWantNeoEE);
  TargetNeeded := SuiteRequiredTargetBytes(SuiteEEInstallBytes, SuiteNeoEEInstallBytes, SuiteLauncherBytes, SuiteWantEE, SuiteWantNeoEE);
  if GetSpaceOnDisk64(TempRoot, TempFree, Total) and GetSpaceOnDisk64(Target, TargetFree, Total) then
  begin
    Problem := SuiteSpaceProblem(TempFree, TempNeeded, TargetFree, TargetNeeded, SuiteDriveOf(TempRoot) = SuiteDriveOf(Target));
    Log('Free space: ' + SuiteFormatMegabytes(TempFree) + ' on ' + SuiteDriveOf(TempRoot) + ' (temporary files, ' +
      SuiteFormatMegabytes(TempNeeded) + ' needed), ' + SuiteFormatMegabytes(TargetFree) + ' on ' + SuiteDriveOf(Target) +
      ' (installation, ' + SuiteFormatMegabytes(TargetNeeded) + ' needed), problem ' + IntToStr(Problem));
    if Problem = 1 then
      SuiteStop(SuiteExitDiskSpace, 'not enough free space for the temporary files',
        FmtMessage(CustomMessage('SuiteNotEnoughSpace'), [SuiteDriveOf(TempRoot), SuiteFormatMegabytes(TempNeeded), SuiteFormatMegabytes(TempFree)]))
    else if Problem = 2 then
    begin
      Drive := SuiteDriveOf(Target);
      if SuiteDriveOf(TempRoot) = Drive then
        TargetNeeded := TargetNeeded + TempNeeded;
      SuiteStop(SuiteExitDiskSpace, 'not enough free space for the installation',
        FmtMessage(CustomMessage('SuiteNotEnoughSpace'), [Drive, SuiteFormatMegabytes(TargetNeeded), SuiteFormatMegabytes(TargetFree)]));
    end;
  end
  else
    Log('Free space: not readable, not checked');

  // 5. Without .NET Framework 4.8 the games are installed and the shortcuts start them directly
  if IsDotNet48 then
    Log('.NET Framework 4.8 or later: found, the launcher is installed')
  else
    Log('.NET Framework 4.8 or later: not found, the launcher is not installed and the game shortcuts start the game programs');
end;

// The steps of the installation. The product runner runs the selected product setups at ssInstall
// (WP5); the shortcuts and the suite record are written after everything else, at ssPostInstall, in
// code: the Check functions of [Icons] and [Registry] did not reliably see what ssInstall had set
// (ADR 0013 Evidence), and the uninstaller removes them explicitly.
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ApplySuiteShortcuts(False);
    WriteSuiteRecord;
  end;
end;

// The uninstaller removes what the suite created in code (they are not in its uninstall log). The
// product uninstallers, the data folders and the questions are WP6.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    ApplySuiteShortcuts(True);
    RemoveSuiteRecord;
  end;
end;
