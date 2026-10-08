# Architecture of the Empire Earth Community Setup (v2)

This document describes the architecture of setup v2: what the parts of the script are, how data
flows through an installation, how errors, logging, localization and testing work, and which work
package (S-WP1 ... S-WP12, see [Plan](#plan); all done) brought each change. Decisions are recorded as
ADRs in [docs/adr](adr/README.md). What the setup leaves on the computer for the Empire Earth
Launcher is specified in [docs/CONTRACT.md](CONTRACT.md) (shared with the launcher repository); this
document only explains how the setup implements it.

Starting point is branch `refactor/quality-fixes` (setup 1.7.2 plus the quality fixes, see
[CHANGELOG.md](../CHANGELOG.md) "Unreleased"). v2 evolves it, it does not rewrite it
([ADR 0001](adr/0001-keep-inno-setup-and-pascal-script.md)).

## 1. Goals and constraints

- **Same game installation as before.** The files, registry values, firewall rules and run entries
  a v2 setup creates are those of the refactor branch, except for the changes listed in the
  CHANGELOG. Each work package that changes the compiled setup is checked against dumps of the
  official 1.7.2 setups and of the previous refactor build (see [Testing](#8-testing-strategy)).
- **Toolchain:** Inno Setup **6.2.2** with Pascal Script ([ADR 0002](adr/0002-stay-on-inno-setup-6.2.2.md)),
  no third-party plug-in for downloads ([ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md)).
  Setups run on Windows 7 SP1 to 11 (x86, x64, Arm64 via emulation) and under Wine.
- **Never weaken trust decisions:** HTTPS only, with certificate validation everywhere except for
  online files with a compile-time SHA-256 pin, whose hash decides
  ([ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md)), code only with such a pin, no automatic elevation of the game, CD-key registration through
  `authtools.dll` exactly as before (server, port, arguments, checks unchanged).
- **The launcher can rely on the setup:** install record, `install.ini`, integrity manifest and
  defaults marker as in the contract ([ADR 0004](adr/0004-install-record-and-integrity-manifest.md)).
- **Every user-visible text** in English, German and French; other languages fall back to English
  until a native speaker translates them ([TRANSLATING.md](../TRANSLATING.md)).

## 2. Build variants and products

One script, four variants, selected by ISCC switches (`/DInstallType=EE|NeoEE`,
`/DInstallMode=Regular|Portable`) plus the two AppIds:

| | Regular | Portable |
|---|---|---|
| Install modes (contract) | `admin` (HKLM, Program Files) or `user` (HKCU, `%LOCALAPPDATA%\Programs`) | `portable` (no uninstaller, no uninstall key) |
| Install record (registry) | written (`HKA`) | not written |
| `install.ini`, `files.sha256` | written | written |
| Defaults marker (HKCU) | written, removed by the uninstaller | not written (no uninstaller; contract 3.5) |
| `Empire Earth Community: ContractVersion` in the uninstall key | written (shows that no older setup ran afterwards) | - (no uninstall key) |

`config_ee.iss` / `config_neoee.iss` hold everything that differs between the products (AppId,
names, versions, registry keys of the game settings, icons, output name). Product-specific
content (files, tasks, code) stays in the scripts under `#if InstallType`.

## 3. Module map

The own `.iss` files are parts of one script, not independent units: Pascal Script only knows what
is declared before it is used, so the include order matters. Each file lists in its header what it
requires.

| File | Responsibility | Pure helpers (unit-tested) | v2 change |
|---|---|---|---|
| `setup_is6.iss` | Build switches and their checks, `[Setup]`, `[Languages]`, `[Types]`, `[Tasks]`, `[Components]`, `[Files]`, `[Dirs]`, `[Registry]`, `[Icons]`, `[InstallDelete]`, `[UninstallDelete]`, `[Run]`, `[UninstallRun]`; the event functions (`InitializeSetup`, `InitializeWizard`, `NextButtonClick`, `CurStepChanged`, ...) only dispatch to the modules | - | download wiring (S-WP3, done), compatibility tasks from Windows 8 on, no Vista/7 entries, `RemoveLegacyVistaCompatValues` (S-WP4, done), `SetupLogging` and `ContractVersion` define (S-WP5, done), opt-in task `compatibility_legacy` on Windows 7 (`OnlyBelowVersion`, entries `CompatibilityValuesWin7`, `GetCompatibilityFlags` passes `compatibility or compatibility_legacy`) and the cleanup that keeps its values (S-WP10, done), install record and defaults marker (`[Registry]`, Regular only), the build switch `SetupBuild` with its ISPP check, the first log line, `DeleteInstallState` first at `ssInstall` and `WriteInstallState` last at `ssPostInstall` (S-WP6, done), `AfterInstall: RecordInstalledFile` on every compiled file entry below `{app}` except the setup data folder and `deleteafterinstall` files, `CreateManifestProgressPage` in `InitializeWizard` (S-WP7, done), the screen API (`GetSystemMetrics`) moved to `environment.iss`, `GetScreenResolutionWidth/Height` use `ClampGameWindowWidth` and `GameWindowHeight`, `InitializeSetup` logs the screen and shows the low-screen notice, `NextButtonClick(wpSelectDir)` returns `CheckSelectedFolder` (S-WP8, done), `PrepareToInstall`: in `admin` mode `CheckGameFoldersForLinks`, else a log line (S-WP11, done) |
| `config_ee.iss`, `config_neoee.iss` | Product configuration | - | - |
| `utils.iss` | URL constants, string helpers, language tag, compatibility flags, uninstall keys, the single HTTP implementation (`HttpGet`), the download pages of contract 4.3 (`ProductDownloadPage`), download policy (`GetOnlineFileCheck`, `CodeFileExtensions`) | yes, all functions without wizard access | TLS 1.2 for `HttpGet` on Windows 7 (`NeedsExplicitTlsProtocols`, `ApplyTlsProtocols`), `NextDownloadAction` (S-WP3, done); `IsLegacyVistaCompatValue`, `IsBelowWindows8` (S-WP4, done); `ShouldRemoveLegacyVistaCompatValue`, which keeps the values of `compatibility_legacy` (S-WP10, done); `InstallModeName`, `IsAsciiText`, `BuildInstallIniText`, `ShouldWriteContractVersionValue`, the file helpers `DeleteStateFile` and `ReplaceStateFile` (`.tmp`, delete, check, rename; S-WP6, done); manifest path and exclusions (`GetManifestPath`, `IsManifestExcludedPath`), `ManifestLine`, ordinal comparison and merge sort (`CompareManifestPaths`, `MergeSortManifestPaths`, `RemoveDuplicateManifestPaths`), `BuildMissingAfterInstallText`, `FormatMissingFileList`, `FormatManifestSummary`, and at file level `HashFileWithRetries`, `CollectExternalFiles`, `GetManifestPaths`, `HashManifestFiles`, `WriteInstallStateFiles` (S-WP7, done); the window limits `MinGameWindowWidth` ... `MaxGameWindowHeight` (moved from `setup_is6.iss`; `MaxGameWindowHeight` is 1200 and `WideScreenGameWindowHeight` limits the height of screens wider than 1920, contract 3.3 revision 6) with `ClampGameWindowWidth`, `GameWindowHeight` (it replaced `ClampGameWindowHeight`), `IsScreenTooLow`, `FormatScreenMetrics`, the folder helpers `NormalizeFolderPath`, `IsSameOrInside`, `IsSameFolder`, `IsDriveRootOrEmpty`, `InstalledFromFolder`, `FormatHklmKeyName`, the community publishers `CommunityPublisherEE/NeoEE` with `IsForeignUninstallEntry`, `FormatFindingList` (S-WP8, done); `IsReparsePoint` (moved from `randommaps.iss`), `IsLinkGuardedFolder` (`Data`, `Users` and below), at file level `FindLinksInGameFolder`, `LinkFindingsShownMax` (S-WP11, done); the server states, the transports and the size limit of the online files (`ClassifyOnlineFilesServer`, `ChooseOnlineFilesServerOrder`, `GetOnlineFileTransport`, `IsDownloadSizeAcceptable`, `ParsePinnedSize`, `SplitDownloadUrl`, `DescribeWinHttpError`, `GetWinHttpAccessType`), the WinHTTP declarations and the only code that ignores certificate errors (`ApplyCertificateErrorIgnoreFlags`, called by `OpenWinHttpRequest` for `GetHttpStatusIgnoringCertificate` and the pinned downloads; S-WP12, done, [ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md)) |
| `messages.iss` | `[CustomMessages]` in all languages, `[Messages]` overrides | `ci/check_messages.py` | new texts in en/de/fr per package |
| `eestats.iss` | Wrapper of `EEStatsSetup.dll` (Wine, GPU vendor, statistics values) | - | - |
| `extension.iss` | Command line switches, previous installation (uninstall key), Windows version | - | - |
| `pages.iss` | Custom wizard pages (game language, installation mode, graphics card) | - | - |
| `downloads.iss` | Online localized files: pins (`pins/online-files.txt` and the hash list of the build), policy application, server selection with the state of each server, **download engine** (built-in `TDownloadWizardPage`/`DownloadTemporaryFile`; pinned files from a server with an invalid certificate over WinHTTP, `DownloadPinnedFileWinHttp`), verification into `{tmp}\verified` | policy, pins, server states, transports, size limit and the decision after each attempt via `utils.iss` | engine replaced (S-WP3, done); every online file pinned, pinned downloads from a server with an invalid certificate, size limit (S-WP12, done) |
| `randommaps.iss` | Random map scripts: list-based cleanup, migration of 1.7.2 folders, restore on abort | - | `IsReparsePoint` moved to `utils.iss` for the link check, used as before (S-WP11, done) |
| `telemetry.iss` | Setup statistics, only with consent | - | - |
| `installstate.iss` (new) | Contract writer: records installed files, deletes stale state at `ssInstall` (and remembers a deletion that failed), writes `install.ini` and `files.sha256` (ASCII; hashing with retries) at the end of `ssPostInstall`, the contract version into the uninstall key only if both files were replaced, reports files that disappeared; `GetContractInstallMode` for the install record | via `utils.iss` | new: `install.ini`, the uninstall key value, `GetContractInstallMode` (S-WP6, done); `RecordInstalledFile` (the `AfterInstall` of `[Files]`), `RecordVerifiedOnlineFiles`, `files.sha256` on an output progress page, `ReportMissingFiles` (S-WP7, done) |
| `environment.iss` (new) | Read-only checks before the installation: screen size, DPI and clamped window in the log and a notice for a screen lower than 768 pixels (`InitializeSetup`), foreign or old installations (retail/GOG/old NeoEE keys in both views of HKLM, foreign uninstall entries, the retail folders; one notice per run), installing into their folder, EE and NeoEE in one folder (questions, folder page); the link check before an elevated installation | via `utils.iss` | new (S-WP8, done: `LogScreenMetrics`, `ShowLowScreenResolutionNotice`, `CheckForeignInstallations`, `CheckSelectedFolder`; S-WP11, done: `CheckGameFoldersForLinks`) |
| `internal/lib/bass` | Setup music (third-party) | - | - |
| `internal/lib/idp` | Inno Download Plugin (third-party DLL) | - | **removed** in the last commit of S-WP3 (done) |
| `ci/build.ps1`, `ci/build_helpers.ps1` | Two-pass build of all variants, hash list of `data\localized-text`, DER copy of the certificate, SHA-256 files of the setups, the checks of `pins/online-files.txt` against the online files (`Get-OnlineFiles` reads them from the code of `RegisterOnlineFiles`) and against the hash list of the build, the build identifier `SetupBuild` and its record next to every setup (`<setup>.exe.setupbuild`, bound to the SHA-256 of the setup) | `ci/tests/build_helpers.tests.ps1` | SHA-256 files of the built setups (S-WP5, done), warning with the online files without a pin in a release build (S-WP5, done: the redirect probe showed that `https://` -> `http://` is followed), `/DSetupBuild`: `-SetupBuild`, else `test<TestID>-<commit>` for a test build, the short commit in CI, none otherwise (S-WP6, done); the pins of every online file instead of the warning: missing pin or a different pin in `data\localized-text` stop a release build, a pin of no online file stops every build (S-WP12, done) |
| `ci/check_messages.py` | Checks `messages.iss`, the use of messages in every own script and the encoding (UTF-8 BOM, CRLF) of every own `.iss`; finds the own scripts itself (root and `ci/tests` `*.iss` plus the `#include "..."` closure of `setup_is6.iss`, without `internal/`) | `--self-test` (CI workflow) | own scripts from the `#include` lines, encoding check, self-test (S-WP2, done) |
| `suite/build_suite.ps1`, `ci/suite_build_helpers.ps1` | Three-pass build of the suite installer (ADR 0013): inputs against their `.sha256`, the `SetupBuild` of each product setup from its `.setupbuild` record (a release build stops unless both have one), the AppIds (dummies only with `-Placeholders`), ISCC version, pass 1 measures count and total of the slices, passes 2 and 3 must be identical, every file at most 50,000,000 bytes, `SHA256SUMS.txt`, `BUILD-INFO.txt`; placeholder build with a stub launcher and a computed `DiskSliceSize` (not below the size of `setup.exe`) | `ci/tests/suite_build.tests.ps1` (fake ISCC) | new (WP7); CI builds the placeholder suite after the product builds and uploads it |
| `ci/e2e/run_e2e_suite.ps1`, `ci/e2e/e2e_suite_scenarios.ps1`, `ci/e2e/e2e_suite_helpers.ps1` | The scenarios S1 to S15 of the suite installer on a Windows runner with the placeholder builds (job `suite-e2e` of `build.yml`, no download): they reuse `e2e_helpers.ps1` and `e2e_windows.ps1` (dirty state, cleanup, process runner with limits, shortcut reader, uninstaller runner), set the dummy AppIds with `Set-E2EAppIdOverride` and pass exact task lists through `/EEArgs` and `/NeoEEArgs`; the suite shortcuts are read through `WScript.Shell`, the CD key dummy is snapshot-compared after every scenario | `ci/e2e/tests/e2e_suite_helpers.tests.ps1`, `e2e_suite_scenarios.tests.ps1` (fake Windows), `test_suite_e2e.py` | new (WP8) |
| `ci/check_contract.py` (new) | Checks that the tables of `docs/CONTRACT.md` (header, 2.4 row `code`, 3.2, 3.3, 3.4, 3.7) match the source of truth in the script (`ContractVersion`, `CodeFileExtensions`, the `[Registry]` values of the game settings keys, the compatibility entries with `BuildCompatibilityFlags`/`GetCompatibilityFlags` and the tasks); reads only tables; preprocesses `[Registry]` for every build variant with a small interpreter of the ISPP directives used there (anything else is an error); lints the `[Files]` flags below `{app}` | `--self-test` (CI workflow); `--preprocessed <folder>` compares the interpreter with the scripts ISCC preprocessed (CI workflow, after the build) | new (S-WP5, done); tables of contract 3.3 (window limits) and 3.4 (GPU preference), in 3.7 the Windows versions from `OnlyBelowVersion` ("7 only"), the marker `(opt-in)`, several tasks per flags parameter and entries that would write one value twice (S-WP10, done); `--preprocessed` takes the `SetupBuild` that ISCC got from the install record of the preprocessed script, because `ci/build.ps1` passes one in CI (S-WP6, done); the `[Files]` lint also requires `AfterInstall: RecordInstalledFile` on every compiled entry below `{app}` and forbids it on the setup data folder, `deleteafterinstall` and `external` entries (S-WP7, done); rule "0": the publishers of the table "Products" against `MyAppPublisher` of both configurations and `CommunityPublisherEE/NeoEE` of `utils.iss`, by which the environment checks leave out community installations; the window limits of 3.3 are read from `utils.iss` now (S-WP8, done); rule "2.3": the external `[Files]` entries of `{tmp}\verified` and `RecordVerifiedOnlineFiles` (`installstate.iss`) name the same sources, folders and components (review of v2, done) |
| `ci/compare_contract.py` (new) | Local only: compares the SHA-256 of both copies of `docs/CONTRACT.md` (contract O12); exit code 0 identical, 1 different (both hashes, first differing line), 2 file missing | `--self-test` (CI workflow) | new (S-WP1) |
| `ci/check_test_plan.py` (new) | `docs/TEST-PLAN.de.md`: unique TP ids, a valid status and the template fields per case, the P1 short run, every forum test case 1 to 22 assigned (or "Launcher"/"entfällt" with a reason) with a "Stand" that matches its cases, every TP id named in a Markdown file of the repository exists | `--self-test` (CI workflow) | new (S-WP2, done); field `Priorität` P1/P2/P3 per case (S-WP5, done); the table of the short run (section 7 of the plan) names exactly the P1 cases, whole minutes per step, the row "Summe" is their sum and at most 180 (S-WP9, done) |
| `ci/tests/unit_tests.iss` | Unit tests of the pure helpers (a tiny setup that only computes) | - | extended per package |
| `pins/online-files.txt`, `ci/online_pins.ps1` (new) | The checked-in pins (SHA-256, size, server path) of every online file of both products; the script checks the list (format, coverage of the files `RegisterOnlineFiles` registers, no other path) and rewrites it from a copy of `/localized/` (`-Update`, `-CrossCheck`) | `-SelfTest` (CI workflow) and `ci/tests/build_helpers.tests.ps1` | new (S-WP12) |
| `ci/check_tls_policy.py` (new) | Lint of every script compiled into the setup (root folder and `#include` files, also `internal/lib/bass/bass.iss`) and into the suite installer (`suite/suite.iss` and its `#include` files): certificate errors are only ignored in `ApplyCertificateErrorIgnoreFlags`, called once by `OpenWinHttpRequest`, only for the probe and the download of pinned files, which refuses a file without pin; never the certificate option of the COM object; the functions of `winhttp.dll` only in `utils.iss`, each under its own name; no other HTTP stack; no network code at all in the suite (no `http://` address, no WinHTTP, no `Option[...]` of a COM object, no download function of Inno Setup; ADR 0012, amendment 2026-10-08) | `--self-test` (CI workflow) | new (S-WP12) |

Include order in `setup_is6.iss`: `utils.iss`, `messages.iss`, `bass.iss` before `[Languages]`;
in `[Code]`: `eestats.iss`, `extension.iss`, `pages.iss`, `downloads.iss`, `randommaps.iss`,
`environment.iss`, `installstate.iss`, then the event functions, `telemetry.iss` after the language
functions it uses.

**Rule for new code:** a function that can be written without the wizard, the registry, the file
system or the network goes into `utils.iss` and gets a unit test; the module only gathers the
inputs (wizard state, registry, files) and applies the result.

## 4. Data flows

### 4.1 Installation

```
InitializeSetup
  first log line: product, versions, install type and mode, SetupBuild, TestID, contract version
  music (not silent, not Wine)
  screen size, DPI and clamped game window logged (S-WP8, done)            [always, read-only]
  update check (`&type=` only) -------> api.empireearth.eu (HttpGet, TLS, short timeouts)
  update question: download page -----> browser, empireearth.eu/download/<ee|neo>/ (no request, contract 4.3)
  legal question (first installation)
  test-build warning, install-mode notice,
  screen lower than 768 pixels (S-WP8, done) [notice], NeoEE Wine notice
InitializeWizard
  languages, download pins, telemetry state, custom pages, background, download page (S-WP3)
  SelectNewDefaultComponents (Regular, last): the intro movies once on the first update of a custom
                       installation (install record value ComponentDefaults, NewDefaultComponentSkipReason)
Wizard pages
  language -> installation mode -> (graphics card | components, tasks) -> folder -> ready
  folder page Next (S-WP8, done; skipped page on an update = no check):
                            foreign or old installations [notice, once per run];
                            folder of such an installation? [question, Yes stays on the page]
                            EE and NeoEE in the same folder? [question, Yes stays on the page]
                            (silent, /SUPPRESSMSGBOXES: log only, never stays)
NextButtonClick(wpReady)
  RegisterOnlineFiles: server choice (state of each server: valid certificate, answer only
                       without validation (pins only), no answer), selected localized files,
                       policy and transport per server (pin / TLS only / refused)
  DownloadOnlineFiles (S-WP3): one file at a time, main server then mirror  -> {tmp}\<RelDest>
                               (NextDownloadAction decides; a stop ends all requests;
                               a file without pin only after CheckOnlineFileRedirects:
                               HEAD without redirects, every redirect to https;
                               S-WP12: from a server with an invalid certificate only
                               pinned files, WinHTTP, kept only if size and SHA-256 match)
PrepareToInstall (S-WP11, done; admin mode only, user and portable: a log line)
  Data, Users and every folder below them, both game folders that exist: a junction, a symbolic
  link or a folder that cannot be listed, a file with more than one name (hard link) or one whose
  number of names cannot be read? -> stop with LinkInGameFolder on the Preparing page,
  nothing changed yet (Back: Ready page, Install runs the downloads and the check again;
  silent: exit code 7)
CurStepChanged(ssInstall)
  DeleteInstallState (first): delete install.ini, files.sha256 and their .tmp files of the previous
  run (S-WP6, S-WP7, done); a failed deletion is logged with its cause and remembered (no contract
  version in the uninstall key in this run)
  VerifyDownloadedFiles: pins, move accepted files to {tmp}\verified, notice for the rest
  PrepareRandomMapScripts, previous certificate state
[InstallDelete] -> [Dirs] -> [Files] (AfterInstall: RecordInstalledFile records each destination,
  S-WP7, done) -> [Icons]
  -> [Registry] (game settings; Regular only: install record in HKA, written anew, and defaults
     marker in HKCU, S-WP6, done) -> [Run]
  -> uninstall key (Inno Setup recreates it)
CurStepChanged(ssPostInstall)
  FinishRandomMapScripts, legacy root certificate, legacy RUNASADMIN,
  legacy Vista/7 compatibility values (S-WP4, done: only on Windows Vista/7, only exact values
  of earlier setups, HKLM or HKCU by install mode; S-WP10, done: not the value that this run wrote
  with the opt-in task compatibility_legacy), NeoEE CD keys (authtools.dll)
  WriteInstallState (last step, S-WP6 and S-WP7, done): add the verified online files of the
  external entries; on the progress page "Checking the installed files": manifest paths (sorted,
  unique, without setup data folder and uninstaller), SHA-256 per file (two retries 300 ms apart),
  "Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s" in the log; files.sha256.tmp ->
  files.sha256 (only if complete and ASCII), install.ini.tmp -> install.ini with
  [MissingAfterInstall] (ASCII check, target deleted and gone before each rename); the notice if
  installed files are gone (antivirus hint; log only when silent); ContractVersion into the
  uninstall key (Regular) only if no deletion and no writing failed
NextButtonClick(wpFinished)
  telemetry (only with consent), setup type in the uninstall key
DeinitializeSetup
  restore a random map folder moved aside if the installation did not complete, stop music
```

### 4.2 What the launcher reads afterwards

| Artefact | Where | Written by | Contract |
|---|---|---|---|
| Install record | `HKA\Software\Empire Earth Community\Installations\<Product>` | `[Registry]` (Regular) | 1.1 |
| `install.ini` | `{app}\_setupdata_<Product>\` | `installstate.iss` | 1.2 |
| `files.sha256` | `{app}\_setupdata_<Product>\` | `installstate.iss` | 2 |
| Game settings | `HKCU\<game settings key>` | `[Registry]` `GameSettings` block (source of truth) | 3 |
| Defaults marker | `HKCU\Software\Empire Earth Community\GameDefaults\<Product>` | `[Registry]` | 3.5 |

The install record has one setup-internal value the launcher ignores, `ComponentDefaults` (contract 1.1, revision
6): the revision of the default components the installation has received (`ComponentDefaultsRevision` in
`utils.iss`; 1 = the intro movies belong to the types `full` and `compact`). The types `full` and `compact` select
new default components by themselves on an update; an installation of the type `custom` (every installation of the
"Recommended settings" and of the suite) gets them once, because Inno Setup restores its earlier selection
(`SelectNewDefaultComponents`, not with `/TYPE` or `/COMPONENTS`, not for `raw`).

The dgVoodoo files and configurations: `GameAddOnFiles` installs `DDraw.dll`, `D3DImm.dll` and (64-bit Windows only)
`dgVoodooCpl.exe` from `data\Add-on\DirectX_Wrapper\dgVoodoo_bin`, pinned in `pins/dgvoodoo.txt`, and the configuration
of the chosen level from `config/dgVoodoo` (tracked, byte for byte), into both game folders; `ci/dgvoodoo_pins.ps1`
checks the pins, the entries and the window keys, `ci/build.ps1` the files of `data\`.

### 4.3 Uninstallation

`[UninstallDelete]` removes the setup data folder (with `install.ini`, `files.sha256`, the random
map lists and `EEStatsSetup.dll`); `uninsdeletekey` removes the install record and the defaults
marker of the uninstalling account, `uninsdeletekeyifempty` the empty parent keys; firewall rules,
compatibility values and the GPU preference as before. `Software\Sierra\CDKeys` is never touched.

## 5. Error handling

Principle: **only a failure of the core installation (files, registry of Inno Setup itself) stops
the setup.** Every optional step logs the cause, shows a localized notice (not in silent mode,
not with `/SUPPRESSMSGBOXES`) and continues with what the setup itself contains. No step deletes
or changes anything outside its own scope to recover. The one exception is a security check: the
link check before an elevated installation stops the setup, before anything is changed, when it
finds a link or cannot examine a folder (S-WP11, [ADR 0009](adr/0009-no-installation-through-links.md)).

| Step | Failure | Behaviour |
|---|---|---|
| Update check | no answer, invalid TLS, odd answer | no question, setup continues (the page of the question, contract 4.3, needs no request) |
| Environment checks (S-WP8, done) | registry or folder not readable, an exception in a check | treated as "nothing found" (the rest of the check is skipped), logged; never blocks a silent installation and never keeps the wizard on the folder page |
| Server selection | neither server answers (with pins: neither with nor without certificate validation) | notice `OnlineFilesUnreachable` (server problem, included files installed, run again later), local files only |
| Server with an invalid certificate (S-WP12) | the request with validation fails, the one without gets an answer | pinned files downloaded from it over WinHTTP and kept only if size and SHA-256 match; a file without pin not requested there, named in `DownloadIncomplete` (`DownloadFileServerCertificate`) |
| Download of one file (S-WP3) | network, TLS, HTTP status, size (also a size that cannot match the pin, S-WP12), pin mismatch | other server tried once (if it may deliver the file); still failing: file reported in `DownloadIncomplete`, local version installed |
| User stops the downloads (S-WP3) | stop button | no further request (no mirror, no next file), remaining downloads skipped, installation continues, all listed in `DownloadIncomplete` |
| Verification at `ssInstall` | pin mismatch, move failed | file discarded, reported, local version installed |
| `[Files]` | file locked, disk full | Inno Setup's own retry/abort dialog (unchanged) |
| NeoEE CD keys | `authtools.dll` missing, network, VM, ... | specific `CDKeys*` message, installation completes (repair = run the setup again) |
| Link check before an elevated installation (S-WP11, done) | a junction or symbolic link at or below `Data` or `Users` (the folders of the players included), a folder there that cannot be listed, a file there with more than one name (hard link) or whose number of names cannot be read, an exception during the check | stop on the "Preparing to install" page with `LinkInGameFolder` (remove the link or replace it by a normal folder or file, or install for the own account only); silent: exit code 7, every folder in the log; nothing changed. The only check that fails closed: a folder it cannot examine counts as a finding |
| Deleting `install.ini`/`files.sha256` at `ssInstall` (S-WP6/7) | file held open by another program without `FILE_SHARE_DELETE`, or read-only | logged with the cause; this run writes no `Empire Earth Community: ContractVersion`, so the launcher reports "Unknown" instead of trusting an old manifest (portable: not detectable, logged) |
| Recording a destination (S-WP7) | exception in `RecordInstalledFile` (`AfterInstall`) | caught and counted, never escapes (it would abort the installation); no manifest in this run |
| Hashing one file (S-WP7) | read error (file briefly locked) | two retries after 300 ms; still failing: file and cause logged, no manifest |
| Writing `install.ini`/`files.sha256` (S-WP6/7) | I/O error, a path that is not ASCII, rename failed (`RenameFile` does not overwrite) | logged, temporary file removed, no manifest and no contract version in the uninstall key (the launcher reports "Unknown" and advises a repair) |
| Installed files gone at `ssPostInstall` (S-WP7) | antivirus deletion | listed in `[MissingAfterInstall]`, notice with antivirus advice and repair hint |
| A setup up to 1.7.2 runs later over v2 | it keeps `install.ini`, `files.sha256` and the record | it recreates the uninstall key without `Empire Earth Community: ContractVersion`; the launcher reports "Unknown" (contract revision, S-WP1); portable: not detectable |
| Aborted installation | any | `install.ini`/`files.sha256` were deleted at `ssInstall`, so no stale manifest claims a valid state; random maps restored |

Exceptions in Pascal Script are caught where a call can fail for external reasons (DLL loading,
COM, file I/O, downloads); event functions never let an exception escape into Inno Setup's
installation loop (an exception in `AfterInstall` would abort the installation, so
`RecordInstalledFile` only appends to a list).

## 6. Logging

- **Every run writes a log** (`SetupLogging=yes`, S-WP5): `%TEMP%\Setup Log <date> #<n>.txt`
  (`<date>` as `yyyy-mm-dd`, `<n>` the three-digit number of the run on that day), so that players
  can send it without knowing the `/LOG` switch. `/LOG=<file>` still works and writes to `<file>`
  instead (Inno Setup: a file name given with `/LOG` takes precedence over `SetupLogging`).
- Every decision is logged with its reason: update check, legal question, page choices,
  registered/refused/accepted downloads (pinned or TLS-only, with SHA-256), the state of each file
  server and the transport of every download (`without certificate validation` for the pinned
  WinHTTP downloads, S-WP12), server fallback and its cause, random map moves, certificate handling, CD-key result code, manifest summary (number of
  files, size, duration, missing files), files accepted without size check (no `Content-Length`),
  the reason a download was not retried (stop, no mirror allowed), compatibility values of
  earlier setups removed or kept on Windows Vista/7 (with the value; kept as "written by this run"
  with the opt-in task `compatibility_legacy`, S-WP10), environment findings
  (every registry key, folder and uninstall entry found, the number of uninstall entries read and
  the time, every question and its answer; S-WP8, done), the screen
  (`Screen: <w> x <h> pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), <dpi> DPI (LOGPIXELSX,
  <p> % scaling), game window <w> x <h>`, on every run; S-WP8, done), the link check in `admin` mode
  (one line per finding, then `Link check: <n> folders and <m> files below Data and Users of <app>
  examined in <ms> ms, <k> links or unreadable folders or files found, <f> files with a reparse point
  (allowed)`; in user
  and portable mode `Link check skipped: not the administrative install mode`; S-WP11, done), the manifest (S-WP7: the number of recorded destinations, every hashing
  attempt that failed with its exception, every installed file that is missing, a path refused or
  not ASCII, `Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s`, why no manifest was written), the
  install state: the first line with product, versions, install type and mode, `SetupBuild`,
  `TestID` and contract version, the deletion and the writing of `install.ini` and `files.sha256`
  with the cause of a failure (read-only, held open), whether the contract version went into the
  uninstall key and why not (S-WP6, S-WP7).
- Inno Setup starts logging only after the elevation, in the elevated process: with
  over-the-shoulder elevation the log is in the `%TEMP%` of the administrator account that
  elevated, not in the one of the standard user who started the setup. It contains paths with
  user names; README "Support" says where to find the log in both cases and to check it for user
  names before posting it publicly (test case TP-30).
- **Never logged:** CD keys and anything below `Software\Sierra\CDKeys` (the setup does not read
  it), the anonymous telemetry id (the query of telemetry requests is cut from the log),
  credentials of any kind.
- The uninstaller keeps Inno Setup's default (no log unless `/LOG`).

## 7. Localization

- All own texts are `[CustomMessages]` in `messages.iss`; Inno Setup's own texts come from the
  `.isl` files of `[Languages]`.
- New texts: English, German and French in the same commit as the code (R17). Other languages fall
  back to English; `check_messages.py --coverage` lists them and `TRANSLATING.md` asks native
  speakers. No machine translation (in particular not for `pt_BR` and Chinese).
- The download page (S-WP3) uses Inno Setup's own messages (`DownloadingLabel`,
  `ButtonStopDownload`, `StopDownload`, `ErrorDownload*`), translated in every official 6.2.2
  language file and in the unofficial Chinese files; the unofficial Korean file predates them, so
  Korean shows these few texts in English (listed in `TRANSLATING.md`).
- Placeholders (`%1`, `%n`, `{#...}`) are documented above each message.

## 8. Testing strategy

| Level | What | Where | Command |
|---|---|---|---|
| Unit | Pure `[Code]` helpers (`utils.iss`): strings, URLs, download policy, `NextDownloadAction`, compatibility flags, legacy compatibility values, the Windows versions of their cleanup and its exception for `compatibility_legacy`, the install mode name, the text of `install.ini`, `IsAsciiText` and the rule of the contract version value (S-WP6), manifest path (outside, `..`, `:` refused), exclusions, manifest lines, ordinal comparison, merge sort with 2000 paths in mixed case and duplicates, `[MissingAfterInstall]`, the list of the notice, the log line (S-WP7), the clamp of the game window (equal to the old inline code for every size from -10 to 4000), the low-screen predicate and the screen log line, folder normalization, `IsSameOrInside` (`C:\Sierra2` is not inside `C:\Sierra`), the "Installed From" folder, the regedit names of HKLM keys, the uninstall entry rule (community AppIds and publishers, Empire Earth II/III) and the finding list (S-WP8), which folders the link check examines (`IsLinkGuardedFolder`: `Data`, `Users` and below, not `Data2`, `redist`, `..`; S-WP11), the number of names of a file (`GetFileLinkCount`) and the walk with hard links (`CreateHardLinkW`, also under Wine), the redirect statuses and the target of a `Location` header for the check before a download without pin (`IsRedirectStatus`, `ResolveRedirectUrl`), the state of a file server, the order of the servers and the transport per file and server in every combination, the size limit of a pinned download, the size field of the pins, the URL split for WinHTTP, its error texts and proxy mode (S-WP12) | `ci/tests/unit_tests.iss` (tiny setup, no network) | `ci/run_unit_tests.ps1`; Linux: `ISCC=... sh ci/tests/run_unit_tests.sh` |
| Unit (file) | Writing `install.ini` with `ReplaceStateFile` in `{tmp}` (bytes: no BOM, ASCII, CRLF; over an existing file and a leftover `.tmp`; `RenameFile` fails over an existing file and works after deleting it; a non-ASCII text, a read-only target and a folder of that name leave the old state and no `.tmp`; S-WP6) and the manifest with `install.ini` for files the test creates, one of them deleted (no BOM, only LF, order, hashes equal to `GetSHA256OfFile`, each file once, no `.tmp`, `[MissingAfterInstall]`), a verified online file next to a hidden one, a file held open without sharing (two retries of 300 ms, no manifest), a path that is not ASCII, an incomplete recording, nothing recorded (S-WP7); the walk of the link check over a tree in `{tmp}` (folders examined, hidden ones too, none found, a missing game folder; S-WP11) | `ci/tests/unit_tests.iss` | as above |
| Unit (run time) | Setting the TLS protocol option on a `WinHttpRequest` object without a request (proves the run-time call, not only its compilation); opening WinHTTP handles for `127.0.0.1:9` and setting the option that ignores certificate errors on them without connecting (S-WP12); on Windows only, junctions made with `cmd /c mklink /J` in `{tmp}`: found, not entered, the target unchanged, also a junction whose target is gone (S-WP11; Wine cannot make junctions, there it is a `SKIP` line and the result line says `<n> tests, <s> skipped`) | `ci/tests/unit_tests.iss` | as above |
| Build | All four variants compile against placeholder assets, output names prove the variant | `ci/build.ps1 -Placeholders`; locally `verify_setup.sh` | CI workflow |
| Messages and sources | Duplicates, `==` typos, unknown prefixes, undefined messages in every own script (root and `ci/tests` `*.iss` plus the `#include` lines, so a new module counts from its first commit), order; coverage report; UTF-8 BOM, valid UTF-8 and CRLF of every own `.iss`; a missing included file | `ci/check_messages.py`; `--self-test` runs it against modified copies that must fail (S-WP2) | CI workflow (both) |
| Contract | The tables of `docs/CONTRACT.md` match `ContractVersion`, the publishers (`MyAppPublisher`, `CommunityPublisherEE/NeoEE`), `CodeFileExtensions`, the install record values (1.1), the game settings values (`GameSettings`), the window size limits and the wide-screen limit, the GPU preference entries and the compatibility entries, for all four build variants; `[Files]` flags and `AfterInstall: RecordInstalledFile` below `{app}`; the verified online files of `[Files]` and of `RecordVerifiedOnlineFiles` | `ci/check_contract.py` (S-WP5); `--self-test` against modified copies (one changed value per rule); `--preprocessed` against the scripts ISCC preprocessed | CI workflow (all three) |
| Contract copies | Both copies of `docs/CONTRACT.md` are identical (O12) | `ci/compare_contract.py <launcher clone>` (S-WP1), README "Verify" | local, every package that touches the contract, in both directions (`--repo`); its `--self-test` in the CI workflow |
| Test plan | Unique TP ids, valid status, priority (`P1` to `P3`, S-WP5) and template fields per case, the short run (exactly the `P1` cases, at most 180 minutes, S-WP9), forum test cases 1 to 22 assigned, TP ids named in the README, this document, the ADRs and the other Markdown files exist | `ci/check_test_plan.py`; `--self-test` runs it against modified copies that must fail (S-WP2; a missing priority and `P4`, S-WP5; the short run, S-WP9) | CI workflow (both) |
| dgVoodoo | `pins/dgvoodoo.txt` (format, the version of `DgVoodooVersion`), the dgVoodoo entries of `GameAddOnFiles` in both game folders, the bytes and window keys of the five configurations in `config/dgVoodoo` (fake fullscreen, Alt+Enter off, no deferred screen mode switch, `Version` of the pinned dgVoodoo), the files of `data\` against the pins in a build (ADR 0005, amendment 2026-10-07) | `ci/dgvoodoo_pins.ps1` (47 changed copies in `-SelfTest`), `ci/build.ps1`, `ci/tests/build_helpers.tests.ps1` | CI workflow |
| Build helpers | Hash lists, DER certificate copy, SHA-256 files of the setups, the build identifier `SetupBuild` (rules, refused values, a Git checkout, the dry runs of a test build, a release build, CI and `-SetupBuild`) and its record next to every setup (format, the hash it is bound to, refused records), the online files a setup can download (from the real `setup_is6.iss` and from changed copies that must be listed or refused) and which of them have no pin; reading, writing and checking `pins/online-files.txt` (every rule of its format, the real list pins exactly the online files of both products, the comparison with the hash list of a build) and the checks of the pins in the dry runs (S-WP12) | `ci/tests/build_helpers.tests.ps1` | CI workflow, PowerShell 7 on Linux |
| Run-time probes (maintainers, local only) | The glue code of the modules, which the unit test setup does not include (it only includes `utils.iss`): `CheckForeignInstallations`, `CheckSelectedFolder` and `CheckGameFoldersForLinks` (`environment.iss`), `DeleteInstallState`, `WriteInstallState` and `RemoveLegacyVistaCompatValues` (`installstate.iss`, `setup_is6.iss`), `DownloadOnlineFiles` with `CheckOnlineFileRedirects`, the server states and `DownloadPinnedFileWinHttp` (`downloads.iss`; S-WP12: loopback servers with a certificate for the wrong host name, six scenarios, ADR 0012): small probe setups with the real modules under Wine, without network or against loopback servers in a network namespace without any other interface, with test keys, folders and links made for the probe (results in the ADRs, "Implementation") | not in the repository: they run setups, which CI and the agents must not do with the real ones, and they need a Wine prefix prepared for them; since [ADR 0011](adr/0011-real-data-end-to-end-test-in-ci.md) the end-to-end test of the next row runs this code on Windows with the real setups (not the paths it cannot reach without a human or a second machine, see TEST-PLAN section 12); a regression there shows in that test, in a probe or in the Windows cases (TP-1x, TP-21, TP-40, TP-50, TP-61 to TP-63, TP-80) | after every package that changes this code |
| Real-data equivalence (maintainers, local only) | Build EE and NeoEE with the reconstructed official data, dump with innoextract and compare semantically with the previous build and the official 1.7.2 setups: only the changes of the package may differ | not in the repository (game data must never be committed) | after every package that changes the compiled setup |
| End-to-end (CI, real data) | The real-data setups EE and NeoEE (Regular, real AppIds) built on a GitHub-hosted Windows runner from the official setups 1.7.2 (cached unchanged, SHA-256 checked, extracted with innoextract 1.10-dev, placed with the data-free map `ci/e2e/assets-map.tsv`; a source the preprocessed scripts read that the map does not name fails the job), then installed, checked and uninstalled in five scenarios: A EE for all users in German with the downloads from the mirror, B NeoEE for the current user with a junction in `Data`, E a custom folder next to traces of a foreign installation, D the link guard (junction, hard link: exit code 7, nothing changed) and an update, C the official setup 1.7.2, v2 over it and back, damage, repair. Checks per installation: the contract (K1 to K15: install record, `install.ini`, uninstall key, manifest hashed again, game settings, GPU preference, marker, compatibility values, firewall rules, shortcuts, permissions, the setup log), the downloads and pins (DL), the uninstallation (U), the launcher core of the launcher fork (`RealMachineTests`) against each state. The hosts file blocks every server (`api.empireearth.eu` first) before any setup runs; telemetry, CD key, certificate, DirectPlay and DirectX tasks are refused by the scripts; a dummy value under `Software\Sierra\CDKeys` must survive. Game data stays in the job folder: only the official setups and innoextract are cached, only a report folder of small text files passes the upload guard | `.github/workflows/e2e-realdata.yml`, `ci/e2e/` ([ADR 0011](adr/0011-real-data-end-to-end-test-in-ci.md), README "End-to-end test on Windows"); the self-tests of its pure helpers and tools (`ci/e2e/tests`) | workflow by hand only (`workflow_dispatch`; `r2.empireearth.eu` answers GitHub runners with HTTP 403, so a check on pull requests would be always red; ADR 0011, amendment 2026-10-07; the repository requires approval of workflow runs for all external contributors), the launcher checks from a pinned commit on the launcher's `main`; the self-tests in the CI workflow |
| Manual | Installation, update, repair, uninstall on real Windows; every case has a TP id (`TP-00` server pre-check, then one block per package: `TP-1x` downloads ... `TP-6x` environment, `TP-7x` general and forum cases, `TP-8x` links in the folders all users can write to, `TP-9x` the suite installer on the laptop), the build type (A: placeholder build `ci\build.ps1 -Placeholders -TestID 1`, only in a VM or on a snapshot, with the real `EEStatsSetup.dll`; A+: the same with the official AppIds read from the tester's own installation, only in a VM or Windows Sandbox where the official setup 1.7.2 was installed first, for the update cases without game data (S-WP9, done); B: real build from the tester's own data with the official AppIds, `-TestID 1`), a priority (P1 = the short run before every release, P2, P3 = optional, e.g. Windows 7 or retail only; S-WP5 added the field), the starting state and the snapshot to use; the forum test cases 1 to 22 are each mapped to a case or excluded with a reason. The short run (S-WP9, done) combines the P1 parts of the P1 cases into ten steps on the laptop and in Windows Sandbox, about 155 minutes with ways A and A+ and 170 with the way B step; a state is released when every P1 case with all its P1 parts passed or is excepted with a reason | `docs/TEST-PLAN.de.md` (German; skeleton, safety rules, "Testbuild herstellen", `TP-00` and `TP-70` in S-WP2; each package worked out the cases of its block, S-WP9 completed it: all 33 cases worked out; Block 9 adds TP-90 to TP-97 for the suite installer, 41 cases in all) | tester |

Agents and developers never run an installer (they contact live servers and send statistics); the
only place the real setups run is the throwaway GitHub-hosted runner of the end-to-end test, with
every server blocked, the telemetry, CD key and certificate tasks refused and no game data leaving
the job (ADR 0011). Runtime behaviour is covered by the unit tests as far as possible, then by that
test, and what needs a human, a GPU, Windows 7 or a game start by the manual test plan (its
section 12 lists which cases the end-to-end test covers).

## 9. Security notes

- The setup runs elevated in `admin` mode. It never follows reparse points when it deletes
  (random maps), deletes `[InstallDelete]` paths only below `{app}` with a checked AppId, and only
  installs downloads from `{tmp}\verified`.
- Download policy ([ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md),
  [ADR 0006](adr/0006-strict-tls-and-server-certificates.md),
  [ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md)): every online file is
  pinned (`pins/online-files.txt`); a pinned file may come from a server with an invalid
  certificate (WinHTTP, certificate errors ignored, kept only if size and SHA-256 match); code only
  with pin; unpinned data (test builds) only over HTTPS with a validated certificate;
  `ci/check_tls_policy.py` keeps the one place that ignores certificate errors where it is. What the servers must provide for that (certificate and chain, TLS 1.2
  for Windows 7 clients, `Content-Length`, no redirect to `http://`, identical files on both
  servers) and how to check it: [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md).
- Environment checks are read-only and never offer to delete foreign installations
  ([ADR 0007](adr/0007-environment-warnings.md)).
- **Links in the folders all users can write to** (`admin` mode grants `authusers-modify` on `Data`
  and `Users`): before an elevated installation (`PrepareToInstall`, before anything is changed) the
  setup refuses to run if `Data`, `Users` or any folder below them in either game folder is a
  junction or symbolic link, or cannot be listed, so that it does not write through it, and if a
  file there has more than one name (a hard link, which needs no privilege on Windows 7 and 8.1 and
  through which the external permission entries below would copy a file from outside into one every
  user can read), or its number of names cannot be read
  ([ADR 0009](adr/0009-no-installation-through-links.md), S-WP11, done). The folders of the players
  below `Users` are included: the external `[Files]` entries that set the permissions of `*.cfg`,
  `*.config`, `*.conf` and `*.ini` copy such files in every folder that is not hidden onto
  themselves and give every user modify rights on them, and Inno Setup 6.2.2 follows links there.
  Residual risks: a link created between the check and the writes (a race); the uninstaller, which
  deletes the recorded files also through a link created later; a symbolic link to a file (needs the
  symbolic link privilege; the setup replaces such a file); a user or portable setup run as administrator,
  and an installation folder the administrator chose where all users can write. The complete fix
  would be RedirectionGuard of Inno Setup 6.7 for Windows 10 22H2 and 11
  ([ADR 0002](adr/0002-stay-on-inno-setup-6.2.2.md), security assessment).
- **Redirects:** the built-in downloads follow a redirect from `https://` to `http://` (Wine probe
  of S-WP5: `301`, `302`, `307` and `308`; the redirect is handled by the Delphi HTTP client in
  `Setup.e32`, which switches WinHTTP's own redirect handling off, so it applies on Windows too;
  [ADR 0008](adr/0008-release-checksums-and-contract-check.md), "Implementation"). So before a file
  without pin is requested, `CheckOnlineFileRedirects` (`downloads.iss`) asks its URL with `HEAD`
  requests of `HttpRequest` (`utils.iss`) with `WinHttpRequestOption_EnableRedirects` off and
  follows at most five redirects itself, each of which must lead to `https://`
  (`ResolveRedirectUrl`); anything else, and no answer, refuses the file on that server (security
  review of v2). Under Wine 9.0 the option is ignored and WinHTTP follows the redirects itself,
  refusing one from `https://` to `http://` with an error, which the check treats as no answer: the
  same result. Left open: a server that answers `HEAD` and `GET` differently or changes its answer
  between the check and the download; the log keeps calling such a file "TLS-verified".
  Mitigations for that: the operator rules "no redirect to `http://`" and "answer `HEAD` like
  `GET`" (requirement 4 and check 3.4 of [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md)), and since
  S-WP12 pins for every online file (`pins/online-files.txt`, section 6 there; a release build
  stops without them), so in a release no file depends on that check any more.
- **The uninstaller of the suite and the user data** ([ADR 0013](adr/0013-suite-installer.md), decision 11 and the
  amendment of 2026-10-08): after the answer "Löschen" it deletes fixed folders below the install roots and the
  launcher's data folder with `DelTree`. `DelTree` of Inno Setup 6.2.2 checks only the folder it is given, and each
  folder inside, for a link; Windows follows a link in a folder above, and `Data\dxm` above the target
  `Data\dxm\mods` lies in the part every user may write to. So the suite checks each folder up to its root for links
  before its question and again right before each `DelTree`, the check fails closed (a folder whose entry cannot be
  read counts as a link), and `RemoveDir` removes an empty folder only if it is no link and not behind one. Residual
  risk: a link created between that second check and the end of the `DelTree` (a moment, no longer the time the
  question waits); as for the product setups, the complete fix would be RedirectionGuard of Inno Setup 6.7.

## 10. Open points

- **Contract O2, O6, O8, O9** are launcher or project questions; the setup is not affected.
- **O10** (launcher in the setup): answered by contract revision 4. The product setups do not install the
  launcher; the suite does, outside every product root ([11](#11-suite-empire-earth-community)).
- **O3** (BOM of `SaveStringsToUTF8File`): answered from the 6.2.2 source, it writes a BOM and CRLF.
  `UTF8Encode` does not exist in 6.2.2's Pascal Script (probe compile), so the setup builds the
  manifest and `install.ini` as ASCII, checks that (`IsAsciiText`) and writes them with
  `SaveStringToFile` (no BOM, LF resp. CRLF); a non-ASCII path switches the manifest off instead of
  corrupting it, see [ADR 0004](adr/0004-install-record-and-integrity-manifest.md). Contract 1.2, 2.2
  and O3 say so since the contract revision (S-WP1).
- **O4** (physical pixels): Setup 6.2.2 declares itself system-DPI-aware (`<dpiAware>true</dpiAware>`
  in the manifest of `Setup.e32`), so `GetSystemMetrics` returns physical pixels of the primary
  screen at the logon DPI; a changed scaling without signing out again is the known exception. To be
  confirmed on Windows at 150 % (test plan TP-24), twice: with the task `compatibility` (the game
  is `HIGHDPIAWARE`) and without it (the game is DPI-virtualized and sees logical pixels), plus
  Windows 7, which gets `HIGHDPIAWARE` only with the opt-in task `compatibility_legacy`
  ([ADR 0010](adr/0010-opt-in-compatibility-on-windows-7.md)). If the window only fits with
  `HIGHDPIAWARE`, contract 3.3 says so. Since S-WP8 every setup log has the line `Screen: <w> x <h>
  pixels ..., <dpi> DPI (LOGPIXELSX, <p> % scaling), game window <w> x <h>`, so a report can be
  decided from the log (TP-24, TP-60).
- **O7** (defaults under review): decided in [ADR 0005](adr/0005-compatibility-and-wrapper-defaults.md);
  the contract revision (S-WP1) changed 3.7 in both repositories (a table of the values per task,
  Windows version and root, which `ci/check_contract.py` reads), S-WP4 implemented it (test cases
  TP-20 to TP-24; the wrapper preselection stays until the graphics matrix TP-23 shows a better
  default by the rule fixed in [ADR 0010](adr/0010-opt-in-compatibility-on-windows-7.md), which also
  adds the opt-in task on Windows 7 with contract revision 2, S-WP10, done).
- **O11** (EE and NeoEE in one folder): the setup asks (S-WP8, done: `SharedFolderQuestion`, found by
  the other product's setup data folder, its `<AppId>` folder of setups up to 1.7.2 or its uninstall
  key; TP-62). Contract O11 names all three triggers since contract revision 3, a step in both
  repositories without a change of the code.
- **authtools.dll and `HKLM\Software\Neo`** (S-WP8): the community NeoEE setup writes its game keys
  only in HKCU, so an HKLM `Neo` key is reported as an old NeoEE installation. Whether the closed
  `authtools.dll` writes such a key when it registers the CD keys is unknown (contract O8); TP-61 (e)
  checks it before a release, a hit needs an exception in the check.
- **O12** (copy check): answered locally, `ci/compare_contract.py` (S-WP1).
- **Setup version:** `MySetupVersion` stays `1.7.2` until the maintainers release v2; the update API
  may treat an unknown version as outdated, so the version is raised together with the release and
  the API, not by a work package. Test builds are told apart by `SetupBuild` (S-WP6, done:
  `test<TestID>-<commit>` in `install.ini`, the install record and the first log line).
- **Mirror certificate:** unknown from the analysis environment. A release needs at least one file
  server with a valid certificate ([ADR 0006](adr/0006-strict-tls-and-server-certificates.md),
  release criterion in [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md)); the test plan checks both
  servers first (TP-00).
- **TLS 1.2 on Windows 7** without KB3140245: a hypothesis, tested in a Windows 7 VM (TP-17,
  [ADR 0006](adr/0006-strict-tls-and-server-certificates.md)). The README (Support) names the
  update for players on whose system it fails; the setup never changes SChannel or WinHTTP
  settings.
- **Timeouts of the downloads** cannot be set from Pascal Script in Inno Setup 6.2.2; the short
  reachability check before the downloads covers a server that is down, a server that accepts
  connections and then stalls costs Inno Setup's own timeout once per file
  ([ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md)).

## 11. Suite "Empire Earth Community"

Decided in [ADR 0013](adr/0013-suite-installer.md), specified for the launcher in contract revision 4
([CONTRACT.md](CONTRACT.md): 0 "Suite and launcher", 1.6, 1.7, 4.2, 4.4). Implemented (done): the suite is a
separate, small Inno Setup 6.2.2 script in `suite/`; the four variants of sections 2 and 3 do not change for
it. The CI scenarios S1 to S15 (job `suite-e2e`, placeholder data, silent, no download) are done too. The
Windows tests with real data are the cases TP-90 to TP-99 of the test plan (Block 9); the suite and launcher
1.0.0 are tagged only after TP-93 and TP-95 pass, the suite 1.1.0 only after TP-93, TP-94 (c), TP-95, TP-97, TP-98, TP-99 (all variants),
TP-25 (a) to (d) and TP-27 (a) pass and the job `suite-e2e` (S1 to S14) was green on windows-latest. Suite 1.1.0 was released
on 2026-10-07 as an exception, after session 1 of the laptop test only; TP-93, TP-95, TP-97, TP-98 (b) to (d), TP-99 and
TP-25 (d) were not run on real hardware. The CI scenarios exercise the paths of TP-93, TP-95, TP-97 and TP-99 (silent, English);
nothing covers TP-98 (b) to (d) or TP-25 (d) (test plan, section 8 Block 9).

- **Package:** `Empire Earth Community Setup.exe` plus `.bin` slices of at most 50,000,000 bytes
  (`DiskSpanning`). It embeds the EE and NeoEE Regular setups byte for byte (official AppIds; SHA-256
  and size fixed at build time and checked before they run), the launcher and the Mod Creator.
- **Run:** one elevated run (`PrivilegesRequired=admin`, 64-bit install mode, Windows 7 SP1 and
  later). Prechecks before anything is extracted (all slices present, not started from the ZIP view,
  free space, mutexes). At `CurStepChanged(ssInstall)` the suite runs the selected product setups, EE
  before NeoEE, silently with `/NOICONS /MERGETASKS="!desktopicon"` and a log per product in
  `{app}\Logs`; a repair passes neither `/TYPE` nor `/DIR`. The suite itself shows the legal question,
  the EULA and the NeoEE rules, because the silent product setups skip them. A product installed for
  one user only is skipped with a message.
- **After each product:** success = exit code 0 and the uninstall key in HKLM64; the old shortcuts of
  standalone runs of that product are deleted (contract 1.7 point 7) before the suite creates its
  shortcut `Empire Earth Community` (desktop and start menu folder `Empire Earth Community`, next to the Mod Creator
  and the uninstaller; it starts the launcher without a product, so the launcher opens with the game chosen last;
  without .NET Framework 4.8 it starts the game program of NeoEE, else EE). Every run first deletes the seven
  shortcuts of suite 1.0.0 (`SuiteRemoveOldSuiteShortcuts`, contract 1.7 point 8). The shortcuts and
  the record below are created in code at `ssPostInstall` and removed by the uninstaller (ADR 0013,
  Evidence: the `Check` functions of `[Icons]` and `[Registry]` did not reliably see the results of
  `ssInstall`). For NeoEE the suite
  reads the line `CD Keys generation result: <n>` of the product log and shows it; the CD-key
  registration stays the NeoEE setup's own (D6).
- **Progress of a product setup:** the data source for the progress display of suite 1.1.0 is the log of the
  running product setup, which the suite reads without disturbing it (`SuiteTailLog` in `suite_common.iss`:
  the file is opened for reading with `fmShareDenyNone` at every look, because `LoadStringFromFile` fails
  with a sharing violation while the product setup writes; bytes come in through `ReadFile`, because
  `TStream.Read` does not fill an `AnsiString`; no file yet, a smaller file, a line cut in the middle, the
  UTF-8 byte order mark and the 26 blanks of a continuation line are handled). `SuiteFeedLogLine` is pure:
  the log lines of contract 1.7 point 5 (`SuiteLog*`) move a phase forward (start, online files servers,
  download, verify, install, post install, CD keys, manifest, done) and set counters (files downloaded of
  N, the file being downloaded and its bytes, entries `Dest filename:` against an estimate per product);
  `SuiteProgressPermille` weights the blocks (3, 65, 2, 20, 10 percent; the download weight drops out for a
  run without download; 100 percent only at "Log closed."). The line `Install step: the game folder is changed from here on`, the
  first statement of `CurStepChanged(ssInstall)` of the product script, is the
  point of no return (`SuiteProgressInstalling`; Inno Setup's later line `Starting the installation process.` only backs it up). Success is never decided from the log: exit code and
  uninstall entry stay authoritative (`SuiteRunSucceeded`). `ci/check_suite.py` checks that the product
  scripts still write the lines, each marked with the comment "suite parses this line".
- **A product setup as a process (suite 1.1.0, ADR 0013, amendment):** `SuiteStartProduct` (`suite_common.iss`)
  starts it with `CreateProcessW` like `Exec` (and keeps the handle that `Exec` hides), suspended, puts it into a
  job object without limits and resumes it: the setup program is only the loader of the real setup (a `.tmp` file in
  `%TEMP%`), so only the job stops both (`SuiteKillProduct`, the one place that stops a program). `SuiteWaitForProduct`
  (`suite_run.iss`) waits in slices of 50 ms and handles the messages of Setup (`PeekMessageW`,
  `DispatchMessageW`), reads the product log every 500 ms and logs each phase change; `CancelButtonClick` asks
  before the line `Install step: ...` of the product script (a Yes stops the job after one more look at the log, no further
  product, then `Abort` with exit code 3 if no product succeeded in the run, else the suite finishes its launcher, shortcuts
  and record for the products that did), and after it the button is off; no new log line for 10 minutes asks once (after
  "stop" `SuiteStallStopWanted` looks at the process and the log again), 90 minutes stop the product setup before the
  install step only (`SuiteChildTimeout`, then the next product; during it the cap is only logged); the advanced mode has
  no limits.
  The pure parts are `SuiteTimeoutCheck`, `SuiteCancelMode`, `SuiteChildKind`, `SuiteTicksBetween`; the process
  mechanics are tested on real programs in `ci/tests/suite_tests.iss`; `ci/check_suite.py` (part [Process]) fixes who
  may start and stop a program. The CI parameter `/TestCancel` and the scenario S11 cancel a silent run.
  **The race of Cancel (ADR 0013, amendment of run 5f):** every stop of a product setup before its install step (Yes,
  the stall question, the cap) goes through `SuiteStopBeforeInstall`: `SuiteFreezeJob` suspends every process of the job
  (`QueryInformationJobObject`, `IsProcessInJob`, `NtSuspendProcess`, repeated until the job holds no process that is not
  frozen), `SuiteTailLogToEnd` reads the log to its end including the last line without a line end, and the pure
  `SuiteStopDecision` says stop, too late, unclear or (after the stop, when the log shows the line now) incomplete;
  whatever is not certain is left running (`SuiteResumeFrozen` in a `finally`). A process that Windows no longer suspends
  because it is ending (`STATUS_PROCESS_IS_TERMINATING`, `SuiteSuspendFailureIsEnd`) counts as ended; any other refused
  suspension fails the freeze and is logged with its NTSTATUS (`SuiteNtStatusText`). The freeze counts only if the loader
  has ended (or is ending) or is among the frozen processes, and a stop counts only when `SuiteStopProduct` confirmed it
  (the order taken, the setup gone); an unclear confirmed cancel stays requested for `SuiteCancelTriesMax` decisions and
  then gets the text `SuiteCancelRetry`, never `SuiteCancelNotNow`. `/TestCancelAtInstall` and the placeholder pauses
  around the install step (`PlaceholderInstallPause`, `ci/build.ps1 -Placeholders` only) test the boundary in scenario S14.
- **The progress in the window (suite 1.1.0, ADR 0013, amendment):** every look at the product log ends in
  `SuiteShowProgress` (`suite_run.iss`), which sets the status line (`SuiteStatusText`, one of seven texts by
  `SuiteStatusKind`), the file line (`SuiteFileText`, sizes by `SuiteBytesTexts`), the bar (1000 steps for the
  whole run, `SuiteOverallPermille` of `SuiteRunningPermille`, at most 990 per mille of a share while the product
  setup runs; the end of the share only in `SuiteEndProductDisplay` once the exit code is known) and the list of
  the finished steps (a `TNewCheckListBox` made in `suite_pages.iss`, `SuiteShowStages`, each step once by
  `SuiteStageReached`), each only when its text changed. The cancel reason has its own line below the bar. The last
  page adds the language line of each installed product (`SuiteLangLine`). The display only reads: a failure is a
  log line (`SuiteProgressBroken`), success stays `SuiteRunSucceeded`. The formatting and the arithmetic are pure
  functions in `suite_common.iss` with unit tests; `ci/check_suite.py` part [Display] fixes the rules; the layout is
  checked by TP-98 only.
- **Record and mutexes:** the suite record `HKLM64\Software\Empire Earth Community\Suite` (contract
  1.6) lists the products that succeeded and the folder the package was started from (`SourceDir`), for
  the launcher's repair advice. `SetupMutex=EmpireEarthCommunity_Suite`; `AppMutex` holds the game
  mutexes and the launcher's `EmpireEarthCommunityLauncher`. The suite's own uninstall key has the
  `Publisher` of EE (`Empire Earth Community`, which "Apps" shows and the product setups rely on, ADR
  0007), so the suite marks it with the value `Empire Earth Community: Suite` = 1 (contract 1.3,
  revision 5), written in code at `ssPostInstall` after the record, in every run, only if the key
  exists; the launcher skips a marked key (ADR 0013, amendment of 2026-10-06).
- **Uninstall:** one entry in Windows "Apps" for the package (`suite_uninstall.iss`, ADR 0013 decision
  11). One question lists what goes; the uninstallers of the products it lists run one after the other and
  the suite waits until their uninstall keys and program files are gone (10 minutes at most; the exit
  code of the first process decides nothing), then it removes the launcher, the shortcuts, the record and
  `{app}\Logs`. Saves, profiles and the launcher's backups stay unless the user presses "Löschen" in the
  one task dialog at the end; a silent uninstallation keeps them. The product entries stay visible for a
  single game. A data folder that is a link or lies below one is never offered; the check fails closed, a
  folder whose entry cannot be read counts as a link (`SuiteLinkVerdict`, ADR 0013, amendment of 2026-10-08).
  Each folder is checked again, up to its root, right before its `DelTree`, and an empty folder is removed only
  if it is no link and not behind one (section 9). The CI scenario S15 runs the deletion on the placeholder installation:
  a silent uninstallation never deletes, so the placeholder suite (and only it: `Get-SuitePlaceholderHookDefine`,
  `suite\build_suite.ps1 -Placeholders`, refused by `suite.iss` with real AppIds) has a test hook, the switch
  `/TestDeleteUserData` of its uninstaller, that gives the answer "Löschen".
- **Files:** `suite/suite.iss` (`[Setup]`, payload, prechecks with the exit codes 10 to 15),
  `suite_common.iss` (pure helpers, tested by `ci/tests/suite_tests.iss`), `suite_messages.iss`
  (English, German, French), `suite_shortcuts.iss` and `suite_record.iss` (what the suite leaves
  besides its files: the record and the marker of its uninstall key), `suite_uninstall.iss` (its uninstaller). Build values (AppIds, the pins and sizes of the embedded setups, the slice
  count and total size of a two-pass build) are `/D` defines, listed at the top of `suite.iss`.
- **Checks:** `ci/check_contract.py` reads `suite/suite.iss` and its includes (`SetupMutex`,
  `AppMutex`, the record's value names and types written in code, the shortcut `Empire Earth Community` with the
  products of its fallback, none with `--product=` or a name of suite 1.0.0, the marker of the uninstall key, no reference to the protected keys); `ci/check_suite.py`
  checks that only the paths of suite 1.0.0 are deleted, before the new shortcut is created, and also requires `MarkSuiteUninstallKey` after `WriteSuiteRecord` and `RegKeyExists` before its write; the
  suite scenarios S1, S2, S3, S9 and S10 assert the marker; it also checks the product log lines the suite
  parses (see above); `ci/check_messages.py` checks `suite_messages.iss`
  and forbids `MsgBox` in the suite scripts (only `SuppressibleMsgBox`).

## Plan

| Order | Package | Title | Requirements | State |
|---|---|---|---|---|
| 1 | S-WP1 | Contract revision in both repositories (one step), local copy check | D5, O3, O4, O7, O11, O12 | done |
| 2 | S-WP2 | Test foundation: test plan skeleton with "Testbuild herstellen" and TP-00, source and test plan checks | R17, R18 | done |
| 3 | S-WP3 | Built-in downloads replace IDP; TLS 1.2 for HTTP requests on Windows 7; operator guide | D2, D3, R16, R17 | done |
| 4 | S-WP4 | Compatibility defaults (no values on Windows Vista/7), wrapper preselection documented | R15, O7 | done |
| 5 | S-WP5 | Build, CI and diagnostics: SHA-256 files of the setups, contract check, setup log, priorities in the test plan, redirect probe (followed) and the release warning for files without a pin | R14, D5, D3, R18 | done |
| 6 | S-WP10 | Contract revision 2 in both repositories (tables of 3.3/3.4, opt-in row of 3.7, launcher rules for a running setup in 4.2 and 2.5) and the opt-in task `compatibility_legacy` on Windows 7 | D5, R15, O4, O7, R17 | done |
| 7 | S-WP6 | Install record, `install.ini`, defaults marker, `SetupBuild`, uninstall key value | D5 (1.1, 1.2, 3.5), R1, R17 | done |
| 8 | S-WP7 | Integrity manifest and post-install file check | D5 (2), R2, R11, R17 | done |
| 9 | S-WP8 | Environment warnings: low resolution (with screen metrics in the log), foreign and old installations (incl. old NeoEE keys and foreign uninstall entries), their folders, shared folder | R12, R13, O11, R17 | done |
| 10 | S-WP11 | No elevated installation through links in the folders all users can write to | ADR 0009, R17 | done |
| 11 | S-WP9 | Documentation and completion of the German test plan (build type A+, P1 short run, decision rules in TP-23/TP-71) | R17, R18 | done |
| 12 | S-WP12 | After the first laptop test: every online file pinned (`pins/online-files.txt`), pinned files also from a server with an invalid certificate (WinHTTP), size limit, checks of the pins and of the code that ignores certificate errors | ADR 0012, D3, R16, R17 | done |

The contract comes first because the launcher implements it at the same time; every later contract
change is again one step in both repositories. The test plan skeleton comes next, so that every
package adds its Windows cases with TP ids as it goes. Then the risky toolchain change. The
compatibility change comes before the contract check, which checks the compatibility table of the
revised contract. Each package leaves all checks green, updates the CHANGELOG, the README and these
documents, and states its acceptance criteria and verification in its commit message.

Second plan review (after S-WP4 and half of S-WP5): the numbers S-WP6 to S-WP9 are kept because the
test plan blocks and the ADRs refer to them; the new packages get the next numbers and their place
in the order. Contract revision 2 (S-WP10) comes before S-WP6 and S-WP7, because it fixes the
launcher's side of the manifest replacement (2.5, 4.2) and the tables that S-WP8 refactors (3.3);
it also carries the opt-in task, whose contract row and code must land together so that
`ci/check_contract.py` stays green. The link check (S-WP11) comes after S-WP8, which creates
`environment.iss`, and before the documentation package.
