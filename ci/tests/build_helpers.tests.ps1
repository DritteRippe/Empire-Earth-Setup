<#
.SYNOPSIS
  Tests of ci\build_helpers.ps1 (SHA-256 list of the online files, DER copy of the certificate,
  test build number, build identifier, the online files and their pins in pins\online-files.txt)
  and a dry run of ci\build.ps1.

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

  # --- Get-SetupBuild, Assert-SetupBuild, Get-SetupBuildDefine, Get-GitShortCommit
  Check 'Get-SetupBuild release build' (Get-SetupBuild 0 'ab12cd3' $false) ''
  Check 'Get-SetupBuild release build in CI' (Get-SetupBuild 0 'ab12cd3' $true) 'ab12cd3'
  Check 'Get-SetupBuild test build' (Get-SetupBuild 2 'ab12cd3' $false) 'test2-ab12cd3'
  Check 'Get-SetupBuild test build in CI' (Get-SetupBuild 2 'ab12cd3' $true) 'test2-ab12cd3'
  Check 'Get-SetupBuild test build without a commit' (Get-SetupBuild 2 '' $false) 'test2'
  Check 'Get-SetupBuild CI without a commit' (Get-SetupBuild 0 '' $true) ''
  foreach ($good in @('', 'ab12cd3', 'test1-ab12cd3', 'v2.0.0-rc_1', ('x' * 64))) {
    Check "Assert-SetupBuild accepts '$good'" (Assert-SetupBuild $good) $good
  }
  foreach ($bad in @('a b', 'a}b', '{app}', 'a;b', 'a"b', "a'b", "a$([char]0xE4)", ('x' * 65), "ab`n", "ab`r`n", 'a\b', 'a/b', 'a%b')) {
    CheckThrows "Assert-SetupBuild refuses '$bad'" { Assert-SetupBuild $bad }
  }
  Check 'Get-SetupBuildDefine' (Get-SetupBuildDefine 'test1-ab12cd3') '/DSetupBuild=test1-ab12cd3'
  Check 'Get-SetupBuildDefine of none' @(Get-SetupBuildDefine '').Count 0
  CheckThrows 'Get-SetupBuildDefine refuses an invalid value' { Get-SetupBuildDefine 'a b' }
  # --- Get-PlaceholderPauseDefine, Find-PlaceholderHook: the test hook of the placeholder builds (setup_is6.iss)
  Check 'Get-PlaceholderPauseDefine with -Placeholders' (Get-PlaceholderPauseDefine $true) '/DPlaceholderInstallPause=1'
  Check 'Get-PlaceholderPauseDefine without -Placeholders: nothing' @(Get-PlaceholderPauseDefine $false).Count 0
  $hookFree = Join-Path $temp 'hook_free.iss'
  $hooked = Join-Path $temp 'hooked.iss'
  [System.IO.File]::WriteAllText($hookFree, "Log('Install step: the game folder is changed from here on');`n")
  [System.IO.File]::WriteAllText($hooked, "Log('Install step: x');`nLog('${PlaceholderHookText}: pausing 2000 ms');`nSleep(2000);`n")
  Check 'Find-PlaceholderHook finds the hook' (@(Find-PlaceholderHook @($hookFree, $hooked)) -join '|') $hooked
  Check 'Find-PlaceholderHook finds nothing in a script without it' @(Find-PlaceholderHook @($hookFree)).Count 0
  Check 'Get-GitShortCommit outside a checkout' (Get-GitShortCommit $temp) ''
  $git = Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  # A Git checkout with one commit (a temporary repository; no settings of the user needed)
  function New-TestCheckout([string]$Folder) {
    & $git.Source -C $Folder init -q 2>&1 | Out-Null
    & $git.Source -C $Folder add -A 2>&1 | Out-Null
    & $git.Source -C $Folder -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q -m test 2>&1 | Out-Null
    return "$(& $git.Source -C $Folder rev-parse --short=7 HEAD 2>$null)".Trim()
  }
  if ($git) {
    $checkout = Join-Path $temp 'checkout'
    New-Item -ItemType Directory -Path $checkout | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $checkout 'a.txt'), 'a')
    $expectedCommit = New-TestCheckout $checkout
    Check 'Get-GitShortCommit of a checkout: 7 hex digits' ($expectedCommit -cmatch '^[0-9a-f]{7}$') $true
    Check 'Get-GitShortCommit of a checkout' (Get-GitShortCommit $checkout) $expectedCommit
  } else {
    Write-Host 'SKIP Get-GitShortCommit of a checkout (no git on this system)'
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

  # --- Get-OnlineFiles: the online files of the real setup_is6.iss (same source as
  # RegisterOnlineFiles), per product
  $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $byPath = @{}
  foreach ($type in @('EE', 'NeoEE')) {
    $list = @(Get-OnlineFiles $repoRoot $type)
    $byPath[$type] = @{}
    foreach ($file in $list) { $byPath[$type][$file.RelPath] = $file }
    $paths = [string[]]@($list | ForEach-Object { $_.RelPath })
    $sorted = [string[]]$paths.Clone()
    [Array]::Sort($sorted, [System.StringComparer]::Ordinal)
    Check "Get-OnlineFiles ${type}: sorted ordinally, each path once" (($paths -join '|') -ceq ($sorted -join '|') -and $byPath[$type].Count -eq $paths.Count) $true
    Check "Get-OnlineFiles ${type}: no English files" @($paths | Where-Object { $_ -match '/en/' }).Count 0
    Check "Get-OnlineFiles ${type}: no movie of AoC" @($paths | Where-Object { $_ -like 'Game/*/AoC/Data/Movies/*' }).Count 0
  }
  # 10 languages; EE: 12 files of EE and 6 more of AoC (the 3 shared lobby files once) per language
  Check 'Get-OnlineFiles EE: 180 files' $byPath.EE.Count 180
  Check 'Get-OnlineFiles EE: 20 with code (Language.dll)' @($byPath.EE.Values | Where-Object { $_.IsCode }).Count 20
  Check 'Get-OnlineFiles EE: voices' $byPath.EE['Game/de/EE/Data/data.ssa'].PinPath 'Game/de/EE/Data/data.ssa'
  Check 'Get-OnlineFiles EE: Language.dll is code' $byPath.EE['Game/de/EE/Language.dll'].IsCode $true
  Check 'Get-OnlineFiles EE: language tag pt-BR, movie' $byPath.EE.ContainsKey('Game/pt-BR/EE/Data/Movies/Empire Earth.bik') $true
  Check 'Get-OnlineFiles EE: AoC campaign' $byPath.EE.ContainsKey('Game/ko/AoC/Data/Campaigns/AOCRoman.ssa') $true
  Check 'Get-OnlineFiles EE: zh-TW lobby pinned as Lobby/zh' $byPath.EE['Lobby/zh-TW/shared/Data/WONLobby Resources/_WONStatus.cfg'].PinPath 'Lobby/zh/shared/Data/WONLobby Resources/_WONStatus.cfg'
  Check 'Get-OnlineFiles EE: no NeoEE files' @($byPath.EE.Keys | Where-Object { $_ -like 'Mods/*' }).Count 0
  # NeoEE: the NeoEE versions of Language.dll and WONLobby.cfg, plus _NeoEEResource.cfg
  Check 'Get-OnlineFiles NeoEE: 190 files' $byPath.NeoEE.Count 190
  Check 'Get-OnlineFiles NeoEE: NeoEE Language.dll' $byPath.NeoEE['Mods/NeoEE/Game/de/EE/Language.dll'].IsCode $true
  Check 'Get-OnlineFiles NeoEE: never the EE Language.dll' $byPath.NeoEE.ContainsKey('Game/de/EE/Language.dll') $false
  Check 'Get-OnlineFiles NeoEE: NeoEE lobby of zh-CN' $byPath.NeoEE['Mods/NeoEE/Lobby/zh-CN/EE/WONLobby.cfg'].PinPath 'Mods/NeoEE/Lobby/zh/EE/WONLobby.cfg'
  Check 'Get-OnlineFiles NeoEE: _NeoEEResource.cfg' $byPath.NeoEE.ContainsKey('Mods/NeoEE/Lobby/de/shared/Data/WONLobby Resources/_NeoEEResource.cfg') $true
  Check 'Get-OnlineFiles NeoEE: shared lobby texts' $byPath.NeoEE.ContainsKey('Lobby/de/shared/Data/WONLobby Resources/_GameResource.cfg') $true
  CheckThrows 'Get-OnlineFiles refuses an unknown product' { Get-OnlineFiles $repoRoot 'AoC' }

  # --- Get-UnpinnedOnlineFiles: no pin in the list (exact paths), and never a file with code
  $eeFiles = @(Get-OnlineFiles $repoRoot 'EE')
  $pinList = Join-Path $temp 'pins.sha256'
  $zero = '0' * 64
  [System.IO.File]::WriteAllLines($pinList, [string[]]@(
    "$zero  Game/de/EE/Language.dll", "$zero  Game/de/EE/Data/data.ssa",
    "$zero  Lobby/zh/shared/Data/WONLobby Resources/_WONStatus.cfg", "$zero  game/de/AoC/Data/data.ssa"))
  $unpinned = @(Get-UnpinnedOnlineFiles $eeFiles $pinList)
  Check 'Get-UnpinnedOnlineFiles: count' $unpinned.Count 157
  Check 'Get-UnpinnedOnlineFiles: a pinned data file is not listed' ($unpinned -ccontains 'Game/de/EE/Data/data.ssa') $false
  Check 'Get-UnpinnedOnlineFiles: zh-CN and zh-TW pinned by Lobby/zh' @($unpinned | Where-Object { $_ -like 'Lobby/zh-*/shared/Data/WONLobby Resources/_WONStatus.cfg' }).Count 0
  Check 'Get-UnpinnedOnlineFiles: pins are case-sensitive (CompareStr)' ($unpinned -ccontains 'Game/de/AoC/Data/data.ssa') $true
  Check 'Get-UnpinnedOnlineFiles: never a file with code' @($unpinned | Where-Object { $_ -like '*.dll' }).Count 0
  Check 'Get-UnpinnedOnlineFiles: sorted' ($unpinned[0]) 'Game/de/AoC/Data/Campaigns/AOCAsian.ssa'
  Check 'Get-UnpinnedOnlineFiles without a list' @(Get-UnpinnedOnlineFiles $eeFiles (Join-Path $temp 'missing.sha256')).Count 160
  Check 'Get-UnpinnedOnlineFiles NeoEE without a list' @(Get-UnpinnedOnlineFiles @(Get-OnlineFiles $repoRoot 'NeoEE') '').Count 170
  $someOnlinePins = @([pscustomobject]@{ RelPath = 'Game/de/AoC/Data/data.ssa'; Sha256 = $zero; Size = 1L },
    [pscustomobject]@{ RelPath = 'Lobby/zh-TW/EE/WONLobby.cfg'; Sha256 = $zero; Size = 1L })
  $unpinned = @(Get-UnpinnedOnlineFiles $eeFiles $pinList $someOnlinePins)
  Check 'Get-UnpinnedOnlineFiles with online pins: count' $unpinned.Count 155
  Check 'Get-UnpinnedOnlineFiles: pinned by its server path in pins\online-files.txt' ($unpinned -ccontains 'Game/de/AoC/Data/data.ssa') $false
  Check 'Get-UnpinnedOnlineFiles: zh-TW pinned by its own server path' ($unpinned -ccontains 'Lobby/zh-TW/EE/WONLobby.cfg') $false

  # --- pins\online-files.txt (ADR 0012): the real list, then the functions with test data
  $realList = Join-Path (Join-Path $repoRoot 'pins') 'online-files.txt'
  $realPins = @(Read-OnlinePins $realList)
  $allFiles = @(Get-OnlineFiles $repoRoot 'EE') + @(Get-OnlineFiles $repoRoot 'NeoEE')
  Check 'Read-OnlinePins: the real list has 230 pins' $realPins.Count 230
  $byRelPath = @{}
  foreach ($pin in $realPins) { $byRelPath[$pin.RelPath] = $pin }
  Check 'Read-OnlinePins: Language.dll of de' $byRelPath['Game/de/EE/Language.dll'].Sha256 '61dda16a22fe64f0956ea2a580483d8c5efdb3d2edd0b5dd1bb4dd401cb8d8c7'
  Check 'Read-OnlinePins: size of Language.dll of de' $byRelPath['Game/de/EE/Language.dll'].Size 249856
  Check 'Read-OnlinePins: the voices of es (the largest file)' $byRelPath['Game/es/EE/Data/data.ssa'].Size 172046353
  Check 'Read-OnlinePins: a path with a space' $byRelPath.ContainsKey('Game/de/EE/Data/Movies/Empire Earth.bik') $true
  Check 'Read-OnlinePins: sizes are [long]' ($byRelPath['Game/es/EE/Data/data.ssa'].Size -is [long]) $true
  $coverage = Test-OnlinePinCoverage $allFiles $realPins
  Check 'Test-OnlinePinCoverage: the real list pins every online file' $coverage.Missing.Count 0
  Check 'Test-OnlinePinCoverage: the real list pins nothing else' $coverage.Stale.Count 0
  Check 'Format-OnlinePinList: the real list is in the format it writes' (Format-OnlinePinList $realPins (([System.IO.File]::ReadAllText($realList) -split "`n" | Where-Object { $_ -like '# Source: *' }) -replace '^# Source: ', '')) ([System.IO.File]::ReadAllText($realList))

  $three = @([pscustomobject]@{ RelPath = 'b/c d.ssa'; Sha256 = ('A' * 64); Size = 5L },
    [pscustomobject]@{ RelPath = 'a/b.dll'; Sha256 = ('1' * 64); Size = 4294967296L })
  $listText = Format-OnlinePinList $three 'test'
  Check 'Format-OnlinePinList: header, source, sorted, lowercase, LF' ($listText.EndsWith("# Source: test`n$('1' * 64) 4294967296 a/b.dll`n$('a' * 64) 5 b/c d.ssa`n")) $true
  $testList = Join-Path $temp 'online-files.txt'
  [System.IO.File]::WriteAllText($testList, $listText, [System.Text.UTF8Encoding]::new($false))
  $back = @(Read-OnlinePins $testList)
  Check 'Read-OnlinePins: reads Format-OnlinePinList back' (($back | ForEach-Object { "$($_.Sha256)|$($_.Size)|$($_.RelPath)" }) -join ';') "$('1' * 64)|4294967296|a/b.dll;$('a' * 64)|5|b/c d.ssa"
  $good = "$('1' * 64) 4 a/b.dll"
  $bad = [ordered]@{
    'a BOM' = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::ASCII.GetBytes("$good`n")
    'CRLF' = [System.Text.Encoding]::ASCII.GetBytes("$good`r`n")
    'no LF at the end' = [System.Text.Encoding]::ASCII.GetBytes($good)
    'an empty line' = [System.Text.Encoding]::ASCII.GetBytes("$good`n`n")
    'invalid UTF-8' = [System.Text.Encoding]::ASCII.GetBytes("$good`n") + [byte[]](0xFF, 10)
    'uppercase hex' = [System.Text.Encoding]::ASCII.GetBytes("$('A' * 64) 4 a/b.dll`n")
    'size 0' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 0 a/b.dll`n")
    'size with sign' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) +4 a/b.dll`n")
    'size with 16 digits' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 1000000000000000 a/b.dll`n")
    'two spaces' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64)  4 a/b.dll`n")
    'a backslash' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a\b.dll`n")
    'a colon' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a/b.dll:x`n")
    'a leading slash' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 /a/b.dll`n")
    'a trailing space' = [System.Text.Encoding]::ASCII.GetBytes("$good `n")
    'an empty segment' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a//b.dll`n")
    'a .. segment' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a/../b.dll`n")
    'a tab in the path' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a/b`t.dll`n")
    'unsorted' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 b`n$('1' * 64) 4 a`n")
    'unsorted by case (ordinal)' = [System.Text.Encoding]::ASCII.GetBytes("$('1' * 64) 4 a`n$('1' * 64) 4 B`n")
    'a duplicate' = [System.Text.Encoding]::ASCII.GetBytes("$good`n$good`n")
  }
  foreach ($name in $bad.Keys) {
    [System.IO.File]::WriteAllBytes($testList, $bad[$name])
    CheckThrows "Read-OnlinePins refuses $name" { Read-OnlinePins $testList }
  }
  CheckThrows 'Read-OnlinePins refuses a missing file' { Read-OnlinePins (Join-Path $temp 'missing.txt') }
  [System.IO.File]::WriteAllBytes($testList, [System.Text.Encoding]::ASCII.GetBytes("# only a comment`n"))
  Check 'Read-OnlinePins: comments only' @(Read-OnlinePins $testList).Count 0

  $files = @([pscustomobject]@{ RelPath = 'a/b.dll'; PinPath = 'a/b.dll'; IsCode = $true },
    [pscustomobject]@{ RelPath = 'Lobby/zh-CN/x.cfg'; PinPath = 'Lobby/zh/x.cfg'; IsCode = $false },
    [pscustomobject]@{ RelPath = 'c.ssa'; PinPath = 'c.ssa'; IsCode = $false })
  $pins = @([pscustomobject]@{ RelPath = 'a/b.dll'; Sha256 = ('1' * 64); Size = 4L },
    [pscustomobject]@{ RelPath = 'Lobby/zh-CN/x.cfg'; Sha256 = ('2' * 64); Size = 4L },
    [pscustomobject]@{ RelPath = 'z.ssa'; Sha256 = ('3' * 64); Size = 4L })
  $coverage = Test-OnlinePinCoverage $files $pins
  Check 'Test-OnlinePinCoverage: missing' ($coverage.Missing -join '|') 'c.ssa'
  Check 'Test-OnlinePinCoverage: stale' ($coverage.Stale -join '|') 'z.ssa'
  $localList = Join-Path $temp 'local.sha256'
  [System.IO.File]::WriteAllLines($localList, [string[]]@("$('1' * 64)  a/b.dll", "$('9' * 64)  Lobby/zh/x.cfg", "$('8' * 64)  c.ssa"))
  $conflicts = @(Test-PinConsistency $files $pins $localList)
  Check 'Test-PinConsistency: one conflict, by the pin path of the hash list' (($conflicts | ForEach-Object { "$($_.RelPath)|$($_.PinPath)|$($_.Local)|$($_.Online)" }) -join ';') "Lobby/zh-CN/x.cfg|Lobby/zh/x.cfg|$('9' * 64)|$('2' * 64)"
  [System.IO.File]::WriteAllLines($localList, [string[]]@("$('1' * 64)  A/B.DLL", "$('2' * 64)  Lobby/zh/x.cfg"))
  Check 'Test-PinConsistency: equal pins, other paths: no conflict' @(Test-PinConsistency $files $pins $localList).Count 0
  Check 'Test-PinConsistency: without a hash list' @(Test-PinConsistency $files $pins (Join-Path $temp 'missing.sha256')).Count 0
  # The same SHA-256 in both lists, but pins\online-files.txt has another size than the file in
  # data\localized-text: the setup would reject the right file
  $pinFolder = Join-Path $temp 'pinfolder'
  New-Item -ItemType Directory -Path (Join-Path $pinFolder 'a') -Force | Out-Null
  [System.IO.File]::WriteAllText((Join-Path (Join-Path $pinFolder 'a') 'b.dll'), 'abcd')
  [System.IO.File]::WriteAllLines($localList, [string[]]@("$('1' * 64)  a/b.dll", "$('2' * 64)  Lobby/zh/x.cfg"))
  Check 'Test-PinConsistency: same hashes and sizes (Lobby/zh/x.cfg not in the folder): no conflict' @(Test-PinConsistency $files $pins $localList $pinFolder).Count 0
  [System.IO.File]::WriteAllText((Join-Path (Join-Path $pinFolder 'a') 'b.dll'), 'abcde')
  $conflicts = @(Test-PinConsistency $files $pins $localList $pinFolder)
  Check 'Test-PinConsistency: same SHA-256, another size: a conflict with both sizes' (($conflicts | ForEach-Object { "$($_.RelPath)|$($_.PinPath)|$($_.Local)|$($_.Online)|$($_.LocalSize)|$($_.OnlineSize)" }) -join ';') "a/b.dll|a/b.dll|$('1' * 64)|$('1' * 64)|5|4"
  Check 'Test-PinConsistency: another size, without the folder: not compared' @(Test-PinConsistency $files $pins $localList).Count 0
  [System.IO.File]::WriteAllLines($localList, [string[]]@("$('7' * 64)  a/b.dll"))
  $conflicts = @(Test-PinConsistency $files $pins $localList $pinFolder)
  Check 'Test-PinConsistency: another SHA-256 and another size: one conflict' (($conflicts | ForEach-Object { "$($_.RelPath)|$($_.Local)|$($_.Online)|$($_.LocalSize)|$($_.OnlineSize)" }) -join ';') "a/b.dll|$('7' * 64)|$('1' * 64)|5|4"

  # Write-OnlinePins: from a folder with the layout of /localized/, every file needed, a second copy
  # must be identical
  $copyA = Join-Path $temp 'copyA'
  $copyB = Join-Path $temp 'copyB'
  foreach ($folder in @($copyA, $copyB)) {
    foreach ($file in $files) {
      $target = Join-Path $folder ($file.RelPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      [System.IO.File]::WriteAllText($target, 'abc')
    }
  }
  $written = @(Write-OnlinePins $copyA $files $testList 'unit test' $copyB)
  Check 'Write-OnlinePins: one pin per server path' (($written | ForEach-Object { $_.RelPath }) -join '|') 'Lobby/zh-CN/x.cfg|a/b.dll|c.ssa'
  Check 'Write-OnlinePins: SHA-256 and size' "$($written[0].Sha256) $($written[0].Size)" "$abc 3"
  Check 'Write-OnlinePins: source line' (([System.IO.File]::ReadAllText($testList) -split "`n") -ccontains '# Source: unit test') $true
  [System.IO.File]::WriteAllText((Join-Path $copyB 'c.ssa'), 'abd')
  $before = [System.IO.File]::ReadAllText($testList)
  CheckThrows 'Write-OnlinePins refuses a second copy that differs' { Write-OnlinePins $copyA $files $testList 'unit test' $copyB }
  Remove-Item -LiteralPath (Join-Path $copyA 'c.ssa')
  CheckThrows 'Write-OnlinePins refuses a missing file' { Write-OnlinePins $copyA $files $testList 'unit test' $null }
  Check 'Write-OnlinePins writes nothing after an error' ([System.IO.File]::ReadAllText($testList)) $before

  # --- Get-OnlineFiles reads the code, not a copy of the list: changed copies of the script
  $variantRoot = Join-Path $temp 'variant'
  New-Item -ItemType Directory -Path $variantRoot | Out-Null
  $setupText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'setup_is6.iss'))
  Copy-Item -LiteralPath (Join-Path $repoRoot 'utils.iss') -Destination $variantRoot
  function Set-SetupVariant([string]$Pattern, [string]$Replacement) {
    $changed = [regex]::Replace($setupText, $Pattern, $Replacement)
    if ($changed -ceq $setupText) { throw "test variant: '$Pattern' not found in setup_is6.iss" }
    [System.IO.File]::WriteAllText((Join-Path $variantRoot 'setup_is6.iss'), $changed, [System.Text.UTF8Encoding]::new($true))
  }
  Set-SetupVariant "'EETheGreeks\.ssa'\]" "'EETheGreeks.ssa', 'EETheNew.ssa']"
  Check 'Get-OnlineFiles: a campaign added to RegisterOnlineFiles is listed' (@(Get-OnlineFiles $variantRoot 'EE') | Where-Object { $_.RelPath -ceq 'Game/fr/EE/Data/Campaigns/EETheNew.ssa' } | Measure-Object).Count 1
  Set-SetupVariant "(  AddGameOnlineFile\(Game, Game, GameKey, 'Data/data\.ssa'\);)" "`$1 AddGameOnlineFile(Game, Game, GameKey, 'Data/Extra.ssa');"
  Check 'Get-OnlineFiles: a file added to RegisterGameOnlineFiles is listed' (@(Get-OnlineFiles $variantRoot 'NeoEE') | Where-Object { $_.RelPath -ceq 'Game/it/AoC/Data/Extra.ssa' } | Measure-Object).Count 1
  $unknown = [ordered]@{
    'an unknown statement' = @("(  AddGameOnlineFile\(Game, Game, GameKey, 'Data/data\.ssa'\);)", "  Log('x');`$1")
    'an unknown directive' = @('(?m)(^procedure AddLocalizedGameOnlineFile\(.*\r?\nbegin\r?\n)', "`$1#ifdef Foo`r`n#endif`r`n")
    'English no longer skipped' = @("\(LangCode = 'en'\)", "(LangCode = 'xx')")
    'a game that is not a literal' = @("RegisterGameOnlineFiles\(LangCode, LobbyDir, 'AoC'", 'RegisterGameOnlineFiles(LangCode, LobbyDir, GameName')
    'no RegisterGameOnlineFiles call' = @('RegisterGameOnlineFiles\(LangCode', 'RegisterOtherOnlineFiles(LangCode')
    'GameLangCount not the number of languages' = @('(?m)^#define GameLangCount 11', '#define GameLangCount 12')
  }
  foreach ($name in $unknown.Keys) {
    Set-SetupVariant $unknown[$name][0] $unknown[$name][1]
    CheckThrows "Get-OnlineFiles refuses $name" { Get-OnlineFiles $variantRoot 'EE' }
  }

  # --- dgVoodoo (pins\dgvoodoo.txt, config\dgVoodoo): the reader of the pins, the checks of the script and of the
  # configurations, and the comparison of the files with the pins, on made-up files in a temporary folder
  # (the real dgVoodoo files are not in the repository). ci\dgvoodoo_pins.ps1 -SelfTest runs the mutants of the
  # real repository.
  $dgPinFile = Join-Path (Join-Path $repoRoot 'pins') 'dgvoodoo.txt'
  $dgPins = Read-DgVoodooPins $dgPinFile
  Check 'Read-DgVoodooPins: version' $dgPins.Version 'v2.87.5'
  Check 'Read-DgVoodooPins: archive' "$($dgPins.Archive.Size) $($dgPins.Archive.Url)" '9268078 https://github.com/dege-diosg/dgVoodoo2/releases/download/v2.87.5/dgVoodoo2_87_5.zip'
  Check 'Read-DgVoodooPins: files in ordinal order' (($dgPins.Files | ForEach-Object { $_.Name }) -join ',') 'D3DImm.dll,DDraw.dll,dgVoodooCpl.exe'
  Check 'Read-DgVoodooPins: DDraw.dll' "$($dgPins.Files[1].Size) $($dgPins.Files[1].ArchivePath) $($dgPins.Files[1].Sha256)" '255488 MS/x86/DDraw.dll 612a24408a090a3c6f3886557fa18034ee742e94ad0a40ebdf854d2816176c2e'
  Check 'Get-DgVoodooConfVersion v2.87.5' (Get-DgVoodooConfVersion 'v2.87.5') '0x287'
  Check 'Get-DgVoodooConfVersion v2.82.1' (Get-DgVoodooConfVersion 'v2.82.1') '0x282'
  Check 'Get-DgVoodooConfVersion v3.05.0' (Get-DgVoodooConfVersion 'v3.05.0') '0x305'
  CheckThrows 'Get-DgVoodooConfVersion refuses v2.8.1' { Get-DgVoodooConfVersion 'v2.8.1' }
  CheckThrows 'Get-DgVoodooConfVersion refuses 2.87.5' { Get-DgVoodooConfVersion '2.87.5' }
  CheckThrows 'Read-DgVoodooPins refuses a missing file' { Read-DgVoodooPins (Join-Path $temp 'no-dgvoodoo.txt') }
  $dgText = [System.IO.File]::ReadAllText($dgPinFile)
  $dgDdraw = @($dgText -split "`n" | Where-Object { $_ -like 'File * DDraw.dll *' })[0]
  $dgD3dimm = @($dgText -split "`n" | Where-Object { $_ -like 'File * D3DImm.dll *' })[0]
  $dgBadPins = [ordered]@{
    'a BOM' = [string][char]0xFEFF + $dgText
    'CRLF line ends' = $dgText.Replace("`n", "`r`n")
    'no LF at the end' = $dgText.TrimEnd("`n")
    'an empty line' = $dgText.Replace("Version v2.87.5`n", "Version v2.87.5`n`n")
    'an unknown line' = $dgText.Replace("Version v2.87.5`n", "Version v2.87.5`nFoo bar`n")
    'Version without a number' = $dgText.Replace('Version v2.87.5', 'Version 2.87.5')
    'a second Version' = $dgText.Replace("Version v2.87.5`n", "Version v2.87.5`nVersion v2.87.5`n")
    'Version after Archive' = $dgText.Replace("Version v2.87.5`n", '') + "Version v2.87.5`n"
    'Archive missing' = ($dgText -replace '(?m)^Archive [^\n]*\n', '')
    'a second Archive' = ($dgText -replace '(?m)^(Archive [^\n]*\n)', '$1$1')
    'Archive with http://' = $dgText.Replace(' https://github.com', ' http://github.com')
    'Archive with a double space' = $dgText.Replace('Archive 5ffde', 'Archive  5ffde')
    'no File line' = ($dgText -replace '(?m)^File [^\n]*\n', '')
    'a File line before Archive' = ($dgText -replace '(?m)^(Archive [^\n]*\n)', '').Replace("Version v2.87.5`n", "Version v2.87.5`n$dgDdraw`n")
    'uppercase hex digits' = $dgText.Replace($dgDdraw, 'File ' + $dgDdraw.Substring(5, 64).ToUpperInvariant() + $dgDdraw.Substring(69))
    'a short hash' = $dgText.Replace($dgDdraw, 'File ' + $dgDdraw.Substring(6))
    'a size of 0' = $dgText.Replace($dgDdraw, ($dgDdraw -replace '^(File \S+) \d+ ', '$1 0 '))
    'a size with a leading zero' = $dgText.Replace($dgDdraw, ($dgDdraw -replace '^(File \S+) (\d+) ', '$1 0$2 '))
    'a file name with a slash' = $dgText.Replace(' DDraw.dll MS', ' x/DDraw.dll MS')
    'a path in the archive with ..' = $dgText.Replace(' MS/x86/DDraw.dll', ' ../x86/DDraw.dll')
    'a File line with four fields' = $dgText.Replace(' MS/x86/DDraw.dll', '')
    'two File lines swapped (order)' = $dgText.Replace("$dgD3dimm`n$dgDdraw`n", "$dgDdraw`n$dgD3dimm`n")
    'a File pinned twice' = $dgText.Replace("$dgDdraw`n", "$dgDdraw`n$dgDdraw`n")
  }
  foreach ($name in $dgBadPins.Keys) {
    $file = Join-Path $temp 'bad-dgvoodoo.txt'
    [System.IO.File]::WriteAllBytes($file, [System.Text.UTF8Encoding]::new($false).GetBytes($dgBadPins[$name]))
    CheckThrows "Read-DgVoodooPins refuses $name" { Read-DgVoodooPins $file }
  }

  # The script and the configurations of the repository are fine; a copy with a defect is not
  Check 'Get-DgVoodooScriptProblems: the repository' @(Get-DgVoodooScriptProblems $repoRoot $dgPins).Count 0
  Check 'Get-DgVoodooConfProblems: the repository' @(Get-DgVoodooConfProblems $repoRoot $dgPins).Count 0
  $dgCopy = Join-Path $temp 'dg-repo'
  New-Item -ItemType Directory -Path (Join-Path $dgCopy 'config') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'config\dgVoodoo') -Destination (Join-Path $dgCopy 'config') -Recurse
  $dgSetup = Join-Path $dgCopy 'setup_is6.iss'
  $dgSetupText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'setup_is6.iss'))
  $dgSetupCases = [ordered]@{
    'DgVoodooVersion of another version' = @($dgSetupText.Replace('#define DgVoodooVersion "v2.87.5"', '#define DgVoodooVersion "v2.87.4"'), 'DgVoodooVersion')
    'the wildcard in dgVoodoo_bin' = @($dgSetupText.Replace('dgVoodoo_bin\D3DImm.dll"', 'dgVoodoo_bin\*"'), 'wildcard')
    'an unpinned file in dgVoodoo_bin' = @($dgSetupText.Replace('dgVoodoo_bin\D3DImm.dll"', 'dgVoodoo_bin\D3D9.dll"'), 'D3D9.dll is installed')
    'dgVoodooCpl.exe without Check: IsWin64' = @($dgSetupText.Replace('dx7; Check: IsWin64; AfterInstall', 'dx7; AfterInstall'), 'dgVoodooCpl.exe (x64 only) needs Check: IsWin64')
    'the configuration of dx11_lvl10_1 from the old folder' = @($dgSetupText.Replace('Source: "config\dgVoodoo\dgVoodoo_DX11_LVL10_1.conf"', 'Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10_1.conf"'), 'dgVoodoo_conf')
    'the configuration of dx11_lvl10 for another component' = @($dgSetupText.Replace('Components: additional\directx_wrapper\dx11_lvl10 and', 'Components: additional\directx_wrapper\dx11_lvl11 and'), 'must be installed with the component additional\directx_wrapper\dx11_lvl10')
    'DestDir {#EEDir} on a configuration' = @(($dgSetupText -replace '(dgVoodoo_DX11_LVL11\.conf"; DestDir: ")\{app\}\\\{#AddOnDir\}', '${1}{app}\{#EEDir}'), 'needs DestDir')
    'DestDir {#EEDir} on D3DImm.dll' = @(($dgSetupText -replace '(dgVoodoo_bin\\D3DImm\.dll"; DestDir: ")\{app\}\\\{#AddOnDir\}', '${1}{app}\{#EEDir}'), 'needs DestDir')
    '{#AddOnComp} replaced by game on a configuration' = @(($dgSetupText -replace '(dgVoodoo_DX12_LVL12\.conf"[^\r\n]*?dx12_lvl12 and )\{#AddOnComp\}', '${1}game'), 'configuration of dx12_lvl12 must be installed')
    '{#AddOnComp} replaced by game on a DLL' = @(($dgSetupText -replace '(dgVoodoo_bin\\D3DImm\.dll"[^\r\n]*?directx_wrapper and )\{#AddOnComp\}', '${1}game'), 'D3DImm.dll must be installed with')
    'and not dx9 removed from a DLL' = @(($dgSetupText -replace '(dgVoodoo_bin\\DDraw\.dll"[^\r\n]*?) and not additional\\directx_wrapper\\dx9', '$1'), 'DDraw.dll must be installed with')
    'and not dx7 removed from a DLL' = @(($dgSetupText -replace '(dgVoodoo_bin\\dgVoodooCpl\.exe"[^\r\n]*?) and not additional\\directx_wrapper\\dx7', '$1'), 'dgVoodooCpl.exe must be installed with')
    'DestName dgVoodoo.ini' = @(($dgSetupText -replace '(dgVoodoo_DX12_LVL11\.conf"; DestDir: "[^"]*"; DestName: ")dgVoodoo\.conf', '${1}dgVoodoo.ini'), 'DestName')
    'GameAddOnFiles not called for EEDir' = @(($dgSetupText -replace '(?m)^(#expr AddOnDir = EEDir[^\r\n]*\r?\n)#call GameAddOnFiles\r?\n', '$1'), 'EEDir')
  }
  foreach ($name in $dgSetupCases.Keys) {
    [System.IO.File]::WriteAllText($dgSetup, $dgSetupCases[$name][0], [System.Text.UTF8Encoding]::new($true))
    if ($dgSetupCases[$name][0] -ceq $dgSetupText) { throw "dgVoodoo test: the case '$name' changed nothing" }
    $problems = @(Get-DgVoodooScriptProblems $dgCopy $dgPins)
    Check "Get-DgVoodooScriptProblems: $name" ($problems.Count -gt 0 -and @($problems | Where-Object { $_.Contains($dgSetupCases[$name][1]) }).Count -gt 0) $true
  }
  [System.IO.File]::WriteAllText($dgSetup, $dgSetupText, [System.Text.UTF8Encoding]::new($true))
  Check 'Get-DgVoodooScriptProblems: the unchanged copy' @(Get-DgVoodooScriptProblems $dgCopy $dgPins).Count 0
  $dgConf = Join-Path $dgCopy 'config\dgVoodoo\dgVoodoo_DX12_LVL12.conf'
  $dgConfText = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($dgConf))
  $dgConfCases = [ordered]@{
    'LF line ends' = @($dgConfText.Replace("`r`n", "`n"), 'CRLF')
    'no final CRLF' = @($dgConfText.Substring(0, $dgConfText.Length - 2), 'does not end with CRLF')
    'DeferredScreenModeSwitch = true' = @(($dgConfText -replace '(DeferredScreenModeSwitch\s*= )false', '${1}true'), 'DeferredScreenModeSwitch = true')
    'Alt+Enter on' = @(($dgConfText -replace '(DisableAltEnterToToggleScreenMode\s*= )true', '${1}false'), 'DisableAltEnterToToggleScreenMode = false')
    'FullscreenAttributes removed' = @(($dgConfText -replace '(?m)^FullscreenAttributes[^\r\n]*\r\n', ''), 'FullscreenAttributes is missing')
    'FullscreenAttributes = fake, AlwaysOnTop' = @(($dgConfText -replace '(FullscreenAttributes\s*= )fake', '${1}fake, AlwaysOnTop'), 'FullscreenAttributes = fake, AlwaysOnTop')
    'Version = 0x282' = @(($dgConfText -replace '(Version\s*= )0x287', '${1}0x282'), 'Version = 0x282')
    'OutputAPI of another level' = @(($dgConfText -replace '(OutputAPI\s*= )d3d12_fl12_0', '${1}d3d12_fl11_0'), 'OutputAPI = d3d12_fl11_0')
    'VRAM = 128' = @(($dgConfText -replace '(VRAM\s*= )256', '${1}128'), 'VRAM = 128')
    'a key twice' = @(($dgConfText -replace '(?m)^(VideoCard[^\r\n]*\r\n)', '$1$1'), 'set twice')
    'WindowedAttributes changed' = @($dgConfText.Replace('FullscreenSize', 'Fullscreen'), 'differs from')
    'a non-ASCII character' = @($dgConfText.Replace('; Antialiasing', '; ' + [char]0xE9 + ' Antialiasing'), 'non-ASCII')
  }
  foreach ($name in $dgConfCases.Keys) {
    if ($dgConfCases[$name][0] -ceq $dgConfText) { throw "dgVoodoo test: the case '$name' changed nothing" }
    [System.IO.File]::WriteAllBytes($dgConf, [System.Text.Encoding]::GetEncoding(28591).GetBytes($dgConfCases[$name][0]))
    $problems = @(Get-DgVoodooConfProblems $dgCopy $dgPins)
    Check "Get-DgVoodooConfProblems: $name" ($problems.Count -gt 0 -and @($problems | Where-Object { $_.Contains($dgConfCases[$name][1]) }).Count -gt 0) $true
  }
  [System.IO.File]::WriteAllBytes($dgConf, [System.Text.Encoding]::GetEncoding(28591).GetBytes($dgConfText))
  Check 'Get-DgVoodooConfProblems: the unchanged copy' @(Get-DgVoodooConfProblems $dgCopy $dgPins).Count 0
  Remove-Item -LiteralPath $dgConf
  Check 'Get-DgVoodooConfProblems: a missing configuration' @(Get-DgVoodooConfProblems $dgCopy $dgPins | Where-Object { $_ -like '*dgVoodoo_DX12_LVL12.conf: missing*' }).Count 1

  # Test-DgVoodooFiles: made-up files and the pins that match them
  $dgFiles = Join-Path $temp 'dg-files'
  New-Item -ItemType Directory -Path $dgFiles | Out-Null
  $dgMade = [ordered]@{ 'D3DImm.dll' = [byte[]](1..40); 'DDraw.dll' = [byte[]](50..120); 'dgVoodooCpl.exe' = [byte[]](130..255) }
  $dgMadePinText = $dgText
  foreach ($name in $dgMade.Keys) {
    [System.IO.File]::WriteAllBytes((Join-Path $dgFiles $name), $dgMade[$name])
    $line = @($dgMadePinText -split "`n" | Where-Object { $_ -like "File * $name *" })[0]
    $hash = (Get-FileHash -LiteralPath (Join-Path $dgFiles $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    $dgMadePinText = $dgMadePinText.Replace($line, "File $hash $($dgMade[$name].Length) $name $(($line -split ' ')[4])")
  }
  $dgMadePinFile = Join-Path $temp 'made-dgvoodoo.txt'
  [System.IO.File]::WriteAllBytes($dgMadePinFile, [System.Text.UTF8Encoding]::new($false).GetBytes($dgMadePinText))
  $dgMadePins = Read-DgVoodooPins $dgMadePinFile
  Check 'Test-DgVoodooFiles: the pinned files' @(Test-DgVoodooFiles $dgFiles $dgMadePins).Count 0
  [System.IO.File]::WriteAllBytes((Join-Path $dgFiles 'DDraw.dll'), [byte[]]($dgMade['DDraw.dll'] + [byte]1))
  $found = @(Test-DgVoodooFiles $dgFiles $dgMadePins)
  Check 'Test-DgVoodooFiles: a file one byte longer' "$($found.Count) $($found[0].Name) $($found[0].Placeholder)" '1 DDraw.dll False'
  Check 'Test-DgVoodooFiles: a file one byte longer, message' $found[0].Problem 'DDraw.dll: 72 bytes, but pins\dgvoodoo.txt pins 71 bytes.'
  [System.IO.File]::WriteAllBytes((Join-Path $dgFiles 'DDraw.dll'), $dgMade['DDraw.dll'])
  $other = [byte[]]$dgMade['D3DImm.dll'].Clone()
  $other[3] = 99
  [System.IO.File]::WriteAllBytes((Join-Path $dgFiles 'D3DImm.dll'), $other)
  $found = @(Test-DgVoodooFiles $dgFiles $dgMadePins)
  Check 'Test-DgVoodooFiles: another content of the same size' "$($found.Count) $($found[0].Name) $($found[0].Placeholder) $($found[0].Problem.Contains('SHA-256'))" '1 D3DImm.dll False True'
  [System.IO.File]::WriteAllBytes((Join-Path $dgFiles 'D3DImm.dll'), $dgMade['D3DImm.dll'])
  Remove-Item -LiteralPath (Join-Path $dgFiles 'dgVoodooCpl.exe')
  $found = @(Test-DgVoodooFiles $dgFiles $dgMadePins)
  Check 'Test-DgVoodooFiles: a missing file' "$($found.Count) $($found[0].Name) $($found[0].Placeholder)" '1 dgVoodooCpl.exe False'
  [System.IO.File]::WriteAllText((Join-Path $dgFiles 'dgVoodooCpl.exe'), "placeholder generated by ci/make_placeholder_assets.py - not a real asset`n")
  $found = @(Test-DgVoodooFiles $dgFiles $dgMadePins)
  Check 'Test-DgVoodooFiles: a placeholder' "$($found.Count) $($found[0].Name) $($found[0].Placeholder)" '1 dgVoodooCpl.exe True'
  Check 'Test-DgVoodooFiles: a missing folder' @(Test-DgVoodooFiles (Join-Path $temp 'no-such-folder') $dgMadePins).Count 3

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
  # The real scripts: the release build reads the online file list from them (the fake ISCC
  # ignores their content), and the real pins of the online files
  foreach ($name in @('setup_is6.iss', 'utils.iss')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $repo
  }
  New-Item -ItemType Directory -Path (Join-Path $repo 'pins') | Out-Null
  $repoPins = Join-Path (Join-Path $repo 'pins') 'online-files.txt'
  Copy-Item -LiteralPath $realList -Destination $repoPins
  # The dgVoodoo files of the copy: made-up files and the pin list that matches them (the real files are not in the
  # repository); the release build compares them (pins\dgvoodoo.txt)
  $repoDgPins = Join-Path (Join-Path $repo 'pins') 'dgvoodoo.txt'
  Copy-Item -LiteralPath $dgMadePinFile -Destination $repoDgPins
  $repoDgFolder = Join-Path $repo 'data\Add-on\DirectX_Wrapper\dgVoodoo_bin'
  function New-DryDgVoodooFiles {
    New-Item -ItemType Directory -Path $repoDgFolder -Force | Out-Null
    foreach ($name in $dgMade.Keys) { [System.IO.File]::WriteAllBytes((Join-Path $repoDgFolder $name), $dgMade[$name]) }
  }
  New-DryDgVoodooFiles
  # The copy is a Git checkout (if Git exists), so that test builds get test<TestID>-<commit>; the
  # dry runs are no CI runs unless a case says so
  $repoCommit = ''
  if ($git) { $repoCommit = New-TestCheckout $repo }
  $testBuild = 'test1'
  if ($repoCommit) { $testBuild = "test1-$repoCommit" }
  $savedGitHubActions = $env:GITHUB_ACTIONS
  $env:GITHUB_ACTIONS = $null
  $calls = Join-Path $temp 'iscc_calls.txt'
  $fakeIscc = Join-Path $temp 'fake_iscc.ps1'
  $fake = @'
$script = (Resolve-Path -LiteralPath ([string]$args[-1])).ProviderPath
Add-Content -LiteralPath '%CALLS%' -Value ($args -join ' ')
if ($script -like '*version_probe.iss') { 'ISCC_VERSION=6.2.2'; exit 0 }
$match = [regex]::Match([System.IO.File]::ReadAllText($script), 'SaveToFile\(AddBackslash\(SourcePath\) \+ "([^"]+)"\)')
if ($match.Success) {
  $resolved = '; resolved'
  if (Test-Path -LiteralPath '%HOOKFLAG%') { $resolved += " Test hook of a placeholder build" }
  [System.IO.File]::WriteAllText((Join-Path (Split-Path -Parent $script) $match.Groups[1].Value), $resolved)
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
  $hookFlag = Join-Path $temp 'fake_iscc_hook.flag'
  [System.IO.File]::WriteAllText($fakeIscc, $fake.Replace('%CALLS%', $calls).Replace('%HOOKFLAG%', $hookFlag))
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
  Check "dry run -TestID 1: /DSetupBuild=$testBuild in every compile" @($lines | Where-Object { " $_ " -like "* /DSetupBuild=$testBuild *" }).Count 4
  Check 'dry run -TestID 1: version probe without SetupBuild' ($lines[0] -like '*/DSetupBuild*') $false
  Check 'dry run -TestID 1: SetupBuild printed' @($buildOutput | Where-Object { $_ -ceq "SetupBuild: $testBuild" }).Count 1
  Check 'dry run -TestID 1: setups' @(Get-ChildItem -LiteralPath (Join-Path $repo 'out') -Recurse -Filter '*.exe').Count 2
  Check 'dry run -TestID 1: no test hook of the placeholder builds (/DPlaceholderInstallPause) in any call' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*PlaceholderInstallPause*' }).Count 0
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

  # pins\online-files.txt pins every online file: no warning, no list
  Check 'dry run -TestID 1: the pins are counted' @($buildOutput | Where-Object { $_ -ceq 'Pins: 230 online file(s) in pins\online-files.txt.' }).Count 1
  Check 'dry run -TestID 1: no list of online files' @($buildOutput | Where-Object { $_ -like '    *' -or $_ -like '*without a pin*' -or $_ -like '*no pin*' }).Count 0

  # A release build checks the same; without data\localized-text there is nothing to compare
  Remove-Item -LiteralPath $calls
  $buildOutput = @(& $build @common 3>&1 6>&1 | ForEach-Object { "$_" })
  Check 'dry run without -TestID: exit code' $LASTEXITCODE 0
  Check 'dry run without -TestID: no /DTestID (default of setup_is6.iss)' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DTestID*' }).Count 0
  Check 'dry run without -TestID, not in CI: no /DSetupBuild' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DSetupBuild*' }).Count 0
  Check 'dry run without -TestID, not in CI: no SetupBuild printed' @($buildOutput | Where-Object { $_ -like 'SetupBuild: none*' }).Count 1
  Check 'dry run release: the pins are counted' @($buildOutput | Where-Object { $_ -ceq 'Pins: 230 online file(s) in pins\online-files.txt.' }).Count 1
  Check 'dry run release: the hash list agrees' @($buildOutput | Where-Object { $_ -like 'Pins: data\localized-text and pins\online-files.txt agree*' }).Count 1
  Check 'dry run release: the dgVoodoo files are the pinned ones' @($buildOutput | Where-Object { $_ -ceq 'dgVoodoo: 3 file(s) of v2.87.5 match pins\dgvoodoo.txt.' }).Count 1

  # ... and in CI (GitHub Actions) a release build gets the short commit as SetupBuild
  Remove-Item -LiteralPath $calls
  $env:GITHUB_ACTIONS = 'true'
  try {
    $buildOutput = @(& $build @common -TestID 0 3>&1 6>&1 | ForEach-Object { "$_" })
  } finally {
    $env:GITHUB_ACTIONS = $null
  }
  Check 'dry run -TestID 0: /DTestID=0 in every compile' @(Get-Content -LiteralPath $calls | Where-Object { " $_ " -like '* /DTestID=0 *' }).Count 4
  Check 'dry run -TestID 0: no test hook of the placeholder builds in any call' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*PlaceholderInstallPause*' }).Count 0
  if ($repoCommit) {
    Check 'dry run -TestID 0 in CI: /DSetupBuild=<commit> in every compile' @(Get-Content -LiteralPath $calls | Where-Object { " $_ " -like "* /DSetupBuild=$repoCommit *" }).Count 4
  } else {
    Check 'dry run -TestID 0 in CI without Git: no /DSetupBuild' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DSetupBuild*' }).Count 0
  }

  # Runs build.ps1 and returns its output and the message of the exception that stopped it ('' if none)
  function Invoke-DryBuild([hashtable]$Parameters) {
    $message = ''
    $output = [System.Collections.Generic.List[string]]::new()
    try {
      & $build @Parameters 3>&1 6>&1 | ForEach-Object { $output.Add("$_") }
    } catch {
      $message = $_.Exception.Message
    }
    return [pscustomobject]@{ Output = $output.ToArray(); Error = $message }
  }

  # The resolved script holds a line of the test hook of the placeholder builds, but the build is none (-Placeholders is not
  # given): it stops before ISCC compiles (a build with the real data must not pause in its install step)
  [System.IO.File]::WriteAllText($hookFlag, 'x')
  Remove-Item -LiteralPath $calls
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, hook in the resolved script: stops' ($run.Error -like 'The resolved script holds the test hook of the placeholder builds without -Placeholders (*') $true
  Check 'dry run release, hook in the resolved script: no compile' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DInstallType=*' -and $_ -notlike '*/O- *' }).Count 0
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, hook in the resolved script: stops too' ($run.Error -like 'The resolved script holds the test hook of the placeholder builds without -Placeholders (*') $true
  Remove-Item -LiteralPath $hookFlag

  # A dgVoodoo file of data\ that is not the pinned one (ADR 0005): a release build stops before ISCC compiles, a
  # test build warns and compiles; a placeholder counts as another file; the old folder dgVoodoo_conf is only a warning
  $dgBuildDdraw = Join-Path $repoDgFolder 'DDraw.dll'
  [System.IO.File]::WriteAllBytes($dgBuildDdraw, [byte[]]($dgMade['DDraw.dll'] + [byte]1))
  Remove-Item -LiteralPath $calls
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, other dgVoodoo file: stops' $run.Error 'Release build: the dgVoodoo files of data\ are not those of pins\dgvoodoo.txt (listed above).'
  Check 'dry run release, other dgVoodoo file: names it' @($run.Output | Where-Object { $_ -ceq '    DDraw.dll: 72 bytes, but pins\dgvoodoo.txt pins 71 bytes.' }).Count 1
  Check 'dry run release, other dgVoodoo file: no compile' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DInstallType=*' -and $_ -notlike '*/O- *' }).Count 0
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, other dgVoodoo file: no stop' $run.Error ''
  Check 'dry run test build, other dgVoodoo file: warning' @($run.Output | Where-Object { $_ -like 'Test build: 1 dgVoodoo file(s) of data\ are not those of pins\dgvoodoo.txt (listed above)*' }).Count 1
  Check 'dry run test build, other dgVoodoo file: compiled' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DInstallType=*' -and $_ -notlike '*/O- *' }).Count 2
  [System.IO.File]::WriteAllText($dgBuildDdraw, "placeholder generated by ci/make_placeholder_assets.py - not a real asset`n")
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, dgVoodoo placeholder: stops' $run.Error 'Release build: the dgVoodoo files of data\ are not those of pins\dgvoodoo.txt (listed above).'
  Check 'dry run release, dgVoodoo placeholder: names it' @($run.Output | Where-Object { $_ -like '    DDraw.dll: is a placeholder*' }).Count 1
  [System.IO.File]::WriteAllBytes($dgBuildDdraw, $dgMade['DDraw.dll'])
  $oldConf = Join-Path $repo 'data\Add-on\DirectX_Wrapper\dgVoodoo_conf'
  New-Item -ItemType Directory -Path $oldConf | Out-Null
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, old dgVoodoo_conf folder: no stop' $run.Error ''
  Check 'dry run release, old dgVoodoo_conf folder: warning' @($run.Output | Where-Object { $_ -like 'data\Add-on\DirectX_Wrapper\dgVoodoo_conf is no longer read*' }).Count 1
  Remove-Item -LiteralPath $oldConf

  # A file in data\localized-text that pins another file than pins\online-files.txt (the hash list
  # of the same run counts): a release build stops before ISCC compiles, a test build warns
  $pinned = Join-Path $repo 'data\localized-text\Game\de\EE\Data\data.ssa'
  New-Item -ItemType Directory -Path (Split-Path -Parent $pinned) -Force | Out-Null
  [System.IO.File]::WriteAllText($pinned, 'voices')
  Remove-Item -LiteralPath $calls
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, other file in data\localized-text: stops' $run.Error 'Release build: data\localized-text and pins\online-files.txt pin different files or sizes (listed above).'
  Check 'dry run release, other file in data\localized-text: names it' @($run.Output | Where-Object { $_ -like '    Game/de/EE/Data/data.ssa (Game/de/EE/Data/data.ssa): * here, a52c99648a3e4f6511253c6c0386fd26fffeb96443a1ae1f9ae87611e990e4e6 in pins\online-files.txt' }).Count 1
  Check 'dry run release, other file in data\localized-text: no compile' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DInstallType=*' -and $_ -notlike '*/O- *' }).Count 0
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, other file in data\localized-text: no stop' $run.Error ''
  Check 'dry run test build, other file in data\localized-text: warning' @($run.Output | Where-Object { $_ -like 'Test build: 1 online file(s) are pinned differently*' }).Count 1
  # -DownloadHashesOnly writes the list and names the difference too
  $run = Invoke-DryBuild @{ DownloadHashesOnly = $true }
  Check '-DownloadHashesOnly, other file in data\localized-text: warning' @($run.Output | Where-Object { $_ -like 'Hash list: 1 online file(s) are pinned differently*' }).Count 1

  # pins\online-files.txt pins the same file (SHA-256) as data\localized-text, but with another
  # size (hand edit, merge conflict): a release build stops, a test build warns; with the right
  # size they agree
  $voicesHash = (Get-FileHash -LiteralPath $pinned -Algorithm SHA256).Hash.ToLowerInvariant()
  function Set-TestPin([long]$Size) {
    $text = [System.IO.File]::ReadAllText($realList)
    $pattern = '(?m)^[0-9a-f]{64} [0-9]+ Game/de/EE/Data/data\.ssa$'
    if ([regex]::Matches($text, $pattern).Count -ne 1) { throw 'Set-TestPin: the pin of Game/de/EE/Data/data.ssa not found once' }
    [System.IO.File]::WriteAllText($repoPins, [regex]::Replace($text, $pattern, "$voicesHash $Size Game/de/EE/Data/data.ssa"), [System.Text.UTF8Encoding]::new($false))
  }
  Set-TestPin 7
  Remove-Item -LiteralPath $calls
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, pinned size not the size of the file: stops' $run.Error 'Release build: data\localized-text and pins\online-files.txt pin different files or sizes (listed above).'
  Check 'dry run release, pinned size not the size of the file: names both sizes' @($run.Output | Where-Object { $_ -ceq '    Game/de/EE/Data/data.ssa (Game/de/EE/Data/data.ssa): 6 bytes here, 7 in pins\online-files.txt with the same SHA-256 (its size is wrong)' }).Count 1
  Check 'dry run release, pinned size not the size of the file: no compile' @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DInstallType=*' -and $_ -notlike '*/O- *' }).Count 0
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, pinned size not the size of the file: no stop' $run.Error ''
  Check 'dry run test build, pinned size not the size of the file: warning' @($run.Output | Where-Object { $_ -like 'Test build: 1 online file(s) are pinned differently*a size in pins\online-files.txt is wrong*' }).Count 1
  Set-TestPin 6
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, same SHA-256 and size: no stop' $run.Error ''
  Check 'dry run release, same SHA-256 and size: they agree' @($run.Output | Where-Object { $_ -like 'Pins: data\localized-text and pins\online-files.txt agree*' }).Count 1
  Copy-Item -LiteralPath $realList -Destination $repoPins -Force

  # A placeholder build (CI) does not compare: its data\localized-text holds placeholders. The fake
  # Python stands in for the placeholder generator.
  $fakePython = Join-Path $temp 'fake_python.ps1'
  [System.IO.File]::WriteAllText($fakePython, 'exit 0')
  Remove-Item -LiteralPath $calls
  $buildOutput = @(& $build -Iscc $fakeIscc -Variants @('EE/Regular') -Placeholders -Python $fakePython 3>&1 6>&1 | ForEach-Object { "$_" })
  Check 'dry run -Placeholders: exit code' $LASTEXITCODE 0
  Check 'dry run -Placeholders: not compared' @($buildOutput | Where-Object { $_ -like 'Pins: data\localized-text holds placeholders, not compared*' }).Count 1
  Check 'dry run -Placeholders: no list' @($buildOutput | Where-Object { $_ -like '    *' -or $_ -like 'Release build:*' }).Count 0
  Check 'dry run -Placeholders: dgVoodoo not compared' @($buildOutput | Where-Object { $_ -ceq 'dgVoodoo: data holds placeholders, not compared with pins\dgvoodoo.txt.' }).Count 1
  Remove-Item -LiteralPath (Join-Path $repo 'data') -Recurse -Force
  New-DryDgVoodooFiles

  # An online file without a pin in pins\online-files.txt stops a release build, also the
  # placeholder build of CI; a test build warns and names the files without any pin. A pin of a
  # path that no setup downloads stops every build.
  $realText = [System.IO.File]::ReadAllText($realList)
  $voices = @($realText -split "`n" | Where-Object { $_ -like '* Game/de/EE/Data/data.ssa' })[0]
  [System.IO.File]::WriteAllText($repoPins, $realText.Replace("$voices`n", ''), [System.Text.UTF8Encoding]::new($false))
  $run = Invoke-DryBuild ($common + @{ TestID = 0 })
  Check 'dry run release, missing pin: stops' $run.Error 'Release build: 1 online file(s) have no pin in pins\online-files.txt (listed above); pin them with ci\online_pins.ps1 -Update (docs\SERVER-OPERATIONS.md, section 6).'
  Check 'dry run release, missing pin: names it' @($run.Output | Where-Object { $_ -ceq '    Game/de/EE/Data/data.ssa' }).Count 1
  $run = Invoke-DryBuild @{ Iscc = $fakeIscc; Variants = @('EE/Regular'); Placeholders = $true; Python = $fakePython }
  Check 'dry run -Placeholders, missing pin: stops' ($run.Error -like 'Release build: 1 online file(s) have no pin*') $true
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, missing pin: no stop' $run.Error ''
  Check 'dry run test build, missing pin: warning' @($run.Output | Where-Object { $_ -like 'Test build: 1 online file(s) have no pin in pins\online-files.txt; 1 of them*' }).Count 1
  Check 'dry run test build, missing pin: names it' @($run.Output | Where-Object { $_ -ceq '    Game/de/EE/Data/data.ssa' }).Count 1
  [System.IO.File]::WriteAllText($repoPins, $realText + "$('0' * 64) 1 Mods/NeoEE/Lobby/zz/EE/WONLobby.cfg`n", [System.Text.UTF8Encoding]::new($false))
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run test build, stale pin: stops' ($run.Error -like 'pins\online-files.txt pins 1 path(s) that no setup downloads*') $true
  [System.IO.File]::WriteAllText($repoPins, $realText.Replace("`n", "`r`n"), [System.Text.UTF8Encoding]::new($false))
  $run = Invoke-DryBuild ($common + @{ TestID = 1 })
  Check 'dry run, malformed pin list: stops' ($run.Error -like '*online-files.txt: has a CR*') $true
  Copy-Item -LiteralPath $realList -Destination $repoPins -Force

  # -SetupBuild wins over the default, also in a test build; '' passes none
  Remove-Item -LiteralPath $calls
  & $build @common -TestID 1 -SetupBuild 'v2.0.0-rc_1' 3>$null 6>$null | Out-Null
  Check 'dry run -SetupBuild: /DSetupBuild=v2.0.0-rc_1 in every compile' @(Get-Content -LiteralPath $calls | Where-Object { " $_ " -like '* /DSetupBuild=v2.0.0-rc_1 *' }).Count 4
  Remove-Item -LiteralPath $calls
  & $build @common -TestID 1 -SetupBuild '' 3>$null 6>$null | Out-Null
  Check "dry run -SetupBuild '': no /DSetupBuild" @(Get-Content -LiteralPath $calls | Where-Object { $_ -like '*/DSetupBuild*' }).Count 0

  Remove-Item -LiteralPath $calls
  CheckThrows 'build.ps1 refuses -TestID -1' { & $build @common -TestID -1 3>$null 6>$null }
  CheckThrows 'build.ps1 refuses -TestID abc' { & $build @common -TestID abc 3>$null 6>$null }
  CheckThrows 'build.ps1 refuses -SetupBuild with a space' { & $build @common -SetupBuild 'a b' 3>$null 6>$null }
  CheckThrows 'build.ps1 refuses -SetupBuild with a brace' { & $build @common -SetupBuild '{app}' 3>$null 6>$null }
  Check 'build.ps1 calls no ISCC for an invalid -TestID or -SetupBuild' (Test-Path -LiteralPath $calls) $false

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
  if (Test-Path variable:savedGitHubActions) { $env:GITHUB_ACTIONS = $savedGitHubActions }
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -eq 0) {
  Write-Host "RESULT: PASS ($script:Count checks)"
  exit 0
}
Write-Host "RESULT: FAIL ($script:Failures of $script:Count checks)"
exit 1
