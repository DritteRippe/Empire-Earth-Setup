[![GitHub stars](https://img.shields.io/github/stars/EE-modders/Empire-Earth-Setup)](https://github.com/EE-modders/Empire-Earth-Setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/EE-modders/Empire-Earth-Setup)](https://github.com/EE-modders/Empire-Earth-Setup/network)
[![Setup Version](https://img.shields.io/badge/Setup%20Version-v1.7.2-blue)](https://github.com/EE-modders/Empire-Earth-Setup)
# 📥 Empire Earth Community Setup

## Features
🎮 Empire Earth & The Art of Conquest\
🌐 NeoEE (with CD Keys generation)\
🗺️ Support 11 languages\
💻 Can run on Windows 10/11 powered by an ARM/ARM64 processor\
💡 Simple and advanced installation mode\
📣 Discord Status\
📥 Download localized content online (support mirror, HTTPS only, program files only with a known SHA-256)\
✅ Online update checker (support mirror)\
🖥️ DirectX Wrapper (DX7 to DX12)\
🪛 Better compatibility with additonal flags\
➕ More maps and HD Textures (preview)\
➕ dreXmod 2 & 3\
🔥 Registered in Firewall (Admin)\
📊 Improves long-term game compatibility with EE Stats\
🗿 Allows or disallows the tracking of EE Stats and dreXmod\
📥 Legacy DirectX End-User Runtime install\
🔑 You can use NeoEE without admin right\
🛠️ Tool included: Empire Earth Diagnostic v1.0.0.1\
🔐 Digitally (self-)signed

## Notes for Modders
Empire Earth is very sensitive to version change (which leads to multiplayer incompatibility), some modders might be interested in using this setup to deliver their mods. Please do not do this unless you have created a really popular and functional modpack. We must avoid creating multiple versions of the game to avoid fracturing the community.

## Notes for Dev 
Since the script is licensed under the GNU GPL v3 you have every right to modify the setup script to generate your own versions, but you must also publish the source code of the script. So if you want to contribute I invite you to fork this project, if you have ideas of modifications to do don't hesitate to make suggestions, I also invite you to make pull requests if you think you have done something that deserves to be in this script. The version of the script I'm distributing should become the standard to facilitate future installations. I hope you understand the objective and how necessary and helpful it is for everyone. If you think something is wrong, don't hesitate to tell me!

The registry values, files and per-user game settings that the [Empire Earth Launcher](https://github.com/EE-modders/Empire-Earth-Launcher) relies on are specified in [docs/CONTRACT.md](docs/CONTRACT.md), which both repositories share. Change them only together with that file and the launcher. How the setup is structured and why (module map, data flow, error handling, tests, decision records) is described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/adr](docs/adr/README.md).

## Translating
The texts of the setup are in `messages.iss`. [TRANSLATING.md](TRANSLATING.md) explains the format and lists the texts that still need a translator, in particular Brazilian Portuguese, Traditional Chinese and every text added after setup 1.7.2 (English, German and French only so far).

## Building

### Requirements
- Windows (or Wine) with [Inno Setup](https://jrsoftware.org/isinfo.php) **6.2.x**. Releases are built with 6.2.2; newer versions are untested.
- The game data and setup media. They are not part of this repository (see [Assets](#assets)).
- The AppId GUIDs of both setups (see [AppIds](#appids)).
- Python 3, only for placeholder builds and the message check (`ci/make_placeholder_assets.py`, `ci/check_messages.py`).

### Assets
The script packs files from these folders, which are listed in `.gitignore`:

| Folder | Content |
|---|---|
| `data\` | Game files (EE, AoC, NeoEE), add-ons (DLLs, DirectX wrappers, maps, civilizations, HD content, tools) and [localized-text](https://github.com/EE-modders/localized-text) |
| `internal\media\` | Wizard images and setup backgrounds |
| `internal\misc\` | Setup music (`Loop.flac`) and, for signed builds, the certificate |
| `internal\runtime\` | DirectX End-User Runtime web installer |

The exact file list of a variant: dump its preprocessed script (`ci\build.ps1 -KeepPreprocessed <dir>`) and run `python ci\make_placeholder_assets.py --list <dir>\EE_Regular.iss`.

### AppIds
`EE_AppID` and `NeoEE_AppID` are empty in this repository, and the build stops with an error until both are provided (GUIDs without braces, different from each other). The AppId identifies the setup for Windows (uninstall entry, updates in place), so official builds must keep the AppIds of the published setups, and forks must generate their own once (Inno Setup IDE: *Tools > Generate GUID*) and never change them.

### Build switches
Every switch has a default in the settings block of `setup_is6.iss` and can be overridden with `ISCC /D<Switch>=<Value>`, so building a variant never requires editing the script. The values that differ between the EE and the NeoEE setup (name, version, URL, registry keys, icons, sign tool, output file name) are in `config_ee.iss` and `config_neoee.iss`; `InstallType` selects one of them.

| Switch | Values | Default |
|---|---|---|
| `InstallType` | `EE`, `NeoEE` | `EE` |
| `InstallMode` | `Regular`, `Portable` | `Regular` |
| `EE_AppID`, `NeoEE_AppID` | AppId GUIDs without braces | empty (required) |
| `SignSetup` | `0`, `1` | `0` |
| `CertFileName`, `CertHashSHA1` | certificate in `internal\misc` and its SHA-1 thumbprint, checked against the file (signed builds only, see [Signed builds](#signed-builds)) | `cert_name.crt`, empty |
| `CertDerFile` | DER copy of the certificate to ship instead, when `CertFileName` is PEM; `ci\build.ps1 -SignSetup` sets it | `internal\misc\<CertFileName>` |
| `TestID` | `0` = release, `> 0` = test build (fast compression, warning on start) | `0` |
| `DownloadHashFile` | SHA-256 list of the online localized files (see [Online localized files](#online-localized-files)) | `data\localized-text.sha256` |

```bat
ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss
```

### Signed builds
Signed builds (`/DSignSetup=1`) also need the sign tools named in `[Setup]` (`NameInInnoSetupEE`, `NameInInnoSetupNeo`), configured in the Inno Setup IDE (*Tools > Configure Sign Tools*) or passed to ISCC, e.g. `ISCC "/SNameInInnoSetupEE=signtool.exe sign /a $f" ...`. They offer the unchecked task to add the certificate to the trusted publishers of Windows (never to the trusted root certification authorities), which only helps with a certificate that chains to a trusted root.

The certificate `internal\misc\<CertFileName>` is identified by its SHA-1 thumbprint `CertHashSHA1`: the build compares it with the certificate file, the setup checks the extracted file before adding it, and the uninstaller removes the certificate by this thumbprint. The SHA-1 of the file is the thumbprint only for a DER encoded certificate. The community certificate `Empire_Earth_Community.crt` is PEM (base64 text between `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`), which the preprocessor of Inno Setup 6.2 cannot decode (it has no base64 decoding and no binary strings), so the setup ships a DER copy under the same name:

- `ci\build.ps1 -SignSetup -CertFileName Empire_Earth_Community.crt -CertHashSHA1 <thumbprint>` (plus `-SignTool '<command> $f'` unless the sign tools are configured in the IDE) reads the certificate, DER or PEM with exactly one certificate and nothing else, writes its DER encoding to the temporary build folder, stops unless its thumbprint is `CertHashSHA1` and passes the copy to ISCC as `/DCertDerFile=<file>`.
- With ISCC directly, convert it yourself (`certutil -decode <pem> <der>` on Windows, `openssl x509 -in <pem> -outform der -out <der>`) and pass `/DCertDerFile=<der>`, or put a DER file into `internal\misc`. A PEM file without `CertDerFile` stops the build with this hint.
- `ci\tests\build_helpers.tests.ps1 -CertFile internal\misc\<CertFileName> -CertHashSHA1 <thumbprint>` checks a certificate without building.

### Build script
`ci\build.ps1` builds all four variants (EE/NeoEE x Regular/Portable) into `out\<Type>_<Mode>\` and checks that every output file matches its variant:

```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID>
```

Useful options: `-Variants NeoEE/Regular`, `-OutputDir <dir>`, `-Iscc <path to ISCC.exe>`, `-KeepPreprocessed <dir>`, `-SignSetup` (see [Signed builds](#signed-builds)). Run `Get-Help ci\build.ps1 -Detailed` for all of them. The parts that do not need ISCC (hash list, certificate conversion) are in `ci\build_helpers.ps1`.

### Online localized files
The setups can download localized content (voices, campaigns, the localized intro movie, lobby texts) from `files.empireearth.eu`, with `storage.ee.zocker-160.de` as mirror. Downloads only happen with the component "Download localized voices and campaigns" and a game language other than English; AoC files only with AoC. Both servers are only used over HTTPS, and an invalid TLS certificate stops a download instead of being ignored. What the setup accepts (`downloads.iss`, `GetOnlineFileCheck` in `utils.iss`):

- **Files that can contain code** (`Language.dll`; the extensions are listed once, `CodeFileExtensions` in `utils.iss`: `.dll`, `.exe`, `.asi`, `.ocx`, `.sys`, `.scr`, `.bat`, `.cmd`, `.com`, `.ps1`, `.vbs`, `.js`, `.msi`, `.cpl`, `.lnk`, `.reg`, the Miles Sound System plug-ins `.flt`/`.m3d` and similar) only if their SHA-256 matches a hash compiled into the setup (a "pin"). Without a pin they are not downloaded at all.
- **Data files** (`data.ssa`, the campaigns, the movie, the lobby files) must match their pin if the setup has one. Without a pin they are accepted as the server sends them, but only over HTTPS with a validated certificate and never from an `http://` URL (main server and mirror alike); the setup log calls them "TLS-verified, not pinned".

Why the two rules: most data files (`data.ssa` with the voices, the campaigns, the movie) only exist on the servers and can change there independently of the setup, so a build can rarely pin them. Requiring a pin for every file made the download component useless: with the official data only `Language.dll` and the lobby files had pins, and they are the same files the setup installs itself. Data files are only read by the game, and TLS with certificate validation makes sure they come unchanged from the community servers. That is trust in the server operators, not proof that a file is harmless: TLS only shows where a file comes from, and a crafted data or movie file could still attack the old parsers of the game and of Bink (2001-era code without ASLR/DEP). To rule that out for a file, pin it by placing it in `data\localized-text` (see below). Code is different: the elevated setup installs it into the game folder, where it runs every time the game starts, so the trust in a server (or in anyone who gets hold of it or of a certificate for it) is not enough for code; it must be the exact file the build knew.

Afterwards the setup lists, as a notice, every selected file it did not install from the download: not downloaded (failed or skipped), discarded because it does not match its pin (e.g. updated on the server after the build, or damaged), or a program file without pin, or a file that was downloaded but could not be stored for the installation. For each of them it installs its own version. Failed downloads can be skipped.

The hashes come from `data\localized-text.sha256`, a list in `sha256sum` format (`<hash>  <path>`, UTF-8 without BOM), with paths relative to `data\localized-text`. The `localized` folder of the file servers has the same layout, except that it also has a lobby folder per language tag where `data\localized-text` has one folder for several languages: the setup requests the Chinese lobby files from `Lobby/zh-CN/` and `Lobby/zh-TW/` (also below `Mods/NeoEE/`), like the setups up to 1.7.2, and checks them against the entries of `Lobby/zh/` (the lobby folder of both languages, `GameLangLobbyDirs` in `setup_is6.iss`); the servers hold the same files in all three folders. Inno Setup 6.2 cannot compute SHA-256 in the preprocessor, so the list has to exist before compiling:

- `ci\build.ps1` writes it from `data\localized-text` before every build. Before compiling in the IDE or with ISCC directly, run `powershell -ExecutionPolicy Bypass -File ci\build.ps1 -DownloadHashesOnly`, or on Linux/Wine `(cd data/localized-text && find . -type f -print0 | sort -z | xargs -0 sha256sum) > data/localized-text.sha256`.
- Files that only exist on the servers (voices, campaigns, the localized intro movie) are downloaded without pin (TLS-verified). To pin one as well, place the same file in `data\localized-text` at its server path before the list is written; a pinned file that changes on the servers is discarded until the setup is rebuilt. A `Language.dll` (or any other file with code) is only downloaded if the list has it.
- Without the list (or with an empty one) the compiler prints a warning; the setup still offers the download, but only gets data files (TLS-verified) and no `Language.dll`. `ISCC /DDownloadHashFile=<file>` uses another list.

**Known server issue (checked 2026-10-02):** `files.empireearth.eu` serves the hosting provider's default certificate (`CN=cluster131.hosting.ovh.net`), which does not match the host name. Since the setup validates certificates, every download from it fails and the setup falls back to the mirror (`SelectOnlineFilesServer`); if the mirror is unreachable too, the installation continues with the files included in the setup. Setups up to 1.7.2 did not notice because they ignored invalid certificates. The server operators need to install a certificate for `files.empireearth.eu` (e.g. Let's Encrypt in the OVH control panel); nothing has to change in the setup.

Very old Windows 7 installations without updated root certificates or TLS 1.2 support can no longer download these files (the setup no longer ignores invalid certificates): the installation continues with the files included in the setup. Such systems should install the Windows updates or use the full/offline setup.

### Contributing without the game data
```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders
```
creates a small placeholder file for every missing asset (existing files are never overwritten) and uses dummy AppIds. Such a build only proves that the script compiles for all variants: **never distribute it**, and remove the placeholder files before building with the real data.

### Unit tests
`ci\tests\unit_tests.iss` tests the `[Code]` helpers that only compute something (string split, language tag, compatibility flags, uninstall keys, URL encoding, the URL checks of the update question and the download policy of the online files: file types with code, https URLs, https servers; all in `utils.iss`). It is a tiny setup that runs the tests and exits without installing anything or using the network:

```powershell
powershell -ExecutionPolicy Bypass -File ci\run_unit_tests.ps1
```

On Linux with Wine: `ISCC='<Windows path of ISCC.exe>' sh ci/tests/run_unit_tests.sh`. Code that needs the wizard, the registry or the network is not covered; a helper that can be written without them belongs into `utils.iss` with a test.

`ci\tests\build_helpers.tests.ps1` tests the helpers of the build script (`ci\build_helpers.ps1`: hash list, DER copy of PEM and DER certificates) with generated test certificates; it needs neither Inno Setup nor the game data and also runs with PowerShell 7 on Linux.

### Continuous integration
`.github/workflows/build.yml` checks the messages (`python ci/check_messages.py`), runs the unit tests and the build script tests, runs the placeholder build with Inno Setup 6.2.2 on `windows-latest` for every push and pull request and uploads the preprocessed script of every variant as an artifact.

### Conventions
The own `.iss` files are UTF-8 **with BOM** and CRLF (see `.editorconfig` and `.gitattributes`): Inno Setup 6.2 reads files without BOM as ANSI and would break non-ASCII text. Release notes go into [CHANGELOG.md](CHANGELOG.md). After changing `messages.iss`, run `python ci/check_messages.py`: it reports duplicate messages, `==` typos, unknown language prefixes and messages that are used but not defined, which Inno Setup compiles without a warning, and translations out of the standard order (`--sort` fixes that). `--coverage` adds the list of missing translations per language (see [TRANSLATING.md](TRANSLATING.md)).

## License
Consider setup_is6.iss, config_ee.iss, config_neoee.iss, utils.iss, pages.iss, messages.iss, extension.iss, downloads.iss, randommaps.iss, eestats.iss, telemetry.iss under **GPL-3.0 License**.
