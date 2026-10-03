# Operating the file servers and the API for the setup

This guide is for the people who run the servers the Empire Earth Community Setup talks to. It
says what the servers must provide so that the setup can use them, how to check that, and how to
fix the problem known today. Background: [ADR 0003](adr/0003-built-in-downloads-instead-of-idp.md)
(downloads), [ADR 0006](adr/0006-strict-tls-and-server-certificates.md) (strict TLS) and
[ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md) (pinned files from a server with
an invalid certificate); the setup side is described in the README, "Online localized files".
**If you change a file below `/localized/`, the pins must be regenerated** ([section 6](#6-pins-of-every-online-file)).

## 1. What the setup requests

| Host | Used for | Code |
|---|---|---|
| `api.empireearth.eu` | update check (`/setup/?product=<AppId>`), setup statistics with consent (`/eestats/setup/`) | `HttpGet` (`utils.iss`), WinHTTP |
| `files.empireearth.eu` | localized files below `/localized/` (main server) | `downloads.iss`: Inno Setup's built-in downloads; from a server with an invalid certificate WinHTTP, pinned files only |
| `storage.ee.zocker-160.de` | the same files below `/localized/` (mirror) | as above |

Only `https://` is used, and there is no fallback to `http://`. Every certificate is validated, with
one exception: a file whose SHA-256 and size are compiled into the setup ("pinned",
[section 6](#6-pins-of-every-online-file); since setup v2 every online file is) may also come from a
server whose certificate is invalid, because the setup only installs it if it is exactly the pinned
file ([ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md)). Nothing else ignores a
certificate error: not the update check, not the statistics, not a file without pin.

How the setup uses the two file servers:

1. Before the first download it sends one request to `https://files.empireearth.eu/localized`
   (no trailing slash). **Any HTTP answer** (200, 301, 403, 404, ...) over a valid TLS connection
   makes the server "verified"; the mirror is then not asked. If there is none (no connection,
   timeout, invalid certificate), it sends the same request once more **without certificate
   validation** (and without reading the answer): an HTTP answer now makes the server
   "certificate invalid", none "unreachable". Then the same for the mirror. The server in the
   better state is used first (verified, then certificate invalid; the main server on a tie).
2. It downloads one file at a time from the server chosen in step 1: from a verified server every
   file with Inno Setup's built-in downloads; from a server with an invalid certificate only the
   pinned files, with WinHTTP and the certificate errors ignored, each kept only if its size and
   SHA-256 match the pin. A file without pin is never requested from such a server (the setup
   names it in its notice). If a file fails (network, HTTP status outside 200 to 299, another size,
   a SHA-256 mismatch), it requests the same path from the other server once, if that server may
   deliver the file.
3. If neither server can be used in step 1, the setup shows the notice `OnlineFilesUnreachable`
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
   full chain** (leaf and intermediate certificates). With a certificate for another name (for
   example the hosting provider's default certificate), a self-signed or an expired certificate
   the setup still downloads the pinned files (every online file of a release, as long as it is
   the pinned version), but no file without pin, and players see "certificate invalid" in their
   logs. Fix it anyway (section 4).
2. **Speak TLS 1.2** with at least one cipher suite that Windows 7 SP1 supports (see the handshake
   check below). The setup asks for TLS 1.0 to 1.2 on Windows 7 and 8 and uses the defaults of the
   system on Windows 8.1 and later (TLS 1.2 and, on Windows 11, TLS 1.3).
3. **Send `Content-Length`** for every file below `/localized/`. Without it (for example a
   chunked answer because the server compresses on the fly) the setup cannot check the size of a
   file it has no SHA-256 for, accepts it unchecked and writes `accepted without size check` into
   its log. Do not compress `.ssa`, `.cfg`, `.bik` and `.dll` files on the fly.
4. **Never redirect to `http://`, and answer `HEAD` like `GET`.** A redirect from `https://` to
   `https://` is fine. The download code of Inno Setup 6.2.2 follows redirects itself, **also from
   `https://` to `http://`**: a probe for setup v2 showed that it follows `301`, `302`, `307` and
   `308` to `http://` ([ADR 0008](adr/0008-release-checksums-and-contract-check.md),
   "Implementation"). So before it downloads a file it has no SHA-256 of, the setup asks the URL
   with `HEAD` requests that follow no redirect themselves; a redirect that leads anywhere but
   `https://`, or no answer, makes it skip the file on that server (log: `Online file refused, ...`
   or `... no answer to the check of its redirects ...`). That check only sees what the server
   answers to `HEAD`: a server that redirects `GET` but not `HEAD` to `http://` still gets the file
   delivered over plain HTTP, and the setup still logs it as "TLS-verified". Only the server
   operator can send such a redirect (nobody else can inject one into a validated TLS connection),
   so the guarantee "never over `http://`" for these files depends on this rule; check 3.4 shows it,
   and [section 6](#6-pins-of-every-online-file) removes the dependency: a release pins every
   online file, and for a pinned file the SHA-256 decides, whatever redirect it took. `HEAD` must not
   fail either: a `405` or another status without redirect is fine, but a server that drops the
   connection on `HEAD` makes the setup skip every file without SHA-256 (only test builds have such
   files). (The update check, the reachability check and the downloads of pinned files from a server
   with an invalid certificate use WinHTTP, which refuses redirects from `https://` to `http://`.)
5. **Serve identical files** on main server and mirror at the same paths, **and the files that the
   setups pin.** The setup checks every downloaded file against the SHA-256 and size compiled into
   it (`pins/online-files.txt`); a file that differs on one server is discarded there, and the setup
   tries the other server. Update both servers together, and **after any change of a file below
   `/localized/` regenerate the pins and release a new setup** ([section 6](#6-pins-of-every-online-file)):
   until then every setup discards the changed file and installs its own (English) version.
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
`GET`, like the download; run it once more with `-I` instead of `-o /dev/null -D -` (a `HEAD`
request, like the setup's check of the redirects before a file without SHA-256): the same status
or `405`, never a `location: http://...`, and no error.
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

Extend the list to every path you changed. Compare the hashes with `pins/online-files.txt` of the
setup repository (`<SHA-256> <size> <path>` per line): a file whose hash differs there is discarded
by every released setup.

## 4. Known problems and their fix (2026-10-03)

`files.empireearth.eu` presents the default certificate of its hosting provider,
`CN=cluster131.hosting.ovh.net`, not a certificate for `files.empireearth.eu` (`curl` error 60,
`hostname mismatch` in check 3.1), and the mirror `storage.ee.zocker-160.de` no longer exists in DNS
(NXDOMAIN, checked 2026-10-03). Setups up to 1.7.2 did not notice the certificate because their
download plug-in ignored certificate errors. The first v2 test builds validated it and therefore
installed no localized files at all; since [ADR 0012](adr/0012-pinned-downloads-despite-invalid-certificates.md)
setup v2 downloads the pinned files (every online file) from the main server without certificate
validation and installs each only if it matches its pin. The log of such a run says
`Online files server https://files.empireearth.eu/localized: answers only without certificate validation`
and, per file, `transport WinHTTP without certificate validation`.

The certificate should still be fixed: then every file comes over validated TLS again (also for
players behind a proxy that refuses invalid certificates), and the warning lines disappear from
the logs.

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

Nothing has to change in the setup. The mirror: either remove its name from the setup
(`OnlineFilesMirrorURL` in `utils.iss`; today it only costs a DNS lookup) or bring it back with
the same files and a valid certificate.

## 5. Release criterion

A release of setup v2 needs **at least one file server that serves the `/localized/` files over
HTTPS** (checks 3.4 and 3.5; a valid certificate, checks 3.1 to 3.3, is strongly recommended, see
section 4) **and `pins/online-files.txt` matching the files on that server** (section 6), and
`api.empireearth.eu` passing 3.1 to 3.3. If no file server serves the pinned files, that is a
**release blocker on the server side**, not a defect of the setup: v2 would install no localized
files at all. The Windows test plan starts with the same check
([TP-00](TEST-PLAN.de.md#tp-00-server-vorabprüfung)) before any download test, and the download
cases (`TP-1x`) cover the setup's side.

## 6. Pins of every online file

**What.** `pins/online-files.txt` in the setup repository pins every file the setups can download
from `/localized/`: one line per server path, `<SHA-256, 64 lowercase hex digits> <size in bytes>
<server path>`, for both products (230 paths with the data of setup 1.7.2). The setups are built
with it; a downloaded file is only installed if it has exactly that size and SHA-256. That is what
lets the setup take pinned files even from a server whose certificate is invalid, and what makes a
redirect to `http://` harmless for them (requirement 4).

**Why it must be regenerated.** A file that changes on the servers no longer matches the pin: every
setup built before the change downloads it, discards it (`DownloadFileRejected`, "not the version
this setup knows ... discarded") and installs its own (English) version, until a setup with new
pins is released. So:

- **Do not overwrite a file in place** if you can avoid it. If a translation must change, change
  it on both servers at the same time, then regenerate the pins and release a new setup right away.
- **A new file** (a new language, a new campaign) needs code in `setup_is6.iss` and a pin; a
  release build of the setup stops when the code registers a file that `pins/online-files.txt` does
  not pin (and when the list pins a path that no setup downloads).

**How to regenerate the pins** (on any machine with PowerShell 5.1 or 7):

1. Get a copy of the `localized` folder **over a channel that does not depend on the certificate of
   the web server**: the master copy you upload from, or SFTP/FTP of the hosting (OVHcloud: FTP or
   SFTP login of the hosting plan). The folder must have the layout of `/localized/` (`Game\<tag>\...`,
   `Lobby\<tag>\...`, `Mods\NeoEE\...`, including `Lobby\zh-CN\` and `Lobby\zh-TW\`).
2. In the setup repository:
   `pwsh ci/online_pins.ps1 -Update -Source <copy> -SourceNote "<date>, <where the copy comes from>"`.
   It hashes exactly the files the setups download (read from the code), writes nothing if one is
   missing, and then checks the list.
3. Review `git diff pins/online-files.txt`: only the files you changed may have new hashes. Commit
   it, build and release the setups.

Without access to the hosting: download the files twice, over two independent networks (for
example at home and over a mobile connection), into two folders, and add
`-CrossCheck <second folder>`: every file must be byte-identical in both, or nothing is written.
That still trusts the server on the day of the download ("trust on first use"); record it in
`-SourceNote`. `ci/online_pins.ps1` without switches only checks the list (CI does that on every
push).

**Placeholder and test builds.** The hash list that `ci/build.ps1` writes from `data\localized-text`
(the files the setup ships) applies before `pins/online-files.txt`, so a test build can pin a file
differently on purpose (TEST-PLAN, TP-13 and TP-16). A release build with the real data stops if
the two pin different files: then `data\localized-text` is not the data of the servers. It also
stops if `pins/online-files.txt` pins a file with the same SHA-256 as `data\localized-text`, but
with another size than that file has: the size there is wrong (edited by hand, a merge conflict),
and every setup would reject the right file. Regenerate the list (`-Update`) instead of editing it.
