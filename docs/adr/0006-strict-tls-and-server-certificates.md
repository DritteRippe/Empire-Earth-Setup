# 0006. Strict TLS everywhere, TLS 1.2 on Windows 7, operator guide for the file server certificate

- Status: Accepted (implemented by S-WP1)
- Date: 2026-10-02
- Requirements: R16, D3

## Context

The setup talks to the network in two ways: `HttpGet` in `utils.iss` (WinHTTP COM object
`WinHttp.WinHttpRequest.5.1`: update API, reachability probe of the file servers, statistics with
consent) and the downloads of the localized files ([ADR 0003](0003-built-in-downloads-instead-of-idp.md)).
Both validate certificates and never fall back to HTTP.

`files.empireearth.eu`, the main file server, currently presents the hosting provider's default
certificate `CN=cluster131.hosting.ovh.net` (observed 2026-10-02; the other hosts `empireearth.eu`,
`api.empireearth.eu`, `neoee.net` have valid certificates). Setups up to 1.7.2 did not notice
because they left IDP's certificate handling at its default instead of stopping on invalid
certificates; since the refactor every download from the main server fails and the setup falls back
to the mirror `storage.ee.zocker-160.de`.

Windows 7 SP1 and Windows 8/Server 2012 do not offer TLS 1.1/1.2 to WinHTTP applications that use the
default protocols.

## Decision

1. **Keep strict validation.** No option to ignore certificate errors, no HTTP fallback, neither for
   the update API nor for downloads. A failing main server is handled by the mirror and, if both
   fail, by the setup's own files with a notice.
2. **TLS 1.2 on old Windows:** `HttpGet` sets `WinHttpRequestOption_SecureProtocols` (option 9) to
   TLS 1.0 | 1.1 | 1.2 (`$A80`) on Windows older than 8.1, the same set Inno Setup 6.2.2 sets for its
   downloads. On Windows 8.1 and later the OS defaults stay (they include TLS 1.2 and, on Windows 11,
   TLS 1.3). If setting the option fails, the request continues with the defaults and the failure
   is logged. `WinHttpRequestOption_EnableHttpsToHttpRedirects` keeps its default (off).
3. **User-friendly fallback:** the log names the cause of a failed probe or download (the WinHTTP or
   download error text, e.g. a certificate error) and which server is used instead; a working mirror
   needs no message. If neither server works the notice `OnlineFilesUnreachable` says that the
   servers could not be reached or did not present a valid certificate, that nothing is missing for
   playing in English/with the included files, and that the setup can be run again later
   (en/de/fr text update).
4. **Operator guide:** `docs/SERVER-OPERATIONS.md` (S-WP1) lists what the file servers must provide
   (a certificate valid for the exact host name with the full chain, TLS 1.2, the `localized` layout
   on both servers, no redirect to `http://`, identical files on main server and mirror) and how to
   check it (`curl -sSI https://files.empireearth.eu/localized/`, `openssl s_client -connect
   files.empireearth.eu:443 -servername files.empireearth.eu`), including the fix for the current
   problem (enable a certificate for `files.empireearth.eu` in the hosting control panel, e.g. Let's
   Encrypt for the multisite entry).

## Evidence

- Microsoft, "Update to enable TLS 1.1 and TLS 1.2 as default secure protocols in WinHTTP in
  Windows" (KB3140245; applies to Windows 7 SP1, Server 2008 R2 SP1, Server 2012): applications that
  rely on the default protocols cannot use TLS 1.1/1.2 without the update and a registry value;
  "This update will not change the behavior of applications that are manually setting the secure
  protocols instead of passing the default flag", i.e. setting the protocols explicitly is the way
  that works without the update.
- Microsoft, `WinHttpRequestOption` enumeration: `WinHttpRequestOption_SecureProtocols` selects the
  acceptable protocols; `WinHttpRequestOption_EnableHttpsToHttpRedirects`: "By default, all
  redirects are automatically followed, except those that transfer from a secure (https) URL to a
  non-secure (http) URL."
- Inno Setup 6.2.2, `Install.pas`, `SetUserAgentAndSecureProtocols`: `[TLS1, TLS11, TLS12]` with the
  comment "TLS 1.2 isn't enabled by default on older versions of Windows".
- Certificate of `files.empireearth.eu`: `curl` error 60 and `CN=cluster131.hosting.ovh.net` through
  the agent proxy on 2026-10-02 (real-data knowledge base, follow-up fixes). The mirror could not be
  reached from the analysis environment (proxy 502), so its certificate is unverified: a test-plan
  case.

## Consequences

- Windows 7 SP1 with current root certificates can use the update API and the downloads without
  KB3140245; systems without updated root certificates still cannot (strict validation), the
  installation continues with the setup's own files.
- Windows 11 keeps TLS 1.3 for `HttpGet` because the option is only set on old Windows.
- Until the server certificate is fixed, every download comes from the mirror; the test plan checks
  this path on purpose.

## Alternatives considered

- **Accept invalid certificates for unpinned data files:** would make the policy meaningless
  (anyone on the network could replace voices, campaigns, lobby files).
- **Always set the protocol option:** would pin TLS 1.2 and lose TLS 1.3 on Windows 11.
- **Switch the main URL to the mirror:** a server-side problem should be fixed on the server; the
  fallback already covers it.
