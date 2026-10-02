# Architecture decision records

Each file records one decision of the setup: its context, the decision, the evidence it is based on,
its consequences and the alternatives that were rejected. A record is not edited once it is
accepted; a later decision that changes it is a new record that supersedes it (and the old one gets
"Superseded by NNNN" as status). Until the work package that implements a record is
committed, the record may still be corrected (review findings); every such correction is named in
its "Revised" line. When its work package is complete, the status becomes "Accepted, implemented"
and an "Implementation" section records what was built and how it was verified. The overview of
the setup is [ARCHITECTURE.md](../ARCHITECTURE.md).

| No. | Decision | Status |
|---|---|---|
| [0001](0001-keep-inno-setup-and-pascal-script.md) | Keep Inno Setup 6 and Pascal Script, evolve the refactor branch | Accepted |
| [0002](0002-stay-on-inno-setup-6.2.2.md) | Stay on Inno Setup 6.2.2 | Accepted |
| [0003](0003-built-in-downloads-instead-of-idp.md) | Replace the Inno Download Plugin by Inno Setup's built-in downloads | Accepted |
| [0004](0004-install-record-and-integrity-manifest.md) | How the setup writes the install record, `install.ini`, the integrity manifest and the defaults marker | Accepted |
| [0005](0005-compatibility-and-wrapper-defaults.md) | No compatibility values on Windows Vista/7; keep the DirectX wrapper preselection | Accepted |
| [0006](0006-strict-tls-and-server-certificates.md) | Strict TLS everywhere, TLS 1.2 on Windows 7, operator guide for the file server certificate | Accepted, implemented |
| [0007](0007-environment-warnings.md) | Read-only warnings for low resolution, foreign installations and a shared EE/NeoEE folder | Accepted |
| [0008](0008-release-checksums-and-contract-check.md) | SHA-256 files of the built setups, CI check of the contract, a log of every setup run | Accepted |

Template for a new record (`NNNN-short-title.md`, next free number):

```markdown
# NNNN. Title

- Status: Proposed | Accepted | Accepted, implemented | Superseded by NNNN
- Date: yyyy-mm-dd
- Requirements: ...
- Revised: (optional) yyyy-mm-dd, what changed before implementation

## Context
## Decision
## Evidence
## Consequences
## Alternatives considered
```
