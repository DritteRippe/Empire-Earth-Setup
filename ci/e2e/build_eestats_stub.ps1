<#
.SYNOPSIS
  Builds the stand-in of EEStatsSetup.dll (ci\e2e\stub) for the placeholder builds of CI.

.DESCRIPTION
  The setups load EEStatsSetup.dll when they start (eestats.iss, no delayload). The placeholder
  generator (ci\make_placeholder_assets.py) writes a dummy file that Windows cannot load, so a
  placeholder setup stops with "Cannot Import dll" (error 193) before it does anything, and the
  scenarios of the job suite-e2e run the placeholder setups. The job compile therefore builds this
  stand-in first: a 32-bit DLL (Inno Setup is 32-bit) with the six functions of eestats.iss and
  fixed answers. The generator never touches a file that exists, so the stand-in stays.

  A file that already exists at -OutFile is never replaced (the real DLL of a contributor stays).
  Needs Visual Studio with the C++ tools (the windows-latest runners have them). The DLL is for
  test builds only: never in a release build, never shipped.

.PARAMETER OutFile
  Where the DLL goes, normally data\Add-on\DLLs\EEStats\EEStatsSetup.dll.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\e2e\build_eestats_stub.ps1 -OutFile data\Add-on\DLLs\EEStats\EEStatsSetup.dll
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$Exports = @('EEStats_runInVM', 'EEStats_getUID', 'EEStats_isWine', 'EEStats_getWineVersion',
  'EEStats_getProcessorArch', 'EEStats_getGpuVendorId')

if (Test-Path -LiteralPath $OutFile) {
  Write-Host "$OutFile exists: kept, the stand-in is not built."
  exit 0
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'vswhere.exe not found: Visual Studio with the C++ tools is needed.' }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'No Visual Studio with the C++ tools (x86 and x64) found.' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvarsall.bat'
$src = Join-Path $PSScriptRoot 'stub'

$work = Join-Path ([IO.Path]::GetTempPath()) ('eestats-stub-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $dll = Join-Path $work 'EEStatsSetup.dll'
  # A batch file: the quotes of the paths survive cmd only this way. /MT: no runtime DLL needed.
  $bat = Join-Path $work 'build.cmd'
  @(
    '@echo off',
    "call `"$vcvars`" x86 >nul || exit /b 1",
    "cl /nologo /LD /MT /O1 /W4 /WX `"$src\EEStatsSetup.c`" /Fo`"$work\EEStatsSetup.obj`" /Fe`"$dll`" /link /NOLOGO /DEF:`"$src\EEStatsSetup.def`" || exit /b 1",
    "dumpbin /nologo /exports `"$dll`" > `"$work\exports.txt`" || exit /b 1"
  ) | Set-Content -LiteralPath $bat -Encoding Ascii
  & cmd.exe /d /c $bat
  if ($LASTEXITCODE -ne 0) { throw "Building the stand-in failed (exit code $LASTEXITCODE)." }

  # 32-bit (machine 0x14C in the PE header) and every function of eestats.iss exported by its name
  $bytes = [IO.File]::ReadAllBytes($dll)
  $pe = [BitConverter]::ToInt32($bytes, 0x3C)
  $machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
  if ($machine -ne 0x14C) { throw ('The stand-in is not a 32-bit DLL (machine 0x{0:X}).' -f $machine) }
  $listed = Get-Content -LiteralPath (Join-Path $work 'exports.txt')
  foreach ($name in $Exports) {
    if (-not ($listed | Where-Object { $_ -match ('\s' + [regex]::Escape($name) + '\s*$') })) { throw "The stand-in does not export $name." }
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  Copy-Item -LiteralPath $dll -Destination $OutFile
  Write-Host "Stand-in of EEStatsSetup.dll (32-bit, $($Exports.Count) functions) written to $OutFile"
}
finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
