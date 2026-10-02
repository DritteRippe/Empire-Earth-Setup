<#
.SYNOPSIS
  Helper functions of ci\build.ps1 that do not need Inno Setup: the SHA-256 list of the online
  localized files, the DER copy of the signing certificate and the ISCC switch of the test build
  number.

.DESCRIPTION
  Dot-sourced by ci\build.ps1 and by ci\tests\build_helpers.tests.ps1. Kept free of ISCC and of
  Windows-only APIs, so the functions also run with PowerShell 7 on Linux (tests, local builds
  under Wine). Works with Windows PowerShell 5.1 and PowerShell 7.
#>

# SHA-256 list of the online localized files in sha256sum format ("<hash>  <path>", paths relative
# to $Folder with forward slashes, sorted ordinally, UTF-8 without BOM). downloads.iss compiles it
# into the setup: a downloaded file that can contain code (Language.dll) is only installed if it is
# in this list, a listed data file only if it matches. ISPP 6.2 has no SHA-256 function, so the
# list has to be written before compiling. The paths are those of data\localized-text: the setup
# maps the server paths of languages that share a lobby folder (Lobby/zh-CN/, Lobby/zh-TW/ ->
# Lobby/zh/) itself (GameLangLobbyDirs, RegisterGameOnlineFiles in setup_is6.iss).
function Write-DownloadHashes([string]$Folder, [string]$ListFile) {
  if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Warning "$Folder not found: the setups will download no Language.dll, only data files over HTTPS."
    return
  }
  $base = (Get-Item -LiteralPath $Folder).FullName.TrimEnd('\', '/')
  $entries = @(Get-ChildItem -LiteralPath $Folder -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($base.Length).TrimStart('\', '/').Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    [pscustomobject]@{ Path = $relative; Line = "$hash  $relative" }
  })
  # Ordinal order: the same list on every system and culture
  $sorted = [System.Collections.Generic.List[object]]::new()
  foreach ($entry in $entries) { $sorted.Add($entry) }
  $sorted.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.Path, $b.Path) })
  $lines = [string[]]@($sorted | ForEach-Object { $_.Line })
  [System.IO.File]::WriteAllLines($ListFile, $lines, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Download hashes: $($lines.Count) file(s) of $Folder -> $ListFile"
}

# Reads the X.509 certificate file $Path, DER or PEM encoded, and returns its DER encoding (the
# bytes whose SHA-1 is the thumbprint). PEM must contain exactly one "CERTIFICATE" block and
# nothing else (no private key, no second certificate, no text around it): anything else throws,
# so a wrong file cannot slip into a signed setup.
function Read-CertificateDer([string]$Path) {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $offset = 0
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
  $text = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, $bytes.Length - $offset)

  if ($text.TrimStart().StartsWith('-----BEGIN ')) {
    $pattern = '-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]*)-----END CERTIFICATE-----'
    $blocks = [regex]::Matches($text, $pattern)
    if ($blocks.Count -ne 1) {
      throw "${Path}: expected exactly one PEM certificate, found $($blocks.Count)."
    }
    if ($text.Remove($blocks[0].Index, $blocks[0].Length).Trim() -ne '') {
      throw "${Path}: the PEM file contains more than the certificate (a key, a second block or text)."
    }
    try {
      $der = [Convert]::FromBase64String(($blocks[0].Groups[1].Value -replace '\s', ''))
    } catch {
      throw "${Path}: the PEM certificate is not valid base64."
    }
  } else {
    $der = $bytes
  }

  # Must be one complete X.509 certificate in DER (RawData is exactly the DER encoding)
  try {
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$der)
  } catch {
    throw "${Path}: not an X.509 certificate (DER or PEM)."
  }
  $raw = $certificate.RawData
  if ($raw.Length -ne $der.Length -or [Convert]::ToBase64String($raw) -ne [Convert]::ToBase64String($der)) {
    throw "${Path}: not a single DER encoded X.509 certificate."
  }
  return ,([byte[]]$der)
}

# SHA-1 thumbprint (lowercase hex, as CertHashSHA1 in setup_is6.iss) of DER bytes
function Get-Sha1Hex([byte[]]$Bytes) {
  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  try {
    return (($sha1.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha1.Dispose()
  }
}

# Writes the DER encoding of the certificate $Path (DER or PEM) to $Destination and returns its
# encoding and thumbprint. The setup has to ship DER: its SHA-1 is the thumbprint that ISPP checks
# against CertHashSHA1 and the setup checks before adding the certificate (IsCertificateFileGenuine),
# and ISPP cannot decode PEM (no base64 decoding, no binary strings).
function ConvertTo-DerCertificateFile([string]$Path, [string]$Destination) {
  $der = Read-CertificateDer $Path
  $directory = Split-Path -Parent $Destination
  if ($directory -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [System.IO.File]::WriteAllBytes($Destination, $der)
  $source = [System.IO.File]::ReadAllBytes($Path)
  $encoding = 'PEM'
  if ($source.Length -eq $der.Length -and [Convert]::ToBase64String($source) -eq [Convert]::ToBase64String($der)) { $encoding = 'DER' }
  return [pscustomobject]@{ Encoding = $encoding; Thumbprint = (Get-Sha1Hex $der); Path = $Destination }
}

# CertHashSHA1 as setup_is6.iss reads it: lowercase, without spaces (e.g. copied from the Windows
# certificate dialog)
function ConvertTo-Thumbprint([string]$Value) {
  return ($Value -replace '\s', '').ToLowerInvariant()
}

# ISCC switch of the test build number (ci\build.ps1 -TestID): "/DTestID=<n>". Only a whole number
# >= 0 written with digits is accepted (0 = release build, > 0 = test build, see setup_is6.iss);
# anything else (negative, fraction, sign, text, empty) throws, so ISCC never sees it.
function Get-TestIdDefine($TestID) {
  $number = 0
  $style = [System.Globalization.NumberStyles]::None
  if (-not [int]::TryParse("$TestID", $style, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
    throw "TestID '$TestID' is not a whole number >= 0 (0 = release build, > 0 = test build)."
  }
  return "/DTestID=$number"
}
