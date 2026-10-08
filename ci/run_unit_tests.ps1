<#
.SYNOPSIS
  Compiles and runs the unit tests of the setup's [Code] helpers (ci\tests\unit_tests.iss).

.DESCRIPTION
  unit_tests.iss is a tiny setup that includes utils.iss, runs the tests in InitializeSetup,
  writes the results to a text file and exits without installing anything. The tests need no
  network and no game data. This script compiles it with ISCC, runs it silently (with
  /SAMPLES=<the folder docs\contract-samples of the repository>, the byte samples of the contract
  that the writers must reproduce), prints the results and exits with 0 if every test passed,
  else 1.

.PARAMETER Iscc
  Path to ISCC.exe. Default: $env:ISCC, the "Inno Setup 6" folder in Program Files, then PATH.

.PARAMETER OutputDir
  Folder for the test setup and its results (default: out\unit_tests in the repository).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\run_unit_tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$Iscc,
  [string]$OutputDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $Root 'out\unit_tests' }
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

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

if (-not $Iscc) { $Iscc = Find-Iscc }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ResultFile = Join-Path $OutputDir 'unit_tests_result.txt'
Remove-Item -LiteralPath $ResultFile -ErrorAction SilentlyContinue

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'   # stderr lines of a native command must not throw
try {
  $output = & $Iscc /Q "/O$OutputDir" (Join-Path $Root 'ci\tests\unit_tests.iss') 2>&1
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previous
}
if ($code -ne 0) {
  $output | ForEach-Object { "$_" } | Write-Host
  Write-Host "FAIL: the unit test setup does not compile (ISCC exit code $code)"
  exit 1
}

$exe = Join-Path $OutputDir 'unit_tests.exe'
# /SAMPLES: the byte samples of the contract (docs\contract-samples), which the writers of install.ini and of the
# manifest must reproduce (TestContractSamples)
$Samples = Join-Path $Root 'docs\contract-samples'
$process = Start-Process -FilePath $exe -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', "/RESULTS=$ResultFile", "/SAMPLES=$Samples") -Wait -PassThru
if (-not (Test-Path -LiteralPath $ResultFile -PathType Leaf)) {
  Write-Host "FAIL: no results written (unit_tests.exe exit code $($process.ExitCode))"
  exit 1
}
$lines = @(Get-Content -LiteralPath $ResultFile -Encoding UTF8)
$lines | Where-Object { $_ -notmatch '^PASS ' } | Write-Host
if ($lines.Count -gt 0 -and $lines[-1] -match '^RESULT: PASS') { exit 0 }
exit 1
