# 0002. Stay on Inno Setup 6.2.2

- Status: Accepted
- Date: 2026-10-02
- Requirements: D2
- Revised: 2026-10-02, plan review before implementation (`UTF8Encode` is not available; every API
  listed below is now proven by a probe compile)

## Context

The releases up to 1.7.2 and the refactor branch are built with Inno Setup 6.2.2 (2023-02-15). The
current release is 6.7.3 (2026-05-26). A newer version would bring SHA-256 in the preprocessor,
UTF-8 files without BOM, dark mode and `[Files]` downloads. The constraint for a switch: the setups
must still run on Windows 7 SP1, and the compiler must install in CI (Chocolatey) and locally (Wine);
a switch would be a work package of its own with a full re-verification against the real data.

## Decision

v2 stays on **Inno Setup 6.2.2**. CI keeps `choco install innosetup --version=6.2.2` and
`ci/build.ps1 -RequireVersion 6.2.2`. Everything v2 needs exists in 6.2.2 (see Evidence). The
decision is revisited when one of the triggers below occurs.

## Evidence

Source: the official revision history (`https://jrsoftware.org/files/is6-whatsnew.htm`, fetched
2026-10-02) and the 6.2.2 sources (`jrsoftware/issrc`, tag `is-6_2_2`).

Needed by v2 and present in 6.2.2:

- `CreateDownloadPage`/`TDownloadWizardPage` and `DownloadTemporaryFile(Url, BaseName,
  RequiredSHA256OfFile, OnDownloadProgress)` (since 6.1; `ScriptFunc_R.pas`, `Install.pas` of
  6.2.2), see [ADR 0003](0003-built-in-downloads-instead-of-idp.md).
- `GetSHA256OfFile` at run time (already used by `downloads.iss`), `SaveStringToFile`,
  `RenameFile`, `AfterInstall` with `CurrentFileName`, `[Registry]` `HKA` with
  `uninsdeletekey`/`uninsdeletekeyifempty`, `CreateOutputProgressPage` (`SetProgress` processes
  window messages), `RegWriteDWordValue` on `HKA`, `MinVersion` on `[Tasks]`, the
  `WinHttpRequest.Option[9]` property assignment, `TDownloadWizardPage.AbortedByUser`.
- **Not** present: `UTF8Encode` (`ScriptFunc_R.pas` does not register it; ISCC 6.2.2 reports
  "Unknown identifier 'UTF8Encode'"), hence the ASCII manifest of
  [ADR 0004](0004-install-record-and-integrity-manifest.md).
- Proof: a probe script that uses every API of this list compiles with ISCC 6.2.2 under Wine
  (2026-10-02, plan review; compiled, not run). Each work package that uses one of them proves the
  run-time behaviour with its unit tests or its test plan case.

Breaking changes of newer versions that affect this script:

| Version | Change (vendor history) | Effect on this script |
|---|---|---|
| 6.3.0 (2024-06-09) | "Support for Windows Vista, Windows Server 2008, and the Itanium architecture removed"; `ia64` identifier removed; `x64` deprecated in favour of `x64os`/`x64compatible` | `ArchitecturesInstallIn64BitMode=x64 arm64 ia64` no longer compiles; the meaning of the 64-bit install mode (registry view of the uninstall key and of every HKLM value, `{sys}`) must be re-checked on Arm64 |
| 6.4.0 (2025-01-09) | "support for the long-deprecated [Setup] section directive WindowVisible ... has been dropped ... Pascal Scripting support object MainForm has been removed" | the setup background (`WindowVisible=True`, `CreateSetupBackground` on `MainForm`) does not compile: a visible change of the setup |
| 6.5.0 to 6.5.2 | `[Files]` download flag (6.5.0), downloads in a secondary thread (6.5.1), TLS 1.3 and no TLS 1.0/1.1 for downloads (6.5.2) | no blocker; nice to have |
| 6.6.0 (2025-11-11) | `WizardResizable` dropped; dark mode | no blocker |

Windows 7 SP1 is still the minimum OS of the newest version (6.3.0 made it the minimum, no later
entry changes it), so the OS range alone would not block a switch. What blocks it in v2 is the cost:
the removed background (a visible change the community did not ask for), the architecture change
and a complete new real-data verification, for features v2 can do without.

Toolchain: 6.2.2 installs non-interactively under Wine (`/root/.wine-inno`, used by
`verify_setup.sh` and the real-data builds) and in CI (`choco install innosetup --version=6.2.2`).
The installability of newer versions was not tested, because they are not adopted.

## Consequences

- The hash list of `data\localized-text` keeps being written before compiling
  (`ci/build.ps1`), because the 6.2 preprocessor has no SHA-256.
- Own `.iss` files stay UTF-8 with BOM (6.2 reads BOM-less files as ANSI).
- `SaveStringsToUTF8File` of 6.2.2 writes a BOM and CRLF (`FileClass.pas`,
  `TTextFileWriter.DoWrite`); files that must not have a BOM are written with `UTF8Encode` +
  `SaveStringToFile` ([ADR 0004](0004-install-record-and-integrity-manifest.md)).
- Downloads use TLS 1.0 to 1.2 (`SetUserAgentAndSecureProtocols` in 6.2.2), never TLS 1.3; the
  servers support TLS 1.2.

## Revisit when

- a security fix relevant to this setup is only available in a newer version,
- Windows drops something 6.2.2 relies on,
- or the background image is given up anyway; then a switch to the current 6.x is its own package:
  remove `WindowVisible`/`MainForm`/`ia64`, use `x64compatible`, rebuild, compare all dumps, test on
  Windows 7 SP1, 10, 11 and Arm64.

## Alternatives considered

- **6.3.x** (last version with `MainForm`): only `ia64`/`x64` changes and SHA-256 in ISPP; still a
  full re-verification for little gain.
- **Current 6.7.x:** see above.
