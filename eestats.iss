[Code]
// EEStatsSetup.dll: what the setup needs to know about the system (Wine, graphics card) and the
// values of the setup statistics. The rest of the script calls the functions of this file, never
// the DLL imports.
//
// The setup loads the DLL from its own temporary files ("files:", setuponly), the uninstaller from
// {app}\{#SetupDataDir} (uninstallonly): Inno Setup has no import that works in both, so a function
// both of them need is imported twice and its function here chooses the import by IsUninstaller.
// That is only IsWine; the other functions are setup only (the uninstaller cannot call them).
// Uses: SetupDataDir (setup_is6.iss).

  function EEStats_runInVM: BOOL;
    external 'EEStats_runInVM@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getUID: PAnsiChar;
    external 'EEStats_getUID@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_isWine: BOOL;
    external 'EEStats_isWine@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getWineVersion: PAnsiChar;
    external 'EEStats_getWineVersion@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getProcessorArch: PAnsiChar;
    external 'EEStats_getProcessorArch@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getGpuVendorId: PAnsiChar;
    external 'EEStats_getGpuVendorId@files:EEStatsSetup.dll cdecl setuponly';

  // The uninstaller cannot use "files:" DLLs, it loads EEStatsSetup.dll from {app}\{#SetupDataDir}.
  // delayload: the DLL is only loaded when the function is called (IsWine catches a failure), so a
  // missing DLL cannot stop the uninstaller from starting. The current uninstall code never calls
  // it, so the elevated uninstaller does not load code from the installation folder.
  function EEStats_isWine_U: BOOL;
    external 'EEStats_isWine@{app}\{#SetupDataDir}\EEStatsSetup.dll cdecl uninstallonly delayload';

// Setup and uninstaller: True under Wine
function IsWine(): Boolean;
begin
  if not IsUninstaller then
    Result := EEStats_IsWine()
  else
  begin
    try
      Result := EEStats_IsWine_U();
    except
      // EEStatsSetup.dll missing or not loadable (e.g. removed by an anti-virus): assume Windows
      Log('Unable to use EEStatsSetup.dll, assuming Windows: ' + GetExceptionMessage);
      Result := False;
    end;
  end;
end;

// Setup only: the Wine version
function GetWineVersion(): String;
begin
  Result := String(EEStats_getWineVersion());
end;

// Setup only: PCI vendor id of the graphics card ('10DE' NVIDIA, '1002' AMD, '8086' Intel)
function GetGpuVendorId(): String;
begin
  Result := String(EEStats_getGpuVendorId());
end;

// Setup only, setup statistics: processor architecture
function GetProcessorArch(): String;
begin
  Result := String(EEStats_getProcessorArch());
end;

// Setup only, setup statistics: anonymous id of this computer
function GetEEStatsUID(): String;
begin
  Result := String(EEStats_getUID());
end;

// Setup only, setup statistics: virtual machine detected (the DLL's BOOL as it is)
function IsRunningInVM(): BOOL;
begin
  Result := EEStats_runInVM();
end;
