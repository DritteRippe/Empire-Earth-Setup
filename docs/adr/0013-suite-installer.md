# 0013. A suite installer that runs the unchanged EE and NeoEE setups and installs the launcher

- Status: Accepted (decided by the maintainers on 2026-10-05; not implemented yet, the evidence of
  WP0 is pending, see [Evidence](#evidence))
- Date: 2026-10-05
- Requirements: briefing D1 (Inno Setup 6.2.2, every behaviour change intended), D4 (Windows 7 SP1
  to 11), D5 (shared contract), D6 (CD-key registration untouched, no game data in the repository),
  the maintainers' decisions of 2026-10-05 (both games selectable and preselected, the launcher
  installed with them, unsigned, shortcut names "Empire Earth" and "Neo Empire Earth");
  [docs/CONTRACT.md](../CONTRACT.md) revision 4

## Context

Players get two setups (EE and NeoEE, about 604 MB and 645 MB) and, separately, the Empire Earth
Launcher. The first laptop tests showed that this is too much for a layperson: two downloads, two
wizards, a launcher that has to be found and started by hand. The maintainers want one package,
"Empire Earth Community", that installs both games (selectable, both preselected) and the launcher
in one run, and that a layperson can download from GitHub (files below 100 MB), unpack and start.

Three designs were worked out and judged twice (technical review and a walk-through as a
layperson, `judgements.json` of the v1 design workflow):

- **suite** (winner, 37 and 39 points): a new, small Inno Setup script `suite/suite.iss` that embeds
  both product setups byte for byte, runs them silently and installs the launcher next to them.
- **component** (31 and 34 points): a starter program that joins the parts of the package and runs
  the product setups, each of which installs its own copy of the launcher (`#if BundleLauncher`).
- **merged** (29 and 32 points): one setup with a runtime edition that installs EE, NeoEE or both
  from one shared data set.

Facts the decision relies on, from the code at 332d877:

- The product setups hold only the game mutexes in `AppMutex` (`setup_is6.iss:332`), allow
  `/NOICONS` (`AllowNoIcons=yes`, 344), restore folder, components and tasks of the previous run
  (`UsePreviousAppDir=yes`, 413), and their first type is `full` (481); `neoee_cdkeys` has no
  `unchecked` flag (501-504), so a silent NeoEE run registers the CD keys as before.
- `ConfirmLegalCopy` returns early when the setup runs silently (`setup_is6.iss:1423-1435`); the
  NeoEE setup logs `CD Keys generation result: <n>` (1690).
- The product setups create the shortcuts `{group}\<AppName>`, `{group}\<AppName> - AoC`,
  `{group}\<AppName> Diagnostic`, and with the task `desktopicon` `{autodesktop}\<AppName>` and
  `{autodesktop}\<AppName> - AoC` (`setup_is6.iss:1027-1036`; `{group}` is `Empire Earth`, `AppName`
  `Empire Earth` or `NeoEE`).
- The launcher holds the mutex `EmpireEarthCommunityLauncher`, reserved for exactly this
  (`SingleInstance.cs` of the launcher, contract O10).
- Inno Setup processes `[Files]`, `[Icons]` and `[Registry]` during the installation step, after
  `CurStepChanged(ssInstall)` and before `ssPostInstall` (help topic "Pascal Scripting: Event
  Functions" of 6.2.2; the product setups already do work before `[Files]` at `ssInstall`,
  `setup_is6.iss:1934-1946`).

## Decision

1. **A wrapper, not a merge.** The suite "Empire Earth Community" (`suite/suite.iss`, Inno Setup
   6.2.2, UTF-8 with BOM and CRLF) embeds the two product setups unchanged, byte for byte, with their
   official AppIds, and checks their SHA-256 and size against values fixed at build time before it
   runs them. Nothing in `setup_is6.iss` and its include files changes for the suite; the public EE
   and NeoEE builds stay what they are.
2. **Disk spanning instead of a join script.** The package is `Empire Earth Community Setup.exe`
   plus `Empire Earth Community Setup-N.bin` slices of at most 50,000,000 bytes (`DiskSpanning=yes`),
   about 1.26 GB. Setup reads the slices from its own folder and checks them itself; the user needs
   no PowerShell and sees one SmartScreen prompt. Before anything is extracted the suite checks that
   all slices are there and that it was not started from inside the ZIP view, so Inno Setup's disk
   prompt never appears.
3. **One elevated run, one Apps entry for the package.** `PrivilegesRequired=admin`, 64-bit install
   mode like the products, `MinVersion=6.1sp1` (the same Windows range as the products and the
   launcher, D4). The product setups keep their own entries in Windows "Apps", visible, so a single
   game can still be removed or repaired on its own.
4. **The launcher outside the product roots.** The suite installs the launcher and the Mod Creator
   into the suite root (`{autopf}\Empire Earth Community`). They are in no integrity manifest
   (contract 2.3 unchanged), the suite's `AppMutex` holds the game mutexes and
   `EmpireEarthCommunityLauncher`, its `SetupMutex` is `EmpireEarthCommunity_Suite` (contract 0
   "Suite and launcher", 4.2). This answers contract O10.
5. **The products run at `ssInstall`.** The suite runs the product setups in
   `CurStepChanged(ssInstall)`, EE before NeoEE, waits for each, and keeps the results, so that the
   `Check` functions of its own `[Icons]` and `[Registry]` entries, which Inno Setup evaluates after
   `ssInstall`, see whether each product succeeded. A product succeeded if its setup ended with exit
   code 0 and its uninstall key exists in HKLM64 with an `UninstallString`.
   **Fallback**, if the WP0 spike shows that the `Check` functions are evaluated earlier: the suite
   creates its shortcuts with `CreateShellLink` and writes the suite record with `RegWrite...` at
   `ssPostInstall`, with the same names and values; contract 1.7 point 1 already allows this.
6. **Silent products, legal texts in the suite.** Default parameters `/SILENT /SUPPRESSMSGBOXES
   /NORESTART /ALLUSERS /LANG=<suite language> /NOICONS /MERGETASKS="!desktopicon" /LOG=...`,
   `/TYPE=full` only on a first installation; a repair passes neither `/TYPE` nor `/DIR`. Because a
   silent product setup skips its legal question, the suite shows `LegalQuestion`, the EULA and the
   NeoEE rules itself. The NeoEE setup alone registers the CD keys (`authtools.dll`, D6); the suite
   only reads its log line `CD Keys generation result: <n>` and shows the result, and never touches
   `Software\Sierra\CDKeys`. The log line becomes an interface (contract 1.7 point 5).
7. **Legacy-shortcut cleanup before the suite shortcuts.** The suite's game shortcuts are
   `Empire Earth` and `Neo Empire Earth` on the desktop and in the start menu folder `Empire Earth
   Community`; they start the launcher with `--product=EE` or `--product=NeoEE` (without .NET
   Framework 4.8: the game program of the product). After a product setup succeeded, still at
   `ssInstall` and therefore before the suite's `[Icons]`, the suite deletes the shortcuts of earlier
   standalone runs of that product, exactly the paths of contract 1.7 point 7, and then the start
   menu folder `Empire Earth` if it is empty. Every run of the suite creates its shortcuts again, so a
   repair restores them. The rule "no suite shortcut name equals a product shortcut name" of the
   design is replaced by "the suite shortcuts are created after the legacy cleanup and are recreated
   by a suite repair" (the shortcut names are the maintainers' decision).
8. **HKCU-only guard.** If a product is installed only for one user (a previous installation with
   `/CURRENTUSER`: uninstall key in HKCU, none in HKLM64), the suite does not run its setup, says
   that it has to be removed through Windows "Apps" first, and does not list it in the suite record.
   Two installations of the same AppId in two hives are not worth any elevation tricks; the case is
   rare.
9. **Contract revision 4.** The suite's names, the optional suite record (1.6), how the suite runs a
   product setup (1.7, informative), the launcher argument `--product` (1.4), the suite mutex as a
   setup mutex (4.2) and the repair advice with `SourceDir` (4.4) are optional additions under
   contract section 5; 4.1 and 4.3 do not change. `ci/check_contract.py` reads `suite/suite.iss`
   (`SetupMutex`, `AppMutex`, the record's value names and types, the game shortcuts) as soon as it
   exists.

## Evidence

Pending WP0 spike (ci/spike, branch spike/suite). The spike has to show on a GitHub-hosted Windows
runner, without game data and without network access of the tested setups:

- the `Check` functions of `[Icons]` and `[Registry]` are evaluated after `CurStepChanged(ssInstall)`,
  so they see the results of the product setups (otherwise point 5's fallback applies);
- `Exec(..., ewWaitUntilTerminated)` on a product setup and on a product uninstaller
  (`unins000.exe` relaunches itself from `%TEMP%`) returns only when the work is done, or the
  polling of the uninstall key that the suite uninstaller uses instead is reliable;
- a disk-spanned suite reads its slices, `ExtractTemporaryFile` works from a slice, and the
  precheck for missing slices runs before Inno Setup's disk prompt;
- `AppMutex` with `EmpireEarthCommunityLauncher` stops the suite (also `/VERYSILENT`) while a
  launcher runs.

The results, with the run ids, go here before the status becomes "Accepted, implemented".

## Consequences

- The package is about 1.26 GB: the shared game data (about 713 MB) is in both product setups. That
  is the accepted price for product setups that stay byte-identical. Peak use of drive C: is about
  4.8 GB if the ZIP is kept; the suite checks the free space first.
- Windows "Apps" shows three entries: the suite and the two products. Uninstalling the suite
  removes the products it lists (each through its own uninstaller), the launcher and the shortcuts;
  game saves stay unless the user asks otherwise.
- Uninstalling EE alone through Windows "Apps" can delete the suite's desktop shortcut
  `Empire Earth` if EE was once installed standalone with a desktop shortcut (the uninstall log of EE
  still names `{autodesktop}\Empire Earth.lnk`); running the suite again restores it. Contract 1.7
  point 8 says so; the README of the package (WP10) has to say it too.
- The folder the package was unpacked to is the repair source: the launcher may point to it
  (`SourceDir`, contract 4.4); the official download stays the second option.
- Inno Setup's own log of the suite plus one log per product run in `{app}\Logs` give a complete
  trace for support.
- A change of the NeoEE log line `CD Keys generation result:` or of the product shortcut paths needs
  the same change in contract 1.7 and in the suite.

## Alternatives considered

- **component** (a starter joins the parts and runs the product setups; each product installs its
  own launcher copy): rejected. Installing both games needs two UAC prompts, because the starter
  runs without elevation and each product setup elevates itself, and in advanced mode two wizards
  open; whether a self-elevated child returns its exit code is unverified and cannot be tested on an
  elevated CI runner. Two launcher copies share one `settings.json` and one mutex and need new IPC
  and an own-root preference, and they can drift apart after an official repair. Its change of the
  default selection of contract 1.4 is a new meaning, incompatible by contract section 5. It changes
  the product script (`#if BundleLauncher` in `[Files]`, `[Icons]`, `[Run]`, `AppMutex`, install
  state and uninstall), so the real-data product builds are no longer the official ones. In silent
  mode the CD-key result is never shown. Its good ideas are kept: repairs without `/TYPE` and `/DIR`,
  and shortcuts to the game programs without .NET Framework 4.8.
- **merged** (one setup with a runtime edition, shared data stored once): rejected. It refactors the
  proven product script that the public builds use: about 85 compile-time references in 7 files
  become runtime functions, `AppId`, `AppName`, `AppVersion` and `AppPublisher` become `{code:}`,
  so every official build changes its behaviour paths (D1), and `ci/check_contract.py` needs a
  rework; about 25 days with the highest regression risk. Several core mechanics are allowed by the
  documentation but unproven: an `AppId` from `{code:}` answered by a form in `InitializeSetup`, a
  `SetupMutex` from `{param:}`, two processes reading the same disk-spanning slices, and extraction
  from slices at runtime. With both games, the second pass runs silently as a child, so its failures
  show up only after the first pass; its chained uninstaller is not awaited; removing one product
  asks to remove the other one too, with "Yes" as the default. It would halve the download (about
  0.7 GB); its idea to demand an explicit `neoee_cdkeys` decision in silent runs is kept.
- **Hide the product entries in Windows "Apps"** (`SystemComponent=1`): rejected. A single game
  could no longer be removed or repaired on its own, and the product setups would have to change.
- **A join script** (`copy /b` or PowerShell) instead of disk spanning: rejected. One more step for
  a layperson, PowerShell execution policies, and the joined file would carry the mark of the web.
- **Run the products at `ssPostInstall`** (the first draft): rejected, `[Icons]` and `[Registry]`
  are processed before it, so their `Check` functions could not depend on the results.
- **Shortcut names that differ from the product shortcuts** ("Empire Earth spielen", "Play Empire
  Earth", the first architecture): they would avoid the collision of point 7 with the old EE desktop
  shortcut, but the maintainers chose the plain game names; the cleanup and the repair cover the
  collision.
- **`MinVersion=10.0`** (the first draft): rejected, it would drop Windows 7 SP1 and 8.1, which the
  products and the launcher support (D4).
