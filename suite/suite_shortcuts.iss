[Code]
// The shortcuts of the suite (contract 1.7 point 8): the game shortcuts "Empire Earth" and "Neo Empire
// Earth" on the desktop and in the start menu folder "Empire Earth Community", which start the launcher
// with --product=EE or --product=NeoEE, and the shortcut of the launcher itself. They are created in
// code at ssPostInstall (not by [Icons]: ADR 0013 Evidence) by every run of the suite, so a repair
// restores them, and removed by its uninstaller, which Inno Setup's uninstall log does not do for them.
// Without .NET Framework 4.8 a game shortcut of a product that was installed starts its game program
// instead (the launcher is not installed then).
// ci/check_contract.py reads the SuiteShortcut calls of ApplySuiteShortcuts (one call per shortcut
// and place, literal arguments) and compares them with the table of contract 1.7.
// Requires: IsDotNet48 (suite.iss), SuiteUninstallKey, SuiteProductEE
// (suite_common.iss), the defines LauncherExe, EE_AppID, NeoEE_AppID.

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

// A shortcut file (.lnk) with the COM object of the Windows shell; False (and a log line) if it fails
function SuiteCreateShortcutFile(const LinkFile, Target, Parameters, WorkingDir: String): Boolean;
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
    OleCheck(Link.SetIconLocation(Target, 0));
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

// One shortcut: Place (a folder with constants), Name (without .lnk), Target and Parameters (the
// launcher and --product=<id> for a game shortcut), Product (EE, NeoEE or '' for none: a shortcut of
// a product is created only if its setup succeeded in this run or an earlier run left it installed)
// and Fallback (the game program below the product root, started instead of the launcher without
// .NET Framework 4.8; '' for none: the shortcut is then skipped without .NET Framework 4.8). While
// SuiteShortcutsRemoving is set it deletes the shortcut file instead.
procedure SuiteShortcut(const Place, Name, Target, Parameters, Product, Fallback: String);
var
  Folder, Link, Start, Args, Root: String;
begin
  Folder := ExpandConstant(Place);
  Link := AddBackslash(Folder) + Name + '.lnk';
  if SuiteShortcutsRemoving then
  begin
    if FileExists(Link) then
      if DeleteFile(Link) then
        Log('Shortcut removed: ' + Link)
      else
        Log('Shortcut not removed: ' + Link);
    Exit;
  end;
  Start := ExpandConstant(Target);
  Args := Parameters;
  Root := '';
  if Product <> '' then
  begin
    // the product is installed: its setup ran in this run, or an earlier run (or a standalone setup) installed it
    Root := SuiteProductRoot(Product);
    if Root = '' then
    begin
      Log('Shortcut skipped, ' + Product + ' is not installed: ' + Link);
      Exit;
    end;
  end;
  if CompareText(Start, ExpandConstant('{app}\{#LauncherExe}')) = 0 then
    if not IsDotNet48 then
    begin
      if (Product = '') or (Fallback = '') then
      begin
        Log('Shortcut skipped, the launcher is not installed (no .NET Framework 4.8): ' + Link);
        Exit;
      end;
      Start := Root + Fallback;
      Args := '';
    end;
  ForceDirectories(Folder);
  if SuiteCreateShortcutFile(Link, Start, Args, ExtractFileDir(Start)) then
    Log('Shortcut created: ' + Link + ' -> ' + Start + ' ' + Args);
end;

// Creates (Remove = False) or deletes (True) every shortcut of the suite, then the start menu folder
// if it is empty. Before the suite creates its shortcuts, the product runner has deleted the
// shortcuts of earlier standalone runs of the products (contract 1.7 point 7, WP5).
// One call per shortcut and place; the game shortcuts are those of the table of contract 1.7.
procedure ApplySuiteShortcuts(Remove: Boolean);
begin
  SuiteShortcutsRemoving := Remove;
  SuiteShortcut('{autodesktop}', 'Empire Earth', '{app}\{#LauncherExe}', '--product=EE', 'EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Empire Earth', '{app}\{#LauncherExe}', '--product=EE', 'EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autodesktop}', 'Neo Empire Earth', '{app}\{#LauncherExe}', '--product=NeoEE', 'NeoEE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Neo Empire Earth', '{app}\{#LauncherExe}', '--product=NeoEE', 'NeoEE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Empire Earth Launcher', '{app}\{#LauncherExe}', '', '', '');
  if Remove then
    RemoveDir(ExpandConstant('{autoprograms}\Empire Earth Community'));
  SuiteShortcutsRemoving := False;
end;
