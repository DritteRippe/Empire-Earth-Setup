[Code]
// Install state for the Empire Earth Launcher: install.ini and the contract version in the
// uninstall key (docs/CONTRACT.md 1.2, 1.3, 2.1 and 2.5; docs/adr/0004-install-record-and-integrity-manifest.md
// points 6 and 9). The install record and the defaults marker are [Registry] entries of
// setup_is6.iss (contract 1.1, 3.5); GetContractInstallMode below gives the install mode of the
// record.
//
//  - ssInstall, before [Files] (DeleteInstallState): deletes install.ini of the previous run and a
//    temporary file an aborted run left, so that an aborted installation leaves no install.ini that
//    claims a valid state. A file that cannot be deleted (read-only, held open by a program without
//    FILE_SHARE_DELETE) is logged and remembered.
//  - end of ssPostInstall, after every other step (WriteInstallState): writes install.ini as ASCII
//    with CRLF through install.ini.tmp (ReplaceStateFile: the target is deleted and must be gone
//    before the rename, which never overwrites), then, in the Regular variants, the value
//    'Empire Earth Community: ContractVersion' into the uninstall key, but only if no deletion at
//    ssInstall and no step of the writing failed (ShouldWriteContractVersionValue). Inno Setup has
//    recreated the uninstall key in this run, so without the value the launcher reports the state
//    Unknown instead of trusting files of an earlier run (also of a setup up to 1.7.2 that runs
//    later). A failure is logged, it never stops the installation. Portable setups have no
//    uninstall key: there an install.ini that could not be replaced stays undetected (logged).
// S-WP7 adds the integrity manifest files.sha256 to both steps.
//
// The setup data folder {app}\{#SetupDataDir} is created by [Dirs]; only administrators (admin
// mode) or the installing user (user and portable mode) can write to it.
// Requires: utils.iss (InstallModeName, BuildInstallIniText, ShouldWriteContractVersionValue,
// DeleteStateFile, ReplaceStateFile, StateFileTempSuffix, InstallIniFileName, GetUninstallRegPath); ISPP:
// ContractVersion, InstallType, InstallMode, AppID, MyAppVersion, MySetupVersion, SetupBuild,
// SetupDataDir (setup_is6.iss, config_*.iss).

const
  // Value of the uninstall key (contract 1.3), REG_DWORD = ContractVersion
  ContractVersionValueName = 'Empire Earth Community: ContractVersion';
  // Variant of this build: Portable has no uninstall key and no install record
  IsPortableVariant = {#InstallMode == "Portable" ? "True" : "False"};

var
  // ssInstall could not delete a state file of the previous run (DeleteInstallState)
  InstallStateDeleteFailed: Boolean;

// install.ini in the setup data folder
function GetInstallIniPath: String;
begin
  Result := ExpandConstant('{app}\{#SetupDataDir}\') + InstallIniFileName;
end;

// [Registry] InstallMode of the install record (contract 1.1): admin or user; install.ini also
// portable
function GetContractInstallMode(Param: String): String;
begin
  Result := InstallModeName(IsPortableVariant, IsAdminInstallMode);
end;

// ssInstall, before [Files]: deletes install.ini and install.ini.tmp of the previous run
procedure DeleteInstallState;
var
  IniPath: String;
begin
  InstallStateDeleteFailed := False;
  try
    IniPath := GetInstallIniPath();
    if not DeleteStateFile(IniPath) then
      InstallStateDeleteFailed := True;
    if not DeleteStateFile(IniPath + StateFileTempSuffix) then
      InstallStateDeleteFailed := True;
  except
    InstallStateDeleteFailed := True;
    Log('Unable to delete the install state of the previous run: ' + GetExceptionMessage);
  end;
  if not InstallStateDeleteFailed then
    Log('Install state of the previous run deleted (or there was none): ' + IniPath)
  else if IsPortableVariant then
    Log('The install state of the previous run could not be deleted (portable setup: not visible to the launcher, ' +
      'contract 2.5)')
  else
    Log('The install state of the previous run could not be deleted: this run writes no "' + ContractVersionValueName +
      '" into the uninstall key, so the launcher does not trust it (contract 2.5)');
end;

// End of ssPostInstall: the contract version in the uninstall key of the Regular variants, if
// StateWritten (install.ini written) and no deletion at ssInstall failed
procedure WriteContractVersionValue(const StateWritten: Boolean);
var
  Key: String;
begin
  if not ShouldWriteContractVersionValue(not IsPortableVariant, not InstallStateDeleteFailed, StateWritten) then
  begin
    if IsPortableVariant then
      Log('Portable setup: no uninstall key, so a later run of an older setup or an install state that could not be ' +
        'replaced cannot be shown to the launcher (contract 2.5)')
    else if InstallStateDeleteFailed then
      Log('Not writing "' + ContractVersionValueName + '" into the uninstall key: the install state of the previous ' +
        'run could not be deleted at ssInstall; the launcher reports the state Unknown (contract 2.5)')
    else
      Log('Not writing "' + ContractVersionValueName + '" into the uninstall key: install.ini of this run could not ' +
        'be written; the launcher reports the state Unknown (contract 2.5)');
    Exit;
  end;
  Key := GetUninstallRegPath();
  if not RegKeyExists(HKA, Key) then
    Log('Uninstall key not found, "' + ContractVersionValueName + '" not written')
  else if RegWriteDWordValue(HKA, Key, ContractVersionValueName, {#ContractVersion}) then
    Log('Wrote "' + ContractVersionValueName + '" = {#ContractVersion} into the uninstall key')
  else
    Log('Unable to write "' + ContractVersionValueName + '" into the uninstall key');
end;

// End of ssPostInstall, the last step: install.ini, then the contract version in the uninstall key
procedure WriteInstallState;
var
  IniPath, Text: String;
  IniWritten: Boolean;
begin
  IniWritten := False;
  IniPath := '';
  try
    IniPath := GetInstallIniPath();
    Text := BuildInstallIniText({#ContractVersion}, '{#InstallType}', '{#AppID}', GetContractInstallMode(''),
      '{#MyAppVersion}', '{#MySetupVersion}', '{#SetupBuild}', WizardSelectedComponents(False),
      WizardSelectedTasks(False), GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':'));
    IniWritten := ReplaceStateFile(IniPath, Text);
  except
    Log('Unable to write ' + IniPath + ': ' + GetExceptionMessage);
  end;
  if IniWritten then
    Log('Wrote ' + IniPath + ' (contract version {#ContractVersion}, install mode ' + GetContractInstallMode('') + ')');
  WriteContractVersionValue(IniWritten);
end;
