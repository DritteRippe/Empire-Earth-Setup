<#
.SYNOPSIS
  Tests of ci\e2e\e2e_helpers.ps1, the rules of the real-data end-to-end test, with fake data.

.DESCRIPTION
  Every rule that only looks at text, bytes or values (install.ini, files.sha256, setup logs,
  registry values, components, the setup arguments, the hosts file, the online files and the
  expectation files of the launcher checks) is fed with made-up input: valid input must pass, each
  kind of defect must be reported. No registry, no network, no game data; runs with Windows
  PowerShell 5.1 and PowerShell 7 (also on Linux). The scripts that touch Windows
  (e2e_windows.ps1, e2e_checks.ps1, run_e2e.ps1) are only parsed here; they run in the workflow.
  Prints the failed checks and exits with 0 if every check passed, else 1.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\e2e\tests\e2e_helpers.tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$E2EFolder = Split-Path -Parent $PSScriptRoot
. (Join-Path $E2EFolder 'e2e_helpers.ps1')

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
function Bytes([string]$Text) { return ,([System.Text.Encoding]::ASCII.GetBytes($Text)) }

# --- Parse every script of ci\e2e (PowerShell 5.1 syntax is checked by running this under 5.1)
foreach ($file in Get-ChildItem -LiteralPath $E2EFolder -Filter '*.ps1') {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  Check "parse $($file.Name)" (@($errors).Count) 0
  $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
  Check "ASCII only: $($file.Name)" (@($bytes | Where-Object { $_ -gt 127 }).Count) 0
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-e2e-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  # --- Results: JSON lines, hashes redacted
  $resultFile = Join-Path $temp 'results.jsonl'
  Initialize-E2EResults $resultFile
  $hash = 'ab' * 32
  $null = Complete-E2ECheck 'T' 'step/K1' @("value differs $hash") 6>$null
  $null = Complete-E2ECheck 'T' 'step/K2' @() 'fine' 6>$null
  $null = Complete-E2ECheck 'T' 'step/K3' @('note') -Soft 6>$null
  $lines = @(Get-Content -LiteralPath $resultFile)
  Check 'results: three lines' $lines.Count 3
  $first = $lines[0] | ConvertFrom-Json
  Check 'results: FAIL' $first.status 'FAIL'
  Check 'results: hash redacted' $first.details[0] 'value differs <hash>'
  Check 'results: PASS' ($lines[1] | ConvertFrom-Json).status 'PASS'
  Check 'results: WARN' ($lines[2] | ConvertFrom-Json).status 'WARN'
  Check 'safe text: SHA-1 redacted' (ConvertTo-E2ESafeText ('x ' + ('c' * 40) + ' y')) 'x <hash> y'
  Check 'safe text: shorter hex kept' (ConvertTo-E2ESafeText ('deadbeef' * 2)) ('deadbeef' * 2)
  Check 'safe text: cut' (ConvertTo-E2ESafeText ('a' * 400)).Length 300
  Check 'annotation escaping' (ConvertTo-E2EAnnotation "50% a`nb") '50%25 a%0Ab'

  # --- Lists, sets, uppercase
  Check 'split list' ((Split-E2EList ' a, b ,,c ') -join '|') 'a|b|c'
  Check 'split empty' @(Split-E2EList '').Count 0
  $diff = Compare-E2ESets @('A', 'b', 'c') @('a', 'B', 'd')
  Check 'sets: missing' ($diff.Missing -join ',') 'c'
  Check 'sets: extra' ($diff.Extra -join ',') 'd'
  Check 'ascii upper' (ConvertTo-E2EAsciiUpper '\Program Files (x86)\Empire Earth') '\PROGRAM FILES (X86)\EMPIRE EARTH'
  Check 'ascii upper leaves non-ASCII' (ConvertTo-E2EAsciiUpper ('a' + [char]0xE4)) ('A' + [char]0xE4)
  CheckProblems 'snapshot equal' (Compare-E2ESnapshot @('x|1', 'y|2') @('y|2', 'x|1') 'state') ''
  CheckProblems 'snapshot changed' (Compare-E2ESnapshot @('x|1') @('x|2') 'state') 'state new or changed: x\|2'

  # --- Logs
  $log = "2026-10-03 10:00:00.123   Log opened.`r`n2026-10-03 10:00:00.124   Screen: 1024 x 768 pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), 96 DPI (LOGPIXELSX, 100 % scaling), game window 1024 x 768`r`n" +
         "2026-10-03 10:00:01.000   Unknown GPU detected`r`n2026-10-03 10:00:01.001   Using general GPU settings: additional\directx_wrapper\dx9`r`n" +
         "2026-10-03 10:00:02.000   Tasks: firewallexception`r`n"
  $logLines = ConvertFrom-E2ELogText $log
  Check 'log: time stamp removed' $logLines[0] 'Log opened.'
  CheckProblems 'log: contains' (Test-E2ELogLines -Lines $logLines -Contains @('Log opened.')) ''
  CheckProblems 'log: missing' (Test-E2ELogLines -Lines $logLines -Contains @('Installation process succeeded.')) 'log line missing: Installation'
  CheckProblems 'log: pattern' (Test-E2ELogLines -Lines $logLines -Matches @('^Using \S+ GPU settings: ')) ''
  CheckProblems 'log: forbidden is case-sensitive' (Test-E2ELogLines -Lines $logLines -NotContains @('Exception')) ''
  CheckProblems 'log: forbidden found' (Test-E2ELogLines -Lines $logLines -NotContains @('GPU detected')) 'not allowed: Unknown GPU detected'
  CheckProblems 'log: forbidden pattern' (Test-E2ELogLines -Lines $logLines -NotMatches @('^Using ')) 'not allowed'
  $screen = Get-E2EScreen $logLines
  Check 'screen width' $screen.Width 1024
  Check 'screen window height' $screen.WindowHeight 768
  Check 'screen missing' (Get-E2EScreen @('nothing')) ''
  Check 'clamp low' (Get-E2EClamped 800 1024 1920) 1024
  Check 'clamp high' (Get-E2EClamped 2560 1024 1920) 1920
  Check 'clamp inside' (Get-E2EClamped 1280 1024 1920) 1280
  $gpu = Get-E2EGpuChoice $logLines
  Check 'gpu unknown: dx9' $gpu.Wrapper 'additional\directx_wrapper\dx9'
  Check 'gpu unknown: log name' $gpu.LogName 'general'
  Check 'gpu NVIDIA' (Get-E2EGpuChoice @('NVIDIA GPU detected')).Wrapper 'additional\directx_wrapper\dx11_lvl11'
  Check 'gpu Intel' (Get-E2EGpuChoice @('Intel GPU detected')).Wrapper 'additional\directx_wrapper\dx11_lvl10_1'
  CheckProblems 'gpu none' (Get-E2EGpuChoice @('nothing')).Problems 'no "GPU detected" line'

  # --- install.ini (contract 1.2)
  $expected = @{ ContractVersion = 1; Product = 'EE'; AppId = '4C0B46D8-E7EB-4B95-97D4-A578D9B914C6'; InstallMode = 'admin'
                 GameVersion = '2.0.0.0'; SetupVersion = '1.7.2'; SetupBuild = 'abc1234' }
  $ini = "[Install]`r`nContractVersion=1`r`nProduct=EE`r`nAppId=4C0B46D8-E7EB-4B95-97D4-A578D9B914C6`r`nInstallMode=admin`r`nGameVersion=2.0.0.0`r`n" +
         "SetupVersion=1.7.2`r`nSetupBuild=abc1234`r`nComponents=game,language\en`r`nTasks=compatibility`r`nWritten=2026-10-03 10:00:00`r`n"
  $result = Test-E2EInstallIniBytes (Bytes $ini) $expected
  CheckProblems 'ini: valid' $result.Problems ''
  Check 'ini: components' $result.Values['Components'] 'game,language\en'
  CheckProblems 'ini: BOM' (Test-E2EInstallIniBytes ([byte[]](@(0xEF, 0xBB, 0xBF) + (Bytes $ini))) $expected).Problems 'BOM'
  CheckProblems 'ini: LF only' (Test-E2EInstallIniBytes (Bytes ($ini -replace "`r`n", "`n")) $expected).Problems 'LF without CR'
  CheckProblems 'ini: no CRLF at the end' (Test-E2EInstallIniBytes (Bytes $ini.TrimEnd()) $expected).Problems 'does not end with CRLF'
  CheckProblems 'ini: wrong mode' (Test-E2EInstallIniBytes (Bytes ($ini -replace 'InstallMode=admin', 'InstallMode=user')) $expected).Problems 'InstallMode=user, expected admin'
  CheckProblems 'ini: order' (Test-E2EInstallIniBytes (Bytes ($ini -replace "Product=EE`r`nAppId=4C0B46D8-E7EB-4B95-97D4-A578D9B914C6", "AppId=4C0B46D8-E7EB-4B95-97D4-A578D9B914C6`r`nProduct=EE")) $expected).Problems 'keys are'
  CheckProblems 'ini: missing section' (Test-E2EInstallIniBytes (Bytes ($ini + "[MissingAfterInstall]`r`nEmpire Earth/x.dll`r`n")) $expected).Problems 'not key=value|keys are'
  CheckProblems 'ini: written' (Test-E2EInstallIniBytes (Bytes ($ini -replace 'Written=2026-10-03 10:00:00', 'Written=today')) $expected).Problems 'Written=today'
  CheckProblems 'ini: not ASCII' (Test-E2EInstallIniBytes ([byte[]]((Bytes $ini) + @(0xC3, 0xA4, 13, 10))) $expected).Problems 'not ASCII'
  $noBuild = $expected.Clone()
  $noBuild.SetupBuild = ''
  CheckProblems 'ini: without SetupBuild' (Test-E2EInstallIniBytes (Bytes ($ini -replace "SetupBuild=abc1234`r`n", '')) $noBuild).Problems ''
  CheckProblems 'ini: SetupBuild unexpected' (Test-E2EInstallIniBytes (Bytes $ini) $noBuild).Problems 'keys are'

  # --- files.sha256 (contract 2.2, 2.3)
  $h1 = '0' * 64
  $h2 = '1' * 64
  $manifest = "$h1  Empire Earth/Data/a.dat`n$h2  Empire Earth/Empire Earth.exe`n$h1  Empire Earth/WONLobby.cfg`n$h2  Empire Earth/_x.txt`n"
  $parsed = Test-E2EManifestBytes (Bytes $manifest) '_setupdata_EE'
  CheckProblems 'manifest: valid' $parsed.Problems ''
  Check 'manifest: entries' $parsed.Entries.Count 4
  Check 'manifest: path' $parsed.Entries[1].Path 'Empire Earth/Empire Earth.exe'
  CheckProblems 'manifest: CR' (Test-E2EManifestBytes (Bytes ($manifest -replace "`n", "`r`n")) '_setupdata_EE').Problems 'contains a CR'
  CheckProblems 'manifest: order' (Test-E2EManifestBytes (Bytes "$h1  b.txt`n$h1  a.txt`n") '_setupdata_EE').Problems 'not sorted'
  CheckProblems "manifest: '_' after the letters" (Test-E2EManifestBytes (Bytes "$h1  _a.txt`n$h1  b.txt`n") '_setupdata_EE').Problems 'not sorted'
  CheckProblems 'manifest: duplicate ignoring case' (Test-E2EManifestBytes (Bytes "$h1  A.txt`n$h1  a.txt`n") '_setupdata_EE').Problems 'twice'
  CheckProblems 'manifest: uppercase hash' (Test-E2EManifestBytes (Bytes ("A" * 64 + "  a.txt`n")) '_setupdata_EE').Problems 'malformed'
  CheckProblems 'manifest: backslash' (Test-E2EManifestBytes (Bytes "$h1  Empire Earth\a.txt`n") '_setupdata_EE').Problems 'malformed'
  CheckProblems 'manifest: dot segment' (Test-E2EManifestBytes (Bytes "$h1  Empire Earth/../a.txt`n") '_setupdata_EE').Problems 'unsafe path'
  CheckProblems 'manifest: setup data folder' (Test-E2EManifestBytes (Bytes "$h1  _setupdata_EE/install.ini`n") '_setupdata_EE').Problems 'setup data folder'
  CheckProblems 'manifest: uninstaller' (Test-E2EManifestBytes (Bytes "$h1  unins000.exe`n") '_setupdata_EE').Problems 'uninstaller'
  CheckProblems 'manifest: _wonkver.pub' (Test-E2EManifestBytes (Bytes "$h1  Empire Earth/_wonkver.pub`n") '_setupdata_EE').Problems '_wonkver'
  CheckProblems 'manifest: no LF at the end' (Test-E2EManifestBytes (Bytes "$h1  a.txt") '_setupdata_EE').Problems 'does not end with LF'

  # --- Components
  $full = @('game', 'gameaoc', 'additional', 'additional\directx_wrapper', 'additional\directx_wrapper\dx9', 'language', 'language\de', 'language\update')
  CheckProblems 'components: valid' (Test-E2EComponents $full 'de' 'additional\directx_wrapper\dx9' @('game', 'gameaoc') @('additional\movies')) ''
  CheckProblems 'components: telemetry' (Test-E2EComponents ($full + 'additional\telemetry') 'de' 'additional\directx_wrapper\dx9') 'telemetry'
  CheckProblems 'components: language' (Test-E2EComponents $full 'en' 'additional\directx_wrapper\dx9') 'game languages'
  CheckProblems 'components: two languages' (Test-E2EComponents ($full + 'language\en') 'de' 'additional\directx_wrapper\dx9') 'game languages'
  CheckProblems 'components: wrapper expected none' (Test-E2EComponents $full 'de' '') 'expected none'
  CheckProblems 'components: other wrapper' (Test-E2EComponents $full 'de' 'additional\directx_wrapper\dx11_lvl11') 'DirectX wrapper'
  CheckProblems 'components: required' (Test-E2EComponents $full 'de' 'additional\directx_wrapper\dx9' @('additional\discord')) 'missing: additional\\discord'
  CheckProblems 'components: forbidden' (Test-E2EComponents $full 'de' 'additional\directx_wrapper\dx9' @() @('gameaoc')) 'not expected: gameaoc'

  # --- Registry values
  $want = @{ A = (New-E2ERegValue 'String' 'x'); B = (New-E2ERegValue 'DWord' 32) }
  $have = @{ A = (New-E2ERegValue 'String' 'x'); B = (New-E2ERegValue 'DWord' 32) }
  CheckProblems 'registry: equal' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K' -Exact) ''
  CheckProblems 'registry: key missing' (Compare-E2ERegValues -Actual $null -Expected $want -Where 'K') 'K does not exist'
  $have.B = New-E2ERegValue 'DWord' 16
  CheckProblems 'registry: value differs' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K') "value 'B' = 16, expected 32"
  $have.B = New-E2ERegValue 'String' '32'
  CheckProblems 'registry: kind differs' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K') 'is String, expected DWord'
  $have.B = New-E2ERegValue 'DWord' 32
  $have.C = New-E2ERegValue 'String' 'player'
  CheckProblems 'registry: extra value with -Exact' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K' -Exact) "unexpected value 'C'"
  CheckProblems 'registry: extra value without -Exact' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K') ''
  $have.A = New-E2ERegValue 'String' 'X'
  CheckProblems 'registry: strings case-sensitive' (Compare-E2ERegValues -Actual $have -Expected $want -Where 'K') "value 'A'"

  # --- Game settings of a first installation (contract 3.2, 3.3)
  $settings = Get-E2EGameSettingsExpected 'C:\Program Files (x86)\Empire Earth' 'Empire Earth' $true 1280 1024 13
  Check 'settings: volume' $settings.Main['Installed From Volume'].Value 'C:'
  Check 'settings: directory' $settings.Main['Installed From Directory'].Value '\PROGRAM FILES (X86)\EMPIRE EARTH\Empire Earth\'
  Check 'settings: rasterizer with wrapper' $settings.Main['Rasterizer Name'].Value 'Direct3D'
  Check 'settings: rasterizer without wrapper' (Get-E2EGameSettingsExpected 'C:\x' 'Empire Earth' $false 1024 768 13).Main['Rasterizer Name'].Value 'Direct3D Hardware TnL'
  Check 'settings: values' $settings.Main.Count 12
  Check 'settings: options' $settings.Options.Count 15
  Check 'settings: ending epoch AoC' (Get-E2EGameSettingsExpected 'C:\x' 'AoC' $true 1024 768 14).Options['Ending Epoch'].Value 14
  Check 'settings: autosave' $settings.Main['AutoSave In Milliseconds'].Value 1200000

  # --- Online files
  $downloads = @(
    "Online file verified, SHA-256 pinned: Game/de/EE/Language.dll (SHA-256 $h1)",
    "Online file accepted, TLS-verified, not pinned: Game/de/EE/Data/Campaigns/EELearningCampaign.ssa (SHA-256 $h2)",
    'Online file registered, SHA-256 pinned: Game/de/EE/Language.dll'
  )
  $records = @(Get-E2EDownloadRecords $downloads)
  Check 'downloads: records' $records.Count 2
  Check 'downloads: pinned' $records[0].Pinned $true
  Check 'downloads: not pinned' $records[1].Pinned $false
  Check 'targets: game file' ((Get-E2EOnlineFileTargets 'Game/de/AoC/Data/data.ssa' @('EE', 'AoC')) -join '|') 'Empire Earth - The Art of Conquest/Data/data.ssa'
  Check 'targets: learning campaign for both' ((Get-E2EOnlineFileTargets 'Game/de/EE/Data/Campaigns/EELearningCampaign.ssa' @('EE', 'AoC')) -join '|') 'Empire Earth/Data/Campaigns/EELearningCampaign.ssa|Empire Earth - The Art of Conquest/Data/Campaigns/EELearningCampaign.ssa'
  Check 'targets: learning campaign EE only' ((Get-E2EOnlineFileTargets 'Game/de/EE/Data/Campaigns/EELearningCampaign.ssa' @('EE')) -join '|') 'Empire Earth/Data/Campaigns/EELearningCampaign.ssa'
  Check 'targets: shared lobby' ((Get-E2EOnlineFileTargets 'Lobby/de/shared/Data/WONLobby Resources/_WONStatus.cfg' @('EE', 'AoC')) -join '|') 'Empire Earth/Data/WONLobby Resources/_WONStatus.cfg|Empire Earth - The Art of Conquest/Data/WONLobby Resources/_WONStatus.cfg'
  Check 'targets: lobby of a game' ((Get-E2EOnlineFileTargets 'Lobby/de/AoC/WONLobby.cfg' @('EE', 'AoC')) -join '|') 'Empire Earth - The Art of Conquest/WONLobby.cfg'
  Check 'targets: unknown' @(Get-E2EOnlineFileTargets 'Other/x' @('EE')).Count 0
  $pins = ConvertFrom-E2EPinList "$h1  Game/de/EE/Language.dll`r`n$h2  Lobby/de/EE/WONLobby.cfg`n"
  Check 'pins: CRLF list' $pins['Game/de/EE/Language.dll'] $h1
  Check 'pins: LF list' $pins['Lobby/de/EE/WONLobby.cfg'] $h2

  # --- Hosts file
  $hosts = "# Copyright`r`n127.0.0.1 localhost`r`n"
  $blocked = Get-E2EHostsText $hosts @('api.empireearth.eu', 'files.empireearth.eu')
  Check 'hosts: own lines kept' ($blocked.StartsWith("# Copyright`r`n127.0.0.1 localhost`r`n")) $true
  Check 'hosts: IPv4' ($blocked -match '(?m)^0\.0\.0\.0 api\.empireearth\.eu\r?$') $true
  Check 'hosts: IPv6' ($blocked -match '(?m)^:: files\.empireearth\.eu\r?$') $true
  $again = Get-E2EHostsText $blocked @('api.empireearth.eu')
  Check 'hosts: block replaced' ([regex]::Matches($again, [regex]::Escape($E2EConst.HostsBegin)).Count) 1
  Check 'hosts: name removed' ($again -match 'files\.empireearth\.eu') $false
  Check 'hosts: block removed' (Get-E2EHostsText $blocked @()) $hosts
  Check 'hosts: every API host blocked' (@($E2EConst.BlockedHosts) -contains 'api.empireearth.eu') $true

  # --- Setup arguments (hard rules)
  $base = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/LOG="C:\x.log"')
  CheckProblems 'args: v2 first install' (Test-E2ESetupArguments ($base + '/TASKS="compatibility,desktopicon"') 'v2' 'EE' $true) ''
  CheckProblems 'args: telemetry' (Test-E2ESetupArguments ($base + '/COMPONENTS="game,additional\telemetry"') 'v2' 'EE' $true) 'telemetry'
  CheckProblems 'args: CD key task' (Test-E2ESetupArguments ($base + '/TASKS="neoee_cdkeys"') 'v2' 'NeoEE' $true) 'neoee_cdkeys'
  CheckProblems 'args: certificate task' (Test-E2ESetupArguments ($base + '/MERGETASKS="certinclude"') 'v2' 'EE' $false) 'certinclude'
  CheckProblems 'args: negated tasks allowed' (Test-E2ESetupArguments ($base + '/MERGETASKS="!dxwebsetup,!directplay"') 'v2' 'EE' $false) ''
  CheckProblems 'args: official without /TASKS' (Test-E2ESetupArguments $base 'official' 'EE' $true) 'explicit /TASKS'
  CheckProblems 'args: NeoEE first install without /TASKS' (Test-E2ESetupArguments $base 'v2' 'NeoEE' $true) 'explicit /TASKS'
  CheckProblems 'args: NeoEE update without CD key negation' (Test-E2ESetupArguments $base 'v2' 'NeoEE' $false) 'NeoEE update'
  CheckProblems 'args: NeoEE update with negation' (Test-E2ESetupArguments ($base + '/MERGETASKS="!neoee_cdkeys"') 'v2' 'NeoEE' $false) ''
  CheckProblems 'args: not silent' (Test-E2ESetupArguments @('/LOG="x"') 'v2' 'EE' $false) '/VERYSILENT missing'
  CheckProblems 'args: no log' (Test-E2ESetupArguments @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') 'v2' 'EE' $false) '/LOG= missing'
  Check 'switch value' (Get-E2ESwitchValue @('/DIR="C:\EE CI\Custom Root"') 'DIR') 'C:\EE CI\Custom Root'
  Check 'switch value missing' (Get-E2ESwitchValue @('/LANG=en') 'TASKS') ''

  # --- Expectation files of the launcher checks: arrays stay arrays, also with one or no item
  $installation = New-E2ELauncherInstallation 'EE' 'C:\Program Files (x86)\Empire Earth' @{
    kind = 'Community'; missingPrograms = @(); sources = @('RegistryRecord')
    integrity = [ordered]@{ quick = [ordered]@{ state = 'Damaged'; findings = @([ordered]@{ path = 'Empire Earth/x.dll'; kind = 'Missing' }); offersRepair = $true } }
  }
  $expectation = New-E2ELauncherExpectation -Scenario 'C' -Step 'damaged' -Installations @($installation) -SelectedRoot 'C:\Program Files (x86)\Empire Earth' `
    -Defaults ([ordered]@{ expectNoWrites = $true })
  $json = ConvertTo-E2EJson $expectation
  $back = $json | ConvertFrom-Json
  Check 'json: schema' $back.schema 1
  Check 'json: installations is an array' ($json -match '"installations":\s*\[') $true
  Check 'json: one installation' @($back.installations).Count 1
  Check 'json: root' $back.installations[0].root 'C:\Program Files (x86)\Empire Earth'
  Check 'json: empty array' ($json -match '"missingPrograms":\s*\[\s*\]') $true
  Check 'json: one-item array' ($json -match '"sources":\s*\[\s*"RegistryRecord"\s*\]') $true
  Check 'json: finding' $back.installations[0].integrity.quick.findings[0].kind 'Missing'
  Check 'json: defaults' $back.defaults.expectNoWrites $true
  $empty = ConvertTo-E2EJson (New-E2ELauncherExpectation -Scenario 'A' -Step 'after' -Installations @() -WatchRoots @('C:\x'))
  Check 'json: no installations' ($empty -match '"installations":\s*\[\s*\]') $true
  Check 'json: watch roots array' ($empty -match '"watchRoots":\s*\[\s*"C:\\\\x"\s*\]') $true
  Check 'json: no selected root' ($empty -match 'selectedRoot') $false
  Check 'json: escaping' (ConvertTo-E2EJson ([ordered]@{ a = "q`"b\c`n" + [char]0xE4; n = 5; t = $true; z = $null; e = @{} })) `
    "{`n  `"a`": `"q\`"b\\c\u000a\u00e4`",`n  `"n`": 5,`n  `"t`": true,`n  `"z`": null,`n  `"e`": {}`n}"
  Check 'json: compact' (ConvertTo-E2EJson ([ordered]@{ a = @('x'); b = [ordered]@{ c = 1 } }) -Compress) '{"a":["x"],"b":{"c":1}}'
  Check 'json: nested list' (ConvertTo-E2EJson @(@(1, 2), @())) "[`n  [`n    1,`n    2`n  ],`n  []`n]"
  # A list that passed the pipeline (Windows PowerShell 5.1 wraps it) stays a list
  function Get-Wrapped { return , @('one') }
  Check 'json: list from a function' (ConvertTo-E2EJson ([ordered]@{ l = (Get-Wrapped) })) "{`n  `"l`": [`n    `"one`"`n  ]`n}"
  $script:Count++
  try { ConvertTo-E2EJson ([ordered]@{ d = [datetime]::Now }) | Out-Null; $script:Failures++; Write-Host 'FAIL json: unsupported type accepted' } catch { }

  # --- Products
  Check 'product EE AppId' (Get-E2EProduct 'EE').AppId '4C0B46D8-E7EB-4B95-97D4-A578D9B914C6'
  Check 'product NeoEE AppId' (Get-E2EProduct 'NeoEE').AppId 'A24FCC7A-5491-4FEA-837B-4E4430C349DA'
  Check 'product NeoEE setup' (Get-E2EProduct 'NeoEE').SetupFile 'NeoEE_v2.0.0.5_Setup_v1.7.2.exe'
  $script:Count++
  try { Get-E2EProduct 'Other' | Out-Null; $script:Failures++; Write-Host 'FAIL unknown product: no exception' } catch { }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
