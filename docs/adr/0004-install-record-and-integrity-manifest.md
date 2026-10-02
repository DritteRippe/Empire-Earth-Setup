# 0004. Install record, install.ini, integrity manifest and defaults marker

- Status: Accepted, implemented: points 1, 2, 6, 9 and 10 for `install.ini` by S-WP6, points 3 to 8
  and the manifest in points 6 and 9 by S-WP7 (see [Implementation](#implementation))
- Date: 2026-10-02
- Requirements: D5 (setup side of [CONTRACT.md](../CONTRACT.md) 1.1, 1.2, 2, 3.5), R1, R2, R11, R17
- Revised: 2026-10-02, plan review before implementation (ASCII instead of `UTF8Encode`, which
  Inno Setup 6.2.2 does not offer; no defaults marker in portable variants; `SetupBuild`; a value in
  the uninstall key that shows a later run of an older setup; responsive hashing; "processed" files);
  second plan review (the uninstall key value only after both files were really replaced, because
  `RenameFile` does not overwrite; retries for files that are briefly locked; a sort of at most
  n log n; throughput in the log); implementation of S-WP6 (point 2: every run writes the record
  anew; point 6: a run whose deletion failed still writes the files if it can, only the value of
  point 9 is left out; point 10: the characters of `SetupBuild` and the default of the build script);
  implementation of S-WP7 (point 3: three external entries of verified online files, among them the
  copy of the EE learning campaign for AoC, and a destination that cannot be recorded switches the
  manifest off; point 4: the order manifest, `install.ini`, uninstall key value, and the amount of
  data hashed, measured in the real-data builds, also in Consequences)

## Context

The contract specifies *what* the setup leaves for the launcher. This record decides *how* the setup
writes it with Inno Setup 6.2.2, so that it is correct in every variant, survives aborted runs and
is testable without running an installer.

## Decision

1. **One constant.** `#define ContractVersion 1` in `setup_is6.iss`; the registry record,
   `install.ini`, the defaults marker and the uninstall key value (point 9) use it. `ci/check_contract.py` compares it with the
   contract ([ADR 0008](0008-release-checksums-and-contract-check.md)).
2. **Registry record and defaults marker are declarative `[Registry]` entries**, so that Inno Setup
   writes them in its normal order (after `[Files]`) and removes them on uninstall:
   - record: `Root: HKA; Subkey: "Software\Empire Earth Community\Installations\{#InstallType}"`
     with `ContractVersion` (dword), `InstallPath` (`{app}`), `InstallMode`
     (`{code:GetContractInstallMode}`: `admin`/`user`), `AppId`, `GameVersion`, `SetupVersion`,
     `SetupBuild` (point 10); `deletekey uninsdeletekey` on the product key, so that every run writes
     the record anew and no value of an earlier run stays (e.g. the `SetupBuild` of a test build), the
     parents `Installations` and `Empire Earth Community` with `uninsdeletekeyifempty`; only in the
     Regular variants (`#if InstallMode == "Regular"`);
   - marker: `Root: HKCU; Subkey: "Software\Empire Earth Community\GameDefaults\{#InstallType}"`,
     dword `EE` (`Components: game`) and `AoC` (`Components: gameaoc`) = `ContractVersion`, **only in
     the Regular variants**; `uninsdeletekey` on the product key, `uninsdeletekeyifempty` on the
     parents. Portable variants have no uninstaller, so a marker would stay in HKCU forever, and it
     would only spare the launcher a question about D values the setup has just written itself
     (contract 3.6: the first run only asks if an existing D value differs). Contract 3.5 changes
     accordingly (contract revision, S-WP1).
3. **Recording installed files with `AfterInstall`.** Every compiled `[Files]` entry whose
   destination is below `{app}` gets `AfterInstall: RecordInstalledFile`, except the setup data
   folder (`EEStatsSetup.dll`), `deleteafterinstall` files (`_wonkver.pub`), the `external` entries
   that copy configuration files onto themselves to set permissions, and entries below `{tmp}`.
   `RecordInstalledFile` only adds `ExpandConstant(CurrentFileName)` to a list (no I/O, it must not
   raise). Inno Setup also calls `AfterInstall` for an entry whose file it kept (`Install.pas`: the
   `goto Skip` paths end before `NotifyAfterInstallFileEntry`), so the manifest lists every
   destination the run **processed** (installed or kept); contract 2.3 says so. That a kept file is
   rare is enforced by a lint in `ci/check_contract.py`: every `[Files]` entry below `{app}` has
   `ignoreversion` and none has `onlyifdoesntexist`, `promptifolder` or `confirmoverwrite`. The
   verified online files (an `external` wildcard entry per game folder and one that copies the EE
   learning campaign into the AoC folder as well) are added from `{tmp}\verified` when the manifest
   is written, mapped to their game folder exactly like `[Files]` installs them. A destination that
   `RecordInstalledFile` cannot record (an exception, caught there) switches the manifest off for
   this run.
4. **Writing at the end of `ssPostInstall`** (`installstate.iss`, after random maps, certificate
   handling and NeoEE CD keys): the recorded paths are converted to manifest paths, de-duplicated
   case-insensitively (a later entry that overwrites the same file counts once), sorted ordinal
   ignoring case with a merge sort (at most n log n comparisons; about 1800 paths, an insertion
   sort in interpreted Pascal Script would cost seconds; unit test with 2000 entries), hashed with
   `GetSHA256OfFile` (lowercase hex) and written as
   `<hash><space><space><path>` with LF line ends. Files that no longer exist go to
   `[MissingAfterInstall]` instead. `GetSHA256OfFile` raises on every read error, so each file is
   hashed in `try`/`except` and tried twice more after 300 ms (a virus scanner that briefly holds
   the file open); if it still fails, the file and the exception text are logged and the manifest is
   switched off for this run (no partial manifest). Then `install.ini` (CRLF, ASCII) with `[Install]`
   and, if needed, `[MissingAfterInstall]`. Both are written as `<name>.tmp` with `SaveStringToFile`
   and renamed. `RenameFile` is `MoveFile` without `MOVEFILE_REPLACE_EXISTING` (`ScriptFunc_R.pas`,
   `MoveFileRedir`), so the target is deleted first and `FileExists` must be false before the
   rename; on any error the temporary file is deleted, the error logged, and no file is left that
   looks valid. Hashing runs on an output progress page (`CreateOutputProgressPage`, text "Checking the
   installed files..." in en/de/fr, progress per file): its `SetProgress` processes window messages
   (`ScriptDlg.pas`, `TOutputProgressWizardPage.ProcessMsgs`), so Windows does not mark the wizard
   as "Not responding" while several hundred MB are hashed. The log gets one summary line
   (`Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s`); the test plan sets the limit (under 30 s
   on the test laptop, no "Not responding") and measures once more on an HDD or in the Windows 7 VM.
   The uninstall key value of point 9 is written after both files.
5. **Encoding: ASCII only.** Inno Setup 6.2.2's Pascal Script has no `UTF8Encode` (a probe script
   compiled with ISCC 6.2.2 stops with "Unknown identifier 'UTF8Encode'"; `ScriptFunc_R.pas`
   registers no such function). The text is therefore built as ASCII and written with
   `SaveStringToFile` as `AnsiString`; ASCII is valid UTF-8 without BOM, which is what contract 2.2
   asks for. The manifest paths are relative to the install root, so the root itself may contain any
   character; all installed relative paths are ASCII today (checked over every file of the
   reconstructed official data, including the online files). A pure helper `IsAsciiText` (unit
   tests) checks the complete text before writing: if a path is not ASCII, the setup logs it and
   writes **no** manifest (the launcher then reports Unknown and advises a repair), it never
   replaces characters. `install.ini` contains no path except the `[MissingAfterInstall]` manifest
   paths and is checked the same way. A file-level unit test checks the bytes.
6. **Deleting at `ssInstall`:** `install.ini`, `files.sha256` and their `.tmp` files are deleted
   before `[Files]` runs, so an aborted run leaves no manifest that claims a valid state. A failed
   deletion (the file is held open, e.g. by a reader without `FILE_SHARE_DELETE`, or it is
   read-only) is logged with its cause and remembered: then point 9 does not write its value in this
   run. The run still writes both files at the end if it can (they describe this run); a reader
   that still holds a file open makes its replacement fail as well, and the old file stays. Contract 4.2 asks the launcher not to read these files while a setup mutex exists and
   to open them with `FILE_SHARE_READ | FILE_SHARE_DELETE` (contract revision 2, S-WP10).
7. **Missing files notice (R11):** if `[MissingAfterInstall]` is not empty the setup logs every file
   and shows one localized notice (English, German, French): the files that disappeared during the
   installation (at most ten names, then "and %n more"), that antivirus programs often delete or
   quarantine game files, to add an exception for the installation folder and to run the setup
   again to repair. Not in silent mode or with `/SUPPRESSMSGBOXES`.
8. **Pure helpers in `utils.iss` with unit tests:** manifest path from install root and full path
   (rejects paths outside the root, `..`, `:`), manifest line, ordinal case-insensitive comparison
   and sort, `install.ini` text from its values, `IsAsciiText`, the list formatting of the notice. A
   file-level unit test writes a manifest for files it creates in `{tmp}` and checks the bytes.
9. **A later run of an older setup is visible.** Setups up to 1.7.2 know neither `install.ini` nor
   `files.sha256` nor the record and leave them as they are, so after "1.7.2 over v2" the manifest
   would describe files the older setup has replaced. Inno Setup deletes and recreates the uninstall
   key on every run (`Install.pas`, `RegisterUninstallInfo`: `RegDeleteKeyIncludingSubkeys`), and
   the key exists at `ssPostInstall`. So the Regular variants write the dword
   `Empire Earth Community: ContractVersion` = `ContractVersion` into their uninstall key at the end
   of `ssPostInstall`, after the manifest, **only if** `files.sha256` and `install.ini` of this run
   were both written and renamed (point 4) and no deletion of point 6 failed. Otherwise the value is
   missing (Inno Setup recreated the key in this run, so no old value can survive) and the
   launcher reports Unknown with the repair advice instead of comparing new files with an old
   manifest. Portable variants have no uninstall key: there a manifest that could not be replaced
   stays undetected (logged; documented in contract 2.5). Contract rule (revision in S-WP1): a manifest whose
   uninstall key lacks this value was overwritten by an older setup; the launcher reports Unknown
   ("an older setup ran after the current one, run the current setup"). Portable variants have no
   uninstall key; there the case stays undetected (documented). The file times of installed files
   cannot replace this check: Inno Setup gives them the time stamps of the source files.
10. **`SetupBuild`:** an optional value in `install.ini` and the record, from `/DSetupBuild=<text>`
    (`ci/build.ps1`: CI the short Git commit; test builds `test<TestID>-<commit>`; any other build
    none; `-SetupBuild` overrides; default of the script empty, then not written). At most 64
    characters `A-Z a-z 0-9 . _ -`, checked by ISPP and by the build script before ISCC runs: the
    value goes into the registry, into the ASCII `install.ini` and onto the command line, and a brace
    or a quote would become an Inno Setup constant or end a Pascal string. It tells test builds
    apart while `MySetupVersion` stays `1.7.2`. Compatible change (contract 5).

## Evidence

Inno Setup 6.2.2 sources (`jrsoftware/issrc`, tag `is-6_2_2`):

- `Install.pas`, `CopyFiles`: `NotifyAfterInstallFileEntry(CurFile)` is called once per compiled
  `[Files]` entry, after the file is copied. `Main.pas`: `CurrentFileName` is `FileEntry.DestName`
  during `AfterInstall`. ISCC expands wildcard entries of compiled files into one entry per file with
  the full destination (the dumps of the real-data builds list e.g.
  `"{app}\Empire Earth\Data\Campaigns\EETheBritish.ssa"` as its own entry), so `AfterInstall` sees
  every compiled file with its destination. An `external` wildcard entry is one entry with one call,
  hence the separate handling of `{tmp}\verified`.
- `FileClass.pas`, `TTextFileWriter.DoWrite`: `SaveStringsToUTF8File` writes the UTF-8 preamble
  `EF BB BF` into an empty file and `WriteLine` appends CRLF. `ScriptFunc_R.pas`,
  `SaveStringToFile`: writes the `AnsiString` bytes as they are; `UTF8Encode` is not registered,
  and a probe compile with ISCC 6.2.2 under Wine confirms that it is unknown to scripts. This
  answers contract question **O3**: the setup writes ASCII with `SaveStringToFile`.
- `ScriptDlg.pas`, `TOutputProgressWizardPage.SetProgress`/`SetText`: call `ProcessMsgs`
  ("keep Windows from thinking the process is hung").
- `Install.pas`, `RegisterUninstallInfo`: the uninstall key is deleted with its subkeys and written
  again on every installation; `Main.pas`: `ssPostInstall` comes after `PerformInstall`.
- Contract 1.1 to 3.5: values, keys, lifetimes, exclusions.

## Consequences

- The real-data comparison of S-WP7 shows `AfterInstall: RecordInstalledFile` on the file entries
  below `{app}` and nothing else changed in `[Files]`; S-WP6 shows the new `[Registry]` entries.
- Hashing all installed files takes a measurable time at the end of the installation (the files
  were just written and are usually in the file cache). In the builds from the reconstructed 1.7.2
  data all compiled entries below `{app}` together hold 722 MB (EE) and 809 MB (NeoEE), counting
  every component and every alternative (only one DirectX wrapper and one language are installed
  at a time); the downloaded localized files come on top. The plan's estimate of 1.5 GB was too
  high. The time is logged and has a limit in the test plan; if the limit is missed, the fallback
  is to hash only the `code` class and store the size of the others, which is a contract change.
- A future installed file with a non-ASCII name would switch the manifest off (logged) instead of
  writing a wrong one; the build would have to add an encoder first.
- A run that installs nothing below `{app}` (impossible today, `game` is fixed) would write an empty
  manifest; that is valid.
- The registry record of a `user` installation lives in the HKCU of that user only; the launcher
  finds installations of other accounts through the uninstall keys or the folder (contract 1.4).
- The setup writes the marker for the account that runs it, also in `admin` mode (over-the-shoulder
  elevation: the elevating account), exactly like the game settings it writes.

## Implementation

S-WP6, 2026-10-02: points 1, 2, 6, 9 and 10 for `install.ini`; the manifest (points 3 to 5, 7, 8 and
`files.sha256` in points 6 and 9) came with S-WP7 (second part of this section). In this order: the
pure helpers with their unit tests (`7bde676`), `SetupBuild` (`2474edb`), `install.ini` and the
uninstall key value (`e389f34`), the install record and the defaults marker (`f35856a`), README and
CHANGELOG (`d82e7e5`), the test cases TP-40 and TP-41 (`a9d9229`).

- **Point 1:** `ContractVersion` is the value of the record, the marker, `install.ini` and the
  uninstall key value; its comment in `setup_is6.iss` says so.
- **Point 2:** `[Registry]` under `#if InstallMode == "Regular"`, after the game settings:
  `Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"` (`BaseRegCommunity` =
  `Software\Empire Earth Community`) with `Flags: deletekey uninsdeletekey`, the values
  `ContractVersion` (dword), `InstallPath` `{app}`, `InstallMode` `{code:GetContractInstallMode}`
  (`InstallModeName` of `utils.iss`), `AppId` `{#AppID}`, `GameVersion`, `SetupVersion`, and
  `SetupBuild` under `#if SetupBuild != ""`; the parents with `uninsdeletekeyifempty`. Marker:
  `Root: HKCU; Subkey: "{#BaseRegCommunity}\GameDefaults\{#InstallType}"` with `uninsdeletekey`,
  dword `EE` (`Components: game`) and `AoC` (`Components: gameaoc`), parents
  `uninsdeletekeyifempty`. The scripts that ISCC preprocessed for the Portable variants contain
  neither the word `Installations` nor `GameDefaults`.
- **Point 6:** `installstate.iss`, `DeleteInstallState`, the first step of `ssInstall`:
  `DeleteStateFile` (`utils.iss`) deletes `install.ini` and `install.ini.tmp`; a file that is still
  there is logged with its cause (`it is read-only` from the attributes of `FindFirst`, else `it is
  held open by another program or access is denied`) and remembered (`InstallStateDeleteFailed`).
- **Points 4 and 9 for `install.ini`:** `WriteInstallState`, the last step of `ssPostInstall`, after
  the NeoEE CD keys: `BuildInstallIniText` (the keys in the order of contract 1.2, `SetupBuild` only
  if set, CRLF), `ReplaceStateFile` (`IsAsciiText`; delete an old `.tmp`; `SaveStringToFile` to the
  `.tmp`; delete the target and require `FileExists` = False; `RenameFile`; delete the `.tmp` after
  any failure; `try`/`except`), then `ShouldWriteContractVersionValue(not Portable,
  not InstallStateDeleteFailed, IniWritten)` and only then, if the uninstall key exists,
  `RegWriteDWordValue(HKA, GetUninstallRegPath(), 'Empire Earth Community: ContractVersion', 1)`.
  Every branch writes one log line; nothing stops the installation and no message is shown, so
  `messages.iss` is unchanged (R17: no new user-visible text). S-WP7 adds `files.sha256` to
  `DeleteInstallState` and to the third argument.
- **Point 10:** `#define SetupBuild ""` (an empty or bare `/DSetupBuild` is none), checked by ISPP
  with a recursive `StripChars` macro. `ci/build.ps1 -SetupBuild`, else `Get-SetupBuild`
  (`test<TestID>-<commit>`, the short commit when `GITHUB_ACTIONS` is `true`, else none;
  `Get-GitShortCommit`), `Assert-SetupBuild` before ISCC runs. `ci/check_contract.py --preprocessed`
  takes the value ISCC got from the record of the preprocessed script (the CI build passes the
  commit). The first log line of every run names product, versions, install type and mode,
  `SetupBuild`, `TestID` and contract version.
- **Tests:** 73 new unit tests, 292 in all, pass under Wine: 40 of the pure helpers (the example of
  contract 1.2, all three install modes, with and without `SetupBuild`, CRLF, `IsAsciiText` with
  U+0080, Latin, Chinese and surrogate characters, all 8 combinations of
  `ShouldWriteContractVersionValue`) and 33 at file level in `{tmp}`: `RenameFile` over an existing
  file fails and keeps both files and works after the target was deleted (the evidence of point 4
  at run time); `ReplaceStateFile` over an existing file and a leftover `.tmp`, without a target,
  the bytes (no BOM, only ASCII, only CRLF), refused non-ASCII text, a read-only target and a folder
  of that name leave the old state and no `.tmp`. `ci/tests/build_helpers.tests.ps1`: 40 new checks
  (164), a mutation that does not pass the define fails 3 of them.
- **Real-data comparison** (maintainers only, never committed: EE and NeoEE built with ISCC from the
  reconstructed 1.7.2 data, official AppIds, unsigned, no `SetupBuild`; innoextract dumps compared
  semantically) against the S-WP10 build (`b66a0af`): for EE and NeoEE alike only the compiled code
  (EE 122096 -> 130862 bytes, NeoEE 126791 -> 135561 bytes) and 14 new registry entries (76 -> 90:
  record key with three parents and six values, marker key with its parent and two values) differ;
  messages, tasks, components, files, data, run entries, folders and the other registry entries are
  identical. innoextract prints the root of the record as `HKCU`, because it masks the top bit of the
  stored key; the raw header has `0x00000001` (`HKEY_AUTO`, i.e. `HKA`) for the record and
  `0x80000001` (`HKEY_CURRENT_USER`) for the marker and the game settings.
- **Run-time probe under Wine** (not in the repository): a small setup with `utils.iss` and
  `installstate.iss` unchanged, the `[Registry]` block of record and marker cut out of
  `setup_is6.iss` unchanged, `DeleteInstallState` first at `ssInstall` and `WriteInstallState` last
  at `ssPostInstall`, and optional disturbances. Administrative mode: record in HKLM with
  `InstallMode` `admin`, marker in HKCU, `install.ini` (242 or 243 bytes, 11 CRLF, no BOM, no
  non-ASCII byte), the value `0x1` in the uninstall key. User mode: the same in HKCU; a second run
  over the existing `install.ini` replaces it and writes the value; `install.ini` held open without
  `FILE_SHARE_DELETE` during `ssInstall` (closed right after it): `Unable to delete ...: it is held
  open by another program or access is denied`, `install.ini` written at the end, **no** value;
  read-only `install.ini`: `it is read-only` at both steps, `Not writing ...: the old file is still
  there`, the old file kept, no value; held open during `ssPostInstall`: the same, no `.tmp` left; an
  undisturbed run writes the value again. The uninstaller removes record, marker, the parent keys
  and the folder and keeps a value seeded below `HKCU\Software\Sierra\CDKeys`. Portable: `install.ini`
  with `InstallMode=portable`, no record, no marker, no value, the log line `Portable setup: no
  uninstall key ...`. An install root with non-ASCII characters (`C:\wp6probe_Jeux é ü`) still gives
  an ASCII `install.ini` (it holds no path) and the value. Inno Setup 6.2.2 runs complete
  installations and uninstallations in this Wine prefix when every Wine process of the probe uses
  one X display (one Xvfb, also for `reg.exe`) and `WINEDEBUG=+err`; with a separate `xvfb-run` per
  command the user-mode setups stopped before the installation with "System Error. Code: 120" (the
  earlier probes ran their code in `InitializeSetup` for that reason).
- **Not verified here:** the 64-bit registry view on real 64-bit Windows (the Wine prefix is 32-bit),
  share modes and the read-only attribute on NTFS, over-the-shoulder elevation and a later run of
  the official setup 1.7.2: TP-40 and TP-41.

S-WP7, 2026-10-02: points 3 to 8 and `files.sha256` in points 6 and 9. In this order: the pure
helpers with their unit tests (`ed3f2bd`), the file-level writer with its unit test (`c6b4f10`), the
recording with the `[Files]` lint (`4b64154`), the writing at the end of the setup with the progress
page, the notice and the messages (`4eafaed`), this documentation with test case TP-50.

- **Point 3:** 44 `[Files]` entries as written (107 in the preprocessed EE script, 179 in the NeoEE
  one; 2340 and 2504 after ISCC expanded the wildcards) have `AfterInstall: RecordInstalledFile`.
  `RecordInstalledFile` (`installstate.iss`) appends
  `ExpandConstant(CurrentFileName)` to a `TStringList` inside `try`/`except`; an exception only
  increments `RecordFailures`, which makes `WriteInstallStateFiles` write no manifest. Without it:
  `EEStatsSetup.dll` (setup data folder), `_wonkver.pub` (`deleteafterinstall`), the eight
  permission entries and the three entries of `{tmp}\verified` (all `external`). `Install.pas`,
  `CopyFiles`, calls `NotifyAfterInstallFileEntry` once per entry after `RecurseExternalCopyFiles`
  and `Main.pas` sets `CurrentFileName` to `FileEntry.DestName`, the folder for an external
  wildcard entry; so `RecordVerifiedOnlineFiles` adds the verified files with
  `CollectExternalFiles` (`utils.iss`, the same choice of files as `RecurseExternalCopyFiles`: no
  hidden files, no hidden folders) under the components of the three entries: `{tmp}\verified\EE`
  to the EE folder (`game and language\update`), `{tmp}\verified\AoC` and the EE learning campaign
  to the AoC folder (`gameaoc and language\update`). `ci/check_contract.py` checks the rule in both
  directions, as written and in the preprocessed scripts (five self-test cases).
- **Point 4:** `WriteInstallState`, the last step of `ssPostInstall`, shows the output progress page
  created in `InitializeWizard` (`CreateManifestProgressPage`, caption "Checking the installed
  files") and calls `WriteInstallStateFiles` (`utils.iss`): `GetManifestPaths` (`GetManifestPath`,
  `IsManifestExcludedPath`, `MergeSortManifestPaths` with uppercase keys computed once,
  `RemoveDuplicateManifestPaths` keeping the spelling recorded last), `HashManifestFiles`
  (`FileExists`, `HashFileWithRetries` with 3 attempts and 2 pauses of 300 ms, `FileSize64`,
  `SetText`/`SetProgress` per file), the log line from `FormatManifestSummary` (`GetTickCount` of
  `kernel32.dll`, also across its wrap), `ReplaceStateFile` for `files.sha256` if complete, then for
  `install.ini` with `BuildMissingAfterInstallText`. The page is hidden in `finally`. Order:
  manifest, `install.ini`, notice, uninstall key value.
- **Point 5:** `HashManifestFiles` checks every manifest path with `IsAsciiText`; a path that is not
  ASCII switches the manifest off (logged), `BuildMissingAfterInstallText` leaves such a path out
  of `[MissingAfterInstall]`, the notice still names it.
- **Point 6:** `DeleteInstallState` deletes `files.sha256` and `files.sha256.tmp` as well; a failure
  sets `InstallStateDeleteFailed` as for `install.ini`.
- **Point 7:** `ReportMissingFiles`: one log line per missing file (in `HashManifestFiles`), one
  summary line, and `MsgBox(FilesMissingAfterInstall, mbError)` with `FormatMissingFileList` (at
  most `MissingFilesShownMax` = 10 names with `\`, then `FilesMissingAfterInstallMore`) and the
  installation folder, not if `SilentInstall` or `SuppressMsgBoxes`. New messages in English, German
  and French: `ManifestPageCaption`, `ManifestPageDescription`, `ManifestPageStatus`,
  `FilesMissingAfterInstall`, `FilesMissingAfterInstallMore`.
- **Point 8:** the helpers of point 4 and 7 in `utils.iss`; 138 new unit tests, 430 in all, pass
  under Wine: path conversion (outside, the root itself, `..`, `.`, `:`, empty segments, `/`, a
  root with non-ASCII characters), exclusions, lines, ordering (`_` after the letters,
  `Empire Earth - The Art of Conquest/` before `Empire Earth/`), the merge sort of 2000 paths in
  mixed case (19173 comparisons, limit 2000 * 11) and of 1000 paths recorded twice (the later
  spelling kept), `[MissingAfterInstall]` with the example of contract 1.2, the notice list with 0,
  2, 10, 11 and 25 files, the log line with 3 GB; at file level an installation in `{tmp}` with a
  deleted file (no BOM, only LF, ASCII, order, hashes equal to `GetSHA256OfFile`, each file once,
  excluded and outside paths left out, no `.tmp`, `[MissingAfterInstall]`), a verified file next to
  a hidden one, a file held open without sharing (`Sharing violation`, 602 ms for the three
  attempts, no manifest, `install.ini` written), an incomplete recording, a non-ASCII path, nothing
  recorded (an empty manifest).
- **Point 9:** `WriteContractVersionValue(IniWritten and ManifestWritten)`.
- **Real-data comparison** (maintainers only, never committed: EE and NeoEE built with ISCC from the
  reconstructed 1.7.2 data, official AppIds, unsigned, no `SetupBuild`; innoextract dumps) against
  the S-WP6 build (`f35856a`): the `[Files]` entries are identical in order, fields and locations
  except the new `After install: "RecordInstalledFile"`; EE: 2340 of 2352
  entries below `{app}` have it, the other 12 are the setup data folder (1) and the
  external entries (11); NeoEE: 2504 of 2518, the other 14 are
  the setup data folder (1), the external entries (11) and `_wonkver.pub` (2); no other entry has
  it. Besides that only the compiled code (EE 130862 -> 148571 bytes, NeoEE 135561 -> 153282 bytes)
  and the 15 new messages differ; every other section is identical.
- **Run-time probe under Wine** (not in the repository): a setup with `utils.iss`, `extension.iss`
  and `installstate.iss` unchanged, the three `{tmp}\verified` entries and the 15 message lines cut
  out of the real files, compiled entries like those of the setup (wildcards with subfolders, a
  second entry that installs `Empire Earth.exe` again, the setup data folder, a `deleteafterinstall`
  file), 64 MB of data and verified online files created at `ssInstall` as `VerifyDownloadedFiles`
  leaves them. User, admin and portable mode: 13 recorded destinations, `files.sha256` with 11
  lines that `sha256sum -c` accepts in the installation folder, ordered as `LC_ALL=C sort -f`, no
  BOM, no CR, no `.tmp`, the uninstall key value (not in portable); `Manifest: 11 files, 64.0 MB,
  599 ms, 106.8 MB/s` (between 576 and 752 ms in all runs). Two files deleted right before the last
  step: two log lines, `[MissingAfterInstall]` with both, no dialog in `/VERYSILENT`, the value is
  written. `Data\data.ssa` held open without sharing: three `Sharing violation` attempts, `No
  manifest in this run`, `install.ini` written, no value. The same file only read-only (attribute):
  hashed like any other, manifest and value written (the attribute does not prevent reading). `files.sha256` read-only: `Unable to delete
  ...: it is read-only` at both steps, the old manifest kept, no value. `files.sha256` held open
  without `FILE_SHARE_DELETE` during `ssInstall`: the deletion fails, the new manifest is written at
  the end, no value (decision K4). `/SILENT` with the visible progress window completes. The
  uninstaller removes the folder.
- **Not verified here:** an antivirus program on Windows, share modes on NTFS, "Not responding"
  and the duration with real data on real hardware (test case TP-50, also on an HDD or in the
  Windows 7 virtual machine), the notice itself (only shown without silent mode).

## Alternatives considered

- **Hashing at compile time** (manifest built by ISPP or `ci/build.ps1`): would not know which
  components, tasks and checks (`IsWine`, admin/user file sets of NeoEE) apply on the target, nor
  the downloaded files; the contract requires the state of the actual run.
- **Enumerating the game folders at the end:** cannot tell installed files from player files and
  leftovers.
- **Writing the record in `[Code]`:** no automatic uninstall; `[Registry]` is simpler and visible in
  the dump.
- **`SaveStringsToUTF8File`:** writes a BOM (see Evidence).
- **`UTF8Encode` + `SaveStringToFile`:** not available in Inno Setup 6.2.2 (see Evidence).
- **An own UTF-8 encoder in Pascal Script:** no installed path needs it; the conversion of `String`
  to `AnsiString` uses the ANSI code page, so byte-exact output would need extra care for no case
  that exists.
- **Comparing file times with `Written`** to detect a later older setup: Inno Setup keeps the time
  stamps of the source files, so the file times say nothing about the run.
