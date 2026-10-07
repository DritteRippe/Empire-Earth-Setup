# Third-party components shipped by the setups

The setup scripts are licensed under the GNU GPL v3 (README, "License"). The setups install third-party files that keep
their own terms; this file lists those whose terms restrict how they may be shipped. (The other content and its authors
are named in the header of `setup_is6.iss`.)

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
