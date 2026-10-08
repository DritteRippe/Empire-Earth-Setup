# Third-party components shipped by the setups

The setup scripts are licensed under the GNU GPL v3 (README, "License"). The setups contain and install third-party files
that keep their own terms. This file lists the components whose terms restrict how they may be shipped (dgVoodoo, BASS)
and names the origin of the other binary components, as far as it is known. The authors of the content are also named in
the header of `setup_is6.iss`. This is a record for maintainers and packagers, not legal advice.

## dgVoodoo 2

| | |
|---|---|
| Author | Dege, http://dege.fw.hu/ |
| Version | 2.87.5 (`DgVoodooVersion` in `setup_is6.iss`), official release archive `dgVoodoo2_87_5.zip` |
| Files the setups install | `DDraw.dll` and `D3DImm.dll` (32-bit, `MS\x86` of the archive) and, on 64-bit Windows, `dgVoodooCpl.exe` (x64), into the folders `Empire Earth` and `Empire Earth - The Art of Conquest` when a dgVoodoo level of the component "DirectX Wrapper" is selected |
| Pins | `pins/dgvoodoo.txt` (SHA-256 and size of each file and of the archive) |
| Not dgVoodoo files | the five configurations `config/dgVoodoo/*.conf` (the settings of this project, installed as `dgVoodoo.conf`) |

Terms of dgVoodoo ("Redistribution rights", dgVoodoo readme): "You can freely ship your game or game mod with individual
dgVoodoo files included. If you want to host or re-distribute dgVoodoo as a standalone component for any reason then you
must provide the full .zip package. You cannot bundle dgVoodoo inside launchers or frameworks, for general use across
multiple applications."

How the setups comply: they ship individual dgVoodoo files with the game, into its game folders, and nothing else uses
them. dgVoodoo is never offered as a download of its own. The Empire Earth Launcher neither contains nor downloads
dgVoodoo; it only reads `dgVoodoo.conf`. Keep it that way: dgVoodoo stays in the setups.

## BASS

| | |
|---|---|
| Author | Un4seen Developments, https://www.un4seen.com/ |
| Version | 2.4.16 (version resource of both DLLs, "Copyright © 1999-2021") |
| Files in this repository | `internal/lib/bass/x86/bass.dll` and `internal/lib/bass/x64/bass.dll`, imported by `internal/lib/bass/bass.iss` (the Inno Setup glue, by EnergyCube) |
| How the setups use it | Compiled into every product setup (`dontcopy`, never installed): Inno Setup extracts the DLL of the install mode into the temporary folder of the setup when it starts, the setup plays its music `Loop.flac` with it, and the folder is deleted at the end. Nothing else uses it. The suite installer does not contain it. |
| Source code | Closed source, not under the GPL |

Terms of BASS, in short (the licence section of `bass.txt` in the BASS package and the BASS page of un4seen.com are the
binding text): BASS is free for non-commercial use; a commercial product needs a licence from Un4seen. The setups are
distributed free of charge.

Open points, recorded so that they can be checked: the licence text of version 2.4.16 is not in this repository, and
whether shipping the closed-source library inside one setup program with the GPL-licensed script is fine has not been
checked legally. BASS came with the script from upstream (it is in the setups up to 1.7.2), so this fork did not choose it.
Replacing it, or adding its licence text next to the DLLs, is a decision for a later release.

## Other binary components

None of these files is in this repository: a build takes them from `data\` and `internal\runtime\` (README, "Assets").
In the real-data build of CI every one of them is a file of the official setups 1.7.2 (`ci/e2e/assets-map.tsv` lists
the origin of each file), so they are the files that upstream shipped. Their licence texts are not part of this
repository, and this fork has not re-checked their terms.

| Files | What the setups do with them | Origin, as far as known |
|---|---|---|
| `EEStatsSetup.dll` | Loaded by the setup while it runs (system information: Wine, graphics card; `eestats.iss`) and kept in the setup data folder for the uninstaller | EE Stats of the Empire Earth community, shipped by upstream; author and terms not recorded here |
| `EEStats.dll` | Installed into the game folder only with the component "Telemetry (Compatibility and Stats)", which the player opts into | as above |
| `EEDiscord.dll`, `discord_game_sdk.dll` | Installed with the component "Discord Presence" | `discord_game_sdk.dll` is the Discord Game SDK of Discord Inc. (Discord's terms for developers apply); `EEDiscord.dll` comes from the community, author not recorded here |
| `dreXmod.dll` (dreXmod 2 and 3, dreXmod 2 also in a build without tracking) and the files below `Data\dxm` | Installed with the dreXmod components | dreXmod by yukon aka. drex (header of `setup_is6.iss`) |
| `DDraw.dll` (GOG) | DirectX wrapper "DirectX 9" | GOG's wrapper for Empire Earth (header of `setup_is6.iss`) |
| `DDraw.dll` (DDrawCompat) | DirectX wrapper "DirectX 7" | DDrawCompat; version and terms not recorded here |
| `authtools.dll` | Loaded by the NeoEE setup only for the task that registers the NeoEE CD keys, never installed | NeoEE, closed source |
| `neoee.dll`, `NeoEEUp.exe` and the NeoEE game programs | Installed by the NeoEE setup | NeoEE |
| `EE-Diagnostic.exe` | Installed below `Tools\Diagnostic` of the game folder | Empire Earth Diagnostic 1.0.0.1 of the community, author not recorded here |
| `Language.dll` of every language | Installed with the language; downloaded files only if they match their pin | [localized-text](https://github.com/EE-modders/localized-text) of EE-modders |
| The programs and libraries of the games (`Empire Earth.exe`, `EE-AOC.exe`, Miles Sound System, Bink and the other files of the game folders) | Installed as the game | The original game; the players must own it |
| `dxwebsetup.exe` | Run only with the task that installs the legacy DirectX End-User Runtime | Microsoft's DirectX End-User Runtime web installer |
