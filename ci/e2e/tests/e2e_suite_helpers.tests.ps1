<#
.SYNOPSIS
  Tests of ci\e2e\e2e_suite_helpers.ps1, the rules of the suite end-to-end scenarios S1 to S10, with fake data.

.DESCRIPTION
  The command lines of the suite and of the product setups it runs (valid ones must pass, each kind of defect must be
  reported), the shortcuts, the checksum file of the package, the suite record, the snapshot lines of the CD key dummy
  and the summary of the results are fed with made-up input. No registry, no process, no network, no game data; runs
  with Windows PowerShell 5.1 and PowerShell 7 (also on Linux). The scripts that touch Windows
  (e2e_suite_scenarios.ps1, run_e2e_suite.ps1) are only parsed by e2e_helpers.tests.ps1, they run in the job suite-e2e
  of .github/workflows/build.yml. Prints the failed checks and exits with 0 if every check passed, else 1.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\e2e\tests\e2e_suite_helpers.tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$E2EFolder = Split-Path -Parent $PSScriptRoot
. (Join-Path $E2EFolder 'e2e_helpers.ps1')
. (Join-Path $E2EFolder 'e2e_suite_helpers.ps1')

$script:Count = 0
$script:Failures = 0
function Check([string]$Name, $Actual, $Expected) {
  $script:Count++
  if ("$Actual" -ceq "$Expected") { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: got '$Actual', expected '$Expected'"
}
# Problems must contain a line matching Pattern (or be empty when Pattern is '')
function CheckProblems([string]$Name, [object[]]$Problems, [string]$Pattern) {
  $script:Count++
  $list = @($Problems | Where-Object { $_ })
  if (-not $Pattern) {
    if ($list.Count -eq 0) { return }
    $script:Failures++
    Write-Host "FAIL ${Name}: unexpected problems: $($list -join ' | ')"
    return
  }
  if (@($list | Where-Object { $_ -match $Pattern }).Count -gt 0) { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: no problem matching '$Pattern' in: $($list -join ' | ')"
}

# --- Command lines ---------------------------------------------------------------------------------------------
$tokens = @(Split-E2ECommandLine '/A /LOG="C:\a b\c.log" /M="!x,!y" /T=z')
Check 'tokens: count' $tokens.Count 4
Check 'tokens: the quoted log stays one token' $tokens[1] '/LOG="C:\a b\c.log"'
Check 'tokens: the quoted list stays one token' $tokens[2] '/M="!x,!y"'
Check 'tokens: empty' @(Split-E2ECommandLine '').Count 0

$log = 'D:\a\_temp\report\logs\S1-install.log'
$ee = $E2ESuiteConst.EEArgs
$neo = $E2ESuiteConst.NeoEEArgs
$switches = @(New-E2ESuiteArguments -LogFile $log -Products 'EE,NeoEE' -EEArgs $ee -NeoEEArgs $neo)
Check 'suite arguments: line' ($switches -join ' ') ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LANG=en /LOG="' + $log + '" /PRODUCTS=EE,NeoEE /EEArgs="' + $ee + '" /NeoEEArgs="' + $neo + '"')
Check 'suite arguments: the value of /EEArgs' (Get-E2ESwitchValue $switches 'EEArgs') $ee
Check 'suite arguments: the value of /NeoEEArgs' (Get-E2ESwitchValue $switches 'NeoEEArgs') $neo
CheckProblems 'suite arguments: both products pass' (Get-E2ESuiteArgumentProblems $switches) ''
CheckProblems 'suite arguments: EE only' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE' -EEArgs $ee)) ''
CheckProblems 'suite arguments: NeoEE only' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'NeoEE' -NeoEEArgs $neo)) ''
Check 'the default NeoEE arguments decide against the CD key task' (@(Split-E2EList (Get-E2ESwitchValue (Split-E2ECommandLine $neo) 'MERGETASKS')) -contains '!neoee_cdkeys') $true

function Without([string[]]$List, [string]$Item) { return @($List | Where-Object { $_ -ne $Item }) }
CheckProblems 'suite arguments: no /VERYSILENT' (Get-E2ESuiteArgumentProblems (Without $switches '/VERYSILENT')) '/VERYSILENT missing'
CheckProblems 'suite arguments: no /SUPPRESSMSGBOXES' (Get-E2ESuiteArgumentProblems (Without $switches '/SUPPRESSMSGBOXES')) '/SUPPRESSMSGBOXES missing'
CheckProblems 'suite arguments: no /NORESTART' (Get-E2ESuiteArgumentProblems (Without $switches '/NORESTART')) '/NORESTART missing'
CheckProblems 'suite arguments: no log' (Get-E2ESuiteArgumentProblems @($switches | Where-Object { $_ -notlike '/LOG=*' })) '/LOG= missing'
CheckProblems 'suite arguments: German' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE' -EEArgs $ee -Language 'de')) 'LANG=de'
CheckProblems 'suite arguments: no language' (Get-E2ESuiteArgumentProblems @($switches | Where-Object { $_ -notlike '/LANG=*' })) 'LANG='
CheckProblems 'suite arguments: no products' (Get-E2ESuiteArgumentProblems @($switches | Where-Object { $_ -notlike '/PRODUCTS=*' })) '/PRODUCTS= missing'
CheckProblems 'suite arguments: an unknown product' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE,AoC' -EEArgs $ee)) 'unknown product AoC'
CheckProblems 'suite arguments: EE without arguments' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE')) 'EEArgs= missing'
CheckProblems 'suite arguments: NeoEE without arguments' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'NeoEE')) 'NeoEEArgs= missing'
foreach ($task in @('neoee_cdkeys', 'certinclude', 'directplay', 'dxwebsetup')) {
  CheckProblems "suite arguments: EE selects $task" (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE' -EEArgs "/TYPE=compact /TASKS=compatibility,$task")) "the task $task must not be selected"
  CheckProblems "suite arguments: NeoEE merges $task" (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'NeoEE' -NeoEEArgs ($neo + ",$task"))) "the task $task must not be selected"
}
CheckProblems 'suite arguments: no exact task list' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE' -EEArgs '/TYPE=compact')) 'an explicit /TASKS list is required'
CheckProblems 'suite arguments: NeoEE without the decision' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'NeoEE' -NeoEEArgs '/TYPE=compact /TASKS=compatibility')) '!neoee_cdkeys'
CheckProblems 'suite arguments: telemetry' (Get-E2ESuiteArgumentProblems @(New-E2ESuiteArguments -LogFile $log -Products 'EE' -EEArgs '/TASKS=compatibility /COMPONENTS=additional\telemetry')) 'telemetry'

# --- What the suite gave a product setup (suite_common.iss SuiteProductArguments, suite_run.iss log line) -------------
$logEE = 'C:\Program Files\Empire Earth Community\Logs\EE-20261005-1204.log'
$logNeo = 'C:\Program Files\Empire Earth Community\Logs\NeoEE-20261005-1204.log'
$lineEE = 'Product EE (step 1 of 2, state 0): C:\Users\runneradmin\AppData\Local\Temp\is-AB12C.tmp\EE_Setup.exe /SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + $logEE + '" /TYPE=compact /TASKS=compatibility,compatibility_windows'
$lineNeo = 'Product NeoEE (step 2 of 2, state 0): C:\Users\runneradmin\AppData\Local\Temp\is-AB12C.tmp\NeoEE_Setup.exe /SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,!neoee_cdkeys,!certinclude,!directplay,!dxwebsetup" /LOG="' + $logNeo + '" /TYPE=compact /TASKS=compatibility,compatibility_windows'
$suiteLog = @('Suite 1.0.0 (contract 1, test build 0), started from D:\x', $lineEE, 'Product EE: the setup ended with exit code 0', $lineNeo)
$cmdEE = Get-E2ESuiteChildCommand $suiteLog 'EE'
$cmdNeo = Get-E2ESuiteChildCommand $suiteLog 'NeoEE'
Check 'child command: EE step' $cmdEE.Step 1
Check 'child command: EE steps' $cmdEE.Steps 2
Check 'child command: EE state' $cmdEE.State 0
Check 'child command: EE exe' $cmdEE.Exe 'C:\Users\runneradmin\AppData\Local\Temp\is-AB12C.tmp\EE_Setup.exe'
Check 'child command: EE log token' $cmdEE.Arguments[7] ('/LOG="' + $logEE + '"')
Check 'child command: NeoEE step' $cmdNeo.Step 2
Check 'child command: not there' ($null -eq (Get-E2ESuiteChildCommand @('Product EE (step 1 of 1, state 0): x') 'EE')) $true
Check 'child command: another product' ($null -eq (Get-E2ESuiteChildCommand @($lineEE) 'NeoEE')) $true
CheckProblems 'child arguments: EE passes' (Test-E2ESuiteChildArguments $cmdEE.Arguments 'EE') ''
CheckProblems 'child arguments: NeoEE passes' (Test-E2ESuiteChildArguments $cmdNeo.Arguments 'NeoEE') ''
function ChangedArguments($Command, [scriptblock]$Change) { return @($Command.Arguments | ForEach-Object { & $Change $_ } | Where-Object { $null -ne $_ }) }
CheckProblems 'child arguments: no /NOICONS' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -ne '/NOICONS') { $a } }) 'EE') '/NOICONS missing'
CheckProblems 'child arguments: no /ALLUSERS' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -ne '/ALLUSERS') { $a } }) 'EE') '/ALLUSERS missing'
CheckProblems 'child arguments: /VERYSILENT instead of /SILENT' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -eq '/SILENT') { '/VERYSILENT' } else { $a } }) 'EE') '/SILENT missing'
CheckProblems 'child arguments: /DIR' ((Test-E2ESuiteChildArguments ($cmdEE.Arguments + '/DIR="C:\x"') 'EE')) '/DIR='
CheckProblems 'child arguments: /TYPE=full' ((Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -eq '/TYPE=compact') { '/TYPE=full' } else { $a } }) 'EE')) 'TYPE=full'
CheckProblems 'child arguments: no !desktopicon' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -like '/MERGETASKS=*') { '/MERGETASKS="!other"' } else { $a } }) 'EE') '!desktopicon'
CheckProblems 'child arguments: NeoEE without !neoee_cdkeys' (Test-E2ESuiteChildArguments (ChangedArguments $cmdNeo { param($a) if ($a -like '/MERGETASKS=*') { '/MERGETASKS="!desktopicon"' } else { $a } }) 'NeoEE') '!neoee_cdkeys'
CheckProblems 'child arguments: the task neoee_cdkeys' (Test-E2ESuiteChildArguments (ChangedArguments $cmdNeo { param($a) if ($a -like '/TASKS=*') { '/TASKS=compatibility,neoee_cdkeys' } else { $a } }) 'NeoEE') 'the task neoee_cdkeys must not be selected'
CheckProblems 'child arguments: the log is not in Logs' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -like '/LOG=*') { '/LOG="C:\Temp\EE.log"' } else { $a } }) 'EE') '/LOG= is not a file below Logs'
CheckProblems 'child arguments: German' (Test-E2ESuiteChildArguments (ChangedArguments $cmdEE { param($a) if ($a -like '/LANG=*') { '/LANG=de' } else { $a } }) 'EE') 'LANG=de'

# --- Shortcuts -----------------------------------------------------------------------------------------------------------
$roots = @{ EE = 'C:\Program Files (x86)\Empire Earth'; NeoEE = 'C:\Program Files (x86)\Neo Empire Earth' }
$ids = @{ EE = $E2ESuiteConst.ProductAppIds['EE']; NeoEE = $E2ESuiteConst.ProductAppIds['NeoEE'] }
$expected = @(Get-E2ESuiteExpectedShortcuts -Products @('EE', 'NeoEE') -SuiteRoot 'C:\Program Files\Empire Earth Community' -Desktop 'C:\Users\Public\Desktop' `
  -Group 'C:\ProgramData\Start\Empire Earth Community' -Roots $roots -AppIds $ids -DiagnosticFor @('EE'))
Check 'shortcuts: count (4 games + 2 diagnostic + 3 others)' $expected.Count 9
$byName = @{}
foreach ($item in $expected) { $byName[$item.Path] = $item }
$d = $byName['C:\Users\Public\Desktop\Neo Empire Earth.lnk']
Check 'shortcuts: NeoEE desktop target' $d.Target 'C:\Program Files\Empire Earth Community\Empire Earth Launcher.exe'
Check 'shortcuts: NeoEE desktop arguments' $d.Arguments '--product=NeoEE'
Check 'shortcuts: NeoEE desktop present' $d.Present $true
Check 'shortcuts: EE group arguments' $byName['C:\ProgramData\Start\Empire Earth Community\Empire Earth.lnk'].Arguments '--product=EE'
$diag = $byName['C:\ProgramData\Start\Empire Earth Community\Empire Earth Diagnostic.lnk']
Check 'shortcuts: EE diagnostic target' $diag.Target 'C:\Program Files (x86)\Empire Earth\Tools\Diagnostic\EE-Diagnostic.exe'
Check 'shortcuts: EE diagnostic arguments' $diag.Arguments '{00000000-0000-0000-0000-0000000000EE}_is1'
Check 'shortcuts: NeoEE has no diagnostic here' $byName['C:\ProgramData\Start\Empire Earth Community\Neo Empire Earth Diagnostic.lnk'].Present $false
Check 'shortcuts: the Mod Creator' $byName['C:\ProgramData\Start\Empire Earth Community\Mod Creator.lnk'].Target 'C:\Program Files\Empire Earth Community\Mod Creator\Empire_Earth_Mod.exe'
Check 'shortcuts: the uninstaller' $byName['C:\ProgramData\Start\Empire Earth Community\Uninstall Empire Earth Community.lnk'].Target 'C:\Program Files\Empire Earth Community\unins000.exe'
$only = @(Get-E2ESuiteExpectedShortcuts -Products @('EE') -SuiteRoot 'C:\S' -Desktop 'C:\D' -Group 'C:\G' -Roots $roots -AppIds $ids)
Check 'shortcuts: EE only, NeoEE game shortcut absent' (@($only | Where-Object { $_.Path -eq 'C:\D\Neo Empire Earth.lnk' })[0].Present) $false
Check 'shortcuts: EE only, EE game shortcut present' (@($only | Where-Object { $_.Path -eq 'C:\D\Empire Earth.lnk' })[0].Present) $true
Check 'shortcuts: no diagnostic without the program' (@($only | Where-Object { $_.Path -eq 'C:\G\Empire Earth Diagnostic.lnk' })[0].Present) $false

$actual = @{}
foreach ($item in $expected) {
  if ($item.Present) { $actual[$item.Path] = @{ Target = $item.Target; Arguments = $item.Arguments } }
}
CheckProblems 'shortcuts compare: all as expected' (Compare-E2EShortcuts $expected $actual) ''
$broken = @{}
foreach ($key in $actual.Keys) { $broken[$key] = $actual[$key] }
$broken.Remove('C:\Users\Public\Desktop\Empire Earth.lnk')
CheckProblems 'shortcuts compare: one missing' (Compare-E2EShortcuts $expected $broken) 'Empire Earth.lnk missing'
$broken = @{}
foreach ($key in $actual.Keys) { $broken[$key] = $actual[$key] }
$broken['C:\Users\Public\Desktop\Neo Empire Earth.lnk'] = @{ Target = 'C:\Program Files (x86)\Neo Empire Earth\Empire Earth\Empire Earth.exe'; Arguments = '' }
CheckProblems 'shortcuts compare: the game program instead of the launcher' (Compare-E2EShortcuts $expected $broken) 'Neo Empire Earth.lnk points to'
$broken['C:\Users\Public\Desktop\Neo Empire Earth.lnk'] = @{ Target = 'c:\program files\empire earth community\EMPIRE EARTH LAUNCHER.EXE'; Arguments = '--product=EE' }
CheckProblems 'shortcuts compare: the wrong product' (Compare-E2EShortcuts $expected $broken) "arguments '--product=EE', expected '--product=NeoEE'"
$broken['C:\Users\Public\Desktop\Neo Empire Earth.lnk'] = $actual['C:\Users\Public\Desktop\Neo Empire Earth.lnk']
$broken['C:\ProgramData\Start\Empire Earth Community\Neo Empire Earth Diagnostic.lnk'] = @{ Target = 'x'; Arguments = '' }
CheckProblems 'shortcuts compare: one that must not exist' (Compare-E2EShortcuts $expected $broken) 'Neo Empire Earth Diagnostic.lnk exists'
$broken = @{}
foreach ($key in $actual.Keys) { $broken[$key.ToUpperInvariant()] = $actual[$key] }
CheckProblems 'shortcuts compare: path case does not matter' (Compare-E2EShortcuts $expected $broken) ''

# --- The package ---------------------------------------------------------------------------------------------------------
$h1 = 'a' * 64
$h2 = 'b' * 64
$sums = "$h1  Empire Earth Community Setup.exe`n$h2  Empire Earth Community Setup-1.bin`n"
$files = @{ 'Empire Earth Community Setup.exe' = $h1; 'Empire Earth Community Setup-1.bin' = $h2; 'SHA256SUMS.txt' = ('c' * 64); 'BUILD-INFO.txt' = ('d' * 64) }
CheckProblems 'package: fine' (Test-E2ESuitePackage $sums $files) ''
$changed = @{}
foreach ($key in $files.Keys) { $changed[$key] = $files[$key] }
$changed['Empire Earth Community Setup-1.bin'] = ('e' * 64)
CheckProblems 'package: a changed slice' (Test-E2ESuitePackage $sums $changed) 'Setup-1.bin does not match'
$extra = @{}
foreach ($key in $files.Keys) { $extra[$key] = $files[$key] }
$extra['Empire Earth Community Setup-2.bin'] = $h2
CheckProblems 'package: a slice that is not listed' (Test-E2ESuitePackage $sums $extra) 'Setup-2.bin is not listed'
$less = @{}
foreach ($key in $files.Keys) { if ($key -ne 'Empire Earth Community Setup-1.bin') { $less[$key] = $files[$key] } }
CheckProblems 'package: a slice that is gone' (Test-E2ESuitePackage $sums $less) 'Setup-1.bin is listed in SHA256SUMS.txt but missing'
CheckProblems 'package: a bad line' (Test-E2ESuitePackage ($sums + "garbage`n") $files) 'a line of another form'
CheckProblems 'package: no slice' (Test-E2ESuitePackage "$h1  Empire Earth Community Setup.exe`n" @{ 'Empire Earth Community Setup.exe' = $h1 }) 'no slice'
CheckProblems 'package: no program' (Test-E2ESuitePackage "$h2  Empire Earth Community Setup-1.bin`n" @{ 'Empire Earth Community Setup-1.bin' = $h2 }) 'Empire Earth Community Setup.exe missing'
Check 'zone identifier' (Get-E2EZoneIdentifierText) "[ZoneTransfer]`r`nZoneId=3`r`n"

# --- Suite record ----------------------------------------------------------------------------------------------------------
$record = @{
  ContractVersion = (New-E2ERegValue 'DWord' 1); SuiteVersion = (New-E2ERegValue 'String' '1.0.0')
  InstallPath = (New-E2ERegValue 'String' 'C:\Program Files\Empire Earth Community'); Products = (New-E2ERegValue 'String' 'EE,NeoEE')
  SourceDir = (New-E2ERegValue 'String' 'D:\a\_temp\suite'); EEAppId = (New-E2ERegValue 'String' $ids['EE'])
  NeoEEAppId = (New-E2ERegValue 'String' $ids['NeoEE']); Written = (New-E2ERegValue 'String' '2026-10-05 18:04:31')
}
function CopyRecord() { $c = @{}; foreach ($k in $record.Keys) { $c[$k] = $record[$k] }; return $c }
CheckProblems 'record: fine' (Test-E2ESuiteRecordValues $record 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) ''
CheckProblems 'record: no key' (Test-E2ESuiteRecordValues $null 'EE,NeoEE' 'C:\S' 'D:\x' $ids) 'does not exist'
$c = CopyRecord; $c['Products'] = (New-E2ERegValue 'String' 'EE')
CheckProblems 'record: other products' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) "value 'Products' = 'EE'"
$c = CopyRecord; $c['ContractVersion'] = (New-E2ERegValue 'String' '1')
CheckProblems 'record: contract version as text' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) 'is String, expected DWord'
$c = CopyRecord; $c.Remove('Written')
CheckProblems 'record: a value missing' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) 'lacks Written'
$c = CopyRecord; $c['Extra'] = (New-E2ERegValue 'String' 'x')
CheckProblems 'record: another value' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) 'has more: Extra'
$c = CopyRecord; $c['SourceDir'] = (New-E2ERegValue 'String' 'D:\other')
CheckProblems 'record: another source folder' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) "value 'SourceDir'"
$c = CopyRecord; $c['InstallPath'] = (New-E2ERegValue 'String' 'c:\program files\empire earth community\')
CheckProblems 'record: the folder differs in case and a backslash only' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) ''
$c = CopyRecord; $c['Written'] = (New-E2ERegValue 'String' 'yesterday')
CheckProblems 'record: a bad time' (Test-E2ESuiteRecordValues $c 'EE,NeoEE' 'C:\Program Files\Empire Earth Community' 'D:\a\_temp\suite' $ids) "'Written' is not a time"

# --- CD key dummy ------------------------------------------------------------------------------------------------------------
$dummy = @{ 'CI-Dummy' = (New-E2ERegValue 'String' 'NOT-A-KEY-0000') }
Check 'snapshot: a value' ((ConvertTo-E2ECdKeysSnapshotLines 'HKCU' $dummy @()) -join '|') 'HKCU|CI-Dummy|String|NOT-A-KEY-0000'
Check 'snapshot: no key' ((ConvertTo-E2ECdKeysSnapshotLines 'HKLM64' $null @()) -join '|') 'HKLM64|absent'
Check 'snapshot: a subkey' ((ConvertTo-E2ECdKeysSnapshotLines 'HKLM32' $dummy @('Sub')) -join '|') 'HKLM32|<subkey>|Sub|HKLM32|CI-Dummy|String|NOT-A-KEY-0000'
CheckProblems 'snapshot: a value changed' (Compare-E2ESnapshot (ConvertTo-E2ECdKeysSnapshotLines 'HKCU' $dummy @()) (ConvertTo-E2ECdKeysSnapshotLines 'HKCU' @{ 'CI-Dummy' = (New-E2ERegValue 'String' 'other') } @()) 'CD keys') 'CD keys new or changed'
CheckProblems 'snapshot: the key deleted' (Compare-E2ESnapshot (ConvertTo-E2ECdKeysSnapshotLines 'HKCU' $dummy @()) (ConvertTo-E2ECdKeysSnapshotLines 'HKCU' $null @()) 'CD keys') 'CD keys changed or gone'

# --- Summary of the results -----------------------------------------------------------------------------------------------------
function Json($Scenario, $Check, $Status, $Details = @()) { return (ConvertTo-E2EJson ([ordered]@{ scenario = $Scenario; check = $Check; status = $Status; details = @($Details) }) -Compress) }
$titles = @{ S1 = 'First'; S2 = 'Second | with a bar' }
$good = @((Json 'S1' 'install/RUN' 'PASS' @('exit code 0')), (Json 'S1' 'DONE' 'INFO'), (Json 'S2' 'install/RUN' 'PASS'), (Json 'S2' 'DONE' 'INFO'))
$result = ConvertTo-E2ESuiteSummary -JsonLines $good -Scenarios @('S1', 'S2') -Titles $titles
Check 'summary: passed' $result.Failed $false
Check 'summary: lines' ($result.Lines -join '|') 'PASS S1 First|PASS S2 Second | with a bar'
Check 'summary: verdict' ($result.Markdown -like '*PASSED*2 of 2 scenarios passed*') $true
Check 'summary: the bar of a title does not break the table' ($result.Markdown -like '*Second / with a bar*') $true
$bad = @($good[0], (Json 'S1' 'install/LNK' 'FAIL' @('a|b missing', 'second')), $good[1], $good[2])
$result = ConvertTo-E2ESuiteSummary -JsonLines $bad -Scenarios @('S1', 'S2') -Titles $titles
Check 'summary: a FAIL line fails the scenario' ($result.Lines -join '|') 'FAIL S1 First|FAIL S2 Second | with a bar'
Check 'summary: failed' $result.Failed $true
Check 'summary: the failed check is named' ($result.Markdown -like '*install/LNK*a/b missing / second*') $true
Check 'summary: S2 did not finish' ($result.Markdown -like '*S2** did not run to the end*') $true
$result = ConvertTo-E2ESuiteSummary -JsonLines @($good[0], $good[1]) -Scenarios @('S1', 'S2') -Titles $titles
Check 'summary: a scenario without any result' ($result.Markdown -like '*S2** no result at all*') $true
Check 'summary: failed for a missing scenario' $result.Failed $true
$result = ConvertTo-E2ESuiteSummary -JsonLines @($good[0], (Json 'S1' 'cleanup/UNINSTALL' 'WARN' @('slow')), $good[1]) -Scenarios @('S1') -Titles $titles
Check 'summary: a warning does not fail' $result.Failed $false
Check 'summary: the warning is shown' ($result.Markdown -like '*Warnings*cleanup/UNINSTALL*slow*') $true
$result = ConvertTo-E2ESuiteSummary -JsonLines @((Json 'S1' 'DONE' 'INFO')) -Scenarios @('S1') -Titles $titles
Check 'summary: no check passed' $result.Failed $true

# --- The scenarios and their titles ---------------------------------------------------------------------------------------------------
Check 'scenarios: ten' $E2ESuiteConst.Scenarios.Count 10
foreach ($id in $E2ESuiteConst.Scenarios) { Check "title of $id" ($E2ESuiteTitles.ContainsKey($id) -and $E2ESuiteTitles[$id].Length -gt 10) $true }
Check 'the AppIds are the dummies of ci/build.ps1' ($E2ESuiteConst.ProductAppIds['EE'] + '|' + $E2ESuiteConst.ProductAppIds['NeoEE'] + '|' + $E2ESuiteConst.SuiteAppId) `
  '00000000-0000-0000-0000-0000000000EE|00000000-0000-0000-0000-000000000AEE|00000000-0000-0000-0000-0000000005EE'

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
