# Windows glue of the real-data end-to-end test: reads and writes the registry, the hosts file and
# files, runs processes and reads firewall rules, shortcuts and ACLs. Each function is thin; the
# rules are in e2e_helpers.ps1 (tested with fake data). Only for a GitHub-hosted Windows runner that
# is thrown away after the job (.github/workflows/e2e-realdata.yml). Windows PowerShell 5.1
# compatible, ASCII only. Never touches Software\Sierra\CDKeys except the dummy value of the test.
# Dot-source it after e2e_helpers.ps1.

# --- Registry ------------------------------------------------------------------------------------

# Hive names: HKLM64 (64-bit view), HKLM32 (32-bit view, WOW6432Node), HKCU
function Get-E2ERegBase([string]$Hive) {
  switch ($Hive) {
    'HKLM64' { return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64) }
    'HKLM32' { return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32) }
    'HKCU'   { return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Registry64) }
  }
  throw "Unknown hive $Hive"
}

function Assert-E2ENotCdKeys([string]$SubKey) {
  if ($SubKey -match '(^|\\)Sierra(\\|$)') { throw "Refusing to change ${SubKey}: Software\Sierra is never changed (CD keys)" }
}

function Test-E2ERegKey([string]$Hive, [string]$SubKey) {
  $base = Get-E2ERegBase $Hive
  try {
    $key = $base.OpenSubKey($SubKey, $false)
    if ($key) { $key.Dispose(); return $true }
    return $false
  } finally { $base.Dispose() }
}

# name -> @{ Kind; Value } of the key, $null if it does not exist (environment names not expanded)
function Get-E2ERegValues([string]$Hive, [string]$SubKey) {
  $base = Get-E2ERegBase $Hive
  try {
    $key = $base.OpenSubKey($SubKey, $false)
    if (-not $key) { return $null }
    try {
      $values = @{}
      foreach ($name in $key.GetValueNames()) {
        $values[$name] = @{
          Kind  = $key.GetValueKind($name).ToString()
          Value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
      }
      return $values
    } finally { $key.Dispose() }
  } finally { $base.Dispose() }
}

function Get-E2ERegSubKeyNames([string]$Hive, [string]$SubKey) {
  $base = Get-E2ERegBase $Hive
  try {
    $key = $base.OpenSubKey($SubKey, $false)
    if (-not $key) { return @() }
    try { return @($key.GetSubKeyNames()) } finally { $key.Dispose() }
  } finally { $base.Dispose() }
}

function Set-E2ERegValue([string]$Hive, [string]$SubKey, [string]$Name, $Value, [ValidateSet('String', 'DWord')][string]$Kind) {
  if ($SubKey -notlike "$($E2EConst.CdKeysKey)*") { Assert-E2ENotCdKeys $SubKey }
  $base = Get-E2ERegBase $Hive
  try {
    $key = $base.CreateSubKey($SubKey)
    try { $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]$Kind) } finally { $key.Dispose() }
  } finally { $base.Dispose() }
}

function Remove-E2ERegValue([string]$Hive, [string]$SubKey, [string]$Name) {
  Assert-E2ENotCdKeys $SubKey
  $base = Get-E2ERegBase $Hive
  try {
    $key = $base.OpenSubKey($SubKey, $true)
    if ($key) { try { $key.DeleteValue($Name, $false) } finally { $key.Dispose() } }
  } finally { $base.Dispose() }
}

function Remove-E2ERegTree([string]$Hive, [string]$SubKey) {
  Assert-E2ENotCdKeys $SubKey
  $base = Get-E2ERegBase $Hive
  try { $base.DeleteSubKeyTree($SubKey, $false) } finally { $base.Dispose() }
}

# Sorted lines '<subkey>|<value>|<kind>|<data>' of a key and everything below it, for the
# before/after comparisons of scenario D ($Hive\$SubKey absent: one line 'absent')
function Get-E2ERegTreeLines([string]$Hive, [string]$SubKey) {
  Assert-E2ENotCdKeys $SubKey
  $lines = New-Object System.Collections.Generic.List[string]
  $base = Get-E2ERegBase $Hive
  try {
    $root = $base.OpenSubKey($SubKey, $false)
    if (-not $root) { return @("$Hive\$SubKey|absent") }
    $stack = New-Object System.Collections.Generic.Stack[object]
    $stack.Push(@{ Key = $root; Rel = '' })
    while ($stack.Count -gt 0) {
      $item = $stack.Pop()
      $key = $item.Key
      try {
        $lines.Add("$Hive\$SubKey\$($item.Rel)|<key>")
        foreach ($name in $key.GetValueNames()) {
          $kind = $key.GetValueKind($name).ToString()
          $data = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
          if ($data -is [byte[]]) { $data = [BitConverter]::ToString($data) }
          elseif ($data -is [string[]]) { $data = $data -join '\0' }
          $lines.Add("$Hive\$SubKey\$($item.Rel)|$name|$kind|$data")
        }
        foreach ($child in $key.GetSubKeyNames()) {
          $sub = $key.OpenSubKey($child, $false)
          if ($sub) { $stack.Push(@{ Key = $sub; Rel = ($item.Rel + $child + '\') }) }
        }
      } finally { $key.Dispose() }
    }
  } finally { $base.Dispose() }
  return @($lines | Sort-Object)
}

# --- CD keys (briefing D6, contract 3.8): only the dummy value of the test, never a real key ------

$script:E2ECdKeyHives = @('HKCU', 'HKLM64', 'HKLM32')

# Problems if Software\Sierra\CDKeys exists in any view before the test seeds its dummy: then the
# runner is not the empty machine the test expects (nothing is printed about its content)
function Test-E2ECdKeysAbsent {
  $problems = @()
  foreach ($hive in $script:E2ECdKeyHives) {
    if (Test-E2ERegKey $hive $E2EConst.CdKeysKey) { $problems += "$hive\$($E2EConst.CdKeysKey) exists before the test (not printed, not touched)" }
  }
  return $problems
}

function Initialize-E2ECdKeyDummy {
  foreach ($hive in $script:E2ECdKeyHives) {
    Set-E2ERegValue $hive $E2EConst.CdKeysKey $E2EConst.CdKeyDummyName $E2EConst.CdKeyDummyValue 'String'
  }
}

# Problems if the dummy is not exactly as seeded in every view: one value CI-Dummy (REG_SZ) with the
# dummy text and no subkey. Only "intact or not" is reported, never a value.
function Test-E2ECdKeyDummy {
  $problems = @()
  foreach ($hive in $script:E2ECdKeyHives) {
    $values = Get-E2ERegValues $hive $E2EConst.CdKeysKey
    if ($null -eq $values) { $problems += "$hive CD keys: the key is gone"; continue }
    $ok = ($values.Count -eq 1) -and $values.ContainsKey($E2EConst.CdKeyDummyName) -and
          ($values[$E2EConst.CdKeyDummyName].Kind -eq 'String') -and
          ([string]$values[$E2EConst.CdKeyDummyName].Value -ceq $E2EConst.CdKeyDummyValue)
    if (-not $ok) { $problems += "$hive CD keys: the dummy is not intact (values changed, added or removed)" }
    if (@(Get-E2ERegSubKeyNames $hive $E2EConst.CdKeysKey).Count -gt 0) { $problems += "$hive CD keys: a subkey was added" }
  }
  return $problems
}

# --- Files ---------------------------------------------------------------------------------------

# Every file and folder below Root, without following junctions or symbolic links (a reparse point
# is listed, never entered): @{ Rel; IsDir; Size; Ticks; Attributes; Reparse }
function Get-E2EFileTree([string]$Root) {
  $items = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
  $base = (New-Object System.IO.DirectoryInfo($Root)).FullName.TrimEnd('\')
  $stack = New-Object System.Collections.Generic.Stack[string]
  $stack.Push($base)
  while ($stack.Count -gt 0) {
    $dir = New-Object System.IO.DirectoryInfo($stack.Pop())
    foreach ($entry in $dir.EnumerateFileSystemInfos()) {
      $rel = $entry.FullName.Substring($base.Length + 1)
      $reparse = (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
      $isDir = (($entry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0)
      $size = 0
      if (-not $isDir) { $size = $entry.Length }
      $items.Add(@{ Rel = $rel; IsDir = $isDir; Size = $size; Ticks = $entry.LastWriteTimeUtc.Ticks
                    Attributes = [string]$entry.Attributes; Reparse = $reparse })
      if ($isDir -and -not $reparse) { $stack.Push($entry.FullName) }
    }
  }
  return $items.ToArray()
}

# Sorted lines 'rel|size|ticks|attributes' of the tree, for the before/after comparisons
function Get-E2EFileTreeLines([string]$Root) {
  return @(Get-E2EFileTree $Root | ForEach-Object { '{0}|{1}|{2}|{3}' -f $_.Rel, $_.Size, $_.Ticks, $_.Attributes } | Sort-Object)
}

function Get-E2EFileSha1([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
}

function Get-E2EFileSha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# path (lowercase) -> @{ Path; Size; Sha1 } of the asset map ci/e2e/assets-map.tsv
function Import-E2EAssetMap([string]$Path) {
  $map = @{}
  $header = $null
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    if (-not $line -or $line.StartsWith('#')) { continue }
    $cols = $line.Split("`t")
    if (-not $header) { $header = $cols; continue }
    $map[$cols[1].ToLowerInvariant()] = @{ Path = $cols[1]; Size = $cols[2]; Sha1 = $cols[3] }
  }
  return $map
}

# --- Processes ------------------------------------------------------------------------------------

# Runs a program and returns its exit code; kills it and throws after TimeoutSeconds. With OutFile,
# stdout and stderr go to that file. Environment adds variables for the child only.
function Invoke-E2EProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string]$Arguments = '',
    [int]$TimeoutSeconds = 3600,
    [string]$OutFile,
    [hashtable]$Environment = @{}
  )
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.Arguments = $Arguments
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  foreach ($name in $Environment.Keys) { $psi.EnvironmentVariables[$name] = [string]$Environment[$name] }
  if ($OutFile) {
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
  }
  $process = [System.Diagnostics.Process]::Start($psi)
  $stdout = $null
  $stderr = $null
  if ($OutFile) {
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
  }
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill() } catch { }
    throw "$([System.IO.Path]::GetFileName($FilePath)) did not finish within $TimeoutSeconds s (killed)"
  }
  $process.WaitForExit()
  if ($OutFile) {
    $text = $stdout.Result
    if ($stderr.Result) { $text += $stderr.Result }
    [System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding($false)))
  }
  return $process.ExitCode
}

function Test-E2EMutex([string]$Name) {
  foreach ($candidate in @($Name, "Global\$Name")) {
    $mutex = $null
    if ([System.Threading.Mutex]::TryOpenExisting($candidate, [ref]$mutex)) { $mutex.Dispose(); return $true }
  }
  return $false
}

# Waits until the setup mutex of the product is gone and no uninstaller copy (_iu*.tmp) runs
function Wait-E2ESetupFinished([hashtable]$Product, [int]$TimeoutSeconds = 180) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $busy = (Test-E2EMutex $Product.SetupMutex) -or @(Get-Process | Where-Object { $_.ProcessName -like '_iu*' }).Count -gt 0
    if (-not $busy) { return $true }
    Start-Sleep -Seconds 2
  }
  return $false
}

# --- Small wrappers of the operating system (one place each, simulated in the local smoke run) -----

function Get-E2EKnownFolder([string]$Name) { return [Environment]::GetFolderPath($Name) }

function Get-E2ERunnerInfo {
  $os = Get-CimInstance Win32_OperatingSystem
  return "$($os.Caption) $($os.Version), image $env:ImageOS $env:ImageVersion, PowerShell $($PSVersionTable.PSVersion), time zone $((Get-TimeZone).Id)"
}

function Get-E2EServiceStatus([string]$Name) { return [string](Get-Service -Name $Name).Status }

function Get-E2EWinHttpProxy { return ((& netsh.exe winhttp show proxy) -join ' ') }

function New-E2EJunction([string]$Path, [string]$Target) { New-Item -ItemType Junction -Path $Path -Value $Target | Out-Null }

function New-E2EHardLink([string]$Path, [string]$Target) { New-Item -ItemType HardLink -Path $Path -Value $Target | Out-Null }

# Removes a junction (rmdir removes the link, never the files of its target)
function Remove-E2ELink([string]$Path) {
  if (Test-Path -LiteralPath $Path) { & cmd.exe /c rmdir "$Path" | Out-Null }
}

function Get-E2ESddl([string]$Path) { return (Get-Acl -LiteralPath $Path).Sddl }

# --- Setup runs -----------------------------------------------------------------------------------

# Runs a setup after the safety checks: the argument rules (Test-E2ESetupArguments), the hosts
# block (every blocked host must resolve to nothing, except the mirror while scenario A
# downloads), and at most one run with a language other than English per job (the downloads of
# the localized files, once per run). Throws if a check fails; returns the exit code.
function Invoke-E2ESetup {
  param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][ValidateSet('v2', 'official')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$Product,
    [bool]$FirstInstall = $true,
    [string[]]$Unblocked = @(),
    [int]$TimeoutMinutes = 45
  )
  $problems = @(Test-E2ESetupArguments $Arguments $Kind $Product $FirstInstall)
  $blocked = @($E2EConst.BlockedHosts | Where-Object { $Unblocked -notcontains $_ })
  $problems += @(Test-E2EHostsBlocked $blocked)
  $language = Get-E2ESwitchValue $Arguments 'LANG'
  $marker = Join-Path $env:E2E_WORK 'non-english-run.txt'
  if ($language -and $language -ne 'en') {
    if (Test-Path -LiteralPath $marker) { $problems += "a second setup run with /LANG=$language (only one non-English run per job)" }
  }
  if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) { $problems += "setup not found: $Exe" }
  if ($problems.Count -gt 0) { throw ('Setup not started: ' + ($problems -join '; ')) }
  if ($language -and $language -ne 'en') { Set-Content -LiteralPath $marker -Value ([System.IO.Path]::GetFileName($Exe)) -Encoding ASCII }
  Write-Host "Running $([System.IO.Path]::GetFileName($Exe)) $($Arguments -join ' ')"
  return (Invoke-E2EProcess -FilePath $Exe -Arguments ($Arguments -join ' ') -TimeoutSeconds ($TimeoutMinutes * 60))
}

# Path of the uninstall key of the product (Inno Setup: {<AppId>}_is1)
function Get-E2EUninstallKeyPath([hashtable]$Product) {
  return "$($E2EConst.UninstallKey)\{$($Product.AppId)}_is1"
}

# Runs <Root>\unins000.exe silently and waits until the uninstaller (also its copy in %TEMP%) is
# done and the uninstall key is gone. Returns @{ ExitCode; Problems }.
function Invoke-E2EUninstall([hashtable]$Product, [string]$Root, [string]$Hive, [string]$LogFile, [int]$TimeoutSeconds = 1800) {
  $problems = @()
  $uninstaller = Join-Path $Root 'unins000.exe'
  if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) { return @{ ExitCode = $null; Problems = @("$uninstaller does not exist") } }
  $code = Invoke-E2EProcess -FilePath $uninstaller -Arguments "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$LogFile`"" -TimeoutSeconds $TimeoutSeconds
  $deadline = (Get-Date).AddSeconds(180)
  $keyPath = Get-E2EUninstallKeyPath $Product
  while ((Get-Date) -lt $deadline) {
    $running = @(Get-Process | Where-Object { $_.ProcessName -like '_iu*' }).Count -gt 0
    if (-not $running -and -not (Test-Path -LiteralPath $uninstaller) -and -not (Test-E2ERegKey $Hive $keyPath)) { break }
    Start-Sleep -Seconds 2
  }
  if (Test-Path -LiteralPath $uninstaller) { $problems += "$uninstaller still exists 180 s after the uninstallation" }
  if (Test-E2ERegKey $Hive $keyPath) { $problems += "$Hive\$keyPath still exists 180 s after the uninstallation" }
  if (-not (Wait-E2ESetupFinished $Product 60)) { $problems += 'the uninstaller is still running' }
  return @{ ExitCode = $code; Problems = $problems }
}

# --- Hosts file and network -------------------------------------------------------------------------

function Get-E2EHostsPath { return (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts') }

# Writes the block of this test into the hosts file (no names: removes it) and flushes the DNS cache
function Set-E2EHostsBlock([string[]]$Names) {
  $path = Get-E2EHostsPath
  $current = ''
  if (Test-Path -LiteralPath $path) { $current = [System.IO.File]::ReadAllText($path) }
  [System.IO.File]::WriteAllText($path, (Get-E2EHostsText $current $Names), [System.Text.Encoding]::ASCII)
  & ipconfig.exe /flushdns | Out-Null
  Start-Sleep -Seconds 1
}

# Problems for every name that resolves to anything but 0.0.0.0 or :: (a name that does not resolve
# at all is blocked too)
function Test-E2EHostsBlocked([string[]]$Names) {
  $problems = @()
  foreach ($name in $Names) {
    try {
      $addresses = @([System.Net.Dns]::GetHostAddresses($name))
    } catch {
      continue
    }
    $open = @($addresses | Where-Object { $_.ToString() -ne '0.0.0.0' -and $_.ToString() -ne '::' })
    if ($open.Count -gt 0) { $problems += "$name resolves to $($open[0]) (not blocked)" }
  }
  return $problems
}

# @{ Ok; Status; Detail } of a HEAD request (TLS 1.2 also for Windows PowerShell 5.1)
function Invoke-E2EHead([string]$Url, [int]$TimeoutSeconds = 30) {
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
  try {
    $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSeconds -MaximumRedirection 5
    return @{ Ok = $true; Status = [int]$response.StatusCode; Detail = "HTTP $([int]$response.StatusCode)" }
  } catch {
    $response = $null
    if ($_.Exception.PSObject.Properties['Response']) { $response = $_.Exception.Response }
    if ($response) { return @{ Ok = $true; Status = [int]$response.StatusCode; Detail = "HTTP $([int]$response.StatusCode)" } }
    return @{ Ok = $false; Status = 0; Detail = $_.Exception.Message }
  }
}

# --- Firewall, shortcuts, permissions, certificates --------------------------------------------

# The firewall rules whose program is Program: @{ Name; Direction; Action; Enabled; Profile; Protocol; LocalPort }
function Get-E2EFirewallRules([string]$Program) {
  $rules = @()
  $filters = @(Get-NetFirewallApplicationFilter -Program $Program -ErrorAction SilentlyContinue)
  foreach ($filter in $filters) {
    foreach ($rule in @($filter | Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
      $port = $rule | Get-NetFirewallPortFilter
      $rules += @{
        Name = [string]$rule.DisplayName; Direction = [string]$rule.Direction; Action = [string]$rule.Action
        Enabled = [string]$rule.Enabled; Profile = [string]$rule.Profile
        Protocol = [string]$port.Protocol; LocalPort = (@($port.LocalPort) -join ',')
      }
    }
  }
  return $rules
}

# @{ Target; Arguments } of a .lnk file, $null if it does not exist
function Get-E2EShortcut([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $shell = New-Object -ComObject WScript.Shell
  $link = $shell.CreateShortcut($Path)
  return @{ Target = $link.TargetPath; Arguments = $link.Arguments }
}

# The access rules of a file or folder: @{ Sid; Rights; Allow; Inherited }
function Get-E2EAccessRules([string]$Path) {
  $acl = Get-Acl -LiteralPath $Path
  $rules = @()
  foreach ($rule in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
    $rules += @{ Sid = $rule.IdentityReference.Value; Rights = [int64]$rule.FileSystemRights
                 Allow = ($rule.AccessControlType -eq 'Allow'); Inherited = $rule.IsInherited }
  }
  return $rules
}

# Certificate stores where the root certificate of the official setup holds the thumbprint
function Find-E2ECertificate([string]$Thumbprint) {
  $found = @()
  foreach ($store in @('Cert:\LocalMachine\Root', 'Cert:\LocalMachine\TrustedPublisher', 'Cert:\CurrentUser\Root', 'Cert:\CurrentUser\TrustedPublisher')) {
    if (Test-Path -LiteralPath (Join-Path $store $Thumbprint)) { $found += $store }
  }
  return $found
}

# --- Launcher checks (Empire-Earth-Launcher.RealMachineTests) ----------------------------------------

# Runs the RealMachine checks of the launcher fork with one expectation. The expectation and the
# NUnit result (XML, console text; both free of hashes) go to the report folder; the work folder
# (core.log with hashes, saved values, .reg backups) stays below E2E_WORK and is never uploaded.
# Returns @{ ExitCode; Failures }.
function Invoke-E2ELauncher([string]$Scenario, [string]$Step, $Expectation) {
  $exe = $env:LAUNCHER_RM
  if (-not $exe -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'LAUNCHER_RM is not set or does not exist' }
  $work = Join-Path $env:E2E_WORK "launcher\$Scenario-$Step"
  $reportDir = Join-Path $env:E2E_REPORT 'launcher'
  New-Item -ItemType Directory -Force -Path $work, $reportDir | Out-Null
  $expect = Join-Path $work 'expect.json'
  $json = ConvertTo-E2EJson $Expectation
  [System.IO.File]::WriteAllText($expect, $json, (New-Object System.Text.UTF8Encoding($false)))
  [System.IO.File]::WriteAllText((Join-Path $reportDir "$Scenario-$Step.expect.json"), $json, (New-Object System.Text.UTF8Encoding($false)))
  $result = Join-Path $reportDir "$Scenario-$Step.xml"
  $console = Join-Path $reportDir "$Scenario-$Step.txt"
  $arguments = "--where `"cat == RealMachine`" `"--params=expect=$expect`" `"--params=work=$work`" `"--result=$result`" --labels=All"
  $code = Invoke-E2EProcess -FilePath $exe -Arguments $arguments -TimeoutSeconds 1800 -OutFile $console `
    -Environment @{ EE_LAUNCHER_REAL_MACHINE_TESTS = '1' }
  $failures = @()
  if ($code -ne 0 -and (Test-Path -LiteralPath $console)) {
    $failures = @(Get-Content -LiteralPath $console | Where-Object { $_ -match '^\s*\d+\) ' } | Select-Object -First 8)
  }
  return @{ ExitCode = $code; Failures = $failures }
}

# @{ code; data; mutable } manifest paths of the EE folder (pick-targets of the launcher harness)
function Get-E2ETamperTargets([string]$Root, [string]$Product) {
  $out = Join-Path $env:E2E_WORK 'pick-targets.json'
  $code = Invoke-E2EProcess -FilePath $env:LAUNCHER_RM -Arguments "pick-targets --root `"$Root`" --product $Product" -TimeoutSeconds 300 -OutFile $out
  if ($code -ne 0) { throw "pick-targets failed with exit code $code" }
  $parsed = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
  return @{ code = [string]$parsed.code; data = [string]$parsed.data; mutable = [string]$parsed.mutable }
}
