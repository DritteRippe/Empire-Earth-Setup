# Architecture of the Empire Earth Community Setup (v2)

This document describes the target architecture of setup v2: what the parts of the script are, how
data flows through an installation, how errors, logging, localization and testing work, and which
work package (S-WP1 ... S-WP11, see [Plan](#plan)) brings each change. Decisions are recorded as
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
- **Never weaken trust decisions:** HTTPS with certificate validation only, code only with a
  compile-time SHA-256 pin, no automatic elevation of the game, CD-key registration through
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
| `setup_is6.iss` | Build switches and their checks, `[Setup]`, `[Languages]`, `[Types]`, `[Tasks]`, `[Components]`, `[Files]`, `[Dirs]`, `[Registry]`, `[Icons]`, `[InstallDelete]`, `[UninstallDelete]`, `[Run]`, `[UninstallRun]`; the event functions (`InitializeSetup`, `InitializeWizard`, `NextButtonClick`, `CurStepChanged`, ...) only dispatch to the modules | - | download wiring (S-WP3, done), compatibility tasks from Windows 8 on, no Vista/7 entries, `RemoveLegacyVistaCompatValues` (S-WP4, done), `SetupLogging` and `ContractVersion` define (S-WP5, done), opt-in task `compatibility_legacy` on Windows 7 (`OnlyBelowVersion`, entries `CompatibilityValuesWin7`, `GetCompatibilityFlags` passes `compatibility or compatibility_legacy`) and the cleanup that keeps its values (S-WP10, done), install record and defaults marker (`[Registry]`, Regular only), the build switch `SetupBuild` with its ISPP check, the first log line, `DeleteInstallState` first at `ssInstall` and `WriteInstallState` last at `ssPostInstall` (S-WP6, done), `AfterInstall: RecordInstalledFile` on every compiled file entry below `{app}` except the setup data folder and `deleteafterinstall` files, `CreateManifestProgressPage` in `InitializeWizard` (S-WP7, done), `PrepareToInstall`: no elevated installation through links (S-WP11) |
| `config_ee.iss`, `config_neoee.iss` | Product configuration | - | - |
| `utils.iss` | URL constants, string helpers, language tag, compatibility flags, uninstall keys, the single HTTP implementation (`HttpGet`), URL allow-list of the update API, download policy (`GetOnlineFileCheck`, `CodeFileExtensions`) | yes, all functions without wizard access | TLS 1.2 for `HttpGet` on Windows 7 (`NeedsExplicitTlsProtocols`, `ApplyTlsProtocols`), `NextDownloadAction` (S-WP3, done); `IsLegacyVistaCompatValue`, `IsBelowWindows8` (S-WP4, done); `ShouldRemoveLegacyVistaCompatValue`, which keeps the values of `compatibility_legacy` (S-WP10, done); `InstallModeName`, `IsAsciiText`, `BuildInstallIniText`, `ShouldWriteContractVersionValue`, the file helpers `DeleteStateFile` and `ReplaceStateFile` (`.tmp`, delete, check, rename; S-WP6, done); manifest path and exclusions (`GetManifestPath`, `IsManifestExcludedPath`), `ManifestLine`, ordinal comparison and merge sort (`CompareManifestPaths`, `MergeSortManifestPaths`, `RemoveDuplicateManifestPaths`), `BuildMissingAfterInstallText`, `FormatMissingFileList`, `FormatManifestSummary`, and at file level `HashFileWithRetries`, `CollectExternalFiles`, `GetManifestPaths`, `HashManifestFiles`, `WriteInstallStateFiles` (S-WP7, done); screen size clamp, low-resolution predicate, `IsSameOrInside`, `IsForeignUninstallEntry` (S-WP8); `IsLinkGuardedFolder` (S-WP11) |
| `messages.iss` | `[CustomMessages]` in all languages, `[Messages]` overrides | `ci/check_messages.py` | new texts in en/de/fr per package |
| `eestats.iss` | Wrapper of `EEStatsSetup.dll` (Wine, GPU vendor, statistics values) | - | - |
| `extension.iss` | Command line switches, previous installation (uninstall key), Windows version | - | - |
| `pages.iss` | Custom wizard pages (game language, installation mode, graphics card) | - | - |
| `downloads.iss` | Online localized files: pins, policy application, server selection, **download engine** (built-in `TDownloadWizardPage`/`DownloadTemporaryFile`), verification into `{tmp}\verified` | policy, pins and the decision after each attempt via `utils.iss` | engine replaced (S-WP3, done) |
| `randommaps.iss` | Random map scripts: list-based cleanup, migration of 1.7.2 folders, restore on abort | - | `IsReparsePoint` moves to a shared place for the link check (S-WP11) |
| `telemetry.iss` | Setup statistics, only with consent | - | - |
| `installstate.iss` (new) | Contract writer: records installed files, deletes stale state at `ssInstall` (and remembers a deletion that failed), writes `install.ini` and `files.sha256` (ASCII; hashing with retries) at the end of `ssPostInstall`, the contract version into the uninstall key only if both files were replaced, reports files that disappeared; `GetContractInstallMode` for the install record | via `utils.iss` | new: `install.ini`, the uninstall key value, `GetContractInstallMode` (S-WP6, done); `RecordInstalledFile` (the `AfterInstall` of `[Files]`), `RecordVerifiedOnlineFiles`, `files.sha256` on an output progress page, `ReportMissingFiles` (S-WP7, done) |
| `environment.iss` (new) | Read-only checks before the installation: low screen height (screen size and DPI logged), foreign or old installations (retail/GOG/old NeoEE keys in HKLM, foreign uninstall entries), installing into their folder, EE and NeoEE in one folder; the link check before an elevated installation | via `utils.iss` | new (S-WP8; link check S-WP11) |
| `internal/lib/bass` | Setup music (third-party) | - | - |
| `internal/lib/idp` | Inno Download Plugin (third-party DLL) | - | **removed** in the last commit of S-WP3 (done) |
| `ci/build.ps1`, `ci/build_helpers.ps1` | Two-pass build of all variants, hash list of `data\localized-text`, DER copy of the certificate, SHA-256 files of the setups, the online files without a pin in a release build (`Get-OnlineFiles` reads them from the code of `RegisterOnlineFiles`), the build identifier `SetupBuild` | `ci/tests/build_helpers.tests.ps1` | SHA-256 files of the built setups (S-WP5, done), warning with the online files without a pin in a release build (S-WP5, done: the redirect probe showed that `https://` -> `http://` is followed), `/DSetupBuild`: `-SetupBuild`, else `test<TestID>-<commit>` for a test build, the short commit in CI, none otherwise (S-WP6, done) |
| `ci/check_messages.py` | Checks `messages.iss`, the use of messages in every own script and the encoding (UTF-8 BOM, CRLF) of every own `.iss`; finds the own scripts itself (root and `ci/tests` `*.iss` plus the `#include "..."` closure of `setup_is6.iss`, without `internal/`) | `--self-test` (CI workflow) | own scripts from the `#include` lines, encoding check, self-test (S-WP2, done) |
| `ci/check_contract.py` (new) | Checks that the tables of `docs/CONTRACT.md` (header, 2.4 row `code`, 3.2, 3.3, 3.4, 3.7) match the source of truth in the script (`ContractVersion`, `CodeFileExtensions`, the `[Registry]` values of the game settings keys, the compatibility entries with `BuildCompatibilityFlags`/`GetCompatibilityFlags` and the tasks); reads only tables; preprocesses `[Registry]` for every build variant with a small interpreter of the ISPP directives used there (anything else is an error); lints the `[Files]` flags below `{app}` | `--self-test` (CI workflow); `--preprocessed <folder>` compares the interpreter with the scripts ISCC preprocessed (CI workflow, after the build) | new (S-WP5, done); tables of contract 3.3 (window limits) and 3.4 (GPU preference), in 3.7 the Windows versions from `OnlyBelowVersion` ("7 only"), the marker `(opt-in)`, several tasks per flags parameter and entries that would write one value twice (S-WP10, done); `--preprocessed` takes the `SetupBuild` that ISCC got from the install record of the preprocessed script, because `ci/build.ps1` passes one in CI (S-WP6, done); the `[Files]` lint also requires `AfterInstall: RecordInstalledFile` on every compiled entry below `{app}` and forbids it on the setup data folder, `deleteafterinstall` and `external` entries (S-WP7, done) |
| `ci/compare_contract.py` (new) | Local only: compares the SHA-256 of both copies of `docs/CONTRACT.md` (contract O12); exit code 0 identical, 1 different (both hashes, first differing line), 2 file missing | `--self-test` (CI workflow) | new (S-WP1) |
| `ci/check_test_plan.py` (new) | `docs/TEST-PLAN.de.md`: unique TP ids, a valid status and the template fields per case, every forum test case 1 to 22 assigned (or "Launcher"/"entfällt" with a reason) with a "Stand" that matches its cases, every TP id named in a Markdown file of the repository exists | `--self-test` (CI workflow) | new (S-WP2, done); field `Priorität` P1/P2/P3 per case (S-WP5, done) |
| `ci/tests/unit_tests.iss` | Unit tests of the pure helpers (a tiny setup that only computes) | - | extended per package |

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
  update check -----------------------> api.empireearth.eu (HttpGet, TLS, short timeouts)
  legal question (first installation)
  test-build warning, install-mode notice, NeoEE Wine notice
  low screen height (S-WP8), screen size, DPI and clamped window logged   [read-only, notice]
InitializeWizard
  languages, download pins, telemetry state, custom pages, background, download page (S-WP3)
Wizard pages
  language -> installation mode -> (graphics card | components, tasks) -> folder -> ready
  folder page Next (S-WP8): foreign or old installations [notice];
                            folder of such an installation? [question, can stay on the page]
                            EE and NeoEE in the same folder? [question, can stay on the page]
NextButtonClick(wpReady)
  RegisterOnlineFiles: selected localized files, policy (pin / TLS only / refused), server choice
  DownloadOnlineFiles (S-WP3): one file at a time, main server then mirror  -> {tmp}\<RelDest>
                               (NextDownloadAction decides; a stop ends all requests)
PrepareToInstall (S-WP11, admin mode only)
  links in Data, Users, Users\default and below?  -> stop with a message, nothing changed yet
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

### 4.3 Uninstallation

`[UninstallDelete]` removes the setup data folder (with `install.ini`, `files.sha256`, the random
map lists and `EEStatsSetup.dll`); `uninsdeletekey` removes the install record and the defaults
marker of the uninstalling account, `uninsdeletekeyifempty` the empty parent keys; firewall rules,
compatibility values and the GPU preference as before. `Software\Sierra\CDKeys` is never touched.

## 5. Error handling

Principle: **only a failure of the core installation (files, registry of Inno Setup itself) stops
the setup.** Every optional step logs the cause, shows a localized notice (not in silent mode,
not with `/SUPPRESSMSGBOXES`) and continues with what the setup itself contains. No step deletes
or changes anything outside its own scope to recover.

| Step | Failure | Behaviour |
|---|---|---|
| Update check | no answer, invalid TLS, odd answer | no question, setup continues; a refused update URL falls back to the fixed download page |
| Environment checks (S-WP8) | registry or folder not readable | treated as "nothing found", logged; never blocks a silent installation |
| Server selection | neither server answers or presents a valid certificate | notice `OnlineFilesUnreachable` (server problem, included files installed, run again later), local files only |
| Download of one file (S-WP3) | network, TLS, HTTP status, size, pin mismatch | mirror tried once (if the policy allows it there); still failing: file reported in `DownloadIncomplete`, local version installed |
| User stops the downloads (S-WP3) | stop button | no further request (no mirror, no next file), remaining downloads skipped, installation continues, all listed in `DownloadIncomplete` |
| Verification at `ssInstall` | pin mismatch, move failed | file discarded, reported, local version installed |
| `[Files]` | file locked, disk full | Inno Setup's own retry/abort dialog (unchanged) |
| NeoEE CD keys | `authtools.dll` missing, network, VM, ... | specific `CDKeys*` message, installation completes (repair = run the setup again) |
| Link check before an elevated installation (S-WP11) | a junction or symbolic link below `Data` or `Users\default` | stop on the "Preparing to install" page with a message (remove the link or install for the current user only); silent: exit code 7, folder in the log; nothing changed |
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
  registered/refused/accepted downloads (pinned or TLS-only, with SHA-256), server fallback and its
  cause, random map moves, certificate handling, CD-key result code, manifest summary (number of
  files, size, duration, missing files), files accepted without size check (no `Content-Length`),
  the reason a download was not retried (stop, no mirror allowed), compatibility values of
  earlier setups removed or kept on Windows Vista/7 (with the value; kept as "written by this run"
  with the opt-in task `compatibility_legacy`, S-WP10), environment findings,
  screen size, DPI and clamped window size (S-WP8), the link check (folders checked, duration,
  findings; S-WP11), the manifest (S-WP7: the number of recorded destinations, every hashing
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
| Unit | Pure `[Code]` helpers (`utils.iss`): strings, URLs, download policy, `NextDownloadAction`, compatibility flags, legacy compatibility values, the Windows versions of their cleanup and its exception for `compatibility_legacy`, the install mode name, the text of `install.ini`, `IsAsciiText` and the rule of the contract version value (S-WP6), manifest path (outside, `..`, `:` refused), exclusions, manifest lines, ordinal comparison, merge sort with 2000 paths in mixed case and duplicates, `[MissingAfterInstall]`, the list of the notice, the log line (S-WP7), screen clamp, `IsSameOrInside` | `ci/tests/unit_tests.iss` (tiny setup, no network) | `ci/run_unit_tests.ps1`; Linux: `ISCC=... sh ci/tests/run_unit_tests.sh` |
| Unit (file) | Writing `install.ini` with `ReplaceStateFile` in `{tmp}` (bytes: no BOM, ASCII, CRLF; over an existing file and a leftover `.tmp`; `RenameFile` fails over an existing file and works after deleting it; a non-ASCII text, a read-only target and a folder of that name leave the old state and no `.tmp`; S-WP6) and the manifest with `install.ini` for files the test creates, one of them deleted (no BOM, only LF, order, hashes equal to `GetSHA256OfFile`, each file once, no `.tmp`, `[MissingAfterInstall]`), a verified online file next to a hidden one, a file held open without sharing (two retries of 300 ms, no manifest), a path that is not ASCII, an incomplete recording, nothing recorded (S-WP7) | `ci/tests/unit_tests.iss` | as above |
| Unit (run time) | Setting the TLS protocol option on a `WinHttpRequest` object without a request (proves the run-time call, not only its compilation) | `ci/tests/unit_tests.iss` | as above |
| Build | All four variants compile against placeholder assets, output names prove the variant | `ci/build.ps1 -Placeholders`; locally `verify_setup.sh` | CI workflow |
| Messages and sources | Duplicates, `==` typos, unknown prefixes, undefined messages in every own script (root and `ci/tests` `*.iss` plus the `#include` lines, so a new module counts from its first commit), order; coverage report; UTF-8 BOM, valid UTF-8 and CRLF of every own `.iss`; a missing included file | `ci/check_messages.py`; `--self-test` runs it against modified copies that must fail (S-WP2) | CI workflow (both) |
| Contract | The tables of `docs/CONTRACT.md` match `ContractVersion`, `CodeFileExtensions`, the game settings values (`GameSettings`), the window size limits, the GPU preference entries and the compatibility entries, for all four build variants; `[Files]` flags and `AfterInstall: RecordInstalledFile` below `{app}` | `ci/check_contract.py` (S-WP5); `--self-test` against modified copies (one changed value per rule); `--preprocessed` against the scripts ISCC preprocessed | CI workflow (all three) |
| Contract copies | Both copies of `docs/CONTRACT.md` are identical (O12) | `ci/compare_contract.py <launcher clone>` (S-WP1), README "Verify" | local, every package that touches the contract, in both directions (`--repo`); its `--self-test` in the CI workflow |
| Test plan | Unique TP ids, valid status, priority (`P1` to `P3`, S-WP5) and template fields per case, forum test cases 1 to 22 assigned, TP ids named in the README, this document, the ADRs and the other Markdown files exist | `ci/check_test_plan.py`; `--self-test` runs it against modified copies that must fail (S-WP2; a missing priority and `P4`, S-WP5) | CI workflow (both) |
| Build helpers | Hash lists, DER certificate copy, SHA-256 files of the setups, the build identifier `SetupBuild` (rules, refused values, a Git checkout, the dry runs of a test build, a release build, CI and `-SetupBuild`), the online files a setup can download (from the real `setup_is6.iss` and from changed copies that must be listed or refused) and which of them have no pin, the warning of a release build | `ci/tests/build_helpers.tests.ps1` | CI workflow, PowerShell 7 on Linux |
| Real-data equivalence (maintainers, local only) | Build EE and NeoEE with the reconstructed official data, dump with innoextract and compare semantically with the previous build and the official 1.7.2 setups: only the changes of the package may differ | not in the repository (game data must never be committed) | after every package that changes the compiled setup |
| Manual | Installation, update, repair, uninstall on real Windows; every case has a TP id (`TP-00` server pre-check, then one block per package: `TP-1x` downloads ... `TP-6x` environment, `TP-7x` general and forum cases), the build type (A: placeholder build `ci\build.ps1 -Placeholders -TestID 1`, only in a VM or on a snapshot, with the real `EEStatsSetup.dll`; A+: the same with the official AppIds read from the tester's own 1.7.2 installation, only in a VM, for the update cases without game data (S-WP9); B: real build from the tester's own data with the official AppIds, `-TestID 1`), a priority (P1 = short run of at most 3 hours on a laptop or Windows Sandbox and release-relevant, P2, P3 = optional, e.g. Windows 7 or retail only; S-WP5 adds the field, S-WP9 fixes the P1 run), the starting state and the snapshot to use; the forum test cases 1 to 22 are each mapped to a case or excluded with a reason | `docs/TEST-PLAN.de.md` (German; skeleton, safety rules, "Testbuild herstellen", `TP-00` and `TP-70` in S-WP2; each package works out the cases of its block, S-WP9 completes it) | tester |

Installers are never run in CI or by agents (they contact live servers and send statistics);
runtime behaviour is covered by the unit tests as far as possible and otherwise by the manual test
plan.

## 9. Security notes

- The setup runs elevated in `admin` mode. It never follows reparse points when it deletes
  (random maps), deletes `[InstallDelete]` paths only below `{app}` with a checked AppId, and only
  installs downloads from `{tmp}\verified`.
- Download policy ([ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md),
  [ADR 0006](adr/0006-strict-tls-and-server-certificates.md)): code only with pin; unpinned data
  only over HTTPS with a validated certificate; the remaining trust in the server operators is
  documented in the README. What the servers must provide for that (certificate and chain, TLS 1.2
  for Windows 7 clients, `Content-Length`, no redirect to `http://`, identical files on both
  servers) and how to check it: [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md).
- Environment checks are read-only and never offer to delete foreign installations
  ([ADR 0007](adr/0007-environment-warnings.md)).
- **Links in the folders all users can write to** (`admin` mode grants `authusers-modify` on `Data`
  and `Users`): before an elevated installation the setup refuses to run if a junction or symbolic
  link exists below `Data` or `Users\default`, so that it does not write through it
  ([ADR 0009](adr/0009-no-installation-through-links.md), S-WP11). Residual risk: a link created
  during the installation (a race); the complete fix would be RedirectionGuard of Inno Setup 6.7
  ([ADR 0002](adr/0002-stay-on-inno-setup-6.2.2.md), security assessment).
- **Redirects:** the built-in downloads follow a redirect from `https://` to `http://` (Wine probe
  of S-WP5: `301`, `302`, `307` and `308`; the redirect is handled by the Delphi HTTP client in
  `Setup.e32`, which switches WinHTTP's own redirect handling off, so it applies on Windows too;
  [ADR 0008](adr/0008-release-checksums-and-contract-check.md), "Implementation"). The setup cannot
  see it and logs such a file as "TLS-verified". Mitigations: the operator rule "no redirect to
  `http://`" (check 3.4 of [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md)), and pins for the files
  known at build time, which a release build of `ci/build.ps1` lists as a warning (section 6
  there; a recommendation, not a release criterion).

## 10. Open points

- **Contract O2, O6, O8, O9, O10** are launcher or project questions; the setup is not affected.
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
  `HIGHDPIAWARE`, contract 3.3 says so. From S-WP8 on the setup log shows screen size, DPI and the
  clamped window, so a report can be decided from the log.
- **O7** (defaults under review): decided in [ADR 0005](adr/0005-compatibility-and-wrapper-defaults.md);
  the contract revision (S-WP1) changed 3.7 in both repositories (a table of the values per task,
  Windows version and root, which `ci/check_contract.py` reads), S-WP4 implemented it (test cases
  TP-20 to TP-24; the wrapper preselection stays until the graphics matrix TP-23 shows a better
  default by the rule fixed in [ADR 0010](adr/0010-opt-in-compatibility-on-windows-7.md), which also
  adds the opt-in task on Windows 7 with contract revision 2, S-WP10, done).
- **O11** (EE and NeoEE in one folder): the setup asks (S-WP8).
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
| 9 | S-WP8 | Environment warnings: low resolution (with screen metrics in the log), foreign and old installations (incl. old NeoEE keys and foreign uninstall entries), their folders, shared folder | R12, R13, O11, R17 | planned |
| 10 | S-WP11 | No elevated installation through links in the folders all users can write to | ADR 0009, R17 | planned |
| 11 | S-WP9 | Documentation and completion of the German test plan (build type A+, P1 short run, decision rules in TP-23/TP-71) | R17, R18 | planned |

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
