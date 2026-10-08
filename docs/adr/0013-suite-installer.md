# 0013. A suite installer that runs the unchanged EE and NeoEE setups and installs the launcher

- Status: Accepted (decided by the maintainers on 2026-10-05; being implemented, the evidence of
  the WP0 spike is in [Evidence](#evidence))
- Date: 2026-10-05
- Requirements: briefing D1 (Inno Setup 6.2.2, every behaviour change intended), D4 (Windows 7 SP1
  to 11), D5 (shared contract), D6 (CD-key registration untouched, no game data in the repository),
  the maintainers' decisions of 2026-10-05 (both games selectable and preselected, the launcher
  installed with them, unsigned, shortcut names "Empire Earth" and "Neo Empire Earth"; since suite 1.1.0 one shortcut, see the amendment "One shortcut Empire Earth Community");
  [docs/CONTRACT.md](../CONTRACT.md) revision 4 (revision 5: see the amendment of 2026-10-06; revision 6 and `/VERYSILENT` for the product setups: see the amendment "The product setups run with /VERYSILENT"; the product logs as the data source of the progress display: see the amendment "The log lines of the product setups are an interface"; Cancel and time limits of the runner: see the amendment "The product setups run as processes with a handle"; the display of the progress in the suite window: see the amendment "The suite window shows what the product setup does")

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
    `Users`, `Data\Saved Games` and `Data\dxm\mods` below the root of each removed game (the last holds
    the mods players made; the product setups delete only the presets they install there, `[UninstallDelete]`),
    and `Backups` and `Mod Creator` of the launcher's data folder. The folders that are empty then
    (`Data\dxm`, `Data`, the game folders, the root) are removed from the inside out; a
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
- Up to suite 1.0.0, uninstalling EE alone through Windows "Apps" could delete the suite's desktop shortcut
  `Empire Earth` if EE was once installed standalone with a desktop shortcut (the uninstall log of EE
  still names `{autodesktop}\Empire Earth.lnk`). Since suite 1.1.0 the suite's shortcut is `Empire Earth Community`,
  a name no product setup uses, so this no longer applies (amendment "One shortcut Empire Earth Community").
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

## Amendment: the log lines of the product setups are an interface (2026-10-06, suite 1.1.0)

**Context.** A hidden product setup (previous amendment) shows nothing, and the suite window only showed a
marquee bar. The suite 1.1.0 progress display (status line, bar, file being downloaded, list of finished
steps) needs a data source. The product setup has no API, but it writes a log line by line, unbuffered, in
UTF-8 with a byte order mark, every line with a 26 character time stamp (`yyyy-mm-dd hh:nn:ss.zzz` and three
blanks, continuation lines 26 blanks). The logs of the laptop test of 2026-10-06 (EE 299 s, NeoEE 326 s) show
clean markers: the online files servers, `Downloading <N> online files`, one `Online file downloaded` per
file, `<X> of <Y> bytes done.` about every 10 percent, `All <n> online files accepted`, `Starting the
installation process.` (about 70 percent of the run), 2260 (EE) or 2697 (NeoEE) lines `Dest filename:`,
`Installation process succeeded.`, the CD key step of NeoEE, the manifest and `Log closed.`. The download is
the longest phase (65 to 72 percent), the installation 15 to 21 percent.

**Decision.**

1. The suite reads the log of the running product setup (`SuiteTailLog`, `suite/suite_common.iss`),
   read-only, and a pure parser (`SuiteFeedLogLine`) maps the lines to a phase that only moves forward and to
   counters; `SuiteProgressPermille` weights the blocks (prepare 3, download 65, verify 2, install 20, the
   rest 10 percent; the download weight drops out for a run that downloads nothing). The install block is an
   estimate (entries `Dest filename:` against a constant per product, at most 99 percent of the block), and
   nothing is 100 percent before `Log closed.`.
2. **Success is never decided from the log.** The exit code and the uninstall entry stay authoritative
   (`SuiteRunSucceeded`, contract 1.7 point 5); the log only feeds the display. A reworded or missing line
   makes the display coarser, it cannot make a product succeed or fail.
3. The lines the parser reads are an interface between the product scripts and the suite, like the line
   `CD Keys generation result: <n>` before: contract 1.7 point 5 lists them (contract revision 6, both
   copies), the product scripts mark each of them with the comment "suite parses this line", and
   `ci/check_suite.py` fails if a line is no longer written, if a mark stands above another line, or if
   `suite_common.iss` reads a line the check does not know. A product script change that rewords such a
   line changes the suite and the contract in the same commit.
4. The parser reads the CD key lines only as text (`Register NeoEE CD Keys`, `CD Keys generation result:`).
   The suite still never calls `authtools.dll`, never touches `Software\Sierra\CDKeys`, and the product
   scripts' CD key code is not changed (only a comment was added above the log lines).

**Evidence.** The reader has to open the file while the product setup holds it open for writing and allows
only reading (`Logging.pas`: write access, share mode read): `LoadStringFromFile` opens with share mode read
only and fails with a sharing violation, so `SuiteTailLog` opens a `TFileStream` with `fmShareDenyNone` at
every look, takes only what was appended since the last look (at most 256 KiB per call) and carries an
unfinished last line over to the next call; a file that is missing (the product setup creates it when it
starts) or smaller than what was read (a new log) is handled. The unit test of the reader holds a file open
with the product's share mode (write access, share read) and checks all of this, including that
`LoadStringFromFile` fails on it. It also showed that `TStream.Read` does not fill an `AnsiString` buffer
(it returned the right byte count and other bytes): the reader calls `ReadFile` on `TFileStream.Handle`, the
same pattern `WriteFile` has in `utils.iss`. The unit tests of the parser use short excerpts typed from the two
logs of the laptop test (neutral paths) and check the monotonic phases, the counters, the English-only run,
the clamp, the byte order mark, a line split across two reads and continuation lines.

**Consequences.**

- The text of about twenty lines of `downloads.iss`, `setup_is6.iss`, `installstate.iss` and `utils.iss` is
  now an interface; rewording one needs the contract and `suite_common.iss` in the same commit. The marker
  comments say so where the lines are.
- At the time of this amendment nothing in the suite window used the reader yet; the product runner with a process
  handle and the progress display followed (the next two amendments). Until the windows-latest run of the end-to-end scenarios, the
  `ReadFile` path is verified by the unit test under Wine only.
- The progress is an estimate: the files of the download weigh the same although their sizes differ widely
  (their sizes are not in the log before they start), and the install block depends on a constant per
  product that components and repair runs change.

## Amendment: the product setups run as processes with a handle, Cancel and time limits (2026-10-06, suite 1.1.0)

**Context.** `Exec(ewWaitUntilTerminated)` gives neither a process handle nor a hook. Two defects followed: a click
on Cancel in the suite window was only honored after both games had been installed (`Main.pas`: at `ssInstall`
Cancel sets a flag that `Install.pas` reads after `CurStepChanged(ssInstall)` has returned), and a product
setup that hangs (since the previous amendment without a window of its own) looks like a frozen suite.

**Decision.** The maintainers decided on 2026-10-06: Cancel works only while the product setup that runs has not
started to install files; a first product that is finished stays installed; afterwards Cancel is disabled.

1. **Start and wait.** `SuiteStartProduct` (`suite/suite_common.iss`) starts the product setup with `CreateProcessW`
   like `Exec` does (`InstExec`: the quoted program and its parameters, `SW_SHOWNORMAL`, the thread handle closed
   at once) and keeps the process handle. `SuiteWaitForProduct` (`suite/suite_run.iss`) waits in slices of
   50 ms and handles the messages of Setup in between (`PeekMessageW`, `DispatchMessageW`; a `WM_QUIT` is put
   back for Setup and ends the wait), reads the product log every 500 ms (`SuiteTailLog`) and writes one line
   `Product EE phase: <phase> (<n> of 1000)` to the log of the suite per phase change. The exit code comes from
   `GetExitCodeProcess` after the process ended; 259 (`STILL_ACTIVE`) is no result. The mapping of exit codes
   (`SuiteChildExitKind`), the success rule (exit code 0 and the uninstall entry), the lock on the extracted file
   (kept until the wait has returned) and the order of the legacy shortcut cleanup are unchanged. `Exec` and
   `ShellExec` are not used by the runner any more (`ci/check_suite.py`, part [Process]).
2. **A job object, without limits.** The setup program of a product is only a loader: it extracts the real setup
   to a `.tmp` file in `%TEMP%`, starts it and waits for it (two processes, seen under Wine). Stopping the loader
   alone would leave the real setup running, and it would install the game after the user had cancelled. So the
   process is started suspended, put into a job object and resumed; `SuiteKillProduct` ends the whole job with
   `TerminateJobObject`, the only way a program is stopped (the three places that may call it are fixed by
   `ci/check_suite.py`). The design said "no job object" so that a dying suite does not kill the product setups
   (half installed games); that stays true, because no limit is set: closing the job handle or the end of the
   suite stops nothing. Where a job cannot be used (Windows 7, the suite itself inside another job) the product
   setup runs as it did with `Exec`, nothing is stopped, the Cancel button is off with a reason and the time cap
   only writes a line.
3. **Cancel.** `CancelButtonClick` answers while a product setup runs (Setup's own handling stays when none runs):
   before the log shows the install step (the first version of this amendment took `Starting the installation
   process.`, see the amendment of the review below) it asks (default "No", the question names the game
   and, in the second step, the game that is installed already and stays); "Yes" only sets a request. The wait loop
   looks at the log once more, because the product setup went on while the question was open: if it has started to
   install by then the request is refused with a message, otherwise the job is stopped, the run starts no further
   product, writes `Product EE was cancelled by the user before it installed anything` and ends with `Abort`.
   `Abort` in the installation step ends Setup with exit code 3 and no message of its own (checked under Wine:
   "CurStepChanged raised an exception (fatal)"); the suite writes its files, record and shortcuts after this
   step, so nothing of it exists. From the point of no return, in the advanced mode (the product setup shows its
   own wizard with its own Cancel button) and without a job the button is off and the line below the bar says
   why.
4. **Time limits.** No new line in the product log for 10 minutes: the user is asked once whether to keep
   waiting ("No" stops the product setup; the text warns that a game that started to install may be half
   installed); a silent run only logs it and keeps waiting. 90 minutes: the product setup is stopped. A stopped
   product setup is a new failure kind (`SuiteChildTimeout`, the reason text says whether it had started to
   install), and the suite goes on with the next product like after any failure. The advanced mode has neither
   limit, because the user goes through the wizard at his own pace.
5. **CI hook.** A `/VERYSILENT` run has nobody to click Cancel, so `/TestCancel` (a CI parameter like `/EEArgs`)
   requests the cancel for the first product setup as soon as its real setup has opened its log. Scenario S11
   uses it with the placeholder products and expects exit code 3, no product, no record, no shortcut and no
   process left.

**Evidence.** Under Wine (placeholder suite, copied prefix, no network): the loader and the real setup are two
processes, the job ends both at once, the exit code of a cancelled run is 3, a real click on Cancel in a `/SILENT`
run opens the question, "Yes" stops the product setups and leaves no game file, "No" lets the run finish, a
product that finished before is named in the question of the second step, the Cancel button is off with its
reason once the product setup is in the install phase (checked with a forced phase), and a cap of a few seconds
stops a product setup and goes on with the next. The unit tests start real programs: an exit code, 259, a missing
program, and a second copy of the test setup itself (a loader with a real setup) that the job must stop together
with its child. They run under Wine and in the workflow on Windows; scenario S11 runs only in the workflow.

**Consequences.**

- A stopped product setup leaves its own `%TEMP%\is-*.tmp` folder with what it had downloaded (hundreds of MB
  in a real run). The suite does not know the name of that folder, and deleting folders by pattern is not worth
  the risk; the test plan says so (TP-99).
- After a cancel in the first step the suite folder holds the log of the product setup it stopped and nothing
  else (the suite creates `{app}\Logs` before the first product runs).
- The message pump is hand-made: Pascal Script has no `ProcessMessages`. Messages are dispatched, but the
  keyboard handling of the Delphi forms (Tab between controls) is not part of it; the mouse and Space or Enter on
  the focused button work.
- 90 minutes can stop a download over a very slow connection that would have finished; the next run starts again.
  The numbers are constants of `suite_common.iss` (`SuiteStallMs`, `SuiteProductCapMs`).
- The consequence of the previous amendment that Cancel is only honored after the products ran is gone.
- The message pump, the job and the click on Cancel are verified under Wine and by the unit tests; the first run
  on Windows is the workflow (unit tests and S11), then TP-99 on the laptop.

## Amendment: the suite window shows what the product setup does (2026-10-07, suite 1.1.0)

**Context.** With the product setups hidden (`/VERYSILENT`) the suite window was the only window, but it showed a
marquee bar and one line, "installing <game> ...", for five minutes or more. The maintainers asked for
transparency and decided on 2026-10-06 that the window shows a status line, a bar and the current file, plus a list of the
finished steps and a summary at the end. The log reader and the parser of the previous amendments are the data source,
the runner with a process handle the place to show it from.

**Decision.**

1. **One look, one display.** Every look at the product log (the wait loop looks every 500 ms, and once more when the
   process has ended) ends in `SuiteShowProgress` (`suite/suite_run.iss`). It sets a control only when its text or
   position changed, so nothing flickers.
2. **Status line, file line, bar.** The status line of Setup names the step and the game and what the log says it
   does: it looks for the online files, downloads language file n of N, checks them, installs the game files,
   registers the CD keys (NeoEE), finishes (`SuiteStatusKind` maps the phase to one of seven texts; the first
   line before the log has said anything is the old "installing <game> ..."). The line under it (the file name label of Setup)
   names the online file with the part that has arrived, "name - 16.4 of 163.7 MB" (one decimal from 1 MB,
   else KB; a decimal comma in German and French, "Mo" in French), or the game file being written. The bar of the
   installation page is a real bar now (1000 steps) for the whole run: a product is a share of 1000 divided by the
   number of products, filled by `SuiteProgressPermille` (the weighting of the previous amendment). While a
   product setup runs the bar stays at 990 per mille of its share at most (`SuiteRunningPermille`): the log ends
   before the process does and ends the same way when the product setup failed, so only the exit code lets the bar
   reach the end of the share (`SuiteEndProductDisplay`, called after the product runner returned). The bar never
   goes back because the phases and the counters only move forward. Setup's own values (style, maximum, position) are put back
   after the products.
3. **Cancel line.** The line that says why Cancel is off (previous amendment) moved from the file line to a line
   of its own below the bar, because the file line now has a use of its own.
4. **List of the finished steps.** A `TNewCheckListBox` on the installation page lists per product a heading with the
   game and the steps that are done, ticked, in the order of the log: language files downloaded n of N (or "No
   language files needed"), game files installed, CD keys registered (NeoEE; with its result number and not ticked if
   the registration failed), the list of the installed files written, finished; a failed product ends with "Not
   installed (the log tells why)". A step is added when its result is known (`SuiteStageReached`), each once. The
   list only shows: a click puts a box back.
5. **Summary.** The last page names per installed product how many language files arrived of how many there are
   and, if some are missing, that the game uses the files of the setup for them and how to get the others (until
   now this was in the product log only). A product setup that was not read to its end (the advanced mode) gets no line.
6. **The advanced mode** shows the wizard of each product, reads no log and keeps the running bar and the status
   line "the setup of <game> is open"; the list holds the names of the games and the result.
7. **The display never decides.** Success is still the exit code and the uninstall entry. If the display raises an
   exception it writes one line to the log of the suite and stays as it is (`SuiteProgressBroken`); the installation
   goes on. The suite log gets `Product EE phase: download, 17 files (… of 1000)` at each phase change and, after
   the product setup ended, one line `Product EE log read: …` with the counters, to compare the estimate with
   the real number of entries (`ci/e2e/e2e_suite_scenarios.ps1` expects, for the placeholder products, the phase lines that were logged in the order of the log and the end `done`; a placeholder setup is so fast that a look may skip the phases in between).

**Evidence.** The pure parts (status kind, file index, sizes with the rounding and the decimal separator by language,
the bar of the whole run, the counts of the online files, the stages) are unit tests on both the English
and the other languages and run under Wine and in the workflow. `ci/check_suite_texts.py` checks that every message of
the suite has its English, German and French text with the same placeholders. `ci/check_suite.py` (part
[Display]) fixes the rules of this amendment (no 100 percent while a product runs, the end of the share only in
`SuiteEndProductDisplay`, the try/except, the bar put back, the list that only shows). The layout of the page and
the behaviour of `TNewCheckListBox` are verified by the compile only: TP-98 on the laptop.

**Consequences.**

- The status line depends on the wording of the product log (the interface of the previous amendment): a reworded line
  gives a coarser display (the text of an earlier phase stays), never a wrong success.
- The install share of the bar is an estimate from a constant per product (`SuiteInstallEstimate*`); components and
  repair runs change the real count. The suite log line `log read` shows both numbers for the next adjustment. The
  constants could be passed from the build later.
- The files of the download weigh the same in the bar although their sizes differ widely; the file line shows the
  real bytes of the current file.
- The window is only as fresh as the log: the reader looks every 500 ms and a product setup writes the progress of
  a download about every 10 percent of a file, so the counter of bytes moves in jumps.

## Amendment: review of the runner (2026-10-07, suite 1.1.0)

**Context.** An adversarial review of the runner, the progress display and the Cancel handling (branch `v2` at
b352efe) found one blocker and several defects. This amendment records the decisions of the fixes, one point each,
numbered like the findings of the review (findings 6, 8, 11, 12 and 13 need no decision of their own and are in
the CHANGELOG); the points are added with the commit that fixes them.

1. **The point of no return is a line of the product script, not Inno Setup's.** The suite took `Starting the
   installation process.` as the moment from which Cancel is off. The procedure `CurStepChanged(ssInstall)` of
   `setup_is6.iss` runs before that line (`Main.pas` calls it before `Install.pas` logs the line) and already
   changes the game folder: `DeleteInstallState` deletes `install.ini` and `files.sha256`, `VerifyDownloadedFiles`
   hashes and moves the downloads (seconds for 170 MB) and `PrepareRandomMapScripts` deletes the shipped maps and,
   on an installation of setup 1.7.2, moves the whole folder `Random Map Scripts` aside. A kill in that window
   (`TerminateJobObject`) skips `DeinitializeSetup` and `RestoreRandomMapScripts` and leaves a game without install
   state, which the launcher shows as Unknown or Damaged, and possibly without its random maps. That breaks the
   rule that Cancel works only while nothing is installed (decision of 2026-10-06). The fix: the product script
   logs `Install step: the game folder is changed from here on` as the first statement of that step, before
   `DeleteInstallState`, marked "suite parses this line" like the other interface lines; the suite parses it as
   `SuitePhaseInstall` (`SuiteLogInstallPhase`) and keeps Inno Setup's line only as the fallback for a product
   setup that logs none; `ci/check_suite.py` checks the text, the mark and that it is the first statement of
   the step (`check_install_marker`, three mutants), and the unit tests feed the order of a real log. The log is
   read again after every "Yes" (the existing re-read), so a click that arrives after the line is refused with the
   "not now" message. A small window remains and is accepted: the last read of the log can come just before the product
   setup writes the line, the product then goes straight on to `DeleteInstallState`, and `TerminateJobObject` lands after
   that. The window is milliseconds long (it was seconds with Inno Setup's line); it was not closed here because that
   would need the processes of the job to be suspended before the last read (`NtSuspendProcess` or a thread walk), then
   killed or resumed, for a click that must hit that interval. A "Yes" that loses the race leaves a game without install
   state, which the launcher shows as Unknown and the next run of the suite repairs. **Closed by the amendment "the
   race of Cancel is closed" below (run 5f), which does what this paragraph called too much effort: it suspends the job
   before the last read.** The bar and the stage list lose the short phase "checking
   the language files": the checking is part of the install step now, which is what it is for the game folder (the
   status line says "installing the game files" for those seconds).
2. **The cap never kills an installation.** The cap of 90 minutes (decision 4 of the amendment of the runner) stopped the
   job even when the product setup had started to change its game folder, silently in a `/VERYSILENT` run, and the
   downloads count toward it: at about 0.3 Mbit/s the 171 MB take 76 minutes, so the install step could be cut at the
   cap and leave a half installed game, which is what the Cancel rule and the decision "no kill on close" avoid.
   `SuiteTimeoutCheck` now gets `Installing`: before the install step the cap stops the product setup (after one more
   look at the log, because the line it stands at may be 500 ms old), during it the cap only logs once
   (`SuiteTimeoutCapInstalling`). Only the user stops an installing product setup, through the stall question, whose
   text says that the game may be half installed. The cap is not measured from the start of the install step: a
   download that is slow but alive for more than 90 minutes is still stopped, and the next run starts again.
3. **The stall question is looked at again after the answer.** The question is modal inside the wait loop and "No" used
   to stop the job at once, without looking at the process or the log. `SuiteStallStopWanted` checks after "No": a
   product setup that ended while the box was open is not stopped (its exit code is taken, it was reported as
   `SuiteChildTimeout` before although it had succeeded), and one that logged the install step meanwhile gives the
   question again with the text for an installing setup (the first text said "no game files have been installed yet").
4. **The question of Cancel says what stays.** A killed product setup leaves its `%TEMP%\is-*.tmp` folder with what it
   had downloaded (up to about 170 MB), and a repair or an update leaves the game as it was, so "nothing of it stays
   on this computer" was wrong twice. The suite does not delete the folder: its name is only in a line of the product
   log (`Created temporary directory:`), deleting a folder by a name read from a log is the kind of deletion the runner
   avoids (`ci/check_suite.py` allows no `DelTree` there), and Windows removes it with the temporary files. The four
   texts of `SuiteCancelQuestionText` (first installation or already installed, with or without a product that this run
   finished) name the folder and what stays.
5. **Cancelling the second product finishes the suite part.** `Abort` after a cancel of the second product left the first
   one installed without shortcut (`SuiteRemoveLegacyShortcuts` had deleted the old ones, `/NOICONS`), launcher and record.
   Now `Abort` (exit code 3, nothing written) only follows a cancel with no product succeeded in the run
   (`SuiteProductsOk = ''`); otherwise the run goes on to `ssPostInstall` and writes the launcher, the shortcuts and the
   record for the products that succeeded. The cancelled product counts like a failed one, but the last page says
   "cancelled by you" (`SuiteResultCancelled`). The question of the second step says so.
6. **The file line works with both transports.** The file name and the bytes came only from the WinHTTP transport (`Downloading
   pinned online file ...`, `<X> of <Y> bytes done.`). Inno Setup's download page logs only `Downloading temporary file
   from <URL>: <target>` and no progress, so with a valid certificate the line stayed empty and a large file could trigger
   the stall question during a healthy download. The suite parses Inno Setup's line as well (`SuiteLogTempFile`, listed with
   the other Inno lines in `ci/check_suite.py`), and the progress callback of the download page logs the same
   `<X> of <Y> bytes done.` line at every 10 percent (`IsProgressLogDue`, shared with the WinHTTP loop and unit-tested).
   The stall question stays as it is for the download phase: at 10 percent a line comes at least every few minutes unless
   the line is slower than about 0.25 Mbit/s for the largest file, and then the question is asked once and "keep waiting"
   is the default.
7. **The line for Cancel wraps.** `SuiteCancelLabel` was one line high without `WordWrap`, so the German and the French texts
   were cut off at 100 percent display scaling (the WinForms and Wine runs cannot show that). It wraps now and takes the
   height its text needs at the width and font of the window (`AdjustHeight`, at least one line, none without a text; a
   fixed room for three lines was clipped again by a longer translation or a bigger font), and the list of the steps
   starts below its real height (`SuiteLayoutProgressControls`, called when the text changes). TP-98 and TP-99 check it at
   100 and 150 percent with German and French.
8. **Release criteria of suite 1.1.0.** The riskiest new code (the hand-made `CreateProcessW`, job object and `PeekMessage`
   runner, the record layouts and the `SizeOf` of them, the hand-placed controls) had run only as unit tests and under Wine,
   and TP-98 and TP-99 were P2 although the design requires TP-98 before tagging. The suite 1.1.0 is tagged only after TP-93,
   TP-94 (c), TP-95, TP-97, TP-98 and TP-99 pass (TP-99 with its repair and second-game variants, TP-98 with the display
   scaling check) and the job `suite-e2e` was green on windows-latest for the commit, with S8 and S9 (the shortcuts of
   suite 1.0.0 deleted by a repair and by the uninstaller) and S11, S12 and S13, the scenarios that cancel
   (`docs/TEST-PLAN.de.md`, Block 9, "Freigabekriterium der Suite 1.1.0"). TP-94 (c) and TP-97 are the update path that
   the decision for 1.1.0 requires ("an update or repair of the suite removes the two old icons"): the CI scenarios plant
   the seven shortcuts of suite 1.0.0, they do not come from an update of that suite. Their priority stays P2 like TP-93 and TP-95: the
   short run of section 7 belongs to the product setups and stays at 170 minutes.
9. **`/TestCancel` and the scenarios.** The CI parameter requests the cancel only if the log that was just read is still before
   the install step; otherwise it writes `/TestCancel not requested` and the scenario fails on that line, which is better
   than a cancel that came too late and passed or failed for another reason. A product setup that reaches its install step
   before its log is first read cannot be cancelled at all, so the check does not make S11 deterministic by itself, but
   the failure now names its cause. The switch stays in
   shipped builds: it only cancels, it is of the same kind as `/EEArgs`, and a build without it would not be the one
   the scenarios test. `/TestCancelNeoEE` cancels the second product (scenario S12), and S13 cancels a repair during its downloads.
   `/TestCancel` fires as soon as the real setup has opened its log, long before `CurStepChanged(ssInstall)`, so S13
   does not prove the boundary of point 1 (it would pass with Inno Setup's old line as the marker); the unit tests of the log
   parsing, `check_install_marker` and TP-99 (e) do, and the choice of the text of the cancel question
   (`SuiteCancelQuestionMessage`) and the "cancelled" line of the last page (`SuiteCancelledResult`) are unit-tested in
   `suite_common.iss`. A placeholder hook that sleeps in `CurStepChanged(ssInstall)` with a `/TestCancelAtInstall` switch
   would test the boundary in CI; it was not built here and is built by the amendment "the race of Cancel is closed"
   (scenario S14). `/TestCancel` cancels the first product setup that runs (EE, in a
   run without EE NeoEE).
10. **Keyboard and `WM_QUIT`.** The hand-made message pump bypasses the key handling of the forms: Esc (Cancel) and Tab do not
   work while a product setup runs, mouse and the focused button do. TP-99 and the README say so. `SuiteWaitEnd` leaves
   its wait when `SuitePumpMessages` reports a `WM_QUIT` (it spun for up to 5 seconds), unit-tested with a real program.

## Amendment: one shortcut "Empire Earth Community" (2026-10-07, suite 1.1.0)

The maintainers decided on one launcher for the four games (launcher 1.1.0, contract 1.4 revision 6). The suite
therefore creates one shortcut, `Empire Earth Community`, on the desktop and in its start menu folder; it starts the
launcher without an argument, which opens with the game chosen last. The start menu folder keeps the Mod Creator and
the uninstaller; the game shortcuts `Empire Earth` and `Neo Empire Earth` (with `--product=`), `Empire Earth Launcher`
and the Diagnostic shortcuts of suite 1.0.0 are no longer created. Every run of the suite and its uninstaller delete
them (`SuiteOldSuiteShortcutPath`, contract 1.7 point 8); `{autodesktop}\Empire Earth.lnk` only if it starts the
launcher, because the EE setup's own desktop shortcut has that name. Decision 7's note that uninstalling EE alone can
delete the suite's shortcut no longer applies: the names differ now. Without .NET Framework 4.8 the one shortcut starts
the game program of NeoEE, else EE (the product the launcher would select first); the select page says how to get the
launcher. The launcher keeps `--product=` for shortcuts that players made or that a failed update left.

Two consequences are accepted. `{autodesktop}\Neo Empire Earth.lnk` is deleted whatever it starts: a shortcut of that
name that a player made on the desktop of all users, pointing to the game program, goes too (suite 1.0.0's uninstaller
kept such a shortcut while the game stayed installed). The NeoEE setup's own shortcut is named `NeoEE`, so no setup
shortcut is hit, and a condition "starts the launcher" would keep the shortcut that suite 1.0.0 made without .NET
Framework 4.8 (it starts the game program), so there would be two icons after the update, which the decision rules out.
Separately, a desktop `Empire Earth.lnk` that suite 1.0.0 made without .NET Framework 4.8 survives an update in which EE
is deselected: the EE setup's own cleanup deletes it only when the EE setup runs, and the suite deletes that name only if it
starts the launcher (contract 1.7 point 8).

Evidence: `ci/tests/suite_tests.iss` (`SuiteOldSuiteShortcutPath`, `SuiteOldSuiteShortcutRemovable`,
`SuiteFirstInstalledProduct`), `ci/check_contract.py` and `ci/check_suite.py` with their self-tests, CI scenarios S1,
S3, S8 (`suite-uninstall/OLD-SHORTCUTS`: the uninstaller deletes the seven planted shortcuts) and S9 (`repair/OLD-SHORTCUTS`, then
two repairs of NeoEE alone: `repair-neo/OLD-SHORTCUTS` deletes the desktop `Empire Earth` that starts the launcher by the
suite's own code, because no EE setup runs, `repair-neo-kept/GAME-SHORTCUT` keeps the one that starts a game program),
laptop TP-93, TP-94 (c), TP-97. A Wine run of the placeholder suite (copied
prefix, no network, no .NET Framework 4.8) with the seven shortcuts of suite 1.0.0 planted: the run deleted six of them
and the desktop `Empire Earth` only when its link named the launcher (a log line each, the one that named a game program
stayed), left a foreign `Decoy.lnk`, created `Empire Earth Community` to the game program of the installed product on the
desktop and in the folder (none for the Mod Creator), and the uninstaller removed these and the old ones again.

## Amendment: the race of Cancel is closed (2026-10-07, suite 1.1.0, run 5f)

**Context.** The first CI run of the scenarios on windows-latest (pull request, scenario S12 "cancel while the second
product setup runs") failed on `C:\Program Files (x86)\Neo Empire Earth exists`, the push run of the same commit passed.
The log of the suite shows the sequence: the cancel is requested (`/TestCancelNeoEE`) at 14:00:34.146; the product logs
`Install step: the game folder is changed from here on` at .202, `Install state of the previous run deleted` at .202,
`Starting the installation process.` at .204, `Creating directory: C:\Program Files (x86)\Neo Empire Earth` at .206 and
`Starting 64-bit helper process.` at .208; the suite logs `cancelled by the user before it installed anything, stopping its
setup` at .210 and `Product NeoEE log read: last phase start ... 0 file entries installed`. So "before the install step"
was decided on a read of the log that was older than the line, and the job was terminated after the product had started
to change the game folder. This is the residual window of point 1 of the review amendment, which that amendment called
"milliseconds long" and accepted; a placeholder setup, which has nothing to download and no data to copy, reaches the
install step within a few milliseconds of the first line in its log, and the pull request run hit it. For a repair the same
window deletes `install.ini` and `files.sha256` and moves the folder `Random Map Scripts`. Real setups are slower on their
way to the line, but a human click can hit the window as well, and a game without install state is the damage the rule
"Cancel works only while nothing is installed" exists to prevent.

**Decision.**

1. **Freeze, read, decide.** Whatever stops a product setup before its install step (the "Yes" of the cancel question,
   "stop" of the stall question while the setup does not install, the cap of 90 minutes, `/TestCancel*`) goes through one
   function, `SuiteStopBeforeInstall` (`suite_run.iss`), which first **suspends every process of the job**, then reads the
   log once more from the last offset **to its end**, and only then decides with the pure function `SuiteStopDecision`
   (`suite_common.iss`, unit-tested with the lines read after the freeze, the last line without a line end and the freeze
   result). A frozen process starts no other process and runs no further statement, but the freeze is **not an instant**:
   `NtSuspendProcess` returns before every thread has actually stopped, and a thread finishes the one system call it is in.
   That is enough because of how Inno Setup 6.2.2 writes its log (checked in the source, `Logging.pas` `Log` and
   `FileClass.pas` `TFile.WriteBuffer`): the time stamp, the text and the line end of a line are **separate `WriteFile`
   calls, and there is no buffer** (a line is in the file when its call has returned). The setup has to finish the call that
   writes the text of `Install step: ...`, and then make another call (the line end, then the deletion of the install
   state), before it changes anything. So at most one call completes after the freeze: if the change lies behind the
   freeze, the text was written and the read after the freeze sees it; if the text call is the one still finishing, the
   read sees only the time stamp (or a part of the text), which counts as unclear (point 4), so the cancel is not carried
   out; if the call of the time stamp is the one, the setup never writes the text and changes nothing. The read after the
   kill (point 3) catches anything that is left. The four outcomes: *stop* (no sign of the install step and everything
   frozen, and the stop confirmed, point 7: the job is terminated while frozen; frozen processes can be terminated),
   *too late* (the line is in the log, or any later phase, or the last line without a line end is the start of its text:
   the processes are resumed and the setup runs on; the existing outcome "the cancel came too late, its setup has started
   to install the game files", Cancel applies to the next game as before), *unclear* (point 4 and point 7: resumed and
   running on, but nobody can say that it installs) and *incomplete* (see point 3).
2. **How the freeze is done.** `QueryInformationJobObject(JobObjectBasicProcessIdList)` lists the processes of the job
   (the loader, the real setup, and the 64-bit helper of Inno Setup once it exists); each is opened by its id for
   `PROCESS_SUSPEND_RESUME` and `PROCESS_QUERY_INFORMATION`, **proved to be in the job with `IsProcessInJob`** (an id the job
   named may belong to another program by then; such a process is never touched, the handle of a suspended process is kept
   so that its id cannot be reused until it runs again) and suspended with **`NtSuspendProcess`** of `ntdll`. The job is
   listed again until a pass finds no process that is not frozen yet (a frozen process starts none; a process that was
   started by one not yet frozen shows up in the next pass); 20 passes at most. `NtSuspendProcess` is undocumented but has
   been there since Windows NT and is what every process tool uses; it suspends all threads of a process in one call under
   the lock of its thread list, which a walk over a Toolhelp snapshot with `SuspendThread` per thread (a documented
   alternative) cannot do: a thread that starts between the snapshot and the call is missed, and the walk has to be repeated
   until nothing changes, per thread instead of per process. A process that ended meanwhile is no failure. Windows 7 has
   all four functions.
3. **When the freeze or the read is not certain, nothing is killed.** If a process cannot be opened or suspended, if the
   job cannot be listed (also more than 128 processes), if the job keeps growing or if the log exists but cannot be read
   to its end (`SuiteTailLogToEnd` tells that from "nothing new"), the suite resumes what it froze, logs why and treats the
   cancel as not carried out (*unclear*, point 4): a product setup that could not be frozen is never killed. After a
   termination the log is read one last time (it cannot grow any more, but a line the suite missed, for example one whose
   text call finished after the freeze, shows up now): if the install step is in it, or in its last line, or the log
   cannot be read, the result is *incomplete*:
   the suite does not claim "cancelled before it installed anything", it logs `its log shows the install step ... it may
   be incomplete`, starts no further game, counts the game as failed (the last page lists it as failed, not as
   cancelled) and tells the user, in English, German and French (`SuiteRunCancelledLate`), that the game may be only
   partly installed and must be repaired by running the suite again. The stall question and the cap, which also end a
   product setup, report it with the text they already had (`SuiteReasonTimeoutInstalling`).
4. **A partial last line counts.** A log line that is only partly written (the product was frozen between two writes of one
   line, which the separate calls of `Log` make possible, or the line has no line end yet) counts as the line of the
   install step when its text is the start of `Install step: the game folder is changed from here on` or of Inno Setup's
   `Starting the installation process.`: *too late*. A line of which only the time stamp (or a part of it) is there has no
   text yet and is *unclear*: the suite would rather let a game setup run on than kill one that is about to change the game
   folder, but it cannot say that the game is being installed either. After a termination only a line that is the start of
   the marker counts (nothing can grow any more). A click that arrives while a line is being written is therefore not
   answered with "the game is being installed" (see point 7 for what it gets).
5. **The stall question keeps the user's informed choice.** The text for a setup that installs says the game may be only
   partly installed and the answer "stop" is the user's decision, so `SuiteWaitForProduct` still stops such a setup
   directly (the one remaining direct call of `SuiteStopProduct`); only the answer given to the text "no game files have
   been installed yet" goes through the freeze, because the setup may have started meanwhile.
6. **Deterministic CI coverage of the boundary.** A build with `-Placeholders` (`ci/build.ps1`, only that, through
   `/DPlaceholderInstallPause=1`) makes the placeholder setups pause **2 seconds right after the line `Install step: ...`**
   (before `DeleteInstallState`) and, for the reason below, **2 seconds at the end of `PrepareToInstall`**, before the install
   step; both log `Test hook of a placeholder build: ...`. The switch is not in any release or real-data build: only
   `Get-PlaceholderPauseDefine` builds it, `build.ps1` calls that with `$Placeholders` only, `build.ps1` stops if the
   resolved script of a build without `-Placeholders` holds a hook line (`Find-PlaceholderHook`), a signed build is
   refused by the script itself (`#error`), and `ci/check_suite.py` (part [Hook]) checks that every hook line stands inside
   `#ifdef PlaceholderInstallPause`, that it is never defined in the script and that no other file passes the switch.
   The suite switch `/TestCancelAtInstall` (a CI parameter like `/TestCancel`, which stays in shipped builds because it
   only requests a cancel of the kind a user can click) requests the cancel **as soon as the log of the first product
   setup shows the install step**, from a copy of the progress (`SuiteTestLogShowsInstall`) and with the regular look at
   the log held back while it waits, so the progress of the suite has not seen the line when the cancel is requested: the
   decision has to find the line itself. Scenario **S14** (`/TestCancelAtInstall /TestCancelNeoEE`) expects the outcome
   "too late" for EE (log lines `freezing ...`, `N processes frozen`, `its log shows the install step, its setup is not
   stopped`, `its N processes run again`, `the cancel came too late`), EE complete (folder, `install.ini`, `files.sha256`,
   uninstall key, record, the checks of S2), the pause lines in its product log in the order *before - Install step -
   after - Install state deleted*, exit code 0, and the cancel of NeoEE stopping it before its install step as in S12. The
   phase line `Product EE phase: install` between `N processes frozen` and `its log shows the install step` proves that the
   decision found the line itself: it is written by the read after the freeze, a read before the freeze would put it before
   `freezing`.
   Without the first pause S11, S12 and S13 would flip with the fix: their cancel is requested when the log is first
   read, a placeholder setup reaches the install step within about 50 milliseconds from there, and the decision now
   correctly answers "too late" when it is faster than the suite; the pause before the install step keeps "before" before.
   S11, S12 and S13 now also expect the freeze lines and no line that shows the install step.
7. **The stop is confirmed, the freeze proves the loader, an unclear cancel is tried again** (review of the race fix).
   (a) `SuiteKillProduct` returns what `TerminateJobObject` returned and `SuiteStopProduct` returns True only if the order
   was taken **and the setup is gone** within `SuiteKillWaitMs`. `SuiteStopBeforeInstall` closes the handles of the frozen
   processes without resuming them (`Killed`) only after that. Before, a failed kill left a hidden (`/VERYSILENT`) setup
   frozen for good, holding its mutex, and the read after the kill still saw no install step: the suite reported
   "cancelled before it installed anything" and went on. Now the processes run again and the result is *unclear*.
   (b) `SuiteFreezeJob` takes the loader (`SuiteChildProc`, the process the job was made for). A pass that finds nothing new
   is a success only if the loader has ended or its id (`GetProcessId`) is among the frozen processes: an id that
   `OpenProcess` rejects with `ERROR_INVALID_PARAMETER` counts as ended, so a wrong or empty list of the job (a layout
   mistake of the record under WOW64) would otherwise end as a success with 0 frozen processes, and the kill would go
   ahead on a running setup, which is the old race again. A frozen loader means at least one frozen process while it runs.
   (c) `SuiteStopDecision` tells *too late* (`SuiteStopTooLate`) from *unclear* (`SuiteStopUnclear`: not everything frozen,
   the log not read to its end, a last line with only its time stamp, the stop did not happen). Only *too late* is
   answered with `SuiteCancelNotNow` ("Cancel is no longer possible: the game is being installed"), which would be untrue
   otherwise and dropped the "Yes" of the user. A confirmed cancel with an *unclear* result stays requested and is decided
   again after the next wait slice, `SuiteCancelTriesMax` (5) times (a line that is being written is complete within
   milliseconds, a freeze that failed once usually works the next time); if it stays unclear, the log says `the cancel was
   not carried out, its setup could not be stopped safely` and the user gets the new text `SuiteCancelRetry` (English,
   German, French: it could not be stopped safely right now, the installation goes on unchanged, click Cancel again). The
   stall question and the cap end a product setup only on `SuiteStopDone` (stopped or incomplete), so a result that the wait
   does not know is no stop.
8. **`/TestCancelAtInstall` reads to the end of the log.** `SuiteTestLogShowsInstall` reads its copy of the progress with
   `SuiteTailLogToEnd`: one `SuiteTailLog` call reads one chunk of at most 256 KB, and a log that is longer before the install
   step would never have triggered the test cancel.
9. **Evidence.** Unit tests (`ci/tests/suite_tests.iss`): the decision for 34 combinations of new lines, partial last
   lines, freeze result and termination; `SuiteTailLogToEnd` on a log longer than one chunk, with a cut marker line, missing
   and unreadable; `SuiteFreezeJob` and `SuiteResumeFrozen` on real programs (the setup of the test as a loader with a real
   setup that writes every 25 ms: frozen, nothing is written; resumed, it goes on; terminated while frozen, it ends with
   `SuiteKillCode`; no job; a job whose program ended; a loader that runs outside the job and an empty job, both no freeze; a
   64-bit program frozen, resumed and stopped by the 32-bit test setup; a pause after the freeze before the first size is read,
   because a write that was in progress finishes; `SuiteKillProduct` on a closed job). `ci/check_suite.py` parts [Freeze], [Hook]
   and the list of the log lines the scenarios match, with mutants. The smoke test of the scenarios (the fake Windows) takes the
   lines of the cancel from the `Log(` templates of `suite/*.iss`, filled in with sample values, instead of writing them by hand,
   and runs every pattern of S11 to S14 against those lines: the first version of S14 expected `N processes run again` where the
   code writes `its N processes run again`, and the fake wrote the same wrong line, so nothing caught it before Windows. A Wine run of the placeholder suite (copied prefix, no network): `/TestCancelAtInstall
   /TestCancelNeoEE` gave the S14 sequence above with exit code 0 and EE complete, `/TestCancel` and `/TestCancelNeoEE`
   froze 2 processes and stopped the job before the line (exit codes 3 and 0), and a cancelled repair left every file of
   EE as it was. On Windows the job `suite-e2e` (S11 to S14) and TP-99 on the laptop remain.

**Consequences.**

- A cancel that arrives while the game setup writes the install step line is answered "not now" (before: sometimes a
  killed setup and a game without install state). The user's outcomes otherwise do not change.
- The freeze takes milliseconds. A suite that dies while a product setup is frozen leaves it frozen (nothing resumes it):
  the window is the few milliseconds between the freeze and the decision, and a frozen setup is visible and can be ended in
  the Task Manager; the alternative, a kill, is what this amendment avoids.
- The placeholder setups of CI are 4 seconds slower per product run. There is no buffering risk: Inno Setup 6.2.2 keeps no
  buffer for its log (point 1). The residual window is the late suspension: one system call can finish after the freeze, which
  leaves at most a time stamp or a part of the text in the log (unclear, not stopped), and the read after the termination
  reports a line that shows up late as *incomplete* instead of claiming that nothing was installed. The cases that remain are
  a suite that dies during the few milliseconds of the freeze (documented above) and a stop that Windows does not carry out
  (the processes run again, the click is answered with `SuiteCancelRetry`).
- The contract (1.7 point 2, informative) says that the suite decides on the log of a frozen setup.

## Amendment: a process that is ending counts as ended in the freeze (2026-10-08, for suite 1.1.1)

**Context.** CI run 48 ([run 37684555046](https://github.com/DritteRippe/Empire-Earth-Setup/actions/runs/37684555046), push
of `release-1.1.0`, commit `2b764e4`) failed in the unit test "SuiteFreezeJob of a job whose program ended" with `process
3384 cannot be suspended`; run 49 on the same commit passed. The test starts `cmd.exe /c exit 0`, waits until it has ended
and freezes its job at once. Windows 8 and later start a console helper (`conhost.exe`) in the job of a console program,
and the helper ends a moment after the program. The likely sequence (it cannot be replayed on purpose, and the old reason
did not say what Windows answered): the job still listed the helper, `NtSuspendProcess` refused it because its last thread
was ending (`STATUS_PROCESS_IS_TERMINATING`, `0xC000010A`), and its process object was not signalled yet, so the look
without waiting (`WaitForSingleObject` with 0 ms) did not count it as ended either. `SuiteFreezeJob` took it for a process
that cannot be frozen. A product setup can meet the same moment when its loader or a helper ends while the user cancels:
the cancel was then *unclear* (point 3 of the race amendment) and was decided again. That is safe, but it is not what
happened, and the log did not tell why Windows refused.

**Decision.**

1. **A process that Windows reports as ending is ended for the freeze.** The pure function `SuiteSuspendFailureIsEnd`
   (`suite_common.iss`) decides for every suspension that failed: it counts as an end if the status is
   `STATUS_PROCESS_IS_TERMINATING` or the process has ended (`WAIT_OBJECT_0`). `NtSuspendProcess` returns that status when
   the process is being run down because its last thread is exiting (in the Windows Research Kernel `PsSuspendProcess`
   fails with it when it cannot acquire the run-down protection of the process, which the exit of the last thread runs
   down; current versions are as undocumented as the function itself). Such a process runs no code of its own any more: it
   starts no process and writes no log line. If it is the loader (`GetProcessId` of `Proc`), the end check of the freeze
   counts it like a loader that has ended. **Any other failure is still a process that may run on:** the freeze fails, the
   product setup is not stopped and the cancel is *unclear*, as before (race amendment, points 3 and 7). The guarantee of
   the race amendment does not change: a product setup that runs and cannot be frozen is never stopped.
2. **The reason names the NTSTATUS.** Any other failed suspension is reported as `process <id> cannot be suspended
   (NTSTATUS 0x<8 hex digits>)` (`SuiteNtStatusText`) in the existing log line `its setup could not be frozen (...)`, so a
   refusal on a player's machine can be told apart (for example `0xC0000022`, access denied).
3. **Checks and tests.** `ci/check_suite.py`, part [Freeze]: a failed suspension counts as an end only through
   `SuiteSuspendFailureIsEnd`, which accepts only `STATUS_PROCESS_IS_TERMINATING` (`-1073741558` as a Longint) and
   `WAIT_OBJECT_0`, and `SuiteFreezeJob` suspends in one place only; three mutants of its self-test must fail. The unit
   tests check the classification as a pure function (ending and not yet signalled, ending and signalled, access denied
   with and without an end, another failure, a failed wait) and the text of the status.
4. **The unit test waits until the job is empty.** "SuiteFreezeJob of a job whose program ended" now waits, at most 30
   seconds, until the job lists no process any more (`QueryInformationJobObject` with `JobObjectBasicProcessIdList`, the
   list that `SuiteFreezeJob` reads, rather than the counter `ActiveProcesses` of `JobObjectBasicAccountingInformation`: the
   test waits for exactly the input of the function it tests) and then expects a success with nothing frozen. The moment of
   the ending helper is no longer part of that test; the classification of point 1 is tested on its own (point 3).

**Consequences.**

- A cancel that meets a process of the product setup just as it ends is no longer answered with "could not be stopped
  safely right now" for that reason alone. Nothing else changes for the user.
- The rule still errs on the side of not stopping: a process that refuses the suspension for any other reason, also one
  that ends a moment later, makes the freeze fail.
- The cause of run 48 stays a well-founded guess; a different cause would now show up with its NTSTATUS in the reason of
  the unit test and in the log of the suite.
- The contract (1.7 point 2, informative) says that a product setup that cannot be frozen runs on; a process that is ending
  is not one that cannot be frozen.

## Amendment: the deletion of the user data is checked up to the last moment (2026-10-08, for suite 1.1.1)

**Context.** The check of the state after the release of suite 1.1.0 (2026-10-07) read decision 11 against the code of
`suite_uninstall.iss` and against `DelTree` of Inno Setup 6.2.2 (`Projects/InstFunc.pas` of the tag `is-6_2_2`). What is
deleted after the answer "Delete" is right when the list is made: fixed folders below the install roots and the
launcher's data folder, none that is a link or lies below one. But the suite looks at the folders once, before its
question, and the question waits for the user without a limit. `DelTree` checks only the folder it is given, and each
folder it finds inside, for a link (`IsDirectoryAndNotReparsePointRedir`) and removes such a link without entering it;
a link in a folder above it is resolved by Windows like in any other path. `Data\dxm`, the folder above the target
`Data\dxm\mods`, lies below `Data`, which every user may write to in an installation for all users (ADR 0009), so a
standard user who replaces it by a junction while the question is open makes the elevated `DelTree` delete the content
of the junction's target. Two smaller points: `SuiteIsReparsePoint` took a folder whose entry `FindFirst` could not read
for "no link" (fail open, unlike the walk of the product setups), and the comment above `SuiteIsBehindLink` and the
text of `ci/check_suite.py` said that `DelTree` follows a link that is the folder itself, which it does not.

**Decision.**

1. **A path that cannot be looked at counts as a link.** The pure function `SuiteLinkVerdict` (`suite_common.iss`)
   decides for `SuiteIsReparsePoint`: an entry with `FILE_ATTRIBUTE_REPARSE_POINT` is a link, and so is a path that
   exists (`DirExists` or `FileExists`, which need no right to list the folder above) although `FindFirst` cannot read
   its entry. A path that does not exist is none. The check of the suite fails closed like the walk of the product
   setups (ADR 0009, decision point 1); the log lines say "is a link (junction or symbolic link) or cannot be checked".
   The unit tests check the verdict as a pure function: a folder, a file, a junction, a symbolic link to a file, a path
   that exists but cannot be looked at, a path that does not exist.
2. **The link check is repeated right before each `DelTree`.** `SuiteExistingDataFolders` offers every folder through
   `SuiteOfferDataFolder`, which records the root its link check goes up to (the install root of the product, the
   launcher's data folder) at the same index as the folder. After the answer "Delete", `SuiteDeleteDataFolders` checks
   each folder again right before its `DelTree`: it must still exist (`DirExists`) and neither it nor a folder above it up
   to that root may be a link now (`SuiteIsBehindLink`). A folder that fails stays, with the log line `User data folder
   not deleted, it or a folder above it is a link (junction or symbolic link) now or cannot be checked: <folder>` (or
   `... it is gone already: <folder>`). The window that was open as long as the question waited shrinks to the moment
   between that check and the end of the `DelTree`.
3. **The empty folders are removed only if they are no link.** `RemoveDir` never removes a folder with content, but it
   removes a junction or a symbolic link whatever its target holds, and it follows a link in a folder above. The
   folders of `SuiteEmptyFolder` and the launcher's data folder are removed only if `SuiteIsBehindLink` finds no link
   up to their root; otherwise they stay, with the log line `Folder left as it is, ...`.
4. **The checks.** `ci/check_suite.py`, part [Uninstaller], requires that each folder is offered through
   `SuiteOfferDataFolder` with its root, that `SuiteOfferDataFolder` leaves out a folder behind a link and one of a
   product that stays installed and records the root, that `SuiteDeleteDataFolders` checks `DirExists` and
   `SuiteIsBehindLink(Folders[I], Roots[I])` right before `DelTree`, and that every `RemoveDir(Target)` follows a
   `SuiteIsBehindLink(Target, ...)`; its self-test has a mutant for each (among them the second check removed, and the
   second check against the folder itself instead of its root, which would miss a link in `Data\dxm`). The comment
   above `SuiteIsBehindLink` and the text of the check now describe `DelTree` as it is.
