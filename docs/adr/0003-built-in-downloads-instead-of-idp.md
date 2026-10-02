# 0003. Replace the Inno Download Plugin by Inno Setup's built-in downloads

- Status: Accepted (implemented by S-WP3)
- Date: 2026-10-02
- Requirements: D3, R16, R17
- Revised: 2026-10-02, plan review before implementation (stop button vs. mirror, size check only
  with `Content-Length`, removal of IDP as a separate commit)

## Context

The localized files (Language.dll, lobby texts, voices, campaigns, intro movie) are downloaded with
the Inno Download Plugin (IDP 1.6.0, `internal/lib/idp`): a third-party DLL from 2013/2014 that is
no longer maintained, ships as a binary that was "compiled manually using VS2005 on XP" (CHANGELOG
1.5.0) and cannot be rebuilt reproducibly. Inno Setup has had its own download support since 6.1.
The v1 download policy must stay exactly as it is:

- files that can contain code (`CodeFileExtensions`) only with a compile-time SHA-256 pin,
- data files without pin only over HTTPS with certificate validation,
- never an `http://` URL, main server and mirror alike,
- mirror fallback,
- a clear localized notice of every selected file that was not installed from the download.

## Decision

Use Inno Setup 6.2.2's built-in download support and remove IDP:

- `InitializeWizard` creates one download page with `CreateDownloadPage` (title and description as
  custom messages, progress callback for the log).
- `NextButtonClick(wpReady)`, after `RegisterOnlineFiles`, runs `DownloadOnlineFiles`: for every
  registered URL (a file needed in both game folders is downloaded once and copied, as before) it
  clears the page, adds the one file and calls `Download` inside `try ... except`; on any failure it
  tries the mirror once, if the mirror is allowed for that file (same policy result, i.e. never
  `http://` for an unpinned file). Downloading file by file is needed because
  `TDownloadWizardPage.Download` stops at the first failing file.
- The pin is **not** passed to Inno Setup: the code checks the SHA-256 right after each download, so
  that a mismatch can be told apart from a network error (precise notice, `DownloadFileRejected`),
  the file is deleted and the mirror is tried. Without a pin Inno Setup compares the received size
  with `Content-Length` **if the server sends one** (`Install.pas`: only when `ProgressMax > 0`); a
  chunked answer is accepted without a size check, which the setup logs for that file. The operator
  guide requires `Content-Length` for `/localized/`.
- **The stop button ends all downloads, it never starts the mirror.** `TDownloadWizardPage.Download`
  resets `AbortedByUser` at the start of every call, and a stop raises an exception like a network
  error. So, directly after every exception of `Download`, the code copies `AbortedByUser` into its
  own flag `DownloadsStoppedByUser`; once it is set, no further URL is requested (no mirror, no
  next file), every remaining file counts as skipped, the installation continues with the files of
  the setup, and the notice lists everything that was skipped (the old IDP behaviour with
  `AllowContinue=1`). What happens after each attempt is decided by a pure, unit-tested helper in
  `utils.iss`, `NextDownloadAction(Outcome, MirrorAllowed, MirrorTried, StoppedByUser)`, with the
  outcomes success, failure and pin mismatch and the actions accept, try mirror, give up on this
  file and stop all; the tests cover success, network error, pin mismatch, stop at the main server,
  stop at the mirror and a file without an allowed mirror.
- IDP (`internal/lib/idp`, its `#include` and `[Files]` entry) is removed in a separate, last commit
  of the package, so that the switch can be reverted on its own if the Windows test finds a problem
  with the built-in engine.
- `VerifyDownloadedFiles` (at `ssInstall`) stays as it is apart from asking the download list
  instead of `idpFileDownloaded`: it checks the pins again and moves accepted files to
  `{tmp}\verified`, the only folder `[Files]` installs downloads from.
- `SelectOnlineFilesServer` keeps choosing the server with the short WinHTTP probe of `HttpGet`
  before any download.

## Evidence

Inno Setup 6.2.2 sources (`jrsoftware/issrc`, tag `is-6_2_2`) and the shipped `Setup.e32`:

- `Projects/ScriptFunc_R.pas`: `CREATEDOWNLOADPAGE`, `DOWNLOADTEMPORARYFILE(Url, BaseName,
  RequiredSHA256OfFile, OnDownloadProgress)`, `SETDOWNLOADCREDENTIALS` are registered.
- `Projects/ScriptDlg.pas`, `TDownloadWizardPage.Download`: loops over the files and calls
  `DownloadTemporaryFile` without catching exceptions, so the first failure ends the whole batch
  (hence one file per call); `AbortedByUser` is set by the stop button.
- `Projects/Install.pas`, `DownloadTemporaryFile`: a Delphi `THTTPClient` (strings in `Setup.e32`:
  `TWinHTTPClient`, `winhttp.dll`, i.e. WinHTTP underneath) with `SecureProtocols := [TLS1, TLS11,
  TLS12]` set explicitly ("TLS 1.2 isn't enabled by default on older versions of Windows"); no
  `OnValidateServerCertificate` handler is assigned, so a certificate WinHTTP rejects raises an
  exception (`Setup.e32` contains the RTL messages "Server Certificate Invalid or not present" and
  "Server Certificate not accepted"); the source names `https://expired.badssl.com/` and
  `https://self-signed.badssl.com/` as test cases. HTTP status outside 200 to 299 raises; with a
  required SHA-256 the hash is compared, otherwise the received size is compared with the announced
  size; the file is written to a temporary name and only renamed to `{tmp}\<BaseName>` when
  complete; `BaseName` may contain subfolders (`ForceDirectories`).
- The vendor documentation of the same download code (6.5.0, `[Files]` download flag): "Supports
  HTTPS (but not expired or self-signed certificates) and HTTP. Redirects are automatically
  followed and proxy settings are automatically used."
- Messages of the download page (`DownloadingLabel`, `ButtonStopDownload`, `StopDownload`,
  `ErrorDownloadAborted`, `ErrorDownloadFailed`, `ErrorFileHash1/2`, `ErrorFileSize`,
  `ErrorProgress`) exist in `Default.isl` and every official 6.2.2 language file and in the
  unofficial Chinese files of `internal/unofficial_isl/IS6`; the unofficial `Korean.isl` (6.0.0)
  lacks them, so Korean shows these texts in English.

Not verifiable here (no installer is run outside Windows tests): the runtime behaviour on Windows,
in particular the rejection of `files.empireearth.eu`'s current certificate
(`CN=cluster131.hosting.ovh.net`, see [ADR 0006](0006-strict-tls-and-server-certificates.md)) and
the silent mode. Both are cases of the test plan.

## Consequences

- 632 KB of third-party binaries and their `[Files]` entry leave the repository and the setup; the
  installed game files do not change.
- **Redirects:** `THTTPClient` follows redirects automatically, and nothing documents that it refuses
  one from `https://` to `http://`, so the design assumes it follows those too; IDP uses WinINet,
  which refuses those unless `INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTP` is set (Microsoft documentation;
  a disassembly of `idp.dll` 1.6.0 found no use of the flag, not tested at run time). Pinned files
  are unaffected (the hash decides). For unpinned data files only the operator of the HTTPS server can send such a
  redirect (an attacker on the network cannot inject one into a validated TLS connection), and the
  policy already trusts that operator with the content of these files. Remaining risk: a
  misconfigured server redirect followed by an attacker on the plain-HTTP leg. Mitigation: the
  operator guide ([ADR 0006](0006-strict-tls-and-server-certificates.md), README) requires that the
  file servers never redirect to `http://`; the setup itself never builds an `http://` URL.
- **Timeouts:** `THTTPClient`'s timeouts cannot be set from Pascal Script in 6.2.2 (IDP used 15 s
  connect / 30 s transfer). The short probe of `SelectOnlineFilesServer` keeps the common case
  (server down) fast; a server that answers the probe and then stalls costs the RTL timeout once per
  file before the mirror is tried.
- The page is responsive during a transfer (the progress callback processes messages) and has a stop
  button; IDP's detailed mode and its error dialog with the URL list are gone, the final notice
  lists the files instead.
- Unit tests keep covering the policy (`GetOnlineFileCheck`, `IsCodeFileName`, `IsHttpsUrl`) and the
  decision after each attempt (`NextDownloadAction`); the download loop itself is tested on Windows
  (`docs/TEST-PLAN.de.md`: main server with invalid certificate, mirror, offline, stop button at the
  main server and at the mirror, `/VERYSILENT`, Korean).

## Alternatives considered

- **Keep IDP:** unmaintained binary, cannot be rebuilt, ANSI and Unicode builds from 2014.
- **One `TDownloadWizardPage` batch for all files:** simpler, but the first failure would cancel all
  other downloads and there would be no per-file mirror fallback.
- **Pass the pin to `DownloadTemporaryFile`:** Inno Setup would check it, but a mismatch would only be
  visible as a localized exception text; the own check after the download keeps the precise notice.
- **Own downloader on `WinHttp.WinHttpRequest` (COM):** refuses HTTPS to HTTP redirects by default,
  but is synchronous (the wizard freezes during a 30 MB movie), has no progress and no stop button,
  and would need `ADODB.Stream` to write binary data.
- **`[Files]` `download` flag:** only from Inno Setup 6.5.0 ([ADR 0002](0002-stay-on-inno-setup-6.2.2.md)).
