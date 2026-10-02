# 0010. Opt-in compatibility flags on Windows 7; rules for the graphics and VirtualStore results

- Status: Accepted, implemented: points 1 to 3 and the README part of point 6 by S-WP10, the test
  plan parts of points 4 to 6 by S-WP9 (see [Implementation](#implementation)); points 4 and 5 are
  applied when TP-23 and TP-71 have results
- Date: 2026-10-02
- Requirements: R15 ("decide with evidence, document, keep user-selectable"), contract O7, forum
  report section 8 problem table item 2 (VirtualStore)
- Amends: [ADR 0005](0005-compatibility-and-wrapper-defaults.md) point 1 (the default stays, an
  opt-in is added) and its statement "On Windows 8 and later nothing changes"

## Context

[ADR 0005](0005-compatibility-and-wrapper-defaults.md) (implemented by S-WP4) gave both
compatibility tasks `MinVersion: {#Win8}`. On Windows 7 the setup therefore offers no compatibility
option at all, while R15 asks to keep the defaults user-selectable. Compared with official 1.7.2,
`EE-AOC.exe` lost not only the `WINXPSP3` layer (the subject of the forum evidence) but also the flags
`DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`, for which there is no evidence of harm;
ADR 0005 itself names the consequence that without `HIGHDPIAWARE` the game is DPI-virtualized on
Windows 7 at 150 % and the window of contract 3.3 is larger than the visible area.

ADR 0005 also says "On Windows 8 and later nothing changes". That is true against the refactor
branch only: official 1.7.2 wrote compatibility values only from Windows 10 on (`MinVersion: 0.0,10`
of its "Windows >=8" entries); the base branch (`d10d489`, CHANGELOG "Fixed") already gives
Windows 8 and 8.1 `WIN7RTM` and the flags. Nobody tested that on Windows 8.1.

The test plan collects results for the DirectX wrapper preselection (TP-23) and for VirtualStore
(TP-71), but no rule said what follows from them, so R15 for the wrappers and the setup side of
VirtualStore could never be closed.

## Decision

1. **Opt-in task on Windows 7.** A new task `compatibility_legacy` ("Enable compatibility flags",
   en/de/fr), only below Windows 8 (`OnlyBelowVersion: {#Win8}`), `Flags: unchecked`,
   `Check: not IsWine`, shown with the custom settings like the other compatibility tasks. If
   selected, the setup writes `BuildCompatibilityFlags(<everyoneadminstart>, True)`, i.e.
   `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` (with `RUNASADMIN` in front if that
   task is selected), **never** `WINXPSP3`, for `Empire Earth.exe` (component `game`) and
   `EE-AOC.exe` (component `gameaoc`), in HKLM (`admin`) or HKCU (`user`, `portable`), removed by
   the uninstaller. The default does not change: without the opt-in, Windows 7 still gets no value.
2. **The cleanup keeps what this run writes.** `RemoveLegacyVistaCompatValues` skips a program
   whose value this run writes with `compatibility_legacy` (task selected and the program's component
   selected); for every other program it stays as implemented. The decision is a pure helper with
   unit tests.
3. **Contract revision 2 (S-WP10, both repositories in one step):** contract 3.7 gets the row
   `compatibility_legacy | DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation | 7 only (opt-in)
   | HKLM / HKCU / HKCU` and the exception of point 2 in its cleanup rule; `ci/check_contract.py`
   learns the Windows version "7 only" and checks the new row like the others.
4. **Rule for the wrapper matrix (TP-23), fixed before the test:** if, for one graphics card vendor,
   the wrapper level that the graphics card page preselects shows a defect that "native" does not
   show on the same computer (menu texts missing, mouse not reacting, NeoEE overlay missing, crash
   or freeze), the result goes to the maintainers as a proposal to change the preselection **for
   that vendor** to the best level of the matrix; equal results keep the default. The change itself
   is a follow-up package with CHANGELOG entry (the rasterizer rule of contract 3.3 follows from the
   component and needs no change).
5. **Rule for VirtualStore (TP-71), fixed before the test:** if, after an `admin` installation and a
   game played by a standard user, files of the game appear below
   `%LOCALAPPDATA%\VirtualStore\<path of the game folder>`, a follow-up package grants
   `authusers-modify` to exactly the files or folders found (candidates from the forum: `_won*`,
   `neoee.log`, `upnp_info.txt`); if they are spread over the game folder, the package proposes a
   default folder outside `Program Files` instead. Nothing found: no change (the launcher still
   warns, R8).
6. **Windows 8 and 8.1** are documented as a change against 1.7.2 (README "Compatibility and
   graphics options"), and TP-22 gets an optional Windows 8.1 variant (virtual machine only,
   priority P3).

## Evidence

- `setup_is6.iss` `[Tasks]`: `compatibility` and `compatibility_windows` with `MinVersion: {#Win8}`
  (S-WP4, `56e012b`).
- `origin/master` `setup_is6.iss`: Vista/7 entries of `EE-AOC.exe` with `{code:GetCompatibilityFlags}`
  with and without `WINXPSP3`; the "Windows >=8" entries with `MinVersion: 0.0,10`.
- ADR 0005 Evidence: t=4280 p=30477 concerns "compatibility mode" (the Windows version layer); the
  player's answer (p=30480, p=30485) shows that it was not the cause. No forum post concerns the
  three flags on Windows 7.
- ADR 0005 Consequences: "Without `HIGHDPIAWARE` on Windows 7 the game is DPI-virtualized at 150 %".
- Real-data knowledge base, difference list: "MinVersion nt 10.0 -> nt 6.2 ... Windows 8/8.1 bekommen
  jetzt die Kompatibilitätseinträge" (`d10d489`).
- Forum report section 8, problem table item 2: "Falls ja, ist ein Standardziel außerhalb von
  Program Files die robusteste Lösung".

## Consequences

- Windows 7 players can choose the flags of 1.7.2 again, without the harmful layer; the default
  is unchanged, so the real-data comparison of S-WP10 shows only the new task, its registry entries
  and compiled code.
- One more Windows-7-only code path; TP-20, TP-21 and TP-24 get a variant with the task (virtual
  machine only).
- The launcher may offer the same values on Windows 7 (contract 3.7, "Windows versions of the
  table").
- TP-23 and TP-71 state the rules of points 4 and 5 as their expected consequence (S-WP9).

## Implementation

S-WP10, 2026-10-02, in this order: the helper with its unit tests (`2ce68ee`), contract revision 2
together with the task and the extended contract check (`727bc93` here, `0b2cb40` in the launcher
repository, same subject), the checks of the tables 3.3 and 3.4 (`921360a`), the test cases
(`ce29e90`), README and CHANGELOG (`bb4601e`).

- **Point 1:** `[Tasks]` `compatibility_legacy` with `OnlyBelowVersion: {#Win8}`, `Flags: unchecked`,
  `Check: not IsWine`, message `TaskCompatibilityLegacy` (English, German, French; "Enable
  compatibility flags (optional on Windows 7: can help if the game looks blurry or does not fit on
  the screen with enlarged display scaling)"). `[Registry]`: the new sub `CompatibilityValuesWin7`
  writes `{code:GetCompatibilityFlags}` without a Windows compatibility mode, `OnlyBelowVersion:
  {#Win8}`, `uninsdeletevalue`, for `Empire Earth.exe` (`game`) and `EE-AOC.exe` (`gameaoc`), in
  HKLM (`Check: IsAdminInstallMode`) and HKCU (`Check: not IsAdminInstallMode`). `GetCompatibilityFlags`
  passes `WizardIsTaskSelected('compatibility') or WizardIsTaskSelected('compatibility_legacy')` as
  the flags parameter; no Windows has both tasks, so the value is
  `BuildCompatibilityFlags(<everyoneadminstart>, True)` and nothing changes on Windows 8 and later.
  The RUNASADMIN-only entry requires `not compatibility_legacy` as well, otherwise two entries would
  write the same value on Windows 7 with both opt-in tasks. The preprocessed scripts of all four
  variants contain `WINXPSP3` only in `LegacyVistaCompatLayer`.
- **Point 2:** `ShouldRemoveLegacyVistaCompatValue(Value, LegacyOptInSelected, ProgramSelected)` in
  `utils.iss` (48 unit tests: the six old values with task and component, task without component,
  task not selected with and without component; the two values of the task; five values that are
  never removed; dropping the component condition fails 7 tests, dropping the exception 8).
  `RemoveLegacyVistaCompatValue` passes `WizardIsComponentSelected('game')` resp. `'gameaoc'` and
  logs a kept value as `written by this run (task compatibility_legacy)`; the header line names the
  selected task.
- **Point 3:** contract 3.7 has the row
  `compatibility_legacy | DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation | 7 only (opt-in) | HKLM / HKCU / HKCU`
  (between `compatibility` and `compatibility_windows`, the order of the value), `(opt-in)` also for
  `everyoneadminstart`, the exception in the cleanup rule, and for the launcher: such a value is no
  leftover when `Tasks` contains the task. `ci/check_contract.py` reads the Windows versions from
  `MinVersion` and `OnlyBelowVersion` of the tasks and entries ("7 only"), several tasks joined by
  `or` in `GetCompatibilityFlags` (one row each), `(opt-in)` against `Flags: unchecked`, a task that
  cannot be selected outside its Windows versions, and two entries that could write the value of
  one program in the same run (an error). 20 new self-test cases (11 for 3.7, 9 for 3.3 and 3.4),
  55 in all.
- **Point 6:** README "Compatibility and graphics options" (the option on Windows 7, Windows 8 and
  8.1 against 1.7.2); TP-20 (d) to (f), TP-21 (c) and TP-24 (d) test the task (virtual machine
  only, `P3`).
- Real-data comparison (maintainers only, never committed: EE and NeoEE built with ISCC from the
  reconstructed 1.7.2 data, official AppIds, unsigned; innoextract dumps compared semantically).
  Against the S-WP5 build (`5c4d895`), for EE and NeoEE alike, only these differ: the compiled
  code (EE 121005 -> 122096 bytes, NeoEE 125700 -> 126791 bytes), the three entries of the message
  `TaskCompatibilityLegacy` (845 -> 848 resp. 887 -> 890), the task `compatibility_legacy` (7 -> 8
  resp. 8 -> 9 tasks: only below Windows 8, unchecked, `not IsWine`) and the registry entries (72
  -> 76): the four new entries and `and not compatibility_legacy` in the `Tasks` of the two
  RUNASADMIN-only entries. Files, data, components, the other tasks and registry entries, run
  entries and folders are identical. Against official 1.7.2 the two new `EE-AOC.exe` entries equal
  its Windows Vista/7 entries without `WINXPSP3` (`Tasks: not compatibility_windows and
  compatibility`, value `{code:GetCompatibilityFlags}`, the same root, check, flags and
  `OnlyBelowVersion` NT 6.2) except for `Tasks` and the minimum (Vista; Inno Setup 6 setups start
  on Windows 7 SP1 only); 1.7.2 computed the same value (`~`, `RUNASADMIN` with
  `everyoneadminstart`, the flags with `compatibility`). The two `Empire Earth.exe` entries have no
  counterpart that ever applied in 1.7.2 (its filter `0.6.2`). No compatibility entry of the new
  build contains `WINXPSP3`.
- Run-time probe under Wine (not in the repository): a tiny setup with the real
  `GetCompatibilityFlags` and `RemoveLegacyVistaCompatValue`, cut out of `setup_is6.iss`
  (`WizardIsTaskSelected` replaced by a probe function, because Inno Setup 6.2.2 in this Wine
  prefix stops with "System Error. Code: 120" when the wizard is created, also without any code),
  on a scratch key in HKCU, with the values of earlier setups seeded. Task with Empire Earth only:
  the value of `Empire Earth.exe` written by "[Registry]" (`~ DWM8And16BitMitigation HIGHDPIAWARE
  HeapClearAllocation`) stays ("written by this run"), the old `EE-AOC.exe` value with `WINXPSP3`
  is removed; next run without the task: that value is removed; task with `everyoneadminstart` and
  both games: both `~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` stay; a
  value of the player (`~ WINXPSP3 DISABLEDWM`) stays; an unrelated value is never touched. The
  Windows version filter itself is covered by `OnlyBelowVersion` (Inno Setup) and the unit tests
  of `IsBelowWindows8`; the Wine prefix reports Windows 10.
- Not verified here: whether `DWM8And16BitMitigation` and `HeapClearAllocation` change anything on
  Windows 7, and the effect of `HIGHDPIAWARE` at 150 % there (TP-20 (d), TP-24 (d), virtual machine
  only).

S-WP9, 2026-10-02 (`d3d1421`): TP-23 states the rule of point 4 as the consequence of the
graphics matrix (a defect of the preselected level that "native" does not show on the same
computer: a proposal to change the preselection for that vendor, as a follow-up package; equal
results keep it), TP-71 (worked out then: an administrator installs, a standard user plays) states
the rule of point 5 for the VirtualStore listing, and TP-22 has the optional Windows 8.1 variant (f)
of point 6 (virtual machine `S-Win81` only, `P3`; without such a VM it is recorded as "untested").
The rules were written into the cases before any of them was run; the setup itself does not change.

## Alternatives considered

- **Keep ADR 0005 unchanged:** Windows 7's own compatibility tab can set "Disable display scaling
  on high DPI settings", but R15 asks the setup to keep its options selectable, and the setup's
  uninstaller would then not remove what the player set.
- **Write the flags by default on Windows 7:** ADR 0005 rejected that for `Empire Earth.exe`, which
  never had a value there; an opt-in avoids a new default without evidence.
- **Compute the window size in logical pixels on Windows 7 without `HIGHDPIAWARE`:** a change of
  contract 3.3 for both programs, for a case the opt-in covers.
- **Decide the wrapper and VirtualStore questions after the tests:** rules chosen after the results
  invite reading the results to fit; the rules are fixed now.
