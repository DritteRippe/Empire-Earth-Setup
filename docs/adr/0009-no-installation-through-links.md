# 0009. No elevated installation through links in the folders all users can write to

- Status: Accepted, implemented by S-WP11 (see [Implementation](#implementation))
- Date: 2026-10-02
- Requirements: D1 ("never weaken trust decisions"), R17; [ADR 0002](0002-stay-on-inno-setup-6.2.2.md)
  security assessment
- Revised: 2026-10-02, implementation of S-WP11: every folder below `Users` is checked, not only
  `Users\default` (the external `[Files]` entries that set the permissions of `*.cfg`, `*.config`,
  `*.conf` and `*.ini` copy such files in every folder that is not hidden onto themselves and give
  every user modify rights on them, and Inno Setup 6.2.2 follows links when it recurses there, see
  Context); both game folders that exist are checked, also when AoC is not selected
  (`[InstallDelete]` has no component for the AoC folder); a folder that cannot be listed counts as
  a finding; a file with a reparse point does not; the message names at most three folders

## Context

In `admin` mode the setup gives authenticated users write access to `<game>\Data` and
`<game>\Users` of both games (`[Dirs]` with `Permissions: authusers-modify`, unless the task
`everyoneadminstart` is selected), because the game runs unelevated and writes there (saved games,
scenarios, civilizations, configuration, one profile folder per player below `Users`). An update or
repair then runs elevated and writes into these folders: textures, sounds, movies and campaigns
below `Data`, civilizations below `Users\default`, the verified online files, and
`[InstallDelete]` removes fixed names there.

A standard user can replace a subfolder there by a junction or a symbolic link (for example
`Data\Movies` -> `C:\Windows\...`), or turn the emptied `Data` folder itself into one. The elevated
setup follows it like any program that opens a path: the writes land outside the installation.
Inno Setup 6.7.0 added RedirectionGuard against exactly this, but only for Windows 10 22H2 and 11,
and v2 stays on 6.2.2 (ADR 0002). The over-the-shoulder elevation that
[ADR 0004](0004-install-record-and-integrity-manifest.md) treats as a normal case means that the
standard user operates the elevated wizard.

What limits the impact: most of what the setup writes there are files with fixed names and its own
content (no program file), Inno Setup replaces a file by writing a new one and renaming it (it does
not write through a link to a file), and its `DelTree` does not descend into a reparse point
(`InstFunc.pas` 6.2.2). `randommaps.iss` already refuses to delete through reparse points. What
does not limit it (found during S-WP11): the external `[Files]` entries `{app}\<game>\*.cfg`,
`*.config`, `*.conf` and `*.ini` with `recursesubdirs` and `Permissions: authusers-modify` copy every
such file in every folder below the game folders that is not hidden onto itself and give every user
modify rights on the copy. Inno Setup 6.2.2 enters links when it recurses for them
(`Install.pas` `RecurseExternalCopyFiles` uses `Main.pas` `IsRecurseableDirectory`, which checks
only the directory and hidden attributes). A junction in the profile folder of a player could so
make the elevated setup give every user write access to the configuration files of another folder,
e.g. the `.config` file of a .NET service. The risk existed since 1.0.

## Decision

1. **Check before installing.** In `admin` mode, `PrepareToInstall` looks for reparse points
   (`FILE_ATTRIBUTE_REPARSE_POINT` of `FindFirst`; `IsReparsePoint` of `randommaps.iss` moves to
   `utils.iss`, the shared place) in the folders the setup made writable and then writes into, for
   **both game folders that exist**, selected or not (the `[InstallDelete]` entries of the AoC folder
   run in every installation):
   - `<game>\Data` and every folder below it;
   - `<game>\Users` and every folder below it, the profile folders of the players included (the
     external permission entries above write there).
   A folder with a reparse point (junction, symbolic link to a folder, mount point) is a finding and
   is not entered, so the walk never leaves the game folder. A folder that exists but cannot be
   listed is a finding too: what is in it cannot be checked. Hidden folders are checked as well.
   Files with a reparse point are counted in the log but are no finding: Windows compression (WOF)
   and deduplication mark files the same way, and the setup replaces a file instead of writing
   through it. `{app}` and the game folders themselves are chosen by the administrator and are not
   checked; nor are their other folders (`redist`, `Manual`, ...), which standard users cannot write.
2. **Stop with a clear message.** If one is found, `PrepareToInstall` returns a localized message
   (`LinkInGameFolder`, English, German, French): that nothing has been changed, why (the setup runs
   with administrator rights, every user can change `Data` and `Users`, a link could make it change
   files outside the game folder), which folders (at most three, then `... (+n)`, because the
   "Preparing to install" page has no scroll bar; the log has all of them) and what to do (remove the
   link or replace it by a normal folder and run the setup again, or install for the own account
   with "Install for me only"). The wizard shows it on the "Preparing to install" page, nothing has
   been changed yet; "Back" stays possible, so the check runs again after the link is gone. In
   silent mode the setup ends with exit code 7 and the log names the folder. A question would not
   help: with over-the-shoulder elevation the person who answers it is the standard user. An
   exception during the check stops the setup as well (the folders were not checked).
3. **Pure helper with unit tests** in `utils.iss`: which relative folder below a game folder is
   checked (`IsLinkGuardedFolder`: `Data\Textures` yes, `Users\default\Civilizations` yes,
   `Users\Bob` yes, `Users\defaultX` yes, `Data2`, `redist\win32`, `Mods\NeoEE\Data`, the game folder
   itself and paths with `..` or a drive no; case-insensitive, separators normalized). The walk
   (`FindLinksInGameFolder`) only gathers attributes and is tested on a folder tree in `{tmp}`, on
   Windows also with junctions.
4. Not in `user` and `portable` mode (the setup does not elevate itself there, the account writes
   into its own folders). In `admin` mode it runs regardless of the task `everyoneadminstart`: the
   write access granted by an earlier run stays on the folders. Under Wine the check runs too and
   finds nothing unless links exist.
5. **Residual risks, documented** (ARCHITECTURE section 9, README "Security"):
   - a link created between the check and the writes (a race) is not caught;
   - the uninstaller is not covered: it deletes the files the installation recorded, also through a
     link created after the installation;
   - a link to a file is not a finding (creating one needs the symbolic link privilege:
     administrators, or Developer Mode on Windows 10 and 11); the setup replaces such a file, an
     external permission entry reads the file it points to;
   - a user or portable setup that someone runs as administrator in a folder other users can write
     to, and an installation folder that the administrator chose in a place where all users can
     write (e.g. a new folder directly below `C:\`), are not covered.
   The complete fix is RedirectionGuard of a newer Inno Setup (ADR 0002, "Revisit when").

## Evidence

- `setup_is6.iss` `[Dirs]`: `Data` and `Users` of both games with `Permissions: authusers-modify`
  (`Check: not IsWine and IsAdminInstallMode`, `Tasks: not everyoneadminstart`); `[Files]` entries
  with `DestDir` below `Data` (HD textures and music, movies, campaigns) and below
  `Users\default\Civilizations`; the external entries `{app}\<game>\*.cfg`, `*.config`, `*.conf`,
  `*.ini` with `recursesubdirs` and `Permissions: authusers-modify` (the same in 1.7.2);
  `[InstallDelete]` names below `Data` (e.g. `Data\Scenarios\ScenDefault.scn`, `Data\Movies\`),
  for the AoC folder without `Components`.
- Inno Setup 6.2.2 source: `Install.pas` `RecurseExternalCopyFiles` recurses into every directory
  for which `Main.pas` `IsRecurseableDirectory` is true (directory, not hidden, not `.`/`..`; no
  reparse point check); `InstFunc.pas` `DelTree`: `IsDirectoryAndNotReparsePointRedir` before
  descending; `Main.pas`: exit code 7 `ecPrepareToInstallFailed`.
- Vendor history 6.7.0 ("blocks traversal of NTFS junctions and symbolic links created by
  unprivileged users ... protection against path redirection attacks that could lead to privilege
  escalation"), `evidence/is6-whatsnew.txt`.
- Inno Setup documentation of `PrepareToInstall`: a non-empty result stops the installation before
  anything is changed and is shown on the "Preparing to install" page; silent runs end with exit
  code 7.

## Consequences

- An update or repair in `admin` mode refuses to run while such a link exists; the message says how
  to continue. Players who linked `Data` subfolders (e.g. movies on another drive) or their profile
  folder below `Users` on purpose have to undo it before the update, or install for their own
  account.
- A walk over `Data` and `Users` (about 30 folders per game with the official data) costs a few
  milliseconds; it is logged (number of folders, duration, findings).
- The real-data comparison of S-WP11 shows only compiled code and the new message.
- Test plan (virtual machine only, TP-80): as a standard user replace `Data\Movies` by a junction to
  a scratch folder (`mklink /J`), then run the update as administrator: the message appears, the
  scratch folder stays empty, the installation runs after the link is removed; silent: exit code 7;
  a link in the profile folder of a player stops it as well.

## Implementation

S-WP11, 2026-10-02: the helpers with their unit tests (`4a82871`), the check in `PrepareToInstall`
with the message (`cb3859e`), a unit test of a junction whose target is gone (`5b840a9`), then the
test case TP-80 and this documentation.

- **Point 1:** `utils.iss`: `IsReparsePoint` (moved unchanged from `randommaps.iss`, which uses it as
  before), `IsLinkGuardedFolder`, `FindLinksInGameFolder` (file level, like `CollectExternalFiles`)
  and `LinkFindingsShownMax` (3). `environment.iss`: `CheckGameFoldersForLinks` walks
  `{app}\Empire Earth` and `{app}\Empire Earth - The Art of Conquest` (a missing folder gives
  nothing). `setup_is6.iss`: `PrepareToInstall` calls it if `IsAdminInstallMode`, else it logs `Link
  check skipped: not the administrative install mode`. It runs after `NextButtonClick(wpReady)` (the
  downloads go to `{tmp}` only) and before `ssInstall`.
- **Point 2:** `LinkInGameFolder` in English, German and French (112 custom messages); the folder
  list is `FormatFindingList` of ADR 0007. Log: one line per finding (`Link check: <folder> is a
  junction or symbolic link (reparse point)` or `... cannot be listed, so the folders in it cannot
  be checked`), then `Link check: <n> folders below Data and Users of <app> examined in <ms> ms,
  <k> links or unreadable folders found, <f> files with a reparse point (allowed)` and `The
  installation stops before anything is changed (message LinkInGameFolder on the Preparing to
  install page; silent installation: exit code 7)`; Inno Setup adds `PrepareToInstall failed: ...`.
- **Tests:** 39 unit tests: the scope cases of point 3 and their negatives, `IsReparsePoint` of a
  folder, a file and a missing path, the walk over a tree in `{tmp}` (12 folders, none found, a
  missing AoC folder); on Windows only, with junctions from `cmd /c mklink /J`: `Data\Movies` and
  `Users\Bob\Profile` found, `redist\Junction` not, none entered, the target unchanged, then a
  junction whose target was deleted found as well. Wine cannot make junctions (`mklink` and
  `CreateSymbolicLinkW` report success and create nothing), so this part is a `SKIP` line there (582
  tests, 1 skipped); a one-off run under Wine with Unix symbolic links made from outside passed
  everything except what Wine does differently (it cannot remove such a link with `RemoveDir` and
  does not list a link whose target is missing). Test plan block 8: TP-80.
- **Wine probe** (analysis only, not in the repository): a probe setup with `utils.iss`,
  `extension.iss`, `environment.iss` and the five messages unchanged and `PrepareToInstall` copied
  from `setup_is6.iss`, links as Unix symbolic links (Wine reports them with
  `FILE_ATTRIBUTE_REPARSE_POINT`), no network. `/VERYSILENT /SUPPRESSMSGBOXES`: no game folder (0
  folders) and a tree without links (10 folders, a few ms) install; a link at `Data\Movies`,
  `Users\Bob`, `Data` itself, the AoC `Data\Movies` (AoC not a component of the probe) and seven
  links below `Users\default\Civilizations` end with exit code 7, nothing installed, the scratch
  folder empty; a link in `redist` does not block; `/CURRENTUSER` logs `Link check skipped` and
  installs through the link (the limit of point 4). `/SILENT` without `/SUPPRESSMSGBOXES` shows the
  message in a message box over the Preparing page, then exit code 7. Wizard in German, English and
  French with seven findings and with one, also with long paths below `C:\Program Files (x86)`: the
  message fits on the page (with three long AoC paths in German and French Inno Setup's own last
  line "Setup cannot continue ..." is cut off, the message itself is complete); "Back" is enabled,
  "Next" is not; German: Back, links replaced by normal folders, Install: the check finds nothing
  and the installation succeeds; English and French: Cancel ends without a question, exit code 7.
  Wine does not report a link to a file or a link whose target is missing (on Windows the walk sees
  a junction whose target is missing, see the unit test).
- **Real-data comparison** (local only, nothing committed): EE and NeoEE built from the reconstructed
  1.7.2 data at `5b840a9` against the S-WP8 builds at `1e1e8ee`: only the compiled code (EE 170389 ->
  175277 bytes, NeoEE 175116 -> 180004 bytes) and the 3 new messages (`LinkInGameFolder` in
  English, German, French) differ; `[Files]`, `[Dirs]`, `[Registry]`, `[Run]`, `[InstallDelete]`,
  every other section, the wizard images and the data are identical.
- **Open:** the behaviour on real Windows (TP-80: over-the-shoulder elevation, the page layout with
  Windows fonts, the duration with real data).

## Alternatives considered

- **Switch to Inno Setup 6.7 for RedirectionGuard:** the complete fix on current Windows, but the
  cost of ADR 0002 (background, architecture identifiers, full re-verification) and no protection
  on Windows 7 to 10 21H2.
- **No write access for other users:** the unelevated game needs to write into `Data` and `Users`;
  the opt-in `everyoneadminstart` is the existing way to avoid it.
- **Ask instead of stopping:** with over-the-shoulder elevation the standard user would answer.
- **Only log it:** leaves the gap open.
- **Check only `Users` and `Users\default`, not the other folders below `Users`** (the plan before
  S-WP11, so that a player who moved his own profile folder with a link is not blocked): rejected
  during the implementation, because the external permission entries write into the profile
  folders too and follow links there.
- **Stop at `ssInstall` instead of `PrepareToInstall`:** the setup cannot stop cleanly there.
- **Report files with a reparse point as well:** would block players whose game folder Windows
  compressed (WOF), for little gain: the setup does not write through a link to a file.
