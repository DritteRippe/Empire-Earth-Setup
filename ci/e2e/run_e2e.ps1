<#
.SYNOPSIS
  One phase of the real-data end-to-end test of the v2 setups on a GitHub-hosted Windows runner.

.DESCRIPTION
  Called by .github/workflows/e2e-realdata.yml, one step per phase, after the job has built the
  real-data installers (EE and NeoEE, Regular, real AppIds, unsigned) into $env:E2E_BUILD:

    Prepare  hosts file blocks every server of the setups and the launcher (api.empireearth.eu with
             the statistics endpoints first), the CD key dummy is seeded, nothing of the products
             is installed, no root certificate of the official setup is trusted
    A        EE for all users, German, full type: the only run with downloads (from the mirror,
             which is unblocked only while this setup runs), every check, the launcher checks
             (installing account and a fresh account), uninstallation
    B        NeoEE for the current user, English, without the CD key task; a repair with a junction
             in Data (no link check in the user mode); uninstallation
    E        EE for all users into a custom folder next to traces of a foreign installation
    D        on E: the link guard (junction, hard link: exit code 7, nothing changed), then an
             update without the DirectX wrapper; uninstallation
    C        the official setup 1.7.2, v2 over it, 1.7.2 again, v2 again, damage seen by the
             launcher, repair, uninstallation

  Every result is a line of $env:E2E_REPORT\results.jsonl (ci/e2e/report.py turns it into the job
  summary); setup logs go to $env:E2E_REPORT\logs. A scenario never stops the job: its errors are
  results, and the next scenario starts from a clean machine (leftovers are uninstalled first).
  The phase Prepare exits with 1 if the machine is not safe for the setups, so no setup runs then.

  Hard rules (README.md, "End-to-end test on Windows"): never the telemetry component, never the
  tasks neoee_cdkeys, certinclude, directplay or dxwebsetup, never a real CD key (only the dummy
  under Software\Sierra\CDKeys, which must survive everything), at most one run with a language
  other than English. Game data never leaves the runner: nothing here prints, copies or uploads it.
  Windows PowerShell 5.1 compatible, ASCII only.

.PARAMETER Phase
  Prepare, A, B, E, D or C.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('Prepare', 'A', 'B', 'E', 'D', 'C')][string]$Phase
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'e2e_helpers.ps1')
. (Join-Path $PSScriptRoot 'e2e_windows.ps1')
. (Join-Path $PSScriptRoot 'e2e_checks.ps1')
. (Join-Path $PSScriptRoot 'e2e_scenarios.ps1')

$Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($name in @('E2E_BUILD', 'E2E_OFFICIAL', 'E2E_REPORT', 'E2E_WORK', 'E2E_PIN_COUNT', 'E2E_SETUP_BUILD', 'LAUNCHER_RM')) {
  if (-not [Environment]::GetEnvironmentVariable($name)) { throw "$name is not set (see .github/workflows/e2e-realdata.yml)" }
}
New-Item -ItemType Directory -Force -Path (Join-Path $env:E2E_REPORT 'logs'), $env:E2E_WORK | Out-Null
Initialize-E2EResults (Join-Path $env:E2E_REPORT 'results.jsonl')
$AssetMap = Import-E2EAssetMap (Join-Path $PSScriptRoot 'assets-map.tsv')

# --- Main ----------------------------------------------------------------------------------------------

$exitCode = 0
try {
  switch ($Phase) {
    'Prepare' { Invoke-E2EPrepare }
    'A' { Invoke-E2EScenarioA }
    'B' { Invoke-E2EScenarioB }
    'E' { Invoke-E2EScenarioE }
    'D' { Invoke-E2EScenarioD }
    'C' { Invoke-E2EScenarioC }
  }
} catch {
  Add-E2EResult $Phase 'aborted' 'FAIL' @("unexpected error: $($_.Exception.Message)", "at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)")
  if ($Phase -eq 'Prepare') { $exitCode = 1 }
} finally {
  Add-E2EResult $Phase 'DONE' 'INFO' @("phase $Phase finished")
}
# A failed check of this phase turns its workflow step red (the next scenarios still run; only a
# failed Prepare stops them, see the workflow)
$failed = @(Get-Content -LiteralPath (Join-Path $env:E2E_REPORT 'results.jsonl') |
  Where-Object { $_.Contains('"scenario":"' + $Phase + '"') -and $_.Contains('"status":"FAIL"') })
if ($failed.Count -gt 0) { $exitCode = 1 }
exit $exitCode
