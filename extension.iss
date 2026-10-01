[Code]
// Wizard helpers that Inno Setup does not provide: command line switches, the tasks and
// components of the previous installation, setup update detection and the Windows version.

function WizardContainsParam(Param: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
  begin
    if UpperCase(ParamStr(i)) = UpperCase(Param) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function SuppressMsgBoxes(): Boolean;
begin
  // Log('SUPPRESSMSGBOXES: ' + IntToStr(WizardContainsParam('/SUPPRESSMSGBOXES')));
  Result := WizardContainsParam('/SUPPRESSMSGBOXES');
end;

function SilentInstall(): Boolean;
begin
  // Log('VERYSILENT: ' + IntToStr(WizardContainsParam('/VERYSILENT'));
  // Log('SILENT: ' + IntToStr(WizardSilent);
  Result := (WizardContainsParam('/VERYSILENT') or WizardSilent);
end;

// Exact (not substring) match of Item in a comma separated list value of an uninstall key, like
// "Inno Setup: Selected Tasks" or "Inno Setup: Selected Components"
function UninstallKeyListContains(const UninstallKey, ValueName, Item: String): Boolean;
var
  I: Integer;
  List: String;
  Items: TArrayOfString;
begin
  Result := False;
  if not RegQueryStringValue(HKA, UninstallKey, ValueName, List) then
    Exit;
  Items := StrSplit(List, ',');
  for I := 0 to GetArrayLength(Items) - 1 do
    if CompareText(Trim(Items[I]), Item) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

// Task selected in the last installation of this product
function WizardIsTaskInstalled(Task: String): Boolean;
begin
  Result := UninstallKeyListContains(GetUninstallRegPath(), 'Inno Setup: Selected Tasks', Task);
end;

// Task selected in the last installation of this product or of the other one (EE <-> NeoEE)
function WizardIsTaskInstalledMultiSetup(Task: String): Boolean;
begin
  Result := WizardIsTaskInstalled(Task) or
    UninstallKeyListContains(GetOtherProductUninstallRegPath(), 'Inno Setup: Selected Tasks', Task);
end;

// Component selected in the last installation of this product
function WizardIsComponentInstalled(Component: String): Boolean;
begin
  Result := UninstallKeyListContains(GetUninstallRegPath(), 'Inno Setup: Selected Components', Component);
end;

// Component selected in the last installation of this product or of the other one (EE <-> NeoEE)
function WizardIsComponentInstalledMultiSetup(Component: String): Boolean;
begin
  Result := WizardIsComponentInstalled(Component) or
    UninstallKeyListContains(GetOtherProductUninstallRegPath(), 'Inno Setup: Selected Components', Component);
end;

// Very dirty, because sadly the setup don't store it's own version
// It only store the game product version... For some reason IS don't
// store the setup version but it's own version as 'Inno Setup: Setup Version'...
// So we have the choice, create a new regedit key just for that purpose or
// simply compare if the setup name is different (because *this* setup name is
// formated as 'ProductName ProductVersion - Setup SetupVersion').
function WizardIsUpdate(): Boolean;
var
  Tmp: String;
  LocalVersionName: String;
begin
  Result := False;
  if RegQueryStringValue(HKA, GetUninstallRegPath(), 'DisplayName', Tmp) then
  begin
    LocalVersionName := ExpandConstant('{#SetupSetting("AppVerName")}');
    if CompareText(Tmp, LocalVersionName) <> 0 then
      Result := True;
  end; 
end;

// WARNING
// A little unsafe since the result depend on the IS version (manifest)
// IS 5 will probably be unable to report more than Win 8
// IS 6+ will probably be unable to report more than Win 10
function IsWindowsVersionOrNewer(Major, Minor: Integer): Boolean;
var 
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  Result :=
    (Version.Major > Major) or
    ((Version.Major = Major) and (Version.Minor >= Minor));
end;

function IsWindows10OrNewer: Boolean;
begin
  Result := IsWindowsVersionOrNewer(10, 0);
end;

function IsWindowsXPOrNewer: Boolean;
begin
  Result := IsWindowsVersionOrNewer(5, 1);
end;