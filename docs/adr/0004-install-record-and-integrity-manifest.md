# 0004. Install record, install.ini, integrity manifest and defaults marker

- Status: Accepted (implemented by S-WP6 and S-WP7)
- Date: 2026-10-02
- Requirements: D5 (setup side of [CONTRACT.md](../CONTRACT.md) 1.1, 1.2, 2, 3.5), R1, R2, R11, R17
- Revised: 2026-10-02, plan review before implementation (ASCII instead of `UTF8Encode`, which
  Inno Setup 6.2.2 does not offer; no defaults marker in portable variants; `SetupBuild`; a value in
  the uninstall key that shows a later run of an older setup; responsive hashing; "processed" files)

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
     `SetupBuild` (point 10); `uninsdeletekey`, the parents `Installations` and `Empire Earth Community` with
     `uninsdeletekeyifempty`; only in the Regular variants (`#if InstallMode == "Regular"`);
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
   `ignoreversion` and none has `onlyifdoesntexist`, `promptifolder` or `confirmoverwrite`. The verified online files (one `external` wildcard entry per game folder) are added from
   `{tmp}\verified` when the manifest is written, mapped to their game folder exactly like `[Files]`
   installs them.
4. **Writing at the end of `ssPostInstall`** (`installstate.iss`, after random maps, certificate
   handling and NeoEE CD keys): the recorded paths are converted to manifest paths, de-duplicated
   case-insensitively (a later entry that overwrites the same file counts once), sorted ordinal
   ignoring case, hashed with `GetSHA256OfFile` (lowercase hex) and written as
   `<hash><space><space><path>` with LF line ends. Files that no longer exist go to
   `[MissingAfterInstall]` instead. Then `install.ini` (CRLF, ASCII) with `[Install]` and, if needed,
   `[MissingAfterInstall]`. Both are written as `<name>.tmp` with `SaveStringToFile` and renamed;
   on any error the temporary file is deleted, the error logged, and no file is left that looks
   valid. Hashing runs on an output progress page (`CreateOutputProgressPage`, text "Checking the
   installed files..." in en/de/fr, progress per file): its `SetProgress` processes window messages
   (`ScriptDlg.pas`, `TOutputProgressWizardPage.ProcessMsgs`), so Windows does not mark the wizard
   as "Not responding" while about 1.5 GB are hashed. The log gets one summary line
   (`Manifest: <n> files, <MB> MB, <ms> ms`); the test plan sets the limit (under 30 s on the test
   laptop, no "Not responding").
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
   before `[Files]` runs, so an aborted run leaves no manifest that claims a valid state.
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
   of `ssPostInstall`, after the manifest. Contract rule (revision in S-WP1): a manifest whose
   uninstall key lacks this value was overwritten by an older setup; the launcher reports Unknown
   ("an older setup ran after the current one, run the current setup"). Portable variants have no
   uninstall key; there the case stays undetected (documented). The file times of installed files
   cannot replace this check: Inno Setup gives them the time stamps of the source files.
10. **`SetupBuild`:** an optional value in `install.ini` and the record, from `/DSetupBuild=<text>`
    (CI: short Git commit; test builds: `test<TestID>-<commit>`; default empty, then not written).
    It tells test builds apart while `MySetupVersion` stays `1.7.2`. Compatible change (contract 5).

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
- Hashing all installed files takes a measurable time at the end of the installation (about 1.5 GB;
  the files were just written and are usually in the file cache). The time is logged and has a limit
  in the test plan; if the limit is missed, the fallback is to hash only the `code` class and store
  the size of the others, which is a contract change.
- A future installed file with a non-ASCII name would switch the manifest off (logged) instead of
  writing a wrong one; the build would have to add an encoder first.
- A run that installs nothing below `{app}` (impossible today, `game` is fixed) would write an empty
  manifest; that is valid.
- The registry record of a `user` installation lives in the HKCU of that user only; the launcher
  finds installations of other accounts through the uninstall keys or the folder (contract 1.4).
- The setup writes the marker for the account that runs it, also in `admin` mode (over-the-shoulder
  elevation: the elevating account), exactly like the game settings it writes.

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
