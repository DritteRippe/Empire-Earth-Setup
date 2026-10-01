[Code]
// Setup statistics (telemetry): one request to TelemetryApiURL when the user leaves the finished
// page. Only sent with consent, i.e. when the telemetry component of this product is selected in
// this setup (check box of the installation mode page, or the component in the custom settings):
// otherwise no request is made at all. The uninstaller never sends any.
// Requires: TelemetryApiURL, GetSelectedLanguageFromComponents, GetLanguageTag
// (setup_is6.iss), AppID, MySetupVersion, MyAppVersion (ISPP, setup_is6.iss), UrlEncode,
// GetHttpStatus, IsGameInstalled (utils.iss), WizardIsUpdate (extension.iss), IsWine,
// GetWineVersion, GetProcessorArch, GetEEStatsUID, IsRunningInVM (eestats.iss).

var
  // The previous installation as RecordInstallStateForTelemetry found it: at the end of the
  // installation the uninstall key already describes the new one
  TelemetryWasInstalled, TelemetryWasUpdate: Boolean;

// InitializeWizard, before anything is installed
procedure RecordInstallStateForTelemetry;
begin
  TelemetryWasUpdate := WizardIsUpdate();
  TelemetryWasInstalled := IsGameInstalled();
end;

procedure SendSetupTelemetry();
var
  InstallUrlStats: String;
begin
  if (IsUninstaller or not WizardIsComponentSelected('additional\telemetry')) then
  begin
    Log('Setup stats not sent (no consent)');
    Exit;
  end;

  Log('Sending setup stats over HTTPS!');
  InstallUrlStats := TelemetryApiURL
    + '?install_type=' + UrlEncode('{#AppID}')
    + '&install_lang=' + UrlEncode(GetLanguageTag(GetSelectedLanguageFromComponents()))
    + '&is_uninstall=0'
    + '&setup_version=' + UrlEncode('{#MySetupVersion}')
    + '&game_version=' + UrlEncode('{#MyAppVersion}')
    + '&components=' + UrlEncode(WizardSelectedComponents(False))
    + '&tasks=' + UrlEncode(WizardSelectedTasks(False))
    + '&arch=' + UrlEncode(GetProcessorArch())
    + '&user_uid=' + UrlEncode(GetEEStatsUID());

  if (TelemetryWasInstalled) then
    InstallUrlStats := InstallUrlStats + '&already_installed=1&install_update=' + IntToStr(Integer(TelemetryWasUpdate))
  else
    InstallUrlStats := InstallUrlStats + '&already_installed=0&install_update=0';

  InstallUrlStats := InstallUrlStats + '&os_virtual_machine=' + IntToStr(Integer(IsRunningInVM()));

  if (IsWine()) then
    InstallUrlStats := InstallUrlStats + '&wine=1&os_version=' + UrlEncode(GetWineVersion())
  else
    InstallUrlStats := InstallUrlStats + '&os_version=' + UrlEncode(GetWindowsVersionString()) + '&wine=0';

  // Synchronous like every request (see HttpGet), the answer does not matter
  GetHttpStatus(InstallUrlStats);
end;
