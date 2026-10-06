[Code]
// The suite record (contract 1.6): the key Software\Empire Earth Community\Suite in HKLM, which is the
// 64-bit view in the 64-bit install mode of the suite. Written by every run of the suite after the
// product setups (at ssPostInstall, in code: ADR 0013 Evidence), removed by its uninstaller. The
// launcher may read it, read-only, for its repair advice (contract 4.4) and to recognise the uninstall key
// of a suite built before revision 5 (contract 1.4, source 3); the products have their own records and
// the launcher finds them without it.
// The value names and types are those of the table of contract 1.6; ci/check_contract.py compares them
// with the RegWrite... calls below, so every value is written by one call with literal names.
// MarkSuiteUninstallKey (contract 0 "Suite and launcher", 1.3, revision 5) marks the uninstall key of the
// suite itself, see there. ci/check_contract.py compares its RegWrite call with the row "Suite uninstall
// key marker" of contract 0.
// Requires: SuiteMergeProducts, SuiteUninstallKey (suite_common.iss), SuiteProductsOk (suite.iss), the defines
// SuiteRecordKey, ContractVersion, SuiteVersion, SuiteAppID, EE_AppID, NeoEE_AppID.

// Writes the record. Products lists the products of this run that succeeded and those of the
// earlier runs of the suite (a product that an earlier run listed stays listed, contract 1.6).
procedure WriteSuiteRecord;
var
  Earlier: String;
begin
  Earlier := '';
  RegQueryStringValue(HKLM, '{#SuiteRecordKey}', 'Products', Earlier);
  RegWriteDWordValue(HKLM, '{#SuiteRecordKey}', 'ContractVersion', {#ContractVersion});
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'SuiteVersion', '{#SuiteVersion}');
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'InstallPath', RemoveBackslash(ExpandConstant('{app}')));
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'Products', SuiteMergeProducts(Earlier, SuiteProductsOk));
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'SourceDir', RemoveBackslash(ExpandConstant('{src}')));
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'EEAppId', '{#EE_AppID}');
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'NeoEEAppId', '{#NeoEE_AppID}');
  RegWriteStringValue(HKLM, '{#SuiteRecordKey}', 'Written', GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'));
  Log('Suite record written: ' + SuiteMergeProducts(Earlier, SuiteProductsOk));
end;

// Removes the record (the uninstaller). The key of the suite with all its values, then the key
// Empire Earth Community above it if nothing else is in it. Nothing else is touched.
procedure RemoveSuiteRecord;
begin
  RegDeleteKeyIncludingSubkeys(HKLM, '{#SuiteRecordKey}');
  RegDeleteKeyIfEmpty(HKLM, 'Software\Empire Earth Community');
end;

// Marks the uninstall key of the suite (contract 0 "Suite and launcher", 1.3, revision 5): the value
// "Empire Earth Community: Suite" = 1. Inno Setup wrote the key before ssPostInstall, with the Publisher of
// EE ("Empire Earth Community", which Windows "Apps" shows and by which the product setups do not report
// the suite as a foreign installation, ADR 0007). The value tells the launcher that this key is no
// installation of EE (contract 1.4, source 3). Every run writes it, because Inno Setup deletes and
// rewrites the key (as the products do for ContractVersion); the uninstaller removes it with the key.
// Written only to an existing key, so no stub key is created. HKLM is the 64-bit view in the 64-bit
// install mode of the suite (the key of Inno Setup is there too).
procedure MarkSuiteUninstallKey;
var
  Marker: Cardinal;
begin
  if not RegKeyExists(HKLM, SuiteUninstallKey('{#SuiteAppID}')) then
  begin
    Log('Uninstall key of the suite not found, "Empire Earth Community: Suite" not written');
    Exit;
  end;
  RegWriteDWordValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);
  if RegQueryDWordValue(HKLM, SuiteUninstallKey('{#SuiteAppID}'), 'Empire Earth Community: Suite', Marker) and (Marker = 1) then
    Log('Uninstall key of the suite marked ("Empire Earth Community: Suite" = 1)')
  else
    Log('Unable to write "Empire Earth Community: Suite" into the uninstall key of the suite');
end;
