# 0008. SHA-256 files of the built setups, CI check of the contract, a log of every setup run

- Status: Accepted (implemented by S-WP5; copy check by S-WP1, source checks by S-WP2)
- Date: 2026-10-02
- Requirements: R14, D5 ("the `GameSettings` block is the source of truth"), R18, contract O12
- Revised: 2026-10-02, plan review before implementation (the check reads only tables of the
  contract; `[Files]` flag lint; local copy check of the contract; encoding and message checks of
  every own script)

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
   - `#define ContractVersion` (added by S-WP5) against the contract header table.
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
4. **Source checks** (S-WP2): every own top-level `*.iss` starts with the UTF-8 BOM and has only
   CRLF line ends (Inno Setup 6.2 reads BOM-less files as ANSI); `check_messages.py` takes its list
   of own scripts from the `#include` lines of `setup_is6.iss` plus the root `*.iss` files, minus
   third-party code under `internal/`, so that a new module is checked from its first commit.
5. **Setup log:** `[Setup] SetupLogging=yes`: every run writes `Setup Log <date> #<n>.txt` to the
   user's temporary folder (the log lists no secrets, see ARCHITECTURE 6). The README and the test
   plan say where to find it.

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

## Alternatives considered

- **Generate the contract tables from the script:** the contract is prose shared with the launcher;
  a check keeps it human-written.
- **Checksums only on the website:** they would not be reproducible from the build.
