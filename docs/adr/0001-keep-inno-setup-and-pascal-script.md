# 0001. Keep Inno Setup 6 and Pascal Script, evolve the refactor branch

- Status: Accepted
- Date: 2026-10-02
- Requirements: D1
- Revised: 2026-10-02, plan review before implementation (`UTF8Encode` removed from the list of
  available functions)

## Context

Setup v2 has to fix the gaps found in the forum study (save-ee.com, 2009 to 2019) and implement the
setup side of the launcher contract. The question was whether to keep the current technology or to
move to another installer technology (Windows Installer/WiX, NSIS, a custom installer).

## Decision

The setup stays an Inno Setup 6 script with Pascal Script `[Code]`. v2 is an evolution of the branch
`refactor/quality-fixes` (setup 1.7.2 plus 104 verified review fixes), not a rewrite. Every behaviour
change is intended, listed in the CHANGELOG and visible as such in the real-data comparison.

## Evidence

- The official setups 1.7.2 were reproduced byte-exactly from the reconstructed game data with the
  upstream script and Inno Setup 6.2.2 (header, all sections, data area). The refactor branch was
  compared entry by entry with them; every difference is classified and intended. This equivalence
  proof only exists for Inno Setup and is the strongest guarantee that v2 installs the same game.
- The community, the existing installations (uninstall keys `{<AppId>}_is1`, update in place with
  `UsePreviousAppDir`) and Empire Earth Diagnostic depend on Inno Setup's AppId-based uninstall key.
  Another technology would orphan these installations or need a migration.
- The setup already has CI (four variants against placeholder assets), unit tests of the Pascal
  helpers (113 tests), a message check and build-helper tests. A rewrite would start from zero.
- Everything v2 needs is available in Inno Setup 6.2.2: `[Registry]` with `HKA` and uninstall flags,
  `AfterInstall`/`CurrentFileName`, `GetSHA256OfFile`, `SaveStringToFile` (ASCII text; `UTF8Encode`
  does not exist in 6.2.2, see [ADR 0002](0002-stay-on-inno-setup-6.2.2.md)), built-in
  downloads with SHA-256 checks ([ADR 0003](0003-built-in-downloads-instead-of-idp.md)).

## Consequences

- Pascal Script limits stay (no generics, no closures, synchronous code). Testable logic is kept in
  pure functions in `utils.iss`, the rest is tested on Windows by the test plan.
- Every package that changes the compiled setup is checked against the previous dumps with the
  real-data tools (local only, game data is never committed).

## Alternatives considered

- **WiX/MSI:** better enterprise deployment, but loses the equivalence proof, the existing uninstall
  keys and the Pascal code (CD-key registration, random map migration, downloads); repair semantics
  of MSI differ from the community's "run the setup again".
- **NSIS:** no advantage over Inno Setup for this project, same migration costs.
- **Rewrite in Inno Setup from zero:** throws away the reviewed and verified state.
