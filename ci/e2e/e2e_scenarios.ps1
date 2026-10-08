# Scenarios of the real-data end-to-end test (ci/e2e/run_e2e.ps1 runs one per phase): the setup runs,
# the checks of each step (e2e_checks.ps1), the launcher checks with their expectations, and the
# cleanup between scenarios. The README section "End-to-end test on Windows" and section 12 of
# docs/TEST-PLAN.de.md describe what each scenario does and checks. Uses $Repo and $AssetMap of the
# calling script. Windows PowerShell 5.1 compatible, ASCII only. Dot-source after e2e_checks.ps1.

# The intro movies belong to the types full and compact since suite 1.1.0
$AllAddOns = @('additional\hd\terrain', 'additional\hd\music', 'additional\hd\buildings', 'additional\hd\tech', 'additional\hd\effects',
               'additional\drexmod\v3', 'additional\discord', 'additional\tools\diagnostic', 'additional\civs\ec', 'additional\civs\ec_full',
               'additional\movies')
$CompactAddOns = @('additional\drexmod\v3', 'additional\discord', 'additional\tools\diagnostic', 'additional\civs\ec', 'additional\movies')
# The add-ons of the updates D3 to D5, which name their components with /COMPONENTS (no movies, nothing selected by default)
$ExplicitAddOns = @($CompactAddOns | Where-Object { $_ -ne 'additional\movies' })
$CommandLineDefaults = 'Component defaults: nothing selected: /TYPE, /COMPONENTS or /LOADINF on the command line.'
$ExactTasksAdmin = 'compatibility,compatibility_windows,firewallexception,desktopicon'
$ExactTasksUser = 'compatibility,compatibility_windows,desktopicon'
$ConsistencyAllowed = @('ScreenTooLow', 'WindowLargerThanScreen', 'WindowFitsOnlyWithHighDpiAware')
# An update keeps the tasks of the earlier run; these two are never selected (downloads from Microsoft)
$UpdateMergeTasks = '/MERGETASKS="!dxwebsetup,!directplay"'
# Folders of the test on the system drive: the custom root of E and D, the targets of the links,
# and the default folder of the retail CD, where the setup looks for traces ({sd}\Sierra\Empire Earth)
$SystemDrive = $env:SystemDrive
if (-not $SystemDrive) { $SystemDrive = 'C:' }
$TestFolder = Join-Path $SystemDrive 'EE CI'
$CustomRoot = Join-Path $TestFolder 'Custom Root'
$LinkFolder = Join-Path $SystemDrive 'EE-CI'
$SierraFolder = Join-Path $SystemDrive 'Sierra'

# --- Contexts and setup steps ------------------------------------------------------------------------

function New-E2EContext([string]$Scenario, [string]$Step, [string]$ProductId, [string]$Mode, [string]$Root, [string[]]$Games, [string]$Language) {
  return @{
    Scenario = $Scenario; Step = $Step; Product = (Get-E2EProduct $ProductId); Mode = $Mode; Root = $Root
    Games = $Games; Language = $Language; Tasks = $null; RequiredComponents = @(); ForbiddenComponents = @('additional\telemetry')
    Wrapper = ''; Components = @(); FirstInstall = $true; ManifestExact = $true; ManifestAllowed = @(); Settings = 'fresh'; SettingsKeep = @{}
    LogFile = (Join-Path $env:E2E_REPORT "logs\$Scenario-$Step.log"); LogLines = @()
    SetupBuild = $env:E2E_SETUP_BUILD; PinCount = [int]$env:E2E_PIN_COUNT; AssetMap = $script:AssetMap; Repo = $script:Repo; Manifest = @{}
  }
}

# A copy of the context for the next step
function Copy-E2EContext([hashtable]$Ctx, [string]$Step) {
  $copy = @{}
  foreach ($key in $Ctx.Keys) { $copy[$key] = $Ctx[$key] }
  $copy.Step = $Step
  $copy.LogFile = Join-Path $env:E2E_REPORT "logs\$($Ctx.Scenario)-$Step.log"
  $copy.LogLines = @()
  $copy.Manifest = @{}
  return $copy
}

# Runs a setup step and records RUN (exit code, setup finished, log present); reads the log and,
# on a first installation, the wrapper the GPU page chose. True if the exit code is the expected one.
function Invoke-E2ESetupStep {
  param(
    [hashtable]$Ctx,
    [string[]]$Switches,
    [ValidateSet('v2', 'official')][string]$Kind = 'v2',
    [int]$ExpectExit = 0,
    [string[]]$Unblocked = @()
  )
  if ($Kind -eq 'v2') { $exe = Join-Path (Join-Path $env:E2E_BUILD $Ctx.Product.BuildFolder) $Ctx.Product.SetupFile }
  else { $exe = Join-Path $env:E2E_OFFICIAL "$($Ctx.Product.Id)_Setup.exe" }
  $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') + $Switches + @("/LOG=`"$($Ctx.LogFile)`"")
  $problems = @()
  $code = $null
  try {
    $code = Invoke-E2ESetup -Exe $exe -Arguments $arguments -Kind $Kind -Product $Ctx.Product.Id -FirstInstall $Ctx.FirstInstall -Unblocked $Unblocked
  } catch {
    $problems += $_.Exception.Message
  }
  if ($null -ne $code) {
    if ($code -ne $ExpectExit) { $problems += "exit code $code, expected $ExpectExit" }
    if (-not (Wait-E2ESetupFinished $Ctx.Product 120)) { $problems += 'the setup is still running 120 s after its exit' }
  } elseif (-not (Wait-E2ESetupFinished $Ctx.Product 60)) {
    $problems += 'the setup is still running 60 s after it was stopped'
  }
  if (Test-Path -LiteralPath $Ctx.LogFile) { $Ctx.LogLines = ConvertFrom-E2ELogText ([System.IO.File]::ReadAllText($Ctx.LogFile)) }
  elseif ($null -ne $code) { $problems += "no setup log $($Ctx.LogFile)" }
  if ($Kind -eq 'v2' -and $Ctx.FirstInstall -and $code -eq 0) {
    $gpu = Get-E2EGpuChoice $Ctx.LogLines
    if ($gpu.Wrapper) {
      $Ctx.Wrapper = $gpu.Wrapper
      Add-E2EResult $Ctx.Scenario (Get-E2ECheckId $Ctx 'GPU') 'INFO' @("$($gpu.Vendor) GPU detected: the GPU page chose $($gpu.Wrapper)")
    }
  }
  return (Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'RUN') $problems "exit code $code")
}

# The log rules of a run of the official setup 1.7.2: no successful request (every server is
# blocked; 1.7.2 asks the file servers in every run and sends statistics without consent), no
# certificate, no DirectX or DirectPlay installation
function Test-E2EOfficialLog([hashtable]$Ctx) {
  $problems = @(Test-E2ELogLines -Lines $Ctx.LogLines -Contains @('Installation process succeeded.') `
    -NotMatches @('^Status: ', '^Downloaded string: ') -NotContains @('certutil', 'dism.exe', 'dxwebsetup.exe', 'Register NeoEE CD Keys'))
  $requests = @(Select-E2ELogLines $Ctx.LogLines '^(Sending request|Downloading string): ').Count
  $stats = @(Select-E2ELogLines $Ctx.LogLines '^Sending setup stats over HTTPS!$').Count
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'NET') $problems "$requests request(s) attempted, none answered (hosts block); statistics attempts: $stats")
}

# --- Launcher expectations ---------------------------------------------------------------------------

function Get-E2EPerGame([hashtable]$Ctx, [string]$Value) {
  $perGame = [ordered]@{}
  foreach ($game in $Ctx.Games) { $perGame[$game] = $Value }
  return $perGame
}

function Get-E2ELauncherMode([hashtable]$Ctx) {
  if ($Ctx.Mode -eq 'admin') { return 'Admin' }
  return 'User'
}

# The expectation of an installation of a v2 setup; More adds or replaces members ($null removes one)
function Get-E2ELauncherInstallation([hashtable]$Ctx, [hashtable]$More = @{}) {
  $extra = @{
    kind = 'Community'; mode = (Get-E2ELauncherMode $Ctx); appId = $Ctx.Product.AppId; contractVersion = $E2EConst.ContractVersion
    hasArtOfConquest = ($Ctx.Games -contains 'AoC'); state = 'Ok'; missingPrograms = @()
    sources = @('RegistryRecord', 'UninstallKey', 'InstalledFrom')
    integrity = [ordered]@{ quick = [ordered]@{ state = 'Ok'; findings = @(); offersRepair = $false }; full = [ordered]@{ state = 'Ok'; findings = @() } }
    defaultsStatus = (Get-E2EPerGame $Ctx 'Applied')
    consistency = [ordered]@{ expected = @(); allowed = $script:ConsistencyAllowed }
  }
  foreach ($key in $More.Keys) {
    if ($null -eq $More[$key]) { $extra.Remove($key) } else { $extra[$key] = $More[$key] }
  }
  return (New-E2ELauncherInstallation $Ctx.Product.Id $Ctx.Root $extra)
}

function Get-E2ELauncherWork([string]$Scenario, [string]$Step) {
  return (Join-Path $env:E2E_WORK "launcher\$Scenario-$Step")
}

# After a first installation, as the installing account: the setup's marker means the launcher
# start writes nothing; the values the setup wrote are saved for the fresh account step
function Invoke-E2ELauncherInstalled([hashtable]$Ctx) {
  $values = Join-Path (Get-E2ELauncherWork $Ctx.Scenario 'installed') 'setup-values.json'
  $installation = Get-E2ELauncherInstallation $Ctx @{ defaultsAtStart = (Get-E2EPerGame $Ctx 'None'); installedFromAtStart = (Get-E2EPerGame $Ctx 'Present') }
  $expectation = New-E2ELauncherExpectation -Scenario $Ctx.Scenario -Step 'installed' -Installations @($installation) -SelectedRoot $Ctx.Root `
    -Defaults ([ordered]@{ recordSetupValuesTo = $values; expectNoWrites = $true })
  Invoke-E2ELauncherCheck $Ctx.Scenario 'installed' $expectation
  return $values
}

# A fresh account (R1 simulated: the game settings, the marker and the GPU preferences of the
# product are removed): the launcher start applies the recommended values, which must equal what
# the setup wrote; then the reset with its backup
function Invoke-E2ELauncherFreshAccount([hashtable]$Ctx, [string]$SetupValues) {
  $p = $Ctx.Product
  foreach ($game in @('EE', 'AoC')) {
    Remove-E2ERegTree 'HKCU' $p.SettingsKeys[$game]
    Remove-E2ERegValue 'HKCU' $E2EConst.GpuKey (Get-E2EGameProgram $Ctx $game)
  }
  Remove-E2ERegTree 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$($p.Id)"
  $installation = Get-E2ELauncherInstallation $Ctx @{
    sources = @('RegistryRecord', 'UninstallKey'); integrity = $null; defaultsStatus = $null; consistency = $null
    defaultsAtStart = (Get-E2EPerGame $Ctx 'FirstRun'); installedFromAtStart = (Get-E2EPerGame $Ctx 'Created')
  }
  $expectation = New-E2ELauncherExpectation -Scenario $Ctx.Scenario -Step 'fresh-account' -Installations @($installation) -SelectedRoot $Ctx.Root `
    -Defaults ([ordered]@{ expectRecommendedValues = $true; compareWithSetupValuesFrom = $SetupValues; reset = $true })
  Invoke-E2ELauncherCheck $Ctx.Scenario 'fresh-account' $expectation
}

function Invoke-E2ELauncherUninstalled([hashtable]$Ctx) {
  $expectation = New-E2ELauncherExpectation -Scenario $Ctx.Scenario -Step "$($Ctx.Step)-after" -Installations @() -WatchRoots @($Ctx.Root)
  Invoke-E2ELauncherCheck $Ctx.Scenario "$($Ctx.Step)-after" $expectation
}

# --- Clean machine between scenarios -------------------------------------------------------------

# The install roots in the administrative mode (default folders of both products, the custom root of
# E and D) and in the user mode
function Get-E2EAdminRoots {
  return @((Join-Path ${env:ProgramFiles(x86)} (Get-E2EProduct 'EE').DirName), (Join-Path ${env:ProgramFiles(x86)} (Get-E2EProduct 'NeoEE').DirName), $CustomRoot)
}

function Get-E2EKnownRoots {
  return @(@(Get-E2EAdminRoots) + @((Join-Path $env:LOCALAPPDATA "Programs\$((Get-E2EProduct 'EE').DirName)"), (Join-Path $env:LOCALAPPDATA "Programs\$((Get-E2EProduct 'NeoEE').DirName)")))
}

# Folders of the test that must not exist when a scenario starts (Prepare: before the first one): the
# default roots, the folder of the custom root, the link targets and the retail folder E seeds
function Get-E2ETestFolders {
  return @(@(Get-E2EKnownRoots | Where-Object { $_ -ne $CustomRoot }) + @($TestFolder, $LinkFolder, $SierraFolder))
}

# The game programs below the administrative roots (firewall rules exist only in that mode)
function Get-E2EFirewallPrograms {
  $programs = @()
  foreach ($root in Get-E2EAdminRoots) {
    foreach ($game in @('EE', 'AoC')) { $programs += Join-Path (Join-Path $root $E2EGames[$game].Folder) $E2EGames[$game].Exe }
  }
  return $programs
}

# Compatibility layers and GPU preferences whose value name is a program below a known root:
# @{ Hive; Key; Name }
function Get-E2EProgramValues {
  $found = @()
  foreach ($view in @(@('HKLM64', $E2EConst.LayersKey), @('HKCU', $E2EConst.LayersKey), @('HKCU', $E2EConst.GpuKey))) {
    $values = Get-E2ERegValues $view[0] $view[1]
    if (-not $values) { continue }
    foreach ($name in @(Select-E2EPathsBelow @($values.Keys) (Get-E2EKnownRoots))) { $found += @{ Hive = $view[0]; Key = $view[1]; Name = $name } }
  }
  return $found
}

# The start menu group "Empire Earth" (all users, current user) and the desktop shortcuts of both products
function Get-E2EKnownShortcuts {
  $paths = @()
  foreach ($folder in @('CommonPrograms', 'Programs')) { $paths += Join-Path (Get-E2EKnownFolder $folder) 'Empire Earth' }
  foreach ($desktop in @('CommonDesktopDirectory', 'DesktopDirectory')) {
    foreach ($id in @('EE', 'NeoEE')) {
      $name = (Get-E2EProduct $id).AppName
      $paths += Join-Path (Get-E2EKnownFolder $desktop) "$name.lnk"
      $paths += Join-Path (Get-E2EKnownFolder $desktop) "$name - AoC.lnk"
    }
  }
  return $paths
}

# What a scenario must not find at its start: uninstall keys and records of both products, their
# game settings in HKCU, the community keys, the seeds of E, files and folders of the test, the
# compatibility layers, GPU preferences and firewall rules of programs below the known roots, and
# the shortcuts (an earlier scenario that failed or was stopped before its uninstallation)
function Get-E2EDirtyState {
  $found = @()
  foreach ($id in @('EE', 'NeoEE')) {
    $p = Get-E2EProduct $id
    foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
      if (Test-E2ERegKey $hive (Get-E2EUninstallKeyPath $p)) { $found += "$hive uninstall key of $id" }
    }
    foreach ($game in @('EE', 'AoC')) {
      if (Test-E2ERegKey 'HKCU' $p.SettingsKeys[$game]) { $found += "HKCU\$($p.SettingsKeys[$game])" }
    }
  }
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
    if (Test-E2ERegKey $hive $E2EConst.CommunityKey) { $found += "$hive\$($E2EConst.CommunityKey)" }
  }
  foreach ($key in $SeedKeys) {
    if (Test-E2ERegKey 'HKLM32' $key) { $found += "HKLM32\$key (a seed of scenario E)" }
  }
  foreach ($folder in Get-E2ETestFolders) {
    if (Test-Path -LiteralPath $folder) { $found += "folder $folder ($(@(Get-E2EFileTree $folder | Where-Object { -not $_.IsDir }).Count) file(s))" }
  }
  foreach ($value in @(Get-E2EProgramValues)) { $found += "$($value.Hive)\$($value.Key): $($value.Name)" }
  foreach ($program in Get-E2EFirewallPrograms) {
    $rules = @(Get-E2EFirewallRules $program)
    if ($rules.Count -gt 0) { $found += "$($rules.Count) firewall rule(s) of $program" }
  }
  foreach ($path in Get-E2EKnownShortcuts) {
    if (Test-Path -LiteralPath $path) { $found += "shortcut $path" }
  }
  return $found
}

# Uninstalls what an earlier scenario left, then removes every trace Get-E2EDirtyState looks for
# (never Software\Sierra): an uninstall key without a working uninstaller, the keys, the seeds of E,
# the values and firewall rules of the programs, the shortcuts and the folders of the test
function Reset-E2EMachine([string]$Scenario) {
  foreach ($id in @('EE', 'NeoEE')) {
    $p = Get-E2EProduct $id
    foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) {
      $values = Get-E2ERegValues $hive (Get-E2EUninstallKeyPath $p)
      if (-not $values) { continue }
      if ($values.ContainsKey('Inno Setup: App Path')) {
        $root = [string]$values['Inno Setup: App Path'].Value
        try {
          $run = Invoke-E2EUninstall $p $root $hive (Join-Path $env:E2E_REPORT "logs\$Scenario-cleanup-$id.log")
          if ($run.Problems.Count -gt 0) { Write-Host "Cleanup of $id in ${root}: $($run.Problems -join '; ')" }
        } catch {
          Write-Host "Cleanup of $id in ${root}: $($_.Exception.Message)"
        }
      }
      Remove-E2ERegTree $hive (Get-E2EUninstallKeyPath $p)
    }
    foreach ($game in @('EE', 'AoC')) { Remove-E2ERegTree 'HKCU' $p.SettingsKeys[$game] }
  }
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) { Remove-E2ERegTree $hive $E2EConst.CommunityKey }
  foreach ($key in $SeedKeys) { Remove-E2ERegTree 'HKLM32' $key }
  foreach ($value in @(Get-E2EProgramValues)) { Remove-E2ERegValue $value.Hive $value.Key $value.Name }
  foreach ($program in Get-E2EFirewallPrograms) { Remove-E2EFirewallRules $program }
  foreach ($path in @(@(Get-E2EKnownShortcuts) + @(Get-E2ETestFolders))) {
    try {
      if (Test-Path -LiteralPath $path -PathType Container) { Remove-E2EFolder $path }
      elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    } catch {
      Write-Host "Cleanup of ${path}: $($_.Exception.Message)"
    }
  }
}

# Start of a scenario: a clean machine, the dummy intact, every host blocked. False: skip it.
function Initialize-E2EScenario([string]$Scenario) {
  $dirty = @(Get-E2EDirtyState)
  if ($dirty.Count -gt 0) {
    Add-E2EResult $Scenario 'start/CLEAN' 'WARN' (@('left over by an earlier scenario, removed now:') + $dirty)
    Reset-E2EMachine $Scenario
    $dirty = @(Get-E2EDirtyState)
  }
  $problems = $dirty + @(Test-E2ECdKeyDummy) + @(Test-E2EHostsBlocked $E2EConst.BlockedHosts)
  return (Complete-E2ECheck $Scenario 'start/CLEAN' $problems 'nothing installed, CD key dummy intact, every host blocked')
}

function Test-E2EEmptyFolder([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return @("$Path is gone") }
  $items = @(Get-ChildItem -LiteralPath $Path -Force)
  if ($items.Count -gt 0) { return @("$Path is not empty any more ($($items.Count) item(s))") }
  return @()
}

# --- Phase Prepare -----------------------------------------------------------------------------------

function Invoke-E2EPrepare {
  $s = 'Prepare'
  Add-E2EResult $s 'runner' 'INFO' @("$(Get-E2ERunnerInfo), SetupBuild $env:E2E_SETUP_BUILD")
  $problems = @()
  foreach ($exe in @((Join-Path (Join-Path $env:E2E_BUILD 'EE_Regular') 'EE_Setup_v1.7.2.exe'),
                     (Join-Path (Join-Path $env:E2E_BUILD 'NeoEE_Regular') 'NeoEE_v2.0.0.5_Setup_v1.7.2.exe'),
                     (Join-Path $env:E2E_OFFICIAL 'EE_Setup.exe'), $env:LAUNCHER_RM)) {
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { $problems += "$exe missing" }
  }
  [void](Complete-E2ECheck $s 'inputs' $problems 'both v2 setups, the official EE setup and the launcher checks are there')

  $firewall = Get-E2EServiceStatus 'MpsSvc'
  [void](Complete-E2ECheck $s 'firewall-service' @(if ($firewall -ne 'Running') { "MpsSvc is $firewall" }) 'MpsSvc running')

  # 1. Network: the hosts block before any setup runs, then proof that it holds
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

  # 2. CD keys: none before the test, then only the dummy
  $problems = @(Test-E2ECdKeysAbsent)
  if ($problems.Count -eq 0) {
    Initialize-E2ECdKeyDummy
    $problems = @(Test-E2ECdKeyDummy)
  }
  [void](Complete-E2ECheck $s 'K9' $problems "dummy $($E2EConst.CdKeyDummyName) seeded in HKCU, HKLM64, HKLM32")

  # 3. No trusted root certificate of the official setup
  $stores = @(Find-E2ECertificate $E2EConst.OfficialCertThumbprint)
  [void](Complete-E2ECheck $s 'CERT' @($stores | ForEach-Object { "certificate in $_" }) 'not trusted in any store')

  # 4. Nothing of the products installed
  [void](Complete-E2ECheck $s 'CLEAN' @(Get-E2EDirtyState) 'no installation, no record, no game settings')
}

# --- Scenario A: EE for all users, German, downloads from the mirror --------------------------------

function Invoke-E2EScenarioA {
  $s = 'A'
  if (-not (Initialize-E2EScenario $s)) { return }
  $ctx = New-E2EContext $s 'install' 'EE' 'admin' (Join-Path ${env:ProgramFiles(x86)} 'Empire Earth') @('EE', 'AoC') 'de'
  $ctx.Tasks = $ExactTasksAdmin
  $ctx.RequiredComponents = @('game', 'gameaoc', 'language\update') + $AllAddOns
  $ctx.ForbiddenComponents = @('additional\telemetry', 'additional\rms\omega', 'additional\rms\neoextra', 'additional\drexmod\v2')
  # TP-00: the mirror is the only host unblocked, and only while this setup runs
  $unblocked = @($E2EConst.MirrorHost)
  $mirrorOk = $false
  $ran = $false
  Set-E2EHostsBlock @($E2EConst.BlockedHosts | Where-Object { $unblocked -notcontains $_ })
  try {
    $folder = Invoke-E2EHead "https://$($E2EConst.MirrorHost)/localized/"
    $file = Invoke-E2EHead "https://$($E2EConst.MirrorHost)/localized/Game/de/EE/Data/data.ssa"
    $mirrorOk = $folder.Ok -and $file.Ok -and $file.Status -eq 200
    Add-E2EResult $s 'install/TP-00' 'INFO' @("mirror /localized/: $($folder.Detail); Game/de/EE/Data/data.ssa: $($file.Detail)")
    $ran = Invoke-E2ESetupStep $ctx @('/ALLUSERS', '/LANG=de', '/TYPE=full', "/TASKS=`"$($ctx.Tasks)`"") -Unblocked $unblocked
  } finally {
    Set-E2EHostsBlock $E2EConst.BlockedHosts
    [void](Complete-E2ECheck $s 'install/NET' @(Test-E2EHostsBlocked $E2EConst.BlockedHosts) 'every host blocked again')
  }
  if ($ran) {
    Invoke-E2EInstalledChecks $ctx
    Test-E2EDownloads $ctx $mirrorOk
    $values = Invoke-E2ELauncherInstalled $ctx
    Invoke-E2ELauncherFreshAccount $ctx $values
  }
  $u = Copy-E2EContext $ctx 'uninstall'
  Invoke-E2EUninstallChecks $u
  Invoke-E2ELauncherUninstalled $u
}

# --- Scenario B: NeoEE for the current user, English, no CD key task ---------------------------------

function Invoke-E2EScenarioB {
  $s = 'B'
  if (-not (Initialize-E2EScenario $s)) { return }
  $ctx = New-E2EContext $s 'install' 'NeoEE' 'user' (Join-Path $env:LOCALAPPDATA 'Programs\Neo Empire Earth') @('EE', 'AoC') 'en'
  $ctx.Tasks = $ExactTasksUser
  $ctx.RequiredComponents = @('game', 'gameaoc', 'language\update') + $AllAddOns
  $ctx.ForbiddenComponents = @('additional\telemetry', 'additional\drexmod\v2')
  $switches = @('/CURRENTUSER', '/LANG=en', '/TYPE=full', "/TASKS=`"$($ctx.Tasks)`"")
  if (Invoke-E2ESetupStep $ctx $switches) {
    Invoke-E2EInstalledChecks $ctx
    $values = Invoke-E2ELauncherInstalled $ctx
    Invoke-E2ELauncherFreshAccount $ctx $values

    # TP-80 e: a junction in Data does not stop a setup in the user mode (no link check there)
    $repair = Copy-E2EContext $ctx 'repair-junction'
    $repair.FirstInstall = $false
    $target = (Join-Path $LinkFolder 'user-target')
    $link = Join-Path $ctx.Root 'Empire Earth\Data\ci-junction'
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    New-E2EJunction $link $target
    try {
      if (Invoke-E2ESetupStep $repair $switches) {
        $problems = @(Test-E2ELogLines -Lines $repair.LogLines -Contains @('Link check skipped: not the administrative install mode',
          "Will append to existing uninstall log: $($ctx.Root)\unins000.dat", 'Installation process succeeded.') -NotContains @('CD Keys', 'Exception'))
        $problems += @(Test-E2EEmptyFolder $target)
        [void](Complete-E2ECheck $s 'repair-junction/LINK' $problems 'no link check in the user mode, the link target untouched')
        Test-E2EK4Manifest $repair
        Test-E2EK9CdKeys $s 'repair-junction'
      }
    } finally {
      Remove-E2ELink $link
      Remove-Item -LiteralPath $LinkFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  $u = Copy-E2EContext $ctx 'uninstall'
  Invoke-E2EUninstallChecks $u
  Invoke-E2ELauncherUninstalled $u
}

# --- Scenario E: traces of a foreign installation, custom folder, EE only ----------------------------

$ForeignUninstallKey = "$($E2EConst.UninstallKey)\EE-Test-GOG"
$SeedKeys = @("$($E2EConst.UninstallKey)\EE-Test-GOG", "$($E2EConst.UninstallKey)\EE-Test-Community", "$($E2EConst.UninstallKey)\EE-Test-EE2", 'Software\Neo\Empire Earth')

function Get-E2ESeedLines {
  $lines = @()
  foreach ($key in $SeedKeys) { $lines += @(Get-E2ERegTreeLines 'HKLM32' $key) }
  return $lines
}

function Invoke-E2EScenarioE {
  $s = 'E'
  if (-not (Initialize-E2EScenario $s)) { return }
  $root = $CustomRoot
  # Seeds (TP-61 a and b): a game settings key of an old NeoEE installer in HKLM (32-bit view)
  # naming the retail folder, that folder, and three uninstall entries of which only the GOG one
  # counts; its folder is the EE folder of the chosen root
  $neoExisted = Test-E2ERegKey 'HKLM32' 'Software\Neo'
  $sierraExisted = Test-Path -LiteralPath $SierraFolder
  Set-E2ERegValue 'HKLM32' 'Software\Neo\Empire Earth' 'Installed From Volume' $SystemDrive 'String'
  Set-E2ERegValue 'HKLM32' 'Software\Neo\Empire Earth' 'Installed From Directory' '\SIERRA\EMPIRE EARTH' 'String'
  New-Item -ItemType Directory -Force -Path (Join-Path $SierraFolder 'Empire Earth'), (Join-Path $root 'Empire Earth') | Out-Null
  $seeds = @(
    @{ Key = 'EE-Test-GOG'; DisplayName = 'Empire Earth Gold Edition'; Publisher = 'GOG.com'; Location = (Join-Path $root 'Empire Earth') },
    @{ Key = 'EE-Test-Community'; DisplayName = 'Empire Earth v2.0.0.0 - Setup v1.7.2'; Publisher = 'Empire Earth Community'; Location = "$TestFolder\Other" },
    @{ Key = 'EE-Test-EE2'; DisplayName = 'Empire Earth II'; Publisher = 'Sierra Entertainment'; Location = "$TestFolder\EE2" }
  )
  foreach ($seed in $seeds) {
    $key = "$($E2EConst.UninstallKey)\$($seed.Key)"
    Set-E2ERegValue 'HKLM32' $key 'DisplayName' $seed.DisplayName 'String'
    Set-E2ERegValue 'HKLM32' $key 'Publisher' $seed.Publisher 'String'
    Set-E2ERegValue 'HKLM32' $key 'InstallLocation' $seed.Location 'String'
  }
  $seedsBefore = Get-E2ESeedLines

  $ctx = New-E2EContext $s 'install' 'EE' 'admin' $root @('EE') 'en'
  $ctx.Tasks = $ExactTasksAdmin
  $ctx.RequiredComponents = @('game', 'language\update') + $CompactAddOns
  $ctx.ForbiddenComponents = @('additional\telemetry', 'gameaoc', 'additional\civs\ec_full', 'additional\hd\terrain', 'additional\rms\omega')
  $ran = $false
  try {
    $ran = Invoke-E2ESetupStep $ctx @('/ALLUSERS', '/LANG=en', "/DIR=`"$root`"", '/TYPE=compact', "/TASKS=`"$($ctx.Tasks)`"")
    if ($ran) {
      $problems = @(Test-E2ELogLines -Lines $ctx.LogLines -Contains @(
          "Foreign or old installation: registry key HKLM\Software\WOW6432Node\Neo\Empire Earth: $SystemDrive\SIERRA\EMPIRE EARTH",
          "Foreign or old installation: folder $SierraFolder\Empire Earth (already named by a registry key above)",
          "Foreign or old installation: uninstall entry HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG, DisplayName `"Empire Earth Gold Edition`", Publisher `"GOG.com`", InstallLocation `"$root\Empire Earth`"",
          '2 traces of foreign or old installations found, 2 of their folders exist (notice ForeignInstallFound)',
          'Notice ForeignInstallFound not shown (silent installation or /SUPPRESSMSGBOXES)',
          "The game folders in $root would be, contain or lie in the folder of a foreign or old installation: $root\Empire Earth (question ForeignFolderQuestion)",
          'Question ForeignFolderQuestion not asked (silent installation or /SUPPRESSMSGBOXES), the installation continues'
        ) -NotContains @('EE-Test-Community', 'EE-Test-EE2', 'Empire Earth II'))
      [void](Complete-E2ECheck $s 'install/FOREIGN' $problems 'the foreign installation was reported, the community and EE II entries were not')
      $problems = @(Compare-E2ESnapshot $seedsBefore (Get-E2ESeedLines) 'seed')
      if (-not (Test-Path -LiteralPath (Join-Path $SierraFolder 'Empire Earth'))) { $problems += "$SierraFolder\Empire Earth is gone" }
      [void](Complete-E2ECheck $s 'install/SEEDS' $problems 'the setup changed none of them')
      Invoke-E2EInstalledChecks $ctx
    }
  } finally {
    # The launcher would see the seed key as a foreign installation: remove the seeds first
    foreach ($seed in $seeds) { Remove-E2ERegTree 'HKLM32' "$($E2EConst.UninstallKey)\$($seed.Key)" }
    Remove-E2ERegTree 'HKLM32' 'Software\Neo\Empire Earth'
    if (-not $neoExisted) { Remove-E2ERegTree 'HKLM32' 'Software\Neo' }
    if (-not $sierraExisted) { Remove-Item -LiteralPath $SierraFolder -Recurse -Force -ErrorAction SilentlyContinue }
  }
  if ($ran) { [void](Invoke-E2ELauncherInstalled $ctx) }
  # Scenario D continues with this installation
}

# --- Scenario D: link guard and an update without the wrapper (on E) --------------------------------

# Everything a stopped setup must leave as it was: the files below the root, the state files, the
# record, the uninstall key, the game settings, the marker, the GPU and compatibility values and
# the firewall rules of the programs
function Get-E2EStateLines([hashtable]$Ctx) {
  $p = $Ctx.Product
  $lines = @(Get-E2EFileTreeLines $Ctx.Root | ForEach-Object { "file|$_" })
  foreach ($name in @('install.ini', 'files.sha256')) {
    $path = Join-Path (Join-Path $Ctx.Root $p.SetupDataDir) $name
    if (Test-Path -LiteralPath $path) { $lines += "sha256|$name|$(Get-E2EFileSha256 $path)" }
  }
  $lines += @(Get-E2ERegTreeLines 'HKLM64' "$($E2EConst.CommunityKey)\Installations\$($p.Id)")
  $lines += @(Get-E2ERegTreeLines 'HKLM64' (Get-E2EUninstallKeyPath $p))
  $lines += @(Get-E2ERegTreeLines 'HKCU' $p.SettingsKeys['EE'])
  $lines += @(Get-E2ERegTreeLines 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$($p.Id)")
  foreach ($game in $Ctx.Games) {
    $program = Get-E2EGameProgram $Ctx $game
    foreach ($view in @(@('HKCU', $E2EConst.GpuKey), @('HKLM64', $E2EConst.LayersKey), @('HKCU', $E2EConst.LayersKey))) {
      $values = Get-E2ERegValues $view[0] $view[1]
      if ($values -and $values.ContainsKey($program)) { $lines += "$($view[0])\$($view[1])|$program|$($values[$program].Value)" }
    }
    foreach ($rule in @(Get-E2EFirewallRules $program)) { $lines += "firewall|$($rule.Name)|$($rule.Enabled)|$($rule.Action)" }
  }
  return @($lines | Sort-Object)
}

# A run that the link guard must stop: exit code 7, the stop in the log, nothing changed
function Invoke-E2ELinkStop([hashtable]$Ctx, [string]$FindingLine) {
  $before = Get-E2EStateLines $Ctx
  [void](Invoke-E2ESetupStep $Ctx @('/ALLUSERS', '/LANG=en', $UpdateMergeTasks) -ExpectExit 7)
  $problems = @(Test-E2ELogLines -Lines $Ctx.LogLines -Contains @(
      $FindingLine,
      'The installation stops before anything is changed (message LinkInGameFolder on the Preparing to install page; silent installation: exit code 7)',
      'PrepareToInstall failed: ',
      'English language selected, no need to download online files.'
    ) -Matches @('^Link check: \d+ folders and \d+ files below Data and Users of ' + [regex]::Escape($Ctx.Root) + ' examined in \d+ ms, 1 links or unreadable folders or files found, ') `
    -NotContains @('Install state of the previous run deleted', 'Creating new uninstall log', 'Will append to existing uninstall log', 'Installation process succeeded.'))
  $problems += @(Compare-E2ESnapshot $before (Get-E2EStateLines $Ctx) 'state')
  return $problems
}

function Invoke-E2EScenarioD {
  $s = 'D'
  $root = $CustomRoot
  $p = Get-E2EProduct 'EE'
  $installed = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath $p)
  if ((Get-E2ERegString $installed 'Inno Setup: App Path') -ne $root) {
    [void](Complete-E2ECheck $s 'start/E' @("the installation of scenario E in $root is missing; scenario D needs it"))
    return
  }
  [void](Complete-E2ECheck $s 'start/E' @(Test-E2ECdKeyDummy) "continues with the installation of scenario E in $root")
  $base = New-E2EContext $s 'junction' 'EE' 'admin' $root @('EE') 'en'
  $base.FirstInstall = $false
  New-Item -ItemType Directory -Force -Path (Join-Path $LinkFolder 'link-target') | Out-Null
  try {
    # D1 (TP-80): a junction in Data
    $d1 = Copy-E2EContext $base 'junction'
    $junction = Join-Path $root 'Empire Earth\Data\ci-junction'
    New-E2EJunction $junction (Join-Path $LinkFolder 'link-target')
    try {
      $problems = @(Invoke-E2ELinkStop $d1 "Link check: $junction is a junction or symbolic link (reparse point)")
      $problems += @(Test-E2EEmptyFolder (Join-Path $LinkFolder 'link-target'))
      [void](Complete-E2ECheck $s 'junction/LINK' $problems 'exit code 7, nothing changed, the target untouched')
    } finally { Remove-E2ELink $junction }

    # D2 (TP-80, ADR 0009): a hard link in Users
    $d2 = Copy-E2EContext $base 'hardlink'
    $target = (Join-Path $LinkFolder 'hl-target.txt')
    [System.IO.File]::WriteAllText($target, 'ci', [System.Text.Encoding]::ASCII)
    $sddl = Get-E2ESddl $target
    $hardlink = Join-Path $root 'Empire Earth\Users\ci-hardlink.ini'
    New-E2EHardLink $hardlink $target
    try {
      $problems = @(Invoke-E2ELinkStop $d2 "Link check: $hardlink is a hard link (the file has 2 names)")
      if ([System.IO.File]::ReadAllText($target) -cne 'ci') { $problems += "$target changed" }
      if ((Get-E2ESddl $target) -cne $sddl) { $problems += "the permissions of $target changed" }
      [void](Complete-E2ECheck $s 'hardlink/LINK' $problems 'exit code 7, nothing changed, the linked file untouched')
    } finally { Remove-Item -LiteralPath $hardlink -Force -ErrorAction SilentlyContinue }

    # D3: update without links and without the DirectX wrapper. M1: a self-made mod folder below Data\dxm\mods must
    # survive it, a file a player put into a preset folder goes with the folder, dreXmod.config is reset (K10)
    $modFile = Join-Path $root 'Empire Earth\Data\dxm\mods\ci-mod\CREDITS'
    $presetFile = Join-Path $root 'Empire Earth\Data\dxm\mods\yukon\ci-extra.txt'
    $modPresets = @('drexmod.com', 'images', 'mods\dxm', 'mods\energycube', 'mods\template', 'mods\yukon')
    foreach ($file in @($modFile, $presetFile)) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
      [System.IO.File]::WriteAllText($file, 'ci mod', [System.Text.Encoding]::ASCII)
    }
    Add-Content -LiteralPath (Join-Path $root 'Empire Earth\dreXmod.config') -Value '<!-- ci -->' -Encoding Ascii
    $d3 = Copy-E2EContext $base 'update'
    $d3.ManifestAllowed = @('^Empire Earth/Data/dxm/mods/ci-mod/')
    $d3.Tasks = $ExactTasksAdmin
    $d3.RequiredComponents = @('game', 'language\update') + $ExplicitAddOns
    $d3.ForbiddenComponents = @('additional\telemetry', 'gameaoc', 'additional\movies')
    $d3.Wrapper = ''
    $components = 'game,additional\drexmod\v3,additional\discord,additional\tools\diagnostic,additional\civs\ec,language\en,language\update'
    if (Invoke-E2ESetupStep $d3 @('/ALLUSERS', '/LANG=en', "/COMPONENTS=`"$components`"", $UpdateMergeTasks)) {
      Invoke-E2EInstalledChecks $d3
      # /COMPONENTS is an explicit choice: the intro movies of the new default are not selected on top of it
      [void](Complete-E2ECheck $s 'update/DEFAULTS' @(Test-E2ELogLines -Lines $d3.LogLines -Contains @($CommandLineDefaults)) 'no component selected by default on top of /COMPONENTS')
      $problems = @()
      if (-not (Test-Path -LiteralPath $modFile -PathType Leaf)) { $problems += "$modFile (a self-made mod) is gone" }
      elseif ([System.IO.File]::ReadAllText($modFile) -cne 'ci mod') { $problems += "$modFile changed" }
      if (Test-Path -LiteralPath $presetFile) { $problems += "$presetFile still exists: the preset folder was not reset" }
      foreach ($preset in $modPresets) {
        if (-not (Test-Path -LiteralPath (Join-Path $root "Empire Earth\Data\dxm\$preset") -PathType Container)) { $problems += "Data\dxm\$preset is missing after the update" }
      }
      [void](Complete-E2ECheck $s 'update/MODS' $problems 'the self-made mod kept, the preset folders installed again without the foreign file, dreXmod.config reset (K10)')
      $installation = Get-E2ELauncherInstallation $d3
      Invoke-E2ELauncherCheck $s 'update' (New-E2ELauncherExpectation -Scenario $s -Step 'update' -Installations @($installation) -SelectedRoot $root)

      # D4 (M1): dreXmod 3 to 2 removes the folders the setup installed for dreXmod 3 and nothing else
      $d4 = Copy-E2EContext $d3 'drexmod-v2'
      $d4.RequiredComponents = @('game', 'language\update', 'additional\drexmod\v2', 'additional\discord', 'additional\tools\diagnostic', 'additional\civs\ec')
      $d4.ForbiddenComponents = @('additional\telemetry', 'gameaoc', 'additional\drexmod\v3', 'additional\movies')
      $componentsV2 = 'game,additional\drexmod\v2,additional\discord,additional\tools\diagnostic,additional\civs\ec,language\en,language\update'
      if (Invoke-E2ESetupStep $d4 @('/ALLUSERS', '/LANG=en', "/COMPONENTS=`"$componentsV2`"", $UpdateMergeTasks)) {
        Invoke-E2EInstalledChecks $d4
        [void](Complete-E2ECheck $s 'drexmod-v2/DEFAULTS' @(Test-E2ELogLines -Lines $d4.LogLines -Contains @($CommandLineDefaults)) 'no component selected by default on top of /COMPONENTS')
        $problems = @()
        foreach ($preset in $modPresets) {
          if (Test-Path -LiteralPath (Join-Path $root "Empire Earth\Data\dxm\$preset")) { $problems += "Data\dxm\$preset still exists after the change to dreXmod 2" }
        }
        if (-not (Test-Path -LiteralPath $modFile -PathType Leaf)) { $problems += "$modFile (a self-made mod) is gone" }
        elseif ([System.IO.File]::ReadAllText($modFile) -cne 'ci mod') { $problems += "$modFile changed" }
        $dll = Join-Path $root 'Empire Earth\dreXmod.dll'
        if (-not (Test-Path -LiteralPath $dll)) { $problems += 'dreXmod.dll is missing' }
        elseif ((Get-E2EFileSha1 $dll) -cne (Get-E2EMapSha1 $d4.AssetMap 'data\Add-on\DLLs\dreXmod\2_privacy\dreXmod.dll')) { $problems += 'dreXmod.dll is not the privacy build of dreXmod 2' }
        [void](Complete-E2ECheck $s 'drexmod-v2/MODS' $problems 'the preset folders of dreXmod 3 removed, the self-made mod kept, dreXmod 2 installed')

        # D5: a dgVoodoo level over the installation (ADR 0011 amendment): K10 compares the three pinned files and the
        # configuration of config\dgVoodoo with the installed ones, K5 expects the rasterizer Direct3D
        $d5 = Copy-E2EContext $d4 'dgvoodoo'
        $d5.RequiredComponents = @('game', 'language\update') + $ExplicitAddOns + @('additional\directx_wrapper', 'additional\directx_wrapper\dx11_lvl11')
        $d5.ForbiddenComponents = @('additional\telemetry', 'gameaoc', 'additional\drexmod\v2', 'additional\movies')
        $d5.Wrapper = 'additional\directx_wrapper\dx11_lvl11'
        $componentsDx = 'game,additional\drexmod\v3,additional\discord,additional\tools\diagnostic,additional\civs\ec,additional\directx_wrapper,' +
          'additional\directx_wrapper\dx11_lvl11,language\en,language\update'
        if (Invoke-E2ESetupStep $d5 @('/ALLUSERS', '/LANG=en', "/COMPONENTS=`"$componentsDx`"", $UpdateMergeTasks)) {
          Invoke-E2EInstalledChecks $d5
          [void](Complete-E2ECheck $s 'dgvoodoo/DEFAULTS' @(Test-E2ELogLines -Lines $d5.LogLines -Contains @($CommandLineDefaults)) 'no component selected by default on top of /COMPONENTS')
        }
      }
    }
  } finally {
    Remove-Item -LiteralPath $LinkFolder -Recurse -Force -ErrorAction SilentlyContinue
  }
  $u = Copy-E2EContext $base 'uninstall'
  # the self-made mod of D3 stays (the product uninstaller leaves what a player made below Data\dxm\mods)
  Invoke-E2EUninstallChecks $u @('^Empire Earth\\Data\\dxm\\mods\\ci-mod\\CREDITS$')
  Invoke-E2ELauncherUninstalled $u
  Remove-Item -LiteralPath $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# A run after the first update of scenario C: the components defaults were applied by an earlier run (log line), the movies
# are still selected although the official 1.7.2 ran in between (C3), and the components are those of C2
function Test-E2EComponentDefaultsDone([hashtable]$Ctx, [hashtable]$First) {
  $problems = @(Test-E2ELogLines -Lines $Ctx.LogLines -Contains @('Component defaults: nothing selected: already done by an earlier run (ComponentDefaults 1).'))
  $diff = Compare-E2ESets @($First.Components) @($Ctx.Components)
  if ($Ctx.Components.Count -eq 0) { $problems += 'the components of this run are not known (install.ini)' }
  elseif ($diff.Missing.Count -gt 0 -or $diff.Extra.Count -gt 0) { $problems += "components differ from those of the first update: missing $($diff.Missing -join ', '); new $($diff.Extra -join ', ')" }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'DEFAULTS') $problems 'no component selected again, the components of the first update kept')
}

# --- Scenario C: the official 1.7.2, v2 over it, and back -----------------------------------------------

$OfficialComponents = 'game,gameaoc,additional\hd\terrain,additional\hd\music,additional\hd\buildings,additional\hd\tech,additional\hd\effects,' +
  'additional\drexmod\v3,additional\rms\omega,additional\rms\neoextra,additional\discord,additional\tools\diagnostic,additional\civs\ec,' +
  'additional\civs\ec_full,language\en,language\update'

function Get-E2ERmsFiles([string]$Root, [string]$Game) {
  $folder = Join-Path (Join-Path (Join-Path $Root $E2EGames[$Game].Folder) 'Data') 'Random Map Scripts'
  return @(Get-E2EFileTree $folder | Where-Object { -not $_.IsDir } | ForEach-Object { $_.Rel })
}

# The state of an installation of the official setup 1.7.2 (CONTRACT.md 1.5: no record, no state files)
function Test-E2ELegacyState([hashtable]$Ctx) {
  $p = $Ctx.Product
  $problems = @()
  $uninstall = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath $p)
  if (-not $uninstall) { $problems += 'the uninstall key of 1.7.2 is missing' }
  else {
    if ($uninstall.ContainsKey('Empire Earth Community: ContractVersion')) { $problems += 'the uninstall key has a contract version after 1.7.2' }
    $components = Split-E2EList (Get-E2ERegString $uninstall 'Inno Setup: Selected Components')
    $tasks = Split-E2EList (Get-E2ERegString $uninstall 'Inno Setup: Selected Tasks')
    if ($components -contains 'additional\telemetry') { $problems += 'the telemetry component is selected' }
    foreach ($task in @('certinclude', 'directplay', 'dxwebsetup')) { if ($tasks -contains $task) { $problems += "the task $task is selected" } }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Ctx.Root "$($p.AppId)\EEStatsSetup.dll"))) { $problems += "$($p.AppId)\EEStatsSetup.dll of 1.7.2 missing" }
  if (@(Find-E2ECertificate $E2EConst.OfficialCertThumbprint).Count -gt 0) { $problems += 'the root certificate of the official setup was added' }
  $problems += @(Test-E2ECdKeyDummy)
  return $problems
}

function Invoke-E2EScenarioC {
  $s = 'C'
  if (-not (Initialize-E2EScenario $s)) { return }
  $root = Join-Path ${env:ProgramFiles(x86)} 'Empire Earth'
  $c1 = New-E2EContext $s 'official' 'EE' 'admin' $root @('EE', 'AoC') 'en'
  # Exact /TASKS: 1.7.2 preselects certinclude (root certificate) in the administrative mode
  $officialSwitches = @('/ALLUSERS', '/LANG=en', "/COMPONENTS=`"$OfficialComponents`"", "/TASKS=`"$ExactTasksAdmin`"")
  if (-not (Invoke-E2ESetupStep $c1 $officialSwitches -Kind 'official')) {
    $u = Copy-E2EContext $c1 'uninstall'
    if (Test-Path -LiteralPath (Join-Path $root 'unins000.exe')) { Invoke-E2EUninstallChecks $u @('.*') }
    return
  }
  Test-E2EOfficialLog $c1
  $problems = @(Test-E2ELegacyState $c1)
  $p = $c1.Product
  if (Test-Path -LiteralPath (Join-Path $root $p.SetupDataDir)) { $problems += "$($p.SetupDataDir) exists after 1.7.2" }
  foreach ($hive in @('HKLM64', 'HKLM32', 'HKCU')) { if (Test-E2ERegKey $hive $E2EConst.CommunityKey) { $problems += "$hive\$($E2EConst.CommunityKey) exists after 1.7.2" } }
  [void](Complete-E2ECheck $s 'official/LEGACY' $problems 'state of 1.7.2 as CONTRACT.md 1.5 describes it, no telemetry, no certificate')
  $uninstall = Get-E2ERegValues 'HKLM64' (Get-E2EUninstallKeyPath $p)
  $before = @{
    SetupType = Get-E2ERegString $uninstall 'Inno Setup: Setup Type'
    Components = Get-E2ERegString $uninstall 'Inno Setup: Selected Components'
    Tasks = Get-E2ERegString $uninstall 'Inno Setup: Selected Tasks'
    RmsEE = @(Get-E2ERmsFiles $root 'EE')
    RmsAoC = @(Get-E2ERmsFiles $root 'AoC')
  }
  $hkcuLayers = Get-E2ERegValues 'HKCU' $E2EConst.LayersKey
  $runAsAdmin = $hkcuLayers -and $hkcuLayers.ContainsKey((Get-E2EGameProgram $c1 'EE')) -and [string]$hkcuLayers[(Get-E2EGameProgram $c1 'EE')].Value -eq '~ RUNASADMIN'
  Add-E2EResult $s 'official/state' 'INFO' @("setup type $($before.SetupType)", "components $($before.Components)", "tasks $($before.Tasks)",
    "random maps: $($before.RmsEE.Count) (EE), $($before.RmsAoC.Count) (AoC); per-user RUNASADMIN of 1.7.2: $runAsAdmin")
  $legacy = Get-E2ELauncherInstallation $c1 @{
    kind = 'CommunityLegacy'; contractVersion = 0; sources = @('UninstallKey', 'InstalledFrom')
    integrity = [ordered]@{ quick = [ordered]@{ state = 'Unknown'; unknownReason = 'LegacySetup' } }
    defaultsStatus = (Get-E2EPerGame $c1 'Pending'); consistency = $null
  }
  Invoke-E2ELauncherCheck $s 'official' (New-E2ELauncherExpectation -Scenario $s -Step 'official' -Installations @($legacy) -SelectedRoot $root)

  # Values of the player before the update (contract 3.2 classes): P kept, D overwritten, a value
  # of the player kept, a missing P value created
  $settings = $p.SettingsKeys['EE']
  Set-E2ERegValue 'HKCU' $settings 'Music Volume' 10 'DWord'
  Set-E2ERegValue 'HKCU' $settings 'Wait for VSync' 1 'DWord'
  Set-E2ERegValue 'HKCU' $settings 'Game Bit Depth' 16 'DWord'
  Set-E2ERegValue 'HKCU' $settings 'CI Player Value' 'keep' 'String'
  Remove-E2ERegValue 'HKCU' "$settings\Game Options" 'Map Size'

  # C2: v2 over 1.7.2 (the previous folder, components and tasks)
  $c2 = Copy-E2EContext $c1 'v2-update'
  $c2.FirstInstall = $false
  $c2.ManifestExact = $false
  $c2.Tasks = $before.Tasks
  # 1.7.2 installed the intro movies only on request; the first update by a product setup of suite 1.1.0 selects them once (ComponentDefaults)
  $c2.RequiredComponents = @(Split-E2EList $before.Components) + 'additional\movies'
  $c2.Wrapper = [string](@(Split-E2EList $before.Components | Where-Object { $_ -like 'additional\directx_wrapper\*' }) | Select-Object -First 1)
  $c2.Settings = 'keep'
  $c2.SettingsKeep = @{ EE = @{ 'Music Volume' = (New-E2ERegValue 'DWord' 10); 'CI Player Value' = (New-E2ERegValue 'String' 'keep') } }
  $v2Switches = @('/ALLUSERS', '/LANG=en', $UpdateMergeTasks)
  if (Invoke-E2ESetupStep $c2 $v2Switches) {
    Invoke-E2EInstalledChecks $c2
    $diff = Compare-E2ESets (@(Split-E2EList $before.Components) + 'additional\movies') $c2.Components
    $problems = @()
    if ($diff.Missing.Count -gt 0 -or $diff.Extra.Count -gt 0) { $problems += "components changed: missing $($diff.Missing -join ', '); new $($diff.Extra -join ', ') (expected the components of 1.7.2 and additional\movies)" }
    $problems += @(Test-E2ELogLines -Lines $c2.LogLines -Contains @('Component defaults: additional\movies selected once (an installation of an older setup, setup type custom; ComponentDefaults 0 -> 1).'))
    [void](Complete-E2ECheck $s 'v2-update/COMP' $problems 'the components of 1.7.2 kept, the intro movies added once')
    $removed = @()
    if ($runAsAdmin) {
      foreach ($game in @('EE', 'AoC')) { $removed += "Removed the old per-user RUNASADMIN flag of $(Get-E2EGameProgram $c2 $game)" }
    }
    [void](Complete-E2ECheck $s 'v2-update/COMPAT' @(Test-E2ELogLines -Lines $c2.LogLines -Contains $removed `
      -NotContains @('this setup writes no compatibility values on Windows Vista/7')) 'the per-user RUNASADMIN of 1.7.2 removed (contract 3.7)')
    $rmsFolder = [regex]::Escape((Join-Path $root 'Empire Earth\Data\Random Map Scripts'))
    $rmsFolderAoC = [regex]::Escape((Join-Path $root 'Empire Earth - The Art of Conquest\Data\Random Map Scripts'))
    $problems = @(Test-E2ELogLines -Lines $c2.LogLines -Matches @(
        "^RMS: folder of an older setup moved to $rmsFolder \(backup [^)]+\)$",
        "^RMS: folder of an older setup moved to $rmsFolderAoC \(backup [^)]+\)$"))
    [void](Complete-E2ECheck $s 'v2-update/RMS' $problems 'the random map folders of 1.7.2 moved aside (randommaps.iss)')
    $notes = @(Select-E2ELogLines $c2.LogLines '^RMS: (the backup held no other files, removed|files not installed by this setup kept in .*)$')
    $kept = @(Get-ChildItem -LiteralPath (Join-Path $root 'Empire Earth - The Art of Conquest\Data') -Directory -Filter 'Random Map Scripts (backup*' -ErrorAction SilentlyContinue |
      ForEach-Object { @(Get-E2EFileTree $_.FullName | Where-Object { -not $_.IsDir }).Count })
    Add-E2EResult $s 'v2-update/RMS-backup' 'INFO' (@("files kept in the AoC backup: $($kept -join ', ')") + $notes)
    $installation = Get-E2ELauncherInstallation $c2
    Invoke-E2ELauncherCheck $s 'v2-update' (New-E2ELauncherExpectation -Scenario $s -Step 'v2-update' -Installations @($installation) -SelectedRoot $root)
  }

  # C3: the official 1.7.2 once more over v2 (TP-40 f): the uninstall key loses the contract version
  $c3 = Copy-E2EContext $c1 'official-again'
  $c3.FirstInstall = $false
  if (Invoke-E2ESetupStep $c3 @('/ALLUSERS', '/LANG=en', "/TASKS=`"$ExactTasksAdmin`"") -Kind 'official') {
    Test-E2EOfficialLog $c3
    $problems = @(Test-E2ELegacyState $c3)
    if (-not (Test-E2ERegKey 'HKLM64' "$($E2EConst.CommunityKey)\Installations\EE")) { $problems += 'the install record of v2 is gone' }
    if (-not (Test-Path -LiteralPath (Join-Path $root "$($p.SetupDataDir)\install.ini"))) { $problems += 'install.ini of v2 is gone' }
    [void](Complete-E2ECheck $s 'official-again/LEGACY' $problems 'contract version gone from the uninstall key, record and install.ini kept')
    $installation = Get-E2ELauncherInstallation $c3 @{
      kind = $null; contractVersion = $null; sources = $null; defaultsStatus = $null; consistency = $null
      integrity = [ordered]@{ quick = [ordered]@{ state = 'Unknown'; unknownReason = 'OlderSetupRanAfter'; offersRepair = $true } }
    }
    Invoke-E2ELauncherCheck $s 'official-again' (New-E2ELauncherExpectation -Scenario $s -Step 'official-again' -Installations @($installation) -SelectedRoot $root)
  }

  # C4: v2 again restores the contract version
  $c4 = Copy-E2EContext $c2 'v2-again'
  if (Invoke-E2ESetupStep $c4 $v2Switches) {
    Test-E2EK2InstallIni $c4
    Test-E2EK3UninstallKey $c4
    Test-E2EK4Manifest $c4
    Test-E2EK9CdKeys $s 'v2-again'
    Test-E2EComponentDefaultsDone $c4 $c2
    $installation = Get-E2ELauncherInstallation $c4 @{ consistency = $null; defaultsStatus = $null }
    Invoke-E2ELauncherCheck $s 'v2-again' (New-E2ELauncherExpectation -Scenario $s -Step 'v2-again' -Installations @($installation) -SelectedRoot $root)

    # C5: damage as the launcher sees it (contract 2.4, 2.5), files chosen by its own classes
    try {
      $targets = Get-E2ETamperTargets $root 'EE'
      Add-E2EResult $s 'damage/targets' 'INFO' @("code $($targets.code), data $($targets.data), mutable $($targets.mutable)")
      foreach ($rel in @($targets.data, $targets.mutable)) {
        $stream = [System.IO.File]::Open((Join-Path $root $rel.Replace('/', [System.IO.Path]::DirectorySeparatorChar)), [System.IO.FileMode]::Append)
        try { $stream.WriteByte(32) } finally { $stream.Dispose() }
      }
      $modified = Get-E2ELauncherInstallation $c4 @{ consistency = $null; defaultsStatus = $null
        integrity = [ordered]@{ quick = [ordered]@{ state = 'Ok'; findings = @() }
                                full = [ordered]@{ state = 'Modified'; findings = @([ordered]@{ path = $targets.data; kind = 'HashDiffers' }) } } }
      Invoke-E2ELauncherCheck $s 'modified' (New-E2ELauncherExpectation -Scenario $s -Step 'modified' -Installations @($modified) -SelectedRoot $root)
      Remove-Item -LiteralPath (Join-Path $root $targets.code.Replace('/', [System.IO.Path]::DirectorySeparatorChar)) -Force
      $damaged = Get-E2ELauncherInstallation $c4 @{ consistency = $null; defaultsStatus = $null
        integrity = [ordered]@{ quick = [ordered]@{ state = 'Damaged'; findings = @([ordered]@{ path = $targets.code; kind = 'Missing' }); offersRepair = $true } } }
      Invoke-E2ELauncherCheck $s 'damaged' (New-E2ELauncherExpectation -Scenario $s -Step 'damaged' -Installations @($damaged) -SelectedRoot $root)
      $program = Get-E2EGameProgram $c4 'EE'
      Rename-Item -LiteralPath $program -NewName 'Empire Earth.exe.bak'
      $missing = Get-E2ELauncherInstallation $c4 @{ state = 'Damaged'; missingPrograms = @('EE'); integrity = $null; consistency = $null; defaultsStatus = $null }
      Invoke-E2ELauncherCheck $s 'program-missing' (New-E2ELauncherExpectation -Scenario $s -Step 'program-missing' -Installations @($missing) -SelectedRoot $root)
    } catch {
      Add-E2EResult $s 'damage' 'FAIL' @("the damage steps stopped: $($_.Exception.Message)")
    }

    # C6: repair with v2
    $c6 = Copy-E2EContext $c2 'repair'
    if (Invoke-E2ESetupStep $c6 $v2Switches) {
      Test-E2EK4Manifest $c6
      Test-E2EK9CdKeys $s 'repair'
      Test-E2EK2InstallIni $c6
      Test-E2EComponentDefaultsDone $c6 $c2
      $installation = Get-E2ELauncherInstallation $c6 @{ consistency = $null; defaultsStatus = $null }
      Invoke-E2ELauncherCheck $s 'repair' (New-E2ELauncherExpectation -Scenario $s -Step 'repair' -Installations @($installation) -SelectedRoot $root)
    }
  }

  # C7: uninstallation; the random map backups moved by v2 and the renamed program may stay
  $u = Copy-E2EContext $c1 'uninstall'
  Invoke-E2EUninstallChecks $u @('\\Data\\Random Map Scripts \(backup [^\\]+\)\\', '\.bak$')
  [void](Complete-E2ECheck $s 'uninstall/CERT' @(Find-E2ECertificate $E2EConst.OfficialCertThumbprint | ForEach-Object { "certificate in $_" }) 'no certificate')
  Invoke-E2ELauncherUninstalled $u
}

