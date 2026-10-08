<#
.SYNOPSIS
  Builds the suite installer "Empire Earth Community Setup" (suite\suite.iss, ADR 0013) with
  Inno Setup 6.2: the checked, three-pass build of the setup program and its slices.

.DESCRIPTION
  The suite embeds the two product setups byte for byte and is disk-spanned: the setup program
  "Empire Earth Community Setup.exe" and the slices "Empire Earth Community Setup-N.bin". The number
  and the total size of the slices are compiled into the setup (it checks them before it extracts
  anything), so the build runs ISCC three times:
    1. Pass 1 (/DSlicePass1=1): measures the slices. Its output ("... PASS1 DO NOT SHIP") is
       discarded.
    2. Pass 2 with /DSliceCount and /DSliceTotal (the sum of the sizes of the .bin files).
    3. Pass 3, the same again: count, total and every byte must equal pass 2, else the build stops.
  Before that the inputs are checked: every product setup against its <setup>.exe.sha256 (written
  by ci\build.ps1 next to every setup), the AppIds, the ISCC version (-RequireVersion). The build
  identifier of each product setup comes from its <setup>.exe.setupbuild (also written by
  ci\build.ps1, bound to the SHA-256 of the setup): every product setup reports setup 1.7.2, so a
  release build (no -Placeholders, TestID 0) stops unless both have one. After the build every slice
  must be at most 50,000,000 bytes (a real build also needs -SliceSize at most that). Then out\Suite\
  (-OutputDir) gets the setup program, the slices, SHA256SUMS.txt (the program and every .bin) and
  BUILD-INFO.txt (input hashes, the SetupBuild of the product setups, commits, ISCC version, slice
  data).

  With -Placeholders (CI, contributors without the game data) the inputs are the placeholder product
  setups of ci\build.ps1 -Placeholders (out\EE_Regular, out\NeoEE_Regular), a stub launcher, a stub
  Mod Creator and stub licenses, and dummy AppIds. The slice size is computed from the size of the
  setup program (at least 262144, and DiskSliceSize must not be below the size of setup.exe: ISCC
  refuses that), unless -SliceSize is given. A placeholder build also gets the test hook of the
  uninstaller (the define of Get-SuitePlaceholderHookDefine in ci\suite_build_helpers.ps1:
  /TestDeleteUserData answers "Delete" in a silent uninstallation, CI scenario S15); a real build never
  does. The result is useless and must never be distributed.

  The real AppIds and the real inputs are only ever passed by the local real-data tooling, never
  committed. A real build (no -Placeholders) refuses the dummy AppIds. Never run the product
  of this build on a machine that has the real game installed; this script only builds.

.PARAMETER Placeholders
  Placeholder inputs and dummy AppIds (see above).

.PARAMETER SuiteAppID
  AppId GUID of the suite, without braces (needed for a real build).

.PARAMETER EEAppID
  AppId GUID of the EE setup, without braces: the one the EE setup is built with (real build).

.PARAMETER NeoEEAppID
  AppId GUID of the NeoEE setup, without braces (real build).

.PARAMETER EESetup
  The EE setup to embed. <file>.sha256 must be next to it, and for a release build <file>.setupbuild
  with a SetupBuild (ci\build.ps1 -SetupBuild <identifier>). Real build: required.

.PARAMETER NeoEESetup
  The NeoEE setup to embed, with <file>.sha256 next to it (and <file>.setupbuild, as for -EESetup).
  Real build: required.

.PARAMETER LauncherDir
  Release output of the launcher (no .pdb). Real build: required.

.PARAMETER ModCreatorDir
  Release output of the Mod Creator. Real build: required.

.PARAMETER LicenseDir
  LICENSE, THIRD-PARTY-NOTICES.md, licenses\, Quellcode.txt. Real build: required.

.PARAMETER LauncherCommit
  Git commit of the launcher the files come from, for BUILD-INFO.txt (7 to 40 lower-case hex digits).

.PARAMETER ModCreatorCommit
  Git commit of the Mod Creator, for BUILD-INFO.txt.

.PARAMETER OutputDir
  Output folder (default: out\Suite in the repository).

.PARAMETER SliceSize
  DiskSliceSize in bytes (default 50000000, at most that; with -Placeholders computed).

.PARAMETER EEInstallSize
  Free space the installed EE needs, bytes (default of suite.iss: twice the setup).

.PARAMETER NeoEEInstallSize
  Free space the installed NeoEE needs, bytes.

.PARAMETER TestID
  Test build number (/DTestID, a whole number >= 0; 0 = release build).

.PARAMETER TestWrongEEPin
  Only with -Placeholders, for the CI scenario S5 (ci\e2e\run_e2e_suite.ps1): compiles a wrong SHA-256 of the
  EE setup into the suite (the first hex digit of the real one changed). The embedded setup is untouched, so the
  suite must refuse it before it runs anything (exit code 15). Put the output in its own -OutputDir. Useless,
  never distribute.

.PARAMETER Iscc
  Path to ISCC.exe. Default: $env:ISCC, the "Inno Setup 6" folder in Program Files, then PATH.

.PARAMETER RequireVersion
  Fail unless ISCC has exactly this version (CI uses 6.2.2). Otherwise only a warning is shown when
  ISCC is not 6.2.x.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File suite\build_suite.ps1 -Placeholders -RequireVersion 6.2.2

.EXAMPLE
  .\suite\build_suite.ps1 -SuiteAppID <GUID> -EEAppID <GUID> -NeoEEAppID <GUID> -EESetup <exe> -NeoEESetup <exe> -LauncherDir <dir> -ModCreatorDir <dir> -LicenseDir <dir> -LauncherCommit <hash>
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Placeholders,
  [string]$SuiteAppID,
  [string]$EEAppID,
  [string]$NeoEEAppID,
  [string]$EESetup,
  [string]$NeoEESetup,
  [string]$LauncherDir,
  [string]$ModCreatorDir,
  [string]$LicenseDir,
  [string]$LauncherCommit = '',
  [string]$ModCreatorCommit = '',
  [string]$OutputDir,
  [ValidateRange(1, 2147483647)]
  [long]$SliceSize,
  [ValidateRange(1, 9007199254740991)]
  [long]$EEInstallSize,
  [ValidateRange(1, 9007199254740991)]
  [long]$NeoEEInstallSize,
  [ValidateRange(0, 2147483647)]
  [int]$TestID = 0,
  [switch]$TestWrongEEPin,
  [string]$Iscc,
  [string]$RequireVersion
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
# PowerShell 7.4+: a native command's exit code must not throw, it is checked explicitly.
$PSNativeCommandUseErrorActionPreference = $false

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $Root 'ci\build_helpers.ps1')        # Get-GitShortCommit, Write-FileSha256, Read-SetupBuildRecord
. (Join-Path $Root 'ci\suite_build_helpers.ps1')

$SuiteScript = Join-Path $PSScriptRoot 'suite.iss'
$BaseName = 'Empire Earth Community Setup'
$Pass1Name = "$BaseName PASS1 DO NOT SHIP"
$DummySuiteAppID = '00000000-0000-0000-0000-0000000005EE'
$DummyEEAppID = '00000000-0000-0000-0000-0000000000EE'
$DummyNeoEEAppID = '00000000-0000-0000-0000-000000000AEE'
$GuidPattern = '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\z'
if (-not $OutputDir) { $OutputDir = Join-Path $Root 'out\Suite' }
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

function Resolve-Input([string]$Path) {
  if (-not $Path) { return '' }
  return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\', '/')
}

if (-not (Test-Path -LiteralPath $SuiteScript -PathType Leaf)) { throw "suite.iss not found: $SuiteScript" }
if ($TestWrongEEPin -and -not $Placeholders) { throw '-TestWrongEEPin is only for -Placeholders builds (a setup with a wrong pin must never be built from real inputs).' }
$LauncherCommit = Assert-CommitText $LauncherCommit '-LauncherCommit'
$ModCreatorCommit = Assert-CommitText $ModCreatorCommit '-ModCreatorCommit'

# ---- the AppIds: the real ones only from the caller, the dummies only with -Placeholders ---------
if ($Placeholders) {
  if (-not $SuiteAppID) { $SuiteAppID = $DummySuiteAppID }
  if (-not $EEAppID) { $EEAppID = $DummyEEAppID }
  if (-not $NeoEEAppID) { $NeoEEAppID = $DummyNeoEEAppID }
} else {
  foreach ($pair in @(@('SuiteAppID', $SuiteAppID), @('EEAppID', $EEAppID), @('NeoEEAppID', $NeoEEAppID))) {
    if (-not $pair[1]) { throw "-$($pair[0]) is required for a real build (the real AppIds are only passed by the local tooling; -Placeholders uses dummies)." }
  }
}
foreach ($pair in @(@('SuiteAppID', $SuiteAppID), @('EEAppID', $EEAppID), @('NeoEEAppID', $NeoEEAppID))) {
  if ($pair[1] -cnotmatch $GuidPattern) { throw "-$($pair[0]) '$($pair[1])' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)." }
  if (-not $Placeholders -and $pair[1] -match '^00000000-0000-0000-0000-') { throw "-$($pair[0]) is a dummy AppId: a real build needs the real one." }
}
if (@($SuiteAppID, $EEAppID, $NeoEEAppID | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique).Count -ne 3) {
  throw 'The AppIds of the suite, EE and NeoEE must differ.'
}

# ---- the work folder and the inputs --------------------------------------------------------------
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ('suite_build_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $WorkDir | Out-Null
try {
  if ($Placeholders) {
    # The placeholder product setups of "ci\build.ps1 -Placeholders" (one exe per variant folder)
    if (-not $EESetup) { $EESetup = Join-Path $Root 'out\EE_Regular\*' }
    if (-not $NeoEESetup) { $NeoEESetup = Join-Path $Root 'out\NeoEE_Regular\*' }
    foreach ($which in @('EESetup', 'NeoEESetup')) {
      $value = Get-Variable -Name $which -ValueOnly
      if ($value.EndsWith('*')) {
        $found = @(Get-ChildItem -Path $value -Include '*.exe' -File -ErrorAction SilentlyContinue)
        if ($found.Count -ne 1) { throw "-$which : expected one placeholder setup in $(Split-Path -Parent $value) (run ci\build.ps1 -Placeholders first), found $($found.Count)." }
        Set-Variable -Name $which -Value $found[0].FullName
      }
    }
    # A stub launcher, a stub Mod Creator and stub licenses: files with the names of the real ones
    $stub = Join-Path $WorkDir 'stub'
    $LauncherDir = Join-Path $stub 'launcher'
    $ModCreatorDir = Join-Path $stub 'modcreator'
    $LicenseDir = Join-Path $stub 'licenses'
    foreach ($dir in @($LauncherDir, $ModCreatorDir, (Join-Path $LicenseDir 'licenses'))) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $note = 'PLACEHOLDER (suite build with -Placeholders): not a program, not for distribution.'
    foreach ($file in @((Join-Path $LauncherDir 'Empire Earth Launcher.exe'), (Join-Path $LauncherDir 'Empire Earth Launcher.exe.config'),
        (Join-Path $ModCreatorDir 'Empire_Earth_Mod.exe'), (Join-Path $LicenseDir 'LICENSE'), (Join-Path $LicenseDir 'THIRD-PARTY-NOTICES.md'),
        (Join-Path $LicenseDir 'Quellcode.txt'), (Join-Path (Join-Path $LicenseDir 'licenses') 'placeholder.txt'))) {
      [System.IO.File]::WriteAllText($file, "$note`n", [System.Text.UTF8Encoding]::new($false))
    }
  } else {
    foreach ($pair in @(@('EESetup', $EESetup), @('NeoEESetup', $NeoEESetup), @('LauncherDir', $LauncherDir), @('ModCreatorDir', $ModCreatorDir), @('LicenseDir', $LicenseDir))) {
      if (-not $pair[1]) { throw "-$($pair[0]) is required for a real build." }
    }
  }
  $LauncherDir = Resolve-Input $LauncherDir
  $ModCreatorDir = Resolve-Input $ModCreatorDir
  $LicenseDir = Resolve-Input $LicenseDir

  # Every product setup against its own .sha256 (the file ci\build.ps1 wrote next to it)
  $ee = Assert-InputChecksum (Resolve-Input $EESetup) 'EE setup'
  $neo = Assert-InputChecksum (Resolve-Input $NeoEESetup) 'NeoEE setup'
  if ($ee.Hash -ceq $neo.Hash) { throw 'The EE and the NeoEE setup are the same file (same SHA-256).' }
  # The build identifier of each product setup, from the record next to it (ci\build.ps1): every product setup
  # reports setup 1.7.2, so a release build of the suite needs one for both (ADR 0004 point 10, ADR 0013)
  $releaseBuild = (-not $Placeholders) -and ($TestID -eq 0)
  $eeBuild = Get-ProductSetupBuild $ee 'The EE setup' $releaseBuild
  $neoBuild = Get-ProductSetupBuild $neo 'The NeoEE setup' $releaseBuild
  $launcherTree = Get-TreeDigest $LauncherDir
  $modTree = Get-TreeDigest $ModCreatorDir
  $licenseTree = Get-TreeDigest $LicenseDir
  # The legal texts the suite shows (suite.iss takes them from data\ of this checkout): a real build needs the
  # real files, never the placeholders of CI
  $legalTexts = @()
  if (-not $Placeholders) {
    if (-not $LauncherCommit) { Write-Warning 'No -LauncherCommit: BUILD-INFO.txt will not name the launcher commit.' }
    if (-not $ModCreatorCommit) { Write-Warning 'No -ModCreatorCommit: BUILD-INFO.txt will not name the Mod Creator commit.' }
    $legalTexts = @(
      (Get-SuiteLegalText (Join-Path $Root 'data\Empire Earth Base\Empire Earth\EULA_DSML.txt') 'The EULA of EE'),
      (Get-SuiteLegalText (Join-Path $Root 'data\NeoEE Base\shared\neoee_rules.rtf') 'The rules of NeoEE')
    )
  }

  # ---- ISCC -------------------------------------------------------------------------------------
  $IsccPath = Find-SuiteIscc $Iscc
  $version = Get-SuiteIsccVersion $IsccPath $WorkDir
  if ($RequireVersion) {
    if ($version -cne $RequireVersion) { throw "ISCC $RequireVersion is required, found $version." }
  } elseif ($version -notlike '6.2.*') {
    Write-Warning "ISCC $version found, this script targets Inno Setup 6.2.x (6.2.2 for releases)."
  }
  Write-Host "ISCC $version ($IsccPath)"

  # The pin compiled into the suite: the hash of the file, or with -TestWrongEEPin one with another first digit
  $eePin = $ee.Hash
  if ($TestWrongEEPin) {
    $firstDigit = '0'
    if ($eePin[0] -ceq '0') { $firstDigit = '1' }
    $eePin = $firstDigit + $eePin.Substring(1)
    Write-Warning 'TEST BUILD WITH A WRONG EE PIN (-TestWrongEEPin): the suite refuses the EE setup. Never distribute it.'
  }

  $common = @(
    "/DSuiteAppID=$SuiteAppID", "/DEE_AppID=$EEAppID", "/DNeoEE_AppID=$NeoEEAppID",
    "/DEESetupFile=$($ee.Path)", "/DEESetupSHA256=$eePin", "/DEESetupSize=$($ee.Size)",
    "/DNeoEESetupFile=$($neo.Path)", "/DNeoEESetupSHA256=$($neo.Hash)", "/DNeoEESetupSize=$($neo.Size)",
    "/DLauncherDir=$LauncherDir", "/DModCreatorDir=$ModCreatorDir", "/DLicenseDir=$LicenseDir"
  )
  if ($PSBoundParameters.ContainsKey('EEInstallSize')) { $common += "/DEEInstallSize=$EEInstallSize" }
  if ($PSBoundParameters.ContainsKey('NeoEEInstallSize')) { $common += "/DNeoEEInstallSize=$NeoEEInstallSize" }
  if ($TestID -gt 0) { $common += "/DTestID=$TestID" }
  # The test hook of the uninstaller (CI scenario S15): placeholder builds only
  $common += @(Get-SuitePlaceholderHookDefine ([bool]$Placeholders))

  # One ISCC run into a fresh folder; stops with the errors of the log if ISCC fails
  function Invoke-SuitePass([string]$Name, [string[]]$Defines) {
    $out = Join-Path $WorkDir $Name
    New-Item -ItemType Directory -Path $out | Out-Null
    $log = Join-Path $WorkDir "$Name.log"
    Push-Location $PSScriptRoot
    try {
      $code = Invoke-SuiteIscc $IsccPath (@('/Q', "/O$out") + $common + $Defines + @($SuiteScript)) $log
    } finally {
      Pop-Location
    }
    if ($code -ne 0) {
      Get-Content -LiteralPath $log | Where-Object { $_ -match 'error|warning|line \d+|not found|cannot' } |
        Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
      throw "ISCC failed in $Name (exit code $code)."
    }
    return $out
  }

  # ---- the slice size -------------------------------------------------------------------------
  $MaxSlice = $script:SuiteMaxSliceBytes
  if ($PSBoundParameters.ContainsKey('SliceSize')) {
    if ($SliceSize -gt $MaxSlice) { throw "-SliceSize $SliceSize is more than the limit of $MaxSlice bytes per slice." }
  } elseif ($Placeholders) {
    # DiskSliceSize must be >= the size of setup.exe, which is only known after a build: a probe
    # with the largest slice size measures it
    $probeDir = Invoke-SuitePass 'probe' @('/DSlicePass1=1', "/DSliceSize=$MaxSlice")
    $probeExe = Join-Path $probeDir "$Pass1Name.exe"
    if (-not (Test-Path -LiteralPath $probeExe -PathType Leaf)) { throw "The probe build did not write '$Pass1Name.exe'." }
    $SliceSize = Get-PlaceholderSliceSize (Get-Item -LiteralPath $probeExe).Length
    Write-Host "Slice size (placeholders): $SliceSize bytes (setup program $((Get-Item -LiteralPath $probeExe).Length) bytes)"
  } else {
    $SliceSize = $MaxSlice
  }
  $sizeDefine = "/DSliceSize=$SliceSize"

  # ---- pass 1: count and total of the slices ----------------------------------------------------
  $pass1 = Get-SuiteSliceInfo (Invoke-SuitePass 'pass1' @('/DSlicePass1=1', $sizeDefine)) $Pass1Name
  if ($pass1.Count -lt 1) { throw "Pass 1 wrote no .bin slice: the payload fits into the setup program. Lower -SliceSize (now $SliceSize); the suite needs at least one slice." }
  Write-Host "Pass 1: $($pass1.Count) slice(s), $($pass1.Total) bytes in total (setup program $($pass1.Exe.Length) bytes)"
  if ($pass1.Exe.Length -gt $SliceSize) {
    throw "The setup program is $($pass1.Exe.Length) bytes, more than DiskSliceSize $SliceSize (ISCC needs DiskSliceSize >= setup.exe)."
  }
  $counts = @("/DSliceCount=$($pass1.Count)", "/DSliceTotal=$($pass1.Total)")

  # ---- pass 2 and 3: the real build, twice, must be identical ------------------------------------
  $pass2 = Get-SuiteSliceInfo (Invoke-SuitePass 'pass2' (@($sizeDefine) + $counts)) $BaseName
  if ($pass2.Count -ne $pass1.Count -or $pass2.Total -ne $pass1.Total) {
    throw "Pass 2 has $($pass2.Count) slice(s) and $($pass2.Total) bytes, pass 1 had $($pass1.Count) and $($pass1.Total): the numbers compiled into the setup do not match its slices."
  }
  $pass3 = Get-SuiteSliceInfo (Invoke-SuitePass 'pass3' (@($sizeDefine) + $counts)) $BaseName
  $differences = @(Compare-SuiteBuilds $pass2 $pass3)
  if ($differences.Count -gt 0) { throw "The build is not stable, pass 2 and pass 3 differ: $($differences -join '; ')" }
  Write-Host "Pass 2 and 3: identical ($($pass3.Count) slice(s), $($pass3.Total) bytes, setup program $($pass3.Exe.Length) bytes)"

  # ---- the limits of the files -------------------------------------------------------------------
  # Never more than DiskSliceSize, and in every build at most 50,000,000 bytes (-SliceSize was checked, too)
  $limit = [Math]::Min($SliceSize, $MaxSlice)
  $problems = @(Test-SuiteSliceLimit $pass3 $limit)
  if ($problems.Count -gt 0) { throw "File(s) over the limit: $($problems -join ' ')" }

  # ---- the output folder -------------------------------------------------------------------------
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
  # Only what an earlier run of this script wrote goes (never another file of the folder)
  Get-ChildItem -LiteralPath $OutputDir -File | Where-Object {
    $_.Name -ceq 'SHA256SUMS.txt' -or $_.Name -ceq 'BUILD-INFO.txt' -or $_.Name -clike "$BaseName*.exe" -or $_.Name -clike "$BaseName-*.bin"
  } | Remove-Item -Force
  foreach ($file in (@($pass3.Exe) + @($pass3.Slices))) {
    Copy-Item -LiteralPath $file.FullName -Destination $OutputDir
    # What was copied is what pass 3 built
    $copy = Join-Path $OutputDir $file.Name
    if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) {
      throw "$copy differs from the file of pass 3 after the copy."
    }
  }
  $final = $pass3
  $sums = Write-SuiteSums $final (Join-Path $OutputDir 'SHA256SUMS.txt')

  $git = Get-GitState $Root
  $suiteVersion = ''
  $match = [regex]::Match([System.IO.File]::ReadAllText($SuiteScript), '(?m)^#define SuiteVersion "([^"]+)"')
  if ($match.Success) { $suiteVersion = $match.Groups[1].Value }
  $setupCommit = $git.Commit
  if ($setupCommit -and $git.Dirty) { $setupCommit += ' (with uncommitted changes)' }
  if (-not $setupCommit) { $setupCommit = 'unknown (no Git checkout)' }
  $info = @()
  if ($Placeholders) { $info += 'PLACEHOLDER BUILD: dummy AppIds, placeholder product setups and stub launcher. Useless, never distribute.', '' }
  if ($TestWrongEEPin) { $info += 'WRONG EE PIN (-TestWrongEEPin): the suite refuses the EE setup with exit code 15 (CI scenario S5). Never distribute.', '' }
  $info += @(
    "Empire Earth Community Setup $suiteVersion (suite installer, ADR 0013)",
    "Built (UTC):          $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))",
    "Setup repository:     $setupCommit",
    "Launcher commit:      $(if ($LauncherCommit) { $LauncherCommit } else { 'not given' })",
    "Mod Creator commit:   $(if ($ModCreatorCommit) { $ModCreatorCommit } else { 'not given' })",
    "ISCC:                 $version",
    "Build kind:           $(if ($TestID -gt 0) { "test build $TestID" } else { 'release build (TestID 0)' })",
    "Product SetupBuild:   EE $eeBuild, NeoEE $neoBuild",
    "DiskSliceSize:        $SliceSize",
    "Slices:               $($final.Count), $($final.Total) bytes in total, setup program $($final.Exe.Length) bytes",
    '',
    'Inputs (SHA-256, size):',
    "  EE setup            $($ee.Hash)  $($ee.Size)  $($ee.Name)",
    "  NeoEE setup         $($neo.Hash)  $($neo.Size)  $($neo.Name)",
    "  Launcher folder     $($launcherTree.Digest)  $($launcherTree.Files) files, $($launcherTree.Bytes) bytes (digest of the sorted file hashes, without .pdb)",
    "  Mod Creator folder  $($modTree.Digest)  $($modTree.Files) files, $($modTree.Bytes) bytes",
    "  License folder      $($licenseTree.Digest)  $($licenseTree.Files) files, $($licenseTree.Bytes) bytes"
  )
  foreach ($legal in $legalTexts) { $info += "  Legal text          $($legal.Hash)  $($legal.Size)  $($legal.Name)" }
  $info += @(
    '',
    'Output (SHA-256, the same as in SHA256SUMS.txt):'
  )
  foreach ($line in $sums) { $info += "  $line" }
  [System.IO.File]::WriteAllText((Join-Path $OutputDir 'BUILD-INFO.txt'), (($info -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

  Write-Host "Suite built into ${OutputDir}: $($final.Exe.Name) + $($final.Count) slice(s), SHA256SUMS.txt, BUILD-INFO.txt"
} finally {
  Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}
