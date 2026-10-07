# Scenarios S1 to S13 of the suite installer (suite/suite.iss, ADR 0013) on a GitHub-hosted Windows runner with
# the PLACEHOLDER builds of ci/build.ps1 and suite/build_suite.ps1 (dummy AppIds, stub launcher, no game data;
# job suite-e2e of .github/workflows/build.yml, started by ci/e2e/run_e2e_suite.ps1). They reuse the rules and the
# Windows glue of the real-data end-to-end test (e2e_helpers.ps1, e2e_windows.ps1, e2e_scenarios.ps1): the dirty
# state and the cleanup between scenarios, the CD key dummy, the hosts block, the process runner with its time
# limits, the shortcut reader, the uninstaller runner. Hard rules, as there: every run is silent
# (/VERYSILENT /SUPPRESSMSGBOXES /LOG), English, with an exact task list for the product setups (never the tasks
# neoee_cdkeys, certinclude, directplay, dxwebsetup), every process has an external time limit, no network (every
# host is blocked in the hosts file, and the products skip their downloads in English), no real CD key (only the
# dummy under Software\Sierra\CDKeys, which must survive everything: the snapshot of it is compared after every
# scenario), and nothing starts the launcher (the stub is no program).
# The suite creates its shortcuts and its record in code at ssPostInstall (ADR 0013, Evidence): the scenarios read
# the shortcuts through WScript.Shell (target and arguments) and the record from the registry.
# Uses $env:E2E_REPORT, $env:E2E_WORK, $env:E2E_SUITE (the package of the placeholder suite), $env:E2E_PRODUCTS (the
# placeholder product setups) and $env:E2E_WRONGPIN (the suite built with -TestWrongEEPin).
# Windows PowerShell 5.1 compatible, ASCII only. Dot-source after e2e_helpers.ps1, e2e_windows.ps1, e2e_checks.ps1,
# e2e_scenarios.ps1 and e2e_suite_helpers.ps1.

# --- Places ---------------------------------------------------------------------------------------------------

function Get-E2ESuiteRoot {
  $programFiles = $env:ProgramW6432
  if (-not $programFiles) { $programFiles = $env:ProgramFiles }
  return (Join-Path $programFiles $E2ESuiteConst.Name)
}

# The install roots of the products in the default folders of the administrative install mode
function Get-E2ESuiteProductRoots {
  return @{
    EE    = (Join-Path ${env:ProgramFiles(x86)} (Get-E2EProduct 'EE').DirName)
    NeoEE = (Join-Path ${env:ProgramFiles(x86)} (Get-E2EProduct 'NeoEE').DirName)
  }
}

function Get-E2ESuiteAppIds { return @{ EE = $E2ESuiteConst.ProductAppIds['EE']; NeoEE = $E2ESuiteConst.ProductAppIds['NeoEE'] } }

# The suite as a "product" for Invoke-E2EUninstall (its uninstall key and its setup mutex)
function Get-E2ESuiteProduct {
  return @{ Id = 'Suite'; AppName = $E2ESuiteConst.Name; AppId = $E2ESuiteConst.SuiteAppId; SetupMutex = $E2ESuiteConst.SetupMutex }
}

function Get-E2ESuiteGroup { return (Join-Path (Get-E2EKnownFolder 'CommonPrograms') $E2ESuiteConst.Name) }
function Get-E2ESuiteDesktop { return (Get-E2EKnownFolder 'CommonDesktopDirectory') }
function Get-E2ESuiteUninstallKeyPath { return "$($E2EConst.UninstallKey)\{$($E2ESuiteConst.SuiteAppId)}_is1" }
function Get-E2ELauncherDataDir { return (Join-Path $env:LOCALAPPDATA 'Empire Earth Launcher') }
function Get-E2ESuiteLogFile([string]$Scenario, [string]$Step) { return (Join-Path $env:E2E_REPORT "logs\$Scenario-$Step.log") }

# True if a product id is in the comma separated list
function Test-E2EListHas([string]$List, [string]$Item) { return ((Split-E2EList $List) -contains $Item) }

# --- CD key dummy: the snapshot of Software\Sierra\CDKeys in all views ---------------------------------------

function Get-E2ECdKeysSnapshot {
  $lines = @()
  foreach ($hive in $script:E2ECdKeyHives) {
    $values = Get-E2ERegValues $hive $E2EConst.CdKeysKey
    $subKeys = @()
    if ($null -ne $values) { $subKeys = @(Get-E2ERegSubKeyNames $hive $E2EConst.CdKeysKey) }
    $lines += @(ConvertTo-E2ECdKeysSnapshotLines $hive $values $subKeys)
  }
  return @($lines | Sort-Object)
}

function Get-E2ECdKeysSnapshotFile { return (Join-Path $env:E2E_WORK 'cdkeys-snapshot.txt') }

# After the dummy was seeded (Prepare): the lines are the baseline of every later comparison
function Save-E2ECdKeysSnapshot {
  [System.IO.File]::WriteAllLines((Get-E2ECdKeysSnapshotFile), [string[]]@(Get-E2ECdKeysSnapshot), (New-Object System.Text.UTF8Encoding($false)))
}

function Test-E2ECdKeysSnapshot {
  $file = Get-E2ECdKeysSnapshotFile
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return @("$file does not exist (Prepare did not run)") }
  $before = @([System.IO.File]::ReadAllLines($file))
  return @(Compare-E2ESnapshot $before @(Get-E2ECdKeysSnapshot) 'Software\Sierra\CDKeys (HKCU, HKLM64, HKLM32)')
}

# The snapshot diff and the dummy itself: the CD key registry stayed as the job seeded it
function Test-E2EMachineSnapshot([string]$Scenario, [string]$Step) {
  $problems = @(Test-E2ECdKeysSnapshot) + @(Test-E2ECdKeyDummy)
  [void](Complete-E2ECheck $Scenario "$Step/K9" $problems 'Software\Sierra\CDKeys unchanged in HKCU, HKLM64, HKLM32')
}

# --- Clean machine ----------------------------------------------------------------------------------------------

# What a scenario must not find at its start: the dirty state of the products (their AppIds are the dummies,
# Set-E2EAppIdOverride) and what the suite adds: its uninstall key, its folders, the shortcut names of NeoEE
function Get-E2ESuiteDirtyState {
  $found = @(Get-E2EDirtyState)
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $hive (Get-E2ESuiteUninstallKeyPath)) { $found += "$hive uninstall key of the suite" }
  }
  $paths = @((Get-E2ESuiteRoot), (Get-E2ESuiteGroup), (Get-E2ELauncherDataDir))
  foreach ($desktop in @((Get-E2EKnownFolder 'CommonDesktopDirectory'), (Get-E2EKnownFolder 'DesktopDirectory'))) {
    $paths += Join-Path $desktop 'Neo Empire Earth.lnk'
  }
  foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) { $found += "$path (suite)" }
  }
  return $found
}

# Uninstalls what an earlier scenario left (the suite first: it removes the products), then everything the dirty
# state names (never Software\Sierra)
function Reset-E2ESuiteMachine([string]$Scenario) {
  $values = Get-E2ERegValues 'HKLM64' (Get-E2ESuiteUninstallKeyPath)
  if ($values -and $values.ContainsKey('Inno Setup: App Path')) {
    $root = [string]$values['Inno Setup: App Path'].Value
    try {
      $run = Invoke-E2EUninstall (Get-E2ESuiteProduct) $root 'HKLM64' (Get-E2ESuiteLogFile $Scenario 'cleanup-suite') ($E2ESuiteConst.UninstallTimeoutMinutes * 60)
      if ($run.Problems.Count -gt 0) { Write-Host "Cleanup of the suite in ${root}: $($run.Problems -join '; ')" }
    } catch {
      Write-Host "Cleanup of the suite in ${root}: $($_.Exception.Message)"
    }
  }
  Reset-E2EMachine $Scenario
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) { Remove-E2ERegTree $hive (Get-E2ESuiteUninstallKeyPath) }
  $paths = @((Get-E2ESuiteRoot), (Get-E2ESuiteGroup), (Get-E2ELauncherDataDir))
  foreach ($desktop in @((Get-E2EKnownFolder 'CommonDesktopDirectory'), (Get-E2EKnownFolder 'DesktopDirectory'))) {
    $paths += Join-Path $desktop 'Neo Empire Earth.lnk'
  }
  foreach ($path in $paths) {
    try {
      if (Test-Path -LiteralPath $path -PathType Container) { Remove-E2EFolder $path }
      elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    } catch {
      Write-Host "Cleanup of ${path}: $($_.Exception.Message)"
    }
  }
}

# Start of a scenario: a clean machine, the CD key dummy as seeded, every host blocked. False: skip it.
function Initialize-E2ESuiteScenario([string]$Scenario) {
  $dirty = @(Get-E2ESuiteDirtyState)
  if ($dirty.Count -gt 0) {
    Add-E2EResult $Scenario 'start/CLEAN' 'WARN' (@('left over by an earlier scenario, removed now:') + $dirty)
    Reset-E2ESuiteMachine $Scenario
    $dirty = @(Get-E2ESuiteDirtyState)
  }
  $problems = @($dirty) + @(Test-E2ECdKeyDummy) + @(Test-E2ECdKeysSnapshot) + @(Test-E2EHostsBlocked $E2EConst.BlockedHosts)
  return (Complete-E2ECheck $Scenario 'start/CLEAN' $problems 'nothing installed, CD key dummy intact, every host blocked')
}

# --- Packages and processes -------------------------------------------------------------------------------------

# A copy of the package of the placeholder suite in the work folder (a scenario that changes it never touches the
# original)
function Copy-E2ESuitePackage([string]$Name, [string]$From = $env:E2E_SUITE) {
  $dest = Join-Path $env:E2E_WORK "pkg-$Name"
  if (Test-Path -LiteralPath $dest) { Remove-E2EFolder $dest }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  foreach ($file in @(Get-ChildItem -LiteralPath $From -File)) { Copy-Item -LiteralPath $file.FullName -Destination $dest }
  return $dest
}

# The processes of a setup of the suite or of a product setup (and of an uninstaller): the programs and the copies
# in %TEMP% (Inno Setup starts its .tmp files)
function Get-E2ESuiteProcesses {
  return @(Get-Process | Where-Object {
    $_.ProcessName -like 'Empire Earth Community Setup*' -or $_.ProcessName -like 'EE_Setup*' -or $_.ProcessName -like 'NeoEE*Setup*' -or
    $_.ProcessName -like 'NeoEE_v*' -or $_.ProcessName -like '_iu*'
  })
}

# Waits until no setup mutex (the suite's, EE's, NeoEE's) is held and no setup process runs; stops what still runs
# after the time (False then), so the next step does not meet it
function Wait-E2ESuiteFinished([int]$TimeoutSeconds = 120) {
  $mutexes = @($E2ESuiteConst.SetupMutex, (Get-E2EProduct 'EE').SetupMutex, (Get-E2EProduct 'NeoEE').SetupMutex)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $busy = (@($mutexes | Where-Object { Test-E2EMutex $_ }).Count -gt 0) -or (@(Get-E2ESuiteProcesses).Count -gt 0)
    if (-not $busy) { return $true }
    Start-Sleep -Seconds 2
  }
  foreach ($process in (Get-E2ESuiteProcesses)) { Stop-E2EProcessTree $process }
  return $false
}

# Runs the suite from Package for the products, silently and with the exact task lists of the test; waits until
# everything it started is gone; records the check Step/RUN (exit code, finished, log). Returns @{ Ok; Code;
# LogFile; LogLines; Switches }. EEArgs and NeoEEArgs are the arguments for the product setups (the default lists
# of the test); only those of the products named in Products are passed. ExtraSwitches are added to the command line.
function Invoke-E2ESuiteRun {
  param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Step,
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Products,
    [int]$ExpectExit = 0,
    [int]$TimeoutMinutes = $E2ESuiteConst.SuiteTimeoutMinutes,
    [string]$EEArgs = $E2ESuiteConst.EEArgs,
    [string]$NeoEEArgs = $E2ESuiteConst.NeoEEArgs,
    [string[]]$ExtraSwitches = @()
  )
  $log = Get-E2ESuiteLogFile $Scenario $Step
  if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
  if (-not (Test-E2EListHas $Products 'EE')) { $EEArgs = '' }
  if (-not (Test-E2EListHas $Products 'NeoEE')) { $NeoEEArgs = '' }
  $switches = @(New-E2ESuiteArguments -LogFile $log -Products $Products -EEArgs $EEArgs -NeoEEArgs $NeoEEArgs -ExtraSwitches $ExtraSwitches)
  $exe = Join-Path $Package $E2ESuiteConst.SetupFile
  $problems = @(Get-E2ESuiteArgumentProblems $switches)
  $problems += @(Test-E2EHostsBlocked $E2EConst.BlockedHosts)
  if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { $problems += "setup not found: $exe" }
  $code = $null
  if ($problems.Count -gt 0) {
    $problems = @('suite not started: ' + ($problems -join '; '))
  } else {
    Write-Host "Running $($E2ESuiteConst.SetupFile) $($switches -join ' ')"
    try {
      $code = Invoke-E2EProcess -FilePath $exe -Arguments ($switches -join ' ') -TimeoutSeconds ($TimeoutMinutes * 60)
    } catch {
      $problems += $_.Exception.Message
    }
    if ($null -ne $code -and $code -ne $ExpectExit) { $problems += "exit code $code, expected $ExpectExit" }
    if (-not (Wait-E2ESuiteFinished 120)) { $problems += 'a setup was still running 120 s after the suite ended (stopped now)' }
  }
  $lines = @()
  if (Test-Path -LiteralPath $log) { $lines = @(ConvertFrom-E2ELogText ([System.IO.File]::ReadAllText($log))) }
  elseif ($null -ne $code) { $problems += "no setup log $log" }
  Copy-E2ESuiteProductLogs $Scenario $Step
  $ok = Complete-E2ECheck $Scenario "$Step/RUN" $problems "exit code $code"
  return @{ Ok = $ok; Code = $code; LogFile = $log; LogLines = $lines; Switches = $switches }
}

# The logs of the product setups the suite ran (<suite root>\Logs) next to the other logs of the report
function Copy-E2ESuiteProductLogs([string]$Scenario, [string]$Step) {
  $folder = Join-Path (Get-E2ESuiteRoot) 'Logs'
  if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return }
  foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.log' -File)) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $env:E2E_REPORT "logs\$Scenario-$Step-$($file.Name)") -Force
  }
}

# The lines of the newest log of the product setup in <suite root>\Logs, @() if there is none
function Get-E2EProductLogLines([string]$Id) {
  $folder = Join-Path (Get-E2ESuiteRoot) 'Logs'
  if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return @() }
  $file = @(Get-ChildItem -LiteralPath $folder -Filter "$Id-*.log" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  if ($file.Count -eq 0) { return @() }
  return @(ConvertFrom-E2ELogText ([System.IO.File]::ReadAllText($file[0].FullName)))
}

# Runs the uninstaller of the suite (silent, with /LOG: Invoke-E2EUninstall), which removes the products; waits until
# it and the product uninstallers are done. Returns @{ Code; Problems; LogFile; LogLines }; a stop at the time limit
# is a problem of the result, not an exception
function Invoke-E2ESuiteUninstall([string]$Scenario, [string]$Step) {
  $log = Get-E2ESuiteLogFile $Scenario $Step
  if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
  $code = $null
  $problems = @()
  try {
    $run = Invoke-E2EUninstall (Get-E2ESuiteProduct) (Get-E2ESuiteRoot) 'HKLM64' $log ($E2ESuiteConst.UninstallTimeoutMinutes * 60)
    $code = $run.ExitCode
    $problems = @($run.Problems)
    if ($null -ne $code -and $code -ne 0) { $problems += "unins000.exe exit code $code" }
  } catch {
    $problems += $_.Exception.Message
  }
  if (-not (Wait-E2ESuiteFinished 120)) { $problems += 'a setup or uninstaller was still running 120 s after the uninstallation (stopped now)' }
  $lines = @()
  if (Test-Path -LiteralPath $log) { $lines = @(ConvertFrom-E2ELogText ([System.IO.File]::ReadAllText($log))) }
  return @{ Code = $code; Problems = $problems; LogFile = $log; LogLines = $lines }
}

# The end of a scenario that installed the suite: uninstall it (without checks of the removal: S7 and S8 do those),
# so the next scenario starts clean. A failure is a warning, the next scenario cleans up with Reset-E2ESuiteMachine.
function Invoke-E2ESuiteCleanup([string]$Scenario) {
  if (-not (Test-E2ERegKey 'HKLM64' (Get-E2ESuiteUninstallKeyPath))) { return }
  $run = Invoke-E2ESuiteUninstall $Scenario 'cleanup'
  [void](Complete-E2ECheck $Scenario 'cleanup/UNINSTALL' $run.Problems 'the suite and its products uninstalled' -Soft)
}

# --- Checks -------------------------------------------------------------------------------------------------------

# The suite record, its uninstall key with the marker the launcher needs (contract 1.3, revision 5: DWord 1, written
# in every run) and where they are not (contract 1.6: the 64-bit view of HKLM only)
function Test-E2ESuiteRecord([string]$Scenario, [string]$Step, [string]$Products, [string]$SourceDir) {
  $root = Get-E2ESuiteRoot
  $problems = @(Test-E2ESuiteRecordValues (Get-E2ERegValues 'HKLM64' $E2ESuiteConst.RecordKey) $Products $root $SourceDir (Get-E2ESuiteAppIds))
  foreach ($other in @('HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $other $E2ESuiteConst.RecordKey) { $problems += "$other\$($E2ESuiteConst.RecordKey) exists (the record belongs to HKLM64)" }
  }
  $keyPath = Get-E2ESuiteUninstallKeyPath
  $uninstall = Get-E2ERegValues 'HKLM64' $keyPath
  if ($null -eq $uninstall) { $problems += "HKLM64\$keyPath does not exist" }
  else {
    if ((Get-E2ERegString $uninstall 'Inno Setup: App Path').TrimEnd('\') -ine $root) { $problems += "the uninstall key of the suite names the folder '$(Get-E2ERegString $uninstall 'Inno Setup: App Path')'" }
    if ((Get-E2ERegString $uninstall 'DisplayName') -cne $E2ESuiteConst.UninstallName) { $problems += "DisplayName of the uninstall key is '$(Get-E2ERegString $uninstall 'DisplayName')'" }
    if ((Get-E2ERegString $uninstall 'UninstallString') -eq '') { $problems += 'the uninstall key of the suite has no UninstallString' }
    $marker = $E2ESuiteConst.UninstallMarker
    if (-not $uninstall.ContainsKey($marker) -or $uninstall[$marker].Kind -ne 'DWord' -or [string]$uninstall[$marker].Value -ne '1') {
      $problems += "the uninstall key of the suite has no '$marker' = 1 (contract 1.3, revision 5)"
    }
  }
  foreach ($other in @('HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $other $keyPath) { $problems += "$other\$keyPath exists too" }
  }
  [void](Complete-E2ECheck $Scenario "$Step/REC" $problems "HKLM64\$($E2ESuiteConst.RecordKey): Products=$Products, uninstall key marked")
}

# A product the suite installed: uninstall key, install record, files, the defaults in HKCU; no forbidden task
function Test-E2EProductInstalled([string]$Scenario, [string]$Step, [string]$Id, [string]$Root) {
  $p = Get-E2EProduct $Id
  $problems = @()
  $keyPath = Get-E2EUninstallKeyPath $p
  $uninstall = Get-E2ERegValues 'HKLM64' $keyPath
  if ($null -eq $uninstall) { $problems += "HKLM64\$keyPath does not exist" }
  else {
    if ((Get-E2ERegString $uninstall 'Inno Setup: App Path').TrimEnd('\') -ine $Root) { $problems += "the uninstall key names the folder '$(Get-E2ERegString $uninstall 'Inno Setup: App Path')', expected $Root" }
    if ((Get-E2ERegString $uninstall 'UninstallString') -eq '') { $problems += 'the uninstall key has no UninstallString' }
    foreach ($task in (Split-E2EList (Get-E2ERegString $uninstall 'Inno Setup: Selected Tasks'))) {
      if (@('neoee_cdkeys', 'certinclude', 'directplay', 'dxwebsetup') -contains $task) { $problems += "the task $task is selected" }
    }
  }
  foreach ($other in @('HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $other $keyPath) { $problems += "$other\$keyPath exists too" }
  }
  $recordKey = "$($E2EConst.CommunityKey)\Installations\$Id"
  $record = Get-E2ERegValues 'HKLM64' $recordKey
  if ($null -eq $record) { $problems += "HKLM64\$recordKey does not exist" }
  else {
    if ((Get-E2ERegString $record 'InstallPath').TrimEnd('\') -ine $Root) { $problems += "install record: InstallPath '$(Get-E2ERegString $record 'InstallPath')'" }
    if ((Get-E2ERegString $record 'InstallMode') -cne 'admin') { $problems += "install record: InstallMode '$(Get-E2ERegString $record 'InstallMode')'" }
    if ((Get-E2ERegString $record 'AppId') -cne $p.AppId) { $problems += "install record: AppId '$(Get-E2ERegString $record 'AppId')'" }
  }
  $game = Join-Path (Join-Path $Root $E2EGames['EE'].Folder) $E2EGames['EE'].Exe
  if (-not (Test-Path -LiteralPath $game -PathType Leaf)) { $problems += "$game missing" }
  $data = Join-Path $Root $p.SetupDataDir
  foreach ($name in @('install.ini', 'files.sha256')) {
    if (-not (Test-Path -LiteralPath (Join-Path $data $name) -PathType Leaf)) { $problems += "$data\$name missing" }
  }
  $manifest = Join-Path $data 'files.sha256'
  if ((Test-Path -LiteralPath $manifest -PathType Leaf) -and ([System.IO.File]::ReadAllText($manifest) -match '(?i)launcher')) {
    $problems += 'the manifest of the product lists a launcher file (the launcher lies outside every product root, contract 2.3)'
  }
  if (-not (Test-E2ERegKey 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$Id")) { $problems += "the defaults marker HKCU\$($E2EConst.CommunityKey)\GameDefaults\$Id is missing" }
  if (-not (Test-E2ERegKey 'HKCU' $p.SettingsKeys['EE'])) { $problems += "HKCU\$($p.SettingsKeys['EE']) (the game settings) is missing" }
  [void](Complete-E2ECheck $Scenario "$Step/PROD-$Id" $problems "$Id in $Root")
}

# The product logs of the suite run: the log of the setup of each product (success, no network, no forbidden
# component, no CD key line) and the command line the suite gave it (contract 1.7 point 3 and the rules of the test)
function Test-E2EProductLogs([string]$Scenario, [string]$Step, $Run, [string[]]$Products, [bool]$Adopted) {
  foreach ($id in $Products) {
    $problems = @()
    $lines = @(Get-E2EProductLogLines $id)
    if ($lines.Count -eq 0) { $problems += "no log of the $id setup below $(Join-Path (Get-E2ESuiteRoot) 'Logs')" }
    else {
      $problems += @(Test-E2ELogLines -Lines $lines -Contains @('Installation process succeeded.', 'English language selected, no need to download online files.') `
        -NotContains @('Exception', 'Runtime error', 'PrepareToInstall failed', 'Sending setup stats over HTTPS!', 'api.empireearth.eu', 'dxwebsetup.exe', 'dism.exe',
                       'certutil', 'Register NeoEE CD Keys', 'CD Keys', 'Installed file missing', 'Online file rejected', 'Online file refused', 'Downloading temporary file') `
        -NotMatches @('^HTTP (GET|HEAD) '))
      if ($Adopted) {
        $problems += @(Test-E2ELogLines -Lines $lines -Matches @('^Will append to existing uninstall log: .+\\unins000\.dat$'))
        $problems += @(Test-E2ELogLines -Lines $lines -NotMatches @('^Creating new uninstall log: '))
      }
    }
    $command = Get-E2ESuiteChildCommand $Run.LogLines $id
    if ($null -eq $command) { $problems += "no line 'Product $id (step ...): <setup> <arguments>' in the log of the suite" }
    else {
      $problems += @(Test-E2ESuiteChildArguments $command.Arguments $id)
      $expectedFirst = $true
      if ($Adopted) { $expectedFirst = $false }
      if (($command.State -eq 0) -ne $expectedFirst) { $problems += "the suite saw the state $($command.State) of $id (0: not installed), expected a first installation: $expectedFirst" }
    }
    [void](Complete-E2ECheck $Scenario "$Step/LOG-$id" $problems "$id setup: succeeded, no HTTP request, command line as contract 1.7 point 3")
  }
  # NeoEE: no CD key registration was chosen, and the suite knew it
  if ($Products -contains 'NeoEE') {
    $problems = @(Test-E2ELogLines -Lines $Run.LogLines -Contains @('NeoEE setup ran without the task neoee_cdkeys') -NotContains @('CD key registration failed'))
    [void](Complete-E2ECheck $Scenario "$Step/CDKEYS" $problems 'NeoEE ran without the task neoee_cdkeys')
  }
}

# The phase lines of the suite log ("Product EE phase: install (200 of 1000)") of each product: every phase once and in
# the order of the product log (a phase never goes back), the bar permille never going down. Problems as strings.
function Test-E2ESuitePhaseOrder([string[]]$Lines, [string[]]$Products) {
  $problems = @()
  $order = @('start', 'online files servers', 'download', 'verify', 'install', 'post install', 'CD keys', 'manifest', 'done')
  foreach ($id in $Products) {
    $last = -1
    $lastPermille = -1
    $seen = @{}
    foreach ($line in $Lines) {
      if ($line -cmatch ('^Product ' + $id + ' phase: (.+?)(, \d+ files)? \((\d+) of 1000\)$')) {
        $phase = $Matches[1]
        $permille = [int]$Matches[3]
        $index = [array]::IndexOf($order, $phase)
        if ($index -lt 0) { $problems += "unknown phase of $id in the suite log: $phase"; continue }
        if ($seen.ContainsKey($phase)) { $problems += "phase of $id logged twice: $phase" }
        $seen[$phase] = $true
        if ($index -le $last) { $problems += "phase of $id out of order: $phase after $($order[$last])" }
        if ($permille -lt $lastPermille) { $problems += "the progress of $id went back at the phase $phase ($permille of 1000 after $lastPermille)" }
        $last = [Math]::Max($last, $index)
        $lastPermille = [Math]::Max($lastPermille, $permille)
      }
    }
    if ($lastPermille -ge 0 -and $lastPermille -ne 1000) { $problems += "the last progress of $id is $lastPermille of 1000, not 1000 (the log was read to its end)" }
  }
  return $problems
}

# The suite's own log: the prechecks, the pin checks, the products that succeeded, the record, the shortcuts
function Test-E2ESuiteLog([string]$Scenario, [string]$Step, $Run, [string[]]$Products, [string]$Recorded) {
  $contains = @("Products that succeeded in this run: `"$($Products -join ',')`"",
                "Suite record written: $Recorded", '.NET Framework 4.8 or later: found, the launcher is installed')
  $patterns = @('^Suite \d+\.\d+\.\d+ \(contract \d+, test build \d+\), started from ',
               '^Slices: \d+ checked, all present, none above \d+ bytes, together \d+ bytes$', '^Shortcut created: ')
  foreach ($id in $Products) {
    $setup = 'EE_Setup.exe'
    if ($id -eq 'NeoEE') { $setup = 'NeoEE_Setup.exe' }
    $patterns += '^Pin check of the ' + $id + ' setup: ' + [regex]::Escape($setup) + ' matches \(size, SHA-256\)$'
    # the progress read from the product log (S4): a placeholder setup is finished within a second, so the first look may
    # see its whole log and skip the phases in between; the last look after the exit always sees "Log closed." (phase
    # "done"). The phases that were logged must be in the order of the log (Test-E2ESuitePhaseOrder).
    $patterns += '^Product ' + $id + ' phase: done \(1000 of 1000\)$'
    $patterns += '^Product ' + $id + ' log read: last phase done, '
  }
  $phaseProblems = @(Test-E2ESuitePhaseOrder -Lines $Run.LogLines -Products $Products)
  $problems = @(Test-E2ELogLines -Lines $Run.LogLines -Contains $contains -Matches $patterns `
    -NotContains @('Precheck failed', 'Exception', 'could not be removed', 'does not match its pin') `
    -NotMatches @('^Shortcut .+ not created: ', '^Product \S+ failed', '^Product \S+ not run'))
  $problems += $phaseProblems
  [void](Complete-E2ECheck $Scenario "$Step/LOG" $problems "$(@($Run.LogLines).Count) log lines")
}

# The shortcuts through WScript.Shell: target and arguments of each (Get-E2EShortcut), and none of the products'
# own shortcuts left besides the one name the suite shares with EE
function Test-E2ESuiteShortcuts([string]$Scenario, [string]$Step, [string[]]$Products) {
  $roots = Get-E2ESuiteProductRoots
  $diagnostic = @()
  foreach ($id in $Products) {
    if (Test-Path -LiteralPath (Join-Path $roots[$id] 'Tools\Diagnostic\EE-Diagnostic.exe') -PathType Leaf) { $diagnostic += $id }
  }
  $expected = @(Get-E2ESuiteExpectedShortcuts -Products $Products -SuiteRoot (Get-E2ESuiteRoot) -Desktop (Get-E2ESuiteDesktop) `
    -Group (Get-E2ESuiteGroup) -Roots $roots -AppIds (Get-E2ESuiteAppIds) -DiagnosticFor $diagnostic)
  $actual = @{}
  foreach ($item in $expected) {
    $link = Get-E2EShortcut $item.Path
    if ($link) { $actual[$item.Path] = $link }
  }
  $problems = @(Compare-E2EShortcuts $expected $actual)
  $expectedPaths = @($expected | ForEach-Object { $_.Path.Replace('/', '\') })
  foreach ($path in (Get-E2EKnownShortcuts)) {
    if (($expectedPaths -notcontains $path.Replace('/', '\')) -and (Test-Path -LiteralPath $path)) { $problems += "a shortcut or folder of the products is still there: $path" }
  }
  [void](Complete-E2ECheck $Scenario "$Step/LNK" $problems "$(@($expected | Where-Object { $_.Present }).Count) shortcuts start the launcher or the suite, none of the products' own")
}

# The files of the suite: the stub launcher, the Mod Creator, the license texts, the uninstaller, a log per product
function Test-E2ESuiteFiles([string]$Scenario, [string]$Step, [string[]]$Products) {
  $root = Get-E2ESuiteRoot
  $problems = @()
  foreach ($name in @($E2ESuiteConst.LauncherExe, ($E2ESuiteConst.LauncherExe + '.config'), $E2ESuiteConst.ModCreatorExe, 'Lizenzen\LICENSE', 'unins000.exe', 'unins000.dat')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) { $problems += "$root\$name missing" }
  }
  foreach ($id in $Products) {
    $logs = @()
    if (Test-Path -LiteralPath (Join-Path $root 'Logs') -PathType Container) { $logs = @(Get-ChildItem -LiteralPath (Join-Path $root 'Logs') -Filter "$id-*.log" -File) }
    if ($logs.Count -eq 0) { $problems += "no log $id-*.log in $root\Logs" }
  }
  [void](Complete-E2ECheck $Scenario "$Step/FILES" $problems "the launcher, the Mod Creator, the license texts and the logs are in $root")
}

# Every check of an installation by the suite (S1, S2, S3, S9, S10): Products are the products the run installed
# or adopted, Recorded the Products value of the suite record afterwards
function Invoke-E2ESuiteInstalledChecks {
  param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Step,
    [Parameter(Mandatory = $true)]$Run,
    [Parameter(Mandatory = $true)][string[]]$Products,
    [Parameter(Mandatory = $true)][string]$Package,
    [string]$Recorded = '',
    [bool]$Adopted = $false
  )
  if (-not $Recorded) { $Recorded = ($Products -join ',') }
  $roots = Get-E2ESuiteProductRoots
  Test-E2ESuiteLog $Scenario $Step $Run $Products $Recorded
  Test-E2ESuiteRecord $Scenario $Step $Recorded $Package
  foreach ($id in $Products) { Test-E2EProductInstalled $Scenario $Step $id $roots[$id] }
  Test-E2EProductLogs $Scenario $Step $Run $Products $Adopted
  Test-E2ESuiteShortcuts $Scenario $Step $Products
  Test-E2ESuiteFiles $Scenario $Step $Products
  Test-E2EMachineSnapshot $Scenario $Step
}

# What must be gone after a product was removed: the keys, the records, the defaults, the shortcuts of the product
# and its files below the root (AllowedLeftovers: patterns of the relative paths that may stay, user data)
function Test-E2EProductRemoved([string]$Id, [string]$Root, [string[]]$AllowedLeftovers = @()) {
  $p = Get-E2EProduct $Id
  $problems = @()
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $hive (Get-E2EUninstallKeyPath $p)) { $problems += "$hive\$(Get-E2EUninstallKeyPath $p) is still there" }
  }
  if (Test-E2ERegKey 'HKLM64' "$($E2EConst.CommunityKey)\Installations\$Id") { $problems += "the install record of $Id is still there" }
  if (Test-E2ERegKey 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$Id") { $problems += "the defaults marker HKCU\$($E2EConst.CommunityKey)\GameDefaults\$Id is still there" }
  foreach ($game in @('EE', 'AoC')) {
    if (Test-E2ERegKey 'HKCU' $p.SettingsKeys[$game]) { $problems += "HKCU\$($p.SettingsKeys[$game]) (the game settings) is still there" }
  }
  if (Test-Path -LiteralPath (Join-Path $Root $p.SetupDataDir)) { $problems += "$($p.SetupDataDir) is still there" }
  $left = @(Get-E2EFileTree $Root | Where-Object { -not $_.IsDir } | ForEach-Object { $_.Rel.Replace('/', '\') })
  $unexpected = @($left | Where-Object { $rel = $_; @($AllowedLeftovers | Where-Object { $rel -match $_ }).Count -eq 0 })
  if ($unexpected.Count -gt 0) { $problems += "$($unexpected.Count) file(s) left below ${Root}: $(($unexpected | Select-Object -First 5) -join ', ')" }
  return $problems
}

# --- Install helper ------------------------------------------------------------------------------------------------

# One installation by the suite (the products in the list) and its checks; returns the run
function Invoke-E2ESuiteInstall([string]$Scenario, [string]$Step, [string]$Package, [string]$Products, [bool]$Checks, [bool]$Adopted = $false) {
  $run = Invoke-E2ESuiteRun -Scenario $Scenario -Step $Step -Package $Package -Products $Products
  if ($run.Ok -and $Checks) {
    Invoke-E2ESuiteInstalledChecks -Scenario $Scenario -Step $Step -Run $run -Products @(Split-E2EList $Products) -Package $Package -Adopted $Adopted
  }
  return $run
}

# --- S1: both products ------------------------------------------------------------------------------------------------

function Invoke-E2EScenarioS1 {
  $s = 'S1'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    [void](Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE,NeoEE' $true)
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S2: EE only -------------------------------------------------------------------------------------------------------

function Invoke-E2EScenarioS2 {
  $s = 'S2'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE' $true
    if ($run.Ok) {
      $neo = Get-E2EProduct 'NeoEE'
      $roots = Get-E2ESuiteProductRoots
      $problems = @()
      foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
        if (Test-E2ERegKey $hive (Get-E2EUninstallKeyPath $neo)) { $problems += "$hive uninstall key of NeoEE exists" }
      }
      if (Test-Path -LiteralPath $roots['NeoEE']) { $problems += "$($roots['NeoEE']) exists" }
      if (Test-E2ERegKey 'HKLM64' "$($E2EConst.CommunityKey)\Installations\NeoEE") { $problems += 'the install record of NeoEE exists' }
      $problems += @(Test-E2ELogLines -Lines $run.LogLines -NotMatches @('^Product NeoEE \(step', '^Pin check of the NeoEE setup'))
      if (@(Get-E2EProductLogLines 'NeoEE').Count -gt 0) { $problems += 'a log of the NeoEE setup exists' }
      [void](Complete-E2ECheck $s 'install/NO-NEOEE' $problems 'NeoEE is neither installed, nor recorded, nor run, nor shortcut')
    }
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S3: a product installed by its own setup is adopted --------------------------------------------------------------

function Invoke-E2EScenarioS3 {
  $s = 'S3'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $roots = Get-E2ESuiteProductRoots
    $root = $roots['EE']
    $ee = Get-E2EProduct 'EE'
    # 1. The standalone setup of EE with its own shortcuts (task desktopicon), in the default folder
    $standalone = Join-Path $env:E2E_PRODUCTS $ee.SetupFile
    $log = Get-E2ESuiteLogFile $s 'standalone'
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/ALLUSERS', '/LANG=en', '/TYPE=compact',
                   '/TASKS=compatibility,compatibility_windows,desktopicon', "/LOG=`"$log`"")
    $problems = @()
    $code = $null
    try {
      $code = Invoke-E2ESetup -Exe $standalone -Arguments $arguments -Kind 'v2' -Product 'EE' -FirstInstall $true
    } catch {
      $problems += $_.Exception.Message
    }
    if ($null -ne $code -and $code -ne 0) { $problems += "exit code $code, expected 0" }
    if (-not (Wait-E2ESuiteFinished 120)) { $problems += 'the setup was still running 120 s after its end (stopped now)' }
    if (-not (Complete-E2ECheck $s 'standalone/RUN' $problems "exit code $code")) { return }
    # the shortcuts of the standalone setup: the ones the suite must replace
    $legacy = @(
      (Join-Path (Get-E2ESuiteDesktop) 'Empire Earth.lnk'),
      (Join-Path (Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth') 'Empire Earth.lnk')
    )
    if (Test-Path -LiteralPath (Join-Path $root 'Tools\Diagnostic\EE-Diagnostic.exe') -PathType Leaf) {
      $legacy += Join-Path (Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth') 'Empire Earth Diagnostic.lnk'
    }
    $problems = @()
    foreach ($path in $legacy) {
      $link = Get-E2EShortcut $path
      if (-not $link) { $problems += "$path missing after the standalone setup" }
      elseif ($link.Target -ine (Join-Path (Join-Path $root 'Empire Earth') 'Empire Earth.exe') -and $path -notlike '*Diagnostic*') { $problems += "$path points to $($link.Target)" }
    }
    # a file of the player in the installation, to see that it was adopted and not replaced
    $marker = Join-Path $root 'Empire Earth\Data\ci-adopt-marker.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $marker) | Out-Null
    [System.IO.File]::WriteAllText($marker, 'adopted in place', (New-Object System.Text.UTF8Encoding($false)))
    $before = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath $ee)
    if ($null -eq $before) { $problems += 'the standalone setup left no uninstall key' }
    [void](Complete-E2ECheck $s 'standalone/LNK' $problems 'its own shortcuts exist: desktop, start menu folder Empire Earth (and Diagnostic)')

    # 2. The suite adopts it
    $run = Invoke-E2ESuiteRun -Scenario $s -Step 'suite' -Package $env:E2E_SUITE -Products 'EE'
    if ($run.Ok) {
      Invoke-E2ESuiteInstalledChecks -Scenario $s -Step 'suite' -Run $run -Products @('EE') -Package $env:E2E_SUITE -Adopted $true
      $problems = @()
      $after = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath $ee)
      if ($null -ne $before -and $null -ne $after) {
        if ((Get-E2ERegString $after 'Inno Setup: App Path') -ine (Get-E2ERegString $before 'Inno Setup: App Path')) { $problems += 'the product folder changed' }
        if ((Get-E2ERegString $after 'Inno Setup: Selected Tasks').Replace('desktopicon', '').Trim(',') -cne (Get-E2ERegString $before 'Inno Setup: Selected Tasks').Replace('desktopicon', '').Trim(',')) { $problems += 'the tasks of the product changed' }
      }
      if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { $problems += 'the file of the player in the installation is gone' }
      $command = Get-E2ESuiteChildCommand $run.LogLines 'EE'
      if ($null -eq $command -or $command.State -ne 1) { $problems += 'the suite did not see EE as installed for all users (state 1)' }
      $problems += @(Test-E2ELogLines -Lines $run.LogLines -Matches @('^Products: state EE 1, NeoEE 0 '))
      # the old shortcuts were deleted by the suite (a log line each), and the folder Empire Earth is gone
      foreach ($path in $legacy) {
        $problems += @(Test-E2ELogLines -Lines $run.LogLines -Contains @("Old shortcut of the EE setup removed: $path"))
      }
      if (Test-Path -LiteralPath (Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth')) { $problems += 'the start menu folder Empire Earth of the product is still there' }
      [void](Complete-E2ECheck $s 'suite/ADOPT' $problems 'adopted in place (same folder, same tasks, files kept); the old shortcuts were removed, the suite shortcuts stand')
    }
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S4: one slice missing ---------------------------------------------------------------------------------------------

function Test-E2ENothingInstalled([string]$Scenario, [string]$Step, [string]$What) {
  $problems = @(Get-E2ESuiteDirtyState)
  [void](Complete-E2ECheck $Scenario "$Step/NOTHING" $problems $What)
}

function Invoke-E2EScenarioS4 {
  $s = 'S4'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  $package = Copy-E2ESuitePackage $s
  $slices = @(Get-ChildItem -LiteralPath $package -Filter $E2ESuiteConst.SliceFilter -File | Sort-Object Name)
  if ($slices.Count -eq 0) { Add-E2EResult $s 'package' 'FAIL' @('the package has no slice'); return }
  $victim = $slices[0]
  if ($slices.Count -ge 2) { $victim = $slices[1] }
  Remove-Item -LiteralPath $victim.FullName -Force
  $run = Invoke-E2ESuiteRun -Scenario $s -Step 'missing-slice' -Package $package -Products 'EE,NeoEE' -ExpectExit $E2ESuiteConst.ExitSlices -TimeoutMinutes $E2ESuiteConst.PrecheckTimeoutMinutes
  $problems = @(Test-E2ELogLines -Lines $run.LogLines -Matches @("^Precheck failed, exit code $($E2ESuiteConst.ExitSlices): slices missing or wrong: .*$([regex]::Escape($victim.Name))") `
    -NotMatches @('^Product (EE|NeoEE) \(step', '^Pin check of the ', '^Suite record written'))
  [void](Complete-E2ECheck $s 'missing-slice/STOP' $problems "$($victim.Name) removed: the suite stopped with exit code $($E2ESuiteConst.ExitSlices) before it extracted anything, and did not wait for a disk")
  Test-E2ENothingInstalled $s 'missing-slice' 'no product, no record, no shortcut, no suite folder'
  Test-E2EMachineSnapshot $s 'missing-slice'
}

# --- S5: wrong pin ----------------------------------------------------------------------------------------------------

function Invoke-E2EScenarioS5 {
  $s = 'S5'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  $package = $env:E2E_WRONGPIN
  if (-not $package -or -not (Test-Path -LiteralPath (Join-Path $package $E2ESuiteConst.SetupFile) -PathType Leaf)) {
    Add-E2EResult $s 'package' 'FAIL' @("the suite built with -TestWrongEEPin is missing: $package")
    return
  }
  $run = Invoke-E2ESuiteRun -Scenario $s -Step 'wrong-pin' -Package $package -Products 'EE,NeoEE' -ExpectExit $E2ESuiteConst.ExitProductSetup -TimeoutMinutes $E2ESuiteConst.PrecheckTimeoutMinutes
  $problems = @(Test-E2ELogLines -Lines $run.LogLines -Matches @("^Precheck failed, exit code $($E2ESuiteConst.ExitProductSetup): the EE setup does not match its pin: ") `
    -NotMatches @('^Product (EE|NeoEE) \(step', '^Suite record written', '^Pin check of the EE setup'))
  [void](Complete-E2ECheck $s 'wrong-pin/STOP' $problems "the suite stopped with exit code $($E2ESuiteConst.ExitProductSetup) before any product setup was started")
  Test-E2ENothingInstalled $s 'wrong-pin' 'no product setup was started, nothing installed'
  Test-E2EMachineSnapshot $s 'wrong-pin'
}

# --- S6: a game or the launcher is running -----------------------------------------------------------------------------

# Starts a process that holds the named mutex (a game or the launcher running): the mutex is created in this
# session, where the setups look for it. The process ends by itself after 10 minutes; Stop-E2EMutexHolder stops it.
function Start-E2EMutexHolder([string]$Name) {
  $script = "`$m = New-Object System.Threading.Mutex(`$true, '$Name'); Start-Sleep -Seconds 600"
  $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
  $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded) -WindowStyle Hidden -PassThru
  $deadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $deadline) {
    if (Test-E2EMutex $Name) { return $process }
    Start-Sleep -Milliseconds 500
  }
  Stop-E2EProcessTree $process
  throw "the helper process did not create the mutex $Name within 60 s"
}

function Stop-E2EMutexHolder($Process) {
  if ($null -ne $Process) { Stop-E2EProcessTree $Process }
}

function Invoke-E2EScenarioS6 {
  $s = 'S6'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  $legs = @(
    @{ Step = 'game-ee';  Mutex = $E2ESuiteConst.GameMutexEE;   Text = 'Empire Earth' },
    @{ Step = 'game-aoc'; Mutex = $E2ESuiteConst.GameMutexAoC;  Text = 'The Art of Conquest' },
    @{ Step = 'launcher'; Mutex = $E2ESuiteConst.LauncherMutex; Text = 'the launcher' }
  )
  foreach ($leg in $legs) {
    $holder = $null
    try {
      try {
        $holder = Start-E2EMutexHolder $leg.Mutex
      } catch {
        Add-E2EResult $s "$($leg.Step)/HOLDER" 'FAIL' @($_.Exception.Message)
        continue
      }
      $run = Invoke-E2ESuiteRun -Scenario $s -Step $leg.Step -Package $env:E2E_SUITE -Products 'EE,NeoEE' -ExpectExit $E2ESuiteConst.ExitRunning -TimeoutMinutes $E2ESuiteConst.PrecheckTimeoutMinutes
      $problems = @(Test-E2ELogLines -Lines $run.LogLines -Matches @("^Precheck failed, exit code $($E2ESuiteConst.ExitRunning): a game or the launcher is running ") `
        -NotMatches @('^Product (EE|NeoEE) \(step', '^Pin check of the ', '^Suite record written'))
      [void](Complete-E2ECheck $s "$($leg.Step)/REFUSED" $problems "$($leg.Text) running (mutex $($leg.Mutex)): the suite refused with exit code $($E2ESuiteConst.ExitRunning)")
      Test-E2ENothingInstalled $s $leg.Step 'nothing installed'
    } finally {
      Stop-E2EMutexHolder $holder
    }
  }
  Test-E2EMachineSnapshot $s 'end'
}

# --- S7: a product removed on its own, then the suite uninstaller ----------------------------------------------------------

function Invoke-E2EScenarioS7 {
  $s = 'S7'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE,NeoEE' $false
    if (-not $run.Ok) { return }
    $roots = Get-E2ESuiteProductRoots
    # NeoEE through its own uninstaller (Windows "Apps"), as a user would
    $neo = Get-E2EProduct 'NeoEE'
    $problems = @()
    try {
      $removal = Invoke-E2EUninstall $neo $roots['NeoEE'] 'HKLM64' (Get-E2ESuiteLogFile $s 'neoee-own-uninstall')
      $problems += @($removal.Problems)
      if ($null -ne $removal.ExitCode -and $removal.ExitCode -ne 0) { $problems += "unins000.exe of NeoEE: exit code $($removal.ExitCode)" }
    } catch {
      $problems += $_.Exception.Message
    }
    $problems += @(Test-E2EProductRemoved 'NeoEE' $roots['NeoEE'])
    if (-not (Test-E2ERegKey 'HKLM64' (Get-E2EUninstallKeyPath (Get-E2EProduct 'EE')))) { $problems += 'EE was removed with NeoEE' }
    if (-not (Complete-E2ECheck $s 'prepare/NEOEE-GONE' $problems 'NeoEE removed through its own uninstaller, EE and the suite stand')) { return }

    $un = Invoke-E2ESuiteUninstall $s 'suite-uninstall'
    $problems = @($un.Problems)
    $problems += @(Test-E2ELogLines -Lines $un.LogLines -Contains @('Product NeoEE is listed but not installed any more (removed through its own entry in Apps): nothing to remove',
        "Product EE is installed in $($roots['EE'])") -NotContains @('could not be started', 'no usable uninstaller', 'timed out'))
    $problems += @(Test-E2EProductRemoved 'EE' $roots['EE'])
    $problems += @(Test-E2ESuiteRemoved)
    [void](Complete-E2ECheck $s 'suite-uninstall/SKIPPED' $problems 'the product that was gone was skipped cleanly, EE and the suite removed')
    Test-E2ENothingInstalled $s 'suite-uninstall' 'nothing left'
    Test-E2EMachineSnapshot $s 'suite-uninstall'
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# What must be gone after the suite uninstaller ran: its keys, its record, its files, its shortcuts, its start menu
# folder, the settings and the log of the launcher (silent: the backups and the Mod Creator folder stay)
function Test-E2ESuiteRemoved {
  $problems = @()
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $hive (Get-E2ESuiteUninstallKeyPath)) { $problems += "$hive\$(Get-E2ESuiteUninstallKeyPath) is still there" }
  }
  if (Test-E2ERegKey 'HKLM64' $E2ESuiteConst.RecordKey) { $problems += "HKLM64\$($E2ESuiteConst.RecordKey) is still there" }
  if (Test-E2ERegKey 'HKLM64' $E2EConst.CommunityKey) { $problems += "HKLM64\$($E2EConst.CommunityKey) is still there" }
  if (Test-E2ERegKey 'HKCU' $E2EConst.CommunityKey) { $problems += "HKCU\$($E2EConst.CommunityKey) is still there" }
  $root = Get-E2ESuiteRoot
  if (Test-Path -LiteralPath $root) {
    $left = @(Get-E2EFileTree $root | ForEach-Object { $_.Rel })
    $problems += "$root is still there ($($left.Count) item(s): $(($left | Select-Object -First 5) -join ', '))"
  }
  if (Test-Path -LiteralPath (Get-E2ESuiteGroup)) { $problems += "$(Get-E2ESuiteGroup) is still there" }
  foreach ($desktop in @((Get-E2EKnownFolder 'CommonDesktopDirectory'), (Get-E2EKnownFolder 'DesktopDirectory'))) {
    foreach ($name in @('Empire Earth.lnk', 'Neo Empire Earth.lnk')) {
      if (Test-Path -LiteralPath (Join-Path $desktop $name)) { $problems += "$desktop\$name is still there" }
    }
  }
  foreach ($file in @('settings.json', 'log.txt')) {
    if (Test-Path -LiteralPath (Join-Path (Get-E2ELauncherDataDir) $file)) { $problems += "the launcher's $file is still there" }
  }
  return $problems
}

# --- S8: the suite uninstaller keeps the user data ----------------------------------------------------------------------------

function Invoke-E2EScenarioS8 {
  $s = 'S8'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE,NeoEE' $false
    if (-not $run.Ok) { return }
    $roots = Get-E2ESuiteProductRoots
    # what a player has: saved games and a self-made mod (Data\dxm\mods, M1) in both products, the settings, the log and a backup of the launcher
    $userData = @('Empire Earth\Data\Saved Games\ci-save.sav', 'Empire Earth\Data\dxm\mods\ci-mod\CREDITS')
    $keep = @{}
    foreach ($id in @('EE', 'NeoEE')) { $keep[$id] = @($userData | ForEach-Object { Join-Path $roots[$id] $_ }) }
    $data = Get-E2ELauncherDataDir
    $files = @($keep['EE']) + @($keep['NeoEE']) + @((Join-Path $data 'Backups\ci-backup.reg'), (Join-Path $data 'settings.json'), (Join-Path $data 'log.txt'))
    foreach ($file in $files) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
      [System.IO.File]::WriteAllText($file, "ci data $file", (New-Object System.Text.UTF8Encoding($false)))
    }
    # the defaults of the games exist before (the uninstaller must remove them)
    $problems = @()
    foreach ($id in @('EE', 'NeoEE')) {
      if (-not (Test-E2ERegKey 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$id")) { $problems += "HKCU GameDefaults\$id missing before the uninstallation" }
    }
    [void](Complete-E2ECheck $s 'before/DATA' $problems 'saved games, launcher data and the defaults in HKCU exist')

    $un = Invoke-E2ESuiteUninstall $s 'suite-uninstall'
    $problems = @($un.Problems)
    $patterns = @($userData | ForEach-Object { '^' + [regex]::Escape($_) + '$' })
    foreach ($id in @('EE', 'NeoEE')) {
      $problems += @(Test-E2EProductRemoved $id $roots[$id] $patterns)
      foreach ($path in $keep[$id]) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $problems += "${id}: $path (user data) is gone" }
        elseif ([System.IO.File]::ReadAllText($path) -cne "ci data $path") { $problems += "${id}: $path (user data) changed" }
      }
    }
    $problems += @(Test-E2ESuiteRemoved)
    if (-not (Test-Path -LiteralPath (Join-Path $data 'Backups\ci-backup.reg') -PathType Leaf)) { $problems += 'the backup of the launcher is gone (a silent uninstallation keeps the user data)' }
    $problems += @(Test-E2ELogLines -Lines $un.LogLines -Contains @('Silent uninstallation: the user data stays:') -NotContains @('User data folder deleted'))
    [void](Complete-E2ECheck $s 'suite-uninstall/REMOVED' $problems 'both products, the launcher, the shortcuts, the record and the defaults in HKCU are gone; saved games, self-made mods and backups stay')
    Test-E2EMachineSnapshot $s 'suite-uninstall'
  } finally {
    Invoke-E2ESuiteCleanup $s
    # the data of the scenario stays out of the next one
    foreach ($path in @((Get-E2ELauncherDataDir), (Get-E2ESuiteProductRoots)['EE'], (Get-E2ESuiteProductRoots)['NeoEE'])) {
      try { if (Test-Path -LiteralPath $path) { Remove-E2EFolder $path } } catch { Write-Host "Cleanup of ${path}: $($_.Exception.Message)" }
    }
  }
}

# --- S9: a second run is a repair --------------------------------------------------------------------------------------------

function Get-E2ESuiteState([string[]]$Ids) {
  $state = @{}
  foreach ($id in $Ids) {
    $values = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath (Get-E2EProduct $id))
    $state[$id] = @{
      Root = (Get-E2ERegString $values 'Inno Setup: App Path'); Tasks = (Get-E2ERegString $values 'Inno Setup: Selected Tasks')
      Components = (Get-E2ERegString $values 'Inno Setup: Selected Components')
    }
  }
  return $state
}

function Invoke-E2EScenarioS9 {
  $s = 'S9'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE,NeoEE' $false
    if (-not $run.Ok) { return }
    $ids = @('EE', 'NeoEE')
    $roots = Get-E2ESuiteProductRoots
    $first = Get-E2ESuiteState $ids
    $problems = @()
    foreach ($id in $ids) {
      if (-not $first[$id].Root) { $problems += "$id has no uninstall key after the first run" }
      if (Test-E2EListHas $first[$id].Tasks 'neoee_cdkeys') { $problems += "${id}: the task neoee_cdkeys is selected after the first run" }
    }
    if (-not (Complete-E2ECheck $s 'install/STATE' $problems 'both products installed, no neoee_cdkeys in the tasks')) { return }

    # a self-made mod folder below Data\dxm\mods in both products: the repair must leave it as it is (M1)
    $mods = @{}
    foreach ($id in $ids) {
      $mods[$id] = Join-Path $roots[$id] 'Empire Earth\Data\dxm\mods\ci-mod\CREDITS'
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mods[$id]) | Out-Null
      [System.IO.File]::WriteAllText($mods[$id], "ci mod $id", (New-Object System.Text.UTF8Encoding($false)))
    }

    # damage: a game program is gone, two of the suite's shortcuts are gone
    $game = Join-Path (Join-Path $roots['EE'] $E2EGames['EE'].Folder) $E2EGames['EE'].Exe
    Remove-Item -LiteralPath $game -Force
    $gone = @((Join-Path (Get-E2ESuiteDesktop) 'Neo Empire Earth.lnk'), (Join-Path (Get-E2ESuiteGroup) 'Empire Earth.lnk'))
    foreach ($path in $gone) { Remove-Item -LiteralPath $path -Force }

    # as a repair by the suite itself: no /TYPE, so the products keep their components
    $repair = Invoke-E2ESuiteRun -Scenario $s -Step 'repair' -Package $env:E2E_SUITE -Products 'EE,NeoEE' `
      -EEArgs $E2ESuiteConst.RepairEEArgs -NeoEEArgs $E2ESuiteConst.RepairNeoEEArgs
    if ($repair.Ok) {
      Invoke-E2ESuiteInstalledChecks -Scenario $s -Step 'repair' -Run $repair -Products $ids -Package $env:E2E_SUITE -Adopted $true
      $second = Get-E2ESuiteState $ids
      $problems = @()
      foreach ($id in $ids) {
        if ($second[$id].Root -ine $first[$id].Root) { $problems += "${id}: the folder changed from $($first[$id].Root) to $($second[$id].Root)" }
        if ($second[$id].Tasks -cne $first[$id].Tasks) { $problems += "${id}: the tasks changed from '$($first[$id].Tasks)' to '$($second[$id].Tasks)'" }
        if ($second[$id].Components -cne $first[$id].Components) { $problems += "${id}: the components changed" }
        if (Test-E2EListHas $second[$id].Tasks 'neoee_cdkeys') { $problems += "${id}: the task neoee_cdkeys was added" }
        $command = Get-E2ESuiteChildCommand $repair.LogLines $id
        if ($null -eq $command -or $command.State -ne 1) { $problems += "${id}: the suite did not see it as installed (state 1)" }
      }
      $problems += @(Test-E2ELogLines -Lines $repair.LogLines -NotContains @('CD Keys generation result'))
      if (-not (Test-Path -LiteralPath $game -PathType Leaf)) { $problems += "$game was not restored" }
      foreach ($path in $gone) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $problems += "$path was not restored" }
      }
      [void](Complete-E2ECheck $s 'repair/KEPT' $problems 'the same folders, components and tasks (no neoee_cdkeys), the missing game program and the two shortcuts restored')
      $problems = @()
      foreach ($id in $ids) {
        if (-not (Test-Path -LiteralPath $mods[$id] -PathType Leaf)) { $problems += "${id}: the self-made mod folder $($mods[$id]) is gone after the repair" }
        elseif ([System.IO.File]::ReadAllText($mods[$id]) -cne "ci mod $id") { $problems += "${id}: the file of the self-made mod changed" }
      }
      [void](Complete-E2ECheck $s 'repair/MODS' $problems 'a folder below Data\dxm\mods that the player made is still there, unchanged (the setups delete only the presets they install)')
    }
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S10: Zone.Identifier on the package -------------------------------------------------------------------------------------

# Puts the stream Zone.Identifier (the zone of the internet, as a browser or an extracted ZIP does) on every file of
# the package; returns the problems of reading it back
function Set-E2EZoneIdentifier([string]$Folder) {
  $problems = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $Folder -File)) {
    Set-Content -LiteralPath $file.FullName -Stream 'Zone.Identifier' -Value (Get-E2EZoneIdentifierText) -Encoding Ascii
    $back = @(Get-Content -LiteralPath $file.FullName -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue)
    if (($back -join ' ') -notmatch 'ZoneId=3') { $problems += "$($file.Name): the stream Zone.Identifier was not written" }
  }
  return $problems
}

function Invoke-E2EScenarioS10 {
  $s = 'S10'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $package = Copy-E2ESuitePackage $s
    $problems = @(Set-E2EZoneIdentifier $package)
    if (-not (Complete-E2ECheck $s 'prepare/ADS' $problems "Zone.Identifier (ZoneId=3) on the program and every slice of $package")) { return }
    [void](Invoke-E2ESuiteInstall $s 'install' $package 'EE,NeoEE' $true)
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S11: cancel while the first product setup runs ---------------------------------------------------------------------------

# What a cancelled run may leave: the folder of the suite with the log of the product setup it stopped, and nothing
# else; no product, no record, no shortcut, no uninstall key
function Test-E2ECancelledState([string]$Scenario, [string]$Step) {
  $root = Get-E2ESuiteRoot
  $problems = @()
  foreach ($item in @(Get-E2ESuiteDirtyState)) {
    if ($item -ne "$root (suite)") { $problems += $item }
  }
  if (Test-Path -LiteralPath $root -PathType Container) {
    foreach ($entry in @(Get-ChildItem -LiteralPath $root -Force)) {
      if ($entry.Name -ne 'Logs') { $problems += "$($entry.FullName) was left by the cancelled run" }
    }
    $logs = Join-Path $root 'Logs'
    if (Test-Path -LiteralPath $logs -PathType Container) {
      foreach ($entry in @(Get-ChildItem -LiteralPath $logs -Force)) {
        if ($entry.Name -notlike 'EE-*.log') { $problems += "$($entry.FullName) is not the log of the product setup that was stopped" }
      }
    }
  }
  [void](Complete-E2ECheck $Scenario "$Step/NOTHING" $problems 'no product, no record, no shortcut, no uninstall key; the folder of the suite holds the log of the stopped product setup only')
}

# The suite is started with /TestCancel (suite_run.iss): as soon as the real setup of EE, not only its loader, has opened
# its log, the cancel is requested as if the user had answered the question with Yes. The suite must stop the product
# setup and everything it started (a job object: the loader waits for a .tmp file in %TEMP% that does the work), start
# no NeoEE and end with exit code 3, and nothing may be installed: a product setup that survived would install EE a few
# seconds later, within the time the run waits for every setup to be gone.
function Invoke-E2EScenarioS11 {
  $s = 'S11'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteRun -Scenario $s -Step 'cancel' -Package $env:E2E_SUITE -Products 'EE,NeoEE' -ExpectExit $E2ESuiteConst.ExitCancelled `
      -ExtraSwitches @('/TestCancel')
    $problems = @(Test-E2ELogLines -Lines $run.LogLines -Matches @(
        '^Product EE \(step 1 of 2, state 0\): ',
        '^Product EE: /TestCancel, the cancel is requested as if the user had answered the question with Yes$',
        '^Product EE: cancelled by the user before it installed anything, stopping its setup and everything it started$',
        '^Product EE: its setup is gone$',
        '^Product EE was cancelled by the user before it installed anything$',
        '^Products that succeeded in this run: ""$',
        '^The installation was cancelled by the user: no further product setup is started, Setup ends$') `
      -NotMatches @('^Product NeoEE \(step', '^Suite record written', '^Shortcut created: ', '^Product EE failed',
        '^Product EE: the cancel came too late', '^Product EE: its setup did not end', '^Product EE phase: (install|post install|CD keys|manifest|done)'))
    [void](Complete-E2ECheck $s 'cancel/STOP' $problems 'the cancel stopped the first product setup before it installed anything, NeoEE never started, exit code 3')
    Test-E2ECancelledState $s 'cancel'
    Test-E2EMachineSnapshot $s 'cancel'
  } finally {
    $root = Get-E2ESuiteRoot
    if (Test-Path -LiteralPath $root -PathType Container) { Remove-E2EFolder $root }
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S12: cancel while the second product setup runs ----------------------------------------------------------------------

# The suite is started with /TestCancelNeoEE (suite_run.iss): EE is installed, then the cancel is requested for the NeoEE
# setup as soon as its real setup has opened its log. EE has lost its old shortcuts by then (/NOICONS), so the suite must not
# end here (finding 5 of the review of 2026-10-07): it starts no further product, stops the NeoEE setup with everything it
# started, and finishes its own part for EE: the launcher, the shortcuts of EE, the record with Products = EE, exit code 0.
function Invoke-E2EScenarioS12 {
  $s = 'S12'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteRun -Scenario $s -Step 'cancel' -Package $env:E2E_SUITE -Products 'EE,NeoEE' -ExtraSwitches @('/TestCancelNeoEE')
    if (-not $run.Ok) { return }
    $problems = @(Test-E2ELogLines -Lines $run.LogLines -Matches @(
        '^Product EE \(step 1 of 2, state 0\): ',
        '^Product NeoEE \(step 2 of 2, state 0\): ',
        '^Product NeoEE: /TestCancel, the cancel is requested as if the user had answered the question with Yes$',
        '^Product NeoEE: cancelled by the user before it installed anything, stopping its setup and everything it started$',
        '^Product NeoEE: its setup is gone$',
        '^Product NeoEE was cancelled by the user before it installed anything$',
        '^Products that succeeded in this run: "EE"$',
        '^The installation of NeoEE was cancelled by the user: no further product setup is started, the suite finishes its own part for "EE"$',
        '^Suite record written: EE$') `
      -NotMatches @('^Product NeoEE failed', '^Product NeoEE: the cancel came too late', '^Product NeoEE: its setup did not end',
        '^Product NeoEE phase: (install|post install|CD keys|manifest|done)',
        '^The installation was cancelled by the user: no further product setup is started, Setup ends$'))
    [void](Complete-E2ECheck $s 'cancel/STOP' $problems 'the NeoEE setup was stopped before it installed anything and the suite finished its part for EE')
    # what the suite part of a run with EE alone leaves, as in S2: the checks of an installation by the suite
    Invoke-E2ESuiteInstalledChecks -Scenario $s -Step 'cancel' -Run $run -Products @('EE') -Package $env:E2E_SUITE
    $neo = Get-E2EProduct 'NeoEE'
    $roots = Get-E2ESuiteProductRoots
    $problems = @()
    foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
      if (Test-E2ERegKey $hive (Get-E2EUninstallKeyPath $neo)) { $problems += "$hive uninstall key of NeoEE exists" }
    }
    if (Test-Path -LiteralPath $roots['NeoEE']) { $problems += "$($roots['NeoEE']) exists" }
    if (Test-E2ERegKey 'HKLM64' "$($E2EConst.CommunityKey)\Installations\NeoEE") { $problems += 'the install record of NeoEE exists' }
    [void](Complete-E2ECheck $s 'cancel/NO-NEOEE' $problems 'NeoEE is neither installed nor recorded, EE and the launcher are')
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- S13: cancel of a repair leaves the installed product as it was -------------------------------------------------------

# EE is installed by the suite, then the suite runs again as a repair with /TestCancel: the cancel stops the EE setup before
# it changes the game folder (the first statement of its install step, finding 1 of the review). Nothing of EE may differ
# afterwards: every file with its size and time, the uninstall key values, and the record of the suite stay as they were.
function Invoke-E2EScenarioS13 {
  $s = 'S13'
  if (-not (Initialize-E2ESuiteScenario $s)) { return }
  try {
    $run = Invoke-E2ESuiteInstall $s 'install' $env:E2E_SUITE 'EE' $false
    if (-not $run.Ok) { return }
    $roots = Get-E2ESuiteProductRoots
    $before = @(Get-E2EFileTreeLines $roots['EE'])
    $stateBefore = Get-E2ESuiteState @('EE')
    $recordBefore = Get-E2ERegValues 'HKLM64' $E2ESuiteConst.RecordKey
    $problems = @()
    if (-not $stateBefore['EE'].Root) { $problems += 'EE has no uninstall key after the first run' }
    if ($before.Count -eq 0) { $problems += "no file below $($roots['EE'])" }
    if ($null -eq $recordBefore) { $problems += 'no suite record after the first run' }
    if (-not (Complete-E2ECheck $s 'install/STATE' $problems "EE installed, $($before.Count) entries below its root")) { return }

    $cancel = Invoke-E2ESuiteRun -Scenario $s -Step 'repair-cancel' -Package $env:E2E_SUITE -Products 'EE' -ExpectExit $E2ESuiteConst.ExitCancelled `
      -EEArgs $E2ESuiteConst.RepairEEArgs -ExtraSwitches @('/TestCancel')
    if (-not $cancel.Ok) { return }
    $problems = @(Test-E2ELogLines -Lines $cancel.LogLines -Matches @(
        '^Product EE \(step 1 of 1, state 1\): ',
        '^Product EE: /TestCancel, the cancel is requested as if the user had answered the question with Yes$',
        '^Product EE: cancelled by the user before it installed anything, stopping its setup and everything it started$',
        '^Product EE: its setup is gone$',
        '^Product EE was cancelled by the user before it installed anything$',
        '^Products that succeeded in this run: ""$',
        '^The installation was cancelled by the user: no further product setup is started, Setup ends$') `
      -NotMatches @('^Suite record written', '^Shortcut created: ', '^Product EE failed', '^Product EE: the cancel came too late',
        '^Product EE: its setup did not end', '^Product EE phase: (install|post install|CD keys|manifest|done)'))
    [void](Complete-E2ECheck $s 'repair-cancel/STOP' $problems 'the repair of EE was stopped before it changed anything, exit code 3')

    $after = @(Get-E2EFileTreeLines $roots['EE'])
    $problems = @(Compare-E2ESnapshot $before $after 'a file or folder of EE')
    $stateAfter = Get-E2ESuiteState @('EE')
    if ($stateAfter['EE'].Root -ine $stateBefore['EE'].Root) { $problems += "the folder of EE changed from $($stateBefore['EE'].Root) to $($stateAfter['EE'].Root)" }
    if ($stateAfter['EE'].Tasks -cne $stateBefore['EE'].Tasks) { $problems += 'the tasks of EE changed' }
    if ($stateAfter['EE'].Components -cne $stateBefore['EE'].Components) { $problems += 'the components of EE changed' }
    $recordAfter = Get-E2ERegValues 'HKLM64' $E2ESuiteConst.RecordKey
    if ($null -eq $recordAfter) { $problems += 'the suite record is gone' }
    elseif ($null -ne $recordBefore -and (Get-E2ERegString $recordAfter 'Written') -cne (Get-E2ERegString $recordBefore 'Written')) { $problems += 'the suite record was written again' }
    foreach ($name in @('install.ini', 'files.sha256')) {
      if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $roots['EE'] (Get-E2EProduct 'EE').SetupDataDir) $name) -PathType Leaf)) { $problems += "$name of EE is gone (the install state a cancel must not delete)" }
    }
    [void](Complete-E2ECheck $s 'repair-cancel/UNCHANGED' $problems 'every file of EE with its size and time, the uninstall key values, install.ini, files.sha256 and the suite record are as before the cancelled repair')
    Test-E2EMachineSnapshot $s 'repair-cancel'
  } finally {
    Invoke-E2ESuiteCleanup $s
  }
}

# --- Phase Prepare -------------------------------------------------------------------------------------------------------

# The Release value of .NET Framework 4 (HKLM64), 0 if there is none
function Get-E2EDotNetRelease {
  $values = Get-E2ERegValues 'HKLM64' 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
  if ($null -eq $values -or -not $values.ContainsKey('Release')) { return 0 }
  return [int]$values['Release'].Value
}

# SHA-256 of every file of a folder as name -> hash (lower case), for Test-E2ESuitePackage
function Get-E2EFolderHashes([string]$Folder) {
  $hashes = @{}
  foreach ($file in @(Get-ChildItem -LiteralPath $Folder -File)) { $hashes[$file.Name] = Get-E2EFileSha256 $file.FullName }
  return $hashes
}

# Problems of a package folder of the placeholder suite: SHA256SUMS.txt names exactly its files, with their hashes
function Test-E2EPackageFolder([string]$Folder, [string]$What) {
  if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { return @("$What folder missing: $Folder") }
  $sums = Join-Path $Folder 'SHA256SUMS.txt'
  if (-not (Test-Path -LiteralPath $sums -PathType Leaf)) { return @("$What has no SHA256SUMS.txt: $Folder") }
  return @(Test-E2ESuitePackage ([System.IO.File]::ReadAllText($sums)) (Get-E2EFolderHashes $Folder) | ForEach-Object { "${What}: $_" })
}

function Invoke-E2ESuitePrepare {
  $s = 'Prepare'
  Add-E2EResult $s 'runner' 'INFO' @("$(Get-E2ERunnerInfo)")
  # 1. The inputs: the package of the placeholder suite and the one with the wrong pin (both with their checksums),
  # the placeholder product setups of S3
  $problems = @()
  $problems += @(Test-E2EPackageFolder $env:E2E_SUITE 'the suite')
  $problems += @(Test-E2EPackageFolder $env:E2E_WRONGPIN 'the suite with the wrong pin')
  foreach ($id in @('EE', 'NeoEE')) {
    $setup = Join-Path $env:E2E_PRODUCTS (Get-E2EProduct $id).SetupFile
    if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { $problems += "$setup missing" }
  }
  [void](Complete-E2ECheck $s 'inputs' $problems 'both packages match their SHA256SUMS.txt, both placeholder product setups are there')
  # 2. The runner is the machine the scenarios expect: .NET Framework 4.8 (else the suite installs no launcher), 64-bit
  $release = Get-E2EDotNetRelease
  $problems = @()
  if ($release -lt $E2ESuiteConst.DotNet48Release) { $problems += ".NET Framework Release $release is below $($E2ESuiteConst.DotNet48Release) (4.8): the suite would install no launcher" }
  if (-not [Environment]::Is64BitOperatingSystem) { $problems += 'the runner is not 64-bit Windows' }
  [void](Complete-E2ECheck $s 'runner/DOTNET' $problems ".NET Framework Release $release")

  # 3. Network: the hosts block before any setup runs, then proof that it holds
  Set-E2EHostsBlock $E2EConst.BlockedHosts
  $problems = @(Test-E2EHostsBlocked $E2EConst.BlockedHosts)
  $probe = Invoke-E2EHead 'https://api.empireearth.eu/' 10
  if ($probe.Ok) { $problems += "https://api.empireearth.eu/ answered ($($probe.Detail)) despite the hosts block" }
  $proxy = Get-E2EWinHttpProxy
  if ($proxy -notmatch 'Direct access') { $problems += "a WinHTTP proxy is set, which would bypass the hosts block: $proxy" }
  foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
    if ([Environment]::GetEnvironmentVariable($name)) { $problems += "$name is set" }
  }
  [void](Complete-E2ECheck $s 'NET' $problems "blocked (IPv4 and IPv6): $($E2EConst.BlockedHosts -join ', ')")

  # 4. CD keys: none before the test, then only the dummy in all views; the snapshot is the baseline of every scenario
  $problems = @(Test-E2ECdKeysAbsent)
  if ($problems.Count -eq 0) {
    Initialize-E2ECdKeyDummy
    $problems = @(Test-E2ECdKeyDummy)
    if ($problems.Count -eq 0) { Save-E2ECdKeysSnapshot }
  }
  [void](Complete-E2ECheck $s 'K9' $problems "dummy $($E2EConst.CdKeyDummyName) seeded in HKCU, HKLM64, HKLM32, snapshot saved")

  # 5. Nothing of the products and of the suite installed
  [void](Complete-E2ECheck $s 'CLEAN' @(Get-E2ESuiteDirtyState) 'no installation, no record, no suite, no shortcut')
}

# --- The scenarios by name ------------------------------------------------------------------------------------------------

function Invoke-E2ESuiteScenario([string]$Id) {
  switch ($Id) {
    'Prepare' { Invoke-E2ESuitePrepare }
    'S1' { Invoke-E2EScenarioS1 }
    'S2' { Invoke-E2EScenarioS2 }
    'S3' { Invoke-E2EScenarioS3 }
    'S4' { Invoke-E2EScenarioS4 }
    'S5' { Invoke-E2EScenarioS5 }
    'S6' { Invoke-E2EScenarioS6 }
    'S7' { Invoke-E2EScenarioS7 }
    'S8' { Invoke-E2EScenarioS8 }
    'S9' { Invoke-E2EScenarioS9 }
    'S10' { Invoke-E2EScenarioS10 }
    'S11' { Invoke-E2EScenarioS11 }
    'S12' { Invoke-E2EScenarioS12 }
    'S13' { Invoke-E2EScenarioS13 }
    default { throw "Unknown scenario $Id" }
  }
}
