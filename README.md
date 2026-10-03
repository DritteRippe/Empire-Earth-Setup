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

New in setup v2 (not released yet, see [CHANGELOG.md](CHANGELOG.md) "Unreleased"):
- A log of every run, without any switch (see [Support](#support)), and a SHA-256 file next to every built setup (see [Checksums of the setups](#checksums-of-the-setups)).
- Launcher integration: an install record, `install.ini` and the integrity manifest `files.sha256` for the [Empire Earth Launcher](#empire-earth-launcher); files that disappear during the installation (antivirus) are named at the end.
- Hints before the installation: a screen lower than 768 pixels, traces of other or old installations (original CD, GOG, old NeoEE installers) and their folders, EE and NeoEE in one folder; nothing is changed or deleted.
- No elevated installation through links in the folders `Data` and `Users` (see [Security](#security)).
- Downloads with Inno Setup's built-in support instead of a third-party plug-in: HTTPS with certificate validation only (TLS 1.2 requested also on Windows 7), the mirror as fallback, a clear notice of what was not installed (see [Online localized files](#online-localized-files)).
- Windows 7: no compatibility values by default, the flags of 1.7.2 without the Windows XP mode as an option (see [Compatibility and graphics options](#compatibility-and-graphics-options)).

## Support
- **Check the download:** the SHA-256 of every released setup is published next to its download. Compare it with `Get-FileHash <setup>.exe -Algorithm SHA256` in PowerShell before you run the setup, see [Checksums of the setups](#checksums-of-the-setups).
- **Help:** ask on [empireearth.eu](https://empireearth.eu) or the community Discord, and attach the setup log (next point).
- **Setup log:** every run of the setup writes a log, without any switch: `%TEMP%\Setup Log <date> #<n>.txt`, e.g. `Setup Log 2026-10-02 #001.txt` (type `%TEMP%` into the address bar of the Explorer; the number counts the runs of that day, the highest is the last one). `/LOG="<file>"` still works and writes the log to that file instead, e.g. `/LOG="%USERPROFILE%\Desktop\EE-Setup.log"`. **Installed for all users from a standard account?** If Windows asked for the password of an administrator account (over-the-shoulder elevation), the setup ran as that administrator, and its log is in **that** account's `%TEMP%` (`C:\Users\<administrator>\AppData\Local\Temp`), not in yours; with a "Yes" in the prompt of your own administrator account it is in your own `%TEMP%`. The uninstaller writes a log only when it is started with `/LOG="<file>"`. The log contains no CD keys and no passwords, but folder names with Windows user names (e.g. `C:\Users\<name>\...`): **check it before you post it publicly** and replace the names if you like.
- **Files missing at the end of the installation (antivirus):** at the end of every installation the setup checks the files it has just installed (page "Checking the installed files"). If some are gone, it names them ("Some installed files were missing at the end of the installation", at most ten names and "and ... more") and the installation folder. Antivirus programs often delete or quarantine game files during the installation (save-ee.com t=11045 p=48037, t=41147 p=80317): add an exception for the installation folder in your antivirus program, then run the setup again for the same folder to repair the installation. The setup log lists every file (`Installed file missing after the installation ...`), `install.ini` lists them under `[MissingAfterInstall]` (see [Empire Earth Launcher](#empire-earth-launcher)); in silent mode and with `/SUPPRESSMSGBOXES` the setup shows nothing and only logs them.
- **Small screen (netbooks):** the menus of the game need a screen at least 768 pixels high. On a lower screen (e.g. 1024 x 600) the setup shows a notice (`LowScreenResolution`) and sets the game window to at least 1024 x 768 as before; the game may not fit or may crash after the intro (save-ee.com t=3863 p=26167). The scaling of the graphics driver ("GPU scaling") or a DirectX wrapper can help. Every setup log names the screen, its DPI and the game window it wrote (`Screen: ... pixels ..., ... DPI (LOGPIXELSX, ... % scaling), game window ...`).
- **Old or other installations (original CD, GOG, old NeoEE installers):** when you leave the folder page, the setup looks for their registry keys in `HKEY_LOCAL_MACHINE` (`SSSI\Empire Earth`, `Mad Doc Software\EE-AOC`, `Neo\Empire Earth`, `Neo\Art of Conquest`), their uninstall entries and the folders `C:\Sierra\Empire Earth` and `C:\Program Files (x86)\Sierra\Empire Earth` (on 32-bit Windows `C:\Program Files\Sierra\Empire Earth`), and lists what it found once ("The setup found traces of another Empire Earth installation ..."). It changes nothing: the community setup installs its own copy. If Empire Earth or The Art of Conquest later starts the other installation, these entries can be the cause (save-ee.com t=1036 p=4756, t=12082 p=49553, t=10577 p=46302). **Never delete the registry key `Software\Sierra` or one of its parent keys:** `Software\Sierra\CDKeys` holds the NeoEE CD keys, and deleting `Software\Sierra` cost players their keys (t=10950, t=11021). To remove the other installation, use its own uninstaller (Windows "Apps" or "Programs and Features"), if it has one. The [Empire Earth Launcher](https://github.com/EE-modders/Empire-Earth-Launcher) removes old game settings of your own account (`HKEY_CURRENT_USER`) with a backup; it does not remove the keys in `HKEY_LOCAL_MACHINE` that the setup lists, the uninstall entries or the folders (for some old keys it explains how to export them before you delete them). If you are unsure, ask for help and attach the setup log. If you choose the folder of such an installation (e.g. `C:\Sierra` or the GOG folder), the setup asks whether you want another folder ("Yes" is the default and recommended): installing there mixes the files of both, and uninstalling the community version later removes files of the other one. Installations of the community setups themselves are never listed.
- **EE and NeoEE in one folder:** if the chosen folder already holds the other community product, the setup asks whether you want another folder ("Yes", the default and recommended, goes back to the folder page): in one folder the launcher can no longer check the files of the first product, and uninstalling one of them also removes files and the firewall rules of the other. Install them into separate folders (the defaults `Empire Earth` and `Neo Empire Earth` are). In silent mode and with `/SUPPRESSMSGBOXES` the setup asks nothing; the log names what it found, and the installation continues. An update of an existing installation does not show the folder page and does not check again.
- **"The setup has stopped before changing anything" (installation for all users):** a folder below `Data` or `Users` of the game is a link (junction or symbolic link), or a file there is a hard link, see [Security](#security).
- **Localized files missing:** if the setup says that the servers of the localized files could not be reached or did not present a valid certificate (`OnlineFilesUnreachable`), or lists files it could not install from the download (`DownloadIncomplete`), the game is installed anyway, with the files included in the setup; some voices, campaigns or the intro movie may stay in English. Run the setup again later to add them. A certificate problem is a problem of the servers, not of your computer; the operators find what to check in [docs/SERVER-OPERATIONS.md](docs/SERVER-OPERATIONS.md).
- **Windows 7 SP1:** the setup asks for TLS 1.2 itself. If the setup log still shows TLS or certificate errors for `api.empireearth.eu` or the file servers (lines `HTTP GET ... failed` or `Online file download failed`), install the Windows updates, in particular the updated root certificates and **KB3140245**, Microsoft's "[Update to enable TLS 1.1 and TLS 1.2 as default secure protocols in WinHTTP in Windows](https://support.microsoft.com/en-us/servicing/os/windows-server/2019/07/update-to-enable-tls-1-1-and-tls-1-2-as-default-secure-protocols-in-winhttp-in-windows)". Its article also describes the registry values (`DefaultSecureProtocols`, and the SChannel value `DisabledByDefault`) that Windows 7 needs for TLS 1.2. The setup never changes these system settings; applying them is your decision. Without them the game is still installed, with the files included in the setup.

## Security
- **Links in the game folders (installation for all users):** the game runs without administrator rights and writes into the folders `Data` and `Users` of `Empire Earth` and `Empire Earth - The Art of Conquest`, so an installation for all users lets every user of the computer change them. An update or repair runs with administrator rights and writes there too. If such a folder, or one below it, is a junction or symbolic link (e.g. `Data\Movies` moved to another drive with `mklink /J`), the writes would land wherever the link points, and a standard user could use that to change files outside the game. A file there with a second name elsewhere (a hard link, which every user can make on Windows 7 and 8.1) would let the update copy a file from outside the game, which the user may not be allowed to read, into one every user can read. So before it changes anything, the setup looks for links in `Data`, `Users` and every folder below them (the profile folders of the players included) and for hard links among their files, and stops if it finds one, or a folder or file it cannot check: "The setup has stopped before changing anything ..." on the page "Preparing to install", with the folders and files (all of them in the setup log, lines `Link check: ...`). Nothing has been changed. Remove the link with `rmdir <link>` (without `/s`; that removes only the link, not the folder it points to) or replace it by a normal folder with the same files, delete a hard link with `del <file>` (that removes only this name of the file) or replace it by a copy, then click "Back" and "Install" or run the setup again; or install the game for your account only ("Install for me only"). In silent mode the setup ends with exit code 7. The check only runs in an installation for all users; a symbolic link to a file and a file compressed by Windows do not stop it. Decision record: [ADR 0009](docs/adr/0009-no-installation-through-links.md); Windows test case TP-80 of the [test plan](docs/TEST-PLAN.de.md).
- **What the check cannot cover:** a link created while the setup is already installing (between the check and the writes), a symbolic link to a file (creating one needs administrator rights or the Developer Mode of Windows 10 and 11), the uninstaller (it deletes the files the installation recorded, also through a link made later), a user or portable setup that someone runs as administrator, and an installation folder that the administrator chose where every user can write (e.g. a new folder directly below `C:\`; the default `C:\Program Files (x86)` is safe). The complete protection would be the "RedirectionGuard" of Inno Setup 6.7 (Windows 10 22H2 and 11 only), which this setup does not use yet ([ADR 0002](docs/adr/0002-stay-on-inno-setup-6.2.2.md)). On a computer shared with people you do not trust, do not let them start the setup for you with your administrator password.
- **Downloads and the update check** use HTTPS with validated certificates only; files that can contain code are only installed with a SHA-256 known at build time, see [Online localized files](#online-localized-files) and [CHANGELOG.md](CHANGELOG.md) ("Security"). Check the SHA-256 of a setup before you run it, see [Checksums of the setups](#checksums-of-the-setups).

## Compatibility and graphics options
- **Compatibility values (Windows 8 and later):** the tasks "Enable compatibility flags" (`DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`) and "Enable earlier Windows compatibility mode" (the Windows 7 mode `WIN7RTM`, on Windows 10/11 also the high-performance graphics card) are selected by default; their page is shown with "Custom install settings". The setup writes them for `Empire Earth.exe` and `EE-AOC.exe`, for all users in an administrative installation, else for the current user, and the uninstaller removes them. Players report that the Windows 7 mode helps on Windows 8 and 10 (save-ee.com t=5842 p=39349, t=5748 p=38768). **Windows 8 and 8.1** get these values too since setup v2; the official 1.7.2 setups wrote them only from Windows 10 on, so on Windows 8.1 this is new and untested so far. Exact values: [docs/CONTRACT.md](docs/CONTRACT.md), section 3.7.
- **Windows 7: no compatibility values by default** (since setup v2). The official 1.7.2 setups gave `EE-AOC.exe` the Windows XP SP3 mode with the flags there, `Empire Earth.exe` got nothing (its Windows 7 entries never applied); now neither program gets a value unless you choose the option below. The evidence is thin but points one way: the forum administrators never needed a compatibility mode on Windows XP, Vista or 7 (t=4280 p=30479, t=1827 p=12147), one got "a long black screen and a runtime error" with it on Windows 7 (t=4280 p=30477), and no post reports that it helped there; the forum ends in 2019, before this setup existed, so the Windows 7 cases of the [test plan](docs/TEST-PLAN.de.md) (TP-20, TP-21) check it. An update on Windows 7 removes the values earlier setups wrote there, but only values that are exactly one of theirs; a compatibility mode you set yourself stays. Only the unchecked tasks "Always run the game as administrator, for all users" (`RUNASADMIN`) and the option below still write a value. If the game needs a compatibility mode on your Windows 7, set it in the properties of `Empire Earth.exe` or `EE-AOC.exe` (tab "Compatibility"). Decision record: [ADR 0005](docs/adr/0005-compatibility-and-wrapper-defaults.md).
- **Windows 7: compatibility flags as an option.** With "Custom install settings" Windows 7 shows the unchecked task "Enable compatibility flags (optional on Windows 7: ...)". It writes the flags of 1.7.2 **without** the Windows XP SP3 mode, `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` (with `RUNASADMIN` in front if you also chose to run the game as administrator), for `Empire Earth.exe` and, with The Art of Conquest, `EE-AOC.exe`, for all users in an administrative installation, else for the current user; the uninstaller removes it. Compared with 1.7.2: `EE-AOC.exe` had these flags plus the XP mode by default, `Empire Earth.exe` nothing; now both get the flags only if you select the task. `HIGHDPIAWARE` is the useful part: without it Windows 7 scales the game at 150 % display scaling and more, so its window may be blurry or larger than the screen (test case TP-24). Whether the other two flags change anything on Windows 7 is not tested. A later run of the setup keeps the value while the task stays selected (the regular setups preselect the tasks of the previous run) and removes it when the task is not selected. Decision record: [ADR 0010](docs/adr/0010-opt-in-compatibility-on-windows-7.md).
- **DirectX wrapper:** with "Recommended settings" the graphics card page preselects a wrapper for the brand of your graphics card: dgVoodoo DirectX 11 (API level 11 for NVIDIA and, from Windows 10, AMD; level 10.1 for Intel and AMD before Windows 10), and the GOG `DDraw.dll` (DirectX 9) for "I don't know" or an unknown brand. The forum barely covers wrappers: dgVoodoo appears once (t=5887 p=39385, GOG version on Windows 7: the menu texts came back, the mouse did not react in game). The setup has shipped wrappers since 1.0.0.0 and the maintainers tuned their configurations from player feedback up to 1.7.2 (see [CHANGELOG.md](CHANGELOG.md)), so the preselection stays until tests show something better (graphics matrix TP-23).
- **Without a wrapper ("Native"):** run the setup (again), choose "Recommended settings" and then "Native" on the graphics card page; or choose "Custom install settings" and uncheck the component "DirectX Wrapper" (DirectX 7, 9, 11 and 12 can be picked there too). The setup removes the files of a previous wrapper from both game folders (`DDraw.dll`, `D3DImm.dll`, `D3D8.dll`, `D3D9.dll`, `dgVoodoo.conf`, `dgVoodooCpl.exe`) and sets the renderer to "Direct3D Hardware TnL" (with a wrapper: "Direct3D").

## Empire Earth Launcher
The setup records each installation for the [Empire Earth Launcher](https://github.com/EE-modders/Empire-Earth-Launcher), as specified in [docs/CONTRACT.md](docs/CONTRACT.md) (sections 1, 2 and 3.5) and decided in [ADR 0004](docs/adr/0004-install-record-and-integrity-manifest.md). Players do not need to do anything with these entries; they are listed here for support and for the launcher developers.

- **Install record** (regular setups): `HKLM\SOFTWARE\Empire Earth Community\Installations\EE` (or `\NeoEE`) for an installation for all users, in the 64-bit registry view on 64-bit Windows (not below `WOW6432Node`), and `HKCU\Software\Empire Earth Community\Installations\...` for an installation "just for me". Values: `ContractVersion`, `InstallPath`, `InstallMode` (`admin` or `user`), `AppId`, `GameVersion`, `SetupVersion` and, in test and CI builds, `SetupBuild` (see [Build switches](#build-switches)). Every run writes it anew; the uninstaller removes it. Portable setups write none (they have no uninstaller).
- **`install.ini`** in the hidden setup data folder of the installation (`_setupdata_EE` or `_setupdata_NeoEE`), in every variant including portable: the same values (`InstallMode` also `portable`), the selected components and tasks and the time of the run, and under `[MissingAfterInstall]` the files that were gone at the end of the installation (see [Support](#support)). Plain ASCII with CRLF and without BOM. The setup deletes it at the start of the installation and writes it at the end, so an aborted installation leaves none that looks valid; do not edit it.
- **Integrity manifest `files.sha256`** in the same folder, in every variant: the SHA-256 of every file the installation installed or kept, in the `sha256sum` format (`<hash>  <path>`, the path relative to the installation folder with `/`), one line per file, sorted by path, ASCII with LF and without BOM; the setup data folder itself, the uninstaller, `_wonkver.pub` (deleted after the installation) and files the setup did not install (your saves, mods, files the game creates) are not in it. The launcher uses it to find files that an antivirus program deleted or that changed. Like `install.ini` it is deleted at the start and written at the end of every run (first installation, update, repair, other components), from the files that run processed. Checking the files takes a few seconds on the page "Checking the installed files"; the setup log has the line `Manifest: <files> files, <MB> MB, <ms> ms, <MB/s> MB/s`. A file that stays locked (tried three times, 300 ms apart) or a path that is not ASCII is logged and leaves this run **without** a manifest instead of a wrong one. To check an installation by hand: `sha256sum -c _setupdata_EE/files.sha256` in the installation folder (Git Bash, Linux), or the PowerShell lines of test case TP-50.
- **Defaults marker** `HKCU\Software\Empire Earth Community\GameDefaults\EE` (or `\NeoEE`) with the values `EE` and `AoC`: the default game settings of this setup were applied for this account. Like the game settings themselves, the marker and the settings go to the account that runs the setup. **Installed for all users from a standard account?** With over-the-shoulder elevation that is the administrator account that confirmed the elevation, not the standard account that started the setup; every other account gets the default settings from the launcher on its first start. Regular setups only; the uninstaller removes the marker of the account that uninstalls.
- **Contract version in the uninstall key** (`Empire Earth Community: ContractVersion`): a regular setup writes it at the end, but only if it could delete the old `install.ini` and `files.sha256` and write both new ones. It is missing after a later run of a setup up to 1.7.2, when another program held one of the two files open or a file is read-only, or when the manifest could not be written (a locked game file, see above); the launcher then shows the installation state "Unknown" and advises to run the current setup again. The setup log names the cause (`Unable to delete ...install.ini: it is read-only` or `... held open by another program ...`, `No manifest in this run: ...`, then `Not writing "Empire Earth Community: ContractVersion" ...`): close that program or remove the read-only attribute and run the setup again. Files that were merely missing at the end do not prevent the value; the launcher reads them from `[MissingAfterInstall]`.
- The uninstaller removes the record, the marker and the setup data folder. Neither the setup nor the uninstaller ever touches `Software\Sierra\CDKeys` (the NeoEE CD keys).

The Windows test cases are TP-40, TP-41 and TP-50 of the [test plan](docs/TEST-PLAN.de.md).

## Notes for Modders
Empire Earth is very sensitive to version change (which leads to multiplayer incompatibility), some modders might be interested in using this setup to deliver their mods. Please do not do this unless you have created a really popular and functional modpack. We must avoid creating multiple versions of the game to avoid fracturing the community.

## Notes for Dev 
Since the script is licensed under the GNU GPL v3 you have every right to modify the setup script to generate your own versions, but you must also publish the source code of the script. So if you want to contribute I invite you to fork this project, if you have ideas of modifications to do don't hesitate to make suggestions, I also invite you to make pull requests if you think you have done something that deserves to be in this script. The version of the script I'm distributing should become the standard to facilitate future installations. I hope you understand the objective and how necessary and helpful it is for everyone. If you think something is wrong, don't hesitate to tell me!

The registry values, files and per-user game settings that the [Empire Earth Launcher](https://github.com/EE-modders/Empire-Earth-Launcher) relies on are specified in [docs/CONTRACT.md](docs/CONTRACT.md), which both repositories share. Change them only together with that file and the launcher. `ci/check_contract.py` (also in CI) fails when the tables of the contract and the script differ, see [Verify](#verify). How the setup is structured and why (module map, data flow, error handling, tests, decision records) is described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/adr](docs/adr/README.md).

## Translating
The texts of the setup are in `messages.iss`. [TRANSLATING.md](TRANSLATING.md) explains the format and lists the texts that still need a translator, in particular Brazilian Portuguese, Traditional Chinese and every text added after setup 1.7.2 (English, German and French only so far).

## Building

### Requirements
- Windows (or Wine) with [Inno Setup](https://jrsoftware.org/isinfo.php) **6.2.x**. Releases are built with 6.2.2; newer versions are untested.
- The game data and setup media. They are not part of this repository (see [Assets](#assets)).
- The AppId GUIDs of both setups (see [AppIds](#appids)).
- Python 3, only for placeholder builds and the checks (`ci/make_placeholder_assets.py`, `ci/check_messages.py`, `ci/check_test_plan.py`, `ci/check_contract.py`, `ci/compare_contract.py`); no packages needed.

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
| `TestID` | `0` = release, `> 0` = test build (fast compression, warning on start, also in silent mode; `ci\build.ps1 -TestID <n>`) | `0` |
| `SetupBuild` | build identifier that the setups write into `install.ini` and the install record (see [Empire Earth Launcher](#empire-earth-launcher)), so that builds of the same setup version can be told apart: at most 64 characters of `A-Z a-z 0-9 . _ -`, anything else stops the build. `ci\build.ps1` passes `test<TestID>-<commit>` for a test build and the short Git commit in CI (`-SetupBuild <text>` overrides it) | empty (no `SetupBuild` value) |
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

Useful options: `-Variants NeoEE/Regular`, `-OutputDir <dir>`, `-Iscc <path to ISCC.exe>`, `-KeepPreprocessed <dir>`, `-TestID <n>` (a test build, `/DTestID=<n>`, a whole number >= 0; for testing only, never distribute it, see [Testing on Windows](#testing-on-windows)), `-SetupBuild <text>` (the build identifier `/DSetupBuild`; without it a test build gets `test<n>-<short commit>`, a build in CI the short commit and any other build none), `-SignSetup` (see [Signed builds](#signed-builds)). Run `Get-Help ci\build.ps1 -Detailed` for all of them. The parts that do not need ISCC (hash list, certificate conversion, test build number, build identifier, checksum files) are in `ci\build_helpers.ps1`. Next to every setup it built, the script writes its SHA-256 file (see [Checksums of the setups](#checksums-of-the-setups)). A release build (without `-TestID` or with `-TestID 0`) also warns with the online files the setups download without a pin (see [Online localized files](#online-localized-files)).

### Checksums of the setups
`ci\build.ps1` writes `<setup>.exe.sha256` next to every setup that passed, e.g. `out\EE_Regular\EE_Setup_v1.7.2.exe.sha256`, and prints the hash (`SHA-256 <hash>  EE_Setup_v1.7.2.exe -> EE_Setup_v1.7.2.exe.sha256`). The file has the format of `sha256sum`: the 64 lowercase hex digits of the SHA-256, two spaces, the file name of the setup (no folder) and one LF, UTF-8 without BOM. It is written after ISCC has compiled and, for signed builds, signed the setup, so it is the hash of the file the players download; an existing file is overwritten. The helper is `Write-FileSha256` in `ci\build_helpers.ps1` ([ADR 0008](docs/adr/0008-release-checksums-and-contract-check.md)).

**Maintainers:** publish the hash of every released setup next to its download link (website, mirrors) and attach the `.sha256` files to the GitHub release. Do not rename a setup after the build: its name is part of the line (rename both and edit the line). Broken or repacked downloads were a recurring problem in the support forum (save-ee.com t=5741, t=3763).

**Players** check a download in PowerShell, in the folder of the setup:

```powershell
Get-FileHash .\EE_Setup_v1.7.2.exe -Algorithm SHA256
```

and compare `Hash` with the published value (PowerShell prints it in uppercase; the letters do not matter). With the `.sha256` file in the same folder, `(Get-FileHash .\EE_Setup_v1.7.2.exe -Algorithm SHA256).Hash -eq (Get-Content .\EE_Setup_v1.7.2.exe.sha256).Split(' ')[0]` prints `True`, and on Linux, in Git Bash or WSL `sha256sum -c EE_Setup_v1.7.2.exe.sha256` prints `EE_Setup_v1.7.2.exe: OK`. A different hash means a damaged or modified file: delete it and download the setup again from [empireearth.eu](https://empireearth.eu/download).

### Online localized files
The setups can download localized content (voices, campaigns, the localized intro movie, lobby texts) from `files.empireearth.eu`, with `storage.ee.zocker-160.de` as mirror. Downloads only happen with the component "Download localized voices and campaigns" and a game language other than English; AoC files only with AoC. Both servers are only used over HTTPS, and an invalid TLS certificate stops a download instead of being ignored. What the setup accepts (`downloads.iss`, `GetOnlineFileCheck` in `utils.iss`):

- **Files that can contain code** (`Language.dll`; the extensions are listed once, `CodeFileExtensions` in `utils.iss`: `.dll`, `.exe`, `.asi`, `.ocx`, `.sys`, `.scr`, `.bat`, `.cmd`, `.com`, `.ps1`, `.vbs`, `.js`, `.msi`, `.cpl`, `.lnk`, `.reg`, the Miles Sound System plug-ins `.flt`/`.m3d` and similar) only if their SHA-256 matches a hash compiled into the setup (a "pin"). Without a pin they are not downloaded at all.
- **Data files** (`data.ssa`, the campaigns, the movie, the lobby files) must match their pin if the setup has one. Without a pin they are accepted as the server sends them, but only over HTTPS with a validated certificate and never from an `http://` URL (main server and mirror alike); the setup log calls them "TLS-verified, not pinned". Inno Setup's downloads follow a redirect, **also one from `https://` to `http://`** (probed for setup v2, [ADR 0008](docs/adr/0008-release-checksums-and-contract-check.md)). So right before such a file is downloaded, the setup asks its URL with `HEAD` requests that follow no redirect themselves (`CheckOnlineFileRedirects`): every redirect must lead to `https://` again (at most five); a redirect to `http://`, a redirect without target or no answer refuses the file on that server like a failed download (the other server may still be tried), with a log line `Online file refused, ...` or `... no answer to the check of its redirects ...`. What this check cannot see is a server that answers `HEAD` and `GET` differently, or changes its answer in between; only the operator of a file server can send such a redirect, so the servers must still never redirect to `http://`, and a release should pin the files known at build time ([docs/SERVER-OPERATIONS.md](docs/SERVER-OPERATIONS.md), requirement 4 and section 6).

Why the two rules: most data files (`data.ssa` with the voices, the campaigns, the movie) only exist on the servers and can change there independently of the setup, so a build can rarely pin them. Requiring a pin for every file made the download component useless: with the official data only `Language.dll` and the lobby files had pins, and they are the same files the setup installs itself. Data files are only read by the game, and TLS with certificate validation makes sure they come unchanged from the community servers. That is trust in the server operators, not proof that a file is harmless: TLS only shows where a file comes from, and a crafted data or movie file could still attack the old parsers of the game and of Bink (2001-era code without ASLR/DEP). To rule that out for a file, pin it by placing it in `data\localized-text` (see below). Code is different: the elevated setup installs it into the game folder, where it runs every time the game starts, so the trust in a server (or in anyone who gets hold of it or of a certificate for it) is not enough for code; it must be the exact file the build knew.

How the files are downloaded (`DownloadOnlineFiles` in `downloads.iss`, with Inno Setup's built-in downloads; [ADR 0003](docs/adr/0003-built-in-downloads-instead-of-idp.md)): before the first file the setup checks which server answers over validated TLS (`SelectOnlineFilesServer`: the main server, or the mirror if only the mirror answers). Then it downloads one file at a time on a download page, from that server and, if a file fails there (network or certificate error, HTTP status, wrong size, a SHA-256 that does not match its pin, or for a file without pin a redirect to `http://` found by the check above), once from the other server, if the policy above allows the other URL too. A pinned file is checked right after its download and deleted if it does not match. The stop button of the page ends all downloads: no further request, neither to the other server nor for the remaining files. Nothing of this stops the installation.

Afterwards the setup lists, as a notice, every selected file it did not install from the download: not downloaded (failed on both servers), stopped or skipped after the stop button, discarded because it does not match its pin (e.g. updated on the server after the build, or damaged), or a program file without pin, or a file that was downloaded but could not be stored for the installation. For each of them it installs its own version. In silent mode and with `/SUPPRESSMSGBOXES` the notice is only written to the log.

The hashes come from `data\localized-text.sha256`, a list in `sha256sum` format (`<hash>  <path>`, UTF-8 without BOM), with paths relative to `data\localized-text`. The `localized` folder of the file servers has the same layout, except that it also has a lobby folder per language tag where `data\localized-text` has one folder for several languages: the setup requests the Chinese lobby files from `Lobby/zh-CN/` and `Lobby/zh-TW/` (also below `Mods/NeoEE/`), like the setups up to 1.7.2, and checks them against the entries of `Lobby/zh/` (the lobby folder of both languages, `GameLangLobbyDirs` in `setup_is6.iss`); the servers hold the same files in all three folders. Inno Setup 6.2 cannot compute SHA-256 in the preprocessor, so the list has to exist before compiling:

- `ci\build.ps1` writes it from `data\localized-text` before every build. Before compiling in the IDE or with ISCC directly, run `powershell -ExecutionPolicy Bypass -File ci\build.ps1 -DownloadHashesOnly`, or on Linux/Wine `(cd data/localized-text && find . -type f -print0 | sort -z | xargs -0 sha256sum) > data/localized-text.sha256`.
- Files that only exist on the servers (voices, campaigns, the localized intro movie) are downloaded without pin (TLS-verified). To pin one as well, place the same file in `data\localized-text` at its server path before the list is written (only `Language.dll` and the lobby folders of `data\localized-text` are packed into the setup, so the setup does not grow); a pinned file that changes on the servers is discarded until the setup is rebuilt. A `Language.dll` (or any other file with code) is only downloaded if the list has it. A release build (`ci\build.ps1` without `-TestID` or with `-TestID 0`) warns with every file the setups would still download without a pin, per product; the list is read from the code of `RegisterOnlineFiles` (`Get-OnlineFiles` in `ci\build_helpers.ps1`), and a change of that code it does not understand stops the build. A placeholder build only prints the number.
- Without the list (or with an empty one) the compiler prints a warning; the setup still offers the download, but only gets data files (TLS-verified) and no `Language.dll`. `ISCC /DDownloadHashFile=<file>` uses another list.

**Known server issue (checked 2026-10-02):** `files.empireearth.eu` serves the hosting provider's default certificate (`CN=cluster131.hosting.ovh.net`), which does not match the host name. Since the setup validates certificates, every download from it fails and the setup falls back to the mirror (`SelectOnlineFilesServer`); if the mirror is unreachable too, the installation continues with the files included in the setup. Setups up to 1.7.2 did not notice because they ignored invalid certificates. The server operators need to install a certificate for `files.empireearth.eu` (e.g. Let's Encrypt in the OVH control panel); nothing has to change in the setup. What the file servers and the API must provide (certificate with its chain, TLS 1.2 for Windows 7 clients, `Content-Length`, no redirect to `http://`, identical files on both servers), how to check it and the release criterion (at least one file server with a valid certificate) are in [docs/SERVER-OPERATIONS.md](docs/SERVER-OPERATIONS.md).

Windows 7 installations without updated root certificates or without a usable TLS 1.2 handshake cannot download these files (the setup no longer ignores invalid certificates): the installation continues with the files included in the setup. See [Support](#support).

### Contributing without the game data
```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders
```
creates a small placeholder file for every missing asset (existing files are never overwritten) and uses dummy AppIds. Such a build only proves that the script compiles for all variants: **never distribute it**, and remove the placeholder files before building with the real data.

### Unit tests
`ci\tests\unit_tests.iss` tests the `[Code]` helpers that only compute something (string split, language tag, compatibility flags, the old Windows Vista/7 compatibility values that an update removes and the Windows versions where it does (`IsLegacyVistaCompatValue`, `IsBelowWindows8`), uninstall keys, URL encoding, the URL checks of the update question, the download policy of the online files: file types with code, https URLs, https servers, what happens after each download attempt (`NextDownloadAction`: accept, try the mirror, give up, or stop all downloads after the stop button), and the Windows versions on which HTTP requests ask for TLS 1.2 explicitly, which folders the link check examines (`IsLinkGuardedFolder`); all in `utils.iss`). File-level tests write `install.ini` and `files.sha256` for files they create in `{tmp}` and walk a folder tree there for the link check; on Windows that walk is also tested with junctions made by `cmd /c mklink /J` (no administrator rights needed; Wine cannot make junctions, so there these tests are reported as `SKIP` and the last line says `<n> tests, <s> skipped`). One test runs code at run time: it sets that TLS option on a `WinHttpRequest` object, as `HttpGet` does on Windows 7, without sending a request (under Wine the option is not implemented; the test only requires that no exception escapes and logs the outcome). It is a tiny setup that runs the tests and exits without installing anything or using the network:

```powershell
powershell -ExecutionPolicy Bypass -File ci\run_unit_tests.ps1
```

On Linux with Wine: `ISCC='<Windows path of ISCC.exe>' sh ci/tests/run_unit_tests.sh`. Code that needs the wizard, the registry or the network is not covered; a helper that can be written without them belongs into `utils.iss` with a test.

`ci\tests\build_helpers.tests.ps1` tests the helpers of the build script (`ci\build_helpers.ps1`: hash list, DER copy of PEM and DER certificates, test build number, the SHA-256 file of a setup: content, LF, no BOM, overwriting, and `sha256sum -c` where that program exists; the online files a setup can download, read from the real `setup_is6.iss`, and which of them have no pin, also against changed copies of the script whose new files must be listed and whose unknown statements must stop it) with generated test certificates, and runs a copy of `ci\build.ps1` with a fake ISCC that records the switches it gets (e.g. `-TestID`) and checks the SHA-256 file next to every setup and the warning of a release build; it needs neither Inno Setup nor the game data and also runs with PowerShell 7 on Linux.

### Testing on Windows
The build workflow never runs an installer; the real-data end-to-end workflow runs them only on a throwaway GitHub-hosted runner with every server blocked (see [End-to-end test on Windows](#end-to-end-test-on-windows)), and nobody runs them on a development machine by script. The manual tests on real Windows (a laptop and virtual machines) are described in German in [docs/TEST-PLAN.de.md](docs/TEST-PLAN.de.md): safety rules (placeholder builds only in a virtual machine or on a snapshot, only your own legally obtained game data, never delete `Software\Sierra\CDKeys`, never pass a test build on, where the setup log is), how to make a test build, the server pre-check `TP-00` and every test case with its id `TP-xy`, its priority (`P1`: the short run before every release, `P2`: important, outside the short run, `P3`: optional, e.g. Windows 7 only), the build type, the starting state and the snapshot to use. All 33 cases of setup v2 are worked out, and the forum test cases 1 to 22 of the save-ee.com study are each assigned to a case (or to the launcher, or excluded with a reason); a new change adds the cases it needs.

- **Placeholder build** (way A, setup mechanics only): `ci\build.ps1 -Placeholders -TestID 1`. Copy the real `EEStatsSetup.dll` of your own installation to `data\Add-on\DLLs\EEStats\` first: the setup loads it at start, a placeholder stops it.
- **Placeholder build with the official AppIds** (way A+, the update over setup 1.7.2 without the game data): `ci\build.ps1 -Placeholders -EEAppID <GUID> -NeoEEAppID <GUID> -TestID 1 -OutputDir out\aplus`, with the AppIds read from the uninstall key of your own installation (`reg query`). For Windows such a setup is the published product: it updates an installation of 1.7.2 in place and replaces the game files by placeholders. Run it only in a virtual machine or in Windows Sandbox where the official setup 1.7.2 was installed first, **never on a computer with your real installation**.
- **Real build** (way B): your own data in `data\` (see [Assets](#assets)), the official AppIds read from the uninstall key `{<AppId>}_is1` of an existing installation (`reg query`), then `ci\build.ps1 -DownloadHashesOnly` and `ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID> -TestID 1`.
- Test builds show their warning even in silent mode, so silent test runs need `/VERYSILENT /SUPPRESSMSGBOXES`; start every test run with `/LOG=<file>`.
- **Short run before a release:** section 7 of the test plan combines the `P1` cases into ten steps on the laptop and in Windows Sandbox, about 2.5 hours with ways A and A+ and at most three hours with the way B step. A state (commit) is released when every `P1` case with all its `P1` parts passed or is excepted with a reason (e.g. "no data" for the way B parts); `P2` and `P3` cases (Windows 7 and 8.1, original CD, GOG, second accounts and computers) do not block a release.

A new case gets the next free id of its block; `python ci/check_test_plan.py` checks the form of the plan (unique ids, every case with a valid status, a priority `P1`, `P2` or `P3` and the fields of the template, the short run naming exactly the `P1` cases within three hours, the forum test cases 1 to 22 assigned) and that every id named in the documentation exists.

### End-to-end test on Windows
`.github/workflows/e2e-realdata.yml` builds the real-data setups and installs, checks and uninstalls them on a GitHub-hosted
Windows runner (`windows-latest`), which GitHub throws away after the job. The result is a red or green check in the pull
request and a German/English table in the job summary. Expect about two hours per run.

**When it runs.** By hand: *Actions* > *E2E real data* > *Run workflow* (GitHub shows the button only once the workflow
file is on the default branch; input `launcher_commit`: a full commit of the launcher fork on its branch
`LAUNCHER_BRANCH`, empty for the pinned `LAUNCHER_COMMIT`, see below). For a pull request only if it comes from a branch
of this repository, carries the label `e2e` (create it once) and changes a setup script (`*.iss`), `internal/lib`,
`internal/unofficial_isl`, `ci/build.ps1`, `ci/build_helpers.ps1`, `ci/e2e/` or the workflow. GitHub compares the whole
pull request with its base, not only the last push, so every push to a pull request with the label starts a run: add the
label when a push needs the test and remove it before pushes that do not (documentation, review fixes elsewhere). Every
run downloads the localized files of one language from the community mirror (17 files, among them the large voice files
`data.ssa` of EE and AoC and 8 campaigns), so runs are not free for the community servers. A newer run for the same
branch (a push to the pull request, or a dispatch on its branch) cancels the older one; adding another label or pushing
to a pull request without the label cancels nothing.

**Pull requests from forks never run it, and the repository must require approval.** A pull request runs the workflow
file and the scripts of its own branch, next to the game data and the built installers, so a fork's pull request could
publish them or send them anywhere. The condition in the workflow only stops harmless runs, because such a pull request
could remove it. Every repository that holds this workflow (this fork, and upstream after a merge) must therefore set
*Settings* > *Actions* > *General*, approval of fork pull request workflows: **Require approval for all external
contributors** (GitHub's default asks only first-time contributors). Approve a run of an outside pull request only after
reading its changes to `.github/` and `ci/`; to test such a change, push it to a branch of this repository.

**The launcher checks come from a pinned commit.** `LAUNCHER_COMMIT` in the workflow is a full commit of the launcher
fork (`LAUNCHER_REPOSITORY`), moved on purpose by a commit here; the job refuses a commit given by hand unless it has 40
hex digits, and any commit that is not on `LAUNCHER_BRANCH` of the fork. No branch, tag or pull request ref is checked
out: the launcher code runs as administrator next to the game data, and a run must be reproducible.

**Caches.** The two caches (official setups, innoextract) belong to the branch or pull request that created them. A
pull request run finds those of the pull request itself, of its base branch and of the default branch, not those of
another branch: a dispatch on `v2` does not help a pull request from `v2` into `master`. Before the workflow is merged,
the first run of each pull request therefore downloads both official setups again from `r2.empireearth.eu` (about
1.25 GB) and builds innoextract; its later runs use the caches of the pull request. After the merge, start the workflow
once by hand on the default branch, then every pull request finds the caches. GitHub deletes a cache that was not used
for 7 days; the next run downloads again.

What the job does, in this order:

1. **Official setups**: downloads the two official setups 1.7.2 (`EE_Setup.exe`, `NeoEE_Setup.exe` from
   `r2.empireearth.eu`, public downloads), checks their SHA-256 in every run and keeps them unchanged in the Actions cache.
2. **innoextract 1.10-dev** (1.9 cannot read Inno Setup 6.2.2 setups; there is no Windows binary of 1.10-dev): built from
   a pinned commit with MSYS2/MinGW as a static `innoextract.exe` (only system DLLs, checked with `objdump`) and cached.
3. **Assets**: extracts both setups, decompresses their setup headers (`ci/e2e/inno_headers.py`, the wizard bitmaps are
   stored there) and puts every file the v2 build reads at its source path (`ci/e2e/place_assets.py`). Which file goes
   where comes from the committed, data-free map `ci/e2e/assets-map.tsv`: one row per file (path, size, SHA-1, last write
   time, product, origin) and per empty folder, no content. Every placed file is checked again (size, SHA-1, time), and the
   asset folders may hold nothing else.
4. **Build**: `ci/build.ps1` with Inno Setup 6.2.2 for `EE/Regular` and `NeoEE/Regular`, the real AppIds (an update over
   1.7.2 needs them), release build (`-TestID 0`), unsigned (no certificate, so the task `certinclude` does not exist).
   Then `ci/e2e/readset.py` checks that the preprocessed scripts read exactly the files of the map (a new or renamed asset
   fails here until the map is generated again, see below) and that `data\localized-text.sha256` is the one of the map.
5. **Safety before any setup runs** (`ci/e2e/run_e2e.ps1 -Phase Prepare`): the hosts file blocks (IPv4 and IPv6)
   `api.empireearth.eu` (update API and every statistics endpoint, also those of `EEStats.dll`), `files.empireearth.eu`,
   `storage.ee.zocker-160.de`, `neoee.net`, `www.neoee.net`, `titan.empireearth.eu`, `empireearth.eu`, `www.empireearth.eu`
   and `www.gog.com`, and the job proves it (no address, no HTTPS answer, no WinHTTP proxy). `Software\Sierra\CDKeys` must
   not exist in any view; the job then seeds the dummy value `CI-Dummy` = `NOT-A-KEY-0000` in HKCU, HKLM (64-bit) and HKLM
   (32-bit) and checks after every setup run, uninstallation and launcher check that it is unchanged (only "intact or not"
   is ever printed). No setup runs unless this phase passed.
6. **Scenarios** (Windows PowerShell 5.1, `ci/e2e/run_e2e.ps1 -Phase A|B|E|D|C`), each starting from a clean machine
   (whatever an earlier scenario left, because it failed or was stopped, is reported as `WARN` and removed first: the
   uninstall keys, records and game settings of both products, the seeds of E, the folders of the test, compatibility,
   GPU and firewall entries of programs below them and the shortcuts; never `Software\Sierra`). Every program has a time
   limit (setup 25 minutes, uninstaller and launcher checks 10) and no phase runs past its budget, 5 minutes below the
   limit of its workflow step, of which 15 minutes are kept for the uninstallation: a program that hangs is stopped with
   its child processes and recorded as `FAIL`, and the scenario still uninstalls, before GitHub would stop the step:

   | Scenario | What runs |
   |---|---|
   | A | EE for all users, German, type full: the only run with downloads (the mirror is unblocked only while this setup runs; the main server stays blocked, so the way "main server unusable, mirror" is tested); checks, launcher checks (installing account, then a fresh account), uninstallation |
   | B | NeoEE for the current user, English, without the CD key task; a repair with a junction in `Data` (no link check in the user mode); uninstallation |
   | E | EE for all users into `C:\EE CI\Custom Root` next to traces of a foreign installation (an HKLM key of an old NeoEE installer, `C:\Sierra\Empire Earth`, a GOG uninstall entry pointing into the chosen folder, two entries that must not count) |
   | D | On E: a junction in `Data` and a hard link in `Users` stop the update with exit code 7 and change nothing; then an update without the DirectX wrapper; uninstallation |
   | C | The official EE setup 1.7.2, v2 over it (components, tasks, the player's game settings by class, the old per-user `RUNASADMIN`, the random map folders), 1.7.2 again (the uninstall key loses the contract version), v2 again, damage as the launcher sees it (a modified data file, a missing code file, a missing program), repair, uninstallation |

   After every run the checks of the contract: K1 install record (1.1), K2 `install.ini`, components and tasks (1.2),
   K3 uninstall key (1.3), K4 integrity manifest (format, every line hashed again, the file tree), K5 game settings
   (3.1 to 3.3, the window size from the log line `Screen:`), K6 GPU preference, K7 defaults marker, K8 compatibility values
   (3.7), K9 CD key dummy, K10 files and privacy (no `EEStats.dll`, the privacy `dreXmod.config`, the wrapper the GPU page
   chose, the NeoEE programs of the install mode, no `_wonkver.pub`), K11 firewall rules, K12 shortcuts, K13 write
   permissions, K14 the setup log (expected and forbidden lines), K15 no HTTP request in English runs, DL the downloads
   (pins, the redirect check over https, every download in the manifest with the same hash), U what the uninstaller must
   remove. L runs the launcher core of the launcher fork (`Empire-Earth-Launcher.RealMachineTests`, category `RealMachine`)
   against the real installation with an expectation file per step: discovery, quick and full integrity check, the state
   of the defaults, the defaults of the launcher start for the installing and for a fresh account, and the machine state.
7. **Report**: `ci/e2e/report.py` writes the table to the job summary; the job is red if any check fails or a scenario did
   not run to its end. `SERVER` marks a community server that did not answer while the setup behaved correctly.

**Hard rules of the job** (enforced by the scripts before a setup starts, `Test-E2ESetupArguments`): never the telemetry
component; never the tasks `neoee_cdkeys` (the NeoEE CD key registration and `authtools.dll` never run), `certinclude`
(the official setups would add their root certificate; the job checks the certificate stores), `directplay` or
`dxwebsetup`; the official setup and every NeoEE setup only with an explicit `/TASKS` list (they preselect those tasks);
at most one run in a language other than English (the localized files of one language are downloaded once per run from
the mirror); the official setups only from the cache or `r2.empireearth.eu` before the hosts block.

**Legal note: no game data leaves the runner.** The extracted files, the placed asset folders, the built installers and
the installations exist only in the job workspace and the temporary folder of the runner and are deleted at the end of the
job (GitHub discards the runner anyway). They are never committed, cached, uploaded or printed: innoextract runs with `-q`,
the scripts print counts, paths and check results only, and every hash in the report is replaced by `<hash>`. Only two
caches exist, the unchanged official setups (public downloads) and `innoextract.exe`, each saved explicitly by path. The
only upload is the report folder (`e2e-realdata-report`: setup logs, launcher results, the expectation files, the report);
`ci/e2e/guard_upload.py` refuses it unless it is a separate folder holding at most 400 text files of at most 8 MB each and
64 MB together, none a link, none with the signature of a binary file and none with the SHA-1 of a file of the map. The map
holds names, sizes, SHA-1 values and times of the files of the official setups, nothing of their content.

**Not covered** (stays with [docs/TEST-PLAN.de.md](docs/TEST-PLAN.de.md)): starting the game, graphics cards and the
effect of the GPU preference (the runner has none, the GPU page chooses the DirectX 9 wrapper there), Windows 7 and 8.1, a
second Windows account (the launcher's fresh account is simulated by removing the game settings), interactive pages and
messages, the stop button of the downloads, display scaling and low resolutions, the NeoEE CD keys, signed builds and the
portable variants. Section 12 of the test plan lists which test cases the job covers.

**Self-tests**: the tools of the job are tested without game data in every build (`build.yml`) and in the first step of
the job: `python -m unittest discover -s ci/e2e/tests -p "test_*.py"` (header extraction with a made-up setup, placing
files, the read set against the map, the upload guard, the report, the committed map is well-formed) and
`powershell -ExecutionPolicy Bypass -File ci\e2e\tests\e2e_helpers.tests.ps1` (every rule of the checks with fake data,
also under PowerShell 7 on Linux; all scripts of `ci/e2e` must parse in Windows PowerShell 5.1 and be ASCII).

**Regenerating the map** (maintainers, locally, only with the official setups): after a change of `[Files]` or `[Setup]`
that adds, renames or removes an asset, the step "Check the build inputs against the map" fails. Then extract both official
setups with innoextract 1.10-dev (`innoextract -e --collisions=rename-all -d x\EE EE_Setup.exe`, the same for NeoEE),
decompress their headers (`python ci/e2e/inno_headers.py EE_Setup.exe hd\EE`, the same for NeoEE), make a folder with the
complete asset folders of a real-data build (e.g. `ci/e2e/place_assets.py` with the old map plus the new files), run
`ci\build.ps1 -DownloadHashesOnly` there and preprocess `EE/Regular` and `NeoEE/Regular` (`ci\build.ps1 ... -KeepPreprocessed pp`),
then `python ci/e2e/gen_map.py --assets <folder> --pp EE=pp\EE_Regular.iss --pp NeoEE=pp\NeoEE_Regular.iss --extract
EE=x\EE NeoEE=x\NeoEE --headers EE=hd\EE NeoEE=hd\NeoEE --out ci/e2e/assets-map.tsv`. It fails if a file the build reads is
not in one of the official setups (then the job cannot place it). Commit only the map, never the folders.

### Verify
Before a commit, run the checks that the change touches. The CI workflow runs all of them except the copy check of the contract:

| Check | Command |
|---|---|
| Messages, their use in the own scripts, BOM and CRLF of every own script | `python ci/check_messages.py` (`--self-test` checks the check itself) |
| Unit tests | `powershell -ExecutionPolicy Bypass -File ci\run_unit_tests.ps1` (Linux/Wine: see [Unit tests](#unit-tests)) |
| Build script tests | `powershell -ExecutionPolicy Bypass -File ci\tests\build_helpers.tests.ps1` (also `pwsh` on Linux) |
| All four variants compile | `powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders` (see [Contributing without the game data](#contributing-without-the-game-data)) |
| Test plan: unique test case ids, a status and a priority per case, the short run (exactly the `P1` cases, at most three hours), forum test cases 1 to 22 assigned, every id named in the documentation defined | `python ci/check_test_plan.py` (`--self-test` checks the check itself) |
| The tables of the contract match the script; `[Files]` flags below `{app}` | `python ci/check_contract.py` (`--self-test` checks the check itself) |
| Both copies of the contract are identical | `python ci/compare_contract.py <launcher clone>` |
| Tools of the end-to-end test (no game data) | `python -m unittest discover -s ci/e2e/tests -p "test_*.py"` and `powershell -ExecutionPolicy Bypass -File ci\e2e\tests\e2e_helpers.tests.ps1` (also `pwsh` on Linux) |

`docs/CONTRACT.md` exists in this repository and in the [launcher repository](https://github.com/EE-modders/Empire-Earth-Launcher) and must stay byte-identical; a change of the contract is one step in both repositories (same text, same commit subject). CI cannot reach the other repository, so after every change of the contract run the copy check against a local clone of the launcher, e.g. `python ci/compare_contract.py ../Empire-Earth-Launcher` (the clone's root folder or its `docs/CONTRACT.md`). Exit code 0: identical, the SHA-256 is printed; 1: different, both SHA-256 values and the first differing line are printed (and a hint if only the line endings differ, see `core.autocrlf`); 2: a file is missing. `python ci/compare_contract.py --self-test` checks the script itself.

`python ci/check_contract.py` checks that the tables of the contract match the script, the source of truth, and runs in CI: the contract version in its header against `#define ContractVersion` of `setup_is6.iss`, the publishers of the products (0) against `MyAppPublisher` of `config_ee.iss`/`config_neoee.iss` and the constants `CommunityPublisherEE`/`CommunityPublisherNeoEE` of `utils.iss`, the row `code` of 2.4 against `CodeFileExtensions` (`utils.iss`), the table of 3.2 against the `[Registry]` values of the game settings keys (name, type, data of both games including the ending epochs, class S/D = `deletevalue`, P = `createvalueifdoesntexist`), the table of 3.3 against the constants `MinGameWindowWidth` ... `MaxGameWindowHeight` (`utils.iss`), the table of 3.4 against the GPU preference entries (program, component, data, Windows versions, task) and the table of 3.7 against the compatibility entries (the flags of each task, the Windows compatibility mode, the Windows versions from `MinVersion` and `OnlyBelowVersion` of the tasks and entries, `(opt-in)` for an unchecked task, the root per install mode and the order; two entries that could write the value of one program in the same run are an error). It reads only tables, never the prose of the contract, and preprocesses `[Registry]` for all four build variants with a small interpreter of the ISPP directives used there; a directive or function it does not know is an error, not a guess. It also lints `[Files]` (contract 2.3): every entry whose `DestDir` is `{app}` or below has `ignoreversion` and none has `onlyifdoesntexist`, `promptifolder` or `confirmoverwrite`, so that every run processes every file it installs and the integrity manifest can list it, and the external entries that install the verified online files from `{tmp}\verified` must name the same sources, folders and components as `RecordVerifiedOnlineFiles` (`installstate.iss`), which adds those files to the manifest. A change of a default therefore fails CI until the contract is changed too, in both repositories, followed by the copy check above. `python ci/check_contract.py --self-test` runs it against modified copies (e.g. `Music Volume` `$2C` -> `$2D`, another publisher in `config_neoee.iss`, an extension missing, the window width limit 1920 -> 2560, `GpuPreference=1;`, `WIN7RTM` -> `WIN8RTM`, the row `compatibility_legacy` missing or with `WINXPSP3`, an entry without `ignoreversion`, the learning campaign recorded in the wrong folder) that must fail. After the placeholder build, `python ci/check_contract.py --preprocessed out/preprocessed` (CI; locally after `ci\build.ps1 -Placeholders -KeepPreprocessed out\preprocessed`) compares the `[Registry]` entries of that interpreter with the scripts ISCC itself preprocessed, for all four variants, and lints their fully expanded `[Files]` sections.

### Continuous integration
`.github/workflows/build.yml` checks the messages and the own scripts (`python ci/check_messages.py` and its `--self-test`), checks the test plan (`python ci/check_test_plan.py` and its `--self-test`), checks the contract against the script (`python ci/check_contract.py`, its `--self-test`, and after the build `--preprocessed out/preprocessed`), runs the self-test of the contract copy check (`python ci/compare_contract.py --self-test`), the unit tests, the build script tests and the self-tests of the end-to-end tools, runs the placeholder build with Inno Setup 6.2.2 on `windows-latest` for every push and pull request and uploads the preprocessed script of every variant as an artifact. `.github/workflows/e2e-realdata.yml` builds and tests the real-data setups on Windows, see [End-to-end test on Windows](#end-to-end-test-on-windows).

### Conventions
The own `.iss` files are UTF-8 **with BOM** and CRLF (see `.editorconfig` and `.gitattributes`): Inno Setup 6.2 reads files without BOM as ANSI and would break non-ASCII text. Release notes go into [CHANGELOG.md](CHANGELOG.md). After changing `messages.iss` or any own script, run `python ci/check_messages.py`: it reports duplicate messages, `==` typos, unknown language prefixes and messages that are used but not defined, which Inno Setup compiles without a warning, translations out of the standard order (`--sort` fixes that), and every own script without the UTF-8 BOM or with a line end other than CRLF. It finds the own scripts itself (every `*.iss` in the root folder and in `ci/tests`, plus every file named by an `#include "..."` line of `setup_is6.iss` or of a script found that way, without `internal/`), so a new module is checked from its first commit. `--coverage` adds the list of missing translations per language (see [TRANSLATING.md](TRANSLATING.md)).

## License
Consider setup_is6.iss, config_ee.iss, config_neoee.iss, utils.iss, pages.iss, messages.iss, extension.iss, downloads.iss, randommaps.iss, eestats.iss, telemetry.iss, environment.iss, installstate.iss under **GPL-3.0 License**.
