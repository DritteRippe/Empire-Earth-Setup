[Code]
// Install state for the Empire Earth Launcher: install.ini, the integrity manifest files.sha256
// and the contract version in the uninstall key (docs/CONTRACT.md 1.2, 1.3, 2 and 2.5;
// docs/adr/0004-install-record-and-integrity-manifest.md points 3 to 9). The install record and the
// defaults marker are [Registry] entries of setup_is6.iss (contract 1.1, 3.5);
// GetContractInstallMode below gives the install mode of the record.
//
//  - ssInstall, before [Files] (DeleteInstallState): deletes install.ini and files.sha256 of the
//    previous run and the temporary files an aborted run left, so that an aborted installation
//    leaves no state file that claims a valid state. A file that cannot be deleted (read-only, held
//    open by a program without FILE_SHARE_DELETE) is logged and remembered.
//  - [Files] (RecordInstalledFile, the AfterInstall of every compiled entry below {app}): records
//    the destination of every file the run processed.
//  - end of ssPostInstall, after every other step (WriteInstallState): adds the verified online
//    files of the external entries (RecordVerifiedOnlineFiles), hashes every recorded file on an
//    output progress page (WriteInstallStateFiles in utils.iss: sorted, unique, retries for a
//    locked file, the summary line in the log) and writes files.sha256 (ASCII, LF) and install.ini
//    (ASCII, CRLF, with [MissingAfterInstall]) through their .tmp files (ReplaceStateFile: the target
//    is deleted and must be gone before the rename, which never overwrites). Files that are gone are
//    logged and named in one notice (antivirus exception, repair; not in silent mode or with
//    /SUPPRESSMSGBOXES). Then, in the Regular variants, the value
//    'Empire Earth Community: ContractVersion' goes into the uninstall key, but only if no deletion
//    at ssInstall and no step of writing both files failed (ShouldWriteContractVersionValue). Inno
//    Setup has recreated the uninstall key in this run, so without the value the launcher reports
//    the state Unknown instead of trusting files of an earlier run (also of a setup up to 1.7.2
//    that runs later). A failure is logged, it never stops the installation. Portable setups have
//    no uninstall key: there state files that could not be replaced stay undetected (logged).
//
// The setup data folder {app}\{#SetupDataDir} is created by [Dirs]; only administrators (admin
// mode) or the installing user (user and portable mode) can write to it.
// Requires: utils.iss (InstallModeName, BuildInstallIniText, ShouldWriteContractVersionValue,
// DeleteStateFile, StateFileTempSuffix, InstallIniFileName, ManifestFileName, CollectExternalFiles,
// WriteInstallStateFiles, FormatMissingFileList, MissingFilesShownMax, GetUninstallRegPath),
// extension.iss (SilentInstall, SuppressMsgBoxes), the Manifest* and FilesMissingAfterInstall*
// messages (messages.iss); ISPP: ContractVersion, InstallType, InstallMode, AppID, MyAppVersion,
// MySetupVersion, SetupBuild, SetupDataDir, EEDir, AoCDir (setup_is6.iss, config_*.iss).

const
  // Value of the uninstall key (contract 1.3), REG_DWORD = ContractVersion
  ContractVersionValueName = 'Empire Earth Community: ContractVersion';
  // Variant of this build: Portable has no uninstall key and no install record
  IsPortableVariant = {#InstallMode == "Portable" ? "True" : "False"};

var
  // ssInstall could not delete a state file of the previous run (DeleteInstallState)
  InstallStateDeleteFailed: Boolean;
  // Destinations (full paths) of the [Files] entries this run processed, recorded by
  // RecordInstalledFile, and the number of destinations it could not record
  InstalledFiles: TStringList;
  RecordFailures: Integer;
  // Shown while the installed files are hashed (CreateManifestProgressPage, WriteInstallState)
  ManifestProgressPage: TOutputProgressWizardPage;

// AfterInstall of every compiled [Files] entry below {app} (ADR 0004 point 3; ci/check_contract.py
// checks that each has it): records the destination of the file the entry has just installed or
// kept (Inno Setup calls AfterInstall in both cases). It only appends to a list: no I/O, and no
// exception escapes, because an exception in AfterInstall would abort the installation. A
// destination that cannot be recorded is counted, and this run then writes no manifest.
procedure RecordInstalledFile;
begin
  try
    if InstalledFiles = nil then
      InstalledFiles := TStringList.Create;
    InstalledFiles.Add(ExpandConstant(CurrentFileName));
  except
    RecordFailures := RecordFailures + 1;
  end;
end;

// install.ini in the setup data folder
function GetInstallIniPath: String;
begin
  Result := ExpandConstant('{app}\{#SetupDataDir}\') + InstallIniFileName;
end;

// files.sha256 in the setup data folder
function GetManifestFilePath: String;
begin
  Result := ExpandConstant('{app}\{#SetupDataDir}\') + ManifestFileName;
end;

// InitializeWizard: the page WriteInstallState shows while it hashes the installed files. Its
// SetText and SetProgress process window messages, so the wizard stays responsive.
procedure CreateManifestProgressPage;
begin
  ManifestProgressPage := CreateOutputProgressPage(CustomMessage('ManifestPageCaption'), CustomMessage('ManifestPageDescription'));
end;

// [Registry] InstallMode of the install record (contract 1.1): admin or user; install.ini also
// portable
function GetContractInstallMode(Param: String): String;
begin
  Result := InstallModeName(IsPortableVariant, IsAdminInstallMode);
end;

// ssInstall, before [Files]: deletes install.ini, files.sha256 and their .tmp files of the previous
// run
procedure DeleteInstallState;
var
  IniPath, ManifestPath: String;
begin
  InstallStateDeleteFailed := False;
  IniPath := '';
  ManifestPath := '';
  try
    IniPath := GetInstallIniPath();
    ManifestPath := GetManifestFilePath();
    if not DeleteStateFile(IniPath) then
      InstallStateDeleteFailed := True;
    if not DeleteStateFile(IniPath + StateFileTempSuffix) then
      InstallStateDeleteFailed := True;
    if not DeleteStateFile(ManifestPath) then
      InstallStateDeleteFailed := True;
    if not DeleteStateFile(ManifestPath + StateFileTempSuffix) then
      InstallStateDeleteFailed := True;
  except
    InstallStateDeleteFailed := True;
    Log('Unable to delete the install state of the previous run: ' + GetExceptionMessage);
  end;
  if not InstallStateDeleteFailed then
    Log('Install state of the previous run deleted (or there was none): ' + IniPath + ', ' + ManifestPath)
  else if IsPortableVariant then
    Log('The install state of the previous run could not be deleted (portable setup: not visible to the launcher, ' +
      'contract 2.5)')
  else
    Log('The install state of the previous run could not be deleted: this run writes no "' + ContractVersionValueName +
      '" into the uninstall key, so the launcher does not trust it (contract 2.5)');
end;

// End of ssPostInstall: the contract version in the uninstall key of the Regular variants, if
// StateWritten (install.ini and files.sha256 written) and no deletion at ssInstall failed
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
      Log('Not writing "' + ContractVersionValueName + '" into the uninstall key: install.ini or files.sha256 of ' +
        'this run could not be written; the launcher reports the state Unknown (contract 2.5)');
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

// The verified online files (downloads.iss) that the three external [Files] entries of
// {tmp}\verified installed, with the same folders and components as those entries (their
// AfterInstall would only see the folder): {tmp}\verified\EE to the EE folder, {tmp}\verified\AoC
// to the AoC folder, and the learning campaign of EE also to the AoC folder (setup_is6.iss, [Files];
// change both together; ci/check_contract.py compares both sides, rule "2.3"). The files are
// still in {tmp} at ssPostInstall.
procedure RecordVerifiedOnlineFiles;
var
  Campaign: String;
begin
  if not WizardIsComponentSelected('language\update') then
    Exit;
  if WizardIsComponentSelected('game') then
    CollectExternalFiles(ExpandConstant('{tmp}\verified\EE'), ExpandConstant('{app}\{#EEDir}'), InstalledFiles);
  if WizardIsComponentSelected('gameaoc') then
  begin
    CollectExternalFiles(ExpandConstant('{tmp}\verified\AoC'), ExpandConstant('{app}\{#AoCDir}'), InstalledFiles);
    // The same source and destination as the [Files] entry
    Campaign := ExpandConstant('{tmp}\verified\EE\Data\Campaigns\EELearningCampaign.ssa');
    if FileExists(Campaign) then
      InstalledFiles.Add(ExpandConstant('{app}\{#AoCDir}\Data\Campaigns\EELearningCampaign.ssa'));
  end;
end;

// Logs every installed file that was gone at the end of the installation and names them in one
// notice (ADR 0004 point 7): antivirus exception for the installation folder, then a repair. Only
// the log in silent mode and with /SUPPRESSMSGBOXES.
procedure ReportMissingFiles(const Missing: TArrayOfString);
var
  List: String;
begin
  if GetArrayLength(Missing) = 0 then
    Exit;
  Log(IntToStr(GetArrayLength(Missing)) + ' installed files were missing at the end of the installation, listed in ' +
    '[MissingAfterInstall] of install.ini (see the lines "Installed file missing" above)');
  if SilentInstall or SuppressMsgBoxes then
    Exit;
  List := FormatMissingFileList(Missing, MissingFilesShownMax, CustomMessage('FilesMissingAfterInstallMore'));
  MsgBox(FmtMessage(CustomMessage('FilesMissingAfterInstall'), [List, ExpandConstant('{app}')]), mbError, MB_OK);
end;

// End of ssPostInstall, the last step: files.sha256 and install.ini (WriteInstallStateFiles), the
// notice about files that are gone, then the contract version in the uninstall key
procedure WriteInstallState;
var
  IniPath, Text: String;
  IniWritten, ManifestWritten: Boolean;
  Missing: TArrayOfString;
begin
  IniWritten := False;
  ManifestWritten := False;
  SetArrayLength(Missing, 0);
  IniPath := '';
  try
    if InstalledFiles = nil then
      InstalledFiles := TStringList.Create;
    if RecordFailures > 0 then
      Log(IntToStr(RecordFailures) + ' installed files could not be recorded for the manifest');
    RecordVerifiedOnlineFiles();
    IniPath := GetInstallIniPath();
    Text := BuildInstallIniText({#ContractVersion}, '{#InstallType}', '{#AppID}', GetContractInstallMode(''),
      '{#MyAppVersion}', '{#MySetupVersion}', '{#SetupBuild}', WizardSelectedComponents(False),
      WizardSelectedTasks(False), GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':'));
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Checking ' + IntToStr(InstalledFiles.Count) + ' recorded destinations of installed files for ' + GetManifestFilePath());
    if ManifestProgressPage <> nil then
    begin
      ManifestProgressPage.SetText(CustomMessage('ManifestPageStatus'), '');
      ManifestProgressPage.SetProgress(0, 0);
      ManifestProgressPage.Show;
    end;
    try
      IniWritten := WriteInstallStateFiles(ExpandConstant('{app}'), '{#SetupDataDir}', InstalledFiles, RecordFailures = 0,
        Text, ManifestProgressPage, CustomMessage('ManifestPageStatus'), ManifestWritten, Missing);
    finally
      if ManifestProgressPage <> nil then
        ManifestProgressPage.Hide;
    end;
  except
    Log('Unable to write the install state ' + IniPath + ': ' + GetExceptionMessage);
  end;
  if IniWritten then
    Log('Wrote ' + IniPath + ' (contract version {#ContractVersion}, install mode ' + GetContractInstallMode('') + ')');
  ReportMissingFiles(Missing);
  WriteContractVersionValue(IniWritten and ManifestWritten);
end;
