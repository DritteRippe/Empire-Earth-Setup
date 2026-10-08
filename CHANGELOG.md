# Changelog

Release notes of the Empire Earth Community Setup. The version is the setup version
(`MySetupVersion` in `setup_is6.iss`); EE and NeoEE setups of the same version share the same
features. Up to 1.0.4.1 the setup used the four-part version format of the game, since 1.5.0 it
uses semantic versioning. Since setup v2 the product setups are released only inside the suite
installer "Empire Earth Community" and keep the setup version 1.7.2 (README, "Status"), so these
sections are named after the suite version; the suite has no changelog of its own.

Until 1.7.2 these notes lived in the header of `setup_is6.iss`. They were moved here unchanged
apart from spelling fixes, the 1.7.1 correction noted there, a correction of 1.6.0 and an
off-topic personal remark in 1.0.3.0 that was left out. Dates are the release dates given in the
header.

## Unreleased

## Suite 1.1.1 - 2026-10-08

Suite installer 1.1.1 (`SuiteVersion` 1.1.1, tag `suite-v1.1.1`) with the changes since suite 1.1.0 (tag
`suite-v1.1.0`): a "Delete" of the uninstaller that checks for links up to the last moment, a freeze that counts a
process that is ending as ended, Support and Updates links of its entry in Windows "Apps" that lead to the package,
the `SetupBuild` of both product setups in `BUILD-INFO.txt`, stricter CI and the documents of a public repository. It
packages Empire Earth Launcher 1.1.1 (tag `v1.1.1` of Empire-Earth-Launcher) and the Mod Creator; together they release
contract revision 7. The product setups still report the setup version 1.7.2; the product setups of a suite release
are told apart by their `SetupBuild` (see Added).

Released on 2026-10-08, together with launcher 1.1.1, by decision of the maintainer before its criterion (README, test
plan section 8 Block 9) was met on real hardware: **at the time of the tag no case had run on real hardware with suite
1.1.1.** Session 2 of the laptop test is still open, and the cases of session 1 (TP-94 (c), TP-27 (a), TP-25 (a) to (c),
TP-98 (a)) ran with suite 1.1.0 and were not repeated with 1.1.1. Not run on real hardware, case by case: TP-93,
TP-94 (c), TP-95 (a) to (c), TP-97, TP-98 (a) to (d), TP-99 (a) to (e) (including the cancel of a repair and of the
second game), TP-25 (a) to (d) and TP-27 (a). That includes the parts that are new in 1.1.1: the second link check right
before the deletion (TP-95 (c)) and the log line with the NTSTATUS of a process that Windows refuses to suspend
(TP-99). An install root in its 8.3 short form at the uninstallation is covered by the unit tests only, the Support and
Updates links by `ci/check_suite.py` only. CI: the job `suite-e2e` (S1 to S15, windows-latest, placeholder products,
silent, English) was green, with every job of *Build*, in runs 55 and 56 on `2fc0e76` and `e597714`; the release
commits after them change only the version number and the documents. No test at all covers TP-98 (b) to (d) or
TP-25 (d). The record of the test plan gets the results when they ran.

### Added
- GitHub issue form for bug reports (`.github/ISSUE_TEMPLATE/bug_report.yml`: program, version, Windows version, what happened,
  steps, the log locations of the setup, the suite and the launcher, a required confirmation that the reporter owns the original
  game and attaches no game files, CD keys or private package) and `.github/ISSUE_TEMPLATE/config.yml` (no blank issues, a link
  to the README section "Support"); `SECURITY.md`: report vulnerabilities privately through GitHub private vulnerability
  reporting, the latest release is supported, scope is the code and CI of this repository, no bug bounty.
- `.github/dependabot.yml`: Dependabot proposes monthly pull requests into `main` for the GitHub Actions of the workflows (at most
  three open, commit subjects start with "CI:"). No version updates for NuGet or pip: those versions are pinned on purpose.
- CI scenario S15 of the job `suite-e2e`: the suite uninstaller with "Delete" on the placeholder installation. User data in
  every folder the uninstaller offers, files next to them and `Data\dxm` of NeoEE as a junction to a folder outside with a
  canary; exactly the offered folders must go, everything else and the target of the junction must stay. It runs through a
  test hook that only the placeholder suite contains (`/TestDeleteUserData`, compiled in by `suite\build_suite.ps1
  -Placeholders` only; `suite.iss` refuses the define with real AppIds). Before, the "Delete" branch had never run in any
  test. `ci/check_suite.py` (part [Hook]) checks the hook, the fake of the scenario self-test has three new defects for S15.
- The byte samples of the contract, `docs/contract-samples` (`install.ini` of the three install modes, `files.sha256`,
  `record.reg`), taken over byte for byte from the launcher repository, which tests its readers against them (`-text` in
  `.gitattributes`). `ci/compare_contract.py` compares them file by file like `docs/CONTRACT.md` (per file the first
  differing line and both hashes, the files only one copy has, a hint for line endings; exit code 2 for a missing folder),
  and the new unit test `TestContractSamples` checks that the writers of `install.ini` and of the manifest produce exactly
  these bytes (`ci\run_unit_tests.ps1` and `ci/tests/run_unit_tests.sh` pass the folder as `/SAMPLES=...`).
- `ci\build.ps1` writes `<setup>.exe.setupbuild` next to every setup: `SHA256=<hash of the setup>` and
  `SetupBuild=<identifier>` (empty for none). `BUILD-INFO.txt` of the suite names the `SetupBuild` of both product setups
  (`Product SetupBuild:   EE <id>, NeoEE <id>`; `none` or `not recorded` in placeholder and test builds), so the product
  setups of two packages, which all report setup version 1.7.2, can be told apart (ADR 0013, amendment of 2026-10-08).
- Issue forms `feature_request.yml` (an idea for the setups or the suite, with the limits that are on purpose) and
  `security_contact.yml` (asks for a private contact without any detail: the fallback of `SECURITY.md`, which needs a
  form because blank issues are off).
- `CONTRIBUTING.md`: ways to help, the rules that matter most (Inno Setup 6.2.2, BOM and CRLF, no game data, pinned
  HTTPS downloads, the CD keys, elevated code, the shared contract, three languages), the workflow with a pull request
  into `main`, the local checks, the commit style and the changelog. `.github/pull_request_template.md` asks for what
  and why, the checks and the docs; `.github/CODEOWNERS` asks `@DritteRippe` to review every pull request. The README
  links the guide.
- `docs/RELEASING.md`: the checklist of a suite release, from the test plan, the servers and the settings that let
  reports reach the project (issues, private vulnerability reporting, the labels of the issue forms) to the package:
  every place with the version number (the product setups keep 1.7.2), the merge commit, a tag only on a commit of
  `main` whose complete `build.yml` run was green (a tag starts no run), the build of the product setups with
  `-SetupBuild suite-X.Y.Z-<commit>` and of the suite, what `BUILD-INFO.txt` and `SHA256SUMS.txt` must say, release
  notes without branch names (with a template), the package, `LAUNCHER_COMMIT` afterwards, and what is pinned on
  purpose, and which settings of the repository protect `main`, the tags and the releases. The README,
  `CONTRIBUTING.md` and ARCHITECTURE link it. The bug form says where the suite version is
  shown (its entry in Windows "Apps", the file properties), not the window title.

### Changed
- One main line `main`: development happens on short-lived feature branches with a pull request into `main`, releases
  are tags on `main` (this repository and the launcher repository; the work of the branch `v2` is merged into the base
  branch, which is called `main` from now on, here after the rename of the fork's `master`). `build.yml` runs on a push
  to `main` only (pull requests and manual runs as before), the real-data end-to-end test checks the launcher commit
  against the launcher's `main`, README and the test plan name `main`. References to what happened at a past commit (CONTRACT.md "Based on", released changelog entries, ADR texts
  about past decisions and runs) keep the branch names of that time.
- The real-data end-to-end test (`.github/workflows/e2e-realdata.yml`) runs by hand only (`workflow_dispatch`, input
  `launcher_commit`), not for pull requests: `r2.empireearth.eu` answers GitHub runners with HTTP 403 (an external block),
  so the check failed on every run, and a check that is always red trains people to ignore red checks. The `pull_request`
  trigger, the `paths` filter and the job condition with the label and fork checks are gone, the concurrency group is one
  per ref; the launcher commit check, `guard_upload.py`, the hosts block and the rule that game data never leaves the runner
  are unchanged, `LAUNCHER_BRANCH` is `main`. `ci/e2e/tests/test_e2e_tools.py` checks the new rules (manual only, no other
  trigger, no job condition, the group per ref). To be switched back to pull requests with the label `e2e` when downloads
  work again: README "End-to-end test on Windows", ADR 0011 (amendment 2026-10-07).
- `docs/CONTRACT.md` revision 7 (the same commit subject in both repositories; contract version still 1, compatible, no
  MUST or MUST NOT relaxed). New for the launcher: an installation of the suite is sent to the release page of the package
  (`https://github.com/DritteRippe/Empire-Earth-Community/releases/latest`), never to the product pages, which lead to the
  official setup with the same AppId. New informative text for suite 1.1.1: a process that is ending counts as ended in
  the freeze (1.7 point 2); the product setups of a suite release carry a `SetupBuild` (1.1); the Support and Updates
  links of the suite's uninstall key (1.3); the byte samples, compared by `ci/compare_contract.py` (1.2, 2.2, 5, O12).
  New open question O13: the update question of a product setup in the advanced mode of the suite. Corrections: status
  Released with the tags of both releases, the links at the top lead to the forks of DritteRippe (the EE-modders
  repositories have no copy), the freeze commit in "Based on" is 61797e6.
- Suite: the links "Support" and "Updates" of the entry "Empire Earth Community (Launcher, EE, NeoEE)" in Windows "Apps"
  lead to the repository Empire-Earth-Community and its releases, where the package is published, instead of
  `https://empireearth.eu/`, which neither offers nor supports the suite. The publisher's link stays the one of EE.
  `ci/check_suite.py` requires both values.
- Suite build: a release build of the suite (no `-Placeholders`, `TestID` 0) stops before ISCC unless both product setups
  have a `.setupbuild` record with an identifier; a record written for other bytes always stops the build. Build the
  product setups of a release with `ci\build.ps1 -SetupBuild suite-1.1.1-<commit>`.
- CI: every action of both workflows is pinned by its full commit with the release as a comment, at its Node.js 24 release
  (`actions/checkout` 7.0.1, `actions/upload-artifact` 7.0.1, `actions/download-artifact` 8.0.1, `NuGet/setup-nuget` 4.0,
  `microsoft/setup-msbuild` 3.0.0; `build.yml` used `@v4` tags before). The warning "Node.js 20 is deprecated" is gone.
  Dependabot groups all action updates into one pull request a month and proposes a release only after seven days.
  `ci/e2e/tests/test_suite_e2e.py` requires the pins in `build.yml`.
- Documentation after the review of suite 1.1.0: the README says that the product setups are released inside the suite
  only (with the setup version 1.7.2) and where players get the package; it calls the fix of the dead mouse confirmed
  (TP-25 (b), 2026-10-07) instead of expected; it explains why the product setups use the AppIds of the official setups
  1.7.2 and what follows from that, instead of a rule that forks generate their own; its links to the launcher lead to
  the fork `DritteRippe/Empire-Earth-Launcher` (the upstream repository has neither the contract nor this launcher).
  "Setup 1.1.0", a version no setup ever had, is "suite 1.1.0" in the README, the ADRs, the test plan and the comments.
  ADR 0011 says that the real-data end-to-end test has never run successfully on GitHub (amendment of 2026-10-08), ADR
  0013 is "Accepted, implemented", and ARCHITECTURE lists the open question O13.
- `THIRD-PARTY-NOTICES.md` names BASS 2.4.16 of Un4seen Developments, the closed-source audio library that plays the
  setup music (in this repository below `internal/lib/bass`, compiled into every product setup, never installed), with
  its terms in short and the open points (no licence text in the repository, the combination with the GPL script not
  checked legally). It also lists the other binary components the setups ship from `data\` (EE Stats, Discord Presence,
  dreXmod, the DirectX wrappers of GOG and DDrawCompat, the NeoEE files, the diagnostic tool, `Language.dll`, the game
  files, the DirectX web installer) with their origin as far as it is known.
- `SECURITY.md` starts with the supported versions (the latest suite release and `main`), links the form of GitHub
  private vulnerability reporting directly and names the new issue form as the fallback. The issue chooser links the
  help for the package (issues of Empire-Earth-Community), the launcher repository, the security policy and the README
  section "Support"; the bug form asks for the version of the package and, for a single setup (which always says
  "Setup v1.7.2"), the `SetupBuild` line of its log. README "Support" links the issue chooser. All of this works once
  Issues and private vulnerability reporting are switched on in the settings of the repository (a fork has both off);
  step 1 of `docs/RELEASING.md` checks them before every release.
- README: a banner (`.github/assets/banner-light.svg` and `banner-dark.svg`, chosen by the color scheme), badges of
  this fork (latest release, the build of `main`, license, platform, Inno Setup 6.2.2) instead of the stars, forks and
  setup version of upstream, a navigation line, a hint for players with the link to the package, and the new sections
  "At a glance", "Quick start", "Download" and "Documentation". The paragraph on the suite installer is a list by topic
  (one window, Cancel, the freeze, time limits, the window, shortcuts, .NET Framework 4.8, Windows "Apps"), and the
  long developer details (the online files, both end-to-end tests, `ci/check_contract.py`) are folded. No content is
  removed, and every heading keeps its anchor except the title.

### Fixed
- Suite: a process of a product setup that is just ending (Windows answers its suspension with
  `STATUS_PROCESS_IS_TERMINATING`, `0xC000010A`) counts as ended in the freeze before a stop. A cancel at that moment is no
  longer treated as "unclear" and repeated for that reason alone. Any other process that Windows refuses to suspend still
  blocks the stop, and the log now names its NTSTATUS (`process <id> cannot be suspended (NTSTATUS 0x...)`). ADR 0013,
  amendment of 2026-10-08.
- Suite uninstaller: a product that stays installed is recognized also when its install root is written in its 8.3 short
  form (`C:\PROGRA~2\...`), so the profiles and saves it shares with the removed product are not offered for deletion. A
  subst drive or a link in the spelling of a root is still not resolved.
- CI: the unit test "SuiteFreezeJob of a job whose program ended" no longer depends on timing: it waits until the job lists
  no process (the console helper `conhost.exe` ends a moment after `cmd.exe`). It had failed once in run 48 on the
  release commit `2b764e4` and passed in run 49 on the same commit. `ci/check_suite.py` (part [Freeze]) checks the new
  classification (`SuiteSuspendFailureIsEnd`) with three mutants.
- CI: the module docstrings of `ci/check_contract.py` and `ci/check_suite.py` are raw strings (one invalid escape `\<`,
  and two `\v` that Python read as a vertical tab). `build.yml` runs every Python step with
  `PYTHONWARNINGS=error::SyntaxWarning`, so such an escape fails CI instead of printing a warning.
- CI: `ci/check_suite.py`, `ci/check_suite_texts.py`, `ci/check_contract.py` and `ci/check_messages.py` fail when
  `suite/suite.iss` is missing, instead of skipping the rules of the suite and passing.
- CI: the cancel scenarios S11 to S14 accept a cancel that is decided again because its first look met a log line with
  only its time stamp (the processes run on, "the cancel stays requested (try N of 5)", contract 1.7 point 2). `/TestCancel`
  asks as soon as the log of the product setup is open, while it writes many lines, and S14 failed on such a try on
  2026-10-08 although NeoEE was then stopped as expected. Only the exact three lines of such a try are taken out
  (`Remove-E2ECancelRetries`); a try that cannot freeze or read, and the last try, still fail the scenario.

### Security
- Suite uninstaller: each user data folder is checked for links again right before it is deleted. Before, the folders
  were checked only before the question, and a junction created while the question was open (for example at `Data\dxm`,
  which every user may replace in an installation for all users) could make the elevated `DelTree` delete outside the
  installation. A folder that cannot be checked counts as a link (fail closed), and the cleanup of the empty folders
  leaves links alone. What remains is the moment between the second check and the end of the deletion (ADR 0013,
  amendment of 2026-10-08). The comment and the text of the CI check about `DelTree` and links are corrected.
- CI: `ci/check_tls_policy.py` also reads the suite installer (`suite/suite.iss` and its `#include` files). Every rule of
  ADR 0012 applies there, and the suite may hold no network code at all (no `http://` address, no WinHTTP, no `Option[...]`
  of a COM object, no download function), because it downloads nothing itself (ADR 0012, amendment of 2026-10-08).

## Suite 1.1.0 - 2026-10-07

Setup v2 and the suite installer "Empire Earth Community" up to suite 1.1.0. Setup v2: the
refactoring and quality fixes of the base branch and the work packages of the v2 plan
(`docs/ARCHITECTURE.md`, "Plan", all done): built-in downloads instead of a plug-in, every online
file pinned by its SHA-256 (also downloaded from a server with an invalid certificate), the
compatibility defaults, a log of every run and checksums of the setups, the install record and the
integrity manifest for the Empire Earth Launcher, hints before the installation, no elevated
installation through links, and a complete German test plan for Windows. No new game content.
Setup v2 has no release of its own: its product setups are released inside the suite, as suite
1.0.0 (tag `suite-v1.0.0`, 2026-10-06) and suite 1.1.0 (tag `suite-v1.1.0`, 2026-10-07), and keep
the setup version 1.7.2. The entries that name the suite describe the suite installer.

### Added
- Suite installer 1.1.0: `SuiteVersion` of `suite/suite.iss` is 1.1.0 (the suite has no changelog of its own; its entries are
  the ones of this file that name the suite). It packages launcher 1.1.0 (`LAUNCHER_COMMIT` of
  `.github/workflows/e2e-realdata.yml`); `MySetupVersion` of the product setups stays 1.7.2 until setup v2 is released.
  The criterion for tagging a suite 1.1.0 was TP-93, TP-94 (c), TP-95, TP-97, TP-98, TP-99 (all variants), TP-25 (a) to (d) and TP-27 (a) plus a green job
  `suite-e2e` (S1 to S14) on windows-latest for that commit (README, test plan section 8 Block 9).
  Released on 2026-10-07 (tag `suite-v1.1.0`, together with launcher 1.1.0), as an exception to that criterion by decision of
  the maintainer: after session 1 of the laptop test only (TP-94 (c), TP-27 (a), TP-25 (a), (b), (c) and (e), TP-26 (a), TP-98 (a);
  the mouse works right after the start without Alt+Tab), without session 2. TP-93, TP-95, TP-97, TP-98 (b) to (d), TP-99 (a) to (e)
  (including the cancel of a repair) and TP-25 (d) were not run on real hardware. The job `suite-e2e` (S1 to S14, windows-latest,
  placeholder products, silent, English, green on `2b764e4` and `75923f3`) exercises install, adoption, repair, uninstall and cancel,
  which are the paths of TP-93, TP-95, TP-97 and TP-99, but not the visible windows of the real run. No test at all covers
  TP-98 (b) to (d) (the window of the suite in English, with "Advanced", in German and French at 100 % and 150 % scaling) or
  TP-25 (d) (API level 11 through "Advanced"). The cases are to be run on hardware before or with 1.1.1; a problem found there is
  fixed in 1.1.1.
- Build switches can be set on the command line instead of editing the script:
  `ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss`
  (also `SignSetup`, `CertFileName`, `CertHashSHA1`, `TestID`); invalid values stop the build
  with a clear message.
- `ci/build.ps1`: clean two-pass build of all four variants, optionally against placeholder
  assets; GitHub Actions workflow compiling every push and pull request with Inno Setup 6.2.2.
  `-SignSetup -CertFileName -CertHashSHA1 [-SignTool]` makes signed builds with a DER or PEM
  certificate (see Changed). Its helpers that need no Inno Setup are in `ci/build_helpers.ps1`,
  tested by `ci/tests/build_helpers.tests.ps1` (also in the workflow).
- `suite/build_suite.ps1`: the three-pass build of the suite installer (slice count and total measured in
  pass 1, identical bytes required in pass 2 and 3, every slice at most 50,000,000 bytes, inputs checked
  against their `.sha256`, `SHA256SUMS.txt` and `BUILD-INFO.txt`); CI builds it with placeholder products
  and uploads it as an artifact. Tested by `ci/tests/suite_build.tests.ps1`.
  `-TestWrongEEPin` (placeholders only) builds the suite with a wrong pin of the EE setup for the CI scenario S5.
  A real build stops before ISCC if the legal texts the suite shows (`EULA_DSML.txt`, `neoee_rules.rtf` in `data\`)
  are missing or the placeholders of CI, and names their SHA-256 in `BUILD-INFO.txt`.
- End-to-end test of the suite installer (job `suite-e2e` of `build.yml`, `ci/e2e/run_e2e_suite.ps1`): eleven
  scenarios on a Windows runner with the placeholder builds, without any download: both products, EE only, a
  product installed on its own and adopted, a missing slice (exit code 11), a wrong pin (15), a running game or
  launcher (14), a product removed on its own before the suite uninstaller, the suite uninstaller keeping saved
  games, a repair run, a `Zone.Identifier` on the package, and a cancel while the first product setup runs
  (S11, the CI parameter `/TestCancel`: exit code 3, nothing installed, no process left). Silent runs with exact task lists that never
  select `neoee_cdkeys`, `certinclude`, `directplay` or `dxwebsetup`, shortcuts read through `WScript.Shell`, a
  dummy under `Software\Sierra\CDKeys` in all views that must survive everything, one PASS/FAIL line per
  scenario in the job summary. Tested against a fake Windows in every build
  (`ci/e2e/tests/e2e_suite_*.tests.ps1`, `test_suite_e2e.py`). The placeholder setups get a 32-bit stand-in
  of `EEStatsSetup.dll` (`ci/e2e/stub`, built by `ci/e2e/build_eestats_stub.ps1` before the placeholder
  build): the setups load the DLL when they start, and the dummy file of the placeholder generator stops them.
  CI also puts a text file named `Empire Earth.exe` into both placeholder game folders: the scenarios check the
  game program of each product, and S9 deletes it to see the repair bring it back.
- Test plan: the cases TP-90 to TP-97 for the suite installer on the laptop with real data (the package ZIP with
  and without "Zulassen" and the SmartScreen warning, a start from the ZIP view, both games with the defaults and
  played from the desktop shortcuts, a repair, the uninstaller with "Behalten" and "Löschen", the "Erweitert" path,
  an update over an existing standalone setup). TP-93 and TP-95 are the release criteria for the tags launcher
  1.0.0 and suite 1.0.0. README: a section on the suite installer; ARCHITECTURE section 11 is no longer "planned".
- `ci/make_placeholder_assets.py`: creates placeholder assets for contributors and CI, and lists
  the assets a variant needs (`--list`).
- `ci/check_messages.py` (also run by the workflow): finds duplicate messages, `==` typos, unknown
  language prefixes, used but undefined messages and translations out of the standard order
  (English, then the languages alphabetically; `--sort` fixes it) in `messages.iss`. `--coverage`
  lists the missing translations per language and the Traditional Chinese texts that are copies
  of the Simplified Chinese ones; the workflow prints that report.
- `.gitattributes` and `.editorconfig` (UTF-8 with BOM and CRLF for the own `.iss` files).
- Unit tests of the `[Code]` helpers that only compute something (`ci/tests/unit_tests.iss`, run
  by `ci/run_unit_tests.ps1`, on Linux/Wine by `ci/tests/run_unit_tests.sh`, and by the
  workflow): string split, language tag, compatibility flags, uninstall keys, URL encoding, the
  URL checks of the update question and the download policy of the online localized files (file
  types with code, https URLs, https servers). The test setup only computes, it installs nothing
  and uses no network.
- This changelog (moved out of the script header) and a "Building" section in the README.
- SHA-256 list of the online localized files (`data\localized-text.sha256`, build switch
  `DownloadHashFile`): `ci/build.ps1` writes it before compiling, `-DownloadHashesOnly` only writes
  it (for builds in the Inno Setup IDE). The setups install a downloaded `Language.dll` only if it
  is in this list. See README, "Online localized files".
- Localized texts (English, German, French) for the new messages and for the task descriptions of
  the firewall, administrator and certificate options.
- German and French texts for the installation types, the tasks and components, the status texts
  shown while installing, the DirectX wrapper part of the graphics card options and the remaining
  message boxes (Wine notice of NeoEE setups, test builds). They were English in every language;
  the other languages still show them in English. Names of games, mods and content packs and the
  shortcut names stay untranslated.
- `TRANSLATING.md`: how to translate the setup, and which texts still need native translators
  (Brazilian Portuguese beyond the language page, Traditional Chinese texts that are copies of the
  Simplified Chinese ones, and every text added after 1.7.2 in the languages other than English,
  German and French). These gaps are documented rather than machine translated.
- `docs/CONTRACT.md` (contract version 1, draft): what the setup leaves on the computer for the
  launcher (install record, `install.ini`, integrity manifest `files.sha256`, per-user default game
  settings, defaults marker) and how the launcher sends the user back to the setup for a repair. The
  same file is in the launcher repository. The setup implements it with the install state and the
  integrity manifest below; it stays a draft until a release.
- `docs/ARCHITECTURE.md`: target architecture of setup v2 (module map, data flow of an
  installation, error handling, logging, localization, testing strategy, plan of the work packages)
  and architecture decision records in `docs/adr/`: keep Inno Setup and Pascal Script, stay on Inno
  Setup 6.2.2, replace the download plug-in IDP by Inno Setup's built-in downloads, how the install
  record and the integrity manifest are written, compatibility and DirectX wrapper defaults, strict
  TLS and the file server certificate, warnings before the installation, checksums of the setups
  and a check of the contract. The entries below implement it, one work package after the other
  (all done). Two more records were added by a second plan review: no elevated installation
  through links in the
  folders all users can write to (0009), and opt-in compatibility flags on Windows 7 with rules for
  the graphics and VirtualStore test results (0010).
- `ci/compare_contract.py`: checks locally that `docs/CONTRACT.md` is identical in this and in the
  launcher repository (CI cannot reach the other repository): exit code 0 if the SHA-256 of both
  copies is the same, 1 with both hashes and the first differing line if not, 2 if a file is
  missing. Its `--self-test` runs in the workflow. See README, "Verify".
- `ci/build.ps1 -TestID <n>` builds test setups (`/DTestID=<n>`: fast compression and a warning on
  every start) without calling ISCC directly; anything but a whole number >= 0 stops the script
  before ISCC runs. `ci/tests/build_helpers.tests.ps1` checks the switch with a dry run of the
  build script against a fake ISCC that records its arguments.
- `ci/check_messages.py` also checks the encoding of the own scripts: every own `.iss` must start
  with the UTF-8 BOM, be valid UTF-8 and have only CRLF line ends (Inno Setup 6.2 reads a file
  without BOM as ANSI). It no longer has a fixed list of the own scripts: it takes every `*.iss` of
  the root folder and of `ci/tests` and every file named by an `#include "..."` line of
  `setup_is6.iss` (and of the files found that way), without third-party code under `internal/`
  and the temporary build copies, so a new module is checked from its first commit; an `#include`
  of a missing file is reported. `--self-test` (also in the workflow) runs the check against
  modified copies, e.g. a new module with an undefined message or without BOM, which must fail.
- `docs/TEST-PLAN.de.md`: the German plan of the manual tests on Windows for setup v2: safety rules
  (placeholder builds only in a virtual machine or on a snapshot, only own legally obtained game
  data, `Software\Sierra\CDKeys` is never deleted, test builds are never passed on, where the setup
  log is), test case ids (`TP-00` and one block per work package), a template per case, test
  environments and snapshots, how to make a test build (from placeholders, which needs the real
  `EEStatsSetup.dll`, or from own data with the official AppIds read from the uninstall key; the
  tools that rebuilt the data from the official 1.7.2 setups stay outside the repository, with the
  reasons), silent test runs with `/SUPPRESSMSGBOXES`, the server pre-check `TP-00`, the basic run
  `TP-70`, and the forum test cases 1 to 22 mapped to test cases or excluded with a reason. The
  other cases were placeholders, worked out by the work packages below. README: "Testing on
  Windows".
- `ci/check_test_plan.py` (also run by the workflow, with its `--self-test`): checks that every test
  case id of `docs/TEST-PLAN.de.md` is defined once with a valid status and the fields of the
  template, that the forum test cases 1 to 22 are each assigned (or excluded with a reason) and
  that every test case id named in the README, the architecture document, the ADRs or another
  Markdown file of the repository exists.
- `docs/SERVER-OPERATIONS.md`: what the file servers and the API must provide for the setup (a
  certificate for the exact host name with its chain, TLS 1.2 with a cipher suite Windows 7
  supports, `Content-Length` for every file below `/localized/`, no redirect to `http://`, identical
  files on main server and mirror), the commands to check it (`openssl s_client`, `curl`, the SSL
  Labs handshake simulation "IE 11 / Win 7" for the API, the file server and the mirror), the fix
  for the current certificate of `files.empireearth.eu` and the release criterion: at least one
  file server with a valid certificate. README: a "Support" section (setup log, missing localized
  files, Windows 7 and the update KB3140245).
- `docs/TEST-PLAN.de.md`, block 1: the Windows cases of the built-in downloads, each with build
  type, starting state, snapshot, steps, expected result and the log lines that prove it: main
  server with an invalid certificate and download from the mirror (TP-10), no server reachable
  (TP-11), stop button at the first and at the second server (TP-12, TP-13), `/VERYSILENT`,
  `/SILENT` and `/SUPPRESSMSGBOXES` without any dialog (TP-14), Korean (TP-15), a download that does
  not match its pin (TP-16) and TLS 1.2 on Windows 7 SP1 without and with KB3140245 in a virtual
  machine (TP-17). The self-test of `ci/check_test_plan.py` no longer depends on which cases are
  still planned.
- `docs/TEST-PLAN.de.md`, block 2: the Windows cases of the compatibility values and the graphics
  options: a new installation on Windows 7 writes no compatibility value except the opt-in
  `~ RUNASADMIN` (TP-20), an update on Windows 7 removes only the values of earlier setups (over
  official 1.7.2: the value of `EE-AOC.exe`) and keeps a value the player set (TP-21), Windows
  10/11 keep the values with all tasks, without `compatibility_windows` and without both (TP-22),
  the graphics matrix native, DirectX 7, 9 and 11 with menu texts, HUD, mouse and the NeoEE
  overlay (TP-23), and 150 % display scaling with and without the task `compatibility` (TP-24,
  contract O4). Windows 7 cases run in a virtual machine only (snapshot `S-Win7-172-EE` for the
  update). A planned case may be split and its block renumbered while it has no protocol; ids of
  worked-out cases stay fixed.
- SHA-256 files of the setups: `ci/build.ps1` writes `<setup>.exe.sha256` next to every setup it
  built, after ISCC compiled and signed it, in `sha256sum` format (lowercase hash, two spaces, the
  file name, one LF, UTF-8 without BOM), and prints the hash, so that it can be published next to
  the download (broken downloads in the forum, t=5741, t=3763). The helper `Write-FileSha256`
  (`ci/build_helpers.ps1`) is tested by `ci/tests/build_helpers.tests.ps1`: content, LF, no BOM,
  overwriting, relative paths, `sha256sum -c` where it exists, and the file next to every setup of
  the dry run. README: "Checksums of the setups" (publishing the hash, checking a download with
  `Get-FileHash`) and a line in "Support".
- `ci/check_contract.py` (Python 3 without packages, run by the workflow): checks that the tables
  of `docs/CONTRACT.md` match the script, which is their source of truth: the contract version in
  the header against the new `#define ContractVersion 1` of `setup_is6.iss` (no effect on the
  compiled setup yet), the row `code` of 2.4 against `CodeFileExtensions`, the table of 3.2
  against the `[Registry]` values of the game settings keys of both games (name, type, data, the
  ending epochs, class S/D = `deletevalue`, P = `createvalueifdoesntexist`) and the table of 3.7
  against the compatibility entries (the flags of each task, `WIN7RTM`, the `MinVersion` of the
  tasks and entries, the root per install mode, the order). It reads only tables of the contract
  and preprocesses `[Registry]` for all four build variants with a small interpreter of the ISPP
  directives used there; anything else is an error. It also lints `[Files]` (contract 2.3): every
  entry below `{app}` has `ignoreversion` and none has `onlyifdoesntexist`, `promptifolder` or
  `confirmoverwrite`; all 58 entries comply, so no entry changes. `--self-test` (workflow) runs it
  against modified copies that must fail (e.g. `Music Volume` `$2C` -> `$2D`, `m3d` missing,
  `WIN7RTM` -> `WIN8RTM`, an entry without `ignoreversion`); `--preprocessed out/preprocessed`
  (workflow, after the build) checks that its interpreter reads `[Registry]` exactly as ISCC
  preprocessed it and lints the expanded `[Files]` sections. README: "Verify".
- Every run of the setup writes a log (`SetupLogging=yes`): `Setup Log <yyyy-mm-dd> #<nnn>.txt` in
  the temporary folder (`%TEMP%`) of the account that runs it, so that players can attach it to a
  support request without knowing the `/LOG` switch; `/LOG=<file>` still writes to that file
  instead. With over-the-shoulder elevation the setup runs as the administrator account that
  confirmed the elevation, so the log is in that account's `%TEMP%`. The uninstaller still writes a
  log only with `/LOG`. Nothing else in the compiled setups changes. README: "Support" (where to
  find the log, and to check it for user names in folder paths before posting it publicly).
- `docs/TEST-PLAN.de.md`: every test case has a priority (new field `Priorität`, also for planned
  cases): `P1` belongs to the short run before every release (at most about three hours on the
  laptop, in Windows Sandbox or in a Windows 10/11 virtual machine; its content and the release
  criterion: see the short run below), `P2` is important but outside the short run, `P3` is
  optional (Windows 7 or 8.1 only, a second computer, an original CD). Then 10 cases were `P1`, 18
  `P2`, 4 `P3` (now 11, 18 and 4 of 33).
  `ci/check_test_plan.py` reports a missing or invalid priority (only `P1` to `P3`, optionally
  with a remark in parentheses), and its self-test proves it with a case without the field and one
  with `P4`.
- `docs/TEST-PLAN.de.md`, block 3: the Windows case of the checksums and the setup log (TP-30,
  `P1`): the `.sha256` file of every setup checked with `Get-FileHash` and `sha256sum -c`, also
  against a modified copy; the log without `/LOG` in the `%TEMP%` of the administrator, of the
  standard user after over-the-shoulder elevation (in the administrator's `%TEMP%`, not in the
  user's), of a "just for me" installation; `/LOG=<file>` instead of the `%TEMP%` log; no log of
  the uninstaller without `/LOG`; user names in the paths of the log.
- Release builds of `ci/build.ps1` (without `-TestID` or with `-TestID 0`) warn with every online
  file the setups download without a SHA-256 pin, per product (with the 1.7.2 data: the voices,
  campaigns and movies, 110 server paths each). A loopback probe under Wine showed that Inno
  Setup's downloads follow a redirect from `https://` to `http://` and that the setup then
  accepts such a file as "TLS-verified", so these files were only as safe as the configuration of
  the file servers (the setup now checks the redirects before such a download, see "Security"). The list is read from the code of `RegisterOnlineFiles` and the procedures it
  calls (`Get-OnlineFiles` in `ci/build_helpers.ps1`: the game languages, the files per game, the
  NeoEE versions, the shared lobby folder of zh-CN and zh-TW) and the hash list of the same build;
  a change of that code it does not understand stops the build. Placeholder builds (CI) only
  print the number. Tested by `ci/tests/build_helpers.tests.ps1` (the real script, changed copies,
  the dry run). `docs/SERVER-OPERATIONS.md`: requirement 4 states the probe result, and a new
  section 6 recommends pinning the files known at build time, with its trade-off (a pinned file
  that changes on the servers is discarded until the next setup). README: "Online localized
  files", "Build script".
- Compatibility flags on Windows 7 as an option: the new unchecked task "Enable compatibility
  flags (optional on Windows 7: can help if the game looks blurry or does not fit on the screen
  with enlarged display scaling)" (`compatibility_legacy`, message `TaskCompatibilityLegacy` in
  English, German and French), shown only below Windows 8 and not under Wine, on the tasks page of
  the custom settings. It writes `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`, with
  `RUNASADMIN` in front if "Always run the game as administrator, for all users" is selected too,
  for `Empire Earth.exe` (component `game`) and `EE-AOC.exe` (component `gameaoc`), in HKLM for an
  administrative installation, else in HKCU, and the uninstaller removes it; it never adds the
  Windows XP SP3 mode. Compared with official 1.7.2 this is the value of `EE-AOC.exe` there without
  the XP mode, now for both programs and off by default. The cleanup of the old Windows Vista/7
  values keeps the value of a program that the run writes with the task (pure helper
  `ShouldRemoveLegacyVistaCompatValue`, 48 unit tests) and logs it as "written by this run"; a run
  without the task removes it like every old value. Why: R15 asks to keep the compatibility
  options user-selectable, and without `HIGHDPIAWARE` Windows 7 scales the game at 150 % display
  scaling (contract O4). Decision record 0010; README "Compatibility and graphics options"; test
  cases TP-20, TP-21 and TP-24 have variants with the task (virtual machine only, `P3`).
- Install state for the Empire Earth Launcher (contract 1.1, 1.2, 1.3 and 3.5; ADR 0004 points 1,
  2, 6, 9 and 10; README "Empire Earth Launcher"):
  - install record `Software\Empire Earth Community\Installations\<EE|NeoEE>` in HKLM (64-bit
    view on 64-bit Windows) for an installation for all users, in HKCU for one "just for me", with
    `ContractVersion`, `InstallPath`, `InstallMode` (`admin`/`user`), `AppId` (without braces),
    `GameVersion`, `SetupVersion` and `SetupBuild` (only if the build sets one); every run writes
    it anew (`deletekey`), the uninstaller removes it and the parent keys if they are empty;
  - defaults marker `HKCU\Software\Empire Earth Community\GameDefaults\<EE|NeoEE>`, dwords `EE`
    (component `game`) and `AoC` (component `gameaoc`) = contract version, for the account that
    runs the setup like the game settings (with over-the-shoulder elevation: the administrator
    account); removed by the uninstaller for the account that uninstalls;
  - `install.ini` in the setup data folder, in every variant including portable (`[Install]` with
    `ContractVersion`, `Product`, `AppId`, `InstallMode` `admin`/`user`/`portable`, `GameVersion`,
    `SetupVersion`, `SetupBuild`, `Components`, `Tasks`, `Written`): deleted at the start of the
    installation step (with its temporary file), so that an aborted run leaves none, and written as
    the last step after the NeoEE CD keys, as ASCII with CRLF and without BOM through
    `install.ini.tmp`: the old file is deleted and must be gone before the rename, because
    Inno Setup's `RenameFile` never overwrites;
  - the dword `Empire Earth Community: ContractVersion` in the uninstall key, written by the regular
    setups at the end, but only if no deletion at the start and no step of writing `install.ini`
    failed (decision K4): a read-only `install.ini` or one that a program holds open without
    `FILE_SHARE_DELETE` is logged with the cause and leaves the value out, so the launcher reports
    the state Unknown instead of trusting an old file. Inno Setup recreates the uninstall key on
    every run, so the value is also missing after a later run of a setup up to 1.7.2.
  Portable setups write no record and no marker (they have no uninstaller) and no value. Failures
  only go to the setup log, they never stop the installation, so there is no new message. The code
  is in the new module `installstate.iss`; the decisions and the file handling are pure helpers in
  `utils.iss` (`InstallModeName`, `IsAsciiText`, `BuildInstallIniText`,
  `ShouldWriteContractVersionValue`, `DeleteStateFile`, `ReplaceStateFile`) with 73 new unit tests,
  33 of them at file level (no BOM, ASCII, CRLF, `RenameFile` fails over an existing file and works
  after deleting it, a read-only target or a folder of that name leaves the old state and no
  temporary file). A probe setup under Wine with the real code showed every case: fresh
  installation and repair write the value, a locked or read-only `install.ini` leaves it out with a
  log line, admin, user and portable write what the contract says, the uninstaller removes record,
  marker and folder and leaves `Software\Sierra\CDKeys` alone. The integrity manifest
  `files.sha256` came with the next work package (S-WP7, see below).
- Build switch `SetupBuild` (ADR 0004 point 10): an optional build identifier of at most 64
  characters `A-Z a-z 0-9 . _ -` (anything else stops the build), written into `install.ini` and the
  install record, so that builds of the same setup version can be told apart. `ci/build.ps1` passes
  `test<TestID>-<short commit>` for a test build (`test<TestID>` without Git), the short commit in
  CI (GitHub Actions) and none for any other build; `-SetupBuild <text>` overrides it (`''` passes
  none). Helpers `Get-SetupBuild`, `Assert-SetupBuild`, `Get-SetupBuildDefine`, `Get-GitShortCommit`
  in `ci/build_helpers.ps1`, 40 new checks in `ci/tests/build_helpers.tests.ps1` (with a temporary
  Git checkout and dry runs). `ci/check_contract.py --preprocessed` takes the `SetupBuild` that ISCC
  got from the record of the preprocessed script, so the CI step stays exact. README: "Build
  switches", "Build script".
- The setup log starts with one line naming the product, the game and setup versions, install type
  and mode, `SetupBuild`, `TestID` and the contract version.
- `docs/TEST-PLAN.de.md`, block 4: the Windows cases of the install state: record, `install.ini`
  (bytes checked in PowerShell), marker, `SetupBuild` and the value in the uninstall key for EE-admin,
  EE-user, EE-portable and NeoEE next to EE, the value missing with a read-only or an open
  `install.ini` and after the official setup 1.7.2 ran over the test build, and what the uninstaller
  removes (TP-40, `P1`); the game settings and the marker of the installing account, a second
  account and over-the-shoulder elevation (TP-41, `P2`). Section 6 says where a test build shows its
  `SetupBuild`.
- Integrity manifest `files.sha256` for the Empire Earth Launcher (contract 2; ADR 0004 points 3 to
  8; README "Empire Earth Launcher"), in every variant including portable, next to `install.ini` in
  the setup data folder:
  - every compiled `[Files]` entry below the installation folder has
    `AfterInstall: RecordInstalledFile`, which only adds the destination to a list (no file access,
    no exception can escape and abort the installation); the setup data folder, `_wonkver.pub`
    (deleted after the installation) and the `external` entries have none, and the verified online
    localized files are added from `{tmp}\verified` with the folders of their `[Files]` entries,
    including the EE learning campaign that AoC uses;
  - at the end of the installation, after the NeoEE CD keys, the page "Checking the installed files"
    (English, German, French) shows the progress while the setup hashes every recorded file once
    (paths sorted ordinal ignoring case by a merge sort, one entry per file in the spelling of the
    last entry that installed it) and writes `<sha256>  <path>` lines (lowercase hex, `/`, LF, ASCII
    without BOM) through `files.sha256.tmp`; the log gets
    `Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s`;
  - a file that cannot be read is tried twice more after 300 ms; if it stays locked, or a path is not
    ASCII, or a destination could not be recorded, the run writes **no** manifest (logged), and
    neither then nor after a failed deletion of the old one does the uninstall key get
    `Empire Earth Community: ContractVersion`, so the launcher reports "Unknown" instead of trusting
    an old or wrong manifest;
  - installed files that are gone at that moment (typically deleted or quarantined by an antivirus
    program, forum t=11045, t=41147) are logged, listed under `[MissingAfterInstall]` in
    `install.ini` and named in one notice `FilesMissingAfterInstall` (English, German, French: at
    most ten names and "and ... more", the advice to add an antivirus exception for the installation
    folder and to run the setup again for the same folder); in silent mode and with
    `/SUPPRESSMSGBOXES` only the log.
  The pure helpers (`GetManifestPath`, `IsManifestExcludedPath`, `ManifestLine`,
  `CompareManifestPaths`, `MergeSortManifestPaths`, `RemoveDuplicateManifestPaths`,
  `BuildMissingAfterInstallText`, `FormatMissingFileList`, `FormatManifestSummary`) and the file-level
  writer (`HashFileWithRetries`, `CollectExternalFiles`, `GetManifestPaths`, `HashManifestFiles`,
  `WriteInstallStateFiles`) are in `utils.iss` with 138 new unit tests (430 in all), among them a sort
  of 2000 paths in mixed case and a file-level test with a deleted and a locked file.
  `ci/check_contract.py` checks that every compiled entry below `{app}` has the `AfterInstall` and
  that the excluded ones do not (five new self-test cases). A probe setup under Wine with the real
  code showed every case, including `sha256sum -c` over the written manifest. 5 new custom messages
  (107 in all).
- `docs/TEST-PLAN.de.md`, block 5: the Windows cases of the manifest (TP-50, `P1`): `files.sha256`
  of EE-admin, NeoEE-admin and EE-portable checked line by line with PowerShell `Get-FileHash` (or
  `sha256sum -c` in Git Bash), two files deleted during the installation by a PowerShell loop that
  plays the antivirus program (notice, `[MissingAfterInstall]`, repair, silent), a file held open
  without sharing (no manifest, no value in the uninstall key), and the duration on the laptop
  (under 30 s, no "Not responding") and on an HDD or in the Windows 7 virtual machine.
- Hints before the installation, read-only (`environment.iss`, ADR 0007; forum report 4.5, 4.7, 4.8,
  4.17, section 8 items 6, 8, 9, 21):
  - every run logs the primary screen, its DPI and the game window the setup writes:
    `Screen: <w> x <h> pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), <dpi> DPI (LOGPIXELSX,
    <p> % scaling), game window <w> x <h>` (contract O4: physical pixels at 150 % can now be
    decided from the setup log);
  - a screen lower than 768 pixels (netbooks with 1024 x 600 crash after the intro, t=3863 p=26167)
    gets the notice `LowScreenResolution` after the install-mode question: the screen size, the
    game window the setup sets (at least 1024 x 768, as before) and what can help (scaling of the
    graphics driver, a DirectX wrapper);
  - leaving the folder page the first time, the setup looks for traces of retail, GOG and old
    NeoEE installations: the keys `Software\SSSI\Empire Earth`, `Software\Mad Doc Software\EE-AOC`,
    `Software\Neo\Empire Earth` and `Software\Neo\Art of Conquest` in both registry views of HKLM
    (the community setups write them only in HKCU; an old NeoEE key in HKLM was the cause in
    t=10577 p=46302) with the folder of their "Installed From" values, the folders
    `<system drive>\Sierra\Empire Earth` and `Program Files (x86)\Sierra\Empire Earth`, and the
    uninstall entries of HKLM (both views) whose name contains Empire Earth or NeoEE, except those
    of the two community setups (by AppId and publisher) and Empire Earth II and III. What it finds
    is logged and shown once in the notice `ForeignInstallFound`, which changes nothing and offers
    nothing for deletion: "Never delete the registry key Software\Sierra or one of its parent keys:
    Software\Sierra\CDKeys holds the NeoEE CD keys. To remove the other installation, use its own
    uninstaller (Windows "Apps" or "Programs and Features"), if it has one. The Empire Earth Launcher
    removes old game settings of your user account with a backup. If you are unsure, ask the
    community and attach the setup log." (deleting `Software\Sierra` by hand lost the CD keys in
    t=10950 and t=11021; the notice promises no cleanup of the HKLM keys, uninstall entries and
    folders it lists, which the launcher does not offer, ADR 0007 point 2);
  - the question `ForeignFolderQuestion` if the chosen folder is, contains or lies in the folder of
    such an installation (e.g. `C:\Sierra` or the GOG folder; `C:\Sierra2` is not inside
    `C:\Sierra`), and the question `SharedFolderQuestion` if it already holds the other community
    product (EE in a NeoEE folder or the other way round, also an installation of setup 1.7.2): it
    names the consequences (the launcher can no longer check the files of the other product;
    uninstalling one removes files and the firewall rules of the other). "Yes", the default, goes
    back to the folder page, "No" installs into the folder anyway;
  - in silent mode and with `/SUPPRESSMSGBOXES` none of this is shown, the findings are only
    logged and the installation continues. An update in place skips the folder page and these
    checks. The new messages exist in English, German and French (111 custom messages now).
  The pure parts are in `utils.iss` with 113 new unit tests (543 in all): `ClampGameWindowWidth/Height`
  (the clamp of the game window, same results as before; the limits moved there from
  `setup_is6.iss`), `IsScreenTooLow`, `FormatScreenMetrics`, `NormalizeFolderPath`,
  `IsSameOrInside`, `IsSameFolder`, `IsDriveRootOrEmpty`, `InstalledFromFolder`,
  `FormatHklmKeyName`, `IsForeignUninstallEntry`, `FormatFindingList`. `environment.iss` writes
  nothing: no registry or file function that changes anything, and no key below `Software\Sierra`
  is read.
- `ci/check_contract.py` also checks that the external `[Files]` entries of `{tmp}\verified` and
  `RecordVerifiedOnlineFiles` (`installstate.iss`), which adds the files they installed to the
  manifest, name the same sources, destination folders and components (rule "2.3", six new
  self-test cases, 70 in all): until now only a comment kept both sides together.
- `ci/check_contract.py` also checks the row "Publisher in the uninstall key" of contract 0
  against `MyAppPublisher` of `config_ee.iss` and `config_neoee.iss` and against the constants
  `CommunityPublisherEE` and `CommunityPublisherNeoEE` of `utils.iss`, by which the environment
  checks leave out the community installations (four new self-test cases, 64 in all).
- `docs/TEST-PLAN.de.md`, block 6: the Windows cases of the hints before the installation: low
  screen and the screen line of the log (TP-60), old installations created with `reg add` and
  removed again, with the exact wording of the notice and a check that a NeoEE installation with
  CD keys leaves no `Neo` key in HKLM (TP-61, `P1`), EE and NeoEE in one folder (TP-62), and the
  folder of a GOG or CD installation (TP-63). TP-24 now also reads the screen line of the log.
- `docs/TEST-PLAN.de.md`, block 8 (the ID scheme gets the row `TP-8x`): TP-80, only in a virtual
  machine: as a standard user replace `Data\Movies` by a junction (`mklink /J`), update as
  administrator with over-the-shoulder elevation: the setup stops on "Preparing to install", the
  folder the junction points to stays empty, after removing the link "Back" and "Install" run the
  installation; silent with exit code 7; a junction in the profile folder of a player stops it too,
  and so does a hard link there (`mklink /H`, part f); the user mode is not checked.
- `docs/TEST-PLAN.de.md`, build type A+: a placeholder build with the official AppIds read from the
  tester's own uninstall key (`ci\build.ps1 -Placeholders -EEAppID <GUID> -NeoEEAppID <GUID>
  -TestID 1 -OutputDir out\aplus`), so that the update over the official setup 1.7.2 can be tested
  without the game data of the maintainers: removal of the old folder `<game>\<AppId>`, the cleanup
  of old compatibility values and of `RUNASADMIN`, record, `install.ini`, manifest and the contract
  version after an update. Because such a setup updates a real installation in place and replaces
  its files by placeholders, it runs only in a virtual machine or in Windows Sandbox where setup
  1.7.2 was installed first (how: section 5), never on the laptop. TP-21 (a), TP-22 (e), TP-40 (f),
  TP-62 (d) and TP-70 (b) take it.
- `docs/TEST-PLAN.de.md`, block 7 complete: TP-71 standard user after an installation for all users
  (VirtualStore, the version with and without administrator rights), TP-72 version and LAN game
  between two installations, TP-73 repair (a deleted and a changed file, 16 bit, no uninstall key,
  a broken NeoEE installation), TP-74 The Art of Conquest without a previous start of Empire Earth
  (`Installed From`), TP-75 EE and NeoEE in separate folders with one uninstalled (firewall rules,
  settings, CD keys of the other stay), TP-76 the firewall rules when hosting, TP-77 NeoEE CD keys
  with the license server blocked and in a virtual machine, TP-78 the German version of both games,
  TP-79 the setup and the uninstaller while a game runs (`AppMutex`; with way A a PowerShell holds
  the game's mutex). TP-23 and TP-71 state the rules of ADR 0010 for their results (wrapper
  preselection per vendor, VirtualStore), TP-22 has an optional Windows 8.1 variant (virtual machine
  only, `P3`). All 33 cases are worked out; all forum test cases 1 to 22 are assigned.
- `docs/TEST-PLAN.de.md`, section 7: the `P1` short run before every release, ten steps on the
  laptop and in Windows Sandbox that combine cases with the same starting state, with minutes per
  step (about 155 minutes with ways A and A+, 170 with the step that needs the game data), and the
  release criterion: every `P1` case with all its `P1` parts passed or excepted with a reason. The
  priority field of each `P1` case names its `P1` parts. `ci/check_test_plan.py` checks that the
  short run names exactly the `P1` cases and takes at most 180 minutes (six new self-test cases, 28
  in all). README: what is new in setup v2 (under "Features"), way A+ and the short run (under
  "Testing on Windows").
- Real-data end-to-end test on a GitHub-hosted Windows runner (`.github/workflows/e2e-realdata.yml`,
  README "End-to-end test on Windows", ADR 0011): the job downloads the official setups 1.7.2
  (cached unchanged, SHA-256 checked), builds innoextract 1.10-dev with MSYS2 (cached), puts the
  files of the official setups where the build reads them (`ci/e2e/place_assets.py` with the
  data-free map `ci/e2e/assets-map.tsv`: names, sizes, SHA-1 values and times, no content;
  `ci/e2e/inno_headers.py` for the wizard bitmaps of the setup headers; `ci/e2e/gen_map.py`
  regenerates the map), builds the EE and NeoEE setups (Regular, real AppIds, unsigned) and checks
  that the scripts read exactly the files of the map (`ci/e2e/readset.py`). With every server of the
  setups blocked in the hosts file and a dummy CD key value seeded, it runs five scenarios
  (`ci/e2e/run_e2e.ps1`, Windows PowerShell 5.1): EE for all users in German with the downloads from
  the mirror, NeoEE for the current user without the CD key task, EE next to a foreign
  installation, the link guard (exit code 7) and an update without wrapper, and the official 1.7.2
  with v2 over it, back and forth, damage and repair; after each run the contract checks (install
  record, `install.ini`, uninstall key, the manifest hashed again, game settings, GPU preference,
  marker, compatibility values, firewall rules, shortcuts, permissions, the setup log) and the
  launcher core of the launcher fork against the installation (`Empire-Earth-Launcher.RealMachineTests`).
  The job is red if a check fails; the job summary has a German/English table
  (`ci/e2e/report.py`). Only logs and the report are uploaded, after `ci/e2e/guard_upload.py`
  checked that they are small text files and no file of the map; no game data is committed,
  cached, uploaded or printed. The tools are tested without game data in `build.yml`
  (`ci/e2e/tests`). `docs/TEST-PLAN.de.md`, section 12: which test cases the job covers.
  After its review: every program the scenarios start has a time limit and each phase a budget
  below its step limit (a hang is stopped with its child processes, recorded as a failure, and the
  scenario still uninstalls), and each scenario reports and removes what earlier ones left (also
  files, compatibility, GPU and firewall entries and shortcuts). The job runs by hand only since suite
  1.1.0 (see "Suite 1.1.1", Changed; the repository must require approval of workflow runs for all external contributors), and the
  launcher checks come from a pinned full commit that must be on the launcher branch. README: when it
  runs, the approval setting, the pin, the caches.

- `pins/online-files.txt`: the SHA-256 and size of every online localized file both setups can
  download, by its server path (230 paths, hashes only, no game data), compiled into every setup
  ([ADR 0012](docs/adr/0012-pinned-downloads-despite-invalid-certificates.md)).
  `ci/online_pins.ps1` checks it (format; every online file of EE and NeoEE pinned as the code of
  `RegisterOnlineFiles` registers it; no other path), rewrites it from a copy of the `localized`
  folder (`-Update -Source <folder> [-CrossCheck <second copy>]`) and has a `-SelfTest`;
  `ci/check_tls_policy.py` (with `--self-test`) checks that certificate errors are only ignored for
  pinned files, in every script compiled into the setup (also the files of `#include` lines in
  subfolders), with the functions of `winhttp.dll` declared only in `utils.iss`, each under its own
  name (no alias). CI runs all four. SERVER-OPERATIONS section 6 explains when and how the operators
  regenerate the pins.
- README, section "Known issues" (documentation only, no change to any program or configuration; the findings
  are not yet confirmed on real hardware): that `Empire Earth.exe` minimizes itself when the application loses
  activation (`WM_ACTIVATEAPP`, then `CloseWindow`), independent of the DirectX wrapper, and what reduces the
  triggers (Windows 11 "Do not disturb"/"Nicht stören", tray programs that take the foreground); the goal is a
  reliable restore, not "never minimizes". The mouse that does not react at the start until the game is minimized
  and restored (probable cause: DirectInput in foreground mode, not proven) with the two start comparisons that
  separate launcher from game. Editing `dgVoodoo.conf`: the setup writes it again on every run, `FullScreenMode`
  alone does nothing while `AppControlledScreenMode = true`, and a copy in the VirtualStore can shadow the file.
  The "2 GB": address space of a 32-bit program, not RAM, no report of a memory problem in the forum archive,
  why the setup does not set the large-address-aware flag (NeoEE programs are not ours to change, signature,
  integrity check, every run), and how to measure the memory of a running game (PowerShell, Task Manager,
  VMMap, Event Viewer). Test plan: TP-23 gets the steps 7 to 10 (mouse at the start, self-minimizing and "Do not
  disturb", VirtualStore copy, optional memory measurement) as observations, section 12 names them.
- `THIRD-PARTY-NOTICES.md` with the terms of dgVoodoo.
- The real-data end-to-end test downloads the pinned dgVoodoo archive and installs a dgVoodoo level in scenario D
  (step D5).

### Changed
- DirectX wrapper: dgVoodoo 2.87.5 instead of 2.82.1 (x86 `DDraw.dll` and `D3DImm.dll`; the control panel
  `dgVoodooCpl.exe`, x64 only since dgVoodoo 2.86.3, only on 64-bit Windows). The five configurations of the dgVoodoo
  levels have new window settings: fake fullscreen (`FullscreenAttributes = fake`), Alt+Enter off
  (`DisableAltEnterToToggleScreenMode = true`), no deferred screen mode switch (`DeferredScreenModeSwitch = false`),
  `Version = 0x287`; the API, VRAM, video card, vendor IDs, watermark and `WindowedAttributes` are unchanged. With them
  the multiplayer lobby no longer minimizes the game and Alt+Tab returns at full size on the test laptop (ADR 0005,
  amendment 2026-10-07).
- The configurations are part of the repository (`config/dgVoodoo`) and the dgVoodoo files are pinned
  (`pins/dgvoodoo.txt`): CI checks the window keys of every configuration and the `[Files]` entries of both game
  folders, `ci/build.ps1` stops a release build whose dgVoodoo files are not the pinned ones (`ci/dgvoodoo_pins.ps1`).
- The intro videos are part of the installation types "full" and "compact". An installation with custom components
  (every installation of the wizard's "Recommended settings" and of the suite) gets them once with the first update by
  this setup; an explicit `/TYPE` or `/COMPONENTS` and the type "raw" are kept. The install record has the new value
  `ComponentDefaults` (contract 1.1, revision 6).
- Game window: up to 1920 x 1200 (was 1920 x 1080), so a 1920 x 1200 screen gets the game at its own resolution without
  a display mode change; screens wider than 1920 keep their shape (2560 x 1440 and 4K stay 1920 x 1080, 2560 x 1600 gets
  1920 x 1200; contract 3.3, revision 6).
- The hidden setup data folder (holds `EEStatsSetup.dll` for the uninstaller) is now
  `{app}\_setupdata_EE` or `{app}\_setupdata_NeoEE` instead of `{app}\<AppId>`: a fixed name, but
  still one per product, so EE and NeoEE installed into the same folder do not delete each
  other's files on uninstall. Updates remove the old folder.
- Running the game as administrator is opt-in: administrative installs no longer set
  `RUNASADMIN` for the installing account by default, and updates remove that old per-user value
  (only if it is exactly the old default). The unchecked task "Always run the game as
  administrator, for all users" sets it for all users (HKLM) and now also works without the
  compatibility tasks. With it, the setup no longer gives all users write access to `Data`,
  `Users` and the config files, which an elevated game would read. Per-user values (GPU
  preference, game defaults) still go to the account that ran the setup; the script documents why.
- Firewall rules: unchanged in effect (program rules for the game, all ports), but `profile=any`
  is now written out and documented: hosting needs incoming connections on "Public" networks too.
  The task describes what it allows.
- Signed builds only (`SignSetup`): the community certificate is no longer installed as a trusted
  root certification authority (a root CA can issue certificates for any website or program), but
  only added to the trusted publishers, and only if the user checks the task (it was preselected
  for administrators). This only helps with a certificate that chains to a trusted root, e.g. one
  bought from a public CA. Updates and the uninstaller remove the root entry earlier setups made.
  The build stops unless `CertHashSHA1` is the thumbprint of the certificate file the setup ships;
  the setup only adds a certificate file with that thumbprint, and it is removed only if this
  product added it and the other product (EE/NeoEE) does not use it, with consistent `certutil`
  arguments. The thumbprint is the SHA-1 of the DER encoding, and the community certificate is
  PEM, which the preprocessor cannot decode: `ci/build.ps1 -SignSetup` converts it to a DER copy
  and passes it as `CertDerFile`, so the setup ships the certificate DER encoded (same name,
  `certutil` reads both). Builds with ISCC directly need a DER file; a PEM file stops them with a
  hint (see README, "Signed builds").
- The Wine notice of NeoEE setups is worded as a proper sentence (same content).
- Online localized files are downloaded with Inno Setup's built-in download support instead of the
  Inno Download Plugin (IDP): one download page ("Downloading localized files", title and
  description in English, German and French), one file at a time, from the server chosen before
  (main server, or the mirror if only the mirror answers) and, if a file fails there, once from the
  other server, under the same download policy as before (a file without SHA-256 never over
  `http://`). A file needed in both game folders is still downloaded once. What happens after each
  attempt is decided by `NextDownloadAction` (`utils.iss`, unit-tested). The SHA-256 of a pinned
  file is checked right after its download, so that a mismatch is told apart from a network error:
  the file is deleted and the other server is tried. Without a pin, Inno Setup compares the size of
  the file with the `Content-Length` the server sends; a file without one is accepted unchecked and
  the log says `accepted without size check`. Every failure is logged with its cause (HTTP status,
  certificate or network error), the server switch too. The verification at the start of the
  installation (`VerifyDownloadedFiles`) is unchanged and still installs only from
  `{tmp}\verified`.
- The stop button of the download page ("Stop download") ends all downloads: neither the other
  server nor any further file is requested. The installation continues with the files included in
  the setup, and the notice lists the stopped and skipped files ("download stopped, not
  downloaded"). IDP's detailed view and its error dialog with the list of URLs are gone; the notice
  after the download lists the files. In silent mode and with `/SUPPRESSMSGBOXES` nothing of this
  shows a dialog, everything is in the log.
- The timeouts of the downloads are those of Inno Setup's download code, which a script cannot set
  (IDP used 15 s to connect and 30 s per network operation). The reachability check before the
  downloads keeps its short timeouts, so a server that is down is still noticed before any file.
- The notice shown when neither file server can be used (`OnlineFilesUnreachable`) says that the
  servers could not be reached or did not present a valid security certificate (a problem of the
  servers, not of the player's computer), that the game is installed with the files included in
  the setup (some voices and campaigns may stay in English) and that running the setup again later
  adds the localized files. The log names the cause of the server switch.
- Online localized files: a downloaded `Language.dll` (or any other file with code) is only
  installed if the setup knows its SHA-256; with the official data it knows those of every
  language. Voices, campaigns, the localized movie and the lobby files are still downloaded
  without a known hash, but only over HTTPS with a validated certificate (see Security): they only
  exist on the servers and change there, and requiring a hash for them as well would leave the
  download component practically useless (it would only fetch files identical to the ones the
  setup installs anyway). The component is offered whenever downloads are possible, also by a
  setup built without the hash list, which then downloads no `Language.dll`. The notice after the
  download only lists files that really were not installed from it.
- `docs/CONTRACT.md`, revision 2026-10-02 after the review of the v2 plan (still contract version
  1, draft; the same text in the launcher repository): the setup writes `install.ini` and the
  manifest as ASCII (manifest LF, `install.ini` CRLF) and no manifest if a path is not ASCII (O3);
  optional `SetupBuild`; the value `Empire Earth Community: ContractVersion` in the uninstall key,
  whose absence tells the launcher that an older setup ran later (state Unknown); the manifest
  lists every file the run processed (installed or kept); portable setups write no defaults
  marker; contract 3.7 has a table of the compatibility values (none on Windows Vista/7 except the
  opt-in `~ RUNASADMIN`, O7); O4, O11 and O12 are answered. The entries below implement it.
- `docs/CONTRACT.md`, revision 2 after the second review of the v2 plan (still contract version 1,
  draft, because every change is compatible by its section 5; the same text and commit subject in
  the launcher repository): tables of the window size limits (3.3) and of the GPU preference values
  (3.4); in 3.7 the row of the opt-in task `compatibility_legacy` ("7 only"), the marker
  `(opt-in)`, the exception from the cleanup of the old values, and for the launcher: such a value
  is no leftover if `Tasks` contains the task; while `EE_Setup` or `NeoEE_Setup` exists the
  launcher reads neither `install.ini` nor `files.sha256` and runs no check, and it opens them with
  `FILE_SHARE_READ` and `FILE_SHARE_DELETE` (4.2, 2.5); the setup writes
  `Empire Earth Community: ContractVersion` only if it replaced `install.ini` and the manifest, so a
  manifest it could not replace is Unknown, not detectable for portable installations (1.3, 2.1,
  2.5). `ci/check_contract.py` also checks the tables of 3.3 (`MinGameWindowWidth` ...
  `MaxGameWindowHeight`) and 3.4 (the GPU preference entries), and in 3.7 the Windows versions from
  `MinVersion` and `OnlyBelowVersion`, tasks joined by `or` in `GetCompatibilityFlags`, the opt-in
  marker and two entries that could write the value of one program in the same run (55 self-test
  cases).
- `docs/CONTRACT.md`, revision 4 for the suite installer "Empire Earth Community"
  ([ADR 0013](docs/adr/0013-suite-installer.md); still contract version 1, draft: optional
  additions only, 4.1 and 4.3 unchanged; the same text and commit subject in the launcher
  repository): the names and mutexes of the suite and the launcher (0 "Suite and launcher"), the
  launcher argument `--product=EE|NeoEE` for one session (1.4), the optional suite record (1.6), how
  the suite runs a product setup, with the log line `CD Keys generation result: <n>` as an
  interface, the guard for products installed for one user only, the removal of the old product
  shortcuts before the suite shortcuts `Empire Earth` and `Neo Empire Earth`, and the launcher
  outside the product roots (1.7, O10 answered), the suite mutex as a setup mutex (4.2), the repair
  advice with the package folder (4.4). `ci/check_contract.py` checks `suite/suite.iss` against it
  (`SetupMutex`, `AppMutex` with the launcher mutex, the value names and types of the suite record,
  the game shortcuts to the launcher) and skips these rules while the file does not exist (90
  self-test cases). ADR 0013 and ARCHITECTURE section 11 describe the suite.
- `docs/CONTRACT.md` revision 5 (optional additions, still contract version 1; the same text in the
  launcher repository): the suite marks its own uninstall key with `Empire Earth Community: Suite`
  (REG_DWORD 1; 0, 1.3), and launcher source 3 skips a key with that value, or, for a suite built
  before revision 5, a key whose root is the `InstallPath` of the suite record (1.4, 1.6). Found in
  the laptop test TP-93: the suite's key has the `Publisher` of EE and showed up in the launcher as
  a damaged EE installation. The publisher stays, so Windows "Apps" still shows
  `Empire Earth Community`. `ci/check_contract.py` and `ci/check_suite.py` check the marker, and
  `ci/check_contract.py` also that no product script names it; the suite scenarios assert it.
- `docs/CONTRACT.md` revision 6 (compatible, still contract version 1, no MUST or MUST NOT relaxed; the same
  text in the launcher repository) joins the suite part (1.7 points 2, 3 and 5, see the suite entries below)
  and the launcher part: the user's explicit choice of the game window size in launcher 1.1.0 is the consent
  of 3.2 to overwrite `Game Window Width` and `Game Window Height`, within the limits of 3.3, after the guard
  and the backup of 3.6 (3.2, 3.3, 3.6). The product setups change nothing for it: they write both values at
  every run as before, so a repair or an update ends the user's choice. One row in the history, the
  checklist "Additions of revision 6" names the suite, product setup and launcher items.
- `suite/`: the frame of the suite installer "Empire Earth Community" (ADR 0013, not yet the whole
  installer): `suite.iss` (`[Setup]` for Windows 7 SP1 and later, 64-bit install mode, disk spanning
  into slices of `DiskSliceSize` bytes; the launcher, the Mod Creator and the licenses only with
  .NET Framework 4.8; the two product setups stored byte for byte with their pins), the prechecks of
  `InitializeSetup` before anything is extracted (every slice there with its exact size, as the WP0
  spike showed that a missing slice hangs even a silent run; started from the ZIP view; the games or
  the launcher running; free space; the products and the CD key decision of a silent run) with the
  exit codes 10 to 15, `suite_common.iss` (the pure helpers, 112 unit tests in `ci/tests/suite_tests.iss`),
  `suite_messages.iss` (English, German, French), and the shortcuts and the suite record written in
  code at `ssPostInstall` (the result of the spike). Build values are `/D` defines (two-pass build for
  the slices). `ci/check_suite.py` (new, with a self-test) checks the frame; `ci/check_contract.py`
  reads the record and the shortcuts from the code and rejects any reference to the protected keys
  of the CD key registration (110 self-test cases); `ci/check_messages.py` also checks the suite's
  messages and forbids `MsgBox` there (only `SuppressibleMsgBox`).
- `suite/suite_pages.iss`: the wizard pages of the suite installer (WP4). The product page ticks Empire
  Earth and Neo Empire Earth, shows for each whether it is installed (uninstall key of the runtime AppId
  in HKLM64; a product installed for one user only is shown, not ticked and skipped), has the box
  "Erweitert" (the product setups then show their full wizard) and disables "Weiter" while nothing is
  ticked. The license page shows the EULA and, only when neither product is installed, the legal
  question of the products with a "Ja" box that has to be ticked; the NeoEE rules page appears only
  when NeoEE is ticked, and the last page before the installation has the button "Installieren". The
  last page lists what became of each item, the NeoEE CD key line (the number the product logged;
  never queried or changed by the suite), the log folder and "Launcher jetzt starten" (`[Run]`,
  `postinstall runasoriginaluser nowait skipifsilent`). A silent run shows none of them; its products
  come from `/PRODUCTS`. The German texts of the suite use "du". `suite_common.iss` has the pure helpers
  (37 more unit tests); `ci/check_suite_texts.py` (new, with a self-test, in CI) fails when the legal
  question differs from `LegalQuestion` of `messages.iss` (en, de, fr) or when the embedded EULA or
  NeoEE rules are not the files of the product setups.
- `suite/suite_run.iss`: the product runner of the suite installer (WP5). `PrepareToInstall` extracts
  every selected product setup once, compares its size and SHA-256 with the pins of the build and
  deletes it again; a mismatch ends the suite with exit code 15 before any product setup runs. At
  `ssInstall` the runner runs EE, then NeoEE: mutex check, extraction, a second comparison right
  before the start, the setup started with the command line of contract 1.7 point 3 (`/TYPE=full`
  only for a first installation, never `/DIR`, the CI pass-through `/EEArgs` and `/NeoEEArgs` appended
  with its `/MERGETASKS` merged into the suite's, so a `!neoee_cdkeys` decision cannot be lost) and
  deleted afterwards. A product succeeded with exit code 0 and its uninstall entry in HKLM; exit code
  1 is reported as "a game is probably running" and the suite goes on with the next product. After a
  success the old shortcut files of a standalone run are deleted (exactly the five paths of contract
  1.7 point 7, each one logged) before the suite creates its own shortcuts at `ssPostInstall`; the
  record and the shortcuts follow what the runner reports. The number of the NeoEE log line `CD Keys
  generation result: <n>` is read tolerantly and read-only. The product logs go to `{app}\Logs`.
  `suite_common.iss` has the pure helpers (95 more unit tests); `ci/check_suite.py` checks the runner
  (one `Exec`, after the pin check; deletions limited to what the runner owns) and that no suite file
  names the CD key registry key or library (16 more self-test cases).
- `suite/suite_uninstall.iss`: the uninstaller of the suite installer (WP6). It stops while a game or the
  launcher runs or another suite setup holds the setup mutex, holds that mutex itself (contract 4.2) and
  asks one question that lists the launcher, each game with its folder and the shortcuts. The uninstallers
  of the products the suite record lists and that are still installed run one after the other (NeoEE, then
  EE; only an `unins*.exe` inside the product root, with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART`). The
  exit code of the first process decides nothing, because it only starts a copy of itself in `%TEMP%` (WP0
  spike): the suite polls the uninstall key and the program file, 10 minutes at most. A product that is gone
  already is skipped, one that fails is reported with the way through Windows "Apps" and the rest goes on.
  Afterwards the shortcuts, the record, the `settings.json` and `log.txt` of the launcher of the account that
  uninstalls and (`[UninstallDelete]`) `{app}\Logs` are removed. The profiles and saved games of both games
  (`Users`, `Data\Saved Games` below the install root of each product) and the launcher's `Backups` and
  `Mod Creator` folders (and the folder `Data\dxm\mods` of each game, see Fixed) are deleted only after the second button "Löschen" of one task dialog; "Behalten
  (empfohlen)" is the default, a silent uninstallation keeps all of it. Folders that are empty afterwards are
  removed from the inside out; the empty folder of the suite is removed again at the end if Inno Setup could not
  (a virus scanner still holding the deleted `unins000.exe`). Nothing in the suite writes or deletes below
  `Software\Sierra`. The start menu
  folder `Empire Earth Community` also has `Mod Creator`, `Uninstall Empire Earth Community` and, for a product
  that has the tool, `Empire Earth Diagnostic` and `Neo Empire Earth Diagnostic`; the game shortcuts show the
  icon of the game program. `suite_common.iss` has the pure helpers (88 more unit tests); `ci/check_suite.py`
  checks the uninstaller (12 rules, 21 more self-test cases: the programs it starts, where `DelTree` is
  allowed, the answer "Löschen", no registry deletion outside the record).
- Suite installer, fixes after the review of WP3 to WP6. The two-pass build records the number and the
  total size of the slices (`/DSliceCount`, `/DSliceTotal`) instead of their single sizes, which
  changed `setup.exe` and with it slice 1 so that the build never became stable; the setup checks that
  every slice exists, none is empty or above `DiskSliceSize` and the total matches, and the first pass
  is named `... PASS1 DO NOT SHIP`. `HKLM` and `HKCU` instead of `HKLM64` and `HKCU64` (an error on a
  32-bit Windows), no `PrivilegesRequiredOverridesAllowed` (no `/CURRENTUSER`), a stop outside the
  admin install mode. The advanced mode passes `/ALLUSERS` to the product setups (contract 1.7 point
  3). A product that is installed for all users needs no space for its files in a repair, and an
  interactive run checks only the smallest setup before the product page. `neoee_cdkeys` counts only
  in `/TASKS=` and `/MERGETASKS=`; a NeoEE run without the task says "registration not selected". The
  extracted product setup is locked against writing until it has run, and a failed extraction (a
  damaged slice) has its own text (exit code 15). The uninstaller waits for `unins000.exe` as long as
  for the uninstall key (10 minutes), does not offer a data folder that is a link or behind one or
  that belongs to a product that stays installed, keeps the game shortcut of a product that stays
  installed unless it starts the launcher, and rejects `..` in an uninstaller path. 11 more self-test
  cases in `ci/check_suite.py`, 34 more unit tests.
- `docs/CONTRACT.md`, revision 3 (still contract version 1, draft: only compatible clarifications
  by its section 5; the same text and commit subject in the launcher repository; no change of the
  setup's code): O11 names all three triggers of the question `SharedFolderQuestion`, also the
  `<AppId>` setup data folder of setups up to 1.7.2 that `IsOtherProductInFolder` checks since S-WP8.
  The launcher rules now say what the launcher v2 does: "Installed From" key before hive, the real
  game folders of foreign installations, a registry record without `install.ini` (1.4); Modified
  without a message or repair offer (2.5); at the launcher start class S only created and the first
  run only for an unambiguous installation, the display question until it is answered, class S
  while no other game runs (3.2, 3.5, 3.6); no answer of the update API is no statement about the
  version, which is also what `CheckUpdate` does (4.5).
- Compatibility values on Windows Vista/7: the setup writes none by default any more. The tasks
  "Enable compatibility flags" and "Enable earlier Windows compatibility mode" exist on Windows 8 and
  later only, where nothing changes (`WIN7RTM`, the flags `DWM8And16BitMitigation HIGHDPIAWARE
  HeapClearAllocation`, the GPU preference); on Windows Vista/7 only the opt-in task "Always run
  the game as administrator, for all users" can still write `~ RUNASADMIN`, and on Windows 7 the
  opt-in task `compatibility_legacy` the flags without the XP mode (see Added). Compared with the
  official 1.7.2 setups, `Empire Earth.exe` still gets no value on Windows 7 (its Vista/7 entries
  never applied because of the version filter `0.6.2`) and `EE-AOC.exe` no longer gets
  `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3`. Compared with the refactor
  branch before v2, which had fixed that filter, both programs lose the value. An update on
  Windows Vista/7 removes, for both programs and in the root of the install mode (HKLM for an
  administrative installation, else HKCU), a value that is exactly one of the six earlier setups
  could write there with flags or the Windows XP SP3 mode (`IsLegacyVistaCompatValue`, unit-tested);
  any other value, e.g. one the player set, and `~ RUNASADMIN` stay, and the log names every value
  removed or kept. Why: no forum post reports that the XP mode or the flags helped on Windows 7, the
  administrators never needed a compatibility mode there and one got a black screen and a runtime
  error with it (save-ee.com t=4280 p=30477, p=30479; t=1827 p=12147). The evidence is thin, so the
  test plan checks Windows 7 in a virtual machine (TP-20, TP-21). Without `HIGHDPIAWARE` Windows 7
  scales the game at 150 % display scaling (TP-24). README: "Compatibility and graphics options";
  decision record 0005.
- The DirectX wrapper preselection of the graphics card page is unchanged; the README explains the
  evidence and how to install without a wrapper ("Native"), the test plan has the graphics matrix
  (TP-23).

- Online localized files when a file server presents an invalid certificate (today
  `files.empireearth.eu`, whose certificate is that of its hosting provider; the mirror
  `storage.ee.zocker-160.de` no longer exists): the setup asks such a server once more without
  certificate validation and, if it answers, downloads the **pinned** files from it with WinHTTP,
  streamed to a temporary file that is only kept if its size and SHA-256 match the pin (ADR 0012).
  Every online file is pinned now, so the voices, campaigns and intro movie of the chosen language
  (the movie with the component "Install intro videos") arrive again; the notice
  `OnlineFilesUnreachable` only comes when no server answers at all. From a server with a valid
  certificate everything is downloaded as before; the mirror is not asked while the main server has
  one. A file without pin is never downloaded from a server whose certificate is invalid; the
  notice names it with the new message `DownloadFileServerCertificate` (English, German, French).
  The log names the state of each server and the transport of every file
  (`transport WinHTTP without certificate validation`), and a summary line counts both transports.
- Every pinned download (both transports) stops as soon as its announced or received size cannot
  match the pin, and such a file counts as "not the version this setup knows" (discarded). The
  stop button also works for the WinHTTP downloads (between two reads); their timeouts are 8 s for
  the name, 15 s to connect and send, 30 s per read.
- `ci/build.ps1`: instead of warning with the online files without a pin, every build checks
  `pins/online-files.txt`: a pinned path that no setup downloads stops every build, an online file
  without a pin stops a release build (also the placeholder build of CI) and is a warning in a test
  build, and a release build with the real data stops if `data\localized-text` pins a file
  differently, or if `pins/online-files.txt` has another size for a file with the same SHA-256 than
  the file in `data\localized-text` (the setups would reject the right file).
  `-DownloadHashesOnly` names such files too. The end-to-end check expects every
  download to be pinned.
- Suite installer: the product setups of the default mode run with `/VERYSILENT` instead of `/SILENT`, so
  neither game setup shows a progress window or a taskbar button of its own; the window of the suite is the
  only one (`SuiteProductArguments`, contract 1.7 point 3, contract revision 6, compatible, `ContractVersion`
  stays 1). The advanced mode passes no silent switch and shows the setup of each game as before. The
  unit tests, the end-to-end helpers of the suite scenarios, ADR 0013 (amendment, decisions 6 and 10) and the
  text of TP-93 follow. A hidden game setup cannot be cancelled on its own; the suite's own Cancel handling
  comes with the suite 1.1.0 runner.
- Suite installer: the progress of a running product setup can be read from its log (`SuiteTailLog`,
  `SuiteFeedLogLine`, `SuiteProgressPermille` in `suite/suite_common.iss`): the log is read while the product
  setup writes it (a share-safe read at every look, a line cut in the middle, a log that starts again), a pure
  parser maps the log lines to phases (online files servers, download, verify, installation, CD keys,
  manifest, end) and counters (files downloaded, the file and its bytes, entries installed against an
  estimate per product), and a pure function weights them into one progress value. Nothing in the suite
  shows it yet (the progress display follows); success is still decided by the exit code and the uninstall
  entry only. The log lines are an interface between the product scripts and the suite (contract 1.7 point 5,
  contract revision 6): the product scripts mark each of them with a comment, and `ci/check_suite.py` fails if
  one is reworded or no longer written. Unit tests with excerpts of the laptop logs of 2026-10-06 and a
  file-level test of the share-safe read.
- Suite installer: Cancel works while a game is installed, and a hanging game setup no longer freezes the suite.
  The suite starts each product setup with `CreateProcessW` and keeps its handle (`SuiteStartProduct`,
  `SuiteWaitForProduct`) instead of `Exec`: it keeps its window alive while it waits, logs every phase
  change of the product setup, and takes the exit code from the handle. Before a game setup has logged
  `Install step: the game folder is changed from here on` (the first statement of the installation step of the game
  setup, see Fixed) a click on Cancel asks and, on "Yes", stops the game setup and
  everything it started (the job object holds the setup program and the real setup it starts, a kill of the
  program alone would leave the game installing) and starts no further game. If a game was finished before in
  this run, the suite finishes its own part for it (launcher, shortcuts, record; exit code 0) and the last page says
  that the other game was cancelled by you; with no finished game it ends with exit code 3 and writes nothing.
  From the start of the file installation step on (the line `Install step: ...`), in the advanced mode and where
  no job can be used the Cancel button is off and a line says why; before, a click was only honored after both
  games. A game setup whose log does not grow for 10 minutes asks once whether to keep waiting (a silent run keeps
  waiting); one that runs for 90 minutes and has not reached its install step is stopped and counts as failed
  (the suite goes on with the next game), one that installs is never stopped for its time, only by the user
  through the question. New texts in English, German and French, unit tests on real programs (exit code, 259,
  a loader with a real setup stopped together), the part [Process] and mutants of `ci/check_suite.py`, scenarios
  S11 to S13, ADR 0013 (amendments), contract 1.7 point 2 (revision 6, informative) and the test case TP-99.
  A stopped game setup leaves its `%TEMP%\is-*.tmp` folder.
- Suite installer: the window shows what the game setup does. The status line names the step and the game and what the
  game setup is doing ("Step 1 of 2: Empire Earth - downloading language file 4 of 17 ...", then checking the
  files, installing the game files, registering the CD keys of NeoEE, finishing), the line under it the file with
  the part that has arrived ("name - 16.4 of 163.7 MB", decimal comma in German and French) or the game file
  being written, the bar is a real bar for the whole run (one share per game; it never goes back and is not at
  100 percent before the exit code of the game setup is known), and a list shows per game the steps that are
  done (language files downloaded n of N, game files installed, CD keys registered, list of the installed files
  written, finished; a failed game ends with "Not installed"). The line that says why Cancel is off moved below the bar.
  The last page says per game how many language files arrived (and what a missing one means), which until now was only
  in the log of the game setup. The advanced mode keeps its wizards and the line "the setup is open". The display only
  reads the log; success stays the exit code and the uninstall entry, and a failing display only writes a line to the
  log of the suite, which also gets one line per phase change and one `log read` line per game. New texts in English,
  German and French (`ci/check_suite_texts.py` now checks that all texts of the suite exist in the three languages with
  the same placeholders), unit tests of the formatting and of the bar, the part [Display] of `ci/check_suite.py`, the
  phase lines in the checks of the scenarios that install (S1, S2, S3, S9, S10; and two more defects of the fake), ADR 0013 (amendment) and the
  test case TP-98.

- The download link of the update dialogs: the update question opens `https://empireearth.eu/download/ee/` (EE) or
  `https://empireearth.eu/download/neo/` (NeoEE; any other product `https://empireearth.eu/download/`, contract 4.3
  revision 6) instead of the address that the update API names, which pointed to a host that no longer exists:
  `GET api.empireearth.eu/setup/?product=<AppId>` answered `https://cdn.empireearth.eu/setup/game/EE_Setup.exe`, and
  `cdn.empireearth.eu` no longer resolves (a CNAME to a traffic manager that does not exist any more), so the button of
  the dialog led nowhere. The website's pages work and redirect the browser to the current setup. The setup asks the
  API only the version question (`&type=` ...; `ProductDownloadPage` in `utils.iss`, unit-tested).
- Suite installer: one shortcut instead of the game shortcuts. The suite creates the shortcut `Empire Earth Community` on
  the desktop and in its start menu folder (the launcher without `--product=`: it opens with the game chosen last, and
  the player picks one of the four games on its Play page) instead of the icons `Empire Earth` and `Neo Empire Earth`
  that started the launcher with one game. The start menu folder `Empire Earth Community` holds that shortcut, the Mod
  Creator and the uninstaller; the suite creates no Diagnostic shortcut any more (the program stays in `Tools\Diagnostic`
  of the game folder). Every install, update, repair and the uninstaller delete the seven shortcuts of suite 1.0.0 that
  exist (`SuiteRemoveOldSuiteShortcuts`, `SuiteOldSuiteShortcutPath`; a log line each): `Empire Earth` and `Neo Empire
  Earth` on the desktop and in the start menu folder, their Diagnostic shortcuts and `Empire Earth Launcher`; the desktop
  shortcut `Empire Earth` only if it starts the launcher, because the EE setup's own shortcut has that name (the desktop
  `Neo Empire Earth` is deleted whatever it starts: a shortcut of that name that a player made on the desktop of all
  users goes too, and a desktop `Empire Earth` that suite 1.0.0 made without .NET Framework 4.8 stays when the EE setup
  does not run). Without .NET
  Framework 4.8 there is no launcher: the shortcut `Empire Earth Community` then starts the game program of NeoEE, else
  of EE (`SuiteFirstInstalledProduct`), and the select page says how to get the launcher. Contract 1.7 point 8 and its
  table, 1.4 and 4.3 (revision 6, compatible, `ContractVersion` stays 1; the launcher keeps `--product=EE|NeoEE` for old
  shortcuts and the hand-off), `ci/check_contract.py` (the table against the calls of `ApplySuiteShortcuts`),
  `ci/check_suite.py`, the scenarios S1, S3, S8 and S9 (`repair/OLD-SHORTCUTS`) of the suite e2e, ADR 0013 (amendment),
  TP-93, TP-94 (c), TP-95 and TP-97. The launcher has to show the four games in one list on the Play page and to open
  with the remembered game without `--product=` (launcher repository).

### Removed
- The game shortcuts `Empire Earth` and `Neo Empire Earth` that suite 1.0.0 created with `--product=EE` and
  `--product=NeoEE`, its Diagnostic shortcuts and its shortcut `Empire Earth Launcher` (replaced by `Empire Earth
  Community`, see Changed; an update deletes them).
- `IsAllowedUpdateUrl` (the allow-list for the download URL of the update API), `IsDomainOrSubdomain`, `SplitHttpsUrl`
  and the constants `DomainNeoEE`, `GitHubHost` and `GitHubProjectPath` of `utils.iss`: the setup no longer asks the
  update API for a download URL, so nothing calls them any more.
- Entries for Windows XP and older: the WIN98 compatibility mode and the pre-Vista `netsh
  firewall` rules (23 entries). Setups made with Inno Setup 6 do not start on these systems, so
  the entries never ran. For the same reason the Quick Launch shortcut task (shown only below
  Windows 7) and its three shortcuts are removed.
- The Inno Download Plugin (IDP 1.6.0, `internal/lib/idp`: two binaries, its script and
  language files) and its `[Files]` entry: the setups no longer contain or load `idp.dll`. The
  localized files are downloaded with Inno Setup's built-in support (see Changed). The installed
  game files do not change.

### Fixed
- English installation mode page: "Recommended settings" instead of "Recommanded settings".
- Test builds (`TestID`): `/SUPPRESSMSGBOXES` now suppresses the test build warning (the log still
  records it), so silent test runs with `/VERYSILENT /SUPPRESSMSGBOXES` no longer wait for a click.
  The warning used Pascal Script's `MsgBox`, which ignores that switch; release builds are not
  affected.
- The build refuses empty, malformed or identical AppIds (an AppId must be 32 hex digits with
  four dashes). An empty AppId used to compile, turned the setup data folder into the install
  folder itself (hidden, and deleted completely on uninstall) and let EE and NeoEE share one
  uninstall key.
- `setup_is6.iss` has its UTF-8 BOM again (lost in 1.6.0). Without it Inno Setup read the file as
  ANSI, so the uninstall cleanup of the pt_BR folder `Users\default\Civilizações` never matched.
- Every online localized file is requested from the mirror at the same path as on the main server
  (some AoC mirror URLs pointed to wrong paths).
- The uninstaller starts even if `EEStatsSetup.dll` is missing from the setup data folder (e.g.
  removed by an anti-virus): it is only loaded on demand, which the uninstall no longer needs, so
  the elevated uninstaller does not load code from the installation folder.
- NeoEE CD keys: the setup registers them itself after all other installation steps instead of
  through a dummy `cmd.exe /C` entry (which failed where cmd.exe is blocked, e.g. by AppLocker). A
  missing `authtools.dll` no longer stops the setup from starting and is reported when the keys
  are registered (the old file checks and the 0.5 s wait could not detect it). Installation
  folders with a comma or characters outside the system code page are reported instead of being
  passed garbled to the CD key tool. The messages are localizable (English, German, French) and
  "Sythax" is spelled correctly. The arguments sent to the tool are unchanged.
- Art of Conquest: with telemetry declined, AoC gets the privacy versions of dreXmod v2/v3 (they
  were copied into the Empire Earth folder, so AoC kept the versions with tracking), and the
  downloaded localized learning campaign goes into the AoC folder instead of the EE folder.
- EE setup: the Omega and NeoEE Extra random maps for Empire Earth are installed into the Empire
  Earth folder. They went into the AoC folder (mixing EE and AoC maps there), NeoEE Extra only when
  AoC was selected.
- NeoEE under Wine: the Wine configuration for AoC (`NeoEE.cfg`) is only installed with AoC.
- Installing without AoC no longer creates AoC registry values (VSync, window size), which also
  stayed behind after uninstalling.
- Compatibility options: Windows 8 and 8.1 get the compatibility entries of Windows 8+ (the
  entries required Windows 10, so 8 and 8.1 got none). The Windows Vista/7 entries, whose wrong
  version filter (`0.6.2` instead of `0.0,6.2`) had only let them apply to AoC, are gone (see
  Changed).
- Portable setups no longer leave an uninstall entry in the registry (holding only the setup
  type) when installed with the recommended settings.
- Tasks and components of the previous installation are matched exactly (release note 1.0.3.0
  announced it, but each list item was still searched as a substring).
- Polish texts: the description of the installation mode page is no longer replaced by "AMD"
  (the AMD option of the GPU page was saved under the wrong name), and two texts no longer start
  with "=". English telemetry option: "its" instead of "it''s".
- The game language page no longer explains "*"/"**" quality markers that no language carries.
- Localized downloads: deselecting "Download localized voices and campaigns" now also stops the
  Empire Earth downloads (the condition was "game or download", and `game` is always selected),
  and AoC files are only downloaded with AoC (the NeoEE AoC `Language.dll` was downloaded without
  it). The downloads no longer use timeouts of 0.5 s, which made slow, mobile or VPN connections
  fail (see Changed for the built-in downloads).
  The servers are no longer contacted for English or with the download deselected, and if only
  the mirror answers, the files are downloaded from it first. After the download the setup lists
  every selected localized file it did not install from the download (not downloaded, discarded
  because it does not match its SHA-256, or a program file the setup knows no verified version
  of) and installs its own version of it; it used to continue silently with a partly translated
  game.
  The list is a notice, not an error. The message about unreachable servers is localized.
- AoC gets the downloaded localized lobby files it shares with Empire Earth: IDP downloads a URL
  only once and silently dropped the second target.
- NeoEE: where a NeoEE version of a localized file exists (`Language.dll`, `WONLobby.cfg`), only
  that one is downloaded, never the EE version. If its download failed, the EE version
  downloaded to the same place replaced the NeoEE file.
- Random map scripts: installing, repairing or updating no longer deletes the whole
  `Data\Random Map Scripts` folders, which also deleted maps players made or downloaded
  themselves. Only the maps the previous setup installed are removed; the setup keeps a list of
  them in its setup data folder. The first update of an installation made by setup 1.7.2 or older
  (which has no such list) moves the old folder aside once, keeps there only the files this setup
  does not install again (own maps, maps of older versions) and says where they are. If that
  installation is cancelled or fails, the old folder is moved back.
- Mods players made: every setup run (first installation, update, repair, other components) and the
  uninstallation deleted the whole `Data\dxm` folder of both games, with the folders players make below
  `Data\dxm\mods` (the comment of `dreXmod.config` invites them to). The setups now delete exactly what they install
  or dreXmod creates there: `drexmod.com`, `images`, the presets `dxm`, `energycube`, `template` and `yukon` below
  `mods`, and the cache `dbcache` (`[InstallDelete]`, `[UninstallDelete]`). A folder of your own below
  `Data\dxm\mods` stays on update, repair, a change from dreXmod 3 to 2 and on uninstallation; a file you put into one
  of the four preset folders is still removed with it, and `dreXmod.config` is still set to the shipped default on
  every run (a choice of `<Mod>` there does not survive a setup run). The uninstaller of the suite lists the
  folder `Data\dxm\mods` of each removed game in its question with the profiles and saved games ("Behalten" is the
  default, a silent uninstallation keeps it) and removes `Data\dxm` afterwards if it is empty. This is an intended
  difference to the official setup 1.7.2, whose `[InstallDelete]` and `[UninstallDelete]` removed the whole folder; no
  file of the repository records it as an exception (the real-data comparison of the maintainers is not in the
  repository, `docs/ARCHITECTURE.md`). The DLLs of the repository data show that nothing else needs listing: dreXmod 3.4
  names only `data/dxm/dbcache` below `Data\dxm` as a path it writes, dreXmod 2 none; a file that a later version creates
  there stays after an uninstallation, and with it `Data\dxm` and the game folder (README, "Notes for Modders"). Tested by
  the scenarios S8, S9 and D of the end-to-end tests (`ci/e2e`), test case TP-81.
- Suite installer: its own uninstall key (Publisher `Empire Earth Community`, the publisher of EE)
  no longer looks like an EE installation to the launcher: the suite marks it with
  `Empire Earth Community: Suite` at the end of every run (see Changed, revision 5; laptop test TP-93).
- Suite installer: Cancel no longer stops a repair, an update or an adoption after the product setup has changed
  its game folder. The point of no return was Inno Setup's line `Starting the installation process.`, but the
  procedure `CurStepChanged(ssInstall)` of the product script runs before it and already deleted `install.ini`
  and `files.sha256`, moved the verified downloads (seconds for 170 MB) and deleted the shipped random maps (on an
  installation of setup 1.7.2 it moves the whole folder aside). A "Yes" in that window killed the product setup
  before `DeinitializeSetup` and `RestoreRandomMapScripts` could run: a game without install state (the launcher
  showed it as Unknown or Damaged) and possibly without its random maps folder. The product scripts now log the
  line `Install step: the game folder is changed from here on` as the very first statement of that step, the suite
  takes it as the install phase (`SuiteLogInstallPhase`; Inno Setup's line stays as the fallback for a product
  setup that logs none), `ci/check_suite.py` fails if the line is reworded, not written or no longer the first
  statement, and unit tests feed the order of a real log. The status "checking the language files" is therefore only
  seen for a moment: the checking of the downloaded files belongs to the install step. Contract 1.7 points 2 and 5,
  ADR 0013 (amendment) and the test case TP-99 (variant e: a repair that is cancelled) follow.
- Suite installer: the time limits of a game setup no longer stop an installation. The cap of 90 minutes killed the
  game setup even when it had started to change its game folder, silently in a `/VERYSILENT` run; the downloads count
  toward it, so a slow line (about 0.3 Mbit/s for 171 MB) could push the installation past the cap and leave a half
  installed game, the very case the Cancel rule avoids. The cap now stops a game setup only before the install step
  (`SuiteTimeoutCheck` gets `Installing`); afterwards it only writes a line. The stall question (no new line for 10
  minutes) looks again after the answer: if the game setup ended while the box was open (it was reported as stopped
  by the suite although it had succeeded) nothing is stopped, and if it started to install meanwhile the user is asked
  again with the text for an installing setup ("No" used to kill it under the text "No game files have been installed
  yet").
- Suite installer: the question of Cancel no longer says that nothing of the game stays on the computer. A stopped game
  setup leaves its `%TEMP%\is-*.tmp` folder with what it had downloaded (up to about 170 MB), and a repair or an update
  leaves the installed game as it was: there are four texts now (first installation or already installed, with or
  without a game that this run finished before), each naming the temporary folder. The line under the bar that says why
  Cancel is off wraps (it was one line high, so the German and the French texts were cut off at 100 percent display
  scaling; it takes the height its text needs at the width and font of the window and the list of the steps starts below it)
  and is shorter.
- Suite installer: cancelling the second game no longer ends the suite with the first game installed and nothing else.
  The old shortcuts of the first game were deleted already (`/NOICONS`), so the user was left with the game, no
  shortcut, no launcher and no record. The suite now finishes its own part (launcher, shortcuts, record) for the games
  that succeeded and the last page says "cancelled by you" for the other one; a cancel with no finished game still ends
  with exit code 3 and writes nothing.
- Suite installer: the file name and the size of the file being downloaded were shown for the WinHTTP transport only
  (the pinned files from a server with an invalid certificate). The normal validated TLS transport logs only Inno
  Setup's line `Downloading temporary file from <URL>: <target>` and no bytes, so with a valid certificate the line below the
  status line stayed empty, the bar moved per file, and a large file (164 MB at 1 Mbit/s takes about 22 minutes)
  could trigger the question "no progress for 10 minutes" during a healthy download. The suite now reads that line of Inno
  Setup too, and the setups log `<X> of <Y> bytes done.` at every 10 percent in that transport as well
  (`OnOnlineFileDownloadProgress`, `IsProgressLogDue` in `utils.iss`, one helper for both transports, unit-tested). Contract
  1.7 point 5 lists both lines, TP-98 covers both transports.
- Suite installer: Cancel could still kill a game setup that had started to change the game folder (run of 2026-10-07,
  scenario S12 on windows-latest: `Neo Empire Earth exists`). The suite decided "before the install step" on a look at the
  log that was a few milliseconds old, and the game setup logged `Install step: ...`, deleted its install state and
  created the game folder before the job was terminated; for a repair the same window deletes `install.ini` and
  `files.sha256` and moves the random maps. Now every stop of a game setup before its install step (Yes of the cancel
  question, "stop" of the stall question, the 90 minute limit) first suspends every process of the job
  (`NtSuspendProcess`, the job listed again until no process is new), then reads the log to its end (a half written
  last line counts as the line of the install step), and only then decides in the pure function `SuiteStopDecision`: the
  line is there, a process cannot be frozen or the log cannot be read: the game setup is resumed and runs on, the click
  counts as too late (as before, "Cancel is no longer possible", Cancel works for the next game); otherwise the job is
  terminated while frozen and the log read once more, and a line that shows up now (a missed one) gives the message that
  the game may be only partly installed and must be repaired by running the suite again (new text
  `SuiteRunCancelledLate` in English, German and French) instead of "cancelled before it installed anything". The log
  of the suite names the steps (`freezing its setup ...`, `N processes frozen`, `its N processes run again`).
  Review of this fix: a stop counts only when Windows took the order and the setup is gone (a failed kill used to leave a
  hidden game setup frozen for good, holding its mutex, while the suite said "cancelled before it installed anything");
  the freeze succeeds only if the loader has ended or is among the frozen processes (an empty or wrong list of the job was
  taken for a freeze); a decision that is not certain (a process that cannot be frozen, a log that cannot be read, a last
  line with only its time stamp) is no longer answered with "the game is being installed": the "Yes" stays requested and is
  decided again a few times, then the new text `SuiteCancelRetry` (English, German, French) says that the game setup
  could not be stopped safely right now; the comments and the ADR give the real reason the late suspension is safe (Inno
  Setup writes the time stamp, the text and the line end of a log line in separate calls without a buffer); the CI scenario
  S14 matched `N processes run again` while the suite writes `its N processes run again`: the smoke test of the scenarios
  now takes the lines of the cancel from the `Log(` templates of the suite and runs every pattern of S11 to S14 against
  them.
  Unit-tested (decision, partial lines, `SuiteTailLogToEnd`, freeze and resume of real processes), checked by
  `ci/check_suite.py` (part [Freeze]). CI: the placeholder setups pause 2 seconds before and after the install step
  (only `ci/build.ps1 -Placeholders`; `build.ps1` and `check_suite.py` prove that no other build has the hook), so S11,
  S12 and S13 stop before the line deterministically, and the new scenario S14 (`/TestCancelAtInstall`) cancels exactly at
  the line and expects "too late": the game setup completes, the cancel of the second game stops it.
- Suite installer: `/TestCancel` requests the cancel only if the log that was just read is still before the install step
  (it logs `/TestCancel not requested` otherwise, so the scenario S11 fails with a clear line instead of testing a cancel
  that came too late), and `/TestCancelNeoEE` cancels the second game (scenario S12). `SuiteWaitEnd` leaves its wait as
  soon as Setup is closing (it spun for the rest of the 5 seconds after a `WM_QUIT`); unit test with a real program.

### Security
- Online localized files: downloads use HTTPS only, from both servers, and TLS certificates are
  validated (invalid certificates used to be ignored). Files that can contain code (`Language.dll`;
  `.dll`, `.exe`, `.asi`, `.ocx`, `.sys`, `.scr`, `.bat`, `.cmd`, `.com`, `.ps1`, `.vbs`, `.js`,
  `.msi`, `.cpl`, the Miles Sound System plug-ins `.flt`/`.m3d` and similar, listed once in
  `utils.iss`) are only installed if their SHA-256
  matches a hash compiled into the setup, and not downloaded at all without one: the elevated
  setup puts them into the game folder, where they run whenever the game starts, so trusting the
  server and its certificate is not enough for them. Data files (`data.ssa` with the voices, the
  campaigns, the localized movie, the lobby files) must match their hash if the setup has one;
  without one they are accepted over HTTPS with a validated certificate ("TLS-verified, not
  pinned" in the log), never over HTTP. Most of them only exist on the servers and change there,
  so the build can rarely know their hashes. This trusts the server operators: TLS only shows
  where a file comes from, and a crafted data or movie file could still attack the old game and
  Bink parsers, so a file that must be ruled out has to be pinned. Files that do not match their hash are deleted,
  logged and reported, and the setup installs its own files instead. The hashes come from
  `data\localized-text.sha256`, which `ci/build.ps1` writes from `data\localized-text` (see
  README, "Online localized files"). The Chinese lobby files, requested from `Lobby/zh-CN/` and
  `Lobby/zh-TW/` as before, are checked against the hashes of `Lobby\zh\` (also below
  `Mods\NeoEE\`), the one lobby folder `data\localized-text` has for both languages. The
  reachability check of the file servers no longer falls back to HTTP. Very old Windows 7
  installations without updated root certificates can no longer download these files and continue
  with the files included in the setup; they should install the Windows updates or use the
  full/offline setup.
- The downloads use Inno Setup's own download code instead of a third-party DLL from 2014 that
  could not be rebuilt. It validates TLS certificates and has no way to ignore an invalid one. It
  follows redirects automatically, also from `https://` to `http://` (a loopback probe under Wine
  showed it for `301`, `302`, `307` and `308`, see `docs/adr/0008-release-checksums-and-contract-check.md`):
  only the operator of a validated server can send such a redirect, pinned files are unaffected
  (their SHA-256 decides), `docs/SERVER-OPERATIONS.md` requires that the file servers never
  redirect to `http://` and recommends pinning the files known at build time, and a release build
  lists the files without a pin. The update check and the reachability check (WinHTTP) refuse such
  redirects.
- Random map scripts: the elevated setup never follows junctions or symbolic links in the random
  map folders, which all users can write to. A user could otherwise have made it delete files or
  empty folders elsewhere, or loop through a link to a parent folder.
- Online files without SHA-256 never come over a redirect to `http://` that the server also sends
  to a `HEAD` request: Inno Setup's downloads follow a redirect from `https://` to `http://` (Wine
  probe, ADR 0008), so before such a file is requested, `CheckOnlineFileRedirects` asks its URL
  with `HEAD` requests that follow no redirect themselves (`HttpRequest`, the generalised
  `HttpGet`); every redirect must lead to `https://` again, at most five. A redirect elsewhere,
  one without `Location` or no answer refuses the file on that server like a failed download
  (log `Online file refused, ...` or `... no answer to the check of its redirects ...`), so the
  other server may still be tried; otherwise the log notes `Online file redirect check: ...`. One
  request more per file without pin; pinned files are not checked (their hash decides). Not
  covered: a server that answers `HEAD` and `GET` differently, or changes its answer in between
  (operator rules in `docs/SERVER-OPERATIONS.md`, requirement 4). New tested helpers
  `IsRedirectStatus` and `ResolveRedirectUrl` (37 unit tests).
- No elevated installation through links (ADR 0009): an installation for all users gives every
  user modify rights on `Data` and `Users` of both games, and an update or repair writes there with
  administrator rights. A standard user could replace such a folder by a junction or symbolic link
  and redirect these writes outside the game; the worst case were the `[Files]` entries that set the
  permissions of `*.cfg`, `*.config`, `*.conf` and `*.ini`: they copy every such file in every
  folder below the game folders onto itself and give every user modify rights on it, and Inno Setup
  6.2.2 follows links there, so a junction in the profile folder of a player could have given every
  user write access to the configuration files of another program; through a hard link (no
  privilege needed on Windows 7 and 8.1) the same entries could copy a file from outside the game
  that only administrators may read into one every user can read. Since setup v2, in the
  administrative install mode, `PrepareToInstall` looks at `Data`, `Users` and every folder below
  them in both game folders that exist (hidden ones too) before anything is changed. A folder that
  is a junction or symbolic link (`FILE_ATTRIBUTE_REPARSE_POINT`), or that cannot be listed, and a
  file there with more than one name (a hard link, `nNumberOfLinks` of
  `GetFileInformationByHandle`), or whose number of names cannot be read, stop the setup with the
  new message `LinkInGameFolder` (English, German, French; 112 custom messages) on the "Preparing
  to install" page: nothing changed, the folders and files (at most three, all in the log), and the
  remedy (remove the link or replace it by a normal folder or file, then "Back" and "Install" or
  run the setup again; or "Install for me only"). Silent installations end with exit code 7. The
  log names every finding and `Link check: <n> folders and <m> files below Data and Users of <app>
  examined in <ms> ms, ...`. Players who moved a folder there with a link on purpose have to undo
  it before an update. Not covered: a link created during the installation, the uninstaller,
  symbolic links to files, user and portable setups run as administrator, an installation folder
  all users can write to; RedirectionGuard of Inno Setup 6.7 would be the complete fix (ADR 0002).
  `IsReparsePoint` moved from `randommaps.iss` to `utils.iss`; the new helpers
  `IsLinkGuardedFolder`, `GetFileLinkCount` and `FindLinksInGameFolder` have 53 unit tests (596 in
  all), on Windows also with real junctions, everywhere with real hard links.
- Update check: HTTPS only (it used to retry over plain HTTP after any error) and only HTTP 200
  answers count. The download link sent by the server is only opened if it is an https URL of
  empireearth.eu, neoee.net or github.com/EE-modders, otherwise https://empireearth.eu/download
  opens. Links open in the browser of the original user instead of with the setup's admin
  rights, and the update question is shown as a question instead of an error. Systems without
  TLS 1.2 support skip the update check.
- HTTP requests of the setup (update check, reachability check of the file servers, statistics with
  consent) ask for TLS 1.0, 1.1 and 1.2 explicitly on Windows older than 8.1
  (`WinHttpRequestOption_SecureProtocols`, the set Inno Setup uses for its own downloads): Windows 7
  SP1 and 8 do not offer TLS 1.1 and 1.2 to applications that rely on the default protocols. Windows
  8.1 and later keep their defaults (with TLS 1.3 on Windows 11). If the option cannot be set, the
  request continues with the defaults and the log says why. The setup never changes the SChannel or
  WinHTTP settings of Windows (registry values such as `DisabledByDefault`); whether the explicit
  protocols are enough on Windows 7 SP1 without the update KB3140245 is checked in a Windows 7 VM
  (see `docs/TEST-PLAN.de.md`). Unit tests cover the version rule and set the option on a
  `WinHttpRequest` object at run time, without sending a request.
- Setup statistics are only sent when the telemetry component of this product is selected. A
  refusal used to send the same request with components, tasks, VM detection and OS version (only
  the user id was left out); now no request is made at all, and the uninstaller never sends one.
  The consent box is no longer pre-checked because of the consent given for the other product
  (EE/NeoEE). The request uses HTTPS only (no HTTP fallback), all values are URL-encoded, and the
  log no longer contains the query with the anonymous user id.

- Certificate validation has one exception now (ADR 0012): a pinned online file (every online
  file of a release) may be downloaded from a file server whose certificate is invalid, because it
  is only installed if its size and SHA-256 match the pin compiled into the setup. Nothing else
  ignores a certificate: not the update check, not the statistics, not a file without pin, which
  still needs a validated certificate and the check of its redirects. The flags that ignore
  certificate errors (`WINHTTP_OPTION_SECURITY_FLAGS`, `$3300`) are set in one function, only for
  the probe of a server and the download of a pinned file, which refuses a file without pin;
  `ci/check_tls_policy.py` checks that in CI. Without a valid certificate, someone on the network
  path can see which files are requested and make downloads fail, but cannot get anything else
  installed (setup 1.7.2 accepted any file in that situation).

### Internal
Refactoring without any change to what the setups install or do: the preprocessed scripts of all
four variants keep the same entries in the same order in every section, except a few entries
merged or cleaned up with the same effect (listed below).
- The game languages are listed once (`GameLangs`, `GameLangLobbyDirs` in `setup_is6.iss`). The
  language components, the localized-text `[Files]` entries (124 hand-written lines before) and
  the language list of the code are generated from it with ISPP; adding a language means adding
  it there, plus its `LIQP_<name>` message and its files. `ci/check_messages.py` checks that every
  listed language has its message.
- Repeated blocks are written once as ISPP subs and used for EE and AoC: add-on files
  (`GameAddOnFiles`), game settings (`GameSettings`), compatibility values (`CompatibilityValues`)
  and the firewall rules, whose delete entries `[Run]` and `[UninstallRun]` now share.
- Named constants instead of literals: game folders and programs (`EEDir`, `AoCDir`, `EEExe`,
  `AoCExe`, `RmsSubDir`), Windows versions of the version filters (`Win7`, `Win8`, ...), one base
  URL per web endpoint (`ApiURL`, `UpdateApiURL`, `TelemetryApiURL`, `OnlineFilesURL`, ...),
  timeouts, window size limits and the result codes of the NeoEE CD key tool.
- The product-specific values of the EE and the NeoEE setup (AppIds, name, version, publisher,
  URL, install folder name, registry keys, icons, sign tool, output file name) are in
  `config_ee.iss` and `config_neoee.iss` instead of `#if InstallType` branches spread over the
  script; `InstallType` includes one of them. The remaining branches select product content
  (NeoEE files, tasks and code).
- The URL constants of the web endpoints, `IsAllowedUpdateUrl` and `GetLanguageTag` moved to
  `utils.iss`; the compatibility value is built by `BuildCompatibilityFlags` from two flags
  instead of reading the wizard, so these helpers are covered by the unit tests.
- `RegisterOnlineFiles` registers EE and AoC from one file list; the download target of a file is
  derived from its server path.
- `eestats.iss` holds the `EEStatsSetup.dll` imports and the functions the rest of the script
  uses instead of them (`IsWine`, `GetWineVersion`, `GetGpuVendorId`, ...).
- ISPP 6.2 pitfall, documented in the script: after a `#sub` has run, later plain `#define`s of
  the same file are invisible inside subs and in files included afterwards.
- `NextButtonClick` only dispatches to one handler per page (`OnManualInstallPageNext`,
  `ApplyGpuOption`, `OnLanguagePageNext`, `OnFinishedPageNext`, ...); `InitializeSetup` and
  `InitializeWizard` are lists of named steps. The setup statistics moved to `telemetry.iss`; they
  are still sent when the user leaves the finished page.
- The options of the installation mode page are addressed by named indexes (`MiqpRecommended`,
  `MiqpCustom`, `MiqpTelemetry`, ...) instead of `Values[0]`..`Values[5]`, whose meaning shifted
  with the repair/update option. The graphics card page is defined in one table
  (`RegisterGpuOptions`: label, DirectX wrapper component, PCI vendor id). A probe setup confirmed
  the same page behaviour as before in 23552 combinations.
- One HTTP implementation, `HttpGet`, with the wrappers `GetHttpStatus` and `DownloadString`. It is
  synchronous and says so: the 1.6.0 note "Stats send is now asynchronous" was never true (the
  flag only skipped reading the status), and an asynchronous request would be cancelled because
  the statistics are sent when the setup exits.
- Names: `extention.iss` is now `extension.iss`; `MIQP_Recommanded*` messages are
  `MIQP_Recommended*`; `GetUninstallRegPath(Reverse)` is split into `GetUninstallRegPath` and
  `GetOtherProductUninstallRegPath`; `CorrectLanguageCode` is `GetLanguageTag`. `messages.iss`
  explains the `LIQP_`/`MIQP_`/`GPUIQP_` prefixes.
- Dead code removed: commented-out entries (Reborn.dll, old dreXmod variants, DirectPlay
  uninstall, ...) and code, the unused variable `ServersReacheable`, unused helpers and the
  `AntiVirusWarning` message (unused since 1.7.0). Wrong, outdated and off-topic comments are
  rewritten; the 64-bit install mode, used only to avoid the registry redirection, is a documented
  TODO.
- Same effect, fewer entries: one DirectPlay `[Run]` entry instead of two that differed only in
  `Is64BitInstallMode` / `not Is64BitInstallMode`; `upnp_info.txt` is no longer listed twice per
  game in `[UninstallDelete]`; two `[Files]` sources lost a doubled backslash.
- Consistent style (semicolons, indentation, `;` comments in sections, no trailing whitespace),
  and every include file states what it requires; the include sites explain why the order matters.

## 1.7.2 - 2023-12-04

Updated dreXmod config

- dreXmod config changes
  - Disabled mod section
  - Fixed invalid HUD size since 10 players support

## 1.7.1 - 2023-12-03

Random Map Script fixes

- Fixed an invalid RMS in the NeoEE Extra RMS
- Fixed invalid Vanilla custom RMS selection

The script header repeated the title and date of 1.7.0 for this release (copy-paste error).
The title above is taken from its content and the date from its release commit (88f0c23).

## 1.7.0 - 2023-11-29

dreXmod update and performance improvement

- Updated dgVoodoo from v2.81.0 to v2.82.1
  - Corrected window size issue when going in game from lobby/scn editor and dgVoodoo
  - White minimap fixed
- Added DDrawCompat 0.5.1 pre-release with EE fix #251
- Minor file clean-up improvement
- Added NeoEE extra maps by default for NeoEE installs
- Updated French _WONStatus.cfg
- Disabled Anti-Virus prevention message as most anti virus no longer report false positive
- Updated dreXmod from v3.2 to v3.4
  - Fixed game crash on Windows < 8 caused by 32 bits display check skip
  - 10 Players support in lobby
  - Menu resolution editable during runtime in the game settings
  - Force vertex buffer into system memory for T&L
  - Auto updater don't lock process for more than 5s (was 100s)
  - Missed message summary while in game

## 1.6.1 - 2023-07-30

dgVoodoo update and window priority fixed

- Updated dgVoodoo from v2.79.3 to v2.81.0
- dreXmod now show EE intro video by default if present to avoid window priority focus bug with dgVoodoo
- dreXmod edited to respect XML v1 convention (header comment was wrong)

## 1.6.0 - 2023-07-18

NeoEE maps update, localization fix and dXm update

- Updated dreXmod from v3.1 to v3.2
  - The game can now load campaign in other languages than the one used by Language.dll
  - Rank database fetching reduced with cache
  - A little faster game saving
  - A little faster game start (no more strange windows creation on game start)
  - Fixed invalid map type when doing /[set name] in an existing multiplayer game
  - Now possible to close the previous game instance in case it's still running in background
  - Fixed lobby/game rank icon size that was not respecting the resolution mentioned in dreXmod.config
  - Gate-crash fix (the patch is already present on NeoEE, but since it's now in dxm any EE/AoC instance will have the fix)
- Include dreXmod image web cache by default to reduce the freeze time during first login
- DX Web setup only run for DX9 and native render
- Fixed problems with the language patching (EE-modders/localized-text)
- Fixed invalid auto GPU selection
- Reworked dgVoodoo configs
- Fixed invalid NeoEE WON files copy
- Disabled online DirectX End-User Runtime install for Wine
- Improved laptop compatibility by suggesting to Windows 10/11 to use a real graphic card if present
- Updated IS from 6.2.1 to 6.2.2
- Use the Windows resolution as default game resolution if >=1024x768 && <=1920x1080
- Fixed invalid repair/modify auto selection (was messed up with telemetry agreement)
- Added Kazter RMS Pack v1 for Neo (and included Perfect Island by yukon) (+13 (11 + 2) maps)
- Stats send is now asynchronous (not sure that it work)
- Removed J2 civs

Correction: the statistics request stayed synchronous (the setup waited for the answer); see the
Internal notes of the release after 1.7.2.

## 1.5.0 - 2023-02-06

Massive bug fixing in the setup, more simple installation and new language behaviour for setup

- Changed setup versioning to semantic versioning (old one didn't make sense but was respecting the format of the game)
- Added localized message for telemetry
- Updated dgVoodoo from v2.71.3 to v2.79.3
- Fixed tab overlapping in the Internet Screen and adjusted the one in the LAN Screen
- Fixed telemetry selection when disabled in install mode screen that was still enabled in custom components list
- Updated dreXmod from v3.0 to v3.1
  - Fix AoC camera bug introduced in v3.0
  - Reworked themes to support dynamic fonts & UI (resolution)
  - dxmdata is now located in data\dxm
  - Fixed a crash when dxmdata was not found
- Updated EES from v1.0.4 to v1.0.5
- Added 'Take JPG Screenshots' to regedit, allowing game screenshots to be jpg and not bmp, which greatly reduces the files size
- Reactivation of the DirectPlay installation
- Reworked languages folders to fit https://github.com/EE-modders/localized-text
- The setup language is now different than the game one, so a game lang page has been added
- The setup no longer ask the setup lang except if unable to detect a setup compatible one
- Fixed invalid telemetry selection that could be unselected in some cases
- Fixed a bug that make the setup telemetry always report installed as true
- Thanks to Jodocus authtools source code, I converted it to a dll with built-in admin/user support, AV should be happy now
- Automatic GPU detection for DirectX Wrapper
- Added Warning Message Box (and log) if authtools.dll is removed (probably by antivirus)
- Muting the setup audio will now pause the music instead of muting it
- Updated IDP from v1.5.1 to v1.6.0 (compiled manually using VS2005 on XP)
- DirectX End-User Runtime install now use the web based installer to reduce the setup
- Added EE & AoC mutex to Setup to detect and avoid operations while an instance is running

## 1.0.4.1 - 2022-12-26

Runtime fix

- DLL are now compiled with /MT to ensure no additional runtime libs are required
- This include: EEStats.dll EEStatsSetup.dll EEDiscord.dll

## 1.0.4.0 - 2022-12-24

Better support for Wine and ARM, added Telemetry (+possibility to accept/refuse) and dreXmod 3

- Added Empire Earth Stats v1.0.4
- Added dreXmod v3 (yeah, I'm not kidding, it's finally released)
  - Add a ranking system in the multiplayer lobby
  - Add an anti cheat system
  - Improved resolution patch
  - Add a Lobby Theme and Mod system
  - Add a quick civ selection in game
  - Various minor improvement and fix for the game and lobby
- Now able to agree or reject tracking for dreXmod and EES!
- Updated EE Discord from v1.0 to v1.1.1
- More secure files and folder permissions, only Data/Users can be edited by anyone (avoid non-admin to add/edit dll to game dir)
- Show update and not repair when a setup version different from the one already installed is started
- EE Diag is no more selected by default with Wine
- Fixed invalid regedit path not overwritten when not created by the setup (Sierra Setup create but don't delete it...)
- Fixed Wine detection, the setup was reading the registry, we are now using a dll that call ntdll.dll -> wine_get_version
- Disabled compatibility, firewall, certutil and file permissions flags for Wine (was useless and speed up the install process)
- Removed Retail/GOG text on EE/AoC banners since we only use Retail
- Less visible EE black border in startup banner and reduced EnergyCube logo opacity
- Added Setup mutex to avoid multiple instance running at the same time
- Reworked the Setup code and reorganized some parts because the code was getting really messy
- Added ARM support (tested on Windows 11 ARM64 Parallels Desktop)
- Fixed regedit entry for Wine installations (created even without using AoC for ex.)
- Added EE and AoC pl campaign thanks to jorrr1#1558
- Fixed Scenario Editor render bug caused by HD Terrain that was transparent

## 1.0.3.0 - 2022-04-14

eC Civs update, lobby regist. for Gen Z, fixed Linux setup crash, easy install mode and CD Keys/Install repair

- Updated eC civs thanks to Kazter
- Added back the NeoEE Updater because it could still be required
- NeoEE registration now allow year up to 3000 (was limited to 1999)
- Fixed NeoEE Admin binary headers
- Added a new page in the setup to install with default options (easy) or custom options
- Added a new page for default options to select GPU vendor to try to apply settings
- Renamed 'Game Intro' to 'Install intro videos' to avoid that people don't understand
- Updated HD Icons by Fortuking
- CD Keys now display an error message when fail
- Installation step has been reworked to use safer IS function instead of the page ID
- Components/Tasks now split the elements rather than stupidly looking for a match in the whole reg list as string
- Added back dgVoodoo DX 11 config and more stable DX 12 thanks to Giord (also removed useless dgVoodoo dlls files)
- Fixed AoC directory creation when not installing it while using DirectX Wrapper
- Reworked gold corners of IG interface (isn't in HD content, it's by default)
- Removed already installed warning

## 1.0.2.0 - 2022-03-06

NeoEE Map fix, new HD content inc. icons with/without letters

- Fixed invalid maps on NeoEE
- Fixed EE:Diagnostic error while EE running
- Reworked WON Lobby Dialog images
- Added tips for recommended multiplayer max pop for NeoEE
- Updated HD Icons by Fortuking
- Added some HD terrain textures from Yukon mod
- Better file clean-up (OOS, UPnP)
- Reworked Omega content management in the Setup

## 1.0.1.0 - 2022-02-20

NeoEE CDKeys user support, fixed Regedit and added new tool

- Patched authtools.exe to install CDKeys in HKCU (now there is 2 authtools bin)
- Patched EE & AoC to read CDKeys in HKCU (now there is 2 Neo EE/AoC bin)
- Fixed wrong regedit compatibility delete that was deleting the entire (Layers) key
- Reworked compatibility flags, with fewer flags and better admin rights
- Added Empire Earth Diagnostic, a simple tool giving install information (.NET 4)
- Better certificate uninstall (check if another game is installed)
- Allow to install the certificate as user
- Redirected Chinese traditional setup messages to Chinese

## 1.0.0.1 - 2022-02-17

NeoEE version fix

- Fixed invalid regedit path for NeoEE (Installed From Directory was reversed)
- Deleted old NeoEE integrated updater

## 1.0.0.0 - 2022-02-16

Initial Version

- EE & AoC (in 11 languages)
- Support NeoEE, dreXmod, Omega content
- Support NeoEE CDKey generation (Admin)
- Download localized content online (support mirror)
- Online update checker (support mirror)
- DirectX Wrapper (DX9 with GOG dll and DX12 with dgVoodoo dll)
- Better compatibility with additional flags
- HD Content with FortuKing textures
- Registered in Firewall (Admin)
- DirectX 9 Install (when using DirectX Wrapper for DirectX 9)
- Removable Movies
- Digitally signed

Notes:
- DX11 (API 10 & 11) has been disabled. It is obviously impossible to fix the bug related to the
  full screen of the lobby (which puts the main window in window).
- Reborn.dll is currently disabled because of a bug that makes it unusable with dgVoodoo (or makes
  the window bug occur even with DirectX 12).
- Since after analysis the binaries of GOG and the one of the 2002 Empire Earth crack are identical
  the installation mode of the GOG binary has been removed since it is useless (its equivalent is to
  simply use the DirectX Wrapper of DirectX 9)
