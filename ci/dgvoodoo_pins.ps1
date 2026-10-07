<#
.SYNOPSIS
  Checks pins\dgvoodoo.txt, the dgVoodoo entries of setup_is6.iss and the five dgVoodoo configurations
  of config\dgVoodoo.

.DESCRIPTION
  The setups install dgVoodoo (the DirectX 11/12 wrapper) into both game folders: three pinned files
  (pins\dgvoodoo.txt: DDraw.dll, D3DImm.dll and, on 64-bit Windows only, dgVoodooCpl.exe, with SHA-256 and
  size) and one of five configurations (config\dgVoodoo\dgVoodoo_<level>.conf, installed as dgVoodoo.conf).
  The configurations carry the window keys that decide whether the multiplayer lobby, the scenario editor and
  Alt+Tab work: fake fullscreen (FullscreenAttributes = fake), Alt+Enter off (DisableAltEnterToToggleScreenMode
  = true), no deferred screen mode switch (DeferredScreenModeSwitch = false) and Version 0x287
  (docs/adr/0005-compatibility-and-wrapper-defaults.md, amendment 2026-10-07).

  Without switches the script checks, in the repository:
    - pins\dgvoodoo.txt: the format (Read-DgVoodooPins in ci\build_helpers.ps1);
    - setup_is6.iss (Get-DgVoodooScriptProblems): DgVoodooVersion is the pinned version, #sub GameAddOnFiles
      names every pinned file (no wildcard), has Check: IsWin64 on dgVoodooCpl.exe only and one configuration
      entry per dgVoodoo level of [Components], and is called for both game folders;
    - config\dgVoodoo (Get-DgVoodooConfProblems): the bytes (ASCII, CRLF, no BOM), the window keys and the
      tier keys of each configuration, and that the five files differ only in OutputAPI and VRAM.
  Exit code 0 if everything is fine, 1 otherwise (CI: .github/workflows/build.yml).

  -DataRoot <folder> also compares the dgVoodoo files in <folder>\Add-on\DirectX_Wrapper\dgVoodoo_bin (the
  data\ folder of a build) with the pins (Test-DgVoodooFiles). ci\build.ps1 does the same when it builds
  the real data.

  -SelfTest runs the checks against changed copies of the repository that must fail (and an unchanged copy
  that must pass).

.PARAMETER DataRoot
  The data folder whose dgVoodoo files are compared with the pins (the folder that holds Add-on\).

.PARAMETER SelfTest
  Check the check itself.

.PARAMETER Root
  The repository (default: the parent folder of ci\).

.EXAMPLE
  pwsh ci/dgvoodoo_pins.ps1

.EXAMPLE
  pwsh ci/dgvoodoo_pins.ps1 -DataRoot D:\realdata\data
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$DataRoot,
  [switch]$SelfTest,
  [string]$Root
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'build_helpers.ps1')
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }

# Problems of the repository $RepoRoot (an empty list if none) and the summary line for the success case.
# $DataFolder: the data folder to compare with the pins ('' = none).
function Get-DgVoodooPinProblems([string]$RepoRoot, [string]$DataFolder) {
  $problems = [System.Collections.Generic.List[string]]::new()
  try {
    $pins = Read-DgVoodooPins (Join-Path $RepoRoot $DgVoodooPinFile)
  } catch {
    $problems.Add($_.Exception.Message)
    return [pscustomobject]@{ Problems = $problems.ToArray(); Summary = '' }
  }
  foreach ($problem in @(Get-DgVoodooScriptProblems $RepoRoot $pins)) { $problems.Add($problem) }
  foreach ($problem in @(Get-DgVoodooConfProblems $RepoRoot $pins)) { $problems.Add($problem) }
  $summary = "$DgVoodooPinFile`: dgVoodoo $($pins.Version), $($pins.Files.Count) files; $DgVoodooConfFolder`: $($DgVoodooConfTiers.Count) configurations with the window keys of ADR 0005"
  if ($DataFolder) {
    $folder = Join-Path $DataFolder 'Add-on\DirectX_Wrapper\dgVoodoo_bin'
    foreach ($item in @(Test-DgVoodooFiles $folder $pins)) { $problems.Add($item.Problem) }
    $summary += "; the files of $folder are the pinned ones"
  }
  return [pscustomobject]@{ Problems = $problems.ToArray(); Summary = $summary }
}

# Changes the text of $Text at the first match of the regular expression $Pattern; throws if there is none
# (a mutant that changes nothing would test nothing)
function Edit-Text([string]$Text, [string]$Pattern, [string]$Replacement) {
  $regex = [regex]::new($Pattern)
  if (-not $regex.IsMatch($Text)) { throw "self-test: '$Pattern' not found" }
  return $regex.Replace($Text, $Replacement, 1)
}

function Invoke-SelfTest {
  $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-dgvoodoo-pins-' + [System.Guid]::NewGuid().ToString('N'))
  $latin1 = [System.Text.Encoding]::GetEncoding(28591)
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  $utf8Bom = [System.Text.UTF8Encoding]::new($true)
  $script:SelfCount = 0
  $script:SelfFailures = 0
  try {
    $copy = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path (Join-Path $copy 'pins') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $copy $DgVoodooConfFolder) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'setup_is6.iss') -Destination $copy
    Copy-Item -LiteralPath (Join-Path $Root $DgVoodooPinFile) -Destination (Join-Path $copy 'pins')
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Root $DgVoodooConfFolder) -Filter '*.conf' -File) {
      Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $copy $DgVoodooConfFolder)
    }
    $files = @{
      pins = Join-Path $copy $DgVoodooPinFile
      setup = Join-Path $copy 'setup_is6.iss'
      lvl10 = Join-Path $copy "$DgVoodooConfFolder\dgVoodoo_DX11_LVL10.conf"
      lvl11 = Join-Path $copy "$DgVoodooConfFolder\dgVoodoo_DX11_LVL11.conf"
    }
    $original = @{}
    foreach ($key in $files.Keys) { $original[$key] = [System.IO.File]::ReadAllBytes($files[$key]) }
    $texts = @{
      pins = $utf8.GetString($original['pins'])
      setup = [System.IO.File]::ReadAllText($files['setup'])
      lvl10 = $latin1.GetString($original['lvl10'])
      lvl11 = $latin1.GetString($original['lvl11'])
    }
    # The data of the pin lines to change
    $pinLines = @($texts['pins'] -split "`n" | Where-Object { $_ -like 'File *' })
    $ddraw = @($pinLines | Where-Object { $_ -like 'File * DDraw.dll *' })[0]
    $d3dimm = @($pinLines | Where-Object { $_ -like 'File * D3DImm.dll *' })[0]

    function Write-Case([string]$Key, [string]$Text) {
      if ($Key -eq 'pins') { [System.IO.File]::WriteAllBytes($files[$Key], $utf8.GetBytes($Text)) }
      elseif ($Key -eq 'setup') { [System.IO.File]::WriteAllText($files[$Key], $Text, $utf8Bom) }
      else { [System.IO.File]::WriteAllBytes($files[$Key], $latin1.GetBytes($Text)) }
    }
    # Runs the check on the changed copy; $Fragment: text that a problem must contain ('' = the copy must pass)
    function Expect([string]$Name, [string]$Fragment) {
      $script:SelfCount++
      $result = Get-DgVoodooPinProblems $copy ''
      if ($Fragment -eq '') {
        if ($result.Problems.Count -ne 0) { $script:SelfFailures++; Write-Host "FAIL self-test ${Name}: the check failed: $($result.Problems -join '; ')" }
        return
      }
      if ($result.Problems.Count -eq 0) { $script:SelfFailures++; Write-Host "FAIL self-test ${Name}: the check passed"; return }
      if (@($result.Problems | Where-Object { $_.Contains($Fragment) }).Count -eq 0) {
        $script:SelfFailures++
        Write-Host "FAIL self-test ${Name}: no problem names '$Fragment': $($result.Problems -join '; ')"
      }
    }
    function Restore {
      foreach ($key in $files.Keys) { [System.IO.File]::WriteAllBytes($files[$key], $original[$key]) }
    }
    # [name, file key, scriptblock text -> text, fragment of the expected problem]
    $cases = @(
      @('pins: a BOM', 'pins', { param($t) [string][char]0xFEFF + $t }, 'BOM'),
      @('pins: CRLF line ends', 'pins', { param($t) $t.Replace("`n", "`r`n") }, 'has a CR'),
      @('pins: no LF at the end', 'pins', { param($t) $t.TrimEnd("`n") }, 'no LF'),
      @('pins: uppercase hex digits', 'pins', { param($t) $t.Replace($ddraw, 'File ' + $ddraw.Substring(5, 64).ToUpperInvariant() + $ddraw.Substring(69)) }, 'lowercase hex'),
      @('pins: a short hash', 'pins', { param($t) $t.Replace($ddraw, 'File ' + $ddraw.Substring(6)) }, 'lowercase hex'),
      @('pins: a size of 0', 'pins', { param($t) $t.Replace($ddraw, ($ddraw -replace '^(File \S+) \d+ ', '$1 0 ')) }, 'at least 1'),
      @('pins: a size with a leading zero', 'pins', { param($t) $t.Replace($ddraw, ($ddraw -replace '^(File \S+) (\d+) ', '$1 0$2 ')) }, 'leading zeros'),
      @('pins: an unknown line', 'pins', { param($t) $t.Replace("Version v2.87.5`n", "Version v2.87.5`nFoo bar`n") }, 'unknown line'),
      @('pins: Version v2.87.4', 'pins', { param($t) $t.Replace('Version v2.87.5', 'Version v2.87.4') }, 'DgVoodooVersion'),
      @('pins: File lines swapped (order)', 'pins', { param($t) $t.Replace("$d3dimm`n$ddraw`n", "$ddraw`n$d3dimm`n") }, 'ordinal order'),
      @('pins: the DDraw.dll line removed', 'pins', { param($t) $t.Replace("$ddraw`n", '') }, 'DDraw.dll'),
      @('pins: a File line of D3D9.dll', 'pins', { param($t) $t.Replace("$d3dimm`n", "File $('a' * 64) 5 D3D9.dll MS/x86/D3D9.dll`n$d3dimm`n") }, 'D3D9.dll'),
      @('pins: Archive with http://', 'pins', { param($t) $t.Replace(' https://github.com', ' http://github.com') }, 'https://'),
      @('pins: Archive missing', 'pins', { param($t) Edit-Text $t '(?m)^Archive [^\n]*\n' '' }, 'Archive'),
      @('setup: DgVoodooVersion v2.87.4', 'setup', { param($t) $t.Replace('#define DgVoodooVersion "v2.87.5"', '#define DgVoodooVersion "v2.87.4"') }, 'DgVoodooVersion'),
      @('setup: the wildcard back', 'setup', { param($t) $t.Replace('dgVoodoo_bin\DDraw.dll"', 'dgVoodoo_bin\*"') }, 'wildcard'),
      @('setup: dgVoodooCpl.exe without Check: IsWin64', 'setup', { param($t) $t.Replace('and not additional\directx_wrapper\dx7; Check: IsWin64; AfterInstall', 'and not additional\directx_wrapper\dx7; AfterInstall') }, 'dgVoodooCpl.exe (x64 only) needs Check: IsWin64'),
      @('setup: Check: IsWin64 on DDraw.dll', 'setup', { param($t) Edit-Text $t '(dgVoodoo_bin\\DDraw\.dll"[^\r\n]*?dx7; )AfterInstall' '${1}Check: IsWin64; AfterInstall' }, 'Check: IsWin64 on'),
      @('setup: the configuration of dx11_lvl11 from the old folder', 'setup', { param($t) $t.Replace('Source: "config\dgVoodoo\dgVoodoo_DX11_LVL11.conf"', 'Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL11.conf"') }, 'dgVoodoo_conf'),
      @('setup: the configuration entry of dx12_lvl12 removed', 'setup', { param($t) Edit-Text $t '(?m)^Source: "config\\dgVoodoo\\dgVoodoo_DX12_LVL12\.conf"[^\r\n]*\r?\n' '' }, 'DX12_LVL12'),
      @('setup: DestName dgVoodoo.ini', 'setup', { param($t) Edit-Text $t '(dgVoodoo_DX11_LVL11\.conf"; DestDir: "[^"]*"; DestName: ")dgVoodoo\.conf' '${1}dgVoodoo.ini' }, 'DestName'),
      @('setup: DestDir {#EEDir} on the configuration of dx11_lvl11', 'setup', { param($t) Edit-Text $t '(dgVoodoo_DX11_LVL11\.conf"; DestDir: ")\{app\}\\\{#AddOnDir\}' '${1}{app}\{#EEDir}' }, 'needs DestDir'),
      @('setup: DestDir {#EEDir} on DDraw.dll', 'setup', { param($t) Edit-Text $t '(dgVoodoo_bin\\DDraw\.dll"; DestDir: ")\{app\}\\\{#AddOnDir\}' '${1}{app}\{#EEDir}' }, 'needs DestDir'),
      @('setup: {#AddOnComp} replaced by game on the configuration of dx12_lvl12', 'setup', { param($t) Edit-Text $t '(dgVoodoo_DX12_LVL12\.conf"[^\r\n]*?dx12_lvl12 and )\{#AddOnComp\}' '${1}game' }, 'configuration of dx12_lvl12 must be installed'),
      @('setup: {#AddOnComp} replaced by game on D3DImm.dll', 'setup', { param($t) Edit-Text $t '(dgVoodoo_bin\\D3DImm\.dll"[^\r\n]*?directx_wrapper and )\{#AddOnComp\}' '${1}game' }, 'D3DImm.dll must be installed with'),
      @('setup: and not ...\dx9 removed from DDraw.dll', 'setup', { param($t) Edit-Text $t '(dgVoodoo_bin\\DDraw\.dll"[^\r\n]*?) and not additional\\directx_wrapper\\dx9' '$1' }, 'DDraw.dll must be installed with'),
      @('setup: and not ...\dx7 removed from dgVoodooCpl.exe', 'setup', { param($t) Edit-Text $t '(dgVoodoo_bin\\dgVoodooCpl\.exe"[^\r\n]*?) and not additional\\directx_wrapper\\dx7' '$1' }, 'dgVoodooCpl.exe must be installed with'),
      @('setup: the call of GameAddOnFiles for AoCDir removed', 'setup', { param($t) Edit-Text $t '(?m)^(#expr AddOnDir = AoCDir[^\r\n]*\r?\n)#call GameAddOnFiles\r?\n' '$1' }, 'AoCDir'),
      @('conf: LF line ends', 'lvl11', { param($t) $t.Replace("`r`n", "`n") }, 'CRLF'),
      @('conf: a BOM', 'lvl11', { param($t) [string][char]0xEF + [char]0xBB + [char]0xBF + $t }, 'BOM'),
      @('conf: no final CRLF', 'lvl11', { param($t) $t.Substring(0, $t.Length - 2) }, 'does not end with CRLF'),
      @('conf: DeferredScreenModeSwitch = true', 'lvl11', { param($t) Edit-Text $t '(DeferredScreenModeSwitch\s*= )false' '${1}true' }, 'DeferredScreenModeSwitch'),
      @('conf: DisableAltEnterToToggleScreenMode = false', 'lvl11', { param($t) Edit-Text $t '(DisableAltEnterToToggleScreenMode\s*= )true' '${1}false' }, 'DisableAltEnterToToggleScreenMode'),
      @('conf: FullscreenAttributes removed', 'lvl11', { param($t) Edit-Text $t '(?m)^FullscreenAttributes[^\r\n]*\r\n' '' }, 'FullscreenAttributes is missing'),
      @('conf: FullscreenAttributes = fake, x', 'lvl11', { param($t) Edit-Text $t '(FullscreenAttributes\s*= )fake' '${1}fake, x' }, 'FullscreenAttributes'),
      @('conf: Version = 0x282', 'lvl11', { param($t) Edit-Text $t '(Version\s*= )0x287' '${1}0x282' }, 'Version = 0x282'),
      @('conf: AppControlledScreenMode = false', 'lvl11', { param($t) Edit-Text $t '(AppControlledScreenMode\s*= )true' '${1}false' }, 'AppControlledScreenMode'),
      @('conf: LVL10 OutputAPI = d3d11_fl11_0', 'lvl10', { param($t) Edit-Text $t '(OutputAPI\s*= )d3d11_fl10_0' '${1}d3d11_fl11_0' }, 'OutputAPI'),
      @('conf: LVL10 VRAM = 256', 'lvl10', { param($t) Edit-Text $t '(VRAM\s*= )128' '${1}256' }, 'VRAM'),
      @('conf: dgVoodooWatermark = true', 'lvl11', { param($t) Edit-Text $t '(dgVoodooWatermark\s*= )false' '${1}true' }, 'dgVoodooWatermark'),
      @('conf: a key twice in [DirectX]', 'lvl11', { param($t) Edit-Text $t '(?m)^(Resolution[^\r\n]*\r\n)' '$1$1' }, 'set twice'),
      @('conf: WindowedAttributes changed in one conf only', 'lvl11', { param($t) Edit-Text $t '(= Borderless, AlwaysOnTop), FullscreenSize' '$1' }, 'differs from'),
      @('conf: a non-ASCII character in a comment', 'lvl11', { param($t) Edit-Text $t '; Antialiasing' ('; ' + [char]0xE9 + ' Antialiasing') }, 'non-ASCII')
    )
    Restore
    Expect 'unchanged copy' ''
    foreach ($case in $cases) {
      Write-Case $case[1] ([string](& $case[2] $texts[$case[1]]))
      Expect $case[0] $case[3]
      Restore
    }
    # A missing configuration and a configuration of no level
    Remove-Item -LiteralPath $files['lvl10']
    Expect 'conf: the configuration of DX11_LVL10 missing' 'dgVoodoo_DX11_LVL10.conf: missing'
    Restore
    [System.IO.File]::WriteAllBytes((Join-Path $copy "$DgVoodooConfFolder\dgVoodoo_DX13_LVL13.conf"), $original['lvl10'])
    Expect 'conf: a configuration of no level' 'not the configuration of a dgVoodoo level'
    Remove-Item -LiteralPath (Join-Path $copy "$DgVoodooConfFolder\dgVoodoo_DX13_LVL13.conf")
    Remove-Item -LiteralPath $files['pins']
    Expect 'pins: the list missing' 'not found'
    Restore
    Expect 'unchanged copy again' ''

    # -DataRoot: made-up files and pins that match them (the real files are not in the repository)
    $data = Join-Path $temp 'data\Add-on\DirectX_Wrapper\dgVoodoo_bin'
    New-Item -ItemType Directory -Path $data -Force | Out-Null
    $sha = [System.Security.Cryptography.SHA256]::Create()
    function Get-TestHash([byte[]]$Bytes) { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    $made = @{ 'D3DImm.dll' = [byte[]](1..40); 'DDraw.dll' = [byte[]](50..120); 'dgVoodooCpl.exe' = [byte[]](130..255) }
    $pinText = $texts['pins']
    foreach ($name in $made.Keys) {
      [System.IO.File]::WriteAllBytes((Join-Path $data $name), $made[$name])
      $line = @($pinText -split "`n" | Where-Object { $_ -like "File * $name *" })[0]
      $new = 'File ' + (Get-TestHash $made[$name]) + ' ' + $made[$name].Length + ' ' + $name + ' ' + ($line -split ' ')[4]
      $pinText = $pinText.Replace($line, $new)
    }
    [System.IO.File]::WriteAllBytes($files['pins'], $utf8.GetBytes($pinText))
    $madePins = Read-DgVoodooPins $files['pins']
    function Expect-Data([string]$Name, [string]$Fragment, [bool]$Placeholder) {
      $script:SelfCount++
      $items = @(Test-DgVoodooFiles $data $madePins)
      $found = @($items | Where-Object { $Fragment -ne '' -and $_.Problem.Contains($Fragment) })
      if ($Fragment -eq '') {
        if ($items.Count -ne 0) { $script:SelfFailures++; Write-Host "FAIL self-test ${Name}: $($items[0].Problem)" }
      } elseif ($found.Count -eq 0 -or $found[0].Placeholder -ne $Placeholder) {
        $script:SelfFailures++
        Write-Host "FAIL self-test ${Name}: expected a problem with '$Fragment' (placeholder $Placeholder), got $(@($items | ForEach-Object { $_.Problem + ' [' + $_.Placeholder + ']' }) -join '; ')"
      }
    }
    Expect-Data 'data: all three files right' '' $false
    [System.IO.File]::WriteAllBytes((Join-Path $data 'DDraw.dll'), [byte[]]($made['DDraw.dll'] + [byte]1))
    Expect-Data 'data: DDraw.dll one byte longer' 'DDraw.dll: 72 bytes' $false
    [System.IO.File]::WriteAllBytes((Join-Path $data 'DDraw.dll'), $made['DDraw.dll'])
    $other = [byte[]]$made['D3DImm.dll'].Clone()
    $other[0] = 99
    [System.IO.File]::WriteAllBytes((Join-Path $data 'D3DImm.dll'), $other)
    Expect-Data 'data: D3DImm.dll with another hash and the same size' 'D3DImm.dll: SHA-256' $false
    [System.IO.File]::WriteAllBytes((Join-Path $data 'D3DImm.dll'), $made['D3DImm.dll'])
    Remove-Item -LiteralPath (Join-Path $data 'dgVoodooCpl.exe')
    Expect-Data 'data: dgVoodooCpl.exe missing' 'dgVoodooCpl.exe: missing' $false
    [System.IO.File]::WriteAllText((Join-Path $data 'dgVoodooCpl.exe'), "placeholder generated by ci/make_placeholder_assets.py - not a real asset`n", $utf8)
    Expect-Data 'data: the placeholder text' 'is a placeholder' $true
    $sha.Dispose()
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($script:SelfFailures -eq 0) {
    Write-Host "self-test: PASS ($script:SelfCount cases)"
    return 0
  }
  Write-Host "self-test: FAIL ($script:SelfFailures of $script:SelfCount cases)"
  return 1
}

if ($SelfTest) { exit (Invoke-SelfTest) }

$dataFolder = ''
if ($DataRoot) { $dataFolder = $DataRoot }
$result = Get-DgVoodooPinProblems $Root $dataFolder
if ($result.Problems.Count -gt 0) {
  foreach ($problem in $result.Problems) { Write-Host "ERROR $problem" }
  Write-Host "dgVoodoo: $($result.Problems.Count) problem(s); see docs\adr\0005-compatibility-and-wrapper-defaults.md (amendment 2026-10-07)"
  exit 1
}
Write-Host $result.Summary
exit 0
