# 0004. Install record, install.ini, integrity manifest and defaults marker

- Status: Accepted (implemented by S-WP3 and S-WP4)
- Date: 2026-10-02
- Requirements: D5 (setup side of [CONTRACT.md](../CONTRACT.md) 1.1, 1.2, 2, 3.5), R1, R2, R11, R17

## Context

The contract specifies *what* the setup leaves for the launcher. This record decides *how* the setup
writes it with Inno Setup 6.2.2, so that it is correct in every variant, survives aborted runs and
is testable without running an installer.

## Decision

1. **One constant.** `#define ContractVersion 1` in `setup_is6.iss`; the registry record,
   `install.ini` and the defaults marker use it. `ci/check_contract.py` compares it with the
   contract ([ADR 0008](0008-release-checksums-and-contract-check.md)).
2. **Registry record and defaults marker are declarative `[Registry]` entries**, so that Inno Setup
   writes them in its normal order (after `[Files]`) and removes them on uninstall:
   - record: `Root: HKA; Subkey: "Software\Empire Earth Community\Installations\{#InstallType}"`
     with `ContractVersion` (dword), `InstallPath` (`{app}`), `InstallMode`
     (`{code:GetContractInstallMode}`: `admin`/`user`), `AppId`, `GameVersion`, `SetupVersion`;
     `uninsdeletekey`, the parents `Installations` and `Empire Earth Community` with
     `uninsdeletekeyifempty`; only in the Regular variants (`#if InstallMode == "Regular"`);
   - marker: `Root: HKCU; Subkey: "Software\Empire Earth Community\GameDefaults\{#InstallType}"`,
     dword `EE` (`Components: game`) and `AoC` (`Components: gameaoc`) = `ContractVersion`, in every
     variant; `uninsdeletekey` on the product key, `uninsdeletekeyifempty` on the parents.
3. **Recording installed files with `AfterInstall`.** Every compiled `[Files]` entry whose
   destination is below `{app}` gets `AfterInstall: RecordInstalledFile`, except the setup data
   folder (`EEStatsSetup.dll`), `deleteafterinstall` files (`_wonkver.pub`), the `external` entries
   that copy configuration files onto themselves to set permissions, and entries below `{tmp}`.
   `RecordInstalledFile` only adds `ExpandConstant(CurrentFileName)` to a list (no I/O, it must not
   raise). The verified online files (one `external` wildcard entry per game folder) are added from
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
   valid. The status label shows a localized "Checking the installed files..." meanwhile.
5. **Encoding:** text is built as `String`, converted once with `UTF8Encode` and written with
   `SaveStringToFile` (raw bytes): UTF-8 without BOM. All installed paths are ASCII today (checked
   over every file of the reconstructed official data); the conversion keeps any future non-ASCII name correct.
6. **Deleting at `ssInstall`:** `install.ini`, `files.sha256` and their `.tmp` files are deleted
   before `[Files]` runs, so an aborted run leaves no manifest that claims a valid state.
7. **Missing files notice (R11):** if `[MissingAfterInstall]` is not empty the setup logs every file
   and shows one localized notice (English, German, French): the files that disappeared during the
   installation (at most ten names, then "and %n more"), that antivirus programs often delete or
   quarantine game files, to add an exception for the installation folder and to run the setup
   again to repair. Not in silent mode or with `/SUPPRESSMSGBOXES`.
8. **Pure helpers in `utils.iss` with unit tests:** manifest path from install root and full path
   (rejects paths outside the root, `..`, `:`), manifest line, ordinal case-insensitive comparison
   and sort, `install.ini` text from its values, the list formatting of the notice. A file-level
   unit test writes a manifest for files it creates in `{tmp}` and checks the bytes.

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
  `SaveStringToFile`: writes the `AnsiString` bytes as they are. This answers contract question
  **O3**: the setup does not use `SaveStringsToUTF8File` for the manifest.
- Contract 1.1 to 3.5: values, keys, lifetimes, exclusions.

## Consequences

- The real-data comparison of S-WP4 shows `AfterInstall: RecordInstalledFile` on the file entries
  below `{app}` and nothing else changed in `[Files]`; S-WP3 shows the new `[Registry]` entries.
- Hashing all installed files takes a few seconds at the end of the installation (the files were
  just written and are usually in the file cache).
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
