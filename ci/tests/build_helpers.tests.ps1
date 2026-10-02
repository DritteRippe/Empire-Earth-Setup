<#
.SYNOPSIS
  Tests of ci\build_helpers.ps1 (SHA-256 list of the online files, DER copy of the certificate,
  test build number) and a dry run of ci\build.ps1.

.DESCRIPTION
  Needs neither Inno Setup nor the game data: the test certificates are generated (self-signed,
  thrown away afterwards) and the files live in a temporary folder. The dry run calls a copy of
  ci\build.ps1 with a fake ISCC that only records its arguments, and checks what the script passes
  to ISCC. Runs with Windows PowerShell 5.1 and PowerShell 7 (also on Linux). Prints the failed
  checks and exits with 0 if every check passed, else 1.

  Optional: -CertFile <file> -CertHashSHA1 <hash> also converts a real certificate (DER or PEM)
  and checks that its DER copy has that thumbprint, e.g. the community certificate before a
  signed build.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ci\tests\build_helpers.tests.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$CertFile,
  [string]$CertHashSHA1
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'build_helpers.ps1')

$script:Count = 0
$script:Failures = 0
function Check([string]$Name, $Actual, $Expected) {
  $script:Count++
  if ("$Actual" -ceq "$Expected") { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: got '$Actual', expected '$Expected'"
}
function CheckThrows([string]$Name, [scriptblock]$Block) {
  $script:Count++
  try { & $Block | Out-Null } catch { return }
  $script:Failures++
  Write-Host "FAIL ${Name}: no exception"
}
function Base64Lines([byte[]]$Bytes, [string]$NewLine) {
  $text = [Convert]::ToBase64String($Bytes)
  $lines = for ($i = 0; $i -lt $text.Length; $i += 64) { $text.Substring($i, [Math]::Min(64, $text.Length - $i)) }
  return ($lines -join $NewLine)
}
function New-TestCertificateDer([string]$Name) {
  $rsa = [System.Security.Cryptography.RSA]::Create(2048)
  try {
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
      "CN=$Name", $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
      [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $now = [DateTimeOffset]::UtcNow
    $certificate = $request.CreateSelfSigned($now.AddDays(-1), $now.AddDays(1))
    return ,([byte[]]$certificate.RawData)
  } finally {
    $rsa.Dispose()
  }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ee-setup-helpers-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  # --- Write-DownloadHashes
  $folder = Join-Path $temp 'localized-text'
  $files = [ordered]@{
    'Game/de/EE/Language.dll' = 'dll'
    'Lobby/zh/shared/Data/WONLobby Resources/_WONStatus.cfg' = 'status'
    'Lobby/de/EE/WONLobby.cfg' = 'lobby'
    'Mods/NeoEE/Lobby/zh/EE/WONLobby.cfg' = ''
  }
  foreach ($path in $files.Keys) {
    $full = Join-Path $folder $path
    New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
    [System.IO.File]::WriteAllText($full, $files[$path])
  }
  $list = Join-Path $temp 'localized-text.sha256'
  Write-DownloadHashes $folder $list 6>$null
  $bytes = [System.IO.File]::ReadAllBytes($list)
  Check 'hash list without BOM' ($bytes[0] -ne 0xEF) $true
  $lines = @([System.IO.File]::ReadAllLines($list))
  Check 'hash list lines' $lines.Count 4
  Check 'hash list ordinal order' ($lines | ForEach-Object { $_.Substring(66) }) (@('Game/de/EE/Language.dll', 'Lobby/de/EE/WONLobby.cfg', 'Lobby/zh/shared/Data/WONLobby Resources/_WONStatus.cfg', 'Mods/NeoEE/Lobby/zh/EE/WONLobby.cfg'))
  Check 'hash list sha256sum format' ($lines[0] -cmatch '^[0-9a-f]{64}  [^ ]') $true
  Check 'hash list hash' $lines[3] 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  Mods/NeoEE/Lobby/zh/EE/WONLobby.cfg'
  Write-DownloadHashes (Join-Path $temp 'missing') (Join-Path $temp 'missing.sha256') 3>$null 6>$null
  Check 'hash list of a missing folder is not written' (Test-Path -LiteralPath (Join-Path $temp 'missing.sha256')) $false

  # --- Read-CertificateDer / ConvertTo-DerCertificateFile
  $der = New-TestCertificateDer 'Empire Earth Setup test'
  $thumbprint = Get-Sha1Hex $der
  $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$der)
  Check 'Get-Sha1Hex is the thumbprint' $thumbprint $certificate.Thumbprint.ToLowerInvariant()

  $derFile = Join-Path $temp 'test_der.crt'
  [System.IO.File]::WriteAllBytes($derFile, $der)
  $pem = "-----BEGIN CERTIFICATE-----`r`n" + (Base64Lines $der "`r`n") + "`r`n-----END CERTIFICATE-----`r`n"
  $pemFile = Join-Path $temp 'test_pem.crt'
  [System.IO.File]::WriteAllText($pemFile, $pem)
  $pemLfFile = Join-Path $temp 'test_pem_lf_bom.crt'
  [System.IO.File]::WriteAllText($pemLfFile, ($pem -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($true))

  foreach ($case in @(@('DER', $derFile), @('PEM', $pemFile), @('PEM', $pemLfFile))) {
    $out = Join-Path (Join-Path $temp 'out') ([System.IO.Path]::GetFileName($case[1]))
    $result = ConvertTo-DerCertificateFile $case[1] $out
    $name = [System.IO.Path]::GetFileName($case[1])
    Check "$name encoding" $result.Encoding $case[0]
    Check "$name thumbprint" $result.Thumbprint $thumbprint
    Check "$name DER copy" ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($out))) ([Convert]::ToBase64String($der))
    Check "$name SHA-1 of the copy" (Get-Sha1Hex ([System.IO.File]::ReadAllBytes($out))) $thumbprint
  }

  $second = New-TestCertificateDer 'Second'
  $bundle = $pem + "-----BEGIN CERTIFICATE-----`n" + (Base64Lines $second "`n") + "`n-----END CERTIFICATE-----`n"
  $bad = [ordered]@{
    'two certificates' = $bundle
    'certificate and key' = $pem + "-----BEGIN PRIVATE KEY-----`nAAAA`n-----END PRIVATE KEY-----`n"
    'text before the certificate' = "subject=CN = test`n" + $pem
    'no certificate block' = "-----BEGIN PRIVATE KEY-----`nAAAA`n-----END PRIVATE KEY-----`n"
    'broken base64' = "-----BEGIN CERTIFICATE-----`nAAA`n-----END CERTIFICATE-----`n"
    'not a certificate' = 'hello'
  }
  foreach ($name in $bad.Keys) {
    $file = Join-Path $temp 'bad.crt'
    [System.IO.File]::WriteAllText($file, $bad[$name])
    CheckThrows "Read-CertificateDer refuses $name" { Read-CertificateDer $file }
  }
  $file = Join-Path $temp 'trailing.der'
  [System.IO.File]::WriteAllBytes($file, [byte[]]($der + [byte[]](0, 0)))
  CheckThrows 'Read-CertificateDer refuses DER with trailing bytes' { Read-CertificateDer $file }

  Check 'ConvertTo-Thumbprint' (ConvertTo-Thumbprint 'F8 73 8C 35 49 EF 13 8F 6F 3B 17 77 D4 CC 1A CF 23 3D CD 47') 'f8738c3549ef138f6f3b1777d4cc1acf233dcd47'

  # --- Get-TestIdDefine
  Check 'Get-TestIdDefine 1' (Get-TestIdDefine 1) '/DTestID=1'
  Check 'Get-TestIdDefine 0' (Get-TestIdDefine 0) '/DTestID=0'
  Check 'Get-TestIdDefine of a string' (Get-TestIdDefine '42') '/DTestID=42'
  foreach ($bad in @(-1, '-1', '+1', '1.5', ' 1', '1e3', 'abc', '', $null, '2147483648')) {
    CheckThrows "Get-TestIdDefine refuses '$bad'" { Get-TestIdDefine $bad }
  }

  # --- Write-FileSha256: sha256sum format, one LF, UTF-8 without BOM, overwrites
  $setupDir = Join-Path $temp 'setups'
  New-Item -ItemType Directory -Path $setupDir | Out-Null
  $setup = Join-Path $setupDir 'EE_Setup_v1.7.2.exe'
  [System.IO.File]::WriteAllBytes($setup, [System.Text.Encoding]::ASCII.GetBytes('abc'))
  $abc = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'   # SHA-256 of "abc"
  $result = Write-FileSha256 $setup
  $checksumFile = "$setup.sha256"
  Check 'Write-FileSha256 returns the hash' $result.Hash $abc
  Check 'Write-FileSha256 default file name' $result.Path $checksumFile
  $bytes = [System.IO.File]::ReadAllBytes($checksumFile)
  $text = [System.Text.Encoding]::ASCII.GetString($bytes)
  Check 'Write-FileSha256 content: hash, two spaces, file name only, LF' $text "$abc  EE_Setup_v1.7.2.exe`n"
  Check 'Write-FileSha256 without BOM' ($bytes[0] -eq [byte][char]'b') $true
  Check 'Write-FileSha256 has no CR' ([Array]::IndexOf($bytes, [byte]13)) -1
  Check 'Write-FileSha256 ends with exactly one LF' (($bytes[-1] -eq 10) -and ($bytes[-2] -ne 10)) $true
  Check 'Write-FileSha256 line is the sha256sum format' ($text -cmatch '^[0-9a-f]{64}  [^ /\\]+\n$') $true

  # An existing file is replaced completely: longer, with BOM, CRLF and an old hash
  $old = [System.Text.UTF8Encoding]::new($true).GetPreamble() + [System.Text.Encoding]::ASCII.GetBytes(('0' * 64) + "  old_name.exe`r`n" + ('x' * 200) + "`r`n")
  [System.IO.File]::WriteAllBytes($checksumFile, $old)
  [System.IO.File]::WriteAllBytes($setup, [System.Text.Encoding]::ASCII.GetBytes(''))
  $result = Write-FileSha256 $setup
  $empty = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'   # SHA-256 of ""
  Check 'Write-FileSha256 overwrites: hash' $result.Hash $empty
  Check 'Write-FileSha256 overwrites: content' ([System.IO.File]::ReadAllText($checksumFile)) "$empty  EE_Setup_v1.7.2.exe`n"
  Check 'Write-FileSha256 overwrites: no BOM, no old bytes left' ([System.IO.File]::ReadAllBytes($checksumFile).Length) 86

  # Other destination: still only the file name of the setup in the line
  $other = Join-Path $temp 'other.sha256'
  Write-FileSha256 $setup $other | Out-Null
  Check 'Write-FileSha256 other destination' ([System.IO.File]::ReadAllText($other)) "$empty  EE_Setup_v1.7.2.exe`n"
  # Relative paths are relative to the PowerShell location (not the folder of the process)
  Push-Location -LiteralPath $setupDir
  try {
    Write-FileSha256 'EE_Setup_v1.7.2.exe' 'relative.sha256' | Out-Null
  } finally {
    Pop-Location
  }
  $relative = Join-Path $setupDir 'relative.sha256'
  Check 'Write-FileSha256 relative paths: file in the PowerShell location' (Test-Path -LiteralPath $relative -PathType Leaf) $true
  if (Test-Path -LiteralPath $relative -PathType Leaf) {
    Check 'Write-FileSha256 relative paths: content' ([System.IO.File]::ReadAllText($relative)) "$empty  EE_Setup_v1.7.2.exe`n"
    Remove-Item -LiteralPath $relative
  }
  CheckThrows 'Write-FileSha256 refuses a missing file' { Write-FileSha256 (Join-Path $temp 'missing.exe') }
  Check 'Write-FileSha256 writes nothing for a missing file' (Test-Path -LiteralPath (Join-Path $temp 'missing.exe.sha256')) $false

  # Cross-check with the real sha256sum where it exists (Linux, Git Bash), else skipped
  $sha256sum = Get-Command 'sha256sum' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($sha256sum) {
    [System.IO.File]::WriteAllBytes($setup, [byte[]](0..255))
    Write-FileSha256 $setup | Out-Null
    Push-Location -LiteralPath $setupDir
    try {
      $output = & $sha256sum.Source -c 'EE_Setup_v1.7.2.exe.sha256' 2>&1
      Check 'sha256sum -c accepts the file' "$LASTEXITCODE $output" '0 EE_Setup_v1.7.2.exe: OK'
      [System.IO.File]::WriteAllBytes($setup, [byte[]](1..255))
      $output = & $sha256sum.Source -c 'EE_Setup_v1.7.2.exe.sha256' 2>&1
      Check 'sha256sum -c detects a changed setup' ($LASTEXITCODE -ne 0) $true
    } finally {
      Pop-Location
    }
  } else {
    Write-Host 'SKIP sha256sum -c cross-check (no sha256sum on this system)'
  }

  # --- ci\build.ps1 -TestID: dry run of a copy of the script with a fake ISCC. The fake records
  # its arguments, answers the version probe, writes the resolved script of pass 1 and an empty
  # setup in pass 2, so the script runs completely without Inno Setup and game data.
  $repo = Join-Path $temp 'repo'
  $repoCi = Join-Path $repo 'ci'
  New-Item -ItemType Directory -Path $repoCi | Out-Null
  $ciDir = Split-Path -Parent $PSScriptRoot
  foreach ($name in @('build.ps1', 'build_helpers.ps1')) {
    Copy-Item -LiteralPath (Join-Path $ciDir $name) -Destination $repoCi
  }
  [System.IO.File]::WriteAllText((Join-Path $repo 'setup_is6.iss'), "; dry run`r`n")
  $calls = Join-Path $temp 'iscc_calls.txt'
  $fakeIscc = Join-Path $temp 'fake_iscc.ps1'
  $fake = @'
$script = (Resolve-Path -LiteralPath ([string]$args[-1])).ProviderPath
Add-Content -LiteralPath '%CALLS%' -Value ($args -join ' ')
if ($script -like '*version_probe.iss') { 'ISCC_VERSION=6.2.2'; exit 0 }
$match = [regex]::Match([System.IO.File]::ReadAllText($script), 'SaveToFile\(AddBackslash\(SourcePath\) \+ "([^"]+)"\)')
if ($match.Success) {
  [System.IO.File]::WriteAllText((Join-Path (Split-Path -Parent $script) $match.Groups[1].Value), '; resolved')
  exit 0
}
$out = ''; $type = ''; $mode = ''
foreach ($arg in $args) {
  if ($arg -like '/O*') { $out = $arg.Substring(2) }
  if ($arg -like '/DInstallType=*') { $type = $arg -replace '^/DInstallType=', '' }
  if ($arg -like '/DInstallMode=*') { $mode = $arg -replace '^/DInstallMode=', '' }
}
[System.IO.File]::WriteAllText((Join-Path $out "${type}_${mode}_dry_run.exe"), '')
exit 0
'@
  [System.IO.File]::WriteAllText($fakeIscc, $fake.Replace('%CALLS%', $calls))
  $build = Join-Path $repoCi 'build.ps1'
  $common = @{
    Iscc = $fakeIscc
    EEAppID = '00000000-0000-0000-0000-0000000000EE'
    NeoEEAppID = '00000000-0000-0000-0000-000000000AEE'
    Variants = @('EE/Regular', 'NeoEE/Portable')
  }

  $buildOutput = @(& $build @common -TestID 1 3>$null 6>&1 | ForEach-Object { "$_" })
  Check 'dry run -TestID 1: exit code' $LASTEXITCODE 0
  $lines = @(Get-Content -LiteralPath $calls)
  Check 'dry run -TestID 1: ISCC calls (version probe, 2 x pass 1, 2 x pass 2)' $lines.Count 5
  Check 'dry run -TestID 1: version probe without TestID' ($lines[0] -like '*/DTestID*') $false
  Check 'dry run -TestID 1: /DTestID=1 in every compile' @($lines | Where-Object { " $_ " -like '* /DTestID=1 *' }).Count 4
  Check 'dry run -TestID 1: AppIds in every compile' @($lines | Where-Object { $_ -like '*/DEE_AppID=00000000-0000-0000-0000-0000000000EE /DNeoEE_AppID=00000000-0000-0000-0000-000000000AEE*' }).Count 4
  Check 'dry run -TestID 1: setups' @(Get-ChildItem -LiteralPath (Join-Path $repo 'out') -Recurse -Filter '*.exe').Count 2
  # A SHA-256 file next to every setup that passed, and the hash in the output
  foreach ($variantName in @('EE_Regular', 'NeoEE_Portable')) {
    $leaf = "${variantName}_dry_run.exe"
    $exeFile = Join-Path (Join-Path (Join-Path $repo 'out') $variantName) $leaf
    $sumFile = "$exeFile.sha256"
    Check "dry run: $leaf.sha256 written" (Test-Path -LiteralPath $sumFile -PathType Leaf) $true
    if (Test-Path -LiteralPath $sumFile -PathType Leaf) {
      Check "dry run: $leaf.sha256 content" ([System.IO.File]::ReadAllText($sumFile)) "$empty  $leaf`n"
    }
    Check "dry run: SHA-256 of $leaf printed" @($buildOutput | Where-Object { $_ -like "*SHA-256 $empty  $leaf -> $leaf.sha256*" }).Count 1
  }
  Check 'dry run: only setups and SHA-256 files in out' @(Get-ChildItem -LiteralPath (Join-Path $repo 'out') -Recurse -File | Where-Object { $_.Name -notlike '*.exe' -and $_.Name -notlike '*.exe.sha256' }).Count 0

  Remove-Item -LiteralPath $calls
  & $build @common 3>$null 6>$null
  Check 'dry run without -TestID: exit code' $LASTEXITCODE 0
  Check 'dry run without -TestID: no /DTestID (default of setup_is6.iss)' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DTestID*' }).Count 0

  Remove-Item -LiteralPath $calls
  & $build @common -TestID 0 3>$null 6>$null
  Check 'dry run -TestID 0: /DTestID=0 in every compile' @(Get-Content -LiteralPath $calls | Where-Object { " $_ " -like '* /DTestID=0 *' }).Count 4

  Remove-Item -LiteralPath $calls
  CheckThrows 'build.ps1 refuses -TestID -1' { & $build @common -TestID -1 3>$null 6>$null }
  CheckThrows 'build.ps1 refuses -TestID abc' { & $build @common -TestID abc 3>$null 6>$null }
  Check 'build.ps1 calls no ISCC for an invalid -TestID' (Test-Path -LiteralPath $calls) $false

  # An ISCC that prints nothing (e.g. it cannot start): a clear version error, not a missing log
  $silentIscc = Join-Path $temp 'silent_iscc.ps1'
  [System.IO.File]::WriteAllText($silentIscc, 'exit 1')
  $common.Iscc = $silentIscc
  $message = ''
  try { & $build @common -RequireVersion 6.2.2 3>$null 6>$null } catch { $message = $_.Exception.Message }
  Check 'dry run with an ISCC that prints nothing' $message 'ISCC 6.2.2 is required, found unknown.'

  # --- Optional: a real certificate
  if ($CertFile) {
    $out = Join-Path (Join-Path $temp 'real') ([System.IO.Path]::GetFileName($CertFile))
    $result = ConvertTo-DerCertificateFile $CertFile $out
    Write-Host "$CertFile ($($result.Encoding)) -> DER copy with SHA-1 $($result.Thumbprint)"
    if ($CertHashSHA1) { Check "thumbprint of $CertFile" $result.Thumbprint (ConvertTo-Thumbprint $CertHashSHA1) }
  }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
