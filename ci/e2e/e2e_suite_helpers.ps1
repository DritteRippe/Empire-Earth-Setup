# Pure helpers of the end-to-end scenarios S1 to S13 of the suite installer (suite/suite.iss, ADR 0013), run by
# ci/e2e/run_e2e_suite.ps1 in the job suite-e2e of .github/workflows/build.yml with the PLACEHOLDER builds (dummy
# AppIds, stub launcher, no game data, no official download). Like e2e_helpers.ps1 nothing here touches the
# registry, the network or a process: constants, the command lines of the suite and of its child setups and the
# rules they must follow, the expected shortcuts, the checksum file of the package, the snapshot lines of the
# CD key dummy and the summary of the results. ci/e2e/tests/e2e_suite_helpers.tests.ps1 tests all of it with fake
# data, also with PowerShell 7 on Linux. Windows PowerShell 5.1 compatible (no PowerShell 7 syntax), ASCII only.
# Dot-source it after e2e_helpers.ps1: . (Join-Path $PSScriptRoot 'e2e_suite_helpers.ps1')

# --- Constants (suite/suite.iss, suite_common.iss, docs/CONTRACT.md "Suite and launcher", 1.6, 1.7) ---------

$E2ESuiteConst = @{
  # The AppIds ci/build.ps1 and suite/build_suite.ps1 use with -Placeholders
  SuiteAppId     = '00000000-0000-0000-0000-0000000005EE'
  ProductAppIds  = @{ EE = '00000000-0000-0000-0000-0000000000EE'; NeoEE = '00000000-0000-0000-0000-000000000AEE' }
  Name           = 'Empire Earth Community'
  SetupFile      = 'Empire Earth Community Setup.exe'
  SliceFilter    = 'Empire Earth Community Setup-*.bin'
  UninstallName  = 'Empire Earth Community (Launcher, EE, NeoEE)'
  RecordKey      = 'Software\Empire Earth Community\Suite'
  # The value the suite writes (DWord 1) into its own uninstall key at ssPostInstall of every run, so that the launcher
  # does not take the key (Publisher of EE) for an installation of EE: contract 0 "Suite and launcher" and 1.3, revision 5
  UninstallMarker = 'Empire Earth Community: Suite'
  RecordValues   = @('ContractVersion', 'SuiteVersion', 'InstallPath', 'Products', 'SourceDir', 'EEAppId', 'NeoEEAppId', 'Written')
  SetupMutex     = 'EmpireEarthCommunity_Suite'
  GameMutexEE    = 'StainlessSteelStudiosPresentsEmpireEarth'
  GameMutexAoC   = 'MadDocSoftwarePresentsEmpireEarthExpansion'
  LauncherMutex  = 'EmpireEarthCommunityLauncher'
  LauncherExe    = 'Empire Earth Launcher.exe'
  ModCreatorExe  = 'Mod Creator\Empire_Earth_Mod.exe'
  # Exit codes of the suite (suite_common.iss SuiteExit*)
  ExitSilentArguments = 10
  ExitSlices          = 11
  ExitZipView         = 12
  ExitDiskSpace       = 13
  ExitRunning         = 14
  ExitProductSetup    = 15
  # The code of a cancel: Abort in the installation step (the cancel of S11), not one of the prechecks
  ExitCancelled       = 3
  # .NET Framework 4.8 (Release value): without it the suite installs no launcher and no launcher shortcuts
  DotNet48Release     = 528040
  # Time limits of the programs the scenarios start (minutes): the suite with its two product setups, a run
  # that must stop at its prechecks (a hang there is a failure, spike Q3), the uninstaller of the suite (it
  # waits for each product uninstaller, up to 10 minutes each)
  SuiteTimeoutMinutes     = 25
  PrecheckTimeoutMinutes  = 5
  UninstallTimeoutMinutes = 25
  # What the scenarios pass to the product setups (/EEArgs=, /NeoEEArgs=): an exact task list, the compact
  # type, never the tasks neoee_cdkeys, certinclude, directplay, dxwebsetup; NeoEE also names neoee_cdkeys with a
  # "!" (the suite requires an explicit decision in a silent run). The values contain no blank inside an item.
  EEArgs    = '/TYPE=compact /TASKS=compatibility,compatibility_windows'
  NeoEEArgs = '/TYPE=compact /TASKS=compatibility,compatibility_windows /MERGETASKS=!neoee_cdkeys,!certinclude,!directplay,!dxwebsetup'
  # The same for a repair (S9) without /TYPE: the suite passes no type on a repair, so the products keep their
  # components (a /TYPE would replace them by the components of that type, without the choice of the GPU page)
  RepairEEArgs    = '/TASKS=compatibility,compatibility_windows'
  RepairNeoEEArgs = '/TASKS=compatibility,compatibility_windows /MERGETASKS=!neoee_cdkeys,!certinclude,!directplay,!dxwebsetup'
  Scenarios = @('S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13')
}

$E2ESuiteTitles = @{
  Prepare = 'Preparation: network block, CD key dummy, package check, clean runner'
  S1  = 'Both products: records, install.ini, manifests, suite record, launcher shortcuts, logs'
  S2  = 'EE only: NeoEE neither installed nor recorded'
  S3  = 'EE installed by its own setup: adopted in place, old shortcuts replaced'
  S4  = 'One slice missing: stop before any extraction (exit code 11)'
  S5  = 'Wrong pin of the EE setup: stop before any product setup runs (exit code 15)'
  S6  = 'Game or launcher running: refused (exit code 14)'
  S7  = 'NeoEE removed on its own, then the suite uninstaller: skipped cleanly'
  S8  = 'Suite uninstaller: products, launcher and shortcuts gone, saved games kept'
  S9  = 'Second run as a repair: roots and tasks kept, no CD key task, shortcuts restored'
  S10 = 'Zone.Identifier on the package files does not change the chain'
  S11 = 'Cancel while the first product setup runs: it is stopped before it installs anything (exit code 3)'
  S12 = 'Cancel while the second product setup runs: the suite finishes its part for the first one (exit code 0)'
  S13 = 'Cancel of a repair: the installed product stays exactly as it was (exit code 3)'
}

# The game shortcut names (contract 1.7 point 8): since suite 1.1.0 the suite creates none with the launcher, and the
# Diagnostic shortcut belongs to each of them
$E2ESuiteGames = @(
  @{ Id = 'EE';    Name = 'Empire Earth';      Diagnostic = 'Empire Earth Diagnostic' },
  @{ Id = 'NeoEE'; Name = 'Neo Empire Earth';  Diagnostic = 'Neo Empire Earth Diagnostic' }
)

# --- Command lines ------------------------------------------------------------------------------------------

# The arguments of a command line as tokens; a quoted part stays in its token with its quotes, so
# /LOG="C:\a b\c.log" and /MERGETASKS="!x,!y" are one token each
function Split-E2ECommandLine([string]$Text) {
  $tokens = @()
  if (-not $Text) { return $tokens }
  foreach ($match in [regex]::Matches($Text, '(?:[^\s"]|"[^"]*")+')) { $tokens += $match.Value }
  return $tokens
}

# The switches of a silent run of the suite. The value of /EEArgs= and /NeoEEArgs= is quoted as a whole: Setup
# removes the quotes ({param:EEArgs|}), so the product setups get the arguments with their blanks. ExtraSwitches go
# last (S11, S13: /TestCancel, which cancels the first product setup as soon as its real setup has opened its log; S12:
# /TestCancelNeoEE, which does the same for the second).
function New-E2ESuiteArguments {
  param(
    [Parameter(Mandatory = $true)][string]$LogFile,
    [Parameter(Mandatory = $true)][string]$Products,
    [string]$EEArgs = '',
    [string]$NeoEEArgs = '',
    [string]$Language = 'en',
    [string[]]$ExtraSwitches = @()
  )
  $switches = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LANG=$Language", "/LOG=`"$LogFile`"", "/PRODUCTS=$Products")
  if ($EEArgs) { $switches += "/EEArgs=`"$EEArgs`"" }
  if ($NeoEEArgs) { $switches += "/NeoEEArgs=`"$NeoEEArgs`"" }
  return @($switches + $ExtraSwitches)
}

# Problems of the switches of a run of the suite against the hard rules of the test: silent with a log, English
# (at most one run with another language per job, and none here), the products named, and for each product the
# arguments for its setup follow Test-E2ESetupArguments (an exact /TASKS list, none of the forbidden tasks, no
# telemetry); NeoEE additionally names "!neoee_cdkeys" in /MERGETASKS= (the explicit decision the suite needs)
function Get-E2ESuiteArgumentProblems([string[]]$Switches) {
  $problems = @()
  foreach ($required in @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')) {
    if ($Switches -notcontains $required) { $problems += "$required missing" }
  }
  if ($null -eq (Get-E2ESwitchValue $Switches 'LOG')) { $problems += '/LOG= missing' }
  $language = Get-E2ESwitchValue $Switches 'LANG'
  if ($language -ne 'en') { $problems += "/LANG=$language (the suite scenarios run in English)" }
  $products = Get-E2ESwitchValue $Switches 'PRODUCTS'
  if ($null -eq $products) { return @($problems + '/PRODUCTS= missing') }
  $list = @(Split-E2EList $products)
  if ($list.Count -eq 0) { $problems += '/PRODUCTS= names no product' }
  foreach ($item in $list) {
    if (@('EE', 'NeoEE') -notcontains $item) { $problems += "/PRODUCTS= names the unknown product $item" }
  }
  foreach ($id in @('EE', 'NeoEE')) {
    if ($list -notcontains $id) { continue }
    $extra = Get-E2ESwitchValue $Switches ($id + 'Args')
    if ($null -eq $extra -or $extra -eq '') { $problems += "/${id}Args= missing (an exact task list is required)"; continue }
    $child = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/LOG=x') + @(Split-E2ECommandLine $extra)
    $problems += @(Test-E2ESetupArguments $child 'v2' $id $true | ForEach-Object { "/${id}Args=: $_" })
    # the preselected tasks are never used, not even for EE (Test-E2ESetupArguments asks for the list only for NeoEE)
    if ($id -eq 'EE' -and $null -eq (Get-E2ESwitchValue $child 'TASKS')) { $problems += '/EEArgs=: an explicit /TASKS list is required (no preselected tasks)' }
    if ($id -eq 'NeoEE') {
      $merge = Get-E2ESwitchValue $child 'MERGETASKS'
      if ((Split-E2EList $merge) -notcontains '!neoee_cdkeys') { $problems += '/NeoEEArgs= needs /MERGETASKS= with !neoee_cdkeys (the explicit decision against the CD key registration)' }
    }
  }
  return $problems
}

# What a run of the suite logged for a product setup ("Product EE (step 1 of 2, state 0): <exe> <arguments>",
# suite_run.iss) as @{ Step; Steps; State; Exe; Arguments = tokens }, or $null if there is no such line
function Get-E2ESuiteChildCommand([string[]]$Lines, [string]$Product) {
  foreach ($line in $Lines) {
    $m = [regex]::Match($line, '^Product ' + [regex]::Escape($Product) + ' \(step (\d+) of (\d+), state (\d+)\): (.+?_Setup\.exe) (.*)$')
    if ($m.Success) {
      return @{ Step = [int]$m.Groups[1].Value; Steps = [int]$m.Groups[2].Value; State = [int]$m.Groups[3].Value
                Exe = $m.Groups[4].Value; Arguments = @(Split-E2ECommandLine $m.Groups[5].Value) }
    }
  }
  return $null
}

# Problems of the command line the suite gave a product setup (the tokens of Get-E2ESuiteChildCommand): the
# default parameters of contract 1.7 point 3 (the suite runs the setup with /VERYSILENT, like the rules of the
# test, so the line is checked as it is; a /SILENT would show a progress window per product), the log below the suite's
# Logs folder, the tasks the test selects, no folder (/DIR: a repair or adoption keeps the product's folder) and
# not the type full (the scenarios pass the compact type)
function Test-E2ESuiteChildArguments([string[]]$Arguments, [string]$Product) {
  $problems = @()
  foreach ($required in @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/ALLUSERS', '/NOICONS')) {
    if ($Arguments -notcontains $required) { $problems += "$required missing" }
  }
  if ($Arguments -contains '/SILENT') { $problems += '/SILENT is passed (the product setup would show a progress window of its own)' }
  if ((Get-E2ESwitchValue $Arguments 'LANG') -ne 'en') { $problems += "/LANG=$(Get-E2ESwitchValue $Arguments 'LANG'), expected en" }
  $log = Get-E2ESwitchValue $Arguments 'LOG'
  if ($null -eq $log -or $log -notlike "*\Logs\$Product-*.log") { $problems += "/LOG= is not a file below Logs\ named $Product-*.log: $log" }
  $merge = @(Split-E2EList (Get-E2ESwitchValue $Arguments 'MERGETASKS'))
  if ($merge -notcontains '!desktopicon') { $problems += '/MERGETASKS= does not name !desktopicon' }
  if ($Product -eq 'NeoEE' -and $merge -notcontains '!neoee_cdkeys') { $problems += '/MERGETASKS= does not name !neoee_cdkeys' }
  if ($null -ne (Get-E2ESwitchValue $Arguments 'DIR')) { $problems += '/DIR= is passed (the product keeps its folder)' }
  if ((Get-E2ESwitchValue $Arguments 'TYPE') -eq 'full') { $problems += '/TYPE=full is passed (the scenarios use the compact type)' }
  $problems += @(Test-E2ESetupArguments $Arguments 'v2' $Product $true)
  return $problems
}

# A path below a folder: the folder, a backslash, the name (Join-Path would reject a drive that the machine does not
# have, and these are Windows paths, also when the tests run on Linux)
function Join-E2EPath([string]$Folder, [string]$Name) { return ($Folder.TrimEnd('\', '/') + '\' + $Name) }

# --- Shortcuts (contract 1.7 point 8) -----------------------------------------------------------------------------

# The shortcuts a run leaves, as @{ Path; Target; Arguments; Present }: the one desktop shortcut "Empire Earth
# Community" (the launcher without a product); NO game shortcut (the names Empire Earth and Neo Empire Earth on the
# desktop and in the start menu folder, which suite 1.0.0 created with --product=<id> and suite 1.1.0 deletes where they
# start the launcher; the standalone setups' own shortcuts of these names are deleted by the product runner), so they
# are listed as absent; the shortcuts of the launcher, the Mod Creator and the uninstaller always; the Diagnostic
# shortcut of a product only if it is in Products and has its program (DiagnosticFor). Roots: product id -> install
# root. AppIds: product id -> AppId (the Diagnostic tool gets "{<AppId>}_is1").
function Get-E2ESuiteExpectedShortcuts {
  param(
    [string[]]$Products,
    [string]$SuiteRoot,
    [string]$Desktop,
    [string]$Group,
    [hashtable]$Roots,
    [hashtable]$AppIds,
    [string[]]$DiagnosticFor = @()
  )
  $launcher = Join-E2EPath $SuiteRoot $E2ESuiteConst.LauncherExe
  $list = @()
  $list += @{ Path = Join-E2EPath $Desktop 'Empire Earth Community.lnk'; Target = $launcher; Arguments = ''; Present = $true }
  foreach ($game in $E2ESuiteGames) {
    $present = ($Products -contains $game.Id)
    $list += @{ Path = Join-E2EPath $Desktop "$($game.Name).lnk"; Target = ''; Arguments = ''; Present = $false }
    $list += @{ Path = Join-E2EPath $Group "$($game.Name).lnk"; Target = ''; Arguments = ''; Present = $false }
    $diag = ($present -and ($DiagnosticFor -contains $game.Id))
    $target = ''
    $arguments = ''
    if ($diag) {
      $target = Join-E2EPath $Roots[$game.Id] 'Tools\Diagnostic\EE-Diagnostic.exe'
      $arguments = '{' + $AppIds[$game.Id] + '}_is1'
    }
    $list += @{ Path = Join-E2EPath $Group "$($game.Diagnostic).lnk"; Target = $target; Arguments = $arguments; Present = $diag }
  }
  $list += @{ Path = Join-E2EPath $Group 'Empire Earth Launcher.lnk'; Target = $launcher; Arguments = ''; Present = $true }
  $list += @{ Path = Join-E2EPath $Group 'Mod Creator.lnk'; Target = (Join-E2EPath $SuiteRoot $E2ESuiteConst.ModCreatorExe); Arguments = ''; Present = $true }
  $list += @{ Path = Join-E2EPath $Group 'Uninstall Empire Earth Community.lnk'; Target = (Join-E2EPath $SuiteRoot 'unins000.exe'); Arguments = ''; Present = $true }
  return $list
}

# Problems of the shortcuts: Expected from Get-E2ESuiteExpectedShortcuts, Actual path -> @{ Target; Arguments } of
# the shortcut files that exist (a path that is not a key does not exist)
function Compare-E2EShortcuts([object[]]$Expected, [hashtable]$Actual) {
  $problems = @()
  foreach ($item in $Expected) {
    $found = $Actual.ContainsKey($item.Path)
    if (-not $item.Present) {
      if ($found) { $problems += "$($item.Path) exists" }
      continue
    }
    if (-not $found) { $problems += "$($item.Path) missing"; continue }
    $link = $Actual[$item.Path]
    if ([string]$link.Target -ine $item.Target) { $problems += "$($item.Path) points to '$($link.Target)', expected '$($item.Target)'" }
    if ([string]$link.Arguments -ine $item.Arguments) { $problems += "$($item.Path) has the arguments '$($link.Arguments)', expected '$($item.Arguments)'" }
  }
  return $problems
}

# --- The package -------------------------------------------------------------------------------------------------

# The lines of SHA256SUMS.txt ("<64 hex digits>  <name>") as name -> hash; a line of another form is a problem
function ConvertFrom-E2ESumsText([string]$Text, [ref]$Problems) {
  $map = @{}
  foreach ($line in @($Text -split "`r?`n")) {
    if ($line -eq '') { continue }
    $m = [regex]::Match($line, '^([0-9a-f]{64})  (.+)$')
    if (-not $m.Success) { $Problems.Value += "SHA256SUMS.txt: a line of another form: $line"; continue }
    $map[$m.Groups[2].Value] = $m.Groups[1].Value
  }
  return $map
}

# Problems of a package folder: SHA256SUMS.txt names exactly the files Actual (name -> SHA-256) holds, with the
# hashes (BUILD-INFO.txt and SHA256SUMS.txt themselves are not listed); the program is there and at least one slice
function Test-E2ESuitePackage([string]$SumsText, [hashtable]$Actual) {
  $problems = @()
  $listed = ConvertFrom-E2ESumsText $SumsText ([ref]$problems)
  $payload = @($Actual.Keys | Where-Object { $_ -ne 'SHA256SUMS.txt' -and $_ -ne 'BUILD-INFO.txt' })
  foreach ($name in ($payload | Sort-Object)) {
    if (-not $listed.ContainsKey($name)) { $problems += "$name is not listed in SHA256SUMS.txt"; continue }
    if ([string]$Actual[$name] -cne [string]$listed[$name]) { $problems += "$name does not match SHA256SUMS.txt" }
  }
  foreach ($name in ($listed.Keys | Sort-Object)) {
    if ($payload -notcontains $name) { $problems += "$name is listed in SHA256SUMS.txt but missing" }
  }
  if ($payload -notcontains $E2ESuiteConst.SetupFile) { $problems += "$($E2ESuiteConst.SetupFile) missing" }
  if (@($payload | Where-Object { $_ -like $E2ESuiteConst.SliceFilter }).Count -eq 0) { $problems += 'no slice (.bin)' }
  return $problems
}

# The content of the alternate data stream Zone.Identifier that a browser (or Explorer extracting a ZIP) puts on a
# downloaded file: the zone of the internet
function Get-E2EZoneIdentifierText { return ("[ZoneTransfer]`r`nZoneId=3`r`n") }

# --- Suite record (contract 1.6) -----------------------------------------------------------------------------------

# The values of the suite record a run must have written, without InstallPath and SourceDir (paths are compared
# without case by the caller), SuiteVersion and Written (patterns): name -> @{ Kind; Value }
function Get-E2ESuiteRecordExpected([string]$Products, [hashtable]$AppIds) {
  return @{
    ContractVersion = New-E2ERegValue 'DWord' $E2EConst.ContractVersion
    Products        = New-E2ERegValue 'String' $Products
    EEAppId         = New-E2ERegValue 'String' $AppIds['EE']
    NeoEEAppId      = New-E2ERegValue 'String' $AppIds['NeoEE']
  }
}

# Problems of the values of the suite record (from Get-E2ERegValues, $null if the key does not exist)
function Test-E2ESuiteRecordValues($Values, [string]$Products, [string]$SuiteRoot, [string]$SourceDir, [hashtable]$AppIds) {
  $where = "HKLM64\$($E2ESuiteConst.RecordKey)"
  $problems = @(Compare-E2ERegValues -Actual $Values -Expected (Get-E2ESuiteRecordExpected $Products $AppIds) -Where $where)
  if ($null -eq $Values) { return $problems }
  $diff = Compare-E2ESets $E2ESuiteConst.RecordValues @($Values.Keys)
  if ($diff.Missing.Count -gt 0) { $problems += "$where lacks $($diff.Missing -join ', ')" }
  if ($diff.Extra.Count -gt 0) { $problems += "$where has more: $($diff.Extra -join ', ')" }
  foreach ($pair in @(@('InstallPath', $SuiteRoot), @('SourceDir', $SourceDir))) {
    $have = Get-E2ERegString $Values $pair[0]
    if ($have.TrimEnd('\') -ine $pair[1].TrimEnd('\')) { $problems += "$where value '$($pair[0])' = '$have', expected '$($pair[1])'" }
  }
  if ((Get-E2ERegString $Values 'SuiteVersion') -cnotmatch '^\d+\.\d+\.\d+$') { $problems += "$where value 'SuiteVersion' is not a version" }
  if ((Get-E2ERegString $Values 'Written') -cnotmatch '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$') { $problems += "$where value 'Written' is not a time" }
  return $problems
}

# --- CD key dummy (briefing D6): the snapshot of Software\Sierra\CDKeys ------------------------------------------

# Lines '<hive>|<value>|<kind>|<data>' of the key of one view (Values from Get-E2ERegValues, $null if the key does not
# exist, SubKeys its subkey names), '<hive>|absent' for no key. Only the dummy of the test is ever in it.
function ConvertTo-E2ECdKeysSnapshotLines([string]$Hive, $Values, [string[]]$SubKeys = @()) {
  if ($null -eq $Values) { return @("$Hive|absent") }
  $lines = @()
  foreach ($name in $Values.Keys) { $lines += "$Hive|$name|$($Values[$name].Kind)|$($Values[$name].Value)" }
  foreach ($sub in $SubKeys) { $lines += "$Hive|<subkey>|$sub" }
  $sorted = [string[]]$lines
  [Array]::Sort($sorted, [StringComparer]::Ordinal)
  return $sorted
}

# --- Summary of the results ------------------------------------------------------------------------------------------

# Markdown for the job summary and the verdict. JsonLines: the lines of results.jsonl (Add-E2EResult). A scenario
# passes if it has no FAIL line and its DONE line; a scenario without a line, or without its DONE line, failed (it
# did not run to the end). Returns @{ Markdown; Lines (one 'PASS S1 ...' or 'FAIL S1 ...' per scenario); Failed }.
function ConvertTo-E2ESuiteSummary {
  param(
    [string[]]$JsonLines,
    [string[]]$Scenarios,
    [hashtable]$Titles,
    [string]$Context = ''
  )
  $records = @()
  foreach ($line in $JsonLines) {
    if (-not $line) { continue }
    $records += ConvertFrom-Json -InputObject $line
  }
  $failed = $false
  $lines = @()
  $table = @('| Scenario | Result | PASS | FAIL | WARN | What |', '|---|---|---|---|---|---|')
  $problems = @()
  foreach ($id in $Scenarios) {
    $mine = @($records | Where-Object { $_.scenario -eq $id })
    $fails = @($mine | Where-Object { $_.status -eq 'FAIL' })
    $passes = @($mine | Where-Object { $_.status -eq 'PASS' })
    $warns = @($mine | Where-Object { $_.status -eq 'WARN' })
    $done = @($mine | Where-Object { $_.check -eq 'DONE' }).Count -gt 0
    $result = 'PASS'
    if ($mine.Count -eq 0) { $result = 'FAIL'; $problems += "- **$id** no result at all (the scenario did not run)" }
    elseif (-not $done) { $result = 'FAIL'; $problems += "- **$id** did not run to the end (no DONE line)" }
    elseif ($fails.Count -gt 0) { $result = 'FAIL' }
    elseif ($passes.Count -eq 0) { $result = 'FAIL'; $problems += "- **$id** no check passed" }
    if ($result -eq 'FAIL') { $failed = $true }
    $title = ''
    if ($Titles.ContainsKey($id)) { $title = $Titles[$id] }
    $lines += "$result $id $title"
    $table += "| $id | **$result** | $($passes.Count) | $($fails.Count) | $($warns.Count) | $($title.Replace('|', '/')) |"
    foreach ($item in $fails) {
      $detail = ''
      if (@($item.details).Count -gt 0) { $detail = ' - ' + ((@($item.details) | Select-Object -First 3) -join ' / ') }
      $problems += "- **$id** ``$($item.check)``$($detail.Replace('|', '/'))"
    }
  }
  $md = @('## Suite installer end-to-end test (placeholder products)', '')
  if ($Context) { $md += $Context; $md += '' }
  $verdict = 'PASSED'
  if ($failed) { $verdict = 'FAILED' }
  $md += "**$verdict**: " + (@($lines | Where-Object { $_ -like 'PASS *' }).Count) + ' of ' + @($Scenarios).Count + ' scenarios passed.'
  $md += ''
  $md += $table
  if ($problems.Count -gt 0) { $md += ''; $md += '### Failed checks'; $md += ''; $md += $problems }
  $notes = @($records | Where-Object { $_.status -eq 'WARN' })
  if ($notes.Count -gt 0) {
    $md += ''; $md += '### Warnings'; $md += ''
    foreach ($item in ($notes | Select-Object -First 20)) {
      $detail = ''
      if (@($item.details).Count -gt 0) { $detail = ' - ' + ((@($item.details) | Select-Object -First 2) -join ' / ') }
      $md += "- $($item.scenario) ``$($item.check)``$($detail.Replace('|', '/'))"
    }
  }
  return @{ Markdown = ($md -join "`n") + "`n"; Lines = $lines; Failed = $failed }
}
