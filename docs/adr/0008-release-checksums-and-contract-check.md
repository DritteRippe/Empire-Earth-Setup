# 0008. SHA-256 files of the built setups, CI check of the contract, a log of every setup run

- Status: Accepted, implemented (S-WP5, see [Implementation](#implementation); copy check by S-WP1,
  source checks by S-WP2)
- Date: 2026-10-02
- Requirements: R14, D5 ("the `GameSettings` block is the source of truth"), R18, contract O12
- Revised: 2026-10-02, plan review before implementation (the check reads only tables of the
  contract; `[Files]` flag lint; local copy check of the contract; encoding and message checks of
  every own script); S-WP2: the source checks also cover `ci/tests/*.iss` (own scripts according
  to `.editorconfig`) and report an `#include` of a missing file; second plan review (the tables of
  contract 3.3 and 3.4 are checked too; the README names where the log of an elevated run lands;
  the redirect from `https://` to `http://` is probed and a release build lists its unpinned online
  files)

## Context

- Players download the setups from the website and mirrors; the forum shows broken and repacked
  downloads (t=5741, t=3763). There is no published checksum of a setup EXE (forum report section 8,
  item 12).
- `docs/CONTRACT.md` repeats values whose source of truth is the script: the `GameSettings` block,
  `CodeFileExtensions`, the compatibility flags of `BuildCompatibilityFlags` and the contract
  version. Nothing stops them from drifting apart.
- Support in the forum depended on players describing what they did; the setup writes a log only
  with `/LOG`.

## Decision

1. **SHA-256 files:** `ci/build.ps1` writes `<setup>.exe.sha256` next to every built setup (after
   ISCC, i.e. after signing), in `sha256sum` format (`<lowercase hash><space><space><file name>`, LF,
   UTF-8 without BOM), and prints the hash. The function lives in `ci/build_helpers.ps1`
   (`Write-FileSha256`) and is tested by `ci/tests/build_helpers.tests.ps1`. The README explains how
   maintainers publish the hash next to the download and how players check it
   (`Get-FileHash <file> -Algorithm SHA256`, `sha256sum -c`).
2. **Contract check:** `ci/check_contract.py` (Python 3, no dependencies) parses `setup_is6.iss` and
   `utils.iss` and fails if `docs/CONTRACT.md` differs from them. It reads **only tables** of the
   contract, never prose:
   - every value of the `GameSettings` sub (name, type, data, `deletevalue` = class S/D,
     `createvalueifdoesntexist` = class P) and the ending epochs passed to it, against the table of
     contract 3.2;
   - `CodeFileExtensions` against the `code` row of contract 2.4;
   - the flags of `BuildCompatibilityFlags`, the tasks and the Windows versions of the compatibility
     entries against the table that the contract revision (S-WP1) adds to contract 3.7;
   - `#define ContractVersion` (added by S-WP5) against the contract header table;
   - from contract revision 2 (S-WP10, both repositories): the table of 3.3 (minimum and maximum
     window width and height) against `MinGameWindowWidth` ... `MaxGameWindowHeight`, and the table
     of 3.4 (value, Windows version, task, programs) against the `UserGpuPreferences` entries of
     `[Registry]`. The launcher computes the same values, so they need the same protection as 3.2.
   It also lints `[Files]`: every entry below `{app}` has `ignoreversion` and none has
   `onlyifdoesntexist`, `promptifolder` or `confirmoverwrite` (contract 2.3, the manifest lists
   every file the run processed). Its parser handles ISPP line continuations and `#expr`/`#call`
   only as far as these blocks need, and `--self-test` runs it against modified copies (one changed
   value per rule) that must fail. It runs in the CI workflow next to `check_messages.py` and in the
   local verification.
3. **Copy check of the contract (O12, local):** CI cannot reach the other repository, so
   `ci/compare_contract.py <path of the other clone>` compares the SHA-256 of both `docs/CONTRACT.md`
   files and is part of the local verification of every package that touches the contract. Every
   contract change is one step that changes both copies in the same run, with the same commit
   subject, and runs the checks of both repositories.
4. **Source checks** (S-WP2): every own `*.iss` starts with the UTF-8 BOM and has only
   CRLF line ends (Inno Setup 6.2 reads BOM-less files as ANSI); `check_messages.py` takes its list
   of own scripts from the `#include` lines of `setup_is6.iss` plus the root `*.iss` files and the
   unit test setup in `ci/tests`, minus third-party code under `internal/` and the temporary build
   copies, so that a new module is checked from its first commit; `--self-test` (CI workflow)
   proves that a new module with an undefined message or without BOM fails the check.
5. **Setup log:** `[Setup] SetupLogging=yes`: every run writes `Setup Log <date> #<n>.txt` to the
   user's temporary folder (the log lists no secrets, see ARCHITECTURE 6). The README and the test
   plan say where to find it, including the case of an elevated run: with over-the-shoulder
   elevation the setup runs as the administrator account, so the log is in **that** account's
   `%TEMP%`. The README also says that the log contains paths with user names and should be
   checked before it is posted publicly.
6. **Redirects of unpinned downloads (D3 "never `http://`"):** [ADR 0003](0003-built-in-downloads-instead-of-idp.md)
   only assumes that `THTTPClient` follows a redirect from `https://` to `http://`. S-WP5 proves it
   with the existing Wine probe (a local HTTPS server whose certificate the Wine prefix trusts
   answers `302` with an `http://` location) and records the result in the implementation section
   of this record. If the redirect is followed, or the probe cannot decide it: `ci/build.ps1`
   prints, for a release build (`TestID` 0), a warning that lists every online file the setup
   registers without a pin, and [SERVER-OPERATIONS.md](../SERVER-OPERATIONS.md) gets the release
   recommendation to pin the files that are known at build time (placing them in
   `data\localized-text`), with its trade-off (a pinned file that changes on the server is refused
   until the next build). The operator rule "no redirect to `http://`" stays in any case.

## Evidence

- Forum report section 8, item 12 ("SHA-256 jeder Setup-Version auf der Downloadseite
  veröffentlichen, direkt in `ci/build.ps1` per `Get-FileHash`").
- Contract 3: "A change there changes this section in the same commit", and section 7 ("`GameSettings`,
  `BuildCompatibilityFlags`, `CodeFileExtensions` and this document changed together"): a rule that
  is only written down is not enforced.
- `check_messages.py` already shows that such text checks catch mistakes Inno Setup compiles without
  a warning.

## Consequences

- A release has one more artefact per setup; the website must show or link it.
- A change of a default fails CI until the contract (in both repositories) is updated: intended.
- CI cannot verify the launcher's copy of the contract (no network in CI); the local copy check covers
  it for every package that touches the contract (O12 answered: locally, not in CI).

## Implementation

S-WP5, 2026-10-02, in this order: the SHA-256 files, the contract check, the setup log, the
priorities of the test plan and the test case TP-30, then the redirect probe and the warning of a
release build.

- **Point 1:** `Write-FileSha256` in `ci/build_helpers.ps1`; `ci/build.ps1` calls it for every
  setup that passed, after ISCC (and its sign tool), and prints the hash; a failure counts as a
  failed variant. `ci/tests/build_helpers.tests.ps1`: content, one LF, no BOM, overwriting,
  relative paths, a missing file, `sha256sum -c` (accepts the file, detects a changed setup), and
  the file next to every setup of a dry run of `build.ps1`. README "Checksums of the setups" and
  "Support"; test case TP-30 (a) checks it on Windows with `Get-FileHash` and `sha256sum -c`.
- **Point 2:** `#define ContractVersion 1` in `setup_is6.iss` (no effect on the compiled setup) and
  `ci/check_contract.py`: header, 2.4 row `code`, 3.2 (27 values of both games in all four
  variants) and 3.7 against the script, `[Files]` lint (58 entries as written, 193 expanded, all
  compliant), an interpreter of the ISPP directives used in `[Registry]` whose output equals ISCC's
  preprocessing for all four variants (72 entries each; `--preprocessed` checks that in CI), and
  `--self-test` with 35 cases (modified copies that must fail, and copies that must pass). The
  tables of 3.3 and 3.4 followed with contract revision 2 (S-WP10, `921360a`: the window limits
  against `MinGameWindowWidth` ... `MaxGameWindowHeight`, the GPU preference entries; 3.7 also
  reads `OnlyBelowVersion` and `(opt-in)` since `727bc93`; 55 self-test cases, ADR 0010).
- **Point 3 and 4** were implemented by S-WP1 and S-WP2 (`ci/compare_contract.py`, the encoding and
  message checks of `ci/check_messages.py`).
- **Point 5:** `[Setup] SetupLogging=yes`. Inno Setup 6.2.2 (`Main.pas`) starts logging after the
  elevation, in the elevated process, and uses a file name given with `/LOG` instead of
  `%TEMP%\Setup Log <yyyy-mm-dd> #<nnn>.txt`; the uninstaller keeps its default (`UninstallLogging`
  is not set). README "Support" (where the log is, also after over-the-shoulder elevation, and to
  check it for user names before posting it), ARCHITECTURE section 6, rule 6 of the test plan and
  TP-30 (b) to (e). Real-data comparison (maintainers only, never committed: EE and NeoEE built
  with ISCC from the reconstructed 1.7.2 data, official AppIds, unsigned, dumped with innoextract)
  against the build of the state before (the contract check commit): the only difference in the
  setups is the header option `setup logging`; compiled code (EE 121005 bytes, NeoEE 125700
  bytes, same SHA-1), messages, files, data, registry, tasks, components and run entries are
  identical. In NeoEE the compressed header block is 216 bytes longer (LZMA of the changed
  header), which moves the offset of `Setup.e32` behind it; its CRC32 is unchanged.
- **Point 6, the redirect probe.** A tiny probe setup compiled with ISCC 6.2.2 (not in the
  repository) calls `DownloadTemporaryFile` against two local servers: HTTPS on
  `127.0.0.1:18443` with a certificate of a probe CA that only a copy of the Wine prefix trusts (the
  CA in the root store of the current user of that prefix,
  `HKCU\Software\Microsoft\SystemCertificates\Root`; Wine fills the machine store with the roots of
  the host), and plain HTTP on `127.0.0.1:18080`. It ran inside a new network namespace that has only the
  loopback interface (`unshare -n`: no route, a connection to an outside address fails with
  "Network is unreachable"), without any proxy setting; both servers logged every request with its
  client address, and every request came from `127.0.0.1`. Results (Wine 9.0):

  | Case | Request | Result |
  |---|---|---|
  | control: certificate trusted | `https://127.0.0.1:18443/ok` -> `200` | downloaded, body of the HTTPS server |
  | control: redirect within HTTPS | `302` -> `https://127.0.0.1:18443/ok` | followed, body of the HTTPS server |
  | redirect to HTTP | `302`, `301`, `307`, `308` -> `http://127.0.0.1:18080/target/...` | **followed** in all four cases, body of the HTTP server, no exception |
  | negative control: CA removed from the store | all of the above | every case failed at the TLS handshake (`Error sending data: (12157)`), no request reached a server |

  Server log of the `302` case: `tls 127.0.0.1:50900 GET /redir302-http/b HTTP/1.1`, then
  `plain 127.0.0.1:60116 GET /target/b HTTP/1.1`. The WinHTTP trace shows why this is not a Wine
  artefact: for every request the Delphi HTTP client in `Setup.e32` sets
  `WINHTTP_OPTION_DISABLE_FEATURE` with `WINHTTP_DISABLE_REDIRECTS` (`WinHttpSetOption(..., 63,
  ...)`, value `0x2`), so WinHTTP returns the `302` itself and its default policy against
  `https://` -> `http://` never applies; after reading the status and the `Location` header the
  client closes the request and opens a new one itself (`WinHttpConnect(..., "127.0.0.1", 18080)`,
  `WinHttpOpenRequest(..., "/target/b", ..., 0)`, i.e. without `WINHTTP_FLAG_SECURE`). The same
  compiled client runs on Windows, so the result holds there too. A second run with
  `downloads.iss` itself (a copy of `utils.iss` whose server URLs point to the loopback servers,
  the download policy unchanged) shows what the setup logs for an unpinned file that the HTTPS
  server redirects to HTTP:

  ```
  Online file registered, TLS-verified, not pinned: Game/de/EE/Data/data.ssa
  Downloading temporary file from https://127.0.0.1:18443/localized/Game/de/EE/Data/data.ssa: C:\users\root\Temp\is-PUB53.tmp\EE\Data\data.ssa
  Online file downloaded, TLS-verified, size checked: https://127.0.0.1:18443/localized/Game/de/EE/Data/data.ssa
  Online file accepted, TLS-verified, not pinned: Game/de/EE/Data/data.ssa (SHA-256 ba8f63dd5e8be73fad3860f965c91afc3e27e4ddf48844b66018677b3c8f7779)
  ```

  The SHA-256 is that of the body of the HTTP server. Result: **the client follows the redirect**,
  so both measures of point 6 apply:
  - `ci/build.ps1` warns in a release build (`TestID` 0, also without `-TestID`) with every online
    file the setups download without a pin, per product. `Get-OnlineFiles` (`ci/build_helpers.ps1`)
    reads them from the code of `RegisterOnlineFiles` and the procedures it calls, the game
    languages and `CodeFileExtensions`, the same source the setup uses; a statement or directive it
    does not understand stops the build, also the placeholder build of CI, which only prints the
    number. `Get-UnpinnedOnlineFiles` keeps the data files whose pin path is not in the hash list
    of the same build. With the 1.7.2 data: 110 paths per product (voices, campaigns, movie of 10
    languages), the same as the independent simulation of the real-data analysis. Tested by
    `ci/tests/build_helpers.tests.ps1` against the real script, against changed copies and in dry
    runs of `build.ps1`.
  - [SERVER-OPERATIONS.md](../SERVER-OPERATIONS.md): requirement 4 states the result; section 6
    recommends pinning the files known at build time, with the trade-off. No hard release
    criterion (second plan review, K6).

  Not done: detecting the redirect in the setup. Pascal Script of 6.2.2 gets neither the final URL
  nor a hook into the redirect of `DownloadTemporaryFile`, so the log keeps naming the requested
  `https://` URL; the operator rule and the pins are the mitigation.

## Alternatives considered

- **Generate the contract tables from the script:** the contract is prose shared with the launcher;
  a check keeps it human-written.
- **Checksums only on the website:** they would not be reproducible from the build.
