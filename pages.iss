[Code]
// The custom wizard pages: game language, installation mode and graphics card. The code refers
// to their options by the indexes stored below, never by literal numbers: options are only
// added under conditions (repair/update), so the index of the ones after them changes.

var
  LanguageInstallQuestionPage: TInputOptionWizardPage;
  ManualInstallQuestionPage: TInputOptionWizardPage;
  GPUInstallQuestionPage: TInputOptionWizardPage;
  // Options of ManualInstallQuestionPage, as returned by AddEx. MiqpRecommended is checked
  // together with one of its game choices MiqpRecommendedEE or MiqpRecommendedEEAoC.
  // MiqpRepairOrUpdate is -1 if the game is not installed (the option is not on the page then).
  MiqpRecommended, MiqpRecommendedEE, MiqpRecommendedEEAoC, MiqpCustom: Integer;
  MiqpRepairOrUpdate, MiqpTelemetry: Integer;

const
  // PCI vendor ids of the graphics card makers (GetGpuVendorId, eestats.iss)
  GpuVendorNVIDIA = '10DE';
  GpuVendorAMD = '1002';
  GpuVendorIntel = '8086';

type
  // One option of GPUInstallQuestionPage: what it shows and the DirectX wrapper it selects
  TGpuOption = record
    LogName: String;     // name in the log
    LabelKey: String;    // custom message of the option
    Wrapper: String;     // DirectX wrapper shown after the label, '' if none
    Components: String;  // what the option selects, in WizardSelectComponents syntax
    VendorId: String;    // preselected for graphics cards of this vendor, '' if none
  end;

var
  // The options of the GPU page, in their order on the page (index = option index)
  GpuOptions: array of TGpuOption;
  // Option preselected if the vendor of the graphics card is not in GpuOptions
  GpuUnknownVendorOption: Integer;

procedure AddGpuOption(const LogName, LabelKey, Wrapper, Components, VendorId: String);
var
  N: Integer;
begin
  N := GetArrayLength(GpuOptions);
  SetArrayLength(GpuOptions, N + 1);
  GpuOptions[N].LogName := LogName;
  GpuOptions[N].LabelKey := LabelKey;
  GpuOptions[N].Wrapper := Wrapper;
  GpuOptions[N].Components := Components;
  GpuOptions[N].VendorId := VendorId;
end;

// The only place that defines the GPU page: label, DirectX wrapper component
// (additional\directx_wrapper\... in [Components]) and preselecting vendor of every option
procedure RegisterGpuOptions;
begin
  SetArrayLength(GpuOptions, 0);
  AddGpuOption('NVIDIA', 'GPUIQP_NVIDIA', 'DirectX Wrapper 11 API 11', 'additional\directx_wrapper\dx11_lvl11', GpuVendorNVIDIA);
  // AMD: feature level 11 only from Windows 10 on
  if IsWindows10OrNewer then
    AddGpuOption('AMD', 'GPUIQP_AMD', 'DirectX Wrapper 11 API 11', 'additional\directx_wrapper\dx11_lvl11', GpuVendorAMD)
  else
    AddGpuOption('AMD', 'GPUIQP_AMD', 'DirectX Wrapper 11 API 10.1', 'additional\directx_wrapper\dx11_lvl10_1', GpuVendorAMD);
  // Intel: feature level 10.1, Intel HD Graphics 2000/3000 do not support level 11
  // (https://www.intel.com/content/www/us/en/support/articles/000005524/graphics.html)
  AddGpuOption('Intel', 'GPUIQP_Intel', 'DirectX Wrapper 11 API 10.1', 'additional\directx_wrapper\dx11_lvl10_1', GpuVendorIntel);
  // "I don't know": DirectX 9, the most compatible wrapper; also for unknown vendors
  GpuUnknownVendorOption := GetArrayLength(GpuOptions);
  AddGpuOption('general', 'GPUIQP_Default', 'DirectX Wrapper 9', 'additional\directx_wrapper\dx9', '');
  // No DirectX wrapper
  AddGpuOption('native', 'GPUIQP_Native', '', '!additional\directx_wrapper', '');
end;

function GetGpuOptionCaption(const Option: TGpuOption): String;
begin
  Result := '&' + CustomMessage(Option.LabelKey);
  if Option.Wrapper <> '' then
    Result := Result + ' (' + Option.Wrapper + ')';
end;

// Read Selected Components to try to find the language: 'en' if no components are recorded,
// '' if none of them is a language
function GetSelectedLanguageFromRegistry(): String;
var
  i: Integer;
  Components: String;
begin
  if (not RegQueryStringValue(HKA, GetUninstallRegPath(), 'Inno Setup: Selected Components', Components)
      or (Components = '')) then
  begin
    Result := 'en';
    Exit;
  end;

  Result := '';
  for i := 0 to Langs.Count - 1 do
  begin
    if (WizardIsComponentInstalled('language\' + Langs[i])) then
    begin
      Result := Langs[i];
      Exit;
    end;
  end;
end;


procedure SetupLanguagePage;
var
  i: Integer;
  LanguageSelected: Boolean;
begin
  // Language page. No sub caption: the former one explained "*"/"**" quality markers that no
  // language name carries. Add it back together with the markers if they are introduced.
  Log('Create language page');
  LanguageInstallQuestionPage := CreateInputOptionPage(wpSelectDir,
    ExpandConstant('{cm:LIQP_Title}'), ExpandConstant('{cm:LIQP_Desc}'),
    '', True, True);

  // Register all langs to the page
  // Auto select the language in the list from the one used by the OS
  LanguageSelected := False;
  for i := 0 to Langs.Count - 1 do
  begin
    LanguageInstallQuestionPage.AddEx({ '&' + } ExpandConstant('{cm:LIQP_' + Langs[i] + '}'), 0, True);
    if (Langs[i] = ActiveLanguage) then
    begin
      LanguageInstallQuestionPage.Values[i] := True;
      LanguageSelected := True;
      // Break; not break, because we want to register all langs to the page
    end;
  end;

  // If the language is not found, select english
  if (not LanguageSelected) then
  begin
    for i := 0 to Langs.Count - 1 do
    begin
      if (Langs[i] = 'en') then
      begin
        LanguageInstallQuestionPage.Values[i] := True;
        LanguageSelected := True;
        Break;
      end;
    end;
  end;

  // If game is installed, try to find the language from the registry
  if (IsGameInstalled()) then
  begin
    for i := 0 to Langs.Count - 1 do
    begin
      if (Langs[i] = GetSelectedLanguageFromRegistry()) then
      begin
        LanguageInstallQuestionPage.Values[i] := True;
        LanguageSelected := True;
        Break;
      end;
    end;
  end;

  // Last resort, select the first language in the list
  if (not LanguageSelected) then
    LanguageInstallQuestionPage.Values[0] := True;

end;

procedure SetupManualCustomInstallPage;
begin
// Manual or custom install page
  Log('Create install manual/custom page');
  ManualInstallQuestionPage :=
    CreateInputOptionPage(LanguageInstallQuestionPage.ID, ExpandConstant('{cm:MIQP_Title}'),
      ExpandConstant('{cm:MIQP_Desc}'), ExpandConstant('{cm:MIQP_Content}'), True, False);

  // Recommended settings with the choice of the games, or custom settings (all pages)
  MiqpRecommended := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Recommended}'), 1, True);
  MiqpRecommendedEE := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Recommended_EE}'), 1, True);
  MiqpRecommendedEEAoC := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Recommended_EE_AoC}'), 1, True);
  MiqpCustom := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Custom}'), 0, True);
  ManualInstallQuestionPage.Values[MiqpRecommended] := True;
  ManualInstallQuestionPage.Values[MiqpRecommendedEE] := True;

  // Repair or update the current installation, preselected if there is one
  MiqpRepairOrUpdate := -1;
  if (IsGameInstalled()) then
  begin
    if (WizardIsUpdate()) then
      MiqpRepairOrUpdate := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Update}'), 0, True)
    else
      MiqpRepairOrUpdate := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Repair}'), 0, True);
    ManualInstallQuestionPage.Values[MiqpRepairOrUpdate] := True;
  end;

  // Telemetry consent (check box). Pre-checked only if this product was installed with
  // telemetry: the consent given for the other product (EE <-> NeoEE) does not count for this one
  MiqpTelemetry := ManualInstallQuestionPage.AddEx('&' + ExpandConstant('{cm:MIQP_Telemetry}'), 0, False);
  if (IsGameInstalled() and WizardIsComponentInstalled('additional\telemetry')) then
    ManualInstallQuestionPage.Values[MiqpTelemetry] := True;
end;

// Graphics card page: preselects the option of the detected vendor (see RegisterGpuOptions)
procedure SetupGPUInstallPage;
var
  VendorId: String;
  I, Selected: Integer;
begin
  Log('Create GPU DirectX Wrapper selection');
  GPUInstallQuestionPage :=
    CreateInputOptionPage(ManualInstallQuestionPage.ID, ExpandConstant('{cm:GPUIQP_Title}'),
      ExpandConstant('{cm:GPUIQP_Desc}'), ExpandConstant('{cm:GPUIQP_Content}'), True, False);

  RegisterGpuOptions();
  for I := 0 to GetArrayLength(GpuOptions) - 1 do
    GPUInstallQuestionPage.Add(GetGpuOptionCaption(GpuOptions[I]));

  VendorId := GetGpuVendorId();
  Selected := GpuUnknownVendorOption;
  for I := 0 to GetArrayLength(GpuOptions) - 1 do
    if (GpuOptions[I].VendorId <> '') and (GpuOptions[I].VendorId = VendorId) then
    begin
      Selected := I;
      Break;
    end;
  if (Selected = GpuUnknownVendorOption) then
    Log('Unknown GPU detected')
  else
    Log(GpuOptions[Selected].LogName + ' GPU detected');
  GPUInstallQuestionPage.Values[Selected] := True;
end;

// NextButtonClick of the GPU page: selects the DirectX wrapper of the checked option
procedure ApplyGpuOption;
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(GpuOptions) - 1 do
    if (GPUInstallQuestionPage.Values[I]) then
    begin
      Log('Using ' + GpuOptions[I].LogName + ' GPU settings: ' + GpuOptions[I].Components);
      WizardSelectComponents(GpuOptions[I].Components);
      Break;
    end;
end;