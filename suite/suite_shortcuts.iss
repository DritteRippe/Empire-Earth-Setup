[Code]
// The shortcuts of the suite (contract 1.7 point 8): one shortcut, "Empire Earth Community", on the desktop and in the start
// menu folder "Empire Earth Community", which starts the launcher without an argument (the launcher opens with the game
// the player chose last), and in that folder the shortcuts of the Mod Creator and of the uninstaller of the suite.
// Without .NET Framework 4.8 there is no launcher: the shortcut of the same name then starts the game program of the
// first installed product of the list NeoEE, EE. Every run of the suite, before it creates its shortcuts, and its
// uninstaller delete the shortcuts of suite 1.0.0 (SuiteRemoveOldSuiteShortcuts): the game shortcuts "Empire Earth" and
// "Neo Empire Earth" (the launcher with --product=EE or --product=NeoEE), the Diagnostic shortcuts and "Empire Earth
// Launcher". They are created in code at ssPostInstall (not by [Icons]: ADR 0013 Evidence) by every run of the suite, so a
// repair restores them, and removed by its uninstaller, which Inno Setup's uninstall log does not do for them.
// ci/check_contract.py reads the SuiteShortcut calls of ApplySuiteShortcuts (one call per shortcut and place, literal
// arguments) and compares them with the table of contract 1.7.
// Requires: IsDotNet48 (suite.iss), SuiteUninstallKey, SuiteProductEE, SuiteProductNeoEE, SuiteIsSameOrInside,
// SuiteFirstInstalledProduct, SuiteOldSuiteShortcutPath, SuiteOldSuiteShortcutRemovable (suite_common.iss), the defines
// LauncherExe, ModCreatorExe, EE_AppID, NeoEE_AppID.

const
  CLSID_ShellLink = '{00021401-0000-0000-C000-000000000046}';

type
  IShellLinkW = interface(IUnknown)
    '{000214F9-0000-0000-C000-000000000046}'
    procedure Dummy;
    procedure Dummy2;
    procedure Dummy3;
    function GetDescription(pszName: String; cchMaxName: Integer): HResult;
    function SetDescription(pszName: String): HResult;
    function GetWorkingDirectory(pszDir: String; cchMaxPath: Integer): HResult;
    function SetWorkingDirectory(pszDir: String): HResult;
    function GetArguments(pszArgs: String; cchMaxPath: Integer): HResult;
    function SetArguments(pszArgs: String): HResult;
    function GetHotkey(var pwHotkey: Word): HResult;
    function SetHotkey(wHotkey: Word): HResult;
    function GetShowCmd(out piShowCmd: Integer): HResult;
    function SetShowCmd(iShowCmd: Integer): HResult;
    function GetIconLocation(pszIconPath: String; cchIconPath: Integer; out piIcon: Integer): HResult;
    function SetIconLocation(pszIconPath: String; iIcon: Integer): HResult;
    function SetRelativePath(pszPathRel: String; dwReserved: DWORD): HResult;
    function Resolve(Wnd: HWND; fFlags: DWORD): HResult;
    function SetPath(pszFile: String): HResult;
  end;

  IPersist = interface(IUnknown)
    '{0000010C-0000-0000-C000-000000000046}'
    function GetClassID(var classID: TGUID): HResult;
  end;

  IPersistFile = interface(IPersist)
    '{0000010B-0000-0000-C000-000000000046}'
    function IsDirty: HResult;
    function Load(pszFileName: String; dwMode: Longint): HResult;
    function Save(pszFileName: String; fRemember: BOOL): HResult;
    function SaveCompleted(pszFileName: String): HResult;
    function GetCurFile(out pszFileName: String): HResult;
  end;

var
  // True while ApplySuiteShortcuts deletes the shortcuts (the uninstaller) instead of creating them
  SuiteShortcutsRemoving: Boolean;

// A shortcut file (.lnk) with the COM object of the Windows shell; False (and a log line) if it fails.
// IconFile is the file whose first icon the shortcut shows.
function SuiteCreateShortcutFile(const LinkFile, Target, Parameters, WorkingDir, IconFile: String): Boolean;
var
  Obj: IUnknown;
  Link: IShellLinkW;
  Persist: IPersistFile;
begin
  Result := False;
  try
    Obj := CreateComObject(StringToGuid(CLSID_ShellLink));
    Link := IShellLinkW(Obj);
    OleCheck(Link.SetPath(Target));
    OleCheck(Link.SetArguments(Parameters));
    OleCheck(Link.SetWorkingDirectory(WorkingDir));
    OleCheck(Link.SetIconLocation(IconFile, 0));
    OleCheck(Link.SetShowCmd(SW_SHOWNORMAL));
    Persist := IPersistFile(Obj);
    OleCheck(Persist.Save(LinkFile, True));
    Result := True;
  except
    Log('Shortcut ' + LinkFile + ' not created: ' + GetExceptionMessage);
  end;
end;

// The folder a product is installed in (its root, "Inno Setup: App Path" of its uninstall key), '' if
// the product is not installed. The uninstall key is the one of the product setup: <AppId>_is1.
function SuiteProductRoot(const Product: String): String;
var
  AppId: String;
begin
  Result := '';
  if CompareText(Product, SuiteProductEE) = 0 then
    AppId := '{#EE_AppID}'
  else
    AppId := '{#NeoEE_AppID}';
  if RegQueryStringValue(HKLM, SuiteUninstallKey(AppId), 'Inno Setup: App Path', Result) then
    Result := RemoveBackslash(Result)
  else
    Result := '';
end;

// True if the shortcut file starts the launcher of the suite (SuiteLinkTextNamesFile); a shortcut that cannot be
// read does not
function SuiteLinkStartsLauncher(const LinkFile: String): Boolean;
var
  Content: AnsiString;
begin
  Result := LoadStringFromFile(LinkFile, Content) and SuiteLinkTextNamesFile(String(Content), '{#LauncherExe}');
end;

// Deletes the shortcuts of suite 1.0.0 that exist (SuiteOldSuiteShortcutPath: exactly these paths), one log line each.
// The desktop shortcut "Empire Earth" only if it starts the launcher: the EE setup's own shortcut has that name.
// Called first by ApplySuiteShortcuts, so that every install, update, repair and uninstallation leaves none of them.
procedure SuiteRemoveOldSuiteShortcuts;
var
  I: Integer;
  Path: String;
begin
  for I := 1 to SuiteOldSuiteShortcutCount do
  begin
    Path := SuiteOldSuiteShortcutPath(I, ExpandConstant('{autodesktop}'), ExpandConstant('{autoprograms}\Empire Earth Community'));
    if FileExists(Path) then
    begin
      if not SuiteOldSuiteShortcutRemovable(I, SuiteLinkStartsLauncher(Path)) then
        Log('Shortcut of suite 1.0.0 kept, it does not start the launcher: ' + Path)
      else if DeleteFile(Path) then
        Log('Shortcut of suite 1.0.0 removed: ' + Path)
      else
        Log('Shortcut of suite 1.0.0 could not be removed: ' + Path);
    end;
  end;
end;

// One shortcut: Place (a folder with constants), Name (without .lnk), Target and Parameters (the launcher without
// parameters: the suite creates no shortcut with --product=), Products (comma separated product ids, '' for none) and
// Fallback (the game program below the product root, started instead of a file of the suite without .NET Framework
// 4.8: the first installed product of Products gives the root; '' for none: the shortcut is then skipped without .NET
// Framework 4.8). With .NET Framework 4.8 the shortcut is created always, so the launcher shows its games disabled if
// none is installed. While SuiteShortcutsRemoving is set it deletes the shortcut file instead.
procedure SuiteShortcut(const Place, Name, Target, Parameters, Products, Fallback: String);
var
  Folder, Link, Start, Args, Product: String;
begin
  Folder := ExpandConstant(Place);
  Link := AddBackslash(Folder) + Name + '.lnk';
  if SuiteShortcutsRemoving then
  begin
    if FileExists(Link) then
    begin
      if DeleteFile(Link) then
        Log('Shortcut removed: ' + Link)
      else
        Log('Shortcut not removed: ' + Link);
    end;
    Exit;
  end;
  Start := ExpandConstant(Target);
  Args := Parameters;
  // the launcher and the Mod Creator are installed only with .NET Framework 4.8, the uninstaller always
  if (CompareText(Start, ExpandConstant('{uninstallexe}')) <> 0) and SuiteIsSameOrInside(Start, ExpandConstant('{app}')) and not IsDotNet48 then
  begin
    if Fallback = '' then
    begin
      Log('Shortcut skipped, the launcher is not installed (no .NET Framework 4.8): ' + Link);
      Exit;
    end;
    Product := SuiteFirstInstalledProduct(Products, SuiteProductRoot(SuiteProductEE) <> '', SuiteProductRoot(SuiteProductNeoEE) <> '');
    if Product = '' then
    begin
      Log('Shortcut skipped, neither NeoEE nor EE is installed (no .NET Framework 4.8): ' + Link);
      Exit;
    end;
    Start := SuiteProductRoot(Product) + Fallback;
    if not FileExists(Start) then
    begin
      Log('Shortcut skipped, the product has no ' + Start + ': ' + Link);
      Exit;
    end;
    Args := '';
  end;
  ForceDirectories(Folder);
  if SuiteCreateShortcutFile(Link, Start, Args, ExtractFileDir(Start), Start) then
    Log('Shortcut created: ' + Link + ' -> ' + Start + ' ' + Args);
end;

// Creates (Remove = False) or deletes (True) every shortcut of the suite, then the start menu folder
// if it is empty. Before the suite creates its shortcuts, the product runner has deleted the
// shortcuts of earlier standalone runs of the products (contract 1.7 point 7, suite_run.iss), and
// SuiteRemoveOldSuiteShortcuts deletes those of suite 1.0.0 (point 8), the desktop one named Empire Earth only if it
// starts the launcher.
// One call per shortcut and place; the shortcuts are those of the table of contract 1.7. The names
// are written out here: the uninstaller deletes exactly these files, whatever language it runs in.
procedure ApplySuiteShortcuts(Remove: Boolean);
begin
  SuiteShortcutsRemoving := Remove;
  SuiteRemoveOldSuiteShortcuts;
  SuiteShortcut('{autodesktop}', 'Empire Earth Community', '{app}\{#LauncherExe}', '', 'NeoEE,EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Empire Earth Community', '{app}\{#LauncherExe}', '', 'NeoEE,EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Mod Creator', '{app}\Mod Creator\{#ModCreatorExe}', '', '', '');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Uninstall Empire Earth Community', '{uninstallexe}', '', '', '');
  if Remove then
    RemoveDir(ExpandConstant('{autoprograms}\Empire Earth Community'));
  SuiteShortcutsRemoving := False;
end;
