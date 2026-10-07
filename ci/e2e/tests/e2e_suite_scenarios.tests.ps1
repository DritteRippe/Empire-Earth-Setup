<#
.SYNOPSIS
  Smoke test of the suite scenarios S1 to S14 (ci\e2e\e2e_suite_scenarios.ps1) against a FAKE Windows: no installer runs.

.DESCRIPTION
  The scenarios read and write the registry, shortcuts, files and processes of a Windows runner. Here the glue
  functions of e2e_windows.ps1 are replaced by an in-memory registry, shortcut files that hold "target|arguments", a
  list of held mutexes and a fake of the suite, of the product setups and of their uninstallers (written after
  suite/suite*.iss: the log lines, the registry values, the files, the exit codes 3, 11, 14 and 15). The checks of the
  scenarios must PASS against the fake, and each of a few defects of the fake (a missing shortcut, the old shortcuts
  not removed, a product that stays after the uninstallation, a changed CD key dummy, ...) must make the check that
  is meant to catch it FAIL. The fake only proves the scenarios hang together and bite; the job suite-e2e of
  .github/workflows/build.yml runs the real thing. Everything happens in a temporary folder.
  Prints the failed checks and exits with 0 if every check passed, else 1.

.EXAMPLE
  pwsh -File ci/e2e/tests/e2e_suite_scenarios.tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$E2EFolder = Split-Path -Parent $PSScriptRoot

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-suite-smoke-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$savedEnvironment = @{}
foreach ($name in @('ProgramW6432', 'ProgramFiles(x86)', 'LOCALAPPDATA', 'SystemDrive', 'E2E_REPORT', 'E2E_WORK', 'E2E_SUITE', 'E2E_PRODUCTS', 'E2E_WRONGPIN', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
  $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
$script:Count = 0
$script:Failures = 0
function Check([string]$Name, $Actual, $Expected) {
  $script:Count++
  if ("$Actual" -ceq "$Expected") { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: got '$Actual', expected '$Expected'"
}

try {
  # --- The sandbox: the folders of the runner, the packages -------------------------------------------------------
  # no proxy: Prepare checks that none is set
  foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) { [Environment]::SetEnvironmentVariable($name, $null) }
  [Environment]::SetEnvironmentVariable('ProgramW6432', (Join-Path $sandbox 'pf64'))
  [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', (Join-Path $sandbox 'pf86'))
  [Environment]::SetEnvironmentVariable('LOCALAPPDATA', (Join-Path $sandbox 'local'))
  [Environment]::SetEnvironmentVariable('SystemDrive', (Join-Path $sandbox 'sd'))
  $env:E2E_REPORT = Join-Path $sandbox 'report'
  $env:E2E_WORK = Join-Path $sandbox 'work'
  $env:E2E_SUITE = Join-Path $sandbox 'suite'
  $env:E2E_WRONGPIN = Join-Path $sandbox 'wrongpin'
  $env:E2E_PRODUCTS = Join-Path $sandbox 'products'
  foreach ($dir in @('pf64', 'pf86', 'local', 'sd', 'report', 'work', 'suite', 'wrongpin', 'products', 'start-all', 'start-user', 'desk-all', 'desk-user')) {
    New-Item -ItemType Directory -Path (Join-Path $sandbox $dir) -Force | Out-Null
  }
  function New-Package([string]$Folder) {
    $base = 'Empire Earth Community Setup'
    [System.IO.File]::WriteAllBytes((Join-Path $Folder "$base.exe"), [byte[]](1..200))
    foreach ($n in 1..3) { [System.IO.File]::WriteAllBytes((Join-Path $Folder "$base-$n.bin"), [byte[]]((1..250) + $n)) }
    [System.IO.File]::WriteAllBytes((Join-Path $Folder 'BUILD-INFO.txt'), [byte[]](65..70))
    $lines = @()
    foreach ($file in (Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Name -ne 'BUILD-INFO.txt' } | Sort-Object Name)) {
      $lines += ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $file.Name)
    }
    [System.IO.File]::WriteAllText((Join-Path $Folder 'SHA256SUMS.txt'), (($lines -join "`n") + "`n"))
  }
  New-Package $env:E2E_SUITE
  New-Package $env:E2E_WRONGPIN
  foreach ($name in @('EE_Setup_v1.7.2.exe', 'NeoEE_v2.0.0.5_Setup_v1.7.2.exe')) { [System.IO.File]::WriteAllBytes((Join-Path $env:E2E_PRODUCTS $name), [byte[]](1..20)) }

  # --- The scenarios and their glue, as the runner loads them -------------------------------------------------------
  . (Join-Path $E2EFolder 'e2e_helpers.ps1')
  . (Join-Path $E2EFolder 'e2e_windows.ps1')
  . (Join-Path $E2EFolder 'e2e_checks.ps1')
  . (Join-Path $E2EFolder 'e2e_scenarios.ps1')
  . (Join-Path $E2EFolder 'e2e_suite_helpers.ps1')
  . (Join-Path $E2EFolder 'e2e_suite_scenarios.ps1')
  Set-E2EAppIdOverride $E2ESuiteConst.ProductAppIds

  # --- Fake registry (HKLM64, HKLM32, HKCU; a key exists if it has values or a key below it) ------------------------
  $script:Reg = @{}
  function Get-FakeKey([string]$Hive, [string]$SubKey) { return ($Hive + '|' + $SubKey.ToLowerInvariant().TrimEnd('\')) }
  function Test-E2ERegKey([string]$Hive, [string]$SubKey) {
    $key = Get-FakeKey $Hive $SubKey
    return (@($script:Reg.Keys | Where-Object { $_ -eq $key -or $_.StartsWith($key + '\') }).Count -gt 0)
  }
  function Get-E2ERegValues([string]$Hive, [string]$SubKey) {
    if (-not (Test-E2ERegKey $Hive $SubKey)) { return $null }
    $key = Get-FakeKey $Hive $SubKey
    $values = @{}
    if ($script:Reg.ContainsKey($key)) { foreach ($name in $script:Reg[$key].Keys) { $values[$name] = $script:Reg[$key][$name] } }
    return $values
  }
  function Get-E2ERegSubKeyNames([string]$Hive, [string]$SubKey) {
    $prefix = (Get-FakeKey $Hive $SubKey) + '\'
    $names = @{}
    foreach ($key in $script:Reg.Keys) {
      if ($key.StartsWith($prefix)) { $names[$key.Substring($prefix.Length).Split('\')[0]] = $true }
    }
    return @($names.Keys)
  }
  function Set-E2ERegValue([string]$Hive, [string]$SubKey, [string]$Name, $Value, [string]$Kind) {
    $key = Get-FakeKey $Hive $SubKey
    if (-not $script:Reg.ContainsKey($key)) { $script:Reg[$key] = @{} }
    $script:Reg[$key][$Name] = @{ Kind = $Kind; Value = $Value }
  }
  function Remove-E2ERegValue([string]$Hive, [string]$SubKey, [string]$Name) {
    Assert-E2ENotCdKeys $SubKey
    $key = Get-FakeKey $Hive $SubKey
    if ($script:Reg.ContainsKey($key)) { $script:Reg[$key].Remove($Name) }
  }
  function Remove-E2ERegTree([string]$Hive, [string]$SubKey) {
    Assert-E2ENotCdKeys $SubKey
    $key = Get-FakeKey $Hive $SubKey
    foreach ($candidate in @($script:Reg.Keys)) {
      if ($candidate -eq $key -or $candidate.StartsWith($key + '\')) { $script:Reg.Remove($candidate) }
    }
  }
  Set-E2ERegValue 'HKLM64' 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' 'Release' 533320 'DWord'

  # --- Fake operating system ---------------------------------------------------------------------------------------------
  $script:Mutexes = @()
  $script:Bug = ''
  function Get-E2EKnownFolder([string]$Name) {
    switch ($Name) {
      'CommonPrograms' { return (Join-Path $sandbox 'start-all') }
      'Programs' { return (Join-Path $sandbox 'start-user') }
      'CommonDesktopDirectory' { return (Join-Path $sandbox 'desk-all') }
      'DesktopDirectory' { return (Join-Path $sandbox 'desk-user') }
    }
    throw "fake folder $Name"
  }
  function Set-E2EHostsBlock([string[]]$Names) { }
  function Test-E2EHostsBlocked([string[]]$Names) { return @() }
  function Invoke-E2EHead([string]$Url, [int]$TimeoutSeconds = 30) { return @{ Ok = $false; Status = 0; Detail = 'blocked' } }
  function Get-E2EWinHttpProxy { return 'Direct access (no proxy server).' }
  function Get-E2ERunnerInfo { return 'fake runner' }
  function Get-E2EFirewallRules([string]$Program) { return @() }
  function Remove-E2EFirewallRules([string]$Program) { }
  function Test-E2EMutex([string]$Name) { return ($script:Mutexes -contains $Name) }
  function Start-E2EMutexHolder([string]$Name) { $script:Mutexes += $Name; return $Name }
  function Stop-E2EMutexHolder($Process) { if ($null -ne $Process) { $script:Mutexes = @($script:Mutexes | Where-Object { $_ -ne $Process }) } }
  function Stop-E2EProcessTree($Process) { }
  function Get-E2ESuiteProcesses { return @() }
  function Get-E2EShortcut([string]$Path) {
    $file = $Path.Replace('\', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $null }
    $parts = ([System.IO.File]::ReadAllText($file)).Split('|')
    return @{ Target = $parts[0]; Arguments = $parts[1] }
  }
  # Alternate data streams exist on NTFS only: the fake leaves a marker file next to each file
  function Set-E2EZoneIdentifier([string]$Folder) {
    foreach ($file in @(Get-ChildItem -LiteralPath $Folder -File)) { [System.IO.File]::WriteAllText($file.FullName + '.zone', (Get-E2EZoneIdentifierText)) }
    return @()
  }
  function Set-FakeShortcut([string]$Path, [string]$Target, [string]$Arguments) {
    $Path = $Path.Replace('\', [System.IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [System.IO.File]::WriteAllText($Path, "$Target|$Arguments")
  }
  # The shortcuts of suite 1.0.0 that S9 plants (scenarios.ps1 calls the Windows function)
  function Set-E2EShortcut([string]$Path, [string]$Target, [string]$Arguments) { Set-FakeShortcut $Path $Target $Arguments }

  # The log of the fake: lines with a time stamp like the ones of Inno Setup
  function Add-FakeLog([string]$File, [string[]]$Lines) {
    if (-not $File) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $File) | Out-Null
    [System.IO.File]::AppendAllText($File, ((@($Lines | ForEach-Object { '2026-10-05 12:04:31.123   ' + $_ }) -join "`r`n") + "`r`n"))
  }

  # --- Fake product setup and uninstaller (config_*.iss, setup_is6.iss) ---------------------------------------------------
  function Install-FakeProduct([string]$Id, [bool]$Icons, [string]$Tasks, [string]$LogFile, [bool]$Repair) {
    $p = Get-E2EProduct $Id
    $root = (Get-E2ESuiteProductRoots)[$Id]
    $keyPath = Get-E2EUninstallKeyPath $p
    $game = Join-Path (Join-Path $root 'Empire Earth') 'Empire Earth.exe'
    $data = Join-Path $root $p.SetupDataDir
    foreach ($file in @($game, (Join-Path $data 'install.ini'), (Join-Path $data 'files.sha256'), (Join-Path $root 'Tools\Diagnostic\EE-Diagnostic.exe'), (Join-Path $root 'unins000.exe'), (Join-Path $root 'unins000.dat'))) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
      [System.IO.File]::WriteAllText($file, "fake $Id")
    }
    Set-E2ERegValue 'HKLM64' $keyPath 'Inno Setup: App Path' $root 'String'
    Set-E2ERegValue 'HKLM64' $keyPath 'UninstallString' ('"' + $root + '\unins000.exe"') 'String'
    Set-E2ERegValue 'HKLM64' $keyPath 'Inno Setup: Selected Tasks' $Tasks 'String'
    Set-E2ERegValue 'HKLM64' $keyPath 'Inno Setup: Selected Components' 'game,additional\tools\diagnostic' 'String'
    $record = "$($E2EConst.CommunityKey)\Installations\$Id"
    Set-E2ERegValue 'HKLM64' $record 'InstallPath' $root 'String'
    Set-E2ERegValue 'HKLM64' $record 'InstallMode' 'admin' 'String'
    Set-E2ERegValue 'HKLM64' $record 'AppId' $p.AppId 'String'
    Set-E2ERegValue 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$Id" 'EE' 1 'DWord'
    Set-E2ERegValue 'HKCU' $p.SettingsKeys['EE'] 'Screen' 1 'DWord'
    if ($Icons) {
      $group = Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth'
      Set-FakeShortcut (Join-Path (Get-E2EKnownFolder 'CommonDesktopDirectory') "$($p.AppName).lnk") $game ''
      Set-FakeShortcut (Join-Path $group "$($p.AppName).lnk") $game ''
      Set-FakeShortcut (Join-Path $group "$($p.AppName) Diagnostic.lnk") (Join-Path $root 'Tools\Diagnostic\EE-Diagnostic.exe') ('{' + $p.AppId + '}_is1')
    }
    if ($LogFile -and (Test-Path -LiteralPath $LogFile)) { Remove-Item -LiteralPath $LogFile -Force }
    # the defect of setups up to M1: the whole Data\dxm folder is deleted on every run
    if ($Repair -and $script:Bug -eq 'delmods' -and (Test-Path -LiteralPath (Join-Path $root 'Empire Earth\Data\dxm'))) { Remove-Item -LiteralPath (Join-Path $root 'Empire Earth\Data\dxm') -Recurse -Force }
    # the placeholder setup (setup_is6.iss, PlaceholderInstallPause): a pause before the install step and one right after its line
    $lines = @()
    if ($script:Bug -ne 'nohook') {
      $lines += @('Test hook of a placeholder build: pausing 2000 ms before the install step', 'Install step: the game folder is changed from here on',
        'Test hook of a placeholder build: pausing 2000 ms after the install step line')
    }
    $lines += @('Install state of the previous run deleted (or there was none): x\install.ini, x\files.sha256',
      'Installation process succeeded.', 'English language selected, no need to download online files.')
    if ($Repair) { $lines += "Will append to existing uninstall log: $root\unins000.dat" } else { $lines += "Creating new uninstall log: $root\unins000.dat" }
    Add-FakeLog $LogFile $lines
  }

  function Uninstall-FakeProduct([string]$Id) {
    $p = Get-E2EProduct $Id
    $root = (Get-E2ESuiteProductRoots)[$Id]
    foreach ($tree in @((Get-E2EUninstallKeyPath $p), "$($E2EConst.CommunityKey)\Installations\$Id")) { Remove-E2ERegTree 'HKLM64' $tree }
    Remove-E2ERegTree 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$Id"
    Remove-E2ERegTree 'HKCU' $p.SettingsKeys['EE']
    if (Test-Path -LiteralPath $root) {
      $keep = [regex]::Escape((Join-Path $root 'Empire Earth\Data')) + '[\\/](Saved Games|dxm[\\/]mods)[\\/]'
      foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.FullName -notmatch ('^' + $keep) })) { Remove-Item -LiteralPath $file.FullName -Force }
      foreach ($dir in @(Get-ChildItem -LiteralPath $root -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending)) {
        if (@(Get-ChildItem -LiteralPath $dir.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $dir.FullName -Force }
      }
      if (@(Get-ChildItem -LiteralPath $root -Force).Count -eq 0) { Remove-Item -LiteralPath $root -Force }
    }
  }

  # --- Fake suite (suite.iss, suite_run.iss, suite_shortcuts.iss, suite_record.iss, suite_uninstall.iss) ---------------------
  function Invoke-FakeSuite([string]$Exe, [string]$ArgText) {
    $tokens = @(Split-E2ECommandLine $ArgText)
    $log = Get-E2ESwitchValue $tokens 'LOG'
    $products = @(Split-E2EList (Get-E2ESwitchValue $tokens 'PRODUCTS'))
    $package = Split-Path -Parent $Exe
    $suiteRoot = Get-E2ESuiteRoot
    $lines = @("Suite 1.0.0 (contract 1, test build 0), started from $package, temporary folder x, silent 1")
    $bins = @(Get-ChildItem -LiteralPath $package -Filter 'Empire Earth Community Setup-*.bin' -File)
    if ($bins.Count -lt 3) {
      Add-FakeLog $log ($lines + 'Precheck failed, exit code 11: slices missing or wrong: Empire Earth Community Setup-2.bin (missing)')
      return 11
    }
    foreach ($mutex in @($E2ESuiteConst.GameMutexEE, $E2ESuiteConst.GameMutexAoC, $E2ESuiteConst.LauncherMutex)) {
      if ($script:Mutexes -contains $mutex) {
        Add-FakeLog $log ($lines + 'Precheck failed, exit code 14: a game or the launcher is running (mutex of x)')
        return 14
      }
    }
    if ($package -like '*wrongpin*') {
      Add-FakeLog $log ($lines + 'Precheck failed, exit code 15: the EE setup does not match its pin: size 1 (expected 1), SHA-256 a (expected b)')
      return 15
    }
    $state = @{}
    foreach ($id in @('EE', 'NeoEE')) { $state[$id] = 0; if (Test-E2ERegKey 'HKLM64' (Get-E2EUninstallKeyPath (Get-E2EProduct $id))) { $state[$id] = 1 } }
    $lines += "Products: state EE $($state['EE']), NeoEE $($state['NeoEE']) (0 not installed, 1 for all users, 2 for one user only, skipped); selected `"$($products -join ',')`""
    $lines += 'Slices: 3 checked, all present, none above 393216 bytes, together 920000 bytes'
    $lines += '.NET Framework 4.8 or later: found, the launcher is installed'
    $ordered = @(@('EE', 'NeoEE') | Where-Object { $products -contains $_ })
    foreach ($id in $ordered) { $lines += "Pin check of the $id setup: $id`_Setup.exe matches (size, SHA-256)" }
    $step = 0
    $ok = @()
    $cancelled = ''
    foreach ($id in $ordered) {
      $step++
      $p = Get-E2EProduct $id
      $extra = @(Split-E2ECommandLine (Get-E2ESwitchValue $tokens ($id + 'Args')))
      $merge = Get-E2ESwitchValue $extra 'MERGETASKS'
      $tasks = Get-E2ESwitchValue $extra 'TASKS'
      $rest = @($extra | Where-Object { $_ -notlike '/MERGETASKS=*' })
      $productLog = "$suiteRoot\Logs\$id-20261005-1204.log"
      $first = ($state[$id] -eq 0)
      $arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,' + $merge + '" /LOG="' + $productLog + '"'
      if ($first -and (Get-E2ESwitchValue $rest 'TYPE') -ne 'compact') { $arguments += ' /TYPE=full' }
      $arguments += ' ' + ($rest -join ' ')
      $lines += "Product $id (step $step of $($ordered.Count), state $($state[$id])): C:\Users\x\AppData\Local\Temp\is-1.tmp\$id`_Setup.exe $arguments"
      # /TestCancel (suite_run.iss): the first product setup is stopped before it installs anything, Setup ends with Abort;
      # /TestCancelNeoEE: the same for the second one, but a product that finished before makes the suite finish its own part
      # /TestCancelAtInstall: the cancel is requested when the log shows the install step, the setup is frozen, the log read again,
      # the line found: too late, the processes run again and the setup completes (the defect 'latekilled' stops it as the old code did)
      $atInstall = (($tokens -contains '/TestCancelAtInstall') -and $step -eq 1)
      $stopped = ((($tokens -contains '/TestCancel') -and $step -eq 1) -or (($tokens -contains '/TestCancelNeoEE') -and $id -eq 'NeoEE') -or ($atInstall -and $script:Bug -eq 'latekilled'))
      if ($atInstall -and -not $stopped) {
        $lines += "Product ${id}: /TestCancelAtInstall, its log shows the install step, the cancel is requested now"
        if ($script:Bug -ne 'nofreeze') {
          $lines += "Product ${id}: freezing its setup and everything it started, to look at its log once more before it is stopped"
          $lines += "Product ${id}: 2 processes frozen"
        }
        $lines += "Product ${id} phase: install (200 of 1000)"
        $lines += "Product ${id}: its log shows the install step, its setup is not stopped"
        $lines += "Product ${id}: 2 processes run again"
        $lines += "Product ${id}: the cancel came too late, its setup has started to install the game files"
      }
      if ($stopped) {
        $lines += "Product ${id}: /TestCancel, the cancel is requested as if the user had answered the question with Yes"
        if ($script:Bug -ne 'nofreeze') {
          $lines += "Product ${id}: freezing its setup and everything it started, to look at its log once more before it is stopped"
          $lines += "Product ${id}: 2 processes frozen"
        }
        $lines += "Product ${id}: cancelled by the user before it installed anything, stopping its setup and everything it started"
        $lines += "Product ${id}: its setup is gone"
        $lines += "Product $id was cancelled by the user before it installed anything"
        New-Item -ItemType Directory -Force -Path "$suiteRoot\Logs" | Out-Null
        Add-FakeLog "$suiteRoot\Logs\$id-20261005-1204.log" @('Log opened.')
        if ($ok.Count -eq 0 -or $script:Bug -eq 'cancel2abort') {
          $lines += "Products that succeeded in this run: `"$($ok -join ',')`""
          $lines += 'The installation was cancelled by the user: no further product setup is started, Setup ends'
          if ($script:Bug -eq 'cancelinstalled') { Install-FakeProduct $id $false $tasks $null $false }
          if ($script:Bug -eq 'cancelnext') { $lines += 'Product NeoEE (step 2 of 2, state 0): x\NeoEE_Setup.exe /VERYSILENT' }
          # the defect of a cancel after the install step began: the install state of a repair is gone
          if ($script:Bug -eq 'repairkilled') { Remove-Item -LiteralPath (Join-Path (Join-Path (Get-E2ESuiteProductRoots)[$id] $p.SetupDataDir) 'install.ini') -Force }
          Add-FakeLog $log $lines
          if ($script:Bug -eq 'cancelexit0') { return 0 }
          return 3
        }
        $cancelled = $id
        break
      }
      # what the suite read from the product log (SuiteLookAtLog, S4): the phases of a placeholder setup in the order of its log
      $phases = @('install (200 of 1000)', 'post install (840 of 1000)', 'manifest (900 of 1000)', 'done (1000 of 1000)')
      if ($atInstall) { $phases = @($phases | Where-Object { $_ -notlike 'install *' }) }
      if ($script:Bug -eq 'phaseback') { $phases = @('post install (840 of 1000)', 'install (200 of 1000)', 'manifest (900 of 1000)', 'done (1000 of 1000)') }
      if ($script:Bug -eq 'phasenoend') { $phases = @('install (200 of 1000)', 'post install (840 of 1000)', 'manifest (900 of 1000)') }
      foreach ($phase in $phases) { $lines += "Product $id phase: $phase" }
      if ($script:Bug -ne 'phasenoend') { $lines += "Product $id log read: last phase done, language files 0 of 0 (0 missing), 3 file entries installed (estimate 3), CD key result `"`"" }
      Install-FakeProduct $id $false $tasks (Join-Path (Join-Path $suiteRoot 'Logs') "$id-20261005-1204.log") (-not $first)
      $lines += "Product ${id}: the setup ended with exit code 0 (kind 0), uninstall entry 1"
      $ok += $id
      # the old shortcuts of earlier standalone runs
      if ($script:Bug -ne 'legacykept') {
        $group = Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth'
        foreach ($path in @((Join-Path (Get-E2EKnownFolder 'CommonDesktopDirectory') "$($p.AppName).lnk"), (Join-Path $group "$($p.AppName).lnk"), (Join-Path $group "$($p.AppName) Diagnostic.lnk"))) {
          if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force; $lines += "Old shortcut of the $id setup removed: $path" }
        }
        if ((Test-Path -LiteralPath $group) -and @(Get-ChildItem -LiteralPath $group -Force).Count -eq 0) { Remove-Item -LiteralPath $group -Force }
      }
      if ($id -eq 'NeoEE') {
        $lines += 'NeoEE CD key result from its log: "" (empty: no such line)'
        $lines += "NeoEE setup ran without the task neoee_cdkeys (tasks of the run: `"$tasks`"): no registration was chosen"
      }
    }
    $lines += "Products that succeeded in this run: `"$($ok -join ',')`""
    if ($cancelled) { $lines += "The installation of $cancelled was cancelled by the user: no further product setup is started, the suite finishes its own part for `"$($ok -join ',')`"" }
    # the files of the suite
    foreach ($name in @($E2ESuiteConst.LauncherExe, ($E2ESuiteConst.LauncherExe + '.config'), $E2ESuiteConst.ModCreatorExe, 'Lizenzen\LICENSE', 'unins000.exe', 'unins000.dat')) {
      $file = Join-Path $suiteRoot $name
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
      [System.IO.File]::WriteAllText($file, 'fake')
    }
    # the shortcuts, created in code at ssPostInstall
    $roots = Get-E2ESuiteProductRoots
    $launcher = Join-E2EPath $suiteRoot $E2ESuiteConst.LauncherExe
    $desktop = Get-E2ESuiteDesktop
    $group = Get-E2ESuiteGroup
    # SuiteRemoveOldSuiteShortcuts first: the seven shortcuts of suite 1.0.0, the desktop one named Empire Earth only if it
    # starts the launcher (the run of the EE setup above deletes the EE setup's own shortcut of that name)
    foreach ($oldShortcut in (Get-E2ESuiteV1Shortcuts -SuiteRoot $suiteRoot -Desktop $desktop -Group $group -Roots $roots -AppIds (Get-E2ESuiteAppIds))) {
      $link = Get-E2EShortcut $oldShortcut.Path
      if (-not $link -or $script:Bug -eq 'oldkept') { continue }
      if ($oldShortcut.Path -ieq (Join-E2EPath $desktop 'Empire Earth.lnk') -and $link.Target -ine $launcher -and $script:Bug -ne 'oldremoved') {
        $lines += "Shortcut of suite 1.0.0 kept, it does not start the launcher: $($oldShortcut.Path)"
        continue
      }
      Remove-Item -LiteralPath $oldShortcut.Path -Force
      $lines += "Shortcut of suite 1.0.0 removed: $($oldShortcut.Path)"
    }
    # the one shortcut on the desktop and in the start menu folder
    if ($script:Bug -ne 'noshortcuts') {
      $arguments = ''
      if ($script:Bug -eq 'wrongargs') { $arguments = '--product=EE' }
      foreach ($folder in @($desktop, $group)) {
        Set-FakeShortcut (Join-Path $folder "$E2ESuiteShortcutName.lnk") $launcher $arguments
        $lines += "Shortcut created: $(Join-Path $folder "$E2ESuiteShortcutName.lnk") -> $launcher $arguments"
      }
    }
    Set-FakeShortcut (Join-Path $group 'Mod Creator.lnk') (Join-E2EPath $suiteRoot $E2ESuiteConst.ModCreatorExe) ''
    Set-FakeShortcut (Join-Path $group 'Uninstall Empire Earth Community.lnk') (Join-E2EPath $suiteRoot 'unins000.exe') ''
    # the record and the uninstall key
    $earlier = ''
    $old = Get-E2ERegValues 'HKLM64' $E2ESuiteConst.RecordKey
    if ($old) { $earlier = Get-E2ERegString $old 'Products' }
    $merged = @(@('EE', 'NeoEE') | Where-Object { (Split-E2EList $earlier) -contains $_ -or $ok -contains $_ }) -join ','
    $record = $E2ESuiteConst.RecordKey
    Set-E2ERegValue 'HKLM64' $record 'ContractVersion' 1 'DWord'
    foreach ($pair in @(@('SuiteVersion', '1.0.0'), @('InstallPath', $suiteRoot), @('Products', $merged), @('SourceDir', $package),
        @('EEAppId', $E2ESuiteConst.ProductAppIds['EE']), @('NeoEEAppId', $E2ESuiteConst.ProductAppIds['NeoEE']), @('Written', '2026-10-05 12:04:31'))) {
      Set-E2ERegValue 'HKLM64' $record $pair[0] $pair[1] 'String'
    }
    $key = Get-E2ESuiteUninstallKeyPath
    Set-E2ERegValue 'HKLM64' $key 'Inno Setup: App Path' $suiteRoot 'String'
    Set-E2ERegValue 'HKLM64' $key 'DisplayName' $E2ESuiteConst.UninstallName 'String'
    Set-E2ERegValue 'HKLM64' $key 'UninstallString' ('"' + $suiteRoot + '\unins000.exe"') 'String'
    # MarkSuiteUninstallKey (suite_record.iss, contract 1.3, revision 5): after the record, in every run
    if ($script:Bug -ne 'nomarker') { Set-E2ERegValue 'HKLM64' $key $E2ESuiteConst.UninstallMarker 1 'DWord' }
    $lines += "Suite record written: $merged"
    if ($script:Bug -eq 'cdkeys') { Set-E2ERegValue 'HKCU' $E2EConst.CdKeysKey 'Added' 'x' 'String' }
    Add-FakeLog $log $lines
    return 0
  }

  function Uninstall-FakeSuite([string]$LogFile) {
    $suiteRoot = Get-E2ESuiteRoot
    $record = Get-E2ERegValues 'HKLM64' $E2ESuiteConst.RecordKey
    $recorded = Get-E2ERegString $record 'Products'
    $lines = @('Suite uninstaller 1.0.0 (contract 1)', "Suite record lists the products `"$recorded`"")
    $roots = Get-E2ESuiteProductRoots
    foreach ($id in @('NeoEE', 'EE')) {
      if ((Split-E2EList $recorded) -notcontains $id) { $lines += "Product $id is not listed by the suite: it is not touched"; continue }
      if (Test-E2ERegKey 'HKLM64' (Get-E2EUninstallKeyPath (Get-E2EProduct $id))) {
        $lines += "Product $id is installed in $($roots[$id]) (uninstaller x): it will be removed"
        if ($script:Bug -ne 'keepproduct' -or $id -ne 'EE') { Uninstall-FakeProduct $id }
      } else {
        $lines += "Product $id is listed but not installed any more (removed through its own entry in Apps): nothing to remove"
      }
    }
    # SuiteRemoveOldSuiteShortcuts first (the uninstaller runs ApplySuiteShortcuts too): a log line for each shortcut of suite 1.0.0
    foreach ($oldShortcut in (Get-E2ESuiteV1Shortcuts -SuiteRoot $suiteRoot -Desktop (Get-E2ESuiteDesktop) -Group (Get-E2ESuiteGroup) -Roots $roots -AppIds (Get-E2ESuiteAppIds))) {
      $link = Get-E2EShortcut $oldShortcut.Path
      if (-not $link -or $script:Bug -eq 'olduninst') { continue }
      if ($oldShortcut.Path -ieq (Join-E2EPath (Get-E2ESuiteDesktop) 'Empire Earth.lnk') -and $link.Target -ine (Join-E2EPath $suiteRoot $E2ESuiteConst.LauncherExe)) {
        $lines += "Shortcut of suite 1.0.0 kept, it does not start the launcher: $($oldShortcut.Path)"
        continue
      }
      Remove-Item -LiteralPath $oldShortcut.Path -Force
      $lines += "Shortcut of suite 1.0.0 removed: $($oldShortcut.Path)"
    }
    foreach ($folder in @((Get-E2ESuiteDesktop), (Get-E2ESuiteGroup))) {
      foreach ($file in @('Empire Earth Community.lnk')) {
        if (Test-Path -LiteralPath (Join-Path $folder $file)) { Remove-Item -LiteralPath (Join-Path $folder $file) -Force }
      }
    }
    # RemoveDir of the real uninstaller removes the folder only if it is empty: the fake removes what is left of the suite's own files
    if ($script:Bug -ne 'olduninst' -and (Test-Path -LiteralPath (Get-E2ESuiteGroup))) { Remove-Item -LiteralPath (Get-E2ESuiteGroup) -Recurse -Force }
    Remove-E2ERegTree 'HKLM64' $E2ESuiteConst.RecordKey
    Remove-E2ERegTree 'HKLM64' (Get-E2ESuiteUninstallKeyPath)
    foreach ($file in @('settings.json', 'log.txt')) {
      if (Test-Path -LiteralPath (Join-Path (Get-E2ELauncherDataDir) $file)) { Remove-Item -LiteralPath (Join-Path (Get-E2ELauncherDataDir) $file) -Force }
    }
    $lines += 'Silent uninstallation: the user data stays:'
    if (Test-Path -LiteralPath $suiteRoot) { Remove-Item -LiteralPath $suiteRoot -Recurse -Force }
    Add-FakeLog $LogFile $lines
  }

  function Invoke-E2EUninstall([hashtable]$Product, [string]$Root, [string]$Hive, [string]$LogFile, [int]$TimeoutSeconds = 600) {
    if (-not (Test-E2ERegKey $Hive (Get-E2EUninstallKeyPath $Product))) { return @{ ExitCode = $null; Problems = @("$Hive uninstall key does not exist") } }
    if ($Product.Id -eq 'Suite') { Uninstall-FakeSuite $LogFile } else { Uninstall-FakeProduct $Product.Id; Add-FakeLog $LogFile @('uninstalled') }
    return @{ ExitCode = 0; Problems = @() }
  }

  function Invoke-E2EProcess {
    param([string]$FilePath, [string]$Arguments = '', [int]$TimeoutSeconds = 3600, [string]$OutFile, [hashtable]$Environment = @{}, [switch]$Cleanup)
    $name = [System.IO.Path]::GetFileName($FilePath)
    if ($name -eq 'Empire Earth Community Setup.exe') { return (Invoke-FakeSuite $FilePath $Arguments) }
    if ($name -eq 'EE_Setup_v1.7.2.exe') {
      $tokens = @(Split-E2ECommandLine $Arguments)
      Install-FakeProduct 'EE' $true (Get-E2ESwitchValue $tokens 'TASKS') (Get-E2ESwitchValue $tokens 'LOG') $false
      return 0
    }
    throw "the fake does not run $name"
  }

  # --- Run ----------------------------------------------------------------------------------------------------------------
  function Initialize-Results { if (Test-Path -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl')) { Remove-Item -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl') }; Initialize-E2EResults (Join-Path $env:E2E_REPORT 'results.jsonl') }
  function Get-Results { return @(Get-Content -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl') | ForEach-Object { $_ | ConvertFrom-Json }) }
  function Invoke-Quiet([string]$Id) { Invoke-E2ESuiteScenario $Id 6>$null }
  # The results of a scenario: the names of its FAIL checks
  function Get-Failures([string]$Id) { return @(Get-Results | Where-Object { $_.scenario -eq $Id -and $_.status -eq 'FAIL' } | ForEach-Object { $_.check }) }

  Initialize-Results
  Invoke-Quiet 'Prepare'
  Check 'Prepare passes' ((Get-Failures 'Prepare') -join ',') ''
  Check 'Prepare seeded the dummy in three views' (@(Get-E2ECdKeysSnapshot).Count) 3
  foreach ($id in $E2ESuiteConst.Scenarios) {
    Invoke-Quiet $id
    $failed = @(Get-Failures $id)
    Check "$id passes against the fake" ($failed -join ',') ''
    $passes = @(Get-Results | Where-Object { $_.scenario -eq $id -and $_.status -eq 'PASS' }).Count
    Check "$id has PASS lines" ($passes -gt 0) $true
    if ($failed.Count -gt 0) { Get-Results | Where-Object { $_.scenario -eq $id -and $_.status -eq 'FAIL' } | ForEach-Object { Write-Host "  $($_.check): $($_.details -join ' | ')" } }
  }
  Check 'nothing left on the fake machine' (@(Get-E2ESuiteDirtyState) -join '|') ''
  Check 'the summary of a good run' (ConvertTo-E2ESuiteSummary -JsonLines @(Get-Content -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl') | ForEach-Object { $_ } | Where-Object { $_ -notlike '*"Prepare"*' } | ForEach-Object { $_ }) -Scenarios @() -Titles $E2ESuiteTitles).Failed $false
  $all = @(Get-Content -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl') | Where-Object { $_ })
  $withDone = @($all) + @($E2ESuiteConst.Scenarios | ForEach-Object { '{"scenario":"' + $_ + '","check":"DONE","status":"INFO","details":[]}' })
  Check 'the summary: fourteen scenarios PASS' ((ConvertTo-E2ESuiteSummary -JsonLines $withDone -Scenarios $E2ESuiteConst.Scenarios -Titles $E2ESuiteTitles).Lines | Where-Object { $_ -like 'PASS *' }).Count 14

  # --- The checks bite: a defect of the fake must fail the check that is meant to catch it ------------------------------------
  $defects = @(
    @{ Bug = 'noshortcuts'; Scenario = 'S1'; Check = 'install/LNK' },
    @{ Bug = 'wrongargs'; Scenario = 'S1'; Check = 'install/LNK' },
    @{ Bug = 'oldkept'; Scenario = 'S9'; Check = 'repair/OLD-SHORTCUTS' },
    @{ Bug = 'oldkept'; Scenario = 'S9'; Check = 'repair-neo/OLD-SHORTCUTS' },
    @{ Bug = 'oldremoved'; Scenario = 'S9'; Check = 'repair-neo-kept/GAME-SHORTCUT' },
    @{ Bug = 'olduninst'; Scenario = 'S8'; Check = 'suite-uninstall/OLD-SHORTCUTS' },
    @{ Bug = 'legacykept'; Scenario = 'S3'; Check = 'suite/LNK' },
    @{ Bug = 'keepproduct'; Scenario = 'S8'; Check = 'suite-uninstall/REMOVED' },
    @{ Bug = 'keepproduct'; Scenario = 'S7'; Check = 'suite-uninstall/SKIPPED' },
    @{ Bug = 'cdkeys'; Scenario = 'S1'; Check = 'install/K9' },
    @{ Bug = 'nomarker'; Scenario = 'S1'; Check = 'install/REC' },
    @{ Bug = 'nomarker'; Scenario = 'S9'; Check = 'repair/REC' },
    @{ Bug = 'delmods'; Scenario = 'S9'; Check = 'repair/MODS' },
    @{ Bug = 'nofreeze'; Scenario = 'S11'; Check = 'cancel/STOP' },
    @{ Bug = 'nofreeze'; Scenario = 'S12'; Check = 'cancel/STOP' },
    @{ Bug = 'nofreeze'; Scenario = 'S13'; Check = 'repair-cancel/STOP' },
    @{ Bug = 'nofreeze'; Scenario = 'S14'; Check = 'cancel-late/DECISION' },
    @{ Bug = 'latekilled'; Scenario = 'S14'; Check = 'cancel-late/RUN' },
    @{ Bug = 'nohook'; Scenario = 'S14'; Check = 'cancel-late/HOOK' },
    @{ Bug = 'cancelinstalled'; Scenario = 'S11'; Check = 'cancel/NOTHING' },
    @{ Bug = 'cancelnext'; Scenario = 'S11'; Check = 'cancel/STOP' },
    @{ Bug = 'cancelexit0'; Scenario = 'S11'; Check = 'cancel/RUN' },
    @{ Bug = 'cancel2abort'; Scenario = 'S12'; Check = 'cancel/RUN' },
    @{ Bug = 'repairkilled'; Scenario = 'S13'; Check = 'repair-cancel/UNCHANGED' },
    @{ Bug = 'phaseback'; Scenario = 'S1'; Check = 'install/LOG' },
    @{ Bug = 'phasenoend'; Scenario = 'S1'; Check = 'install/LOG' }
  )
  foreach ($defect in $defects) {
    $script:Bug = $defect.Bug
    Initialize-Results
    Invoke-Quiet $defect.Scenario
    $script:Bug = ''
    Check "defect $($defect.Bug) in $($defect.Scenario) is caught by $($defect.Check)" ((Get-Failures $defect.Scenario) -contains $defect.Check) $true
    # what the defect left is cleaned up by the next scenario's start (a CD key change is not: restore the dummy)
    Remove-E2ERegTree 'HKCU' 'Software\Empire Earth Community'
    $script:Reg[(Get-FakeKey 'HKCU' $E2EConst.CdKeysKey)].Remove('Added')
  }
} finally {
  foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
  Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
