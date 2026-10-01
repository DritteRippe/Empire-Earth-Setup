# Changelog

Release notes of the Empire Earth Community Setup. The version is the setup version
(`MySetupVersion` in `setup_is6.iss`); EE and NeoEE setups of the same version share the same
features. Up to 1.0.4.1 the setup used the four-part version format of the game, since 1.5.0 it
uses semantic versioning.

Until 1.7.2 these notes lived in the header of `setup_is6.iss`. They were moved here unchanged
apart from spelling fixes, the 1.7.1 correction noted there and an off-topic personal remark in
1.0.3.0 that was left out. Dates are the release dates given in the header.

## Unreleased

Refactoring and quality fixes (no new game content).

### Added
- Build switches can be set on the command line instead of editing the script:
  `ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss`
  (also `SignSetup`, `CertFileName`, `CertHashSHA1`, `TestID`); invalid values stop the build
  with a clear message.
- `ci/build.ps1`: clean two-pass build of all four variants, optionally against placeholder
  assets; GitHub Actions workflow compiling every push and pull request with Inno Setup 6.2.2.
- `ci/make_placeholder_assets.py`: creates placeholder assets for contributors and CI, and lists
  the assets a variant needs (`--list`).
- `ci/check_messages.py` (also run by the workflow): finds duplicate messages, `==` typos, unknown
  language prefixes and used but undefined messages in `messages.iss`.
- `.gitattributes` and `.editorconfig` (UTF-8 with BOM and CRLF for the own `.iss` files).
- This changelog (moved out of the script header) and a "Building" section in the README.
- SHA-256 list of the online localized files (`data\localized-text.sha256`, build switch
  `DownloadHashFile`): `ci/build.ps1` writes it before compiling, `-DownloadHashesOnly` only writes
  it (for builds in the Inno Setup IDE). See README, "Online localized files".
- Localized texts (English, German, French) for the new messages and for the task descriptions of
  the firewall, administrator and certificate options.

### Changed
- The hidden setup data folder (holds `EEStatsSetup.dll` for the uninstaller) is now
  `{app}\_setupdata` instead of `{app}\<AppId>`; updates remove the old folder.
- Running the game as administrator is opt-in: administrative installs no longer set
  `RUNASADMIN` for the installing account by default, and updates remove that old per-user value
  (only if it is exactly the old default). The unchecked task "Always run the game as
  administrator, for all users" sets it for all users (HKLM) and now also works without the
  compatibility tasks. With it, the setup no longer gives all users write access to `Data`,
  `Users` and the config files, which an elevated game would read. Per-user values (GPU
  preference, game defaults) still go to the account that ran the setup; the script documents why.
- Firewall rules: unchanged in effect (program rules for the game, all ports), but `profile=any`
  is now written out and documented: hosting needs incoming connections on "Public" networks too.
  The task describes what it allows.
- Signed builds only (`SignSetup`): installing the community certificate as trusted root
  certification authority is opt-in for administrators too (it was preselected). The build stops
  unless `CertHashSHA1` is the thumbprint of the DER certificate file; the setup only adds a
  certificate file with that thumbprint, and the uninstaller removes it only if this product added
  it and the other product (EE/NeoEE) does not use it, with consistent `certutil` arguments.

### Removed
- Entries for Windows XP and older: the WIN98 compatibility mode and the pre-Vista `netsh
  firewall` rules (23 entries). Setups made with Inno Setup 6 do not start on these systems, so
  the entries never ran.

### Fixed
- The build refuses empty, malformed or identical AppIds. An empty AppId used to compile, turned
  the setup data folder into the install folder itself (hidden, and deleted completely on
  uninstall) and let EE and NeoEE share one uninstall key.
- `setup_is6.iss` has its UTF-8 BOM again (lost in 1.6.0). Without it Inno Setup read the file as
  ANSI, so the uninstall cleanup of the pt_BR folder `Users\default\Civilizações` never matched.
- Every online localized file is requested from the mirror at the same path as on the main server
  (some AoC mirror URLs pointed to wrong paths).
- The uninstaller starts even if `EEStatsSetup.dll` is missing from the setup data folder (e.g.
  removed by an anti-virus): it is only loaded on demand, which the uninstall no longer needs, so
  the elevated uninstaller does not load code from the installation folder.
- NeoEE CD keys: the setup registers them itself after all other installation steps instead of
  through a dummy `cmd.exe /C` entry (which failed where cmd.exe is blocked, e.g. by AppLocker). A
  missing `authtools.dll` no longer stops the setup from starting and is reported when the keys
  are registered (the old file checks and the 0.5 s wait could not detect it). Installation
  folders with a comma or characters outside the system code page are reported instead of being
  passed garbled to the CD key tool. The messages are localizable (English, German, French) and
  "Sythax" is spelled correctly. The arguments sent to the tool are unchanged.
- Art of Conquest: with telemetry declined, AoC gets the privacy versions of dreXmod v2/v3 (they
  were copied into the Empire Earth folder, so AoC kept the versions with tracking), and the
  downloaded localized learning campaign goes into the AoC folder instead of the EE folder.
- EE setup: the Omega and NeoEE Extra random maps for Empire Earth are installed into the Empire
  Earth folder. They went into the AoC folder (mixing EE and AoC maps there), NeoEE Extra only when
  AoC was selected.
- NeoEE under Wine: the Wine configuration for AoC (`NeoEE.cfg`) is only installed with AoC.
- Installing without AoC no longer creates AoC registry values (VSync, window size), which also
  stayed behind after uninstalling.
- Compatibility options: Windows 8 and 8.1 get the compatibility entries of Windows 8+ (the
  entries required Windows 10, so 8 and 8.1 got none), and Empire Earth gets the Windows 7
  entries on Windows 7 (a wrong version filter, `0.6.2` instead of `0.0,6.2`, had only let them
  apply to AoC).
- Portable setups no longer leave an uninstall entry in the registry (holding only the setup
  type) when installed with the recommended settings.
- Tasks and components of the previous installation are matched exactly (release note 1.0.3.0
  announced it, but each list item was still searched as a substring).
- Polish texts: the description of the installation mode page is no longer replaced by "AMD"
  (the AMD option of the GPU page was saved under the wrong name), and two texts no longer start
  with "=". English telemetry option: "its" instead of "it''s".
- The game language page no longer explains "*"/"**" quality markers that no language carries.

### Security
- Online localized files: TLS certificates are validated (invalid certificates used to be
  ignored), and a downloaded file is only installed if its SHA-256 matches a hash compiled into
  the setup. Other files are deleted, logged and reported, and the setup installs its own files
  instead. The hashes come from `data\localized-text.sha256`, which `ci/build.ps1` writes from
  `data\localized-text`; a setup built without it downloads nothing (see README, "Online
  localized files"). The reachability check of the file servers no longer falls back to HTTP.
  Very old Windows 7 installations without updated root certificates can no longer download
  these files and continue with the files included in the setup; they should install the
  Windows updates or use the full/offline setup.
- Update check: HTTPS only (it used to retry over plain HTTP after any error) and only HTTP 200
  answers count. The download link sent by the server is only opened if it is an https URL of
  empireearth.eu, neoee.net or github.com/EE-modders, otherwise https://empireearth.eu/download
  opens. Links open in the browser of the original user instead of with the setup's admin
  rights, and the update question is shown as a question instead of an error. Systems without
  TLS 1.2 support skip the update check.
- Setup statistics are only sent when the telemetry component of this product is selected. A
  refusal used to send the same request with components, tasks, VM detection and OS version (only
  the user id was left out); now no request is made at all, and the uninstaller never sends one.
  The consent box is no longer pre-checked because of the consent given for the other product
  (EE/NeoEE). The request uses HTTPS only (no HTTP fallback), all values are URL-encoded, and the
  log no longer contains the query with the anonymous user id.

## 1.7.2 - 2023-12-04

Updated dreXmod config

- dreXmod config changes
  - Disabled mod section
  - Fixed invalid HUD size since 10 players support

## 1.7.1 - 2023-12-03

Random Map Script fixes

- Fixed an invalid RMS in the NeoEE Extra RMS
- Fixed invalid Vanilla custom RMS selection

The script header repeated the title and date of 1.7.0 for this release (copy-paste error).
The title above is taken from its content and the date from its release commit (88f0c23).

## 1.7.0 - 2023-11-29

dreXmod update and performance improvement

- Updated dgVoodoo from v2.81.0 to v2.82.1
  - Corrected window size issue when going in game from lobby/scn editor and dgVoodoo
  - White minimap fixed
- Added DDrawCompat 0.5.1 pre-release with EE fix #251
- Minor file clean-up improvement
- Added NeoEE extra maps by default for NeoEE installs
- Updated French _WONStatus.cfg
- Disabled Anti-Virus prevention message as most anti virus no longer report false positive
- Updated dreXmod from v3.2 to v3.4
  - Fixed game crash on Windows < 8 caused by 32 bits display check skip
  - 10 Players support in lobby
  - Menu resolution editable during runtime in the game settings
  - Force vertex buffer into system memory for T&L
  - Auto updater don't lock process for more than 5s (was 100s)
  - Missed message summary while in game

## 1.6.1 - 2023-07-30

dgVoodoo update and window priority fixed

- Updated dgVoodoo from v2.79.3 to v2.81.0
- dreXmod now show EE intro video by default if present to avoid window priority focus bug with dgVoodoo
- dreXmod edited to respect XML v1 convention (header comment was wrong)

## 1.6.0 - 2023-07-18

NeoEE maps update, localization fix and dXm update

- Updated dreXmod from v3.1 to v3.2
  - The game can now load campaign in other languages than the one used by Language.dll
  - Rank database fetching reduced with cache
  - A little faster game saving
  - A little faster game start (no more strange windows creation on game start)
  - Fixed invalid map type when doing /[set name] in an existing multiplayer game
  - Now possible to close the previous game instance in case it's still running in background
  - Fixed lobby/game rank icon size that was not respecting the resolution mentioned in dreXmod.config
  - Gate-crash fix (the patch is already present on NeoEE, but since it's now in dxm any EE/AoC instance will have the fix)
- Include dreXmod image web cache by default to reduce the freeze time during first login
- DX Web setup only run for DX9 and native render
- Fixed problems with the language patching (EE-modders/localized-text)
- Fixed invalid auto GPU selection
- Reworked dgVoodoo configs
- Fixed invalid NeoEE WON files copy
- Disabled online DirectX End-User Runtime install for Wine
- Improved laptop compatibility by suggesting to Windows 10/11 to use a real graphic card if present
- Updated IS from 6.2.1 to 6.2.2
- Use the Windows resolution as default game resolution if >=1024x768 && <=1920x1080
- Fixed invalid repair/modify auto selection (was messed up with telemetry agreement)
- Added Kazter RMS Pack v1 for Neo (and included Perfect Island by yukon) (+13 (11 + 2) maps)
- Stats send is now asynchronous (not sure that it work)
- Removed J2 civs

## 1.5.0 - 2023-02-06

Massive bug fixing in the setup, more simple installation and new language behaviour for setup

- Changed setup versioning to semantic versioning (old one didn't make sense but was respecting the format of the game)
- Added localized message for telemetry
- Updated dgVoodoo from v2.71.3 to v2.79.3
- Fixed tab overlapping in the Internet Screen and adjusted the one in the LAN Screen
- Fixed telemetry selection when disabled in install mode screen that was still enabled in custom components list
- Updated dreXmod from v3.0 to v3.1
  - Fix AoC camera bug introduced in v3.0
  - Reworked themes to support dynamic fonts & UI (resolution)
  - dxmdata is now located in data\dxm
  - Fixed a crash when dxmdata was not found
- Updated EES from v1.0.4 to v1.0.5
- Added 'Take JPG Screenshots' to regedit, allowing game screenshots to be jpg and not bmp, which greatly reduces the files size
- Reactivation of the DirectPlay installation
- Reworked languages folders to fit https://github.com/EE-modders/localized-text
- The setup language is now different than the game one, so a game lang page has been added
- The setup no longer ask the setup lang except if unable to detect a setup compatible one
- Fixed invalid telemetry selection that could be unselected in some cases
- Fixed a bug that make the setup telemetry always report installed as true
- Thanks to Jodocus authtools source code, I converted it to a dll with built-in admin/user support, AV should be happy now
- Automatic GPU detection for DirectX Wrapper
- Added Warning Message Box (and log) if authtools.dll is removed (probably by antivirus)
- Muting the setup audio will now pause the music instead of muting it
- Updated IDP from v1.5.1 to v1.6.0 (compiled manually using VS2005 on XP)
- DirectX End-User Runtime install now use the web based installer to reduce the setup
- Added EE & AoC mutex to Setup to detect and avoid operations while an instance is running

## 1.0.4.1 - 2022-12-26

Runtime fix

- DLL are now compiled with /MT to ensure no additional runtime libs are required
- This include: EEStats.dll EEStatsSetup.dll EEDiscord.dll

## 1.0.4.0 - 2022-12-24

Better support for Wine and ARM, added Telemetry (+possibility to accept/refuse) and dreXmod 3

- Added Empire Earth Stats v1.0.4
- Added dreXmod v3 (yeah, I'm not kidding, it's finally released)
  - Add a ranking system in the multiplayer lobby
  - Add an anti cheat system
  - Improved resolution patch
  - Add a Lobby Theme and Mod system
  - Add a quick civ selection in game
  - Various minor improvement and fix for the game and lobby
- Now able to agree or reject tracking for dreXmod and EES!
- Updated EE Discord from v1.0 to v1.1.1
- More secure files and folder permissions, only Data/Users can be edited by anyone (avoid non-admin to add/edit dll to game dir)
- Show update and not repair when a setup version different from the one already installed is started
- EE Diag is no more selected by default with Wine
- Fixed invalid regedit path not overwritten when not created by the setup (Sierra Setup create but don't delete it...)
- Fixed Wine detection, the setup was reading the registry, we are now using a dll that call ntdll.dll -> wine_get_version
- Disabled compatibility, firewall, certutil and file permissions flags for Wine (was useless and speed up the install process)
- Removed Retail/GOG text on EE/AoC banners since we only use Retail
- Less visible EE black border in startup banner and reduced EnergyCube logo opacity
- Added Setup mutex to avoid multiple instance running at the same time
- Reworked the Setup code and reorganized some parts because the code was getting really messy
- Added ARM support (tested on Windows 11 ARM64 Parallels Desktop)
- Fixed regedit entry for Wine installations (created even without using AoC for ex.)
- Added EE and AoC pl campaign thanks to jorrr1#1558
- Fixed Scenario Editor render bug caused by HD Terrain that was transparent

## 1.0.3.0 - 2022-04-14

eC Civs update, lobby regist. for Gen Z, fixed Linux setup crash, easy install mode and CD Keys/Install repair

- Updated eC civs thanks to Kazter
- Added back the NeoEE Updater because it could still be required
- NeoEE registration now allow year up to 3000 (was limited to 1999)
- Fixed NeoEE Admin binary headers
- Added a new page in the setup to install with default options (easy) or custom options
- Added a new page for default options to select GPU vendor to try to apply settings
- Renamed 'Game Intro' to 'Install intro videos' to avoid that people don't understand
- Updated HD Icons by Fortuking
- CD Keys now display an error message when fail
- Installation step has been reworked to use safer IS function instead of the page ID
- Components/Tasks now split the elements rather than stupidly looking for a match in the whole reg list as string
- Added back dgVoodoo DX 11 config and more stable DX 12 thanks to Giord (also removed useless dgVoodoo dlls files)
- Fixed AoC directory creation when not installing it while using DirectX Wrapper
- Reworked gold corners of IG interface (isn't in HD content, it's by default)
- Removed already installed warning

## 1.0.2.0 - 2022-03-06

NeoEE Map fix, new HD content inc. icons with/without letters

- Fixed invalid maps on NeoEE
- Fixed EE:Diagnostic error while EE running
- Reworked WON Lobby Dialog images
- Added tips for recommended multiplayer max pop for NeoEE
- Updated HD Icons by Fortuking
- Added some HD terrain textures from Yukon mod
- Better file clean-up (OOS, UPnP)
- Reworked Omega content management in the Setup

## 1.0.1.0 - 2022-02-20

NeoEE CDKeys user support, fixed Regedit and added new tool

- Patched authtools.exe to install CDKeys in HKCU (now there is 2 authtools bin)
- Patched EE & AoC to read CDKeys in HKCU (now there is 2 Neo EE/AoC bin)
- Fixed wrong regedit compatibility delete that was deleting the entire (Layers) key
- Reworked compatibility flags, with fewer flags and better admin rights
- Added Empire Earth Diagnostic, a simple tool giving install information (.NET 4)
- Better certificate uninstall (check if another game is installed)
- Allow to install the certificate as user
- Redirected Chinese traditional setup messages to Chinese

## 1.0.0.1 - 2022-02-17

NeoEE version fix

- Fixed invalid regedit path for NeoEE (Installed From Directory was reversed)
- Deleted old NeoEE integrated updater

## 1.0.0.0 - 2022-02-16

Initial Version

- EE & AoC (in 11 languages)
- Support NeoEE, dreXmod, Omega content
- Support NeoEE CDKey generation (Admin)
- Download localized content online (support mirror)
- Online update checker (support mirror)
- DirectX Wrapper (DX9 with GOG dll and DX12 with dgVoodoo dll)
- Better compatibility with additional flags
- HD Content with FortuKing textures
- Registered in Firewall (Admin)
- DirectX 9 Install (when using DirectX Wrapper for DirectX 9)
- Removable Movies
- Digitally signed

Notes:
- DX11 (API 10 & 11) has been disabled. It is obviously impossible to fix the bug related to the
  full screen of the lobby (which puts the main window in window).
- Reborn.dll is currently disabled because of a bug that makes it unusable with dgVoodoo (or makes
  the window bug occur even with DirectX 12).
- Since after analysis the binaries of GOG and the one of the 2002 Empire Earth crack are identical
  the installation mode of the GOG binary has been removed since it is useless (its equivalent is to
  simply use the DirectX Wrapper of DirectX 9)
