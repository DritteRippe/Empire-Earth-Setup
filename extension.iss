[Code]
// Wizard helpers that Inno Setup does not provide: command line switches, the tasks and
// components of the previous installation, setup update detection and the Windows version.
// Requires: StrSplit, GetUninstallRegPath (utils.iss), AppVerName ([Setup]).

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
  Result := WizardContainsParam('/SUPPRESSMSGBOXES');
end;

function SilentInstall(): Boolean;
begin
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

// Component selected in the last installation of this product
function WizardIsComponentInstalled(Component: String): Boolean;
begin
  Result := UninstallKeyListContains(GetUninstallRegPath(), 'Inno Setup: Selected Components', Component);
end;

// True if this product is installed by another version of the game or of the setup. The uninstall
// key holds the game version (AppVersion) but not the setup version ('Inno Setup: Setup Version'
// is the version of Inno Setup), so its DisplayName is compared with AppVerName, which contains
// both: '<name> v<game version> - Setup v<setup version>'.
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

// Windows 11 reports itself as 10.0 (build 22000 and later), so it counts as Windows 10 here
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
