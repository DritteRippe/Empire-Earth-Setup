# 0008. SHA-256 files of the built setups, CI check of the contract, a log of every setup run

- Status: Accepted (implemented by S-WP2)
- Date: 2026-10-02
- Requirements: R14, D5 ("the `GameSettings` block is the source of truth"), R18

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
   `utils.iss` and fails if `docs/CONTRACT.md` differs from them:
   - every value of the `GameSettings` sub (name, type, data, `deletevalue` = class S/D,
     `createvalueifdoesntexist` = class P) and the ending epochs passed to it, against the table of
     contract 3.2;
   - `CodeFileExtensions` against the `code` row of contract 2.4;
   - the flags of `BuildCompatibilityFlags` and the Windows layers of the compatibility entries
     against contract 3.7;
   - `#define ContractVersion` (from S-WP3) against the contract header.
   It runs in the CI workflow next to `check_messages.py` and in the local verification.
3. **Setup log:** `[Setup] SetupLogging=yes`: every run writes `Setup Log <date> #<n>.txt` to the
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
- The check cannot verify the launcher's copy of the contract (no network in CI, contract O12).

## Alternatives considered

- **Generate the contract tables from the script:** the contract is prose shared with the launcher;
  a check keeps it human-written.
- **Checksums only on the website:** they would not be reproducible from the build.
