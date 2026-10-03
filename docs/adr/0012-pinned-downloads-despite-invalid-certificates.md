# 0012. Download pinned online files even from a server with an invalid certificate

- Status: Accepted, implemented (S-WP12, see [Implementation](#implementation))
- Date: 2026-10-03
- Requirements: D3, R16, R17
- Amends: [ADR 0003](0003-built-in-downloads-instead-of-idp.md) (every download with Inno Setup's
  built-in downloads), [ADR 0006](0006-strict-tls-and-server-certificates.md) points 1 and 5 (no
  option to ignore a certificate error; release criterion) and
  [ADR 0008](0008-release-checksums-and-contract-check.md) point 6 (pins of the files known at build
  time)

## Context

The first test of setup v2 on a real laptop logged at the start of the downloads:

```
HTTP GET https://files.empireearth.eu/localized failed: WinHttp.WinHttpRequest: Der Hostname des Zertifikats ist ungültig oder stimmt nicht überein.
HTTP GET https://storage.ee.zocker-160.de/localized failed: ... Der Servername oder die Serveradresse konnte nicht verarbeitet werden.
Unable to reach the online files server! The setup will only use local files...
```

and showed the notice `OnlineFilesUnreachable`: voices and campaigns stayed English. No intro movie
was installed at all: the setup only installs and downloads it with the component "Install intro
videos", which no setup type selects and which was not selected. The facts (2026-10-03):

- `files.empireearth.eu` serves the certificate of its hosting provider,
  `CN=cluster131.hosting.ovh.net`, valid for that name and not for `files.empireearth.eu`
  ([ADR 0006](0006-strict-tls-and-server-certificates.md)); both names resolve to the same address.
- The mirror `storage.ee.zocker-160.de` no longer exists in DNS (NXDOMAIN).
- Setup 1.7.2 called `idpSetOption('InvalidCert', 'Ignore')` and therefore downloaded everything.
- The setups can download 230 server paths (EE 180, NeoEE 50 more). Until now 120 of them had a pin
  from `data\localized-text` (every `Language.dll` and the lobby files, which the setup ships
  itself); the other 110 (the voices `data.ssa`, the campaigns and the localized intro movie of ten
  languages) only exist on the servers and could only be downloaded over a validated certificate.
- Inno Setup 6.2.2 cannot ignore a certificate error in its built-in downloads: its help says of
  `DownloadTemporaryFile` "Supports HTTPS (but not expired or self-signed certificates)",
  `TDownloadWizardPage` has no such option, and `Install.pas` assigns no
  `OnValidateServerCertificate`. Another Inno Setup version is out of scope (D2). The certificate
  option of the `WinHttpRequest` COM object (`Option[4]`, SslErrorIgnoreFlags) is "Not
  implemented" in Wine 9.0 and would hold a whole file (up to 172 MB) in memory.

## Decision

The maintainers decided on 2026-10-03: **pin every online file, and download a pinned file even
from a server whose certificate is invalid**, because its SHA-256 decides whether it is installed,
not the certificate. Files without pin keep the strict rule of ADR 0003 and ADR 0006.

1. **Every online file is pinned** in `pins/online-files.txt`, checked in: one line per server path,
   `<SHA-256, 64 lowercase hex digits> <size in bytes> <server path>`, sorted ordinally, UTF-8
   without BOM, LF, `#` comment lines. It holds hashes and sizes only, no game data (D6).
   `downloads.iss` compiles it with ISPP (a malformed line stops the build). The hash list of the
   build (`data\localized-text.sha256`) still applies first, so that a test build can pin a file
   differently (TEST-PLAN TP-13, TP-16); the size then comes from `pins/online-files.txt` only if both
   pin the same file.
2. **Checks of the list:** `ci/online_pins.ps1` (format, every online file of EE and NeoEE pinned as
   the code of `RegisterOnlineFiles` registers it, no other path; `-SelfTest`; CI) and
   `ci/build.ps1`: a pinned path that no setup downloads stops every build, an online file without a
   pin stops a release build (`TestID` 0, also the placeholder build of CI) and is a warning in a test
   build, and without `-Placeholders` a file that `data\localized-text` pins differently stops a
   release build, as does a file with the same SHA-256 there whose pinned size is not its size (the
   setup takes the size from `pins/online-files.txt` and would reject the right file). `ci/online_pins.ps1 -Update -Source <copy of /localized/> [-CrossCheck <second
   copy>]` writes the list.
3. **State of each file server** (`SelectOnlineFilesServer`, `ClassifyOnlineFilesServer`): the
   request with certificate validation (`GetHttpStatus`, as before) gets an answer: **verified**.
   Otherwise, and only if the setup has pins, one GET request without certificate validation
   (`GetHttpStatusIgnoringCertificate`; the answer is never read): an HTTP answer means
   **certificate invalid**, none **unreachable**. The mirror is not asked while the main server is
   verified (**not checked**: it is only used with the built-in downloads, which validate its
   certificate), so that path stays as it was. The server in the better state comes first
   (verified, then certificate invalid, then unreachable; the main server on a tie); the notice
   `OnlineFilesUnreachable` only comes when neither server can be used.
4. **Transport per file and server** (`GetOnlineFileTransport`, unit-tested for every combination):

   | File | verified or not checked | certificate invalid | unreachable |
   |---|---|---|---|
   | pinned (also `Language.dll`) | built-in download | **WinHTTP, certificate errors ignored** | none |
   | data file without pin | built-in download, after the redirect check | **none** | none |
   | file with code without pin | none | none | none |

   A file without pin on a server whose certificate is invalid is not requested at all and is
   named in the notice with the new message `DownloadFileServerCertificate` (en, de, fr). The other
   server is only tried for a file if it has a transport for it.
5. **The WinHTTP transport** (`DownloadPinnedFileWinHttp`; `winhttp.dll` directly, declared in
   `utils.iss`): `WINHTTP_OPTION_SECURITY_FLAGS` = `$3300` (unknown certification authority, wrong
   usage, certificate for another host name, expired; `ApplyCertificateErrorIgnoreFlags`, the only
   place), the proxy of the system (`WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY` from Windows 8.1, else
   the WinHTTP default), TLS 1.0 to 1.2 asked for explicitly below Windows 8.1 (option 84, `$A80`,
   like `HttpRequest`), timeouts 8 s name resolution, 15 s connect and send, 30 s per read. The body
   is streamed in reads of 64 KB into `{tmp}\<file>.part` (constant memory); the file is kept only if
   the status is 200, the size is the pinned size and the SHA-256 matches the pin, otherwise it is
   deleted and counts as a pin mismatch (`DownloadFileRejected`) or a failure. The progress bar
   shows the pinned size, and the stop button works between two reads (`SetProgress` processes the
   messages of the page). The function raises an exception for a file without pin.
6. **Size limit on both transports** (`IsDownloadSizeAcceptable`): a pinned download stops as soon
   as the announced size (`Content-Length`) is not the pinned size or more bytes arrive than pinned,
   so a server cannot fill the disk (built-in downloads: in the progress callback, which Inno Setup
   calls at least every 512 KB). Without a known size only 1 GiB applies.
7. **Redirects:** for a pinned file the SHA-256 decides, whatever path it took, so it may come over
   any transport and redirect. WinHTTP follows redirects itself with its default policy (to
   `https://` with the same options, never to `http://`: error 12156 in the probe); the built-in
   downloads still follow a redirect to `http://` (ADR 0008 point 6). For files without pin
   nothing changes: the check of the redirects before the download (`CheckOnlineFileRedirects`),
   never from an `http://` URL, never from a server whose certificate is invalid.
8. **Lint:** `ci/check_tls_policy.py` (with `--self-test`, CI) fails if the flags appear outside
   `ApplyCertificateErrorIgnoreFlags`, if that is called anywhere but in `OpenWinHttpRequest`, if
   `OpenWinHttpRequest` ignores certificate errors for any caller but the probe and the pinned
   download, if those are called from elsewhere, if the pinned download loses its guard against
   files without pin, if the pinned transport is chosen for a file without pin, or if the
   certificate option of the COM object is used. It reads every script compiled into the setup:
   the root folder and every file of an `#include` line, also `internal/lib/bass/bass.iss`. So
   that a call cannot escape these rules under another name, it also fails if a function of
   `winhttp.dll` is declared outside `utils.iss`, under another name than its own (an alias), twice
   or with another external text, if `winhttp.dll` is named anywhere else, if the address of a
   WinHTTP function is taken, if another HTTP stack appears (`wininet`, `urlmon`, `XMLHTTP`), if
   `OpenWinHttpRequest` sets another option than the named constant `WinHttpOptionSecureProtocols`
   (a composed value such as `30 + 1` included), or if a named option constant has another value.
9. **Operators:** a pinned file that changes on a server is discarded by every setup built before;
   the pins must be regenerated and a new setup released ([SERVER-OPERATIONS.md](../SERVER-OPERATIONS.md),
   section 6). A valid certificate for `files.empireearth.eu` is still wanted: then everything comes
   over validated TLS again, and files without pin work too.

## Evidence

- **The pins** (2026-10-03, a separate step of this package, no file stored): every one of the 230
  server paths streamed from `https://cluster131.hosting.ovh.net/localized/` with the header
  `Host: files.empireearth.eu` and a validated certificate into SHA-256 and a byte counter; both names
  resolve to the same address, and without the header the server answers 404. All 120 paths with a
  pin from the 1.7.2 data match it; three small files fetched over `http://files.empireearth.eu`
  have the same bytes, and for all 110 others the `Content-Length` there equals the streamed size.
  4,879,083,159 bytes for the 110 files, 84 distinct contents; 29 of them are byte-identical to the
  English files of the setup (all of `ko` and `pt-BR`, parts of `zh-CN`, `zh-TW` and `ru`).
- **Design probe** (Wine 9.0, loopback servers with a certificate of a trusted probe CA for the wrong
  host name): the built-in download and the COM object with validation refuse it (12157), COM
  `Option[4]` is "Not implemented", the flat WinHTTP API with `$3300` downloads 5 MB in 64 KB reads
  with the original SHA-256.
- **Inno Setup 6.2.2** (`ScriptDlg.pas`): `TOutputProgressWizardPage.SetProgress` calls
  `ProcessMsgs`, so the stop button of the page is processed between two reads;
  `TDownloadWizardPage.Download` resets `AbortedByUser`, nothing else does.
- **Laptop retest 2026-10-03** (TP-10 (a), installers built from `02afce0`, on Windows 10.0.26300
  (Windows 11), German, EE and AoC, recommended settings, telemetry off): EE-admin and NeoEE-admin
  passed. Main server "certificate invalid" (answers only without validation), mirror without DNS
  (WinHTTP 12007, not used); EE 17 and NeoEE 18 pinned downloads over WinHTTP, every SHA-256 and
  size equal to its pin, `All 20` and `All 22 online files accepted` (these counts include the
  shared lobby files copied for AoC), no notice. No intro movie: its component is not part of the
  recommended settings.

## Consequences

- Players get the voices, campaigns and intro movie of their language (the movie with the component
  "Install intro videos") again from `files.empireearth.eu`, as long as the files there are the
  pinned ones. A file that changes there is discarded until a setup with new pins is released
  (operator rule: version files instead of overwriting them).
- Without certificate validation, someone on the network path can see which files are requested
  and can block or damage downloads (they are discarded, the setup installs its own files), but
  cannot get anything installed that is not the pinned file. Setup 1.7.2 accepted any file in that
  situation.
- Every online file is pinned, so a release build stops when the code registers a file the list
  does not pin; the CI placeholder build checks the list as well.
- Two requests more only when a server fails the validated probe (one per server); the mirror is
  not asked while the main server is verified.
- What the Wine probe cannot show: the behaviour of the flags on real Windows, where the error of a
  wrong host name is 12038, not Wine's 12157. The laptop retest shows it on Windows 11; Windows 10
  and 7 and the downloads behind a proxy remain open, the test plan checks them (TP-10, TP-17). The
  handles are 32-bit (setups of Inno Setup 6.2.2 are 32-bit).
- Unchanged and out of scope: languages whose server files are the English ones (ko, pt-BR) still
  download about 444 MiB that change nothing.

## Alternatives considered

- **Keep the strict rule:** no localized content until the operators fix the certificate.
- **Ignore certificate errors for every file, as 1.7.2 did:** anyone on the network path could
  replace the files without pin.
- **`WinHttpRequest` (COM) with `Option[4]` and `ADODB.Stream`:** the whole file in memory (up to
  about 500 MB in the 32-bit setup for 172 MB), no progress, no stop button, not testable under Wine,
  and the pattern of downloader malware that virus scanners look for.
- **Request `cluster131.hosting.ovh.net` with the header `Host: files.empireearth.eu`:** valid
  certificate today, but it depends on an internal name of the hosting provider that can change with
  any migration, and the built-in downloads cannot set a header.
- **Pins only for the 110 server-only files:** the list could then not be checked for completeness
  without the game data; with every server path it is checked in CI.

## Implementation

S-WP12, 2026-10-03, four commits on `v2`:

1. `utils.iss`: the pure helpers `ClassifyOnlineFilesServer`, `ChooseOnlineFilesServerOrder`,
   `GetOnlineFileTransport`, `IsDownloadSizeAcceptable`, `ParsePinnedSize`, `SplitDownloadUrl`,
   `DescribeWinHttpError`, `GetWinHttpAccessType`; the WinHTTP declarations (delay loaded),
   `ApplyCertificateErrorIgnoreFlags`, `OpenWinHttpRequest`, `SendWinHttpRequest`,
   `CloseWinHttpRequest`, `GetHttpStatusIgnoringCertificate`. Unit tests for every combination of
   the states and transports and a run-time test that opens WinHTTP handles for `127.0.0.1:9` and
   sets the flags without connecting (a mutation to option 9999 makes it fail).
2. `pins/online-files.txt` (230 pins), the ISPP parser and `GetOnlineFilePin` in `downloads.iss`,
   `Read-OnlinePins`, `Format-OnlinePinList`, `Write-OnlinePins`, `Test-OnlinePinCoverage`,
   `Test-PinConsistency` in `ci/build_helpers.ps1` with tests, the checks of `ci/build.ps1`,
   `ci/online_pins.ps1` with its self-test, CI; the end-to-end check expects every download pinned.
3. The server states, the transports, `DownloadPinnedFileWinHttp`, the size limit, the message
   `DownloadFileServerCertificate`, the log lines, `ci/check_tls_policy.py` with its self-test, CI.
4. The documentation (this record, the notes in ADR 0003, 0006 and 0008, SERVER-OPERATIONS,
   README, CHANGELOG, TRANSLATING, ARCHITECTURE, TEST-PLAN).

Run-time probe under Wine 9.0 (not in the repository: a probe setup with `downloads.iss` unchanged
and `utils.iss` with the two server URLs pointed to loopback servers, run in a network namespace
with only the loopback interface; a copy of the Wine prefix trusts the probe CA): 87 expectations,
all met.

| Scenario | Result |
|---|---|
| A: main server with a certificate for another host name, mirror without listener (the laptop case) | main server "certificate invalid", mirror unused; every pinned file from the main server over WinHTTP, verified by its pin (lobby files, `Language.dll`, a path with a space requested as `%20`, a redirect to `https://` followed, 64 MiB in 3.6 s without more private memory); the file without pin refused with `DownloadFileServerCertificate` and not requested at all; a file with other bytes rejected by its SHA-256, one with another `Content-Length` before its body, one without `Content-Length` and more bytes than pinned during it; a redirect to `http://` refused by WinHTTP (12156), no request reached the http server; a server that stalls after the headers failed after 30 s; no `.part` file left |
| A with the stop button (clicked during the 64 MiB file) | `stopped by the user ... (524288 bytes received)`, no further request, the rest skipped (`DownloadFileSkipped`) |
| B: main server with a valid certificate | unchanged path: built-in downloads only, no request without validation, the mirror not asked, the redirect check before the file without pin, which is accepted over validated TLS; the size limit stops a file with another `Content-Length` in the progress callback |
| C: main server with the wrong host name, mirror valid | mirror first; a pinned file missing there comes from the main server over WinHTTP; the file without pin only from the mirror |
| D: no pins | no request without validation, `OnlineFilesUnreachable` path, no request reached a server |
| E: neither server listens | both "no answer", no server |
