# Operating the file servers and the API for the setup

This guide is for the people who run the servers the Empire Earth Community Setup talks to. It
says what the servers must provide so that the setup can use them, how to check that, and how to
fix the problem known today. Background: [ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md)
(downloads) and [ADR 0006](adr/0006-strict-tls-and-server-certificates.md) (strict TLS); the
setup side is described in the README, "Online localized files".

## 1. What the setup requests

| Host | Used for | Code |
|---|---|---|
| `api.empireearth.eu` | update check (`/setup/?product=<AppId>`), setup statistics with consent (`/eestats/setup/`) | `HttpGet` (`utils.iss`), WinHTTP |
| `files.empireearth.eu` | localized files below `/localized/` (main server) | `downloads.iss`, Inno Setup's built-in downloads |
| `storage.ee.zocker-160.de` | the same files below `/localized/` (mirror) | as above |

Only `https://` is used. **Every certificate is validated, and there is no fallback to `http://`
and no option to ignore a certificate error.** A server with an invalid certificate is treated
like a server that is down.

How the setup uses the two file servers:

1. Before the first download it sends one request to `https://files.empireearth.eu/localized`
   (no trailing slash). **Any HTTP answer** (200, 301, 403, 404, ...) over a valid TLS connection
   counts as "reachable". If there is none (no connection, timeout, invalid certificate), it sends
   the same request to the mirror and, if the mirror answers, downloads from the mirror first.
2. It downloads one file at a time from the server chosen in step 1. If a file fails (network,
   certificate, HTTP status outside 200 to 299, size, or a SHA-256 mismatch for a file the setup
   has a hash of), it requests the same path from the other server once.
3. If neither server answers in step 1, the setup shows the notice `OnlineFilesUnreachable`
   ("could not be reached or did not present a valid security certificate, a problem of the
   servers") and installs only its own files. Files that fail on both servers are listed in the
   notice `DownloadIncomplete`; the setup installs its own version of each.

Layout below `/localized/` (identical on both servers; `<tag>` is a game language other than
English: `de`, `es`, `fr`, `it`, `ko`, `pl`, `pt-BR`, `ru`, `zh-CN`, `zh-TW`; `<game>` is `EE` or
`AoC`):

| Path | Content |
|---|---|
| `Game/<tag>/<game>/Language.dll` | texts of the game (program file: only installed if the setup knows its SHA-256) |
| `Game/<tag>/<game>/Data/data.ssa` | voices |
| `Game/<tag>/<game>/Data/Campaigns/<campaign>.ssa` | campaigns (EE: `EELearningCampaign`, `EETheBritish`, `EETheFuture`, `EETheGermans`, `EETheGreeks`; AoC: `AOCAsian`, `AOCPacific`, `AOCRoman`) |
| `Game/<tag>/EE/Data/Movies/Empire Earth.bik` | localized intro movie |
| `Lobby/<tag>/shared/Data/WONLobby Resources/_WONStatus.cfg`, `_GameResource.cfg`, `_LobbyResource.cfg` | lobby texts, shared by EE and AoC |
| `Lobby/<tag>/<game>/WONLobby.cfg` | lobby configuration |
| `Mods/NeoEE/...` | the NeoEE versions of `Language.dll`, `WONLobby.cfg` and `_NeoEEResource.cfg`, same layout |

`zh-CN` and `zh-TW` have a copy of `Lobby/zh/` each. Paths contain spaces (`Empire Earth.bik`,
`WONLobby Resources`); the setup requests them percent-encoded (`%20`).

## 2. Requirements

Each file server (main server **and** mirror) must:

1. **Present a certificate for its exact host name** (`files.empireearth.eu`,
   `storage.ee.zocker-160.de`) that chains to a root certificate Windows trusts, and **send the
   full chain** (leaf and intermediate certificates). A certificate for another name (for
   example the hosting provider's default certificate), a self-signed or an expired certificate
   makes every request fail.
2. **Speak TLS 1.2** with at least one cipher suite that Windows 7 SP1 supports (see the handshake
   check below). The setup asks for TLS 1.0 to 1.2 on Windows 7 and 8 and uses the defaults of the
   system on Windows 8.1 and later (TLS 1.2 and, on Windows 11, TLS 1.3).
3. **Send `Content-Length`** for every file below `/localized/`. Without it (for example a
   chunked answer because the server compresses on the fly) the setup cannot check the size of a
   file it has no SHA-256 for, accepts it unchecked and writes `accepted without size check` into
   its log. Do not compress `.ssa`, `.cfg`, `.bik` and `.dll` files on the fly.
4. **Never redirect to `http://`.** A redirect from `https://` to `https://` is fine. The download
   code of Inno Setup 6.2.2 follows redirects automatically, and nothing documents that it refuses
   one to `http://`, so the setup has to assume it follows those too. Only the server operator can
   send such a redirect (nobody else can inject one into a validated TLS connection), so the
   guarantee "never over `http://`" depends on this rule. (The update check and the reachability
   check use WinHTTP, which refuses redirects from `https://` to `http://`.)
5. **Serve identical files** on main server and mirror at the same paths. The setup checks a
   downloaded file against the SHA-256 compiled into it where it has one (always for
   `Language.dll`); a file that differs on one server is discarded there, and the setup tries the
   other server. Update both servers together, and if a pinned file changes, a new setup build is
   needed (the README, "Online localized files", explains the hash list).
6. Answer `/localized` (the reachability check) with any HTTP status, quickly. A server that
   accepts connections but answers slowly costs the player the full timeout of the download code
   per file before the other server is tried; the timeouts of Inno Setup's downloads cannot be set
   by the script.

`api.empireearth.eu` must fulfil 1, 2 and 4 as well (its certificate `*.empireearth.eu` was valid
on 2026-10-02).

## 3. Checks

Run them from a machine with a current OpenSSL/curl and **without** a proxy that intercepts TLS
(otherwise you check the proxy's certificate). Replace `HOST` with `files.empireearth.eu`,
`storage.ee.zocker-160.de` and `api.empireearth.eu` in turn.

### 3.1 Certificate and chain

```sh
openssl s_client -connect HOST:443 -servername HOST -verify_hostname HOST -verify_return_error </dev/null 2>&1 \
  | grep -E 'subject=|issuer=|Verify return code|Protocol|Cipher'
```

Expected: `Verify return code: 0 (ok)`, a `subject=` that names the host (or a wildcard that
covers it) and an `issuer=` of a public certification authority. `-showcerts` lists the chain the
server sends: it must contain the intermediate certificate(s), not only the leaf. Failures look
like `Verify return code: 62 (hostname mismatch)` or `21 (unable to verify the first certificate)`
(missing intermediate).

### 3.2 TLS 1.2

```sh
openssl s_client -connect HOST:443 -servername HOST -tls1_2 </dev/null 2>&1 | grep -E 'Protocol|Cipher'
```

Expected: `Protocol  : TLSv1.2` and a cipher other than `0000`/`(NONE)`.

### 3.3 Handshake of Windows 7 clients

OpenSSL does not show whether Windows 7's TLS stack (SChannel) finds a common cipher suite. Use
the handshake simulation of the Qualys SSL Labs server test:
`https://www.ssllabs.com/ssltest/analyze.html?d=HOST` (for each of the three hosts), section
"Handshake Simulation", row **"IE 11 / Win 7"**. Expected: `TLS 1.2` with a cipher suite. "Protocol
or cipher suite mismatch" or "Server sent fatal alert" means Windows 7 players cannot connect
even with a valid certificate: enable a TLS 1.2 cipher suite that the simulated client offers (SSL
Labs lists them per client; for an RSA certificate, for example, `ECDHE-RSA-AES128-SHA256` or
`ECDHE-RSA-AES256-SHA384`). Check the row "IE 11 / Win 10" too. The SSL Labs report also flags an
incomplete chain ("Chain issues: Incomplete").

### 3.4 Files, `Content-Length` and redirects

```sh
for HOST in files.empireearth.eu storage.ee.zocker-160.de; do
  for P in 'Game/de/EE/Data/data.ssa' 'Game/de/EE/Data/Movies/Empire%20Earth.bik' \
           'Lobby/de/shared/Data/WONLobby%20Resources/_WONStatus.cfg' 'Lobby/zh-CN/EE/WONLobby.cfg'; do
    curl -sS -o /dev/null -D - "https://$HOST/localized/$P" \
      | grep -iE '^HTTP/|^content-length|^transfer-encoding|^content-encoding|^location'
  done
done
```

Expected for every file: `HTTP/1.1 200` (or `HTTP/2 200`), a `content-length` header, no
`transfer-encoding: chunked`, no `content-encoding`, no `location: http://...`. The command uses
`GET`, like the setup; a `HEAD` request (`curl -I`) may be answered differently by some servers.
`curl -sS -L -o /dev/null -w '%{url_effective}\n' "https://HOST/localized"` shows where the
reachability URL ends after redirects: it must start with `https://`.

### 3.5 Identical files on both servers

```sh
for P in 'Game/de/EE/Language.dll' 'Game/de/EE/Data/data.ssa' 'Lobby/zh-CN/EE/WONLobby.cfg'; do
  a=$(curl -sS "https://files.empireearth.eu/localized/$P" | sha256sum)
  b=$(curl -sS "https://storage.ee.zocker-160.de/localized/$P" | sha256sum)
  [ "$a" = "$b" ] && echo "same       $P" || echo "DIFFERENT  $P"
done
```

Extend the list to every path you changed. For the files a setup has a hash of, compare with
`data/localized-text.sha256` of the build (the README, "Online localized files").

## 4. Known problem and its fix (2026-10-02)

`files.empireearth.eu` presents the default certificate of its hosting provider,
`CN=cluster131.hosting.ovh.net`, not a certificate for `files.empireearth.eu` (`curl` error 60,
`hostname mismatch` in check 3.1). Setups up to 1.7.2 did not notice because their download
plug-in ignored certificate errors; setup v2 does not, so every request to the main server fails
and the setup falls back to the mirror.

Fix on the hosting side (OVHcloud web hosting, the host is a "multisite" entry of the hosting
plan):

1. Make sure the DNS record of `files.empireearth.eu` points to the hosting plan (the
   certification authority checks the name over HTTP).
2. In the OVHcloud control panel, *Web Cloud* > *Hosting plans* > the plan > tab *Multisite*:
   edit the entry `files.empireearth.eu` and enable SSL for it.
3. Tab *General information*, *SSL certificate*: order or regenerate the free Let's Encrypt
   certificate so that it includes the new entry (it can take a few hours).
   Alternatively import a certificate that covers the name; a hosting plan holds one certificate.
4. Run checks 3.1 to 3.4 for `files.empireearth.eu`.

Nothing has to change in the setup. The mirror's state could not be checked from the analysis
environment; it is part of the release check below.

## 5. Release criterion

A release of setup v2 needs **at least one file server (main server or mirror) that passes checks
3.1 to 3.4 and serves the `/localized/` files**, and `api.empireearth.eu` passing 3.1 to 3.3. If
neither file server does, that is a **release blocker on the server side**, not a defect of the
setup: v2 would install no localized files at all (1.7.2 still downloaded them because it ignored
the certificate), so fix the server first. The Windows test plan starts with the same check
([TP-00](TEST-PLAN.de.md#tp-00-server-vorabprüfung)) before any download test, and the download
cases (`TP-1x`) cover the setup's side.
