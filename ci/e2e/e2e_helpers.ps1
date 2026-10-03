# Pure helpers of the real-data end-to-end test (.github/workflows/e2e-realdata.yml): constants,
# the result file, and every rule that only looks at text, bytes or values handed to it (logs,
# install.ini, files.sha256, registry values read elsewhere, the hosts file, the setup arguments,
# the expectation files of the launcher checks). Nothing here touches the registry, the network or
# a process, so ci/e2e/tests/e2e_helpers.tests.ps1 tests all of it with fake data, also with
# PowerShell 7 on Linux. Windows PowerShell 5.1 compatible (no PowerShell 7 syntax), ASCII only.
# Dot-source it: . (Join-Path $PSScriptRoot 'e2e_helpers.ps1')

# --- Constants (docs/CONTRACT.md, setup_is6.iss, config_*.iss) --------------------------------

$E2EConst = @{
  SetupVersion       = '1.7.2'
  ContractVersion    = 1
  CommunityKey       = 'Software\Empire Earth Community'
  UninstallKey       = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
  LayersKey          = 'Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
  GpuKey             = 'Software\Microsoft\DirectX\UserGpuPreferences'
  # Briefing D6 / contract 3.8: never deleted, never printed; the job seeds a dummy value only
  CdKeysKey          = 'Software\Sierra\CDKeys'
  CdKeyDummyName     = 'CI-Dummy'
  CdKeyDummyValue    = 'NOT-A-KEY-0000'
  # Root certificate of the official 1.7.2 setups (task certinclude, never selected here)
  OfficialCertThumbprint = 'F8738C3549EF138F6F3B1777D4CC1ACF233DCD47'
  # Flags of the tasks compatibility + compatibility_windows on Windows 8 and later (contract 3.7)
  CompatValue        = '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM'
  # RegisterLangs (setup_is6.iss, GameLangs)
  RegisteredLanguages = 'de,en,es,fr,it,ko,pl,pt_BR,ru,zh_CN,zh_TW'
  # The mirror of the localized files; reachable only while scenario A runs
  MirrorHost         = 'storage.ee.zocker-160.de'
  # Every host the setups (v2 and official 1.7.2) or the launcher could contact, blocked in the
  # hosts file before the first setup runs: update API and statistics (also the eestats endpoints
  # of EEStats.dll), the file servers, the NeoEE CD key server, the player list of the launcher and
  # the ShellExec targets of the interactive wizard
  BlockedHosts       = @('api.empireearth.eu', 'files.empireearth.eu', 'storage.ee.zocker-160.de',
                         'neoee.net', 'www.neoee.net', 'titan.empireearth.eu', 'empireearth.eu',
                         'www.empireearth.eu', 'www.gog.com')
  HostsBegin         = '# BEGIN ee-e2e (ci/e2e: hosts blocked for the end-to-end test)'
  HostsEnd           = '# END ee-e2e'
  # Time limits of the programs the scenarios start (minutes), well below the step limits of the
  # workflow, and the part of a phase budget kept for the uninstallation at the end of a scenario
  # (the uninstaller limit plus its waits of up to 4 minutes; ci/e2e/tests/test_e2e_tools.py checks
  # these numbers against the workflow)
  SetupTimeoutMinutes     = 25
  UninstallTimeoutMinutes = 10
  LauncherTimeoutMinutes  = 10
  CleanupReserveMinutes   = 15
}

$E2EGames = @{
  EE  = @{ Id = 'EE';  Folder = 'Empire Earth';                       Exe = 'Empire Earth.exe'; Component = 'game';    EndingEpoch = 13 }
  AoC = @{ Id = 'AoC'; Folder = 'Empire Earth - The Art of Conquest'; Exe = 'EE-AOC.exe';       Component = 'gameaoc'; EndingEpoch = 14 }
}

# The product configuration (config_ee.iss, config_neoee.iss) and the real AppIds of the builds
function Get-E2EProduct([string]$Id) {
  switch ($Id) {
    'EE' {
      return @{
        Id = 'EE'; AppName = 'Empire Earth'; Publisher = 'Empire Earth Community'; GameVersion = '2.0.0.0'
        DirName = 'Empire Earth'; AppId = '4C0B46D8-E7EB-4B95-97D4-A578D9B914C6'
        SettingsKeys = @{ EE = 'Software\SSSI\Empire Earth'; AoC = 'Software\Mad Doc Software\EE-AOC' }
        SetupFile = 'EE_Setup_v1.7.2.exe'; BuildFolder = 'EE_Regular'; SetupMutex = 'EE_Setup'
        SetupDataDir = '_setupdata_EE'
      }
    }
    'NeoEE' {
      return @{
        Id = 'NeoEE'; AppName = 'NeoEE'; Publisher = 'Empire Earth Community & NeoEE'; GameVersion = '2.0.0.5'
        DirName = 'Neo Empire Earth'; AppId = 'A24FCC7A-5491-4FEA-837B-4E4430C349DA'
        SettingsKeys = @{ EE = 'Software\Neo\Empire Earth'; AoC = 'Software\Neo\Art of Conquest' }
        SetupFile = 'NeoEE_v2.0.0.5_Setup_v1.7.2.exe'; BuildFolder = 'NeoEE_Regular'; SetupMutex = 'NeoEE_Setup'
        SetupDataDir = '_setupdata_NeoEE'
      }
    }
  }
  throw "Unknown product $Id"
}

# --- Results ----------------------------------------------------------------------------------

$script:E2EResultFile = $null
$script:E2EStatuses = @('PASS', 'FAIL', 'WARN', 'SERVER', 'SKIP', 'INFO')

function Initialize-E2EResults([string]$Path) {
  $folder = Split-Path -Parent $Path
  if ($folder -and -not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
  $script:E2EResultFile = $Path
}

# A text for the report: hashes (40 or 64 hex digits) are replaced, so no report line carries the
# hash of a game file, and the line is cut to 300 characters
function ConvertTo-E2ESafeText([string]$Text) {
  if ($null -eq $Text) { return '' }
  $safe = [regex]::Replace($Text, '(?<![0-9A-Fa-f])([0-9A-Fa-f]{64}|[0-9A-Fa-f]{40})(?![0-9A-Fa-f])', '<hash>')
  $safe = $safe -replace '[\r\n]+', ' '
  if ($safe.Length -gt 300) { $safe = $safe.Substring(0, 297) + '...' }
  return $safe
}

# Escapes the text of a GitHub workflow command (::error ...)
function ConvertTo-E2EAnnotation([string]$Text) {
  return $Text.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

# One result line (JSON) in the result file, and a line on the console
function Add-E2EResult {
  param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Check,
    [Parameter(Mandatory = $true)][string]$Status,
    [string[]]$Details = @()
  )
  if ($script:E2EStatuses -notcontains $Status) { throw "Unknown status $Status" }
  $safe = @($Details | Where-Object { $_ } | Select-Object -First 25 | ForEach-Object { ConvertTo-E2ESafeText $_ })
  $total = @($Details | Where-Object { $_ }).Count
  if ($total -gt $safe.Count) { $safe += "... and $($total - $safe.Count) more" }
  $record = [ordered]@{ scenario = $Scenario; check = $Check; status = $Status; details = $safe }
  $line = ConvertTo-E2EJson $record -Compress
  if ($script:E2EResultFile) {
    [System.IO.File]::AppendAllText($script:E2EResultFile, $line + "`n", (New-Object System.Text.UTF8Encoding($false)))
  }
  $first = ''
  if ($safe.Count -gt 0) { $first = ': ' + $safe[0] }
  Write-Host ('[{0}] {1} {2}{3}' -f $Status, $Scenario, $Check, $first)
  if ($Status -eq 'FAIL' -and $env:GITHUB_ACTIONS -eq 'true') {
    Write-Host ('::error title=E2E {0} {1}::{2}' -f $Scenario, $Check, (ConvertTo-E2EAnnotation (($safe | Select-Object -First 3) -join ' | ')))
  }
}

# PASS if Problems is empty, else FAIL (WARN with -Soft); Ok is the detail of a pass
function Complete-E2ECheck {
  param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Check,
    [string[]]$Problems = @(),
    [string]$Ok = '',
    [switch]$Soft
  )
  $list = @($Problems | Where-Object { $_ })
  if ($list.Count -eq 0) {
    $details = @()
    if ($Ok) { $details = @($Ok) }
    Add-E2EResult -Scenario $Scenario -Check $Check -Status 'PASS' -Details $details
  } elseif ($Soft) {
    Add-E2EResult -Scenario $Scenario -Check $Check -Status 'WARN' -Details $list
  } else {
    Add-E2EResult -Scenario $Scenario -Check $Check -Status 'FAIL' -Details $list
  }
  return ($list.Count -eq 0)
}

# --- Time budget of a phase -------------------------------------------------------------------------

# Seconds a program may run: at most Requested, and never past the end of the phase budget
# (SecondsLeft; $null: no budget). A program that is not the cleanup itself must also leave
# ReserveSeconds for the uninstallation at the end of the scenario. 0: do not start it (less than a
# minute left, a setup stopped right after its start would only leave a half installation).
function Get-E2EBudgetedSeconds([int]$Requested, $SecondsLeft, [int]$ReserveSeconds, [bool]$Cleanup) {
  if ($null -eq $SecondsLeft) { return $Requested }
  $available = [double]$SecondsLeft
  if (-not $Cleanup) { $available -= $ReserveSeconds }
  if ($available -lt 60) { return 0 }
  return [int][Math]::Min([double]$Requested, [Math]::Floor($available))
}

# --- Text, lists and paths ----------------------------------------------------------------------

# Uppercase like Pascal's UpperCase: only a-z change (GetInstallWithoutDriveLetterBase)
function ConvertTo-E2EAsciiUpper([string]$Text) {
  $chars = $Text.ToCharArray()
  for ($i = 0; $i -lt $chars.Length; $i++) {
    if ($chars[$i] -ge [char]'a' -and $chars[$i] -le [char]'z') { $chars[$i] = [char]([int]$chars[$i] - 32) }
  }
  return -join $chars
}

# The items of a comma separated list (Components=, Tasks=, /TASKS=), trimmed, without empty ones
function Split-E2EList([string]$Text) {
  if (-not $Text) { return @() }
  return @($Text.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

# Missing (in Expected, not in Actual) and Extra (in Actual, not in Expected), ignoring case
function Compare-E2ESets([string[]]$Expected, [string[]]$Actual) {
  $exp = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $act = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($item in @($Expected)) { if ($null -ne $item) { [void]$exp.Add($item) } }
  foreach ($item in @($Actual)) { if ($null -ne $item) { [void]$act.Add($item) } }
  $missing = @($exp | Where-Object { -not $act.Contains($_) } | Sort-Object)
  $extra = @($act | Where-Object { -not $exp.Contains($_) } | Sort-Object)
  return @{ Missing = $missing; Extra = $extra }
}

# The paths that are one of the roots or lie below one (case-insensitive, '/' and '\' alike), e.g.
# the value names of the compatibility layers or GPU preferences that belong to a test folder
function Select-E2EPathsBelow([string[]]$Paths, [string[]]$Roots) {
  $prefixes = @($Roots | Where-Object { $_ } | ForEach-Object { $_.Replace('/', '\').TrimEnd('\').ToLowerInvariant() })
  return @($Paths | Where-Object {
    $path = ([string]$_).Replace('/', '\').ToLowerInvariant()
    @($prefixes | Where-Object { $path -ceq $_ -or $path.StartsWith($_ + '\', [System.StringComparison]::Ordinal) }).Count -gt 0
  })
}

# Problems for the lines of two snapshots (sorted text lines) that differ, at most Max of them
function Compare-E2ESnapshot([string[]]$Before, [string[]]$After, [string]$What, [int]$Max = 10) {
  $diff = Compare-E2ESets $Before $After
  $problems = @()
  foreach ($line in ($diff.Missing | Select-Object -First $Max)) { $problems += "$What changed or gone: $line" }
  foreach ($line in ($diff.Extra | Select-Object -First $Max)) { $problems += "$What new or changed: $line" }
  return $problems
}

# --- Setup logs ------------------------------------------------------------------------------------

# The lines of an Inno Setup log without the time stamp ("2026-10-03 10:00:00.123   text")
function ConvertFrom-E2ELogText([string]$Text) {
  if (-not $Text) { return @() }
  return @($Text -split "`r?`n" | ForEach-Object { $_ -replace '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\s+', '' })
}

# Problems of the log lines: every Contains text in some line (ordinal, case-sensitive), every
# Matches pattern matching some line, no NotContains text and no NotMatches pattern in any line
function Test-E2ELogLines {
  param(
    [string[]]$Lines = @(),
    [string[]]$Contains = @(),
    [string[]]$Matches = @(),
    [string[]]$NotContains = @(),
    [string[]]$NotMatches = @()
  )
  $problems = @()
  foreach ($text in $Contains) {
    if (-not ($Lines | Where-Object { $_.IndexOf($text, [System.StringComparison]::Ordinal) -ge 0 } | Select-Object -First 1)) {
      $problems += "log line missing: $text"
    }
  }
  foreach ($pattern in $Matches) {
    if (-not ($Lines | Where-Object { $_ -cmatch $pattern } | Select-Object -First 1)) { $problems += "log line missing (pattern): $pattern" }
  }
  foreach ($text in $NotContains) {
    $hit = $Lines | Where-Object { $_.IndexOf($text, [System.StringComparison]::Ordinal) -ge 0 } | Select-Object -First 1
    if ($hit) { $problems += "log line not allowed: $hit" }
  }
  foreach ($pattern in $NotMatches) {
    $hit = $Lines | Where-Object { $_ -cmatch $pattern } | Select-Object -First 1
    if ($hit) { $problems += "log line not allowed: $hit" }
  }
  return $problems
}

# The lines that match Pattern (case-sensitive)
function Select-E2ELogLines([string[]]$Lines, [string]$Pattern) {
  return @($Lines | Where-Object { $_ -cmatch $Pattern })
}

# Size of the primary screen and the game window from the log line of environment.iss
# ('Screen: <w> x <h> pixels (primary screen, ...), ..., game window <W> x <H>'), or $null
function Get-E2EScreen([string[]]$Lines) {
  foreach ($line in $Lines) {
    if ($line -cmatch '^Screen: (-?\d+) x (-?\d+) pixels \(primary screen, SM_CXSCREEN x SM_CYSCREEN\), (.*), game window (\d+) x (\d+)$') {
      return @{ Width = [int]$Matches[1]; Height = [int]$Matches[2]; Dpi = $Matches[3]
                WindowWidth = [int]$Matches[4]; WindowHeight = [int]$Matches[5] }
    }
  }
  return $null
}

# Value within Lowest .. Highest (ClampToRange, utils.iss)
function Get-E2EClamped([int]$Value, [int]$Lowest, [int]$Highest) {
  if ($Value -lt $Lowest) { return $Lowest }
  if ($Value -gt $Highest) { return $Highest }
  return $Value
}

# The GPU option of a first installation from the log (pages.iss, RegisterGpuOptions):
# @{ Vendor; LogName; Wrapper; Problems }. The runner's vendor is not known in advance, so the
# expected wrapper follows the detected vendor.
function Get-E2EGpuChoice([string[]]$Lines) {
  $table = @{
    'Unknown' = @{ LogName = 'general'; Wrapper = 'additional\directx_wrapper\dx9' }
    'NVIDIA'  = @{ LogName = 'NVIDIA';  Wrapper = 'additional\directx_wrapper\dx11_lvl11' }
    'AMD'     = @{ LogName = 'AMD';     Wrapper = 'additional\directx_wrapper\dx11_lvl11' }
    'Intel'   = @{ LogName = 'Intel';   Wrapper = 'additional\directx_wrapper\dx11_lvl10_1' }
  }
  $vendor = $null
  foreach ($line in $Lines) {
    if ($line -ceq 'Unknown GPU detected') { $vendor = 'Unknown'; break }
    if ($line -cmatch '^(NVIDIA|AMD|Intel) GPU detected$') { $vendor = $Matches[1]; break }
  }
  if (-not $vendor) { return @{ Vendor = $null; LogName = $null; Wrapper = $null; Problems = @('no "GPU detected" line in the log') } }
  $choice = $table[$vendor]
  return @{ Vendor = $vendor; LogName = $choice.LogName; Wrapper = $choice.Wrapper; Problems = @() }
}

# --- install.ini (contract 1.2) -----------------------------------------------------------------

# Checks the bytes of install.ini: no BOM, ASCII, CRLF only and at the end, the keys of the contract
# in their order with the expected values (Expected: ContractVersion, Product, AppId, InstallMode,
# GameVersion, SetupVersion, SetupBuild = '' for none), Written as yyyy-mm-dd hh:nn:ss, nothing else
# (no [MissingAfterInstall]). Returns @{ Problems; Values } (Values: key -> value of [Install]).
function Test-E2EInstallIniBytes([byte[]]$Bytes, [hashtable]$Expected) {
  $problems = @()
  $values = [ordered]@{}
  if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return @{ Problems = @('install.ini is empty'); Values = $values } }
  if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { $problems += 'install.ini has a BOM' }
  for ($i = 0; $i -lt $Bytes.Length; $i++) {
    $b = $Bytes[$i]
    if ($b -gt 127) { $problems += "install.ini is not ASCII (byte $i)"; break }
    if ($b -eq 10 -and ($i -eq 0 -or $Bytes[$i - 1] -ne 13)) { $problems += "install.ini has an LF without CR (byte $i)"; break }
    if ($b -eq 13 -and ($i + 1 -ge $Bytes.Length -or $Bytes[$i + 1] -ne 10)) { $problems += "install.ini has a CR without LF (byte $i)"; break }
  }
  if ($Bytes.Length -lt 2 -or $Bytes[$Bytes.Length - 2] -ne 13 -or $Bytes[$Bytes.Length - 1] -ne 10) { $problems += 'install.ini does not end with CRLF' }
  $text = [System.Text.Encoding]::ASCII.GetString($Bytes)
  $lines = @($text -split "`r`n")
  if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
  $keys = @('ContractVersion', 'Product', 'AppId', 'InstallMode', 'GameVersion', 'SetupVersion')
  if ($Expected.SetupBuild) { $keys += 'SetupBuild' }
  $keys += @('Components', 'Tasks', 'Written')
  if ($lines.Count -lt 1 -or $lines[0] -cne '[Install]') { $problems += 'install.ini does not start with [Install]' }
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $at = $line.IndexOf('=')
    if ($at -lt 1) { $problems += "install.ini line $($i + 1) is not key=value: $line"; continue }
    $values[$line.Substring(0, $at)] = $line.Substring($at + 1)
  }
  $actualKeys = @($values.Keys)
  if (($actualKeys -join ',') -cne ($keys -join ',')) {
    $problems += "install.ini keys are [$($actualKeys -join ', ')], expected [$($keys -join ', ')]"
  }
  foreach ($key in @('ContractVersion', 'Product', 'AppId', 'InstallMode', 'GameVersion', 'SetupVersion', 'SetupBuild')) {
    if (-not $Expected.ContainsKey($key)) { continue }
    $want = [string]$Expected[$key]
    if ($key -eq 'SetupBuild' -and -not $want) { continue }
    if ($values.Contains($key) -and [string]$values[$key] -cne $want) { $problems += "install.ini ${key}=$($values[$key]), expected $want" }
  }
  if ($values.Contains('Written') -and [string]$values['Written'] -notmatch '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$') {
    $problems += "install.ini Written=$($values['Written']) is not yyyy-mm-dd hh:nn:ss"
  }
  return @{ Problems = $problems; Values = $values }
}

# --- files.sha256 (contract 2.1 to 2.3) --------------------------------------------------------------

# Checks the bytes of the manifest: no BOM, ASCII, LF only and at the end, every line
# '<64 lowercase hex>  <path>' with a safe relative path, no duplicates ignoring case, the order of
# CompareManifestPaths (ordinal on the uppercase paths), and the exclusions of contract 2.3 (the setup
# data folder, unins*.exe/.dat in the root, _wonkver.pub). Returns @{ Problems; Entries } (Entries:
# @{ Hash; Path } in file order).
function Test-E2EManifestBytes([byte[]]$Bytes, [string]$SetupDataDir) {
  $problems = @()
  $entries = New-Object System.Collections.Generic.List[object]
  if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return @{ Problems = @('files.sha256 is empty'); Entries = @() } }
  if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { $problems += 'files.sha256 has a BOM' }
  foreach ($b in $Bytes) {
    if ($b -eq 13) { $problems += 'files.sha256 contains a CR'; break }
    if ($b -gt 127) { $problems += 'files.sha256 is not ASCII'; break }
  }
  if ($Bytes[$Bytes.Length - 1] -ne 10) { $problems += 'files.sha256 does not end with LF' }
  $text = [System.Text.Encoding]::ASCII.GetString($Bytes)
  $lines = @($text.Split([char]10))
  if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $previous = $null
  $orderProblems = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -cnotmatch '^([0-9a-f]{64})  ([^\\:]+)$') { $problems += "files.sha256 line $($i + 1) is malformed"; continue }
    $hash = $Matches[1]
    $path = $Matches[2]
    $segments = $path.Split('/')
    if ($path.StartsWith('/') -or ($segments | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' })) {
      $problems += "files.sha256 line $($i + 1) has an unsafe path: $path"
    }
    if ($segments.Count -gt 1 -and $segments[0] -ieq $SetupDataDir) { $problems += "files.sha256 lists the setup data folder: $path" }
    if ($segments.Count -eq 1 -and $path -imatch '^unins.*\.(exe|dat)$') { $problems += "files.sha256 lists the uninstaller: $path" }
    if ($segments[$segments.Count - 1] -ieq '_wonkver.pub') { $problems += "files.sha256 lists _wonkver.pub: $path" }
    if (-not $seen.Add($path)) { $problems += "files.sha256 lists $path twice (ignoring case)" }
    if ($null -ne $previous -and [string]::CompareOrdinal((ConvertTo-E2EAsciiUpper $previous), (ConvertTo-E2EAsciiUpper $path)) -gt 0) {
      $orderProblems++
      if ($orderProblems -le 3) { $problems += "files.sha256 is not sorted: $previous before $path" }
    }
    $previous = $path
    $entries.Add(@{ Hash = $hash; Path = $path })
  }
  if ($entries.Count -eq 0) { $problems += 'files.sha256 has no entry' }
  return @{ Problems = $problems; Entries = $entries.ToArray() }
}

# Problems of the component list: never additional\telemetry, exactly one game language and it is
# language\<Language>, the DirectX wrapper is exactly Wrapper ('' = none), every Required present,
# no Forbidden one
function Test-E2EComponents([string[]]$Components, [string]$Language, [string]$Wrapper, [string[]]$Required = @(), [string[]]$Forbidden = @()) {
  $problems = @()
  $set = Compare-E2ESets $Components @()
  if ($Components -contains 'additional\telemetry') { $problems += 'the telemetry component is selected' }
  $languages = @($Components | Where-Object { $_ -like 'language\*' -and $_ -ne 'language\update' })
  if ($languages.Count -ne 1 -or $languages[0] -ne "language\$Language") {
    $problems += "game languages [$($languages -join ', ')], expected language\$Language"
  }
  $wrappers = @($Components | Where-Object { $_ -like 'additional\directx_wrapper\*' })
  if ($Wrapper) {
    if ($wrappers.Count -ne 1 -or $wrappers[0] -ne $Wrapper) { $problems += "DirectX wrapper [$($wrappers -join ', ')], expected $Wrapper" }
  } elseif ($wrappers.Count -gt 0) {
    $problems += "DirectX wrapper [$($wrappers -join ', ')], expected none"
  }
  $missing = (Compare-E2ESets $Required $Components).Missing
  if ($missing.Count -gt 0) { $problems += "components missing: $($missing -join ', ')" }
  $present = @($Forbidden | Where-Object { $Components -contains $_ })
  if ($present.Count -gt 0) { $problems += "components not expected: $($present -join ', ')" }
  [void]$set
  return $problems
}

# --- Registry values (read by e2e_windows.ps1 into @{ name = @{ Kind; Value } }) ---------------------

function New-E2ERegValue([string]$Kind, $Value) {
  return @{ Kind = $Kind; Value = $Value }
}

# The text of a registry value (from Get-E2ERegValues), '' if the key or the value is missing
function Get-E2ERegString([hashtable]$Values, [string]$Name) {
  if ($null -eq $Values -or -not $Values.ContainsKey($Name) -or $null -eq $Values[$Name].Value) { return '' }
  return [string]$Values[$Name].Value
}

# The SHA-1 of a path of the asset map (Import-E2EAssetMap), '' if the map does not name it
function Get-E2EMapSha1([hashtable]$Map, [string]$Path) {
  $row = $Map[$Path.ToLowerInvariant()]
  if ($null -eq $row) { return '' }
  return [string]$row.Sha1
}

# Problems of the values of one key against Expected (name -> @{ Kind; Value }); with -Exact no other
# value may exist. Actual $null means the key does not exist.
function Compare-E2ERegValues {
  param(
    [hashtable]$Actual,
    [hashtable]$Expected,
    [string]$Where,
    [switch]$Exact
  )
  if ($null -eq $Actual) { return @("$Where does not exist") }
  $problems = @()
  foreach ($name in ($Expected.Keys | Sort-Object)) {
    $want = $Expected[$name]
    if (-not $Actual.ContainsKey($name)) { $problems += "$Where value '$name' missing"; continue }
    $have = $Actual[$name]
    if ($have.Kind -ne $want.Kind) { $problems += "$Where value '$name' is $($have.Kind), expected $($want.Kind)"; continue }
    if ($want.Kind -eq 'DWord' -or $want.Kind -eq 'QWord') {
      if ([int64]$have.Value -ne [int64]$want.Value) { $problems += "$Where value '$name' = $($have.Value), expected $($want.Value)" }
    } elseif ([string]$have.Value -cne [string]$want.Value) {
      $problems += "$Where value '$name' = '$($have.Value)', expected '$($want.Value)'"
    }
  }
  if ($Exact) {
    foreach ($name in ($Actual.Keys | Sort-Object)) {
      if (-not $Expected.ContainsKey($name)) { $problems += "$Where has the unexpected value '$name'" }
    }
  }
  return $problems
}

# The game settings the setup writes on a first installation (contract 3.1 to 3.3, [Registry]
# GameSettings): @{ Main = values of the key; Options = values of its subkey Game Options }
function Get-E2EGameSettingsExpected([string]$Root, [string]$GameFolder, [bool]$Wrapper, [int]$WindowWidth, [int]$WindowHeight, [int]$EndingEpoch) {
  $rasterizer = 'Direct3D Hardware TnL'
  if ($Wrapper) { $rasterizer = 'Direct3D' }
  $main = @{
    'Installed From Volume'    = New-E2ERegValue 'String' $Root.Substring(0, 2)
    'Installed From Directory' = New-E2ERegValue 'String' ((ConvertTo-E2EAsciiUpper $Root.Substring(2)) + '\' + $GameFolder + '\')
    'Rasterizer Name'          = New-E2ERegValue 'String' $rasterizer
    'Wait for VSync'           = New-E2ERegValue 'DWord' 0
    'Game Bit Depth'           = New-E2ERegValue 'DWord' 32
    'Texture Bit Depth'        = New-E2ERegValue 'DWord' 32
    'Game Window Width'        = New-E2ERegValue 'DWord' $WindowWidth
    'Game Window Height'       = New-E2ERegValue 'DWord' $WindowHeight
    'AutoSave In Milliseconds' = New-E2ERegValue 'DWord' 1200000
    'Music Volume'             = New-E2ERegValue 'DWord' 44
    'Sound Volume'             = New-E2ERegValue 'DWord' 60
    'Take JPG Screenshots'     = New-E2ERegValue 'DWord' 1
  }
  $options = @{
    'Map Type'            = New-E2ERegValue 'String' 'Continental'
    'Map Size'            = New-E2ERegValue 'DWord' 2
    'Starting Resources'  = New-E2ERegValue 'DWord' 3
    'Starting Epoch'      = New-E2ERegValue 'DWord' 0
    'Ending Epoch'        = New-E2ERegValue 'DWord' $EndingEpoch
    'Game Unit Limit'     = New-E2ERegValue 'DWord' 1200
    'Wonders For Victory' = New-E2ERegValue 'DWord' 0
    'Game Variant'        = New-E2ERegValue 'DWord' 2
    'Difficulty Level'    = New-E2ERegValue 'DWord' 0
    'Game Speed'          = New-E2ERegValue 'DWord' 3
    'Reveal Map'          = New-E2ERegValue 'DWord' 0
    'Allow Custom Civs'   = New-E2ERegValue 'DWord' 1
    'Lock Teams'          = New-E2ERegValue 'DWord' 1
    'Lock Speed'          = New-E2ERegValue 'DWord' 1
    'Cheat Codes'         = New-E2ERegValue 'DWord' 0
  }
  return @{ Main = $main; Options = $options }
}

# --- Online files (downloads.iss) --------------------------------------------------------------

# The downloads the log reports as verified or accepted at ssInstall:
# @{ RelPath; Hash; Pinned } per line 'Online file verified, SHA-256 pinned: <path> (SHA-256 <h>)' or
# 'Online file accepted, TLS-verified, not pinned: <path> (SHA-256 <h>)'
function Get-E2EDownloadRecords([string[]]$Lines) {
  $records = @()
  foreach ($line in $Lines) {
    if ($line -cmatch '^Online file verified, SHA-256 pinned: (.+) \(SHA-256 ([0-9a-fA-F]{64})\)$') {
      $records += @{ RelPath = $Matches[1]; Hash = $Matches[2].ToLowerInvariant(); Pinned = $true }
    } elseif ($line -cmatch '^Online file accepted, TLS-verified, not pinned: (.+) \(SHA-256 ([0-9a-fA-F]{64})\)$') {
      $records += @{ RelPath = $Matches[1]; Hash = $Matches[2].ToLowerInvariant(); Pinned = $false }
    }
  }
  return $records
}

# The manifest paths an online file is installed to (RegisterGameOnlineFiles, [Files]): the server
# folders Game/<lang>/<EE|AoC>/ and Lobby/<lang>/<EE|AoC>/ map to that game folder, Lobby/<lang>/shared/
# to every installed game, and AoC also gets the learning campaign of EE
function Get-E2EOnlineFileTargets([string]$RelPath, [string[]]$Games) {
  $targets = @()
  if ($RelPath -cmatch '^(?:Mods/NeoEE/)?(?:Game|Lobby)/[^/]+/(EE|AoC)/(.+)$') {
    $game = $Matches[1]
    $rest = $Matches[2]
    if ($Games -contains $game) { $targets += $E2EGames[$game].Folder + '/' + $rest }
    if ($game -eq 'EE' -and $rest -eq 'Data/Campaigns/EELearningCampaign.ssa' -and $Games -contains 'AoC') {
      $targets += $E2EGames['AoC'].Folder + '/' + $rest
    }
  } elseif ($RelPath -cmatch '^(?:Mods/NeoEE/)?Lobby/[^/]+/shared/(.+)$') {
    $rest = $Matches[1]
    foreach ($game in $Games) { $targets += $E2EGames[$game].Folder + '/' + $rest }
  }
  return $targets
}

# path -> lowercase SHA-256 of data\localized-text.sha256 ('<hash>  <path>' lines, LF or CRLF) or
# of pins\online-files.txt ('<hash> <size> <server path>' lines; '#' comment lines are skipped)
function ConvertFrom-E2EPinList([string]$Text) {
  $pins = @{}
  foreach ($line in ($Text -split "`r?`n")) {
    if ($line -cmatch '^([0-9a-fA-F]{64}) [ *](.+)$') { $pins[$Matches[2]] = $Matches[1].ToLowerInvariant() }
    elseif ($line -cmatch '^([0-9a-f]{64}) [1-9][0-9]* (.+)$') { $pins[$Matches[2]] = $Matches[1] }
  }
  return $pins
}

# --- Hosts file ------------------------------------------------------------------------------------

# The hosts file text with the block of this test replaced: two lines per name (0.0.0.0 and ::),
# so that IPv4 and IPv6 are both blocked. No names: the block is removed. Other lines stay.
function Get-E2EHostsText([string]$Current, [string[]]$Names) {
  $kept = @()
  $inside = $false
  foreach ($line in ($Current -split "`r?`n")) {
    if ($line -ceq $E2EConst.HostsBegin) { $inside = $true; continue }
    if ($line -ceq $E2EConst.HostsEnd) { $inside = $false; continue }
    if (-not $inside) { $kept += $line }
  }
  while ($kept.Count -gt 0 -and $kept[$kept.Count - 1] -eq '') { $kept = @($kept | Select-Object -First ($kept.Count - 1)) }
  if (@($Names).Count -gt 0) {
    $kept += $E2EConst.HostsBegin
    foreach ($name in $Names) { $kept += "0.0.0.0 $name"; $kept += ":: $name" }
    $kept += $E2EConst.HostsEnd
  }
  return (($kept -join "`r`n") + "`r`n")
}

# --- Setup arguments ----------------------------------------------------------------------------

# The value of a switch /NAME=value (quotes removed), or $null
function Get-E2ESwitchValue([string[]]$Arguments, [string]$Name) {
  foreach ($arg in $Arguments) {
    if ($arg -imatch ('^/' + [regex]::Escape($Name) + '=(.*)$')) { return $Matches[1].Trim('"') }
  }
  return $null
}

# Problems of the arguments of a setup run against the hard rules of the test: never the telemetry
# component, never the tasks neoee_cdkeys (CD key registration), certinclude (root certificate),
# directplay or dxwebsetup (downloads from Microsoft) unless negated with '!'; silent with a log;
# the official setup and every NeoEE setup only with an explicit /TASKS list (certinclude and
# neoee_cdkeys are preselected otherwise); an update may use /MERGETASKS with negations instead.
function Test-E2ESetupArguments([string[]]$Arguments, [ValidateSet('v2', 'official')][string]$Kind, [string]$Product, [bool]$FirstInstall) {
  $problems = @()
  $joined = $Arguments -join ' '
  if ($joined -imatch 'telemetry') { $problems += 'the arguments name the telemetry component' }
  foreach ($required in @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')) {
    if ($Arguments -notcontains $required) { $problems += "$required missing" }
  }
  if ($null -eq (Get-E2ESwitchValue $Arguments 'LOG')) { $problems += '/LOG= missing' }
  $forbiddenTasks = @('neoee_cdkeys', 'certinclude', 'directplay', 'dxwebsetup')
  $tasks = Get-E2ESwitchValue $Arguments 'TASKS'
  $merge = Get-E2ESwitchValue $Arguments 'MERGETASKS'
  foreach ($list in @($tasks, $merge)) {
    foreach ($task in (Split-E2EList $list)) {
      if ($forbiddenTasks -contains $task) { $problems += "the task $task must not be selected" }
    }
  }
  $needsExactTasks = ($Kind -eq 'official') -or ($Product -eq 'NeoEE' -and $FirstInstall)
  if ($needsExactTasks -and $null -eq $tasks) { $problems += 'an explicit /TASKS list is required (preselected tasks)' }
  if ($Product -eq 'NeoEE' -and -not $FirstInstall -and $null -eq $tasks -and (Split-E2EList $merge) -notcontains '!neoee_cdkeys') {
    $problems += 'a NeoEE update needs /TASKS or /MERGETASKS with !neoee_cdkeys'
  }
  return $problems
}

# --- Expectation files of the launcher checks (Empire-Earth-Launcher.RealMachineTests, schema 1) ----

# One installation of an expectation; Extra holds further members (integrity, defaultsStatus, ...)
function New-E2ELauncherInstallation([string]$Product, [string]$Root, [hashtable]$Extra = @{}) {
  $installation = [ordered]@{ product = $Product; root = $Root }
  foreach ($key in ($Extra.Keys | Sort-Object)) { $installation[$key] = $Extra[$key] }
  return $installation
}

# An expectation file (README of the launcher, Tests, "Real machine")
function New-E2ELauncherExpectation {
  param(
    [string]$Scenario,
    [string]$Step,
    [object[]]$Installations = @(),
    [string]$SelectedRoot,
    [string[]]$WatchRoots = @(),
    [hashtable]$Defaults,
    [bool]$ExactInstallations = $true
  )
  $expectation = [ordered]@{ schema = 1; scenario = $Scenario; step = $Step; exactInstallations = $ExactInstallations }
  if ($SelectedRoot) { $expectation['selectedRoot'] = $SelectedRoot }
  if (@($WatchRoots).Count -gt 0) { $expectation['watchRoots'] = @($WatchRoots) }
  $expectation['installations'] = @($Installations)
  if ($Defaults) { $expectation['defaults'] = $Defaults }
  return $expectation
}

# JSON of an expectation: dictionaries (in their key order), lists, strings, numbers, booleans and
# null. Written here instead of ConvertTo-Json, whose Windows PowerShell 5.1 version can turn an
# array that passed the pipeline into {"value": [...], "Count": n}; every list stays a list, also
# with one or no item, and the output is ASCII (other characters as \uXXXX).
# With -Compress: one line (the result file).
function ConvertTo-E2EJson($Object, [switch]$Compress) {
  $builder = New-Object System.Text.StringBuilder
  Add-E2EJsonValue $builder $Object '' (-not $Compress)
  return $builder.ToString()
}

function Add-E2EJsonValue([System.Text.StringBuilder]$Builder, $Value, [string]$Indent, [bool]$Pretty) {
  if ($Value -is [System.Management.Automation.PSObject]) { $Value = $Value.PSObject.BaseObject }
  $inner = ''
  $newLine = ''
  $colon = ':'
  if ($Pretty) { $inner = $Indent + '  '; $newLine = "`n"; $colon = ': ' }
  if ($null -eq $Value) { [void]$Builder.Append('null') }
  elseif ($Value -is [bool]) { if ($Value) { [void]$Builder.Append('true') } else { [void]$Builder.Append('false') } }
  elseif ($Value -is [int] -or $Value -is [long] -or $Value -is [uint32]) { [void]$Builder.Append(([long]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)) }
  elseif ($Value -is [string] -or $Value -is [char]) {
    [void]$Builder.Append('"')
    foreach ($c in ([string]$Value).ToCharArray()) {
      $code = [int]$c
      if ($c -eq '"') { [void]$Builder.Append('\"') }
      elseif ($c -eq '\') { [void]$Builder.Append('\\') }
      elseif ($code -lt 32 -or $code -gt 126) { [void]$Builder.Append(('\u{0:x4}' -f $code)) }
      else { [void]$Builder.Append($c) }
    }
    [void]$Builder.Append('"')
  }
  elseif ($Value -is [System.Collections.IDictionary]) {
    if ($Value.Count -eq 0) { [void]$Builder.Append('{}'); return }
    [void]$Builder.Append('{' + $newLine)
    $first = $true
    foreach ($key in $Value.Keys) {
      if (-not $first) { [void]$Builder.Append(',' + $newLine) }
      $first = $false
      [void]$Builder.Append($inner)
      Add-E2EJsonValue $Builder ([string]$key) $inner $Pretty
      [void]$Builder.Append($colon)
      Add-E2EJsonValue $Builder $Value[$key] $inner $Pretty
    }
    [void]$Builder.Append($newLine + $(if ($Pretty) { $Indent } else { '' }) + '}')
  }
  elseif ($Value -is [System.Collections.IEnumerable]) {
    $items = @($Value)
    if ($items.Count -eq 0) { [void]$Builder.Append('[]'); return }
    [void]$Builder.Append('[' + $newLine)
    for ($i = 0; $i -lt $items.Count; $i++) {
      if ($i -gt 0) { [void]$Builder.Append(',' + $newLine) }
      [void]$Builder.Append($inner)
      Add-E2EJsonValue $Builder $items[$i] $inner $Pretty
    }
    [void]$Builder.Append($newLine + $(if ($Pretty) { $Indent } else { '' }) + ']')
  }
  else { throw "ConvertTo-E2EJson: values of the type $($Value.GetType().FullName) are not supported" }
}
