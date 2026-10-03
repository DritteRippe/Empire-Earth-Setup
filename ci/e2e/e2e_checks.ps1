# Check blocks of the real-data end-to-end test, one per part of the contract (docs/CONTRACT.md) and
# of the setup's behaviour; the ids K1 ... K15, DL and U are those of the catalog in README.md
# ("End-to-end test on Windows") and docs/TEST-PLAN.de.md (section 12). Each block reads the
# machine through e2e_windows.ps1, applies the rules of e2e_helpers.ps1 and records one result.
# A context hashtable describes the installation the block checks:
#   Scenario, Step     names of the result (check id '<Step>/<block>')
#   Product            Get-E2EProduct
#   Mode               admin | user
#   Root               install root, no trailing '\'
#   Games              EE, or EE and AoC
#   Language           game language (de, en)
#   Tasks              exact expected task list, or $null
#   Required/ForbiddenComponents, Wrapper (component or ''), Components (set by K2)
#   FirstInstall       a first installation (else an update or repair)
#   ManifestExact      every file below the root is in the manifest (else: manifest within the tree)
#   Settings           fresh | keep (game settings of a first installation, or an update over values
#                      the player changed: SettingsKeep lists the names whose value must stay)
#   LogLines           the setup log without time stamps
#   SetupBuild, PinCount, AssetMap
# Windows PowerShell 5.1 compatible, ASCII only. Dot-source after e2e_helpers.ps1 and e2e_windows.ps1.

function Get-E2EHive([hashtable]$Ctx) {
  if ($Ctx.Mode -eq 'admin') { return 'HKLM64' }
  return 'HKCU'
}

function Get-E2ECheckId([hashtable]$Ctx, [string]$Block) { return "$($Ctx.Step)/$Block" }

function Get-E2EGameProgram([hashtable]$Ctx, [string]$Game) {
  return (Join-Path (Join-Path $Ctx.Root $E2EGames[$Game].Folder) $E2EGames[$Game].Exe)
}

# K1: install record (contract 1.1)
function Test-E2EK1InstallRecord([hashtable]$Ctx) {
  $p = $Ctx.Product
  $hive = Get-E2EHive $Ctx
  $key = "$($E2EConst.CommunityKey)\Installations\$($p.Id)"
  $expected = @{
    ContractVersion = New-E2ERegValue 'DWord' $E2EConst.ContractVersion
    InstallPath     = New-E2ERegValue 'String' $Ctx.Root
    InstallMode     = New-E2ERegValue 'String' $Ctx.Mode
    AppId           = New-E2ERegValue 'String' $p.AppId
    GameVersion     = New-E2ERegValue 'String' $p.GameVersion
    SetupVersion    = New-E2ERegValue 'String' $E2EConst.SetupVersion
  }
  if ($Ctx.SetupBuild) { $expected['SetupBuild'] = New-E2ERegValue 'String' $Ctx.SetupBuild }
  $problems = @(Compare-E2ERegValues -Actual (Get-E2ERegValues $hive $key) -Expected $expected -Where "$hive\$key" -Exact)
  if ($Ctx.Mode -eq 'admin') {
    if (Test-E2ERegKey 'HKLM32' $E2EConst.CommunityKey) { $problems += "HKLM32\$($E2EConst.CommunityKey) exists (the record belongs to the 64-bit view)" }
    if (Test-E2ERegKey 'HKCU' $key) { $problems += "HKCU\$key exists in the administrative install mode" }
  } else {
    if (Test-E2ERegKey 'HKLM64' $key) { $problems += "HKLM64\$key exists in the user install mode" }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K1') $problems "$hive\$key")
}

# K2: install.ini and the setup data folder (contract 1.2); the component and task rules
function Test-E2EK2InstallIni([hashtable]$Ctx) {
  $p = $Ctx.Product
  $problems = @()
  $dataDir = Join-Path $Ctx.Root $p.SetupDataDir
  $ini = Join-Path $dataDir 'install.ini'
  $Ctx.Components = @()
  if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) {
    [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K2') @("$ini does not exist"))
    return
  }
  $expected = @{ ContractVersion = $E2EConst.ContractVersion; Product = $p.Id; AppId = $p.AppId; InstallMode = $Ctx.Mode
                 GameVersion = $p.GameVersion; SetupVersion = $E2EConst.SetupVersion; SetupBuild = $Ctx.SetupBuild }
  $result = Test-E2EInstallIniBytes ([System.IO.File]::ReadAllBytes($ini)) $expected
  $problems += $result.Problems
  $attributes = (Get-Item -LiteralPath $dataDir -Force).Attributes
  if (($attributes -band [System.IO.FileAttributes]::Hidden) -eq 0) { $problems += "$dataDir is not hidden" }
  $names = @(Get-ChildItem -LiteralPath $dataDir -Force | ForEach-Object { $_.Name })
  $want = @('EEStatsSetup.dll', 'files.sha256', 'install.ini', 'rms-EE.txt')
  if ($Ctx.Games -contains 'AoC') { $want += 'rms-AoC.txt' }
  $diff = Compare-E2ESets $want $names
  if ($diff.Missing.Count -gt 0) { $problems += "setup data folder lacks $($diff.Missing -join ', ')" }
  if ($diff.Extra.Count -gt 0) { $problems += "setup data folder has more: $($diff.Extra -join ', ')" }

  $components = Split-E2EList ([string]$result.Values['Components'])
  $tasks = [string]$result.Values['Tasks']
  $Ctx.Components = $components
  $problems += @(Test-E2EComponents $components $Ctx.Language $Ctx.Wrapper $Ctx.RequiredComponents $Ctx.ForbiddenComponents)
  if ($null -ne $Ctx.Tasks -and $tasks -cne $Ctx.Tasks) { $problems += "Tasks=$tasks, expected $($Ctx.Tasks)" }
  foreach ($task in (Split-E2EList $tasks)) {
    if (@('neoee_cdkeys', 'certinclude', 'directplay', 'dxwebsetup') -contains $task) { $problems += "the task $task is selected" }
  }
  $uninstall = Get-E2ERegValues (Get-E2EHive $Ctx) (Get-E2EUninstallKeyPath $p)
  if ($uninstall) {
    foreach ($pair in @(@('Components', 'Inno Setup: Selected Components'), @('Tasks', 'Inno Setup: Selected Tasks'))) {
      $iniValue = [string]$result.Values[$pair[0]]
      $regValue = ''
      if ($uninstall.ContainsKey($pair[1])) { $regValue = [string]$uninstall[$pair[1]].Value }
      if ($iniValue -cne $regValue) { $problems += "install.ini $($pair[0]) differs from '$($pair[1])' of the uninstall key" }
    }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K2') $problems "Components=$($components -join ','); Tasks=$tasks")
}

# K3: uninstall key (contract 1.3)
function Test-E2EK3UninstallKey([hashtable]$Ctx) {
  $p = $Ctx.Product
  $hive = Get-E2EHive $Ctx
  $key = Get-E2EUninstallKeyPath $p
  $expected = @{
    'Inno Setup: App Path' = New-E2ERegValue 'String' $Ctx.Root
    'InstallLocation'      = New-E2ERegValue 'String' ($Ctx.Root + '\')
    'Publisher'            = New-E2ERegValue 'String' $p.Publisher
    'DisplayName'          = New-E2ERegValue 'String' "$($p.AppName) v$($p.GameVersion) - Setup v$($E2EConst.SetupVersion)"
    'DisplayVersion'       = New-E2ERegValue 'String' $p.GameVersion
    'UninstallString'      = New-E2ERegValue 'String' ('"' + $Ctx.Root + '\unins000.exe"')
    'Empire Earth Community: ContractVersion' = New-E2ERegValue 'DWord' $E2EConst.ContractVersion
  }
  $problems = @(Compare-E2ERegValues -Actual (Get-E2ERegValues $hive $key) -Expected $expected -Where "$hive\$key")
  foreach ($other in @('HKLM64', 'HKLM32', 'HKCU')) {
    if ($other -ne $hive -and (Test-E2ERegKey $other $key)) { $problems += "$other\$key exists too" }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K3') $problems "$hive\$key")
}

# K4: integrity manifest (contract 2.1 to 2.5): format, every line hashed again, the file tree
function Test-E2EK4Manifest([hashtable]$Ctx) {
  $p = $Ctx.Product
  $problems = @()
  $file = Join-Path (Join-Path $Ctx.Root $p.SetupDataDir) 'files.sha256'
  $Ctx.Manifest = @{}
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K4') @("$file does not exist"))
    return
  }
  $parsed = Test-E2EManifestBytes ([System.IO.File]::ReadAllBytes($file)) $p.SetupDataDir
  $problems += $parsed.Problems
  $mismatch = @()
  foreach ($entry in $parsed.Entries) {
    $Ctx.Manifest[$entry.Path] = $entry.Hash
    $full = Join-Path $Ctx.Root ($entry.Path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $mismatch += "missing: $($entry.Path)"; continue }
    if ((Get-E2EFileSha256 $full) -cne $entry.Hash) { $mismatch += "hash differs: $($entry.Path)" }
  }
  if ($mismatch.Count -gt 0) { $problems += "$($mismatch.Count) manifest line(s) do not match the file: $(($mismatch | Select-Object -First 5) -join '; ')" }
  $tree = @(Get-E2EFileTree $Ctx.Root | Where-Object { -not $_.IsDir } | ForEach-Object { $_.Rel.Replace([System.IO.Path]::DirectorySeparatorChar, '/') } |
    Where-Object { $_ -notlike "$($p.SetupDataDir)/*" -and $_ -ne 'unins000.exe' -and $_ -ne 'unins000.dat' })
  $diff = Compare-E2ESets @($parsed.Entries | ForEach-Object { $_.Path }) $tree
  if ($diff.Missing.Count -gt 0) { $problems += "in the manifest but not below the root: $(($diff.Missing | Select-Object -First 5) -join ', ')" }
  if ($Ctx.ManifestExact -and $diff.Extra.Count -gt 0) {
    $problems += "$($diff.Extra.Count) file(s) below the root not in the manifest: $(($diff.Extra | Select-Object -First 5) -join ', ')"
  }
  $wrote = @(Select-E2ELogLines $Ctx.LogLines ('^Wrote ' + [regex]::Escape($file) + ' \((\d+) files, 0 missing\)$'))
  if ($wrote.Count -ne 1) { $problems += "log line 'Wrote $file (<n> files, 0 missing)' missing" }
  elseif ($wrote[0] -match '\((\d+) files' -and [int]$Matches[1] -ne $parsed.Entries.Count) {
    $problems += "the log names $($Matches[1]) files, the manifest has $($parsed.Entries.Count)"
  }
  $ok = "$($parsed.Entries.Count) files hashed again"
  if (-not $Ctx.ManifestExact -and $diff.Extra.Count -gt 0) { $ok += "; $($diff.Extra.Count) other file(s) below the root (expected after an older setup)" }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K4') $problems $ok)
  if (-not $Ctx.ManifestExact -and $diff.Extra.Count -gt 0) {
    Add-E2EResult $Ctx.Scenario (Get-E2ECheckId $Ctx 'K4-rest') 'INFO' @("files outside the manifest: $(($diff.Extra | Select-Object -First 10) -join ', ')")
  }
}

# K5: game settings (contract 3.1 to 3.3)
function Test-E2EK5GameSettings([hashtable]$Ctx) {
  $p = $Ctx.Product
  $problems = @()
  $screen = Get-E2EScreen $Ctx.LogLines
  if (-not $screen) {
    [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K5') @('no Screen: line in the log'))
    return
  }
  if ($screen.WindowWidth -ne (Get-E2EClamped $screen.Width 1024 1920) -or $screen.WindowHeight -ne (Get-E2EClamped $screen.Height 768 1080)) {
    $problems += "game window $($screen.WindowWidth) x $($screen.WindowHeight) is not the clamped screen $($screen.Width) x $($screen.Height)"
  }
  $wrapper = (@($Ctx.Components | Where-Object { $_ -like 'additional\directx_wrapper\*' }).Count -gt 0)
  foreach ($game in @('EE', 'AoC')) {
    $key = $p.SettingsKeys[$game]
    if ($Ctx.Games -notcontains $game) {
      if (Test-E2ERegKey 'HKCU' $key) { $problems += "HKCU\$key exists, but $game is not installed" }
      continue
    }
    $expected = Get-E2EGameSettingsExpected $Ctx.Root $E2EGames[$game].Folder $wrapper $screen.WindowWidth $screen.WindowHeight $E2EGames[$game].EndingEpoch
    $main = $expected.Main
    $options = $expected.Options
    $exact = $true
    if ($Ctx.Settings -eq 'keep' -and $Ctx.SettingsKeep.ContainsKey($game)) {
      $exact = $false
      foreach ($name in $Ctx.SettingsKeep[$game].Keys) {
        $value = $Ctx.SettingsKeep[$game][$name]
        if ($name -like 'Game Options\*') { $options[$name.Substring(13)] = $value } else { $main[$name] = $value }
      }
    }
    if ($exact) {
      $problems += @(Compare-E2ERegValues -Actual (Get-E2ERegValues 'HKCU' $key) -Expected $main -Where "HKCU\$key" -Exact)
      $problems += @(Compare-E2ERegValues -Actual (Get-E2ERegValues 'HKCU' "$key\Game Options") -Expected $options -Where "HKCU\$key\Game Options" -Exact)
    } else {
      $problems += @(Compare-E2ERegValues -Actual (Get-E2ERegValues 'HKCU' $key) -Expected $main -Where "HKCU\$key")
      $problems += @(Compare-E2ERegValues -Actual (Get-E2ERegValues 'HKCU' "$key\Game Options") -Expected $options -Where "HKCU\$key\Game Options")
    }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K5') $problems "screen $($screen.Width) x $($screen.Height), game window $($screen.WindowWidth) x $($screen.WindowHeight)")
}

# K6: GPU preference (contract 3.4; the runner is Windows 10 or later, task compatibility_windows)
function Test-E2EK6GpuPreference([hashtable]$Ctx) {
  $values = Get-E2ERegValues 'HKCU' $E2EConst.GpuKey
  if ($null -eq $values) { $values = @{} }
  $problems = @()
  foreach ($game in @('EE', 'AoC')) {
    $name = Get-E2EGameProgram $Ctx $game
    if ($Ctx.Games -contains $game) {
      if (-not $values.ContainsKey($name)) { $problems += "GPU preference of $name missing" }
      elseif ($values[$name].Kind -ne 'String' -or [string]$values[$name].Value -cne 'GpuPreference=2;') { $problems += "GPU preference of $name is '$($values[$name].Value)'" }
    } elseif ($values.ContainsKey($name)) {
      $problems += "GPU preference of $name exists, but $game is not installed"
    }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K6') $problems)
}

# K7: defaults marker (contract 3.5)
function Test-E2EK7Marker([hashtable]$Ctx) {
  $key = "$($E2EConst.CommunityKey)\GameDefaults\$($Ctx.Product.Id)"
  $expected = @{}
  foreach ($game in $Ctx.Games) { $expected[$game] = New-E2ERegValue 'DWord' $E2EConst.ContractVersion }
  $problems = @(Compare-E2ERegValues -Actual (Get-E2ERegValues 'HKCU' $key) -Expected $expected -Where "HKCU\$key" -Exact)
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K7') $problems)
}

# K8: compatibility values (contract 3.7, Windows 8 and later): HKLM 64-bit view in the
# administrative install mode, HKCU in the user mode, never RUNASADMIN or WINXPSP3
function Test-E2EK8Compat([hashtable]$Ctx) {
  $problems = @()
  $hive = 'HKCU'
  $other = 'HKLM64'
  if ($Ctx.Mode -eq 'admin') { $hive = 'HKLM64'; $other = 'HKCU' }
  $values = Get-E2ERegValues $hive $E2EConst.LayersKey
  if ($null -eq $values) { $values = @{} }
  $otherValues = Get-E2ERegValues $other $E2EConst.LayersKey
  if ($null -eq $otherValues) { $otherValues = @{} }
  foreach ($game in @('EE', 'AoC')) {
    $name = Get-E2EGameProgram $Ctx $game
    if ($Ctx.Games -contains $game) {
      if (-not $values.ContainsKey($name)) { $problems += "$hive compatibility value of $name missing" }
      elseif ([string]$values[$name].Value -cne $E2EConst.CompatValue) { $problems += "$hive compatibility value of $name is '$($values[$name].Value)'" }
    } elseif ($values.ContainsKey($name)) {
      $problems += "$hive compatibility value of $name exists, but $game is not installed"
    }
    if ($otherValues.ContainsKey($name)) { $problems += "$other has a compatibility value of $name ('$($otherValues[$name].Value)')" }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K8') $problems)
}

# K9: the CD key dummy is intact in every view (contract 3.8)
function Test-E2EK9CdKeys([string]$Scenario, [string]$Step) {
  [void](Complete-E2ECheck $Scenario "$Step/K9" @(Test-E2ECdKeyDummy) 'intact in HKCU, HKLM64, HKLM32')
}

# K10: installed files and privacy: no EEStats.dll (no telemetry), the privacy dreXmod.config, the
# DirectX wrapper of the selection, the NeoEE files of the install mode, no _wonkver.pub, no old
# setup data folder <AppId>
function Test-E2EK10Files([hashtable]$Ctx) {
  $p = $Ctx.Product
  $map = $Ctx.AssetMap
  $problems = @()
  foreach ($game in $Ctx.Games) {
    $folderName = $E2EGames[$game].Folder
    $folder = Join-Path $Ctx.Root $folderName
    $exe = Join-Path $folder $E2EGames[$game].Exe
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { $problems += "$exe missing" }
    if (Test-Path -LiteralPath (Join-Path $folder 'EEStats.dll')) { $problems += "$folderName\EEStats.dll exists (telemetry)" }
    if ($Ctx.Components -contains 'additional\drexmod\v3') {
      $config = Join-Path $folder 'dreXmod.config'
      $want = Get-E2EMapSha1 $map 'data\Add-on\DLLs\dreXmod\3_privacy\dreXmod.config'
      if (-not (Test-Path -LiteralPath $config)) { $problems += "$folderName\dreXmod.config missing" }
      elseif ((Get-E2EFileSha1 $config) -cne $want) { $problems += "$folderName\dreXmod.config is not the privacy configuration" }
    }
    $ddraw = Join-Path $folder 'DDraw.dll'
    if ($Ctx.Components -contains 'additional\directx_wrapper\dx9') {
      if (-not (Test-Path -LiteralPath $ddraw)) { $problems += "$folderName\DDraw.dll missing (wrapper dx9)" }
      elseif ((Get-E2EFileSha1 $ddraw) -cne (Get-E2EMapSha1 $map 'data\Add-on\DirectX_Wrapper\GOG\DDraw.dll')) { $problems += "$folderName\DDraw.dll is not the dx9 wrapper" }
    } elseif (@($Ctx.Components | Where-Object { $_ -like 'additional\directx_wrapper\*' }).Count -eq 0 -and (Test-Path -LiteralPath $ddraw)) {
      $problems += "$folderName\DDraw.dll exists without a wrapper"
    }
    if ($p.Id -eq 'NeoEE') {
      if (-not (Test-Path -LiteralPath (Join-Path $folder 'neoee.dll'))) { $problems += "$folderName\neoee.dll missing" }
      if (Test-Path -LiteralPath (Join-Path $folder '_wonkver.pub')) { $problems += "$folderName\_wonkver.pub exists (deleteafterinstall)" }
      $cfg = Join-Path $folder 'NeoEE.cfg'
      if (-not (Test-Path -LiteralPath $cfg) -or (Get-E2EFileSha1 $cfg) -cne (Get-E2EMapSha1 $map 'data\NeoEE Base\shared\NeoEE.cfg')) { $problems += "$folderName\NeoEE.cfg is not the Windows version" }
      $variant = 'NeoEE - User'
      if ($Ctx.Mode -eq 'admin') { $variant = 'NeoEE - Admin' }
      $want = Get-E2EMapSha1 $map "data\$variant\$folderName\$($E2EGames[$game].Exe)"
      if ((Test-Path -LiteralPath $exe) -and (Get-E2EFileSha1 $exe) -cne $want) { $problems += "$folderName\$($E2EGames[$game].Exe) is not the program of $variant" }
    }
  }
  if (Test-Path -LiteralPath (Join-Path $Ctx.Root $p.AppId)) { $problems += "the old setup data folder $($p.AppId) exists" }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K10') $problems)
}

# K11: firewall rules (task firewallexception, administrative install mode only): four allow rules
# per program, none in the user mode
function Test-E2EK11Firewall([hashtable]$Ctx) {
  $problems = @()
  $p = $Ctx.Product
  $withRules = ($Ctx.Mode -eq 'admin') -and ((Split-E2EList $Ctx.Tasks) -contains 'firewallexception')
  foreach ($game in @('EE', 'AoC')) {
    $program = Get-E2EGameProgram $Ctx $game
    $rules = @(Get-E2EFirewallRules $program)
    if (-not $withRules -or $Ctx.Games -notcontains $game) {
      if ($rules.Count -gt 0) { $problems += "$($rules.Count) firewall rule(s) for $program, expected none" }
      continue
    }
    $prefix = $p.AppName
    if ($game -eq 'AoC') { $prefix = "$($p.AppName) - AoC" }
    $names = @('TCP - Out', 'TCP - In', 'UDP - Out', 'UDP - In' | ForEach-Object { "$prefix - $_" })
    $diff = Compare-E2ESets $names @($rules | ForEach-Object { $_.Name })
    if ($rules.Count -ne 4 -or $diff.Missing.Count -gt 0 -or $diff.Extra.Count -gt 0) {
      $problems += "firewall rules of ${program}: [$(@($rules | ForEach-Object { $_.Name }) -join ', ')], expected the four of $prefix"
    }
    foreach ($rule in $rules) {
      $direction = 'Inbound'
      if ($rule.Name -like '* - Out') { $direction = 'Outbound' }
      $protocol = 'TCP'
      if ($rule.Name -like '* - UDP - *') { $protocol = 'UDP' }
      if ($rule.Action -ne 'Allow' -or $rule.Enabled -ne 'True' -or $rule.Profile -ne 'Any' -or $rule.Direction -ne $direction -or
          $rule.Protocol -ne $protocol -or $rule.LocalPort -ne 'Any') {
        $problems += "firewall rule '$($rule.Name)': $($rule.Action), enabled $($rule.Enabled), profile $($rule.Profile), $($rule.Direction), $($rule.Protocol), local port $($rule.LocalPort)"
      }
    }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K11') $problems)
}

# K12: shortcuts in the start menu group "Empire Earth" and on the desktop (task desktopicon)
function Test-E2EK12Shortcuts([hashtable]$Ctx) {
  $p = $Ctx.Product
  $problems = @()
  if ($Ctx.Mode -eq 'admin') {
    $group = Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth'
    $desktop = (Get-E2EKnownFolder 'CommonDesktopDirectory')
  } else {
    $group = Join-Path (Get-E2EKnownFolder 'Programs') 'Empire Earth'
    $desktop = (Get-E2EKnownFolder 'DesktopDirectory')
  }
  $expected = @(
    @{ Path = Join-Path $group "$($p.AppName).lnk"; Target = Get-E2EGameProgram $Ctx 'EE'; Present = $true },
    @{ Path = Join-Path $group "$($p.AppName) - AoC.lnk"; Target = Get-E2EGameProgram $Ctx 'AoC'; Present = ($Ctx.Games -contains 'AoC') },
    @{ Path = Join-Path $desktop "$($p.AppName).lnk"; Target = Get-E2EGameProgram $Ctx 'EE'; Present = $true },
    @{ Path = Join-Path $desktop "$($p.AppName) - AoC.lnk"; Target = Get-E2EGameProgram $Ctx 'AoC'; Present = ($Ctx.Games -contains 'AoC') }
  )
  if ($Ctx.Components -contains 'additional\tools\diagnostic') {
    $expected += @{ Path = Join-Path $group "$($p.AppName) Diagnostic.lnk"; Target = Join-Path $Ctx.Root 'Tools\Diagnostic\EE-Diagnostic.exe'
                    Present = $true; Arguments = "{$($p.AppId)}_is1" }
  }
  foreach ($item in $expected) {
    $link = Get-E2EShortcut $item.Path
    if (-not $item.Present) {
      if ($link) { $problems += "$($item.Path) exists" }
      continue
    }
    if (-not $link) { $problems += "$($item.Path) missing"; continue }
    if ($link.Target -ine $item.Target) { $problems += "$($item.Path) points to $($link.Target)" }
    if ($item.ContainsKey('Arguments') -and $link.Arguments -ine $item.Arguments) { $problems += "$($item.Path) has the arguments '$($link.Arguments)'" }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K12') $problems)
}

# K13: write permissions (administrative install mode without everyoneadminstart): Authenticated
# Users may modify Data, Users and the configuration files, never the programs and libraries
# (only the explicit rules of the setup count: an install root outside Program Files inherits
# the rules of its drive)
function Test-E2EK13Permissions([hashtable]$Ctx) {
  $problems = @()
  $authenticated = 'S-1-5-11'
  $users = 'S-1-5-32-545'
  $modify = 0x301BF
  $writeBits = 0x2 -bor 0x4 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x40000000 -bor 0x10000000
  foreach ($game in $Ctx.Games) {
    $folder = Join-Path $Ctx.Root $E2EGames[$game].Folder
    foreach ($path in @((Join-Path $folder 'Data'), (Join-Path $folder 'Users'), (Join-Path $folder 'WONLobby.cfg'))) {
      if (-not (Test-Path -LiteralPath $path)) { $problems += "$path missing"; continue }
      $explicit = @(Get-E2EAccessRules $path | Where-Object { -not $_.Inherited -and $_.Allow -and $_.Sid -eq $authenticated -and (($_.Rights -band $modify) -eq $modify) })
      if ($Ctx.Mode -eq 'admin' -and $explicit.Count -eq 0) { $problems += "$path has no explicit Modify rule for Authenticated Users" }
      if ($Ctx.Mode -ne 'admin' -and $explicit.Count -gt 0) { $problems += "$path has an explicit Modify rule for Authenticated Users in the user mode" }
    }
    $code = @(Get-ChildItem -LiteralPath $folder -File -Force | Where-Object { $_.Extension -ieq '.exe' -or $_.Extension -ieq '.dll' })
    foreach ($file in $code) {
      $writable = @(Get-E2EAccessRules $file.FullName | Where-Object { -not $_.Inherited -and $_.Allow -and ($_.Sid -eq $authenticated -or $_.Sid -eq $users) -and (($_.Rights -band $writeBits) -ne 0) })
      if ($writable.Count -gt 0) { $problems += "$($file.FullName) is writable for $($writable[0].Sid)" }
    }
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K13') $problems)
}

# The log rules of a v2 run (K14, K15) for the context
function Get-E2ELogRules([hashtable]$Ctx) {
  $p = $Ctx.Product
  $dataDir = Join-Path $Ctx.Root $p.SetupDataDir
  $rules = @{
    Contains = @(
      "$($p.AppName) $($p.GameVersion), setup $($E2EConst.SetupVersion) ($($p.Id), Regular), SetupBuild `"$($Ctx.SetupBuild)`", TestID 0, contract version $($E2EConst.ContractVersion)",
      'Update check skipped because using silent mode',
      "Registered languages: $($E2EConst.RegisteredLanguages)",
      "Online files: $($Ctx.PinCount) SHA-256 hashes known",
      "Install state of the previous run deleted (or there was none): $dataDir\install.ini, $dataDir\files.sha256",
      "Wrote $dataDir\install.ini (contract version $($E2EConst.ContractVersion), install mode $($Ctx.Mode))",
      "Wrote `"Empire Earth Community: ContractVersion`" = $($E2EConst.ContractVersion) into the uninstall key",
      'Installation process succeeded.'
    )
    Matches = @(
      '^Screen: -?\d+ x -?\d+ pixels ',
      '^(Unknown|NVIDIA|AMD|Intel) GPU detected$',
      '^Checking \d+ recorded destinations of installed files for ',
      '^Manifest: \d+ files, '
    )
    NotContains = @('Exception', 'Runtime error', 'PrepareToInstall failed', 'Sending setup stats over HTTPS!', 'api.empireearth.eu',
                    'dxwebsetup.exe', 'dism.exe', 'certutil', 'Register NeoEE CD Keys', 'CD Keys', 'No manifest in this run',
                    'Not writing ', 'Installed file missing', 'Online file rejected', 'Online file refused')
    NotMatches = @()
  }
  if ($Ctx.FirstInstall) {
    $rules.Contains += @("Checking the chosen folder $($Ctx.Root)", "Creating new uninstall log: $($Ctx.Root)\unins000.dat")
    $rules.Matches += @('^Using \S+ GPU settings: ', '^Checked \d+ uninstall entries of HKLM in \d+ ms$')
  } else {
    $rules.Contains += @("Will append to existing uninstall log: $($Ctx.Root)\unins000.dat")
    $rules.NotMatches += @('^Using \S+ GPU settings: ')
  }
  if ($Ctx.Mode -eq 'admin') {
    $rules.Matches += @('^Link check: \d+ folders and \d+ files below Data and Users of ' + [regex]::Escape($Ctx.Root) +
      ' examined in \d+ ms, 0 links or unreadable folders or files found, \d+ files with a reparse point \(allowed\)$')
  } else {
    $rules.Contains += @('Link check skipped: not the administrative install mode')
  }
  return $rules
}

# K14: the setup log of a v2 run; K15: no network without downloads (English)
function Test-E2EK14Log([hashtable]$Ctx) {
  $rules = Get-E2ELogRules $Ctx
  $problems = @(Test-E2ELogLines -Lines $Ctx.LogLines -Contains $rules.Contains -Matches $rules.Matches -NotContains $rules.NotContains -NotMatches $rules.NotMatches)
  if ($Ctx.FirstInstall) {
    $gpu = Get-E2EGpuChoice $Ctx.LogLines
    $problems += $gpu.Problems
    if ($gpu.Vendor -and -not (Select-E2ELogLines $Ctx.LogLines ('^Using ' + [regex]::Escape($gpu.LogName) + ' GPU settings: ' + [regex]::Escape($gpu.Wrapper) + '$'))) {
      $problems += "no line 'Using $($gpu.LogName) GPU settings: $($gpu.Wrapper)' for the detected vendor $($gpu.Vendor)"
    }
  }
  $listed = @(Select-E2ELogLines $Ctx.LogLines '^RMS: \d+ installed file\(s\) listed for the next update$').Count
  if ($listed -ne @($Ctx.Games).Count) { $problems += "$listed RMS list line(s), expected $(@($Ctx.Games).Count)" }
  if (-not (Select-E2ELogLines $Ctx.LogLines '^Setup stats not sent \(no consent\)$')) {
    Add-E2EResult $Ctx.Scenario (Get-E2ECheckId $Ctx 'K14-stats') 'INFO' @("no line 'Setup stats not sent (no consent)': the finished page is not processed in silent mode (nothing was sent: see K14)")
  }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K14') $problems "$(@($Ctx.LogLines).Count) log lines")
  if ($Ctx.Language -eq 'en') {
    $net = @(Test-E2ELogLines -Lines $Ctx.LogLines -Contains @('English language selected, no need to download online files.') `
      -NotMatches @('^HTTP (GET|HEAD) ') -NotContains @('Downloading temporary file'))
    [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'K15') $net 'no HTTP request')
  }
}

# Every check of an installed v2 product (K1 to K15); K2 first, it reads the components
function Invoke-E2EInstalledChecks([hashtable]$Ctx) {
  Test-E2EK2InstallIni $Ctx
  Test-E2EK1InstallRecord $Ctx
  Test-E2EK3UninstallKey $Ctx
  Test-E2EK4Manifest $Ctx
  Test-E2EK5GameSettings $Ctx
  Test-E2EK6GpuPreference $Ctx
  Test-E2EK7Marker $Ctx
  Test-E2EK8Compat $Ctx
  Test-E2EK9CdKeys $Ctx.Scenario $Ctx.Step
  Test-E2EK10Files $Ctx
  Test-E2EK11Firewall $Ctx
  Test-E2EK12Shortcuts $Ctx
  Test-E2EK13Permissions $Ctx
  Test-E2EK14Log $Ctx
}

# DL: the downloads of scenario A (German, from the mirror; downloads.iss). MirrorOk is the result
# of the HEAD pre-check (TP-00): without the mirror the expected behaviour is the notice and the
# setup's own files, reported as SERVER.
function Test-E2EDownloads([hashtable]$Ctx, [bool]$MirrorOk) {
  $lines = $Ctx.LogLines
  $id = Get-E2ECheckId $Ctx 'DL'
  $common = @(Test-E2ELogLines -Lines $lines -Matches @('^HTTP GET https://files\.empireearth\.eu/localized failed: ') `
    -NotContains @('Online file rejected', 'Online file refused', 'not to https', 'Mirror not used for'))
  if (-not $MirrorOk) {
    $problems = $common + @(Test-E2ELogLines -Lines $lines -Contains @('Unable to reach the online files server! The setup will only use local files...'))
    if ($problems.Count -eq 0) { Add-E2EResult $Ctx.Scenario $id 'SERVER' @('the mirror did not answer the pre-check; the setup used its own files as it should') }
    else { [void](Complete-E2ECheck $Ctx.Scenario $id $problems) }
    return
  }
  $problems = $common
  $problems += @(Test-E2ELogLines -Lines $lines -Contains @(
      'Main online files server unreachable or without a valid certificate (see the HTTP GET line above), downloading from the mirror first',
      'Downloading 17 online files, one at a time',
      'All 20 online files accepted'))
  $registeredPinned = @(Select-E2ELogLines $lines '^Online file registered, SHA-256 pinned: ').Count
  $registeredOpen = @(Select-E2ELogLines $lines '^Online file registered, TLS-verified, not pinned: ').Count
  if ($registeredPinned -ne 10 -or $registeredOpen -ne 10) { $problems += "registered $registeredPinned pinned and $registeredOpen unpinned online files, expected 10 and 10" }
  $redirects = @(Select-E2ELogLines $lines ('^Online file redirect check: https://' + [regex]::Escape($E2EConst.MirrorHost) + '/localized/.+ answers HTTP 2\d\d over https after \d+ redirects, none to http$')).Count
  if ($redirects -ne 10) { $problems += "$redirects redirect checks of unpinned files over https, expected 10" }
  $records = @(Get-E2EDownloadRecords $lines)
  $pinned = @($records | Where-Object { $_.Pinned })
  if ($pinned.Count -ne 7 -or ($records.Count - $pinned.Count) -ne 10) {
    $problems += "$($pinned.Count) pinned and $($records.Count - $pinned.Count) unpinned downloads verified, expected 7 and 10"
  }
  $pins = @{}
  $pinFile = Join-Path $Ctx.Repo 'data\localized-text.sha256'
  if (Test-Path -LiteralPath $pinFile) { $pins = ConvertFrom-E2EPinList ([System.IO.File]::ReadAllText($pinFile)) }
  else { $problems += "$pinFile missing" }
  foreach ($record in $records) {
    if ($record.Pinned -and $pins[$record.RelPath] -cne $record.Hash) { $problems += "$($record.RelPath): the verified hash is not the pin" }
    $targets = @(Get-E2EOnlineFileTargets $record.RelPath $Ctx.Games)
    if ($targets.Count -eq 0) { $problems += "$($record.RelPath): no target folder known" }
    foreach ($target in $targets) {
      if (-not $Ctx.Manifest.ContainsKey($target)) { $problems += "$target (download $($record.RelPath)) is not in the manifest" }
      elseif ($Ctx.Manifest[$target] -cne $record.Hash) { $problems += "${target}: the manifest hash is not the hash of the download" }
    }
  }
  $failedFiles = @(Select-E2ELogLines $lines '^Online file (download failed from|not downloaded, it failed on both servers)')
  if ($problems.Count -gt 0 -and $failedFiles.Count -gt 0 -and -not ($lines | Where-Object { $_ -like 'Online file rejected*' -or $_ -like 'Online file refused*' })) {
    Add-E2EResult $Ctx.Scenario $id 'SERVER' (@('download errors of the server, the checks of the setup held:') + $failedFiles + $problems)
    return
  }
  [void](Complete-E2ECheck $Ctx.Scenario $id $problems "$($records.Count) downloads verified, $($pinned.Count) of them pinned, all in the manifest")
}

# U: uninstallation and what must be gone afterwards; AllowedLeftovers are regular expressions of
# paths below the root (relative, '\') that may stay
function Invoke-E2EUninstallChecks([hashtable]$Ctx, [string[]]$AllowedLeftovers = @(), [bool]$OtherProductInstalled = $false) {
  $p = $Ctx.Product
  $hive = Get-E2EHive $Ctx
  $log = Join-Path $env:E2E_REPORT "logs\$($Ctx.Scenario)-$($Ctx.Step).log"
  $run = Invoke-E2EUninstall $p $Ctx.Root $hive $log
  $problems = @($run.Problems)
  if ($run.ExitCode -ne 0) { $problems += "unins000.exe exit code $($run.ExitCode)" }
  if (Test-E2ERegKey $hive "$($E2EConst.CommunityKey)\Installations\$($p.Id)") { $problems += "the install record $hive\$($E2EConst.CommunityKey)\Installations\$($p.Id) is still there" }
  if (-not $OtherProductInstalled -and (Test-E2ERegKey $hive $E2EConst.CommunityKey)) { $problems += "$hive\$($E2EConst.CommunityKey) is still there" }
  if (Test-E2ERegKey 'HKCU' "$($E2EConst.CommunityKey)\GameDefaults\$($p.Id)") { $problems += 'the defaults marker is still there' }
  if (-not $OtherProductInstalled -and (Test-E2ERegKey 'HKCU' $E2EConst.CommunityKey)) { $problems += "HKCU\$($E2EConst.CommunityKey) is still there" }
  foreach ($game in @('EE', 'AoC')) {
    if (Test-E2ERegKey 'HKCU' $p.SettingsKeys[$game]) { $problems += "HKCU\$($p.SettingsKeys[$game]) is still there" }
    $program = Get-E2EGameProgram $Ctx $game
    foreach ($view in @('HKLM64', 'HKCU')) {
      $layers = Get-E2ERegValues $view $E2EConst.LayersKey
      if ($layers -and $layers.ContainsKey($program)) { $problems += "$view compatibility value of $program is still there" }
    }
    $gpu = Get-E2ERegValues 'HKCU' $E2EConst.GpuKey
    if ($gpu -and $gpu.ContainsKey($program)) { $problems += "GPU preference of $program is still there" }
    $rules = @(Get-E2EFirewallRules $program)
    if ($rules.Count -gt 0) { $problems += "$($rules.Count) firewall rule(s) of $program are still there" }
  }
  foreach ($folder in @((Join-Path (Get-E2EKnownFolder 'CommonPrograms') 'Empire Earth'), (Join-Path (Get-E2EKnownFolder 'Programs') 'Empire Earth'))) {
    if (Test-Path -LiteralPath (Join-Path $folder "$($p.AppName).lnk")) { $problems += "the shortcut in $folder is still there" }
  }
  foreach ($desktop in @((Get-E2EKnownFolder 'CommonDesktopDirectory'), (Get-E2EKnownFolder 'DesktopDirectory'))) {
    if (Test-Path -LiteralPath (Join-Path $desktop "$($p.AppName).lnk")) { $problems += "the desktop shortcut in $desktop is still there" }
  }
  if (Test-Path -LiteralPath (Join-Path $Ctx.Root $p.SetupDataDir)) { $problems += "$($p.SetupDataDir) is still there" }
  $left = @(Get-E2EFileTree $Ctx.Root | Where-Object { -not $_.IsDir } | ForEach-Object { $_.Rel.Replace('/', '\') })
  $allowed = @($left | Where-Object { $rel = $_; @($AllowedLeftovers | Where-Object { $rel -match $_ }).Count -gt 0 })
  $unexpected = @($left | Where-Object { $allowed -notcontains $_ })
  if ($unexpected.Count -gt 0) { $problems += "$($unexpected.Count) file(s) left below the root: $(($unexpected | Select-Object -First 5) -join ', ')" }
  $problems += @(Test-E2ECdKeyDummy)
  $ok = 'everything removed'
  if ($allowed.Count -gt 0) { $ok = "everything removed except $($allowed.Count) expected file(s) (e.g. $($allowed[0]))" }
  [void](Complete-E2ECheck $Ctx.Scenario (Get-E2ECheckId $Ctx 'U') $problems $ok)
}

# L: the launcher checks of one step; Expectation from New-E2ELauncherExpectation
function Invoke-E2ELauncherCheck([string]$Scenario, [string]$Step, $Expectation) {
  $run = Invoke-E2ELauncher $Scenario $Step $Expectation
  $problems = @()
  if ($run.ExitCode -ne 0) {
    $problems += "RealMachineTests exit code $($run.ExitCode) (launcher/$Scenario-$Step.txt)"
    $problems += $run.Failures
  }
  [void](Complete-E2ECheck $Scenario "$Step/L" $problems 'discovery, integrity, game settings and machine state as expected')
  $problems = @(Test-E2ECdKeyDummy)
  if ($problems.Count -gt 0) { [void](Complete-E2ECheck $Scenario "$Step/L-K9" $problems) }
}
