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
📥 Download localized content online (support mirror, every file checked against its SHA-256)\
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
| `CertFileName`, `CertHashSHA1` | certificate (DER) in `internal\misc` and its SHA-1 thumbprint, checked against the file (signed builds only) | `cert_name.crt`, empty |
| `TestID` | `0` = release, `> 0` = test build (fast compression, warning on start) | `0` |
| `DownloadHashFile` | SHA-256 list of the online localized files (see [Online localized files](#online-localized-files)) | `data\localized-text.sha256` |

```bat
ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss
```

Signed builds (`/DSignSetup=1`) also need the sign tools named in `[Setup]` (`NameInInnoSetupEE`, `NameInInnoSetupNeo`), e.g. `ISCC "/SNameInInnoSetupEE=signtool.exe sign /a $f" ...`. They offer the unchecked task to add the certificate to the trusted publishers of Windows (never to the trusted root certification authorities), which only helps with a certificate that chains to a trusted root.

### Build script
`ci\build.ps1` builds all four variants (EE/NeoEE x Regular/Portable) into `out\<Type>_<Mode>\` and checks that every output file matches its variant:

```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID>
```

Useful options: `-Variants NeoEE/Regular`, `-OutputDir <dir>`, `-Iscc <path to ISCC.exe>`, `-KeepPreprocessed <dir>`. Run `Get-Help ci\build.ps1 -Detailed` for all of them.

### Online localized files
The setups can download localized content (voices, campaigns, lobby texts) from `files.empireearth.eu`, with `storage.ee.zocker-160.de` as mirror. TLS certificates are validated, and a downloaded file is only installed if its SHA-256 matches a hash compiled into the setup; any other file is discarded and the setup installs its own files instead (`downloads.iss`). Downloads only happen with the component "Download localized voices and campaigns" and a game language other than English; AoC files only with AoC. Failed downloads can be skipped. Afterwards the setup lists, as a notice, every selected file it did not install from the download: not downloaded, discarded because it differs from the known version (e.g. updated on the server after the build), or not downloaded at all because the setup knows no hash for it.

The hashes come from `data\localized-text.sha256`, a list in `sha256sum` format (`<hash>  <path>`, UTF-8 without BOM). The paths are relative to the `localized` folder of the file servers, which has the same layout as `data\localized-text`. Inno Setup 6.2 cannot compute SHA-256 in the preprocessor, so the list has to exist before compiling:

- `ci\build.ps1` writes it from `data\localized-text` before every build. Before compiling in the IDE or with ISCC directly, run `powershell -ExecutionPolicy Bypass -File ci\build.ps1 -DownloadHashesOnly`, or on Linux/Wine `(cd data/localized-text && find . -type f -print0 | sort -z | xargs -0 sha256sum) > data/localized-text.sha256`.
- Files that only exist on the servers (voices, campaigns, the localized intro movie) are only downloaded if the same file is placed in `data\localized-text` at its server path before the list is written; otherwise the setup tells the player that they stay as installed (often English). When the files on the servers change, rebuild the setup.
- Without the list (or with an empty one) the compiler prints a warning and the setup does not offer the download component. `ISCC /DDownloadHashFile=<file>` uses another list.

Very old Windows 7 installations without updated root certificates or TLS 1.2 support can no longer download these files (the setup no longer ignores invalid certificates): the installation continues with the files included in the setup. Such systems should install the Windows updates or use the full/offline setup.

### Contributing without the game data
```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders
```
creates a small placeholder file for every missing asset (existing files are never overwritten) and uses dummy AppIds. Such a build only proves that the script compiles for all variants: **never distribute it**, and remove the placeholder files before building with the real data.

### Continuous integration
`.github/workflows/build.yml` checks the messages (`python ci/check_messages.py`), runs the placeholder build with Inno Setup 6.2.2 on `windows-latest` for every push and pull request and uploads the preprocessed script of every variant as an artifact.

### Conventions
The own `.iss` files are UTF-8 **with BOM** and CRLF (see `.editorconfig` and `.gitattributes`): Inno Setup 6.2 reads files without BOM as ANSI and would break non-ASCII text. Release notes go into [CHANGELOG.md](CHANGELOG.md). After changing `messages.iss`, run `python ci/check_messages.py`: it reports duplicate messages, `==` typos, unknown language prefixes and messages that are used but not defined, which Inno Setup compiles without a warning, and translations out of the standard order (`--sort` fixes that). `--coverage` adds the list of missing translations per language (see [TRANSLATING.md](TRANSLATING.md)).

## License
Consider setup_is6.iss, config_ee.iss, config_neoee.iss, utils.iss, pages.iss, messages.iss, extension.iss, downloads.iss, randommaps.iss, eestats.iss, telemetry.iss under **GPL-3.0 License**.
