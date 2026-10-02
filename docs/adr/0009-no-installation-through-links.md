# 0009. No elevated installation through links in the folders all users can write to

- Status: Accepted (implemented by S-WP11)
- Date: 2026-10-02
- Requirements: D1 ("never weaken trust decisions"), R17; [ADR 0002](0002-stay-on-inno-setup-6.2.2.md)
  security assessment

## Context

In `admin` mode the setup gives authenticated users write access to `<game>\Data` and
`<game>\Users` of both games (`[Dirs]` with `Permissions: authusers-modify`, unless the task
`everyoneadminstart` is selected), because the game runs unelevated and writes there (saved games,
scenarios, civilizations, configuration). An update or repair then runs elevated and writes into
these folders: textures, sounds, movies and campaigns below `Data`, civilizations below
`Users\default`, the verified online files, and `[InstallDelete]` removes fixed names there.

A standard user can replace a subfolder there by a junction or a symbolic link (for example
`Data\Movies` -> `C:\Windows\...`). The elevated setup follows it like any program that opens a
path: the writes land outside the installation. Inno Setup 6.7.0 added RedirectionGuard against
exactly this, but only for Windows 10 22H2 and 11, and v2 stays on 6.2.2 (ADR 0002). The
over-the-shoulder elevation that [ADR 0004](0004-install-record-and-integrity-manifest.md) treats as
a normal case means that the standard user operates the elevated wizard.

What limits the impact today: the setup only writes files with fixed names and its own content
there (no program file), and Inno Setup's `DelTree` does not descend into a reparse point
(`InstFunc.pas` 6.2.2). `randommaps.iss` already refuses to delete through reparse points. The risk
existed since 1.0.

## Decision

1. **Check before installing.** In `admin` mode, `PrepareToInstall` looks for reparse points
   (`FILE_ATTRIBUTE_REPARSE_POINT` of `FindFirst`, the existing `IsReparsePoint` of
   `randommaps.iss` moves to a shared place) in the folders the setup made writable and then
   writes into, for each selected game folder that already exists:
   - `<game>\Data` and every folder below it;
   - `<game>\Users`, `<game>\Users\default` and every folder below `Users\default`.
   Other folders below `Users` (one per player profile) are not written by the setup and are not
   checked, so a player who moved his own profile folder with a link is not blocked. `{app}` and
   the game folders themselves are chosen by the administrator and are not checked.
2. **Stop with a clear message.** If one is found, `PrepareToInstall` returns a localized message
   (English, German, French): which folder is a link, that the setup runs with administrator rights
   and does not write through links in folders every user can change, and what to do (remove or
   replace the link by a normal folder, or install in "only for me" mode). The wizard shows it on the
   "Preparing to install" page, nothing has been changed yet; in silent mode the setup ends with
   exit code 7 and the log names the folder. A question would not help: with over-the-shoulder
   elevation the person who answers it is the standard user.
3. **Pure helper with unit tests** in `utils.iss`: which relative folder below a game folder is
   checked (`IsLinkGuardedFolder`, e.g. `Data\Textures` yes, `Users\default\Civilizations` yes,
   `Users\Bob` no, `Users\defaultX` no, case-insensitive, separators normalized). The walk itself
   only gathers attributes.
4. Not in `user` and `portable` mode (no elevation, the account writes into its own folders). In
   `admin` mode it runs regardless of the task `everyoneadminstart`: the write access granted by an
   earlier run stays on the folders. Under Wine the check runs too and finds nothing unless links
   exist.
5. **Residual risk, documented:** a link created between the check and the writes (a race) is
   not caught; the complete fix is RedirectionGuard of a newer Inno Setup (ADR 0002, "Revisit
   when"). ARCHITECTURE section 9 and the README say so.

## Evidence

- `setup_is6.iss` `[Dirs]`: `Data` and `Users` of both games with `Permissions: authusers-modify`
  (`Check: not IsWine and IsAdminInstallMode`, `Tasks: not everyoneadminstart`); `[Files]` entries
  with `DestDir` below `Data` (HD textures and music, movies, campaigns) and below
  `Users\default\Civilizations`; `[InstallDelete]` names below `Data` (e.g.
  `Data\Scenarios\ScenDefault.scn`, `Data\Movies\`).
- Vendor history 6.7.0 ("blocks traversal of NTFS junctions and symbolic links created by
  unprivileged users ... protection against path redirection attacks that could lead to privilege
  escalation"), `evidence/is6-whatsnew.txt`.
- `InstFunc.pas` 6.2.2, `DelTree`: `IsDirectoryAndNotReparsePointRedir` before descending.
- Inno Setup documentation of `PrepareToInstall`: a non-empty result stops the installation before
  anything is changed and is shown on the "Preparing to install" page; silent runs end with exit
  code 7.

## Consequences

- An update or repair in `admin` mode refuses to run while such a link exists; the message says how
  to continue. Players who linked `Data` subfolders on purpose (e.g. movies on another drive) have
  to undo it before the update.
- A walk over `Data` (about 2000 files in about 100 folders) costs well under a second; it is logged
  (number of folders, duration).
- The real-data comparison of S-WP11 shows only compiled code and the new message.
- Test plan (virtual machine only): as a standard user replace `Data\Movies` by a junction to a
  scratch folder (`mklink /J`), then run the update as administrator: the message appears, the
  scratch folder stays empty; a link in `Users\<player>` does not block.

## Alternatives considered

- **Switch to Inno Setup 6.7 for RedirectionGuard:** the complete fix on current Windows, but the
  cost of ADR 0002 (background, architecture identifiers, full re-verification) and no protection
  on Windows 7 to 10 21H2.
- **No write access for other users:** the unelevated game needs to write into `Data` and `Users`;
  the opt-in `everyoneadminstart` is the existing way to avoid it.
- **Ask instead of stopping:** with over-the-shoulder elevation the standard user would answer.
- **Only log it:** leaves the gap open.
- **Check every folder below `Users`:** would block players who moved their own profile folder,
  for no protection, because the setup does not write there.
