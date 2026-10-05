[Code]
// The suite record (contract 1.6): the key Software\Empire Earth Community\Suite in HKLM, which is the
// 64-bit view in the 64-bit install mode of the suite. Written by every run of the suite after the
// product setups (at ssPostInstall, in code: ADR 0013 Evidence), removed by its uninstaller. The
// launcher may read it, read-only, for its repair advice (contract 4.4); the products have their own
// records and the launcher finds them without it.
// The value names and types are those of the table of contract 1.6; ci/check_contract.py compares them
// with the RegWrite... calls below, so every value is written by one call with literal names.
// Requires: SuiteMergeProducts (suite_common.iss), SuiteProductsOk (suite.iss), the defines SuiteRecordKey,
// ContractVersion, SuiteVersion, EE_AppID, NeoEE_AppID.

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
