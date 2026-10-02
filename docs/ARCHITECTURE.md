# Architecture of the Empire Earth Community Setup (v2)

This document describes the target architecture of setup v2: what the parts of the script are, how
data flows through an installation, how errors, logging, localization and testing work, and which
work package (S-WP1 ... S-WP9, see [Plan](#plan)) brings each change. Decisions are recorded as
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
| `setup_is6.iss` | Build switches and their checks, `[Setup]`, `[Languages]`, `[Types]`, `[Tasks]`, `[Components]`, `[Files]`, `[Dirs]`, `[Registry]`, `[Icons]`, `[InstallDelete]`, `[UninstallDelete]`, `[Run]`, `[UninstallRun]`; the event functions (`InitializeSetup`, `InitializeWizard`, `NextButtonClick`, `CurStepChanged`, ...) only dispatch to the modules | - | download wiring (S-WP3, done), compatibility defaults (S-WP4), `SetupLogging` and `ContractVersion` define (S-WP5), install record, defaults marker and `SetupBuild` (S-WP6), `AfterInstall: RecordInstalledFile` on the file entries (S-WP7) |
| `config_ee.iss`, `config_neoee.iss` | Product configuration | - | - |
| `utils.iss` | URL constants, string helpers, language tag, compatibility flags, uninstall keys, the single HTTP implementation (`HttpGet`), URL allow-list of the update API, download policy (`GetOnlineFileCheck`, `CodeFileExtensions`) | yes, all functions without wizard access | TLS 1.2 for `HttpGet` on Windows 7 (`NeedsExplicitTlsProtocols`, `ApplyTlsProtocols`), `NextDownloadAction` (S-WP3, done); `IsLegacyVistaCompatValue` (S-WP4); INI text, `IsAsciiText` (S-WP6); manifest/path helpers, ordinal sort (S-WP7); screen size clamp, low-resolution predicate, `IsSameOrInside` (S-WP8) |
| `messages.iss` | `[CustomMessages]` in all languages, `[Messages]` overrides | `ci/check_messages.py` | new texts in en/de/fr per package |
| `eestats.iss` | Wrapper of `EEStatsSetup.dll` (Wine, GPU vendor, statistics values) | - | - |
| `extension.iss` | Command line switches, previous installation (uninstall key), Windows version | - | - |
| `pages.iss` | Custom wizard pages (game language, installation mode, graphics card) | - | - |
| `downloads.iss` | Online localized files: pins, policy application, server selection, **download engine** (built-in `TDownloadWizardPage`/`DownloadTemporaryFile`), verification into `{tmp}\verified` | policy, pins and the decision after each attempt via `utils.iss` | engine replaced (S-WP3, done) |
| `randommaps.iss` | Random map scripts: list-based cleanup, migration of 1.7.2 folders, restore on abort | - | - |
| `telemetry.iss` | Setup statistics, only with consent | - | - |
| `installstate.iss` (new) | Contract writer: records installed files, deletes stale state at `ssInstall`, writes `install.ini` and `files.sha256` (ASCII) at the end of `ssPostInstall`, the contract version into the uninstall key, reports files that disappeared | via `utils.iss` | new (S-WP6, S-WP7) |
| `environment.iss` (new) | Read-only checks before the installation: low screen height, foreign or old installations, installing into their folder, EE and NeoEE in one folder | via `utils.iss` | new (S-WP8) |
| `internal/lib/bass` | Setup music (third-party) | - | - |
| `internal/lib/idp` | Inno Download Plugin (third-party DLL) | - | **removed** in the last commit of S-WP3 (done) |
| `ci/build.ps1`, `ci/build_helpers.ps1` | Two-pass build of all variants, hash list of `data\localized-text`, DER copy of the certificate | `ci/tests/build_helpers.tests.ps1` | SHA-256 files of the built setups, `/DSetupBuild` (S-WP5, S-WP6) |
| `ci/check_messages.py` | Checks `messages.iss`, the use of messages in every own script and the encoding (UTF-8 BOM, CRLF) of every own `.iss`; finds the own scripts itself (root and `ci/tests` `*.iss` plus the `#include "..."` closure of `setup_is6.iss`, without `internal/`) | `--self-test` (CI workflow) | own scripts from the `#include` lines, encoding check, self-test (S-WP2, done) |
| `ci/check_contract.py` (new) | Checks that the tables of `docs/CONTRACT.md` match the source of truth in the script (`GameSettings`, `CodeFileExtensions`, compatibility table, `ContractVersion`); lints the `[Files]` flags below `{app}` | `--self-test` | new (S-WP5) |
| `ci/compare_contract.py` (new) | Local only: compares the SHA-256 of both copies of `docs/CONTRACT.md` (contract O12); exit code 0 identical, 1 different (both hashes, first differing line), 2 file missing | `--self-test` (CI workflow) | new (S-WP1) |
| `ci/check_test_plan.py` (new) | `docs/TEST-PLAN.de.md`: unique TP ids, a valid status and the template fields per case, every forum test case 1 to 22 assigned (or "Launcher"/"entfällt" with a reason) with a "Stand" that matches its cases, every TP id named in a Markdown file of the repository exists | `--self-test` (CI workflow) | new (S-WP2, done) |
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
  music (not silent, not Wine)
  update check -----------------------> api.empireearth.eu (HttpGet, TLS, short timeouts)
  legal question (first installation)
  test-build warning, install-mode notice, NeoEE Wine notice
  low screen height (S-WP8)                                                [read-only, notice]
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
CurStepChanged(ssInstall)
  delete install.ini and files.sha256 of the previous run (S-WP6/7)
  VerifyDownloadedFiles: pins, move accepted files to {tmp}\verified, notice for the rest
  PrepareRandomMapScripts, previous certificate state
[InstallDelete] -> [Dirs] -> [Files] (AfterInstall: RecordInstalledFile, S-WP7) -> [Icons]
  -> [Registry] (game settings, install record, defaults marker, S-WP6) -> [Run]
  -> uninstall key (Inno Setup recreates it)
CurStepChanged(ssPostInstall)
  FinishRandomMapScripts, legacy root certificate, legacy RUNASADMIN,
  legacy Vista/7 compatibility values (S-WP4), NeoEE CD keys (authtools.dll)
  WriteInstallState (last step, S-WP6/7): hash recorded files on a progress page, ASCII check,
  files.sha256.tmp -> files.sha256, install.ini.tmp -> install.ini, ContractVersion into the
  uninstall key, notice if installed files are gone (antivirus hint)
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
| Writing `install.ini`/`files.sha256` (S-WP6/7) | I/O error, a path that is not ASCII | logged, temporary file removed, no manifest (the launcher reports "Unknown" and advises a repair) |
| Installed files gone at `ssPostInstall` (S-WP7) | antivirus deletion | listed in `[MissingAfterInstall]`, notice with antivirus advice and repair hint |
| A setup up to 1.7.2 runs later over v2 | it keeps `install.ini`, `files.sha256` and the record | it recreates the uninstall key without `Empire Earth Community: ContractVersion`; the launcher reports "Unknown" (contract revision, S-WP1); portable: not detectable |
| Aborted installation | any | `install.ini`/`files.sha256` were deleted at `ssInstall`, so no stale manifest claims a valid state; random maps restored |

Exceptions in Pascal Script are caught where a call can fail for external reasons (DLL loading,
COM, file I/O, downloads); event functions never let an exception escape into Inno Setup's
installation loop (an exception in `AfterInstall` would abort the installation, so
`RecordInstalledFile` only appends to a list).

## 6. Logging

- **Every run writes a log** (`SetupLogging=yes`, S-WP5): `%TEMP%\Setup Log <date> #<n>.txt`, so
  that players can send it without knowing the `/LOG` switch. `/LOG=<file>` still works.
- Every decision is logged with its reason: update check, legal question, page choices,
  registered/refused/accepted downloads (pinned or TLS-only, with SHA-256), server fallback and its
  cause, random map moves, certificate handling, CD-key result code, manifest summary (number of
  files, size, duration, missing files), files accepted without size check (no `Content-Length`),
  the reason a download was not retried (stop, no mirror allowed), environment findings.
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
| Unit | Pure `[Code]` helpers (`utils.iss`): strings, URLs, download policy, `NextDownloadAction`, compatibility flags, legacy compatibility values, manifest lines, path conversion, INI text, `IsAsciiText`, ordinal sort, screen clamp, `IsSameOrInside` | `ci/tests/unit_tests.iss` (tiny setup, no network) | `ci/run_unit_tests.ps1`; Linux: `ISCC=... sh ci/tests/run_unit_tests.sh` |
| Unit (file) | Writing a manifest and `install.ini` for files the test creates in `{tmp}` (bytes: no BOM, ASCII, LF/CRLF, order, hashes) | `ci/tests/unit_tests.iss` | as above |
| Unit (run time) | Setting the TLS protocol option on a `WinHttpRequest` object without a request (proves the run-time call, not only its compilation) | `ci/tests/unit_tests.iss` | as above |
| Build | All four variants compile against placeholder assets, output names prove the variant | `ci/build.ps1 -Placeholders`; locally `verify_setup.sh` | CI workflow |
| Messages and sources | Duplicates, `==` typos, unknown prefixes, undefined messages in every own script (root and `ci/tests` `*.iss` plus the `#include` lines, so a new module counts from its first commit), order; coverage report; UTF-8 BOM, valid UTF-8 and CRLF of every own `.iss`; a missing included file | `ci/check_messages.py`; `--self-test` runs it against modified copies that must fail (S-WP2) | CI workflow (both) |
| Contract | The tables of `docs/CONTRACT.md` match `GameSettings`, `CodeFileExtensions`, the compatibility entries, `ContractVersion`; `[Files]` flags below `{app}` | `ci/check_contract.py` (S-WP5) | CI workflow |
| Contract copies | Both copies of `docs/CONTRACT.md` are identical (O12) | `ci/compare_contract.py <launcher clone>` (S-WP1), README "Verify" | local, every package that touches the contract, in both directions (`--repo`); its `--self-test` in the CI workflow |
| Test plan | Unique TP ids, valid status and template fields per case, forum test cases 1 to 22 assigned, TP ids named in the README, this document, the ADRs and the other Markdown files exist | `ci/check_test_plan.py`; `--self-test` runs it against modified copies that must fail (S-WP2) | CI workflow (both) |
| Build helpers | Hash lists, DER certificate copy, SHA-256 files of the setups | `ci/tests/build_helpers.tests.ps1` | CI workflow, PowerShell 7 on Linux |
| Real-data equivalence (maintainers, local only) | Build EE and NeoEE with the reconstructed official data, dump with innoextract and compare semantically with the previous build and the official 1.7.2 setups: only the changes of the package may differ | not in the repository (game data must never be committed) | after every package that changes the compiled setup |
| Manual | Installation, update, repair, uninstall on real Windows; every case has a TP id (`TP-00` server pre-check, then one block per package: `TP-1x` downloads ... `TP-6x` environment, `TP-7x` general and forum cases), the build type (A: placeholder build `ci\build.ps1 -Placeholders -TestID 1`, only in a VM or on a snapshot, with the real `EEStatsSetup.dll`; B: real build from the tester's own data with the official AppIds, `-TestID 1`), the starting state and the snapshot to use; the forum test cases 1 to 22 are each mapped to a case or excluded with a reason | `docs/TEST-PLAN.de.md` (German; skeleton, safety rules, "Testbuild herstellen", `TP-00` and `TP-70` in S-WP2; each package works out the cases of its block, S-WP9 completes it) | tester |

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
  confirmed on Windows at 150 % (test plan), twice: with the task `compatibility` (the game is
  `HIGHDPIAWARE`) and without it (the game is DPI-virtualized and sees logical pixels). If the window
  only fits with `HIGHDPIAWARE`, contract 3.3 says so.
- **O7** (defaults under review): decided in [ADR 0005](adr/0005-compatibility-and-wrapper-defaults.md);
  the contract revision (S-WP1) changed 3.7 in both repositories (a table of the values per task,
  Windows version and root, which `ci/check_contract.py` reads), S-WP4 implements it.
- **O11** (EE and NeoEE in one folder): the setup asks (S-WP8).
- **O12** (copy check): answered locally, `ci/compare_contract.py` (S-WP1).
- **Setup version:** `MySetupVersion` stays `1.7.2` until the maintainers release v2; the update API
  may treat an unknown version as outdated, so the version is raised together with the release and
  the API, not by a work package. Test builds are told apart by `SetupBuild` (S-WP6).
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

| Package | Title | Requirements |
|---|---|---|
| S-WP1 | Contract revision in both repositories (one step), local copy check | D5, O3, O4, O7, O11, O12 |
| S-WP2 | Test foundation: test plan skeleton with "Testbuild herstellen" and TP-00, source and test plan checks | R17, R18 |
| S-WP3 | Built-in downloads replace IDP; TLS 1.2 for HTTP requests on Windows 7; operator guide | D2, D3, R16, R17 |
| S-WP4 | Compatibility defaults (no values on Windows Vista/7), wrapper preselection documented | R15, O7 |
| S-WP5 | Build, CI and diagnostics: SHA-256 files of the setups, contract check, setup log | R14, D5, R18 |
| S-WP6 | Install record, `install.ini`, defaults marker, `SetupBuild`, uninstall key value | D5 (1.1, 1.2, 3.5), R1, R17 |
| S-WP7 | Integrity manifest and post-install file check | D5 (2), R2, R11, R17 |
| S-WP8 | Environment warnings: low resolution, foreign installations and their folders, shared folder | R12, R13, O11, R17 |
| S-WP9 | Documentation and completion of the German test plan | R17, R18 |

The contract comes first because the launcher implements it at the same time; every later contract
change is again one step in both repositories. The test plan skeleton comes next, so that every
package adds its Windows cases with TP ids as it goes. Then the risky toolchain change. The
compatibility change comes before the contract check, which checks the compatibility table of the
revised contract. Each package leaves all checks green, updates the CHANGELOG, the README and these
documents, and states its acceptance criteria and verification in its commit message.
