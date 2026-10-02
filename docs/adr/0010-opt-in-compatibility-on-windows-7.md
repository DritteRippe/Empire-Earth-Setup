# 0010. Opt-in compatibility flags on Windows 7; rules for the graphics and VirtualStore results

- Status: Accepted (implemented by S-WP10; the rules of points 3 and 4 apply to the test results)
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
