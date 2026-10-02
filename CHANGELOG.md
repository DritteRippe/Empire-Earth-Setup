# Changelog

Release notes of the Empire Earth Community Setup. The version is the setup version
(`MySetupVersion` in `setup_is6.iss`); EE and NeoEE setups of the same version share the same
features. Up to 1.0.4.1 the setup used the four-part version format of the game, since 1.5.0 it
uses semantic versioning.

Until 1.7.2 these notes lived in the header of `setup_is6.iss`. They were moved here unchanged
apart from spelling fixes, the 1.7.1 correction noted there, a correction of 1.6.0 and an
off-topic personal remark in 1.0.3.0 that was left out. Dates are the release dates given in the
header.

## Unreleased

Refactoring and quality fixes (no new game content).

### Added
- Build switches can be set on the command line instead of editing the script:
  `ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss`
  (also `SignSetup`, `CertFileName`, `CertHashSHA1`, `TestID`); invalid values stop the build
  with a clear message.
- `ci/build.ps1`: clean two-pass build of all four variants, optionally against placeholder
  assets; GitHub Actions workflow compiling every push and pull request with Inno Setup 6.2.2.
  `-SignSetup -CertFileName -CertHashSHA1 [-SignTool]` makes signed builds with a DER or PEM
  certificate (see Changed). Its helpers that need no Inno Setup are in `ci/build_helpers.ps1`,
  tested by `ci/tests/build_helpers.tests.ps1` (also in the workflow).
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
  same file is in the launcher repository. The setup does not implement it yet.
- `docs/ARCHITECTURE.md`: target architecture of setup v2 (module map, data flow of an
  installation, error handling, logging, localization, testing strategy, plan of the work packages)
  and architecture decision records in `docs/adr/`: keep Inno Setup and Pascal Script, stay on Inno
  Setup 6.2.2, replace the download plug-in IDP by Inno Setup's built-in downloads, how the install
  record and the integrity manifest are written, compatibility and DirectX wrapper defaults, strict
  TLS and the file server certificate, warnings before the installation, checksums of the setups
  and a check of the contract. Documentation only, the setup does not change yet.
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
  other cases are placeholders that the following work packages work out. README: "Testing on
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

### Changed
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
  opt-in `~ RUNASADMIN`, O7); O4, O11 and O12 are answered. Documentation only, later packages
  implement it.

### Removed
- Entries for Windows XP and older: the WIN98 compatibility mode and the pre-Vista `netsh
  firewall` rules (23 entries). Setups made with Inno Setup 6 do not start on these systems, so
  the entries never ran. For the same reason the Quick Launch shortcut task (shown only below
  Windows 7) and its three shortcuts are removed.
- The Inno Download Plugin (IDP 1.6.0, `internal/lib/idp`: two binaries from 2014, its script and
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
  entries required Windows 10, so 8 and 8.1 got none), and Empire Earth gets the Windows 7
  entries on Windows 7 (a wrong version filter, `0.6.2` instead of `0.0,6.2`, had only let them
  apply to AoC).
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
  follows redirects automatically, and nothing documents that it refuses one from `https://` to
  `http://`: only the operator of a validated server can send such a redirect, pinned files are
  unaffected (their SHA-256 decides), and `docs/SERVER-OPERATIONS.md` requires that the file
  servers never redirect to `http://`. The update check and the reachability check (WinHTTP)
  refuse such redirects.
- Random map scripts: the elevated setup never follows junctions or symbolic links in the random
  map folders, which all users can write to. A user could otherwise have made it delete files or
  empty folders elsewhere, or loop through a link to a parent folder.
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
