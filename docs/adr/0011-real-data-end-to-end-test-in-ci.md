# 0011. Real-data end-to-end test on a throwaway GitHub-hosted Windows runner

- Status: Accepted, implemented (see [Implementation](#implementation); verified locally, the first run
  on GitHub answers the points listed there)
- Date: 2026-10-03
- Requirements: briefing D6 (game data never committed, pushed or uploaded; never run a setup on a
  development machine; tests never use the network), D7; [ADR 0004](0004-install-record-and-integrity-manifest.md),
  [ADR 0009](0009-no-installation-through-links.md); docs/TEST-PLAN.de.md

## Context

Until now nothing ran the setups except a tester on Windows: CI only compiled placeholder builds, the
local probes ran small probe setups under Wine, and the real-data equivalence was a comparison of
dumps. The behaviour of the glue code (environment checks, link guard, install state, downloads)
and of the installed result against the contract was only covered by the manual test plan, and the
maintainer does not want to test manually on a laptop.

A real-data build needs the game files, which may never be committed, uploaded or shared. They are
inside the two official setups 1.7.2, which are public downloads. The local reconstruction proved
that every file the v2 build reads is a file of one of them (by SHA-1 and size) or a bitmap of their
setup headers. The official setup 1.7.2 contacts the file servers on every run and sends statistics
without consent, the NeoEE setup registers CD keys at `neoee.net`, and both offer to add a root
certificate.

## Decision

1. A GitHub Actions workflow (`.github/workflows/e2e-realdata.yml`) builds the real-data setups and
   installs, checks and uninstalls them on a GitHub-hosted Windows runner, which GitHub discards after
   the job. It runs by hand, and for a pull request only if the pull request comes from a branch of
   the repository itself, carries the label `e2e` and changes the setup sources or the end-to-end
   tools; a newer run for the same branch cancels the older one, a run that does not qualify cancels
   nothing. Pull requests from forks never run it: a pull request runs the workflow file and the
   scripts of its own branch, next to the game data. Because such a pull request could remove that
   condition, every repository that holds the workflow must require approval of workflow runs for
   all external contributors (repository setting, README).
2. The game files come only from the official setups at run time: extracted with innoextract 1.10-dev
   and placed with a committed, data-free map (path, size, SHA-1, time, product, origin per file;
   `ci/e2e/assets-map.tsv`). Every placed file is checked; a source the scripts read that the map does
   not name fails the job (`ci/e2e/readset.py`).
3. Game data never leaves the runner: it is not committed, cached, uploaded or printed. Only the
   unchanged official setups and the innoextract binary are cached. The only upload is a report
   folder that a guard (`ci/e2e/guard_upload.py`) accepts only as a separate folder of small text
   files, none with the SHA-1 of a file of the map.
4. Before any setup runs, the hosts file blocks every server of the setups and the launcher
   (`api.empireearth.eu` with every statistics endpoint first) and the job proves the block. The
   telemetry component, the CD key task, the certificate task, DirectPlay and the DirectX runtime are
   never selected (the scripts refuse such arguments), and a dummy CD key value under
   `Software\Sierra\CDKeys` must survive every step. Only one scenario uses another language than
   English, so the downloads of the localized files from the mirror run once per job.
5. The checks are those of the contract and of the test plan that need no game start and no human:
   install record, `install.ini`, uninstall key, manifest (hashed again), game settings, GPU
   preference, marker, compatibility values, firewall rules, shortcuts, permissions, the setup log,
   the downloads, the link guard, foreign installations, the update over 1.7.2 and the uninstallation;
   and the launcher core of the launcher fork against each installation.
6. Agents and developers still never run a setup or the launcher outside such a runner.
7. The scripts, not GitHub, stop what hangs: every program has a time limit well below the limit of
   its workflow step (setup 25 minutes, uninstaller and launcher checks 10), and a phase never runs
   past its budget (`run_e2e.ps1 -BudgetMinutes`, 5 minutes below the step limit, 15 of them kept for
   the uninstallation at its end). A program that runs into a limit is stopped with its child
   processes and recorded as `FAIL`, and the scenario still uninstalls. Each scenario starts on a
   clean machine: it reports what earlier ones left (keys, the seeds of E, files and folders of the
   test, compatibility, GPU and firewall entries of programs below them, shortcuts) as `WARN` and
   removes it, so a failure is counted once, in the scenario that caused it.
8. The launcher checks run from a full commit of the launcher fork fixed in the workflow
   (`LAUNCHER_COMMIT`) and moved on purpose by a commit of this repository; a commit given by hand
   must be a full commit too, and the job refuses any commit that is not on `LAUNCHER_BRANCH`. No
   branch, tag or pull request ref is checked out: that code runs as administrator next to the game
   data, so it must be reviewed code, and a run must be reproducible.

## Evidence

- Local reconstruction (`scratchpad/realdata`, not in the repository): 1796 of the 1799 files the v2
  build reads are file locations of the official setups, 3 are wizard bitmaps of their headers; 16
  empty folders come from `createallsubdirs`.
- A fresh extraction with innoextract 1.10-dev of the official setups (SHA-256 checked) and
  `ci/e2e/place_assets.py` rebuild these 1799 files byte-identical to the reconstruction, with the
  same times; the preprocessed scripts of the current `v2` read exactly the files of the map; the
  pin list `ci/build.ps1` writes from them equals the reconstruction's. ISCC 6.2.2 built both setups
  from such a tree (exploration of this work package).

## Consequences

- The behaviour on Windows is tested on demand, by hand and on the pull requests that carry the
  label, without a tester and without any game data in the repository, the cache or the artifacts.
- Expected frequency: one run per dispatch and per push to a labelled pull request of the
  repository (the label is removed for pushes that do not need the test; GitHub matches the path
  filter against the whole pull request, so without the label every push to a long pull request
  would start a run). Each run that reaches scenario A downloads 17 localized files from the
  mirror, 10 of them unpinned and large (the voices `data.ssa` of EE and AoC, 8 campaigns).
- The job depends on `r2.empireearth.eu` once per cache scope and after 7 days without a run, on
  the mirror once per run (a failing mirror is reported as `SERVER`, not as a failure of the
  setup) and on the image `windows-latest`. Caches belong to the branch or pull request that made
  them; a pull request also reads those of its base and of the default branch. Before the merge the
  first run of every pull request downloads the official setups (about 1.25 GB); after the merge one
  run by hand on the default branch fills the caches for all pull requests.
- A change of the launcher checks reaches this job only with a new `LAUNCHER_COMMIT` here, and the
  launcher branch must never be rewritten.
- A change of the assets of `[Files]` needs a new map, which only a maintainer with the official
  setups can generate (`ci/e2e/gen_map.py`, README).
- What needs a human, a GPU, Windows 7 or a game start stays in the manual test plan.

## Alternatives considered

- Placeholder builds only: they test that the script compiles, not what it installs.
- Uploading the built installers as artifacts to install them in a second job, or caching the
  extracted files: forbidden (game data would leave the runner).
- A self-hosted runner: not discarded after the job, and the data would stay on a machine.
- Running the setups locally under Wine: forbidden by the briefing (live servers, statistics), and
  Wine is not Windows.
- Every pull request that touches the paths, without a label: rejected after the first review. The
  path filter compares the whole pull request with its base, so every push to a long pull request
  (also a documentation commit) would start a two-hour run with downloads from the mirror; a pull
  request from a fork would also run without a review whenever its author had a contribution merged
  before (GitHub's default).
- The launcher checks from a branch of the launcher fork (the first version, input `launcher_ref`):
  rejected after the first review. Code of another repository would run as administrator next to
  the game data without a review here, any ref (also a foreign pull request) could be chosen by hand,
  and no run was reproducible.
- Leaving hangs to the step limits of GitHub: rejected after the first review. GitHub stops the
  whole step, so the result line, the uninstallation and the cleanup of that scenario are missing,
  and child processes may survive into the next scenario.

## Implementation

Files: `.github/workflows/e2e-realdata.yml`; `ci/e2e/assets-map.tsv`, `place_assets.py`,
`inno_headers.py`, `readset.py`, `gen_map.py` (the assets); `run_e2e.ps1`, `e2e_scenarios.ps1`,
`e2e_checks.ps1`, `e2e_windows.ps1`, `e2e_helpers.ps1` (the scenarios and checks, Windows
PowerShell 5.1); `report.py`, `guard_upload.py`; the self-tests in `ci/e2e/tests` (also in
`build.yml`).

Verified locally (Linux, without running any setup): the self-tests; the placement from a fresh
extraction against the reconstruction (byte equality and times of every file the build reads, the
empty folders); the read set of the preprocessed scripts of `v2` against the map; the map
regenerated with `gen_map.py` equal to the committed one; a run of every phase with the machine and
the setups simulated (no runtime error of the scenario and check code), also with an uninstaller
that stops half way and with a setup and a launcher check stopped at their time limits (the failure
is reported in its scenario, the next one reports the leftovers as `WARN` and starts clean); the
time limits of `Invoke-E2EProcess` with real processes (PowerShell 7 on Linux); every expectation
file the scenarios write accepted by the launcher's own parser.

Open until the first run on GitHub: the behaviour of Inno Setup 6.2.2 in silent mode where the code
does not decide it (log lines of Inno itself, exit code 7, the components and tasks after
`/COMPONENTS` and `/MERGETASKS`, whether the finished page runs), the GPU vendor of the runner, the
build of innoextract with the current MSYS2 packages, the time a run needs (whether the time limits
of decision 7 fit), whether `taskkill /T` reaches the child processes of a stopped setup or
uninstaller, whether the conditions of decision 1 behave as intended on the events `labeled` and
`synchronize`, and whether the mirror answers the runner. The approval setting of decision 1 is a
setting of each repository; nothing in the repository can check it, its owner must set it.

Revision after the first review (2026-10-03): decisions 1 (label and fork gate), 7 (time limits,
clean machine) and 8 (pinned launcher commit), with the README sections on runs, approval,
the pin and the caches; `ci/e2e/tests/test_e2e_tools.py` checks that the job condition and the
concurrency group agree, that the launcher is a full commit, that every action is pinned and that
each budget lies below its step limit and leaves room for a setup run and the uninstallation.
