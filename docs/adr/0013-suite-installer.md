# 0013. A suite installer that runs the unchanged EE and NeoEE setups and installs the launcher

- Status: Accepted (decided by the maintainers on 2026-10-05; being implemented, the evidence of
  the WP0 spike is in [Evidence](#evidence))
- Date: 2026-10-05
- Requirements: briefing D1 (Inno Setup 6.2.2, every behaviour change intended), D4 (Windows 7 SP1
  to 11), D5 (shared contract), D6 (CD-key registration untouched, no game data in the repository),
  the maintainers' decisions of 2026-10-05 (both games selectable and preselected, the launcher
  installed with them, unsigned, shortcut names "Empire Earth" and "Neo Empire Earth");
  [docs/CONTRACT.md](../CONTRACT.md) revision 4 (revision 5: see the amendment of 2026-10-06; revision 6 and `/VERYSILENT` for the product setups: see the amendment "The product setups run with /VERYSILENT")

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
6. **Silent products, legal texts in the suite.** Default parameters `/VERYSILENT /SUPPRESSMSGBOXES
   /NORESTART /ALLUSERS /LANG=<suite language> /NOICONS /MERGETASKS="!desktopicon" /LOG=...`,
   `/TYPE=full` only on a first installation; a repair passes neither `/TYPE` nor `/DIR`. (Suite 1.0.0
   passed `/SILENT`; since revision 6 it is `/VERYSILENT`, see the amendment at the end.) Because a
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
10. **Details of the product runner.** Both embedded setups are checked in `PrepareToInstall` (one
    extraction at a time, deleted again; mismatch: exit code 15, nothing installed) and once more right
    before each `Exec` (a mismatch then stops the remaining products). The parameter builder is pure and
    tested; it merges a `/MERGETASKS` of the CI pass-through into its own, because Inno Setup does not
    say which of two switches wins, and a lost `!neoee_cdkeys` would let a test register the CD keys.
    The default mode passes `/VERYSILENT` to the product setups, also in a run of the suite that is
    not silent (contract 1.7 point 3; suite 1.0.0 passed `/SILENT`, see the amendment at the end). A
    failed product (exit code 1 to 8, or exit code 0 without the uninstall entry) is logged, shown
    (not in a silent run) and skipped; the suite itself ends with the exit code 0 then, so an
    unattended caller reads the log, the uninstall keys or the suite record. The runner starts nothing
    but the embedded setups and deletes only its extracted setup, the log of the product setup it
    starts and the legacy shortcut files; `ci/check_suite.py` enforces that.
11. **The uninstaller removes what the suite created, and only that.** `InitializeUninstall` stops
    while a game or the launcher runs or another suite setup holds `EmpireEarthCommunity_Suite` (the
    uninstaller holds it itself, contract 4.2) and asks one question that lists what goes. At
    `usUninstall` it runs the uninstaller of each product that the suite record lists and that still has its
    uninstall key, NeoEE before EE, each only if it is an `unins*.exe` inside the product's install root.
    Because the first process of an Inno Setup uninstaller only starts a copy of itself (Evidence), it
    polls the uninstall key and the program file with a 10 minute timeout instead of trusting the exit
    code; a product that is gone already is skipped silently, a failure is reported (not in a silent
    run) with the way through Windows "Apps", and the rest goes on. At `usPostUninstall` it removes the
    shortcuts and the record (they are not in the uninstall log), the launcher's `settings.json` and
    `log.txt` of the account that uninstalls, and, only after the answer "Delete" (second button of one
    task dialog, "Keep" is the default, never asked and never done in a silent run), the exact folders
    `Users` and `Data\Saved Games` below the root of each removed game, and `Backups` and `Mod Creator`
    of the launcher's data folder. The folders that are empty then are removed from the inside out; a
    root with anything else in it stays. `{app}\Logs` is a folder of the suite and goes with
    `[UninstallDelete]`. The suite never writes or deletes below `Software\Sierra`; the product
    uninstallers keep their own cleanup. `ci/check_suite.py` enforces the places where `DelTree` and the
    registry deletion may appear. Limitation: with over-the-shoulder elevation the account that
    uninstalls is the administrator who confirmed it, so the launcher files below `%LOCALAPPDATA%` of the
    standard user stay (README, test plan).

## Evidence

The WP0 spike: CI run 37321940954 (job 111802943735, artifact `spike-suite-results`), branch
`spike/suite` at dc6877d, GitHub-hosted `windows-latest` (Windows Server 2025), Inno Setup 6.2.2. It
ran throwaway placeholder setups, without game data and without network access; its scripts are
`ci/spike/` of that branch (not on `v2`). The results bind the implementation:

| Question | Result | Decision |
|---|---|---|
| The `Check` functions of `[Icons]` and `[Registry]` see what `CurStepChanged(ssInstall)` set | Not proven: the driver summary says FAIL ("entries missing or evaluated too early"), while the probe lines of the log show `step_seen=1 global_set_in_ssInstall=1` for both sections | Decision 5's **fallback** applies: the suite creates its shortcuts (`CreateShellLink`) and writes the suite record (`RegWrite...`) in code at `CurStepChanged(ssPostInstall)`, with the same names and values. Its uninstaller removes them explicitly, they are not in the uninstall log. The product setups still run at `ssInstall`. `ci/check_contract.py` reads the record and the shortcuts from that code. |
| `Exec(unins000.exe, ewWaitUntilTerminated)` returns when the uninstallation is done | **No**: it returns before the real uninstall has finished (`unins000.exe` starts a copy from `%TEMP%` and ends) | After `Exec`, the suite uninstaller polls until the uninstall key `{<AppId>}_is1` of the product is gone (HKLM64) and `unins000.exe` no longer exists, with one timeout of 10 minutes for both and a clear message when it expires (Inno Setup removes the key early and the program file only after all game files, so a short grace period for the file would let the next uninstaller start while the first still deletes); the exit code alone decides nothing. |
| `DiskSliceSize=262144` | Refused by ISCC: "not enough space on the first disk", the first slice must hold `setup.exe` | `DiskSliceSize` is at least the size of the suite's `setup.exe`; the real build uses 50,000,000, a placeholder build the smallest size that works (the spike used 1,800,000 with a filler). The build script checks it. |
| `ExtractTemporaryFile` of a `dontcopy` file that spans slices | Works (size and SHA-256 equal) | As planned: the product setups are `dontcopy nocompression` files. |
| A missing middle or last slice, `/VERYSILENT /SUPPRESSMSGBOXES` | **Hangs**: "Asking user for new disk containing ..." even in a silent run | `InitializeSetup` verifies, before anything is extracted, that every slice is in the folder of the setup, none is empty or larger than `DiskSliceSize`, and **all together have exactly the recorded total size** (count and total are build-time defines of a two-pass build). The single sizes cannot be recorded: slice 1 is `DiskSliceSize` minus the size of `setup.exe`, and the digits of a list of sizes change `setup.exe`, so such a build alternated between two states and never became stable (observed under Wine); the total does not depend on `setup.exe`. The build script runs a third pass and requires the same count, total and bytes as the second; the first pass is named `... PASS1 DO NOT SHIP` (it has no check). A mismatch ends with a message (`SuppressibleMsgBox`, none in a silent run) and a documented exit code (11, or 12 if the setup was started from the ZIP view or a temporary folder). CI runs the suite under an external timeout. |
| A damaged slice (wrong content, right size) | Clean exit code 3 after 315 ms ("The source file is corrupted") | In the suite the extraction of a product setup is a `try` block: a damaged slice there is exit code 15 with the log text `could not be extracted or read` (and its own message), not 3; the check of the extracted setup against its pin stays in place, and the file is locked against writing from before the hash until the product setup has ended. A damaged slice in the area of the launcher files, the Mod Creator or the license texts is Inno Setup's own failure (exit code 3 or another code of Inno Setup, not one of 10 to 15). CI scenario and test plan expect 15 for a damaged slice in a product setup. |
| A product setup `/SILENT` while its `AppMutex` is held | Exit code 1 after about 0.4 s, nothing installed (without the mutex: 0) | The suite maps child exit code 1 to "a game is running", and still checks the mutexes itself before it starts a product. |
| The suite's wizard while `Exec(ewWaitUntilTerminated)` runs a `/SILENT` child | Stays responsive: 67 of 73 timer ticks, the longest gap 110 ms | `WizardForm.StatusLabel` updates work, no polling loop with its own message pump is needed. |
| A product failing while the suite goes on | Child A exit code 1 (held mutex), the suite continues, child B exit code 0 | After a failed product the suite continues with the next one and reports each result. |

The spike did not run the suite's own `AppMutex` (the launcher mutex) against a started launcher: the
suite checks the game and launcher mutexes itself in `InitializeSetup` (exit code 14) and does not rely
on the `AppMutex` check for that; the CI scenario with a helper process that holds each mutex (test
strategy, S6) covers it. The spike's `[Registry]` and `[Icons]` evidence is ambiguous, so the
fallback of decision 5 is the implemented behaviour; the alternative "Run the products at
`ssPostInstall`" below stays rejected, since only the shortcuts and the record moved to `ssPostInstall`.

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

## Amendment: the uninstall key of the suite (2026-10-06, laptop test TP-93)

**Finding.** The uninstall key of the suite has `AppPublisher` `Empire Earth Community`, which is
exactly the contract publisher of EE ([contract 0, Products](../CONTRACT.md)). The launcher's source 3
(contract 1.4) matches by publisher, so it took the suite key (root = the suite folder) for an EE
installation without install record and `install.ini`: a phantom `community-legacy` installation in
the state damaged. The EE game settings were then shared by two installations (ambiguous), so the
launcher did not write the defaults at the start. The CI did not see it, because the suite scenarios
use a stub launcher.

**Decision.** Contract revision 5. The suite marks its own key: `MarkSuiteUninstallKey`
(`suite/suite_record.iss`) writes the REG_DWORD `Empire Earth Community: Suite` = 1 into
`{<suite AppId>}_is1` at `ssPostInstall` of every run, after the suite record, and only if the key
exists (no stub key; a missing key is logged). Every run writes it again because Inno Setup deletes
and rewrites the key, as the products do for `Empire Earth Community: ContractVersion`. The uninstaller
removes the whole key, so the value needs no removal code. The launcher skips a marked key, whatever the
type and data of the value. A fallback covers a suite built before revision 5, which has no marker: a
key in HKLM whose root is the `InstallPath` of the suite record and whose AppId is neither `EEAppId` nor
`NeoEEAppId` of the record is skipped too. `ci/check_contract.py` and `ci/check_suite.py` check the
marker, the suite scenarios assert it, and the laptop test TP-93 (Windows 11) looks at it.

**Rejected: another `AppPublisher` for the suite.** It would remove the cause, but:

- `IsForeignUninstallEntry` ([ADR 0007](0007-environment-warnings.md)) leaves the
  suite key out of the "foreign or old installation" report only because of the community publisher.
  The `DisplayName` of the suite, "Empire Earth Community (Launcher, EE, NeoEE)", names Empire Earth, so
  the EE and NeoEE setups, including the silent ones the suite runs, would log the suite key, and an
  interactive standalone product setup would show it as a foreign installation.
- Windows "Apps" should keep showing the community publisher for the suite.
- Suites that are already installed keep the old publisher until they are installed again, so the
  launcher would need a fallback anyway.

**Consequences.**

- A suite built before revision 5 whose record was deleted or cannot be read still shows up as an
  installation. Running the suite again (a repair) adds the marker. The `DisplayName` could close this
  gap, but the contract stays free of display strings.
- A product key in the suite folder with an AppId the record does not embed (a test build) is no
  candidate of source 3 any more; contract 0 already says the suite root is no install root of a product.
- The launcher reads the suite record in every discovery, still read-only and still no source.

## Amendment: the product setups run with /VERYSILENT (2026-10-06, suite 1.1.0)

**Finding.** In the laptop test of suite 1.0.0 every product setup showed a window of its own next to the
window of the suite: its installation progress window and a taskbar button, one game after the other. That
is what Inno Setup does under `/SILENT` (`Main.pas` shows the wizard form once the installation starts, the
background window and the pages stay hidden); under `/VERYSILENT` it shows nothing. The suite passed
`/SILENT` (decisions 6 and 10), the test plan described the extra window as expected (TP-93).

**Decision.** In the default mode the suite starts the product setups with `/VERYSILENT /SUPPRESSMSGBOXES
/NORESTART /ALLUSERS /LANG=<suite language> /NOICONS /MERGETASKS="!desktopicon" /LOG=...` (contract 1.7
point 3, revision 6). Nothing else changes: the runner still uses one `Exec(ewWaitUntilTerminated)`, the
lock order, the exit code mapping and the checks of `ci/check_suite.py` stay as they are. The advanced mode
passes no silent switch, so the user still sees the full wizard of the product. The suite's own window shows
the status line and the marquee bar as before.

**Why this is safe.** The product scripts treat both modes alike: `SilentInstall` is true for `/VERYSILENT`
and for `WizardSilent` (`extension.iss`), every message box of the scripts is guarded by it or by
`SuppressibleMsgBox`, and `/SUPPRESSMSGBOXES` stays on the command line. `/NORESTART` still prevents any
restart (the only mode-specific restart behavior of Inno Setup, `imVerySilent`, is reached without it).
Under `/VERYSILENT` the setup downloads and verifies the same files; its pages and download page are not
shown, as they were not shown under `/SILENT` before the installation started.

**Consequences.**

- A hidden product setup has no window and therefore no Cancel button of its own: the user can no longer
  stop a product by closing its progress window, and a hang looks like a frozen suite window. Until the
  runner of the next work package (a process handle, Cancel only before the product started to install
  files, a stall and a total time limit) is in, the suite behaves as before in one respect: Cancel of the
  suite is only honored after the products ran. This is accepted for suite 1.1.0 because both defects
  belong to the same release.
- A message box that no script suppresses would be invisible. None is expected (see above), and
  `/SUPPRESSMSGBOXES` is passed; the CI scenarios run `/VERYSILENT` products already, and TP-93 has to be
  repeated on the laptop.
- Contract 1.7 point 3 changes in both repositories (revision 6, compatible, `ContractVersion` stays 1).
  `ci/tests/suite_tests.iss` expects `/VERYSILENT` and no `/SILENT` token; `ci/e2e/e2e_suite_helpers.ps1`
  requires `/VERYSILENT` in the arguments of the product setups and rejects `/SILENT`.
