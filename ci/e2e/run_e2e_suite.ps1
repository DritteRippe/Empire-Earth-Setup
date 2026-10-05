<#
.SYNOPSIS
  The end-to-end scenarios S1 to S10 of the suite installer on a GitHub-hosted Windows runner, with placeholder builds.

.DESCRIPTION
  Called by the job suite-e2e of .github/workflows/build.yml after the job compile built the placeholder suite
  (suite/build_suite.ps1 -Placeholders), the suite with a wrong pin (-TestWrongEEPin) and the placeholder product
  setups of ci/build.ps1 -Placeholders. It never downloads anything (the official setups of the real-data test and
  r2.empireearth.eu are not involved) and uses no game data:

    Prepare  the packages against their SHA256SUMS.txt, .NET Framework 4.8, hosts file blocks every server, the CD key
             dummy is seeded in HKCU, HKLM64 and HKLM32 and its snapshot saved, nothing installed
    S1       both products: records, install.ini, manifests, suite record, launcher shortcuts (--product, read through
             WScript.Shell), no product shortcuts, logs
    S2       EE only
    S3       EE installed by its own setup with its own shortcuts: adopted in place, the old shortcuts replaced
    S4       one slice (.bin) removed: exit code 11 before any extraction, no wait for a disk
    S5       wrong pin of the EE setup: exit code 15 before any product setup runs
    S6       game (EE, AoC) or launcher mutex held: exit code 14
    S7       NeoEE removed through its own uninstaller, then the suite uninstaller: skipped cleanly
    S8       suite uninstaller: products, launcher, shortcuts, record and defaults gone, saved games kept
    S9       second run as a repair: roots, components and tasks kept, no neoee_cdkeys, shortcuts restored
    S10      Zone.Identifier on every file of the package does not change the chain
    All      Prepare, then S1 to S10 (a failed Prepare stops the run)
    Report   the job summary from the results

  Every result is a line of $env:E2E_REPORT\results.jsonl; the setup logs and the logs of the product setups go to
  $env:E2E_REPORT\logs. A scenario never stops the run: its errors are results, the next one starts from a clean
  machine (leftovers are uninstalled first). Every check is a PASS or FAIL line on the console and in the job summary
  (Report). Hard rules (README.md, "End-to-end test of the suite installer"): every run is silent (/VERYSILENT
  /SUPPRESSMSGBOXES /LOG), English, with an exact task list for the product setups, never the tasks neoee_cdkeys,
  certinclude, directplay or dxwebsetup, every process has a time limit, every host is blocked, no real CD key (only
  the dummy under Software\Sierra\CDKeys, which must survive everything), the launcher is never started.
  Windows PowerShell 5.1 compatible, ASCII only.

.PARAMETER Scenario
  Prepare, S1 to S10, All or Report.

.PARAMETER BudgetMinutes
  The time of the whole run, below the timeout-minutes of the workflow step (0: no budget, only the limits of the
  programs). Ten minutes of it are kept for the uninstallations at the end of a scenario.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('All', 'Prepare', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'Report')][string]$Scenario = 'All',
  [ValidateRange(0, 360)][int]$BudgetMinutes = 0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'e2e_helpers.ps1')
. (Join-Path $PSScriptRoot 'e2e_windows.ps1')
. (Join-Path $PSScriptRoot 'e2e_checks.ps1')
. (Join-Path $PSScriptRoot 'e2e_scenarios.ps1')
. (Join-Path $PSScriptRoot 'e2e_suite_helpers.ps1')
. (Join-Path $PSScriptRoot 'e2e_suite_scenarios.ps1')

foreach ($name in @('E2E_SUITE', 'E2E_PRODUCTS', 'E2E_WRONGPIN', 'E2E_REPORT', 'E2E_WORK')) {
  if (-not [Environment]::GetEnvironmentVariable($name)) { throw "$name is not set (see the job suite-e2e of .github/workflows/build.yml)" }
}
New-Item -ItemType Directory -Force -Path (Join-Path $env:E2E_REPORT 'logs'), $env:E2E_WORK | Out-Null
$ResultFile = Join-Path $env:E2E_REPORT 'results.jsonl'
Initialize-E2EResults $ResultFile
# The placeholder products have the dummy AppIds of ci/build.ps1: every function that names a product uses them
Set-E2EAppIdOverride $E2ESuiteConst.ProductAppIds

# The job summary: one PASS or FAIL line per scenario, the failed checks, the warnings
if ($Scenario -eq 'Report') {
  $lines = @()
  if (Test-Path -LiteralPath $ResultFile) { $lines = @(Get-Content -LiteralPath $ResultFile) }
  $context = "Setup commit: $env:GITHUB_SHA, runner: $env:ImageOS $env:ImageVersion"
  $summary = ConvertTo-E2ESuiteSummary -JsonLines $lines -Scenarios $E2ESuiteConst.Scenarios -Titles $E2ESuiteTitles -Context $context
  foreach ($line in $summary.Lines) { Write-Host $line }
  [System.IO.File]::WriteAllText((Join-Path $env:E2E_REPORT 'report.md'), $summary.Markdown, (New-Object System.Text.UTF8Encoding($false)))
  if ($env:GITHUB_STEP_SUMMARY) { [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, $summary.Markdown, (New-Object System.Text.UTF8Encoding($false))) }
  $prepare = @($lines | Where-Object { $_.Contains('"scenario":"Prepare"') -and $_.Contains('"status":"FAIL"') })
  if ($prepare.Count -gt 0) { Write-Host 'FAIL Prepare (see the log above)'; exit 1 }
  if ($summary.Failed) { exit 1 }
  exit 0
}

# Ten minutes of the budget are kept for the uninstallation at the end of a scenario
Start-E2EPhaseBudget $BudgetMinutes 10

$ids = @($Scenario)
if ($Scenario -eq 'All') { $ids = @('Prepare') + $E2ESuiteConst.Scenarios }
$exitCode = 0
foreach ($id in $ids) {
  try {
    Invoke-E2ESuiteScenario $id
  } catch {
    Add-E2EResult $id 'aborted' 'FAIL' @("unexpected error: $($_.Exception.Message)", "at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)")
  }
  Add-E2EResult $id 'DONE' 'INFO' @("scenario $id finished")
  $failed = @(Get-Content -LiteralPath $ResultFile | Where-Object { $_.Contains('"scenario":"' + $id + '"') -and $_.Contains('"status":"FAIL"') })
  if ($failed.Count -gt 0) { $exitCode = 1 }
  # a machine that is not safe for the setups (no hosts block, no CD key baseline) stops the run
  if ($id -eq 'Prepare' -and $failed.Count -gt 0) {
    Write-Host 'Prepare failed: no setup runs.'
    break
  }
}
exit $exitCode
