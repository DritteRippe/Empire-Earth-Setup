<#
.SYNOPSIS
  Checks or rewrites pins\online-files.txt, the SHA-256 pins of every online localized file.

.DESCRIPTION
  pins\online-files.txt pins every file the setups can download from the file servers, by its
  server path, with SHA-256 and size (docs/adr/0012-pinned-downloads-despite-invalid-certificates.md).
  downloads.iss compiles it into every setup: a downloaded file is only installed if it matches its
  pin, and a pinned file is downloaded even from a server whose certificate is invalid.

  Without switches the script checks the list: its format (Read-OnlinePins in ci\build_helpers.ps1:
  UTF-8 without BOM, LF, "<SHA-256> <size> <server path>", ordinal order, each path once) and that
  it pins exactly the online files of both products as the code registers them (Get-OnlineFiles of
  EE and NeoEE): no file without a pin, no pin of a path that no setup downloads. Exit code 0 if
  the list is fine, 1 otherwise. ci\build.ps1 runs the same checks before every build.

  -Update rewrites the list from a copy of the "localized" folder of the file servers (-Source,
  the layout of /localized/: Game\<tag>\..., Lobby\<tag>\..., Mods\NeoEE\...). Take the copy from
  the master copy of the operators or over a channel that does not depend on the certificate of
  the web server (SFTP/FTP of the hosting); with -CrossCheck a second copy, fetched independently
  (e.g. over another network), must have byte-identical files. Nothing is written if a file is
  missing or differs. Review the diff of the list before committing it (docs\SERVER-OPERATIONS.md,
  section 6).

  -SelfTest runs the check against changed copies of the repository that must fail (and an
  unchanged copy that must pass).

.PARAMETER Update
  Rewrite pins\online-files.txt from -Source.

.PARAMETER Source
  Folder with a copy of /localized/ (only with -Update).

.PARAMETER CrossCheck
  A second, independent copy of /localized/ (only with -Update): every file must be identical.

.PARAMETER SourceNote
  The provenance line of the list (only with -Update), e.g. "2026-11-01, SFTP of the hosting".
  Default: the date and the folder name of -Source.

.PARAMETER SelfTest
  Check the check itself.

.PARAMETER Root
  The repository (default: the parent folder of ci\).

.EXAMPLE
  pwsh ci/online_pins.ps1

.EXAMPLE
  pwsh ci/online_pins.ps1 -Update -Source D:\localized -CrossCheck E:\localized-second -SourceNote '2026-11-01, SFTP and a second download over LTE'
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Update,
  [string]$Source,
  [string]$CrossCheck,
  [string]$SourceNote,
  [switch]$SelfTest,
  [string]$Root
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'build_helpers.ps1')
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }

# Problems of the pin list of the repository $RepoRoot (an empty list if there is none) and a
# summary line for the success case
function Get-OnlinePinProblems([string]$RepoRoot) {
  $problems = [System.Collections.Generic.List[string]]::new()
  $list = Join-Path (Join-Path $RepoRoot 'pins') 'online-files.txt'
  try {
    $pins = @(Read-OnlinePins $list)
    $files = @(Get-OnlineFiles $RepoRoot 'EE') + @(Get-OnlineFiles $RepoRoot 'NeoEE')
  } catch {
    $problems.Add($_.Exception.Message)
    return [pscustomobject]@{ Problems = $problems.ToArray(); Summary = '' }
  }
  $coverage = Test-OnlinePinCoverage $files $pins
  foreach ($path in $coverage.Missing) { $problems.Add("no pin for the online file $path") }
  foreach ($path in $coverage.Stale) { $problems.Add("pin of $path, which no setup downloads") }
  $paths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  foreach ($file in $files) { [void]$paths.Add($file.RelPath) }
  $bytes = 0L
  foreach ($pin in $pins) { $bytes += $pin.Size }
  $summary = "pins\online-files.txt: $($pins.Count) pins, the online files of EE and NeoEE ($($paths.Count) server paths), $bytes bytes"
  return [pscustomobject]@{ Problems = $problems.ToArray(); Summary = $summary }
}

function Invoke-SelfTest {
  $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-online-pins-' + [System.Guid]::NewGuid().ToString('N'))
  try {
    $copy = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path (Join-Path $copy 'pins') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'setup_is6.iss'), (Join-Path $Root 'utils.iss') -Destination $copy
    $listFile = Join-Path (Join-Path $copy 'pins') 'online-files.txt'
    $original = [System.IO.File]::ReadAllBytes((Join-Path (Join-Path $Root 'pins') 'online-files.txt'))
    $text = [System.Text.Encoding]::UTF8.GetString($original)
    $setupText = [System.IO.File]::ReadAllText((Join-Path $Root 'setup_is6.iss'))
    $lines = $text.Split("`n")
    $first = @($lines | Where-Object { $_ -and -not $_.StartsWith('#') })[0]
    $second = @($lines | Where-Object { $_ -and -not $_.StartsWith('#') })[1]
    $hex = $first.Substring(0, 64)
    $cases = [ordered]@{
      'a BOM' = { param($t) [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes($t) }
      'CRLF line ends' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace("`n", "`r`n")) }
      'no LF at the end' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.TrimEnd("`n")) }
      'an empty line' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace("$first`n", "$first`n`n")) }
      'uppercase hex digits' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, $hex.ToUpperInvariant() + $first.Substring(64))) }
      'a short hash' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, $first.Substring(1))) }
      'a size with a leading zero' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, $hex + ' 0' + $first.Substring(65))) }
      'a size of 0' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, $hex + ' 0 ' + ($first.Substring(65) -replace '^\d+ ', ''))) }
      'tab separators' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, ($first -replace '^(\S+) (\S+) ', "`$1`t`$2`t"))) }
      'a backslash in a path' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, $first.Replace('/', '\'))) }
      'a leading slash' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, ($first -replace '^(\S+ \S+ )', '$1/'))) }
      'a .. segment' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace($first, ($first -replace '^(\S+ \S+ )', '$1../'))) }
      'two lines swapped (order)' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace("$first`n$second`n", "$second`n$first`n")) }
      'a path pinned twice' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace("$first`n", "$first`n$first`n")) }
      'a missing pin' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t.Replace("$first`n", '')) }
      'a pin no setup downloads' = { param($t) [System.Text.Encoding]::UTF8.GetBytes($t + "$hex 1 Mods/NeoEE/Lobby/zz/EE/WONLobby.cfg`n") }
      'a missing list' = $null
    }
    $script:SelfCount = 0
    $script:SelfFailures = 0
    function Expect([string]$Name, [bool]$ShouldPass) {
      $script:SelfCount++
      $result = Get-OnlinePinProblems $copy
      $passed = ($result.Problems.Count -eq 0)
      if (-not $passed) { Write-Verbose "self-test ${Name}: $($result.Problems[0])" }
      if ($passed -ne $ShouldPass) {
        $script:SelfFailures++
        Write-Host "FAIL self-test ${Name}: the check $(if ($passed) { 'passed' } else { 'failed: ' + ($result.Problems -join '; ') })"
      }
    }
    [System.IO.File]::WriteAllBytes($listFile, $original)
    Expect 'unchanged copy' $true
    foreach ($name in $cases.Keys) {
      if ($null -eq $cases[$name]) { Remove-Item -LiteralPath $listFile } else { [System.IO.File]::WriteAllBytes($listFile, [byte[]](& $cases[$name] $text)) }
      Expect $name $false
    }
    # A file the code registers in addition must be pinned
    [System.IO.File]::WriteAllBytes($listFile, $original)
    $changed = $setupText -replace "'EETheGreeks\.ssa'\]", "'EETheGreeks.ssa', 'EETheNew.ssa']"
    if ($changed -ceq $setupText) { throw 'self-test: the campaign list was not found in setup_is6.iss' }
    [System.IO.File]::WriteAllText((Join-Path $copy 'setup_is6.iss'), $changed, [System.Text.UTF8Encoding]::new($true))
    Expect 'a campaign added to RegisterOnlineFiles without a pin' $false
    [System.IO.File]::WriteAllText((Join-Path $copy 'setup_is6.iss'), $setupText, [System.Text.UTF8Encoding]::new($true))
    Expect 'unchanged copy again' $true

    # -Update from a folder with every file writes a list that passes; a missing file writes nothing
    $localized = Join-Path $temp 'localized'
    $files = @(Get-OnlineFiles $copy 'EE') + @(Get-OnlineFiles $copy 'NeoEE')
    foreach ($file in $files) {
      $target = Join-Path $localized ($file.RelPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      [System.IO.File]::WriteAllText($target, $file.RelPath)
    }
    $written = @(Write-OnlinePins $localized $files $listFile 'self-test' $null)
    $script:SelfCount++
    if ($written.Count -ne 230 -or (Get-OnlinePinProblems $copy).Problems.Count -ne 0) { $script:SelfFailures++; Write-Host "FAIL self-test -Update: $($written.Count) pins written" }
    $before = [System.IO.File]::ReadAllBytes($listFile)
    Remove-Item -LiteralPath (Join-Path $localized 'Game\de\EE\Data\data.ssa'.Replace('\', [System.IO.Path]::DirectorySeparatorChar))
    $script:SelfCount++
    $threw = $false
    try { Write-OnlinePins $localized $files $listFile 'self-test' $null | Out-Null } catch { $threw = $true }
    if (-not $threw -or [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($listFile)) -cne [Convert]::ToBase64String($before)) {
      $script:SelfFailures++; Write-Host 'FAIL self-test -Update with a missing file: no error, or the list was changed'
    }
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

if ($Update) {
  if (-not $Source) { throw '-Update needs -Source <copy of the localized folder>.' }
  if (-not $SourceNote) { $SourceNote = "$(Get-Date -Format 'yyyy-MM-dd'), copy $([System.IO.Path]::GetFileName($Source.TrimEnd('\', '/')))" }
  $files = @(Get-OnlineFiles $Root 'EE') + @(Get-OnlineFiles $Root 'NeoEE')
  $listFile = Join-Path (Join-Path $Root 'pins') 'online-files.txt'
  $written = @(Write-OnlinePins $Source $files $listFile $SourceNote $CrossCheck)
  Write-Host "$listFile written: $($written.Count) pins. Review the diff before committing it."
}

$result = Get-OnlinePinProblems $Root
if ($result.Problems.Count -gt 0) {
  foreach ($problem in $result.Problems) { Write-Host "ERROR $problem" }
  Write-Host "pins\online-files.txt: $($result.Problems.Count) problem(s); see docs\SERVER-OPERATIONS.md, section 6"
  exit 1
}
Write-Host $result.Summary
exit 0
