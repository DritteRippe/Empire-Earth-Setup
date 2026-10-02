<#
.SYNOPSIS
  Helper functions of ci\build.ps1 that do not need Inno Setup: the SHA-256 list of the online
  localized files, the DER copy of the signing certificate, the ISCC switches of the test build
  number and of the build identifier, the SHA-256 file of every built setup and the list of online
  files without a pin.

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

# Build identifier of the setups (ISCC /DSetupBuild, ADR 0004 point 10): the setups write it into
# install.ini and the install record (contract 1.1, 1.2), so that builds of the same MySetupVersion
# can be told apart. A test build (TestID > 0) gets "test<TestID>-<commit>" ("test<TestID>"
# without a commit), a build in CI ($IsCI: GitHub Actions) the short commit, every other build none
# (''), e.g. a local release build. $Commit is the short Git commit (Get-GitShortCommit), '' if it
# is unknown.
function Get-SetupBuild([int]$TestID, [string]$Commit, [bool]$IsCI) {
  if ($TestID -gt 0) {
    if ($Commit) { return "test$TestID-$Commit" }
    return "test$TestID"
  }
  if ($IsCI) { return $Commit }
  return ''
}

# Checks a build identifier like setup_is6.iss does: '' (none) or at most 64 characters of
# A-Z a-z 0-9 . _ - (it goes into the registry, into install.ini, which is ASCII, and onto the ISCC
# command line). Returns it; anything else throws, so ISCC never sees it.
function Assert-SetupBuild([string]$Value) {
  if ($Value -cnotmatch '^[A-Za-z0-9._-]{0,64}\z') {
    throw "SetupBuild '$Value' is not a build identifier (at most 64 characters of A-Z a-z 0-9 . _ -)."
  }
  return $Value
}

# ISCC switch of the build identifier $Value: "/DSetupBuild=<value>", nothing for '' (the default of
# setup_is6.iss: no SetupBuild value). An invalid value throws (Assert-SetupBuild).
function Get-SetupBuildDefine([string]$Value) {
  $Value = Assert-SetupBuild $Value
  if ($Value -eq '') { return @() }
  return @("/DSetupBuild=$Value")
}

# Short commit of the Git checkout $Root ("git rev-parse --short=7 HEAD": 7 or more lowercase hex
# digits), '' if Git is missing or $Root is not a checkout.
function Get-GitShortCommit([string]$Root) {
  $git = Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $git) { return '' }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'   # stderr lines of a native command must not throw
  try {
    $output = & $git.Source -C $Root rev-parse --short=7 HEAD 2>$null
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  $commit = "$output".Trim()
  if ($code -eq 0 -and $commit -cmatch '^[0-9a-f]{7,40}\z') { return $commit }
  return ''
}

# Writes the SHA-256 of the file $Path to $Destination (default: "$Path.sha256") in sha256sum format:
# "<64 lowercase hex digits><space><space><file name>" and one LF, UTF-8 without BOM. Only the file
# name is written, not the folder, so "sha256sum -c <file>.sha256" works in the folder that holds
# both files, wherever they were copied to. An existing file is overwritten. Returns the hash and
# the path of the checksum file. ci\build.ps1 calls it for every setup it built (README, "Checksums
# of the setups"); players compare the hash with Get-FileHash.
function Write-FileSha256([string]$Path, [string]$Destination) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "${Path}: file not found, no SHA-256 written."
  }
  # .NET resolves relative paths against the process folder, not the PowerShell location
  $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
  if (-not $Destination) { $Destination = "$Path.sha256" }
  $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
  $hash =(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  $name = [System.IO.Path]::GetFileName($Path)
  # sha256sum escapes such names with a leading backslash; setup names never contain them
  if ($name.IndexOfAny([char[]]"`r`n\") -ge 0) {
    throw "${Path}: the file name cannot be written in sha256sum format (line break or backslash)."
  }
  [System.IO.File]::WriteAllText($Destination, "$hash  $name`n", [System.Text.UTF8Encoding]::new($false))
  return [pscustomobject]@{ Hash = $hash; Path = $Destination }
}

# --- Online files without a pin (ci\build.ps1, release builds; ADR 0008 point 6)
#
# Inno Setup's built-in downloads follow a redirect from https:// to http:// (Wine probe of S-WP5,
# ADR 0008 "Implementation"), so an online file without a SHA-256 pin is only as safe as the
# configuration of the file servers. A release build lists these files. The list comes from the
# same source as the setup's own list: the code of RegisterOnlineFiles and of the procedures it
# calls in setup_is6.iss, the game languages there (GameLangs, GameLangLobbyDirs) and
# CodeFileExtensions in utils.iss. Only the statement forms that code uses are understood; anything
# else throws, so that a change of that code cannot silently change the list (the CI build is a
# release build and runs it on every push).

# Text of a Pascal Script source without "//" comments, quoted strings kept
function Remove-PascalComment([string]$Line) {
  $inString = $false
  for ($i = 0; $i -lt $Line.Length; $i++) {
    if ($Line[$i] -eq "'") { $inString = -not $inString; continue }
    if (-not $inString -and $Line[$i] -eq '/' -and $i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '/') {
      return $Line.Substring(0, $i)
    }
  }
  return $Line
}

# Splits $Text at $Separator outside quoted strings, brackets and parentheses; trims the parts
function Split-PascalTopLevel([string]$Text, [char]$Separator) {
  $parts = [System.Collections.Generic.List[string]]::new()
  $depth = 0
  $inString = $false
  $start = 0
  for ($i = 0; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($c -eq "'") { $inString = -not $inString; continue }
    if ($inString) { continue }
    if ($c -eq '(' -or $c -eq '[') { $depth++ }
    elseif ($c -eq ')' -or $c -eq ']') { $depth-- }
    elseif ($c -eq $Separator -and $depth -eq 0) {
      $parts.Add($Text.Substring($start, $i - $start).Trim())
      $start = $i + 1
    }
  }
  if ($inString -or $depth -ne 0) { throw "Unbalanced quotes or brackets in: $Text" }
  $parts.Add($Text.Substring($start).Trim())
  return $parts.ToArray()
}

# The lines of $Lines that ISPP keeps for $InstallType. Only "#if InstallType == "X"",
# "#if InstallType != "X"", "#else" and "#endif" are understood; any other directive throws.
function Select-InstallTypeLines([string[]]$Lines, [string]$InstallType, [string]$Where) {
  $kept = [System.Collections.Generic.List[string]]::new()
  $stack = [System.Collections.Generic.List[object]]::new()
  foreach ($line in $Lines) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith('#')) {
      if ($trimmed -match '^#if\s+InstallType\s*(==|!=)\s*"(\w+)"$') {
        $match = ($Matches[2] -eq $InstallType)
        if ($Matches[1] -eq '!=') { $match = -not $match }
        $stack.Add(@{ Condition = $match; Else = $false })
      } elseif ($trimmed -eq '#else' -and $stack.Count -gt 0 -and -not $stack[$stack.Count - 1].Else) {
        $stack[$stack.Count - 1].Else = $true
        $stack[$stack.Count - 1].Condition = -not $stack[$stack.Count - 1].Condition
      } elseif ($trimmed -eq '#endif' -and $stack.Count -gt 0) {
        $stack.RemoveAt($stack.Count - 1)
      } else {
        throw "${Where}: preprocessor line '$trimmed' is not understood by Get-OnlineFiles (ci\build_helpers.ps1)."
      }
      continue
    }
    if (@($stack | Where-Object { -not $_.Condition }).Count -eq 0) { $kept.Add($line) }
  }
  if ($stack.Count -ne 0) { throw "${Where}: #if without #endif." }
  return $kept.ToArray()
}

# Parameter names and statements (comments removed, split at ";") of the procedure $Name in $Lines
function Get-PascalProcedure([string[]]$Lines, [string]$Name, [string]$InstallType, [string]$File) {
  $head = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^procedure\s+$Name\s*\(") {
      if ($head -ge 0) { throw "${File}: procedure $Name is defined twice." }
      $head = $i
    }
  }
  if ($head -lt 0) { throw "${File}: procedure $Name not found." }
  $begin = -1
  for ($i = $head; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match '^begin\s*$') { $begin = $i; break } }
  $end = -1
  for ($i = $begin + 1; $begin -ge 0 -and $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match '^end;\s*$') { $end = $i; break } }
  if ($begin -lt 0 -or $end -lt 0) { throw "${File}: body of procedure $Name not found (begin/end; in the first column)." }

  $header = ($Lines[$head..($begin - 1)] | ForEach-Object { Remove-PascalComment $_ }) -join ' '
  if ($header -notmatch "^procedure\s+$Name\s*\((.*?)\)\s*;") { throw "${File}: parameter list of $Name not understood." }
  $parameters = [System.Collections.Generic.List[string]]::new()
  if ($Matches[1].Trim()) {
    foreach ($group in ($Matches[1] -split ';')) {
      $names = ($group -split ':')[0] -replace '^\s*(const|var)\s+', ''
      foreach ($parameter in ($names -split ',')) { $parameters.Add($parameter.Trim()) }
    }
  }
  $bodyLines = @()
  if ($end -gt $begin + 1) { $bodyLines = $Lines[($begin + 1)..($end - 1)] }
  $kept = @(Select-InstallTypeLines $bodyLines $InstallType "$File, $Name")
  $body = @($kept | ForEach-Object { Remove-PascalComment $_ }) -join ' '
  $statements = @(@(Split-PascalTopLevel $body ';') | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ })
  return [pscustomobject]@{ Name = $Name; Parameters = $parameters.ToArray(); Statements = $statements; Text = $body }
}

# Value of a string expression of these procedures: quoted strings, variables and "Array[I]"
# joined with "+"
function Get-PascalStringValue([string]$Expression, [hashtable]$Variables, [string]$Where) {
  $value = ''
  foreach ($term in @(Split-PascalTopLevel $Expression '+')) {
    if ($term -match "^'((?:[^']|'')*)'$") { $value += $Matches[1].Replace("''", "'") }
    elseif ($Variables.ContainsKey($term) -and $Variables[$term] -is [string]) { $value += $Variables[$term] }
    else { throw "${Where}: '$term' in '$Expression' is not understood by Get-OnlineFiles (ci\build_helpers.ps1)." }
  }
  return $value
}

# Runs the statement $Statement of a download procedure with $Variables: assignments, calls of the
# procedures in $Procedures, "for I := 0 to GetArrayLength(<array>) - 1 do <call>",
# "if <Boolean parameter> then <call>", and AddOnlineFile (downloads.iss), which adds
# RelPath/PinPath to $Found
function Invoke-OnlineFileStatement([string]$Statement, [hashtable]$Variables, [hashtable]$Procedures, $Found, [string]$Where) {
  if ($Statement -match '^for (\w+) := 0 to GetArrayLength\((\w+)\) - 1 do (.+)$') {
    $index, $arrayName, $inner = $Matches[1], $Matches[2], $Matches[3]
    if (-not $Variables.ContainsKey($arrayName) -or $Variables[$arrayName] -isnot [array]) { throw "${Where}: '$arrayName' is not an array parameter." }
    foreach ($element in $Variables[$arrayName]) {
      $loop = $Variables.Clone()
      $loop["$arrayName[$index]"] = [string]$element
      Invoke-OnlineFileStatement $inner $loop $Procedures $Found $Where
    }
    return
  }
  if ($Statement -match '^if (\w+) then (.+)$') {
    $condition, $inner = $Matches[1], $Matches[2]
    if (-not $Variables.ContainsKey($condition) -or $Variables[$condition] -isnot [bool]) { throw "${Where}: condition '$condition' is not a Boolean parameter." }
    if ($Variables[$condition]) { Invoke-OnlineFileStatement $inner $Variables $Procedures $Found $Where }
    return
  }
  if ($Statement -match '^(\w+) := (.+)$') {
    $target, $expression = $Matches[1], $Matches[2]
    $Variables[$target] = Get-PascalStringValue $expression $Variables $Where
    return
  }
  if ($Statement -match '^(\w+)\((.*)\)$') {
    $name, $argumentText = $Matches[1], $Matches[2]
    $arguments = @(Split-PascalTopLevel $argumentText ',')
    if ($name -eq 'AddOnlineFile') {
      # AddOnlineFile(RelPath, PinPath, RelDest): the download target has the name of RelPath
      if ($arguments.Count -ne 3) { throw "${Where}: AddOnlineFile needs 3 arguments: $Statement" }
      $Found.Add([pscustomobject]@{
        RelPath = Get-PascalStringValue $arguments[0] $Variables $Where
        PinPath = Get-PascalStringValue $arguments[1] $Variables $Where
      })
      return
    }
    if ($Procedures.ContainsKey($name)) {
      $procedure = $Procedures[$name]
      if ($arguments.Count -ne $procedure.Parameters.Count) { throw "${Where}: $name needs $($procedure.Parameters.Count) arguments: $Statement" }
      $local = @{}
      for ($i = 0; $i -lt $arguments.Count; $i++) {
        $local[$procedure.Parameters[$i]] = Get-PascalStringValue $arguments[$i] $Variables $Where
      }
      Invoke-OnlineFileProcedure $procedure $local $Procedures $Found
      return
    }
  }
  throw "${Where}: statement '$Statement' is not understood by Get-OnlineFiles (ci\build_helpers.ps1)."
}

function Invoke-OnlineFileProcedure($Procedure, [hashtable]$Variables, [hashtable]$Procedures, $Found) {
  foreach ($statement in $Procedure.Statements) {
    Invoke-OnlineFileStatement $statement $Variables $Procedures $Found "setup_is6.iss, $($Procedure.Name)"
  }
}

# True if the download policy treats $Path as a file that can contain code (IsCodeFileName in
# utils.iss): the extension of its last name without trailing dots and spaces is in
# $CodeExtensions ("|dll|exe|...|"), or the path has a ':' or the extension a '|'
function Test-CodeFileName([string]$Path, [string]$CodeExtensions) {
  $name = ($Path -split '[\\/]')[-1].TrimEnd('.', ' ')
  $dot = $name.LastIndexOf('.')
  $extension = ''
  if ($dot -ge 0) { $extension = $name.Substring($dot + 1).ToLowerInvariant() }
  return ($Path.Contains(':') -or $extension.Contains('|') -or ($extension -ne '' -and $CodeExtensions.Contains("|$extension|")))
}

# The online files a setup of $InstallType (EE or NeoEE) built from the repository $Root can
# register for download, for every game language except English and with every selectable
# component (movie, AoC): one object per server path with RelPath, PinPath (its path in the
# SHA-256 list) and IsCode (needs a pin, else it is never downloaded), sorted by RelPath (ordinal).
function Get-OnlineFiles([string]$Root, [string]$InstallType) {
  if ($InstallType -cnotin @('EE', 'NeoEE')) { throw "InstallType '$InstallType' is not EE or NeoEE." }
  $setupFile = Join-Path $Root 'setup_is6.iss'
  $utilsFile = Join-Path $Root 'utils.iss'
  $setup = [System.IO.File]::ReadAllText($setupFile)
  $utils = [System.IO.File]::ReadAllText($utilsFile)
  $lines = $setup -split '\r?\n'

  # Game languages (component language\<lang>, language tag with '-') and their lobby folders
  $languages = @{}
  foreach ($name in @('GameLangs', 'GameLangLobbyDirs')) {
    $match = [regex]::Match($setup, "(?m)^#dim $name\[GameLangCount\]\s*\{([^}]*)\}")
    if (-not $match.Success) { throw "${setupFile}: '#dim $name[GameLangCount] {...}' not found." }
    $languages[$name] = @([regex]::Matches($match.Groups[1].Value, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
  }
  $count = [regex]::Match($setup, '(?m)^#define GameLangCount (\d+)\s*$')
  if (-not $count.Success -or $languages.GameLangs.Count -ne [int]$count.Groups[1].Value -or $languages.GameLangLobbyDirs.Count -ne $languages.GameLangs.Count) {
    throw "${setupFile}: GameLangs and GameLangLobbyDirs must both have GameLangCount entries."
  }

  $codeMatch = [regex]::Match($utils, "CodeFileExtensions = ((?:'[^']*'\s*\+?\s*)+);")
  if (-not $codeMatch.Success) { throw "${utilsFile}: CodeFileExtensions not found." }
  $codeExtensions = -join @([regex]::Matches($codeMatch.Groups[1].Value, "'([^']*)'") | ForEach-Object { $_.Groups[1].Value })

  $procedures = @{}
  foreach ($name in @('RegisterGameOnlineFiles', 'AddLocalizedGameOnlineFile', 'AddGameOnlineFile')) {
    $procedures[$name] = Get-PascalProcedure $lines $name $InstallType $setupFile
  }

  # RegisterOnlineFiles itself: English registers nothing, then one RegisterGameOnlineFiles call
  # per game with its campaigns and whether the movie can be selected
  $register = Get-PascalProcedure $lines 'RegisterOnlineFiles' $InstallType $setupFile
  if ($register.Text -notmatch "\(LangCode = 'en'\)") { throw "${setupFile}: RegisterOnlineFiles no longer skips English ((LangCode = 'en')); update Get-OnlineFiles." }
  $calls = @()
  $position = 0
  while (($position = $register.Text.IndexOf('RegisterGameOnlineFiles(', $position)) -ge 0) {
    $open = $position + 'RegisterGameOnlineFiles'.Length
    $depth = 0
    $inString = $false
    $close = -1
    for ($i = $open; $i -lt $register.Text.Length; $i++) {
      $c = $register.Text[$i]
      if ($c -eq "'") { $inString = -not $inString }
      elseif (-not $inString -and $c -eq '(') { $depth++ }
      elseif (-not $inString -and $c -eq ')') { $depth--; if ($depth -eq 0) { $close = $i; break } }
    }
    if ($close -lt 0) { throw "${setupFile}: unbalanced call of RegisterGameOnlineFiles in RegisterOnlineFiles." }
    $arguments = @(Split-PascalTopLevel $register.Text.Substring($open + 1, $close - $open - 1) ',')
    if ($arguments.Count -ne 5 -or $arguments[0] -ne 'LangCode' -or $arguments[1] -ne 'LobbyDir' -or
        $arguments[2] -notmatch "^'(\w+)'$" -or $arguments[3] -notmatch '^\[(.*)\]$') {
      throw "${setupFile}: call of RegisterGameOnlineFiles in RegisterOnlineFiles not understood: $($register.Text.Substring($position, $close - $position + 1))"
    }
    $game = $arguments[2].Trim("'")
    $campaigns = @(@(Split-PascalTopLevel $arguments[3].Substring(1, $arguments[3].Length - 2) ',') |
      Where-Object { $_ } | ForEach-Object { Get-PascalStringValue $_ @{} "$setupFile, RegisterOnlineFiles" })
    # A component check (e.g. the movie) can be selected: the file can be registered
    $calls += [pscustomobject]@{ Game = $game; Campaigns = $campaigns; WithMovie = ($arguments[4] -ne 'False') }
    $position = $close
  }
  if ($calls.Count -eq 0) { throw "${setupFile}: RegisterOnlineFiles calls RegisterGameOnlineFiles nowhere." }

  $found = [System.Collections.Generic.List[object]]::new()
  for ($i = 0; $i -lt $languages.GameLangs.Count; $i++) {
    $tag = $languages.GameLangs[$i]
    $underscore = $tag.IndexOf('_')
    if ($underscore -ge 0) { $tag = $tag.Substring(0, $underscore) + '-' + $tag.Substring($underscore + 1) }   # GetLanguageTag
    if ($tag -eq 'en') { continue }
    foreach ($call in $calls) {
      $variables = @{ LangCode = $tag; LobbyDir = $languages.GameLangLobbyDirs[$i]; GameKey = $call.Game;
                      Campaigns = [object[]]$call.Campaigns; WithMovie = [bool]$call.WithMovie }
      Invoke-OnlineFileProcedure $procedures.RegisterGameOnlineFiles $variables $procedures $found
    }
  }

  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  $result = [System.Collections.Generic.List[object]]::new()
  foreach ($file in $found) {
    if ($seen.Add($file.RelPath + '|' + $file.PinPath)) {
      $result.Add([pscustomobject]@{ RelPath = $file.RelPath; PinPath = $file.PinPath; IsCode = (Test-CodeFileName $file.RelPath $codeExtensions) })
    }
  }
  $result.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.RelPath, $b.RelPath) })
  return $result.ToArray()
}

# RelPaths of the files of $Files (Get-OnlineFiles) that a setup downloads without a pin: no entry
# for their PinPath in the SHA-256 list $HashList (sha256sum format, see Write-DownloadHashes;
# a missing list pins nothing) and not a file with code (those are never downloaded without a
# pin). Sorted ordinally, each path once.
function Get-UnpinnedOnlineFiles([object[]]$Files, [string]$HashList) {
  $pins = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  if ($HashList -and (Test-Path -LiteralPath $HashList -PathType Leaf)) {
    foreach ($line in [System.IO.File]::ReadAllLines($HashList)) {
      if ($line -match '^[0-9a-fA-F]{64}  (.+)$') { [void]$pins.Add($Matches[1]) }
    }
  }
  $paths = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
  foreach ($file in $Files) {
    if (-not $file.IsCode -and -not $pins.Contains($file.PinPath)) { [void]$paths.Add($file.RelPath) }
  }
  return [string[]]@($paths)
}
