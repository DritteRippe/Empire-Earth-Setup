<#
.SYNOPSIS
  Compiles the Empire Earth Community Setup variants with Inno Setup 6.2 (ISCC).

.DESCRIPTION
  Clean two-pass build, used by CI (.github/workflows/build.yml):
    1. Preprocess every variant: a temporary copy of setup_is6.iss gets an ISPP
       "#expr SaveToFile(...)" line appended, so ISCC dumps the fully resolved script.
    2. With -Placeholders: create a dummy file for every asset the resolved scripts reference
       but that does not exist (ci/make_placeholder_assets.py). Existing files are never touched.
    3. Write data\localized-text.sha256, the SHA-256 list of data\localized-text: the setups only
       install a downloaded Language.dll whose hash is in this list, and a listed data file only
       if it matches (see downloads.iss).
    4. Compile every variant with ISCC /DInstallType /DInstallMode /DEE_AppID /DNeoEE_AppID
       [/DTestID] into its own output folder and check that the file name proves the variant took
       effect.
  With -SignSetup the certificate internal\misc\<CertFileName> (DER or PEM) is first converted to
  a DER copy in the temporary build folder, checked against -CertHashSHA1 and passed to ISCC as
  /DCertDerFile, see README.md "Signed builds".
  The functions that do not need ISCC are in ci\build_helpers.ps1 (tested by
  ci\tests\build_helpers.tests.ps1).

  Without -Placeholders the real assets (data\, internal\media, internal\misc, internal\runtime,
  tools\) must be present. An installer built from placeholders is useless and must never be
  distributed.

.PARAMETER Placeholders
  Generate placeholder assets for missing files (CI / contributors without the game data).
  Also uses dummy AppIds unless -EEAppID / -NeoEEAppID are given.

.PARAMETER EEAppID
  AppId GUID of the EE setup, without braces. Default: the EE_AppID define in setup_is6.iss.

.PARAMETER NeoEEAppID
  AppId GUID of the NeoEE setup, without braces. Default: the NeoEE_AppID define in setup_is6.iss.

.PARAMETER TestID
  Test build number, passed to ISCC as /DTestID=<n> (a whole number >= 0, anything else stops the
  script before ISCC runs). 0 is a release build; a number > 0 makes a test build: fast
  compression (zip/1) and a warning with the number on every start, also in silent mode (silent
  test runs need /SUPPRESSMSGBOXES). Default: the TestID define in setup_is6.iss (0). Test builds
  are for testing only and must never be distributed.

.PARAMETER Variants
  Variants to build, any of EE/Regular, NeoEE/Regular, EE/Portable, NeoEE/Portable (default: all).

.PARAMETER OutputDir
  Output folder (default: out\ in the repository). Every variant gets its own subfolder.

.PARAMETER Iscc
  Path to ISCC.exe. Default: $env:ISCC, the "Inno Setup 6" folder in Program Files, then PATH.

.PARAMETER RequireVersion
  Fail unless ISCC has exactly this version (CI uses 6.2.2). Otherwise only a warning is shown
  when ISCC is not 6.2.x.

.PARAMETER Python
  Python 3 executable used for the placeholder generator (default: python).

.PARAMETER KeepPreprocessed
  Folder to copy the resolved script of every variant into (<Type>_<Mode>.iss), e.g. for diffs.

.PARAMETER DownloadHashesOnly
  Only write data\localized-text.sha256 and exit, e.g. before compiling in the Inno Setup IDE.

.PARAMETER SignSetup
  Signed build (ISCC /DSignSetup=1). Needs -CertFileName and -CertHashSHA1, and a sign tool: the
  ones configured in the Inno Setup IDE (Tools > Configure Sign Tools: NameInInnoSetupEE,
  NameInInnoSetupNeo) or -SignTool. Not possible with -Placeholders.

.PARAMETER CertFileName
  Certificate file in internal\misc, DER or PEM (only with -SignSetup). The setup ships a DER copy
  under this name.

.PARAMETER CertHashSHA1
  SHA-1 thumbprint of that certificate (only with -SignSetup); spaces are ignored.

.PARAMETER SignTool
  Sign command for both sign tools (ISCC /SNameInInnoSetupEE=... /SNameInInnoSetupNeo=...), with $f
  for the file, e.g. 'signtool.exe sign /a /fd sha256 /tr http://timestamp.digicert.com /td sha256 $f'.
  Default: the sign tools configured in the Inno Setup IDE.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\build.ps1 -DownloadHashesOnly

.EXAMPLE
  .\ci\build.ps1 -Variants NeoEE/Portable -EEAppID <GUID> -NeoEEAppID <GUID>

.EXAMPLE
  .\ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID> -TestID 1

.EXAMPLE
  .\ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID> -SignSetup -CertFileName Empire_Earth_Community.crt -CertHashSHA1 <thumbprint> -SignTool 'signtool.exe sign /a /fd sha256 $f'
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Placeholders,
  [string]$EEAppID,
  [string]$NeoEEAppID,
  [ValidateRange(0, 2147483647)]
  [int]$TestID,
  [ValidateSet('EE/Regular', 'NeoEE/Regular', 'EE/Portable', 'NeoEE/Portable')]
  [string[]]$Variants = @('EE/Regular', 'NeoEE/Regular', 'EE/Portable', 'NeoEE/Portable'),
  [string]$OutputDir,
  [string]$Iscc,
  [string]$RequireVersion,
  [string]$Python = 'python',
  [string]$KeepPreprocessed,
  [switch]$DownloadHashesOnly,
  [switch]$SignSetup,
  [string]$CertFileName,
  [string]$CertHashSHA1,
  [string]$SignTool
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
# PowerShell 7.4+: a native command's exit code must not throw, it is checked explicitly.
$PSNativeCommandUseErrorActionPreference = $false

$Root = Split-Path -Parent $PSScriptRoot
$MainScript = 'setup_is6.iss'
$DummyEEAppID = '00000000-0000-0000-0000-0000000000EE'
$DummyNeoEEAppID = '00000000-0000-0000-0000-000000000AEE'
if (-not $OutputDir) { $OutputDir = Join-Path $Root 'out' }
# Resolve relative paths against the caller's location before changing into the repository.
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
if ($KeepPreprocessed) {
  $KeepPreprocessed = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KeepPreprocessed)
}

function Find-Iscc {
  $candidates = @()
  if ($env:ISCC) { $candidates += $env:ISCC }
  if (${env:ProgramFiles(x86)}) { $candidates += Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' }
  if ($env:ProgramFiles) { $candidates += Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe' }
  if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe' }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  }
  $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  throw 'ISCC.exe (Inno Setup 6.2) not found. Install it or pass -Iscc <path>.'
}

# Runs ISCC and returns its exit code; the complete output (stdout and stderr) goes to $LogFile,
# which is also written when ISCC prints nothing (e.g. it could not start), so that the callers
# report that clearly instead of failing to read a missing log.
function Invoke-Iscc([string[]]$Arguments, [string]$LogFile) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'   # stderr lines of a native command must not throw
  try {
    $output = & $Iscc @Arguments 2>&1
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  Set-Content -LiteralPath $LogFile -Value @($output | ForEach-Object { "$_" }) -Encoding UTF8
  return $code
}

# The ISCC executables carry no usable version resource, so ask the preprocessor (ISPP "Ver").
function Get-IsccVersion([string]$WorkDir) {
  $probe = Join-Path $WorkDir 'version_probe.iss'
  $lines = @(
    '#pragma message "ISCC_VERSION=" + DecodeVer(Ver)',
    '[Setup]',
    'AppName=probe',
    'AppVersion=1',
    'DefaultDirName={tmp}\probe'
  )
  Set-Content -LiteralPath $probe -Value $lines -Encoding ASCII
  $log = Join-Path $WorkDir 'version_probe.log'
  Invoke-Iscc @('/O-', $probe) $log | Out-Null
  $match = Select-String -LiteralPath $log -Pattern 'ISCC_VERSION=(\S+)' | Select-Object -First 1
  if ($match) { return $match.Matches[0].Groups[1].Value }
  return 'unknown'
}

function Show-LogErrors([string]$LogFile) {
  Get-Content -LiteralPath $LogFile |
    Where-Object { $_ -match 'error|warning|line \d+|not found|cannot' } |
    Select-Object -First 20 |
    ForEach-Object { Write-Host "    $_" }
}

# Write-DownloadHashes, ConvertTo-DerCertificateFile, ConvertTo-Thumbprint, Get-TestIdDefine
. (Join-Path $PSScriptRoot 'build_helpers.ps1')

$LocalizedFolder = Join-Path $Root 'data\localized-text'
$DownloadHashList = Join-Path $Root 'data\localized-text.sha256'
if ($DownloadHashesOnly) {
  Write-DownloadHashes $LocalizedFolder $DownloadHashList
  exit 0
}

if ($SignSetup) {
  if ($Placeholders) { throw '-SignSetup needs the real certificate and cannot be combined with -Placeholders.' }
  if (-not $CertFileName -or -not $CertHashSHA1) { throw '-SignSetup needs -CertFileName and -CertHashSHA1.' }
  $CertSource = Join-Path $Root "internal\misc\$CertFileName"
  if (-not (Test-Path -LiteralPath $CertSource -PathType Leaf)) { throw "Certificate not found: $CertSource" }
}

if (-not $Iscc) { $Iscc = Find-Iscc }
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-setup-build-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $WorkDir | Out-Null

$failed = @()
Push-Location -LiteralPath $Root
try {
  $version = Get-IsccVersion $WorkDir
  Write-Host "ISCC: $Iscc (version $version)"
  if ($RequireVersion -and $version -ne $RequireVersion) {
    throw "ISCC $RequireVersion is required, found $version."
  }
  if ($version -notlike '6.2.*') {
    Write-Warning "The setup script targets Inno Setup 6.2.x (tested with 6.2.2), found $version."
  }

  if ($Placeholders) {
    if (-not $EEAppID) { $EEAppID = $DummyEEAppID }
    if (-not $NeoEEAppID) { $NeoEEAppID = $DummyNeoEEAppID }
    Write-Warning 'Placeholder build: the installers only prove that the script compiles. Never distribute them.'
  }
  # ISCC defines and options of both passes: AppIds, test build number, signing
  $defines = @()
  if ($EEAppID) { $defines += "/DEE_AppID=$EEAppID" }
  if ($NeoEEAppID) { $defines += "/DNeoEE_AppID=$NeoEEAppID" }
  # Without -TestID the default of setup_is6.iss applies (0, release build)
  if ($PSBoundParameters.ContainsKey('TestID')) {
    $defines += Get-TestIdDefine $TestID
    if ($TestID -gt 0) {
      Write-Warning "Test build ${TestID}: fast compression and a warning on every start. For testing only, never distribute it."
    }
  }

  # Signed builds ship a DER copy of the certificate: setup_is6.iss compares its SHA-1 with
  # CertHashSHA1, and the community certificate is PEM, which ISPP cannot decode.
  if ($SignSetup) {
    $certDer = Join-Path (Join-Path $WorkDir 'cert') $CertFileName
    $cert = ConvertTo-DerCertificateFile $CertSource $certDer
    $thumbprint = ConvertTo-Thumbprint $CertHashSHA1
    if ($cert.Thumbprint -ne $thumbprint) {
      throw "CertHashSHA1 $thumbprint is not the thumbprint of $CertSource ($($cert.Thumbprint))."
    }
    Write-Host "Certificate: $CertSource ($($cert.Encoding)), DER copy $certDer, thumbprint $($cert.Thumbprint)"
    $defines += @('/DSignSetup=1', "/DCertFileName=$CertFileName", "/DCertHashSHA1=$thumbprint", "/DCertDerFile=$certDer")
    if ($SignTool) { $defines += @("/SNameInInnoSetupEE=$SignTool", "/SNameInInnoSetupNeo=$SignTool") }
  }

  # Pass 1: dump the resolved script of every variant. The copy has to live next to
  # setup_is6.iss so that its relative #include paths resolve. The compile itself may fail
  # here (assets may still be missing); only the dump matters.
  $resolved = @()
  foreach ($variant in $Variants) {
    $type, $mode = $variant -split '/'
    $copy = "_pp_${type}_${mode}.iss"
    $dump = "_ppout_${type}_${mode}.iss"
    if (Test-Path -LiteralPath $dump) { Remove-Item -LiteralPath $dump }
    Copy-Item -LiteralPath $MainScript -Destination $copy -Force
    $saveLine = '#expr SaveToFile(AddBackslash(SourcePath) + "{0}")' -f $dump
    [System.IO.File]::AppendAllText((Join-Path $Root $copy), "`r`n$saveLine`r`n", [System.Text.UTF8Encoding]::new($false))
    $log = Join-Path $WorkDir "pp_${type}_${mode}.log"
    Invoke-Iscc (@('/Q', '/O-', "/DInstallType=$type", "/DInstallMode=$mode") + $defines + @($copy)) $log | Out-Null
    Remove-Item -LiteralPath $copy
    if (-not (Test-Path -LiteralPath $dump)) {
      Write-Host "FAIL ${variant}: preprocessing produced no output"
      Show-LogErrors $log
      throw 'Preprocessing failed.'
    }
    $resolved += $dump
  }

  if ($KeepPreprocessed) {
    New-Item -ItemType Directory -Path $KeepPreprocessed -Force | Out-Null
    foreach ($dump in $resolved) {
      Copy-Item -LiteralPath $dump -Destination (Join-Path $KeepPreprocessed ($dump -replace '^_ppout_', '')) -Force
    }
  }

  if ($Placeholders) {
    & $Python (Join-Path 'ci' 'make_placeholder_assets.py') --root $Root @resolved
    if ($LASTEXITCODE -ne 0) { throw 'Placeholder generation failed.' }
  }
  foreach ($dump in $resolved) { Remove-Item -LiteralPath $dump }

  Write-DownloadHashes $LocalizedFolder $DownloadHashList

  # Pass 2: the real compile, one output folder per variant.
  foreach ($variant in $Variants) {
    $type, $mode = $variant -split '/'
    $variantOut = Join-Path $OutputDir "${type}_${mode}"
    if (Test-Path -LiteralPath $variantOut) { Remove-Item -LiteralPath $variantOut -Recurse -Force }
    New-Item -ItemType Directory -Path $variantOut | Out-Null
    $log = Join-Path $WorkDir "${type}_${mode}.log"
    $code = Invoke-Iscc (@('/Q', "/O$variantOut", "/DInstallType=$type", "/DInstallMode=$mode") + $defines + @($MainScript)) $log

    $exe = @(Get-ChildItem -LiteralPath $variantOut -Filter '*.exe' | Select-Object -ExpandProperty Name)
    $ok = ($code -eq 0) -and ($exe.Count -eq 1)
    if ($ok) {
      $name = $exe[0]
      # The output file name proves that the /D switches took effect (see OutputBaseFilename).
      if ($type -eq 'NeoEE') { $ok = $name -like 'NeoEE*' } else { $ok = $name -like 'EE_*' }
      if ($mode -eq 'Portable') { $ok = $ok -and ($name -like '*Portable*') } else { $ok = $ok -and ($name -notlike '*Portable*') }
    }
    if ($ok) {
      Write-Host "PASS $variant -> $($exe[0])"
    } else {
      Write-Host "FAIL $variant (ISCC exit code $code, output: $($exe -join ', '))"
      Show-LogErrors $log
      $failed += $variant
    }
  }
} finally {
  Get-ChildItem -LiteralPath $Root -Filter '_pp*.iss' | Where-Object { $_.Name -match '^_pp(out)?_' } | Remove-Item
  Pop-Location
  Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed.Count -gt 0) {
  Write-Host "Build failed for: $($failed -join ', ')"
  exit 1
}
Write-Host "All $($Variants.Count) variant(s) built into $OutputDir"
