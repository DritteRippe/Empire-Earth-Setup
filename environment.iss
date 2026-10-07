[Code]
// Read-only checks before the installation (docs/adr/0007-environment-warnings.md and, for the link
// check, docs/adr/0009-no-installation-through-links.md). They never write, delete or move
// anything. Only the link check can stop the installation; the others never block a silent
// installation: in silent mode and with /SUPPRESSMSGBOXES they only log.
//
//  - InitializeSetup, always (LogScreenMetrics): the size of the primary screen, its DPI with the
//    display scaling it means, and the game window the setup writes ([Registry] Game Window Width
//    and Height, contract 3.3) go into the log, so that a support case and contract O4 can be
//    decided from the setup log.
//  - InitializeSetup, after the install-mode question (ShowLowScreenResolutionNotice): a notice if
//    the primary screen is lower than 768 pixels (R13; t=3863 p=26167: netbooks with 1024 x 600
//    crash after the intro). The clamp of the window size stays.
//  - Folder page, Next (CheckSelectedFolder, called by NextButtonClick(wpSelectDir)):
//    1. Once per run (CheckForeignInstallations): foreign or old installations (R12; report 4.5,
//       4.7, 4.8): the game settings keys of the retail game, GOG and old NeoEE installers in both
//       views of HKLM (the community setups write them only in HKCU) with the folder of their
//       "Installed From" values, the default folders of the retail CD, and the uninstall entries of
//       HKLM (both views) that name Empire Earth or NeoEE and are not those of the community setups
//       (IsForeignUninstallEntry). Everything found is logged and named in one notice,
//       ForeignInstallFound, which advises against deleting registry keys by hand (K15).
//    2. The chosen folder is, contains or lies in the folder of such an installation: question
//       ForeignFolderQuestion, "Yes" (the default) stays on the folder page.
//    3. The chosen folder holds the other community product (EE <-> NeoEE; contract O11): question
//       SharedFolderQuestion, "Yes" (the default) stays on the folder page.
//    Inno Setup skips the folder page on an update (DisableDirPage auto with UsePreviousAppDir):
//    then nothing of this runs; the folder was checked at the first installation. A registry key or
//    folder that cannot be read counts as nothing found (logged).
//  - PrepareToInstall, administrative install mode only (CheckGameFoldersForLinks): links in the
//    folders all users can write to (ADR 0009). [Dirs] gives every user modify rights on Data and
//    Users of both games, and the elevated setup writes below them; a junction or symbolic link
//    there could redirect those writes outside the installation, and a hard link could make the
//    external permission entries copy a file outside the installation into one every user can read.
//    If Data, Users or a folder below them is a link (or cannot be listed), or a file there is a
//    hard link (or its number of names cannot be read), the setup stops on the "Preparing to
//    install" page with the message LinkInGameFolder before anything is changed (silent: exit code
//    7). Not in user and portable mode: there the setup does not elevate itself.
//
// Nothing here writes to the registry or the file system, and no key below Software\Sierra is read
// (the NeoEE CD keys are there).
// Requires: utils.iss (ClampGameWindowWidth, GameWindowHeight, MinGameWindowHeight, IsScreenTooLow,
// FormatScreenMetrics, NormalizeFolderPath, IsSameOrInside, IsSameFolder, IsDriveRootOrEmpty,
// InstalledFromFolder, FormatHklmKeyName, IsForeignUninstallEntry, UninstallKeysPath,
// FormatFindingList, FindingsShownMax, GetOtherProductUninstallRegPath, GetTickCount, TicksSince,
// FindLinksInGameFolder, LinkFindingsShownMax), extension.iss (SilentInstall, SuppressMsgBoxes), the
// messages LowScreenResolution, ForeignInstallFound, ForeignFolderQuestion, SharedFolderQuestion and
// LinkInGameFolder (messages.iss); ISPP: InstallType, OtherAppID, EEDir, AoCDir (setup_is6.iss,
// config_*.iss).

// Size of the primary screen and DPI of the screen. Inno Setup 6.2.2 declares itself
// system-DPI-aware (manifest of Setup.e32), so both are physical values at the display scaling of
// the sign-in; a scaling changed without signing out again is the known exception (contract O4).
function GetSystemMetrics(nIndex: Integer): Integer;
  external 'GetSystemMetrics@user32.dll stdcall';
function GetDC(hWnd: HWND): LongWord;
  external 'GetDC@user32.dll stdcall';
function GetDeviceCaps(hDC: LongWord; nIndex: Integer): Integer;
  external 'GetDeviceCaps@gdi32.dll stdcall';
function ReleaseDC(hWnd: HWND; hDC: LongWord): Integer;
  external 'ReleaseDC@user32.dll stdcall';

const
  // GetSystemMetrics indexes (Win32 API): width and height of the primary screen
  SM_CXSCREEN = 0;
  SM_CYSCREEN = 1;
  // GetDeviceCaps index (Win32 API): pixels per logical inch along the width of the screen
  LOGPIXELSX = 88;

// DPI of the screen (GetDeviceCaps(LOGPIXELSX) of the device context of the whole screen), 0 if it
// cannot be read
function GetScreenDpi: Integer;
var
  ScreenDC: LongWord;
begin
  Result := 0;
  ScreenDC := GetDC(0);
  if ScreenDC = 0 then
    Exit;
  try
    Result := GetDeviceCaps(ScreenDC, LOGPIXELSX);
  finally
    ReleaseDC(0, ScreenDC);
  end;
end;

// InitializeSetup, on every run: screen size, DPI and the clamped game window into the log
// (FormatScreenMetrics). Nothing escapes: the log line is a diagnosis, not a step of the setup.
procedure LogScreenMetrics;
begin
  try
    Log(FormatScreenMetrics(GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), GetScreenDpi()));
  except
    Log('Unable to read the screen size or the DPI: ' + GetExceptionMessage);
  end;
end;

// InitializeSetup, after the install-mode question: a notice if the primary screen is lower than
// the menus of the game need (IsScreenTooLow). Only the log in silent mode and with
// /SUPPRESSMSGBOXES; the installation always continues.
procedure ShowLowScreenResolutionNotice;
var
  Width, Height: Integer;
begin
  Width := GetSystemMetrics(SM_CXSCREEN);
  Height := GetSystemMetrics(SM_CYSCREEN);
  if not IsScreenTooLow(Height) then
    Exit;
  Log('The screen is lower than ' + IntToStr(MinGameWindowHeight) + ' pixels (' + IntToStr(Width) + ' x ' + IntToStr(Height) +
    '): the game window is set to ' + IntToStr(ClampGameWindowWidth(Width)) + ' x ' + IntToStr(GameWindowHeight(Width, Height)) +
    ', the menus may not fit (notice LowScreenResolution)');
  if SilentInstall or SuppressMsgBoxes then
  begin
    Log('Notice LowScreenResolution not shown (silent installation or /SUPPRESSMSGBOXES)');
    Exit;
  end;
  MsgBox(FmtMessage(CustomMessage('LowScreenResolution'), [IntToStr(Width), IntToStr(Height),
    IntToStr(ClampGameWindowWidth(Width)), IntToStr(GameWindowHeight(Width, Height))]), mbInformation, MB_OK);
end;

const
  // Game settings keys in HKLM of the retail game, GOG, old patches (SSSI, Mad Doc Software) and old
  // NeoEE installers (Neo; t=10577 p=46302). The community setups write them only in HKCU (contract
  // 0, Products), so a key in HKLM belongs to another installation.
  ForeignKeyEE = 'Software\SSSI\Empire Earth';
  ForeignKeyAoC = 'Software\Mad Doc Software\EE-AOC';
  ForeignKeyNeoEE = 'Software\Neo\Empire Earth';
  ForeignKeyNeoAoC = 'Software\Neo\Art of Conquest';
  // Default folder of the retail CD, below the system drive and below Program Files (32-bit)
  // (t=5571 p=37625, t=5825 p=39087)
  RetailFolder = 'Sierra\Empire Earth';
  // The other community product (EE <-> NeoEE) for the question SharedFolderQuestion, and its
  // setup data folder (contract 0, Products)
  OtherProductName = '{#InstallType == "EE" ? "NeoEE" : "Empire Earth"}';
  OtherSetupDataDir = '_setupdata_{#InstallType == "EE" ? "NeoEE" : "EE"}';

var
  // CheckForeignInstallations has run (once per run)
  ForeignInstallationsChecked: Boolean;
  // What it found (the lines of the notice) and the folders of those installations that exist
  ForeignFindings: TStringList;
  ForeignFolders: TStringList;

// Adds Folder (normalized) to ForeignFolders if it exists, is not the root of a drive
// (IsDriveRootOrEmpty) and is not there yet. True if it was added.
function AddForeignFolder(const Folder: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if IsDriveRootOrEmpty(Folder) or not DirExists(NormalizeFolderPath(Folder)) then
    Exit;
  for I := 0 to ForeignFolders.Count - 1 do
    if IsSameFolder(ForeignFolders[I], Folder) then
      Exit;
  ForeignFolders.Add(NormalizeFolderPath(Folder));
  Result := True;
end;

// One game settings key in one view of HKLM (RootKey HKLM32 or HKLM64): a finding if it exists,
// named as regedit shows it, with the folder its "Installed From" values name unless that is the
// root of a drive (also a folder for ForeignFolderQuestion if it exists)
procedure CheckForeignRegistryKey(const RootKey: Integer; const SubKey: String; const View32: Boolean);
var
  Line, Volume, Directory, Folder: String;
begin
  if not RegKeyExists(RootKey, SubKey) then
    Exit;
  Line := FormatHklmKeyName(SubKey, View32, IsWin64);
  if not RegQueryStringValue(RootKey, SubKey, 'Installed From Volume', Volume) then
    Volume := '';
  if not RegQueryStringValue(RootKey, SubKey, 'Installed From Directory', Directory) then
    Directory := '';
  Folder := InstalledFromFolder(Volume, Directory);
  if not IsDriveRootOrEmpty(Folder) then
  begin
    Line := Line + ': ' + Folder;
    AddForeignFolder(Folder);
  end;
  Log('Foreign or old installation: registry key ' + Line);
  ForeignFindings.Add(Line);
end;

// The four game settings keys in one view of HKLM
procedure CheckForeignRegistryKeys(const RootKey: Integer; const View32: Boolean);
begin
  CheckForeignRegistryKey(RootKey, ForeignKeyEE, View32);
  CheckForeignRegistryKey(RootKey, ForeignKeyAoC, View32);
  CheckForeignRegistryKey(RootKey, ForeignKeyNeoEE, View32);
  CheckForeignRegistryKey(RootKey, ForeignKeyNeoAoC, View32);
end;

// A default folder of the retail CD: a finding if it exists (named once, also if a key above named
// the same folder)
procedure CheckRetailFolder(const Folder: String);
begin
  if not DirExists(Folder) then
    Exit;
  if AddForeignFolder(Folder) then
  begin
    Log('Foreign or old installation: folder ' + Folder);
    ForeignFindings.Add(Folder);
  end
  else
    Log('Foreign or old installation: folder ' + Folder + ' (already named by a registry key above)');
end;

// The uninstall entries of one view of HKLM: every entry IsForeignUninstallEntry reports is a
// finding with its DisplayName and its InstallLocation (also a folder for ForeignFolderQuestion);
// Count gets the number of entries read
procedure CheckUninstallEntries(const RootKey: Integer; const ViewName: String; var Count: Integer);
var
  Names: TArrayOfString;
  I: Integer;
  SubKey, DisplayName, Publisher, Location, Line: String;
begin
  if not RegGetSubkeyNames(RootKey, UninstallKeysPath, Names) then
  begin
    Log('Unable to read the uninstall entries of ' + ViewName + ' (treated as none)');
    Exit;
  end;
  Count := Count + GetArrayLength(Names);
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    SubKey := UninstallKeysPath + '\' + Names[I];
    if RegQueryStringValue(RootKey, SubKey, 'DisplayName', DisplayName) then
    begin
      if not RegQueryStringValue(RootKey, SubKey, 'Publisher', Publisher) then
        Publisher := '';
      if IsForeignUninstallEntry(Names[I], DisplayName, Publisher) then
      begin
        if not RegQueryStringValue(RootKey, SubKey, 'InstallLocation', Location) then
          Location := '';
        Line := DisplayName;
        if not IsDriveRootOrEmpty(Location) then
        begin
          Line := Line + ': ' + NormalizeFolderPath(Location);
          AddForeignFolder(Location);
        end;
        Log('Foreign or old installation: uninstall entry ' + ViewName + '\' + Names[I] + ', DisplayName "' + DisplayName +
          '", Publisher "' + Publisher + '", InstallLocation "' + Location + '"');
        ForeignFindings.Add(Line);
      end;
    end;
  end;
end;

// Once per run, when the folder page is left the first time: looks for foreign or old installations
// (see the header) and names what it found in the notice ForeignInstallFound. Only the log in silent
// mode and with /SUPPRESSMSGBOXES. Nothing is changed or offered for deletion.
procedure CheckForeignInstallations;
var
  Count: Integer;
  Started: DWORD;
begin
  if ForeignInstallationsChecked then
    Exit;
  ForeignInstallationsChecked := True;
  ForeignFindings := TStringList.Create;
  ForeignFolders := TStringList.Create;
  try
    CheckForeignRegistryKeys(HKLM32, True);
    if IsWin64 then
      CheckForeignRegistryKeys(HKLM64, False);
    CheckRetailFolder(ExpandConstant('{sd}\' + RetailFolder));
    CheckRetailFolder(ExpandConstant('{commonpf32}\' + RetailFolder));
    Count := 0;
    Started := GetTickCount;
    if IsWin64 then
    begin
      CheckUninstallEntries(HKLM64, FormatHklmKeyName(UninstallKeysPath, False, True), Count);
      CheckUninstallEntries(HKLM32, FormatHklmKeyName(UninstallKeysPath, True, True), Count);
    end
    else
      CheckUninstallEntries(HKLM32, FormatHklmKeyName(UninstallKeysPath, True, False), Count);
    Log('Checked ' + IntToStr(Count) + ' uninstall entries of HKLM in ' + IntToStr(TicksSince(Started)) + ' ms');
  except
    Log('The check for foreign or old installations stopped: ' + GetExceptionMessage + ' (the rest counts as nothing found)');
  end;
  if ForeignFindings.Count = 0 then
  begin
    Log('No foreign or old installation of Empire Earth found');
    Exit;
  end;
  Log(IntToStr(ForeignFindings.Count) + ' traces of foreign or old installations found, ' + IntToStr(ForeignFolders.Count) +
    ' of their folders exist (notice ForeignInstallFound)');
  if SilentInstall or SuppressMsgBoxes then
    Log('Notice ForeignInstallFound not shown (silent installation or /SUPPRESSMSGBOXES)')
  else
    MsgBox(FmtMessage(CustomMessage('ForeignInstallFound'), [FormatFindingList(ForeignFindings, FindingsShownMax)]), mbInformation, MB_OK);
end;

// True if a game folder of this installation in the folder Dir ({app}\Empire Earth or {app}\Empire
// Earth - The Art of Conquest) is, contains or lies in a folder of a foreign installation
// (ForeignFolders); Found is that folder
function IsFolderOfForeignInstallation(const Dir: String; var Found: String): Boolean;
var
  I: Integer;
  EEFolder, AoCFolder: String;
begin
  Result := False;
  Found := '';
  EEFolder := AddBackslash(Dir) + '{#EEDir}';
  AoCFolder := AddBackslash(Dir) + '{#AoCDir}';
  for I := 0 to ForeignFolders.Count - 1 do
    if IsSameOrInside(ForeignFolders[I], EEFolder) or IsSameOrInside(EEFolder, ForeignFolders[I]) or
      IsSameOrInside(ForeignFolders[I], AoCFolder) or IsSameOrInside(AoCFolder, ForeignFolders[I]) then
    begin
      Found := ForeignFolders[I];
      Result := True;
      Exit;
    end;
end;

// True if the uninstall key of the other community product in RootKey has Dir as its
// 'Inno Setup: App Path'
function OtherProductAppPathIs(const RootKey: Integer; const Dir: String): Boolean;
var
  AppPath: String;
begin
  Result := RegQueryStringValue(RootKey, GetOtherProductUninstallRegPath(), 'Inno Setup: App Path', AppPath);
  if Result then
    Result := IsSameFolder(AppPath, Dir);
end;

// True if the folder Dir holds the other community product (contract O11): its setup data folder
// (OtherSetupDataDir, or <AppId> of a setup up to 1.7.2) exists there, or its uninstall key (HKLM in
// both views, HKCU) has Dir as 'Inno Setup: App Path', which also finds installations of 1.7.2.
// Reason says which.
function IsOtherProductInFolder(const Dir: String; var Reason: String): Boolean;
begin
  Result := True;
  Reason := AddBackslash(Dir) + OtherSetupDataDir + ' exists';
  if DirExists(AddBackslash(Dir) + OtherSetupDataDir) then
    Exit;
  Reason := AddBackslash(Dir) + '{#OtherAppID} (setup data folder of a setup up to 1.7.2) exists';
  if DirExists(AddBackslash(Dir) + '{#OtherAppID}') then
    Exit;
  Reason := 'the uninstall key of the other product names it as Inno Setup: App Path';
  if OtherProductAppPathIs(HKLM32, Dir) or OtherProductAppPathIs(HKCU, Dir) then
    Exit;
  if IsWin64 then
    if OtherProductAppPathIs(HKLM64, Dir) then
      Exit;
  Reason := '';
  Result := False;
end;

// Asks Question (a message with Yes = choose another folder, the default) unless the installation
// is silent or /SUPPRESSMSGBOXES is set (then only the log). True if the user wants another folder.
function AskForAnotherFolder(const Name, Question: String): Boolean;
begin
  Result := False;
  if SilentInstall or SuppressMsgBoxes then
  begin
    Log('Question ' + Name + ' not asked (silent installation or /SUPPRESSMSGBOXES), the installation continues');
    Exit;
  end;
  Result := MsgBox(Question, mbConfirmation, MB_YESNO) = IDYES;
  if Result then
    Log(Name + ': Yes, the user chooses another folder')
  else
    Log(Name + ': No, the user installs into this folder anyway');
end;

// NextButtonClick(wpSelectDir): the checks of the folder page (see the header). True to continue,
// False to stay on the folder page (only if the user answered a question with Yes). An exception
// counts as nothing found and never keeps the wizard on the page.
function CheckSelectedFolder: Boolean;
var
  Dir, Found, Reason: String;
begin
  Result := True;
  Dir := WizardDirValue;
  Log('Checking the chosen folder ' + Dir);
  CheckForeignInstallations();
  try
    if IsFolderOfForeignInstallation(Dir, Found) then
    begin
      Log('The game folders in ' + Dir + ' would be, contain or lie in the folder of a foreign or old installation: ' + Found +
        ' (question ForeignFolderQuestion)');
      if AskForAnotherFolder('ForeignFolderQuestion', FmtMessage(CustomMessage('ForeignFolderQuestion'), [Found, Dir])) then
      begin
        Result := False;
        Exit;
      end;
    end;
    if IsOtherProductInFolder(Dir, Reason) then
    begin
      Log('The folder ' + Dir + ' already holds ' + OtherProductName + ': ' + Reason + ' (question SharedFolderQuestion)');
      if AskForAnotherFolder('SharedFolderQuestion', FmtMessage(CustomMessage('SharedFolderQuestion'), [OtherProductName, Dir])) then
        Result := False;
    end;
  except
    Log('The check of the chosen folder stopped: ' + GetExceptionMessage + ' (counts as nothing found)');
    Result := True;
  end;
end;

// PrepareToInstall in administrative install mode (see the header, ADR 0009): Data, Users and every
// folder below them in both game folders that exist, selected or not (the [InstallDelete] entries of
// the AoC folder have no component), with FindLinksInGameFolder. Logs the number of folders examined,
// the time and every finding. Returns '' if nothing was found, else the message LinkInGameFolder
// with the folders, which stops the setup before anything is changed. An exception stops it as well,
// because then the folders were not checked.
function CheckGameFoldersForLinks: String;
var
  Findings: TStringList;
  Folders, Files, ReparseFiles: Integer;
  Started: DWORD;
begin
  Result := '';
  Findings := TStringList.Create;
  try
    Folders := 0;
    Files := 0;
    ReparseFiles := 0;
    Started := GetTickCount;
    try
      FindLinksInGameFolder(ExpandConstant('{app}\{#EEDir}'), '', Findings, Folders, Files, ReparseFiles);
      FindLinksInGameFolder(ExpandConstant('{app}\{#AoCDir}'), '', Findings, Folders, Files, ReparseFiles);
    except
      Log('The link check stopped: ' + GetExceptionMessage + ' (the folders count as not checked)');
      Findings.Add(ExpandConstant('{app}'));
    end;
    Log('Link check: ' + IntToStr(Folders) + ' folders and ' + IntToStr(Files) + ' files below Data and Users of ' +
      ExpandConstant('{app}') + ' examined in ' + IntToStr(TicksSince(Started)) + ' ms, ' + IntToStr(Findings.Count) +
      ' links or unreadable folders or files found, ' + IntToStr(ReparseFiles) + ' files with a reparse point (allowed)');
    if Findings.Count > 0 then
    begin
      Log('The installation stops before anything is changed (message LinkInGameFolder on the Preparing to install page; ' +
        'silent installation: exit code 7)');
      Result := FmtMessage(CustomMessage('LinkInGameFolder'), [FormatFindingList(Findings, LinkFindingsShownMax)]);
    end;
  finally
    Findings.Free;
  end;
end;
