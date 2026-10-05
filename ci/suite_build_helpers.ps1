# Helpers of suite\build_suite.ps1 (the build of the suite installer, ADR 0013), dot-sourced by it and
# tested by ci\tests\suite_build.tests.ps1. They need neither Inno Setup nor the game data, except
# Invoke-SuiteIscc, which runs the ISCC it is given.
#
# The two-pass build of suite\suite.iss in short: the number and the total size of the slices
# (SuiteName-N.bin) are compiled into the setup and only known after a build. Pass 1 (/DSlicePass1=1)
# measures them, pass 2 compiles with them, pass 3 repeats pass 2: the same count, total and bytes
# prove that the build is stable. The output of pass 1 is named "... PASS1 DO NOT SHIP" and is thrown
# away.

# The largest slice GitHub accepts in a release with a safety margin: a real build never has a bigger
# one (the slice size is a build define, the build script checks every file).
$script:SuiteMaxSliceBytes = 50000000
# The size of a slice of a placeholder build is rounded up to a multiple of this.
$script:SuiteSliceStep = 65536
# The placeholder build uses at least this slice size (small slices: the test setup has many slices).
$script:SuitePlaceholderSliceMin = 262144

# The first line of a sha256sum file ("<64 hex digits><space><space or *><name>"): returns the hash
# in lower case and the name. Throws if the file is missing or not in that format.
function Read-Sha256File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "${Path}: checksum file not found." }
  $line = @(Get-Content -LiteralPath $Path -TotalCount 1)
  if ($line.Count -eq 0) { throw "${Path}: the checksum file is empty." }
  $match = [regex]::Match([string]$line[0], '^([0-9A-Fa-f]{64}) [ *](.+)$')
  if (-not $match.Success) { throw "${Path}: not in sha256sum format (<64 hex digits>  <file name>)." }
  return [pscustomobject]@{ Hash = $match.Groups[1].Value.ToLowerInvariant(); Name = $match.Groups[2].Value.Trim() }
}

# Checks the file $Path against its checksum file "$Path.sha256" (the file name inside must be the
# name of $Path) and returns its hash and size. Throws on any difference: the suite embeds the file
# byte for byte and the setup compares it with these values before it runs it.
function Assert-InputChecksum([string]$Path, [string]$What) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "${What}: file not found: $Path" }
  $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
  $expected = Read-Sha256File "$Path.sha256"
  $name = [System.IO.Path]::GetFileName($Path)
  if ($expected.Name -cne $name) {
    throw "${What}: $Path.sha256 names '$($expected.Name)', not '$name'."
  }
  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -cne $expected.Hash) {
    throw "${What}: SHA-256 of $Path is $actual, but $Path.sha256 says $($expected.Hash)."
  }
  $size = (Get-Item -LiteralPath $Path).Length
  if ($size -le 0) { throw "${What}: $Path is empty." }
  return [pscustomobject]@{ Path = $Path; Name = $name; Hash = $actual; Size = $size }
}

# A digest over a folder: SHA-256 of the sorted lines "<hash>  <relative path>" (/ as separator) of
# its files, without the ones named in $ExcludeExtensions. For BUILD-INFO.txt (the launcher folder
# has many files); returns the digest and the number and total size of the files.
function Get-TreeDigest([string]$Dir, [string[]]$ExcludeExtensions = @('.pdb')) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { throw "Folder not found: $Dir" }
  $Dir = (Resolve-Path -LiteralPath $Dir).ProviderPath.TrimEnd('\', '/')
  $lines = @()
  $total = [long]0
  $files = @(Get-ChildItem -LiteralPath $Dir -Recurse -File | Where-Object { $ExcludeExtensions -notcontains $_.Extension.ToLowerInvariant() })
  foreach ($file in $files) {
    $relative = $file.FullName.Substring($Dir.Length).TrimStart('\', '/').Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $lines += "$hash  $relative"
    $total += $file.Length
  }
  if ($files.Count -eq 0) { throw "Folder without files: $Dir" }
  # ordinal order of the paths (the digest must not depend on the culture of the machine)
  $sorted = [string[]]@($lines | ForEach-Object { $_.Substring(66) + "`t" + $_ })
  [Array]::Sort($sorted, [StringComparer]::Ordinal)
  $text = (($sorted | ForEach-Object { $_.Substring($_.IndexOf("`t") + 1) }) -join "`n") + "`n"
  $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $digest = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() } finally { $sha.Dispose() }
  return [pscustomobject]@{ Digest = $digest; Files = $files.Count; Bytes = $total }
}

# The slice size of a placeholder build: the size of the setup program rounded up to a multiple of
# 64 KiB plus one more step (the size of setup.exe changes by a few bytes from pass to pass), at least
# 262144. DiskSliceSize must be >= the size of setup.exe (ISCC refuses less, ADR 0013 Evidence).
# Throws if that is more than the limit of a slice.
function Get-PlaceholderSliceSize([long]$SetupExeSize) {
  if ($SetupExeSize -le 0) { throw "The size of the setup program ($SetupExeSize) is not valid." }
  $step = [long]$script:SuiteSliceStep
  $size = ([long][Math]::Ceiling($SetupExeSize / $step) + 1) * $step
  if ($size -lt $script:SuitePlaceholderSliceMin) { $size = [long]$script:SuitePlaceholderSliceMin }
  if ($size -gt $script:SuiteMaxSliceBytes) {
    throw "The setup program is $SetupExeSize bytes: a slice would have to be $size bytes, more than the limit of $($script:SuiteMaxSliceBytes)."
  }
  return $size
}

# The files of one build folder: the setup program "<Base>.exe" and the slices "<Base>-N.bin". Throws
# if the program is missing, a file is unknown, a slice is empty or the numbers are not 1 to N
# without a gap. Returns the program, the slices in order, their count and their total size (the
# values of /DSliceCount and /DSliceTotal).
function Get-SuiteSliceInfo([string]$Dir, [string]$BaseName) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { throw "Build folder not found: $Dir" }
  $files = @(Get-ChildItem -LiteralPath $Dir -File)
  $exe = @($files | Where-Object { $_.Name -ceq "$BaseName.exe" })
  if ($exe.Count -ne 1) { throw "${Dir}: '$BaseName.exe' was not built." }
  $pattern = '^' + [regex]::Escape($BaseName) + '-(\d+)\.bin\z'
  $slices = @()
  $unknown = @()
  foreach ($file in $files) {
    if ($file.Name -ceq "$BaseName.exe") { continue }
    $match = [regex]::Match($file.Name, $pattern)
    if ($match.Success) {
      $slices += [pscustomobject]@{ Number = [int]$match.Groups[1].Value; File = $file }
    } else {
      $unknown += $file.Name
    }
  }
  if ($unknown.Count -gt 0) { throw "${Dir}: unexpected file(s): $($unknown -join ', ')" }
  $slices = @($slices | Sort-Object Number)
  for ($i = 0; $i -lt $slices.Count; $i++) {
    if ($slices[$i].Number -ne $i + 1) { throw "${Dir}: the slices are not numbered 1 to $($slices.Count) without a gap (found $($slices[$i].File.Name))." }
    if ($slices[$i].File.Length -le 0) { throw "${Dir}: $($slices[$i].File.Name) is empty." }
  }
  $total = [long]0
  foreach ($slice in $slices) { $total += $slice.File.Length }
  return [pscustomobject]@{
    Exe = $exe[0]
    Slices = @($slices | ForEach-Object { $_.File })
    Count = $slices.Count
    Total = $total
  }
}

# Every file of the build (program and slices) must be at most $Max bytes (GitHub's limit for a
# release file; for a real build $Max is 50,000,000). Returns the problems as text, none if fine.
function Test-SuiteSliceLimit($Info, [long]$Max) {
  $problems = @()
  foreach ($file in (@($Info.Exe) + @($Info.Slices))) {
    if ($file.Length -gt $Max) { $problems += "$($file.Name) is $($file.Length) bytes, more than the limit of $Max bytes." }
  }
  return $problems
}

# Two builds of the same defines must be identical: the same count and total of slices, and every
# file (program and slices) with the same bytes. Returns the differences as text, none if identical.
function Compare-SuiteBuilds($A, $B) {
  $problems = @()
  if ($A.Count -ne $B.Count) { $problems += "slice count $($A.Count) against $($B.Count)" }
  if ($A.Total -ne $B.Total) { $problems += "slice total $($A.Total) against $($B.Total)" }
  $filesA = @($A.Exe) + @($A.Slices)
  $filesB = @($B.Exe) + @($B.Slices)
  if ($filesA.Count -eq $filesB.Count) {
    for ($i = 0; $i -lt $filesA.Count; $i++) {
      $hashA = (Get-FileHash -LiteralPath $filesA[$i].FullName -Algorithm SHA256).Hash
      $hashB = (Get-FileHash -LiteralPath $filesB[$i].FullName -Algorithm SHA256).Hash
      if ($hashA -cne $hashB) { $problems += "$($filesA[$i].Name) differs in its bytes" }
    }
  }
  return $problems
}

# SHA256SUMS.txt of a build folder: program first, then every slice in order, sha256sum format (LF,
# UTF-8 without BOM, "<hash>  <name>"), so that "sha256sum -c SHA256SUMS.txt" checks the package.
# Returns the lines.
function Write-SuiteSums($Info, [string]$Destination) {
  $lines = @()
  foreach ($file in (@($Info.Exe) + @($Info.Slices))) {
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $lines += "$hash  $($file.Name)"
  }
  [System.IO.File]::WriteAllText($Destination, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
  return $lines
}

# Full commit of the Git checkout $Root and whether it has uncommitted changes (tracked files);
# Commit is '' without Git or outside a checkout.
function Get-GitState([string]$Root) {
  $git = Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  $state = [pscustomobject]@{ Commit = ''; Dirty = $false }
  if (-not $git) { return $state }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $head = "$(& $git.Source -C $Root rev-parse HEAD 2>$null)".Trim()
    if ($LASTEXITCODE -eq 0 -and $head -cmatch '^[0-9a-f]{40}\z') {
      $state.Commit = $head
      $changes = @(& $git.Source -C $Root status --porcelain --untracked-files=no 2>$null)
      $state.Dirty = ($LASTEXITCODE -eq 0 -and $changes.Count -gt 0)
    }
  } finally {
    $ErrorActionPreference = $previous
  }
  return $state
}

# A commit given for BUILD-INFO.txt: 7 to 40 lower-case hex digits, '' if none was given.
function Assert-CommitText([string]$Value, [string]$What) {
  if ($Value -and $Value -cnotmatch '^[0-9a-f]{7,40}\z') { throw "${What} must be 7 to 40 lower-case hex digits (a Git commit), not '$Value'." }
  return $Value
}

# --- ISCC (the same lookups as ci\build.ps1) ---------------------------------------------------

function Find-SuiteIscc([string]$Iscc) {
  if ($Iscc) {
    if (-not (Test-Path -LiteralPath $Iscc -PathType Leaf)) { throw "ISCC not found: $Iscc" }
    return (Resolve-Path -LiteralPath $Iscc).ProviderPath
  }
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

# Runs ISCC and returns its exit code; the whole output goes to $LogFile (also if ISCC prints nothing).
function Invoke-SuiteIscc([string]$Iscc, [string[]]$Arguments, [string]$LogFile) {
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

# The version of ISCC, asked of the preprocessor (ISPP "Ver"); 'unknown' if it does not answer.
function Get-SuiteIsccVersion([string]$Iscc, [string]$WorkDir) {
  $probe = Join-Path $WorkDir 'version_probe.iss'
  Set-Content -LiteralPath $probe -Encoding ASCII -Value @(
    '#pragma message "ISCC_VERSION=" + DecodeVer(Ver)', '[Setup]', 'AppName=probe', 'AppVersion=1', 'DefaultDirName={tmp}\probe')
  $log = Join-Path $WorkDir 'version_probe.log'
  [void](Invoke-SuiteIscc $Iscc @('/O-', $probe) $log)
  $match = Select-String -LiteralPath $log -Pattern 'ISCC_VERSION=(\S+)' | Select-Object -First 1
  if ($match) { return $match.Matches[0].Groups[1].Value }
  return 'unknown'
}
