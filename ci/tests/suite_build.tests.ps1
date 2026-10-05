<#
.SYNOPSIS
  Tests of suite\build_suite.ps1 and ci\suite_build_helpers.ps1 (the build of the suite installer,
  ADR 0013) on made-up inputs.

.DESCRIPTION
  Needs neither Inno Setup nor game data. The helpers are tested directly (checksum files, slice
  sets, limits, comparison of two builds, folder digest, slice size of the placeholder build); the
  script is run in a temporary copy of the repository with a fake ISCC that writes a setup program
  and slices of a made-up size and can be told to misbehave (FAKE_ISCC_MODE: fail, unstable,
  countmismatch, nobins, bigbin, foreign): a placeholder build, a real build with made-up inputs,
  the stops of the script (dummy AppId in a real build, a changed input, ISCC version, an unstable
  build, a slice over the limit, ...). Runs with Windows PowerShell 5.1 and PowerShell 7 (also on
  Linux), on the Windows runner of CI. Prints the failed checks and exits with 0 if every check
  passed, else 1.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\tests\suite_build.tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ciDir = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $ciDir
. (Join-Path $ciDir 'build_helpers.ps1')
. (Join-Path $ciDir 'suite_build_helpers.ps1')

$script:Count = 0
$script:Failures = 0
function Check([string]$Name, $Actual, $Expected) {
  $script:Count++
  if ("$Actual" -ceq "$Expected") { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: got '$Actual', expected '$Expected'"
}
# The block must throw, and the message must contain $Like (a wildcard pattern)
function CheckThrows([string]$Name, [scriptblock]$Block, [string]$Like = '*') {
  $script:Count++
  try { & $Block *>&1 | Out-Null } catch {
    if ($_.Exception.Message -notlike $Like) {
      $script:Failures++
      Write-Host "FAIL ${Name}: the message '$($_.Exception.Message)' does not match '$Like'"
    }
    return
  }
  $script:Failures++
  Write-Host "FAIL ${Name}: no exception"
}

# Deterministic bytes: a repeated block of 251 values, shifted by $Seed
function New-Bytes([int]$Length, [int]$Seed) {
  $block = New-Object byte[] 251
  for ($i = 0; $i -lt 251; $i++) { $block[$i] = [byte](($i + $Seed) % 251) }
  $bytes = New-Object byte[] $Length
  for ($offset = 0; $offset -lt $Length; $offset += 251) {
    [Buffer]::BlockCopy($block, 0, $bytes, $offset, [Math]::Min(251, $Length - $offset))
  }
  return ,$bytes
}
function New-TestFile([string]$Path, [int]$Length, [int]$Seed) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
  [System.IO.File]::WriteAllBytes($Path, (New-Bytes $Length $Seed))
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('suite_build_tests_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$savedMode = $env:FAKE_ISCC_MODE
$savedVersion = $env:FAKE_ISCC_VERSION
try {
  # --- Read-Sha256File, Assert-InputChecksum ----------------------------------------------------
  $inDir = Join-Path $temp 'inputs'
  New-TestFile (Join-Path $inDir 'a.exe') 1000 1
  [void](Write-FileSha256 (Join-Path $inDir 'a.exe'))
  $read = Read-Sha256File (Join-Path $inDir 'a.exe.sha256')
  Check 'Read-Sha256File: name' $read.Name 'a.exe'
  Check 'Read-Sha256File: hash' $read.Hash ((Get-FileHash -LiteralPath (Join-Path $inDir 'a.exe') -Algorithm SHA256).Hash.ToLowerInvariant())
  $checked = Assert-InputChecksum (Join-Path $inDir 'a.exe') 'test'
  Check 'Assert-InputChecksum: size' $checked.Size 1000
  Check 'Assert-InputChecksum: hash' $checked.Hash $read.Hash
  Set-Content -LiteralPath (Join-Path $inDir 'bad.sha256') -Value 'not a checksum'
  CheckThrows 'Read-Sha256File: bad format' { Read-Sha256File (Join-Path $inDir 'bad.sha256') } '*sha256sum format*'
  CheckThrows 'Read-Sha256File: missing' { Read-Sha256File (Join-Path $inDir 'none.sha256') } '*not found*'
  CheckThrows 'Assert-InputChecksum: missing file' { Assert-InputChecksum (Join-Path $inDir 'none.exe') 'test' } '*not found*'
  New-TestFile (Join-Path $inDir 'b.exe') 1000 2
  CheckThrows 'Assert-InputChecksum: no checksum file' { Assert-InputChecksum (Join-Path $inDir 'b.exe') 'test' } '*not found*'
  Copy-Item -LiteralPath (Join-Path $inDir 'a.exe.sha256') -Destination (Join-Path $inDir 'b.exe.sha256')
  CheckThrows 'Assert-InputChecksum: the checksum file names another file' { Assert-InputChecksum (Join-Path $inDir 'b.exe') 'test' } "*names 'a.exe'*"
  [System.IO.File]::WriteAllBytes((Join-Path $inDir 'a.exe'), (New-Bytes 1000 3))
  CheckThrows 'Assert-InputChecksum: changed file' { Assert-InputChecksum (Join-Path $inDir 'a.exe') 'test' } '*SHA-256 of*'

  # --- Get-PlaceholderSliceSize -------------------------------------------------------------------
  Check 'slice size: 300000' (Get-PlaceholderSliceSize 300000) 393216
  Check 'slice size: exactly a multiple' (Get-PlaceholderSliceSize 262144) 327680
  Check 'slice size: tiny setup, minimum' (Get-PlaceholderSliceSize 100) 262144
  Check 'slice size: never below the setup program' ((Get-PlaceholderSliceSize 3200001) -ge 3200001) $true
  CheckThrows 'slice size: more than the limit' { Get-PlaceholderSliceSize 49990000 } '*more than the limit*'
  CheckThrows 'slice size: zero' { Get-PlaceholderSliceSize 0 } '*not valid*'

  # --- Get-SuiteSliceInfo, Test-SuiteSliceLimit, Compare-SuiteBuilds ----------------------------------
  $base = 'Empire Earth Community Setup'
  function New-SliceFolder([string]$Name, [int[]]$Numbers, [int]$Seed) {
    $dir = Join-Path $temp $Name
    New-TestFile (Join-Path $dir "$base.exe") 500 $Seed
    foreach ($n in $Numbers) { New-TestFile (Join-Path $dir "$base-$n.bin") (100 + $n) ($Seed + $n) }
    return $dir
  }
  $info = Get-SuiteSliceInfo (New-SliceFolder 's_ok' @(1, 2, 3) 5) $base
  Check 'slice info: count' $info.Count 3
  Check 'slice info: total (the .bin files only)' $info.Total (101 + 102 + 103)
  Check 'slice info: order' (($info.Slices | ForEach-Object { $_.Name }) -join '|') "$base-1.bin|$base-2.bin|$base-3.bin"
  $ten = Get-SuiteSliceInfo (New-SliceFolder 's_ten' @(1..11) 5) $base
  Check 'slice info: numeric order past 9' $ten.Slices[9].Name "$base-10.bin"
  CheckThrows 'slice info: a gap' { Get-SuiteSliceInfo (New-SliceFolder 's_gap' @(1, 3) 5) $base } '*without a gap*'
  CheckThrows 'slice info: slice 0' { Get-SuiteSliceInfo (New-SliceFolder 's_zero' @(0, 1) 5) $base } '*without a gap*'
  $dir = New-SliceFolder 's_stray' @(1) 5
  New-TestFile (Join-Path $dir 'stray.txt') 10 1
  CheckThrows 'slice info: unknown file' { Get-SuiteSliceInfo $dir $base } '*unexpected file*stray.txt*'
  $dir = New-SliceFolder 's_noexe' @(1) 5
  Remove-Item -LiteralPath (Join-Path $dir "$base.exe")
  CheckThrows 'slice info: no setup program' { Get-SuiteSliceInfo $dir $base } '*was not built*'
  $dir = New-SliceFolder 's_empty' @(1) 5
  [System.IO.File]::WriteAllBytes((Join-Path $dir "$base-1.bin"), [byte[]]@())
  CheckThrows 'slice info: empty slice' { Get-SuiteSliceInfo $dir $base } '*is empty*'
  Check 'slice info: no slices is count 0' (Get-SuiteSliceInfo (New-SliceFolder 's_none' @() 5) $base).Count 0

  Check 'limit: all within' @(Test-SuiteSliceLimit $info 600).Count 0
  Check 'limit: a file over' @(Test-SuiteSliceLimit $info 102).Count 2   # slice 3 (103) and the program (500)
  Check 'limit: names the file' ((@(Test-SuiteSliceLimit $info 102)) -join '|' -like "*$base-3.bin is 103 bytes*") $true

  $same = Get-SuiteSliceInfo (New-SliceFolder 's_same' @(1, 2, 3) 5) $base
  Check 'compare: identical builds' @(Compare-SuiteBuilds $info $same).Count 0
  $other = Get-SuiteSliceInfo (New-SliceFolder 's_other' @(1, 2, 3) 6) $base
  Check 'compare: other bytes' (@(Compare-SuiteBuilds $info $other) | Where-Object { $_ -like '*differs in its bytes' }).Count 4
  $fewer = Get-SuiteSliceInfo (New-SliceFolder 's_fewer' @(1, 2) 5) $base
  $problems = @(Compare-SuiteBuilds $info $fewer)
  Check 'compare: count and total differ' $problems.Count 2
  Check 'compare: names the count' ($problems[0] -like 'slice count 3 against 2') $true

  # --- Get-TreeDigest, Assert-CommitText ------------------------------------------------------------
  $tree = Join-Path $temp 'tree'
  New-TestFile (Join-Path $tree 'a.dll') 100 1
  New-TestFile (Join-Path $tree 'sub\b.txt') 50 2
  New-TestFile (Join-Path $tree 'x.pdb') 70 3
  $digest = Get-TreeDigest $tree
  Check 'digest: files without the .pdb' $digest.Files 2
  Check 'digest: bytes' $digest.Bytes 150
  Check 'digest: 64 hex digits' ($digest.Digest -cmatch '^[0-9a-f]{64}\z') $true
  New-TestFile (Join-Path $tree 'x.pdb') 71 4
  Check 'digest: a .pdb changes nothing' (Get-TreeDigest $tree).Digest $digest.Digest
  New-TestFile (Join-Path $tree 'sub\b.txt') 50 9
  Check 'digest: a changed file changes it' ((Get-TreeDigest $tree).Digest -ceq $digest.Digest) $false
  CheckThrows 'digest: missing folder' { Get-TreeDigest (Join-Path $temp 'nope') } '*not found*'
  Check 'commit: valid' (Assert-CommitText 'abc1234' '-x') 'abc1234'
  Check 'commit: none' (Assert-CommitText '' '-x') ''
  CheckThrows 'commit: upper case' { Assert-CommitText 'ABC1234' '-x' } '*lower-case hex*'
  CheckThrows 'commit: too short' { Assert-CommitText 'abc12' '-x' } '*lower-case hex*'

  # --- the script with a fake ISCC ----------------------------------------------------------------
  $repo = Join-Path $temp 'repo'
  New-Item -ItemType Directory -Path (Join-Path $repo 'suite') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $repo 'ci') | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'suite\build_suite.ps1') -Destination (Join-Path $repo 'suite')
  foreach ($name in @('build_helpers.ps1', 'suite_build_helpers.ps1')) { Copy-Item -LiteralPath (Join-Path $ciDir $name) -Destination (Join-Path $repo 'ci') }
  Set-Content -LiteralPath (Join-Path $repo 'suite\suite.iss') -Value '#define SuiteVersion "9.9.9"'
  $build = Join-Path $repo 'suite\build_suite.ps1'
  # The placeholder product setups of ci\build.ps1 -Placeholders, with their .sha256
  New-TestFile (Join-Path $repo 'out\EE_Regular\EE_Setup_Test.exe') 400000 11
  New-TestFile (Join-Path $repo 'out\NeoEE_Regular\NeoEE_Setup_Test.exe') 500000 12
  [void](Write-FileSha256 (Join-Path $repo 'out\EE_Regular\EE_Setup_Test.exe'))
  [void](Write-FileSha256 (Join-Path $repo 'out\NeoEE_Regular\NeoEE_Setup_Test.exe'))

  $calls = Join-Path $temp 'iscc_calls.txt'
  $marker = Join-Path $temp 'fake_marker'
  $fakeIscc = Join-Path $temp 'fake_iscc.ps1'
  # The fake: a setup program of 300000 bytes, slices of DiskSliceSize for a payload of the two
  # product setups plus 20000 bytes, like Inno Setup the same bytes for the same /D switches
  $fake = @'
$a = @($args)
$script = [string]$a[-1]
if ($script -like '*version_probe.iss') {
  if ($env:FAKE_ISCC_VERSION) { 'ISCC_VERSION=' + $env:FAKE_ISCC_VERSION } else { 'ISCC_VERSION=6.2.2' }
  exit 0
}
Add-Content -LiteralPath '%CALLS%' -Value ($a -join ' ')
$out = ''
$d = @{}
foreach ($x in $a) {
  if ($x -like '/O*') { $out = $x.Substring(2) }
  elseif ($x -like '/D*') { $p = $x.Substring(2).Split([char[]]'=', 2); $d[$p[0]] = $p[1] }
}
$mode = $env:FAKE_ISCC_MODE
if ($mode -eq 'fail') { 'Error on line 1: simulated'; exit 1 }
$pass1 = $d.ContainsKey('SlicePass1')
$size = [long]50000000
if ($d.ContainsKey('SliceSize')) { $size = [long]$d['SliceSize'] }
$name = 'Empire Earth Community Setup'
if ($pass1) { $name += ' PASS1 DO NOT SHIP' }
$exeSize = 300000
if ($exeSize -gt $size) { 'Error: DiskSliceSize is smaller than the setup program'; exit 2 }
function Fill([int]$Length, [int]$Seed) {
  $block = New-Object byte[] 251
  for ($i = 0; $i -lt 251; $i++) { $block[$i] = [byte](($i + $Seed) % 251) }
  $bytes = New-Object byte[] $Length
  for ($o = 0; $o -lt $Length; $o += 251) { [Buffer]::BlockCopy($block, 0, $bytes, $o, [Math]::Min(251, $Length - $o)) }
  return ,$bytes
}
# the program depends on the switches (not on /O), like the real one on the compiled-in numbers
$key = (($d.Keys | Sort-Object | ForEach-Object { "$_=$($d[$_])" }) -join ';')
$exe = Fill $exeSize 7
$keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
[Buffer]::BlockCopy($keyBytes, 0, $exe, 0, [Math]::Min($keyBytes.Length, $exeSize))
if ($mode -eq 'unstable' -and -not $pass1) {
  if (Test-Path -LiteralPath '%MARKER%') { $exe[$exeSize - 1] = 1 } else { Set-Content -LiteralPath '%MARKER%' -Value 'x' }
}
[System.IO.File]::WriteAllBytes((Join-Path $out "$name.exe"), $exe)
$payload = [long]$d['EESetupSize'] + [long]$d['NeoEESetupSize'] + 20000
if ($mode -eq 'nobins') { $payload = 0 }
$n = 0
while ($payload -gt 0) {
  $n++
  $length = [Math]::Min($size, $payload)
  $payload -= $length
  if ($mode -eq 'bigbin' -and $n -eq 1) { $length = $size + 1 }
  [System.IO.File]::WriteAllBytes((Join-Path $out "$name-$n.bin"), (Fill ([int]$length) $n))
}
if ($mode -eq 'countmismatch' -and -not $pass1) {
  $n++
  [System.IO.File]::WriteAllBytes((Join-Path $out "$name-$n.bin"), (Fill 1000 $n))
}
if ($mode -eq 'foreign') { Set-Content -LiteralPath (Join-Path $out 'stray.txt') -Value 'x' }
exit 0
'@
  [System.IO.File]::WriteAllText($fakeIscc, $fake.Replace('%CALLS%', $calls).Replace('%MARKER%', $marker))

  function Reset-Fake([string]$Mode) {
    $env:FAKE_ISCC_MODE = $Mode
    $env:FAKE_ISCC_VERSION = $null
    Remove-Item -LiteralPath $calls, $marker -Force -ErrorAction SilentlyContinue
  }
  function Get-Calls { if (Test-Path -LiteralPath $calls) { return @(Get-Content -LiteralPath $calls) } else { return @() } }
  # file names of a folder in ordinal order (the sort of the machine's culture differs)
  function Get-Names([string]$Dir) { $names = [string[]]@(Get-ChildItem -LiteralPath $Dir -File | ForEach-Object { $_.Name }); [Array]::Sort($names, [StringComparer]::Ordinal); return ($names -join '|') }
  $out = Join-Path $temp 'out_suite'

  # A placeholder build
  Reset-Fake ''
  & $build -Placeholders -Iscc $fakeIscc -RequireVersion 6.2.2 -OutputDir $out 3>$null 6>$null
  $lines = @(Get-Calls)
  Check 'placeholder build: ISCC calls (probe, pass 1, 2, 3)' $lines.Count 4
  Check 'placeholder build: the probe passes the largest slice size' ($lines[0] -like '*/DSlicePass1=1*/DSliceSize=50000000*') $true
  Check 'placeholder build: pass 1' ($lines[1] -like '*/DSlicePass1=1*/DSliceSize=393216*') $true
  Check 'placeholder build: pass 2 has count and total' ($lines[2] -like '*/DSliceSize=393216*/DSliceCount=3 /DSliceTotal=920000*') $true
  Check 'placeholder build: pass 3 is pass 2' ($lines[3].Replace('pass3', 'pass2') -ceq $lines[2].Replace('pass3', 'pass2')) $true
  Check 'placeholder build: dummy AppIds' ($lines[2] -like '*/DSuiteAppID=00000000-0000-0000-0000-0000000005EE /DEE_AppID=00000000-0000-0000-0000-0000000000EE /DNeoEE_AppID=00000000-0000-0000-0000-000000000AEE*') $true
  Check 'placeholder build: the product setups and their hashes' ($lines[2] -like '*/DEESetupFile=*EE_Setup_Test.exe /DEESetupSHA256=* /DEESetupSize=400000 /DNeoEESetupFile=*NeoEE_Setup_Test.exe /DNeoEESetupSHA256=* /DNeoEESetupSize=500000*') $true
  Check 'placeholder build: output files' (Get-Names $out) "BUILD-INFO.txt|$base-1.bin|$base-2.bin|$base-3.bin|$base.exe|SHA256SUMS.txt"
  Check 'placeholder build: nothing of pass 1' (@(Get-ChildItem -LiteralPath $out -File | Where-Object { $_.Name -like '*PASS1*' }).Count) 0
  $sums = @(Get-Content -LiteralPath (Join-Path $out 'SHA256SUMS.txt'))
  Check 'placeholder build: SHA256SUMS.txt lines (program and every slice)' $sums.Count 4
  Check 'placeholder build: SHA256SUMS.txt starts with the program' ($sums[0] -cmatch "^[0-9a-f]{64}  $base\.exe\z") $true
  $sumsOk = $true
  foreach ($line in $sums) {
    $m = [regex]::Match($line, '^([0-9a-f]{64})  (.+)$')
    if (-not $m.Success -or (Get-FileHash -LiteralPath (Join-Path $out $m.Groups[2].Value) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $m.Groups[1].Value) { $sumsOk = $false }
  }
  Check 'placeholder build: SHA256SUMS.txt matches the files' $sumsOk $true
  Check 'placeholder build: SHA256SUMS.txt is LF' ([System.IO.File]::ReadAllText((Join-Path $out 'SHA256SUMS.txt')).Contains("`r")) $false
  $buildInfo = [System.IO.File]::ReadAllText((Join-Path $out 'BUILD-INFO.txt'))
  Check 'BUILD-INFO: placeholder warning' ($buildInfo -like 'PLACEHOLDER BUILD*') $true
  Check 'BUILD-INFO: suite version' ($buildInfo -like '*Empire Earth Community Setup 9.9.9*') $true
  Check 'BUILD-INFO: ISCC version' ($buildInfo -like '*ISCC:                 6.2.2*') $true
  Check 'BUILD-INFO: EE setup hash' ($buildInfo -like "*$((Read-Sha256File (Join-Path $repo 'out\EE_Regular\EE_Setup_Test.exe.sha256')).Hash)  400000  EE_Setup_Test.exe*") $true
  Check 'BUILD-INFO: NeoEE setup hash' ($buildInfo -like "*$((Read-Sha256File (Join-Path $repo 'out\NeoEE_Regular\NeoEE_Setup_Test.exe.sha256')).Hash)  500000  NeoEE_Setup_Test.exe*") $true
  Check 'BUILD-INFO: slices' ($buildInfo -like '*Slices:               3, 920000 bytes in total, setup program 300000 bytes*') $true
  Check 'BUILD-INFO: slice size' ($buildInfo -like '*DiskSliceSize:        393216*') $true
  Check 'BUILD-INFO: the output hashes' ($buildInfo -like "*  $($sums[0])*") $true
  Check 'BUILD-INFO: no AppId' ($buildInfo -like '*0000-0000*') $false
  
  # A second run replaces what the first one wrote, and only that
  Set-Content -LiteralPath (Join-Path $out "$base-9.bin") -Value 'stale'
  Set-Content -LiteralPath (Join-Path $out 'keep.txt') -Value 'mine'
  Reset-Fake ''
  & $build -Placeholders -Iscc $fakeIscc -OutputDir $out 3>$null 6>$null
  Check 'second run: stale slice gone, foreign file kept' (Get-Names $out) "BUILD-INFO.txt|$base-1.bin|$base-2.bin|$base-3.bin|$base.exe|SHA256SUMS.txt|keep.txt"

  # An explicit slice size, a test build, install sizes
  Reset-Fake ''
  $out2 = Join-Path $temp 'out_suite2'
  & $build -Placeholders -Iscc $fakeIscc -OutputDir $out2 -SliceSize 450000 -TestID 2 -EEInstallSize 123 3>$null 6>$null
  $lines = @(Get-Calls)
  Check 'explicit slice size: no probe (pass 1, 2, 3)' $lines.Count 3
  Check 'explicit slice size: used' ($lines[0] -like '*/DSliceSize=450000*') $true
  Check 'test build: TestID passed' ($lines[1] -like '*/DTestID=2*') $true
  Check 'install size passed, the other one not' (($lines[1] -like '*/DEEInstallSize=123*') -and ($lines[1] -notlike '*/DNeoEEInstallSize*')) $true
  Check 'explicit slice size: 3 slices (920000 / 450000)' (@(Get-ChildItem -LiteralPath $out2 -Filter '*.bin').Count) 3
  Check 'BUILD-INFO: test build' ([System.IO.File]::ReadAllText((Join-Path $out2 'BUILD-INFO.txt')) -like '*test build 2*') $true

  # A real build with made-up inputs
  Reset-Fake ''
  $real = Join-Path $temp 'real'
  New-TestFile (Join-Path $real 'launcher\Empire Earth Launcher.exe') 100 21
  New-TestFile (Join-Path $real 'launcher\Empire Earth Launcher.pdb') 100 22
  New-TestFile (Join-Path $real 'mod\Empire_Earth_Mod.exe') 100 23
  New-TestFile (Join-Path $real 'lic\LICENSE') 100 24
  $guids = @('4f9c2b1e-0a37-4d5e-9b61-7a1c3e8d2f40', '8d3e7a52-6b19-4c0f-a2d4-95e1b7c60a38', 'c1a05d93-2e4b-47f8-8e6a-3b9d0f7c1e52')
  $realArgs = @{
    Iscc = $fakeIscc; OutputDir = (Join-Path $temp 'out_real'); RequireVersion = '6.2.2'
    SuiteAppID = $guids[0]; EEAppID = $guids[1]; NeoEEAppID = $guids[2]
    EESetup = (Join-Path $repo 'out\EE_Regular\EE_Setup_Test.exe'); NeoEESetup = (Join-Path $repo 'out\NeoEE_Regular\NeoEE_Setup_Test.exe')
    LauncherDir = (Join-Path $real 'launcher'); ModCreatorDir = (Join-Path $real 'mod'); LicenseDir = (Join-Path $real 'lic')
    LauncherCommit = 'abcdef1234567'; ModCreatorCommit = '0123456'; SliceSize = 450000
  }
  & $build @realArgs 3>$null 6>$null
  $lines = @(Get-Calls)
  Check 'real build: ISCC calls (pass 1, 2, 3)' $lines.Count 3
  Check 'real build: the AppIds of the caller' ($lines[1] -like "*/DSuiteAppID=$($guids[0]) /DEE_AppID=$($guids[1]) /DNeoEE_AppID=$($guids[2])*") $true
  $buildInfo = [System.IO.File]::ReadAllText((Join-Path $realArgs.OutputDir 'BUILD-INFO.txt'))
  Check 'real build: no placeholder note' ($buildInfo -like '*PLACEHOLDER*') $false
  Check 'real build: commits in BUILD-INFO' (($buildInfo -like '*Launcher commit:      abcdef1234567*') -and ($buildInfo -like '*Mod Creator commit:   0123456*')) $true
  Check 'real build: launcher folder without the .pdb' ($buildInfo -like '*1 files, 100 bytes*') $true
  Check 'real build: no AppId in BUILD-INFO' (($buildInfo -like "*$($guids[0])*") -or ($buildInfo -like "*$($guids[1])*")) $false
  Check 'real build: the slice size of the limit is the default' (Test-Path -LiteralPath (Join-Path $realArgs.OutputDir "$base.exe")) $true

  # A real build without -SliceSize uses the limit of GitHub: DiskSliceSize 50,000,000
  Reset-Fake ''
  $a = $realArgs.Clone(); $a.Remove('SliceSize'); $a.OutputDir = (Join-Path $temp 'out_real2')
  & $build @a 3>$null 6>$null
  Check 'real build: default DiskSliceSize 50000000' (@(Get-Calls)[0] -like '*/DSliceSize=50000000*') $true
  Check 'real build: ... one slice for the small payload' (@(Get-ChildItem -LiteralPath $a.OutputDir -Filter '*.bin').Count) 1

  # The stops
  $a = $realArgs.Clone(); $a.EEAppID = '00000000-0000-0000-0000-0000000000EE'
  Reset-Fake ''; CheckThrows 'real build: dummy AppId' { & $build @a } '*dummy AppId*'
  Check 'real build: dummy AppId stops before ISCC' @(Get-Calls).Count 0
  $a = $realArgs.Clone(); $a.Remove('SuiteAppID')
  Reset-Fake ''; CheckThrows 'real build: SuiteAppID missing' { & $build @a } '*-SuiteAppID is required*'
  $a = $realArgs.Clone(); $a.Remove('LauncherDir')
  Reset-Fake ''; CheckThrows 'real build: launcher folder missing' { & $build @a } '*-LauncherDir is required*'
  $a = $realArgs.Clone(); $a.EEAppID = $guids[0]
  Reset-Fake ''; CheckThrows 'AppIds must differ' { & $build @a } '*must differ*'
  $a = $realArgs.Clone(); $a.NeoEEAppID = '{' + $guids[2] + '}'
  Reset-Fake ''; CheckThrows 'AppId with braces' { & $build @a } '*not a GUID*'
  $a = $realArgs.Clone(); $a.SliceSize = 50000001
  Reset-Fake ''; CheckThrows 'slice size over the limit' { & $build @a } '*more than the limit*'
  $a = $realArgs.Clone(); $a.LauncherCommit = 'ABC'
  Reset-Fake ''; CheckThrows 'commit not hex' { & $build @a } '*lower-case hex*'
  $a = $realArgs.Clone(); $a.SliceSize = 200000
  Reset-Fake ''; CheckThrows 'slice size below the setup program (ISCC refuses)' { & $build @a } '*ISCC failed in pass1*'
  # a changed input: its .sha256 no longer matches
  $changed = Join-Path $temp 'changed'
  New-TestFile (Join-Path $changed 'EE_Setup_Test.exe') 400000 99
  Copy-Item -LiteralPath (Join-Path $repo 'out\EE_Regular\EE_Setup_Test.exe.sha256') -Destination $changed
  $a = $realArgs.Clone(); $a.EESetup = (Join-Path $changed 'EE_Setup_Test.exe')
  Reset-Fake ''; CheckThrows 'changed input against its .sha256' { & $build @a } '*SHA-256 of*'
  Check 'changed input stops before ISCC' @(Get-Calls).Count 0
  $a = $realArgs.Clone(); $a.NeoEESetup = $realArgs.EESetup
  Reset-Fake ''; CheckThrows 'the same file as both setups' { & $build @a } '*same file*'
  # ISCC
  Reset-Fake ''; $env:FAKE_ISCC_VERSION = '6.2.1'
  CheckThrows 'wrong ISCC version' { & $build @realArgs } '*6.2.2 is required, found 6.2.1*'
  Check 'wrong ISCC version stops before the build' @(Get-Calls).Count 0
  Reset-Fake ''; $env:FAKE_ISCC_VERSION = $null
  $a = $realArgs.Clone(); $a.Iscc = (Join-Path $temp 'no_iscc.exe')
  CheckThrows 'no ISCC' { & $build @a } '*ISCC not found*'
  Reset-Fake 'fail'; CheckThrows 'ISCC fails' { & $build @realArgs } '*ISCC failed in pass1 (exit code 1)*'
  # the build itself
  Reset-Fake 'nobins'; CheckThrows 'no slices' { & $build @realArgs } '*wrote no .bin slice*'
  Reset-Fake 'countmismatch'; CheckThrows 'numbers of pass 1 do not match pass 2' { & $build @realArgs } '*Pass 2 has 4 slice(s)*'
  Reset-Fake 'unstable'; CheckThrows 'pass 2 and pass 3 differ' { & $build @realArgs } '*not stable*differs in its bytes*'
  Reset-Fake 'bigbin'; CheckThrows 'a slice over DiskSliceSize' { & $build @realArgs } '*over the limit*-1.bin is 450001 bytes*'
  Reset-Fake 'foreign'; CheckThrows 'a stray file in the build folder' { & $build @realArgs } '*unexpected file*stray.txt*'
  # an unstable or failed build leaves no complete package
  $failOut = Join-Path $temp 'out_failed'
  $a = $realArgs.Clone(); $a.OutputDir = $failOut
  Reset-Fake 'unstable'; try { & $build @a 3>$null 6>$null *>$null } catch { }
  Check 'a failed build writes nothing into the output folder' (Test-Path -LiteralPath $failOut) $false

  # placeholders: missing placeholder setups
  Reset-Fake ''
  $bare = Join-Path $temp 'bare'
  New-Item -ItemType Directory -Path (Join-Path $bare 'suite'), (Join-Path $bare 'ci') | Out-Null
  Copy-Item -LiteralPath $build -Destination (Join-Path $bare 'suite')
  Copy-Item -LiteralPath (Join-Path $repo 'suite\suite.iss') -Destination (Join-Path $bare 'suite')
  foreach ($name in @('build_helpers.ps1', 'suite_build_helpers.ps1')) { Copy-Item -LiteralPath (Join-Path $ciDir $name) -Destination (Join-Path $bare 'ci') }
  CheckThrows 'placeholders without the placeholder setups' { & (Join-Path $bare 'suite\build_suite.ps1') -Placeholders -Iscc $fakeIscc } '*run ci\build.ps1 -Placeholders first*'
} finally {
  $env:FAKE_ISCC_MODE = $savedMode
  $env:FAKE_ISCC_VERSION = $savedVersion
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
