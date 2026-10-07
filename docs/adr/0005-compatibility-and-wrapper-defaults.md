# 0005. No compatibility values on Windows Vista/7; keep the DirectX wrapper preselection

- Status: Accepted, implemented (S-WP4, see [Implementation](#implementation)); point 1 amended by
  [ADR 0010](0010-opt-in-compatibility-on-windows-7.md) (opt-in flags on Windows 7, Windows 8/8.1
  compared with 1.7.2, rules for the graphics matrix); the wrapper section amended on 2026-10-07 (dgVoodoo 2.87.5, the
  window keys, intro videos by default, see the last section)
- Date: 2026-10-02
- Requirements: R15, contract question O7
- Revised: 2026-10-02, plan review before implementation (the 1.7.2 baseline was described wrongly;
  the forum evidence is weak; the task `compatibility` is now also limited to Windows 8 and later)

## Context

Two defaults of the setup were questioned by the forum study (save-ee.com support forum, 2009 to
2019, report section 5 and 8):

1. **Compatibility values** (`AppCompatFlags\Layers` of `Empire Earth.exe` and `EE-AOC.exe`): the
   tasks `compatibility` (`DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`) and
   `compatibility_windows` (a Windows version layer: `WIN7RTM` on Windows 8 and later, `WINXPSP3`
   on Windows Vista and 7) are both selected by default; the tasks page is only shown with the
   custom settings. **What the official 1.7.2 setups do on Windows Vista/7:** `EE-AOC.exe` gets
   `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3`, `Empire Earth.exe` gets
   **no value at all**: its Vista/7 entries carry the typo `OnlyBelowVersion: 0.6.2` (NT version
   0.6, i.e. never; `realdata/upstream/setup_is6.iss`, the real-data knowledge base classifies the
   refactor's correction as an intended fix). The refactor branch would therefore have introduced
   the flags and `WINXPSP3` for `Empire Earth.exe` on Windows 7, a change nobody tested.
2. **DirectX wrapper preselection:** the graphics card page of the recommended settings always
   preselects a wrapper (dgVoodoo DirectX 11 for NVIDIA, AMD and Intel, the GOG `DDraw.dll` for
   unknown vendors); "native" (no wrapper) can be chosen but is never preselected.

## Decision

1. **Windows Vista/7 get no compatibility values.** Both tasks, `compatibility` and
   `compatibility_windows`, get `MinVersion: {#Win8}` (they are not shown and not selected below
   Windows 8); the Vista/7 `[Registry]` entries (`CompatibilityValuesByWindows`, `WINXPSP3`) are
   removed. On Windows Vista/7 only the opt-in `~ RUNASADMIN` (task `everyoneadminstart`) can still
   be written. This is what 1.7.2 did for `Empire Earth.exe` and what the forum administrators
   reported as normal for Windows 7 ("never had to use compatibility mode"); `DWM8And16BitMitigation`
   is a Windows 8 mitigation anyway. On Windows 8 and later nothing changes (`WIN7RTM`, the flags,
   the GPU preference). An update on Windows Vista/7 removes the values earlier setups wrote there,
   but only values that exactly match one the setups wrote and that contain the flags or
   `WINXPSP3`: `BuildCompatibilityFlags(RunAsAdmin, Compatibility)` plus an optional ` WINXPSP3`, for
   every combination except the plain `~` and `~ RUNASADMIN` (pure helper
   `IsLegacyVistaCompatValue`, unit-tested), in HKLM (admin) or HKCU (user/portable), for both game
   programs, at `ssPostInstall`. Any other value (set by the player, e.g. `~ WINXPSP3 DISABLEDWM`)
   stays. Because the current run cannot write such a value on Vista/7, the cleanup never removes
   what the same run wrote.
2. **The DirectX wrapper preselection stays**, documented with the evidence below, and stays
   user-selectable (option "native" on the graphics card page, components page of the custom
   settings; the launcher may offer a switch later, contract 3.3). The test plan gets a wrapper
   matrix (mouse, menu text, NeoEE overlay, with and without wrapper).
3. The contract (3.7 with a table of flags per task and Windows version, O7) is changed in both
   repositories by the contract revision (S-WP1), before the setup implements it (S-WP4).

## Evidence

Compatibility mode on Windows 7 (forum; topic and post ids of save-ee.com). **The evidence is weak:**
the forum ends in 2019, the community setup started in 2022, so no post is about the values this
setup writes, and no post names the mode that was used:

- t=4280 p=30477 (Omega, administrator, 2012, Windows 7 64-bit): "Running them in compatibility
  mode is probably your issue ... I just tried starting EE under compatibility mode, and it wouldn't
  even run that way for me. Just a long black screen and a runtime error." The player answered
  (p=30480) that he ran both games without compatibility mode and the problem stayed; it was solved
  by the renderer (p=30485), so the post is no proof of harm, only the administrator's own test.
- t=4280 p=30479 (Ghost, administrator): "I've never had to use compatibility mode for EE or AoC on
  Windows XP, Vista 32, Vista 64, 7 32, or 7 64."
- t=1827 p=12147 (Ghost, 2010): Windows 7 "doesn't require running in compatibility mode or anything
  like that".
- t=5814: the compatibility mode made the program freeze. No forum post reports that the XP layer or
  the flags fixed anything on Windows 7.
- The decision therefore rests on "no evidence of benefit, weak evidence of harm, and the official
  1.7.2 behaviour of `Empire Earth.exe`", not on proof of harm. The test plan checks Windows 7
  (VM only) with and without the values.

Windows 8 and later: t=5842 p=39349 (2015, "my ee never worked on windows 8 ... now it works fine
[on Windows 10] in compatibility mode") and the most read Windows 8 guide (t=5748 p=38768) recommend
the Windows 7 mode; nothing reports harm from `WIN7RTM`. The flags of the task `compatibility` are
mitigations (8/16-bit colour on Windows 8+, DPI, heap), not a version layer; the forum reports
16-bit freezes on Windows 10 (t=10931 p=47182) and the 32-bit fix (t=11042 p=48016), which the
default settings already set.

DirectX wrappers:

- The forum barely covers wrappers: dgVoodoo appears once (t=5887 p=39385, GOG version, Windows 7):
  it brought back the menu texts, the mouse did not react in game; the NeoEE crash in that topic also
  happened without dgVoodoo. The forum ends in 2019, before the setup shipped wrappers.
- The setup has shipped wrappers since 1.0.0.0 (2022), the graphics card page since 1.0.3.0, vendor
  detection since 1.5.0, and the maintainers kept adjusting the dgVoodoo configurations and versions
  from player feedback (CHANGELOG 1.5.0 to 1.7.2: window size and focus fixes, reworked configs).
  The forum gives no evidence against the default, only too little evidence for it; changing a
  default that the current player base uses without new evidence would be a regression risk.

## Consequences

- No compatibility values on Windows Vista/7; players who need one can still set it in the file
  properties. Compared with official 1.7.2: `Empire Earth.exe` unchanged (no value), `EE-AOC.exe`
  loses its value; compared with the refactor branch both lose it. The CHANGELOG states both.
- Without `HIGHDPIAWARE` on Windows 7 the game is DPI-virtualized at 150 % and more; the window
  size of contract 3.3 is then larger than the visible area. Windows 7 test case (VM only).
- The real-data comparison of S-WP4 is made against the previous build **and** against official
  1.7.2 and shows only: `MinVersion` of both tasks, the removed Vista/7 registry entries, the
  compiled code of the legacy value cleanup.
- `CONTRACT.md` 3.7 and O7 change in both repositories (identical text, same commit subject).
- The wrapper question stays open for real tests (test plan: graphics matrix).

## Implementation

S-WP4, 2026-10-02, in this order: the helper with its unit tests, the test cases (TP-20 to TP-24),
then the change of the setup together with README, CHANGELOG and architecture document.

- `utils.iss`: the constant `LegacyVistaCompatLayer` (the only place that still names the Windows
  XP SP3 mode), `IsBelowWindows8(Major, Minor)` (6 unit tests, 5.1 to 10.0) and
  `IsLegacyVistaCompatValue(Value)` (29 unit tests: every combination of `BuildCompatibilityFlags`
  with and without the layer, the six values written out, and 15 values that must stay: `~`,
  `~ RUNASADMIN`, `~ WINXPSP3 DISABLEDWM`, the empty value, other case, order and spacing, the
  Windows 8+ values). Dropping the condition `Compatibility and` or comparing case-insensitively
  makes 4 tests fail each.
- `setup_is6.iss`: `MinVersion: {#Win8}` for the tasks `compatibility` and
  `compatibility_windows`; `CompatibilityValuesByWindows` became `CompatibilityValuesWin8` without
  the Vista/7 branch, so 8 `[Registry]` entries are gone (HKLM and HKCU, two task conditions each,
  `Empire Earth.exe` and `EE-AOC.exe`). `RemoveLegacyVistaCompatValues` runs at `ssPostInstall`
  after `RemoveLegacyRunAsAdmin`: below Windows 8 it reads the values of both programs in HKLM
  (administrative install mode) or HKCU (user and portable mode) and deletes one only if
  `IsLegacyVistaCompatValue` accepts it; each value is logged as removed, kept or missing. It runs
  under Wine like on Windows (contract 3.7: every run) and finds nothing there, because no setup
  offered the tasks under Wine. `pages.iss` is unchanged.
- The preprocessed scripts of all four variants contain `WINXPSP3` only in
  `LegacyVistaCompatLayer`. Their diff against the S-WP3 state (comment lines ignored) is the
  `MinVersion` of the two tasks, the 8 entries and the new code.
- Run-time probe under Wine (not in the repository: a tiny setup with the real
  `RemoveLegacyVistaCompatValue`, cut out of `setup_is6.iss`, working on a scratch key in HKCU): it
  removed `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3` and
  `~ RUNASADMIN WINXPSP3`, kept `~ RUNASADMIN` and `~ WINXPSP3 DISABLEDWM`, logged a missing value
  and left the value of another program alone. The Windows version test is covered by the unit
  tests only (the Wine prefix reports Windows 10).
- Real-data comparison (maintainers only, never committed: EE and NeoEE built with ISCC from the
  reconstructed 1.7.2 data, official AppIds, unsigned; the innoextract dumps compared
  semantically). Against the S-WP3 build, for EE and NeoEE alike, only these differ: the compiled
  code, the `MinVersion` of the tasks `compatibility` and `compatibility_windows` (Windows XP ->
  Windows 8) and the 8 Vista/7 entries (80 -> 72 registry entries); files, data, messages,
  components, the other tasks and registry entries, run entries and folders are identical, so the
  `WIN7RTM` entries, the Windows 8+ flags and the GPU preference are unchanged. Against official
  1.7.2 the registry entries that S-WP4 drops are exactly the 4 `EE-AOC.exe` entries for Windows
  Vista/7 (HKLM and HKCU, with and without `WINXPSP3`); the 4 `Empire Earth.exe` entries with the
  filter `0.62`, which never applied, were already absent from the S-WP3 build in that form and are
  now gone completely. No entry was added. All other differences against 1.7.2 are unchanged.
- README "Compatibility and graphics options" documents the evidence, the change on Windows 7 and
  the way to "Native"; the CHANGELOG (Changed) names both comparisons. Test plan: TP-20 and TP-21
  (Windows 7, virtual machine only: new installation without values, update over 1.7.2 that
  removes the `EE-AOC.exe` value and keeps a value of the player), TP-22 (Windows 10/11
  unchanged), TP-23 (graphics matrix native, DirectX 7, 9 and 11 with menu texts, mouse and the
  NeoEE overlay), TP-24 (150 % with and without the task `compatibility`, and Windows 7; contract
  O4).

## Alternatives considered

- **Unselect `compatibility_windows` by default everywhere:** removes `WIN7RTM` on Windows 8/10,
  where the forum reports it helping.
- **Keep `WINXPSP3`:** contradicts the only first-hand reports.
- **Drop only `WINXPSP3`, keep the flags of `compatibility` on Vista/7:** would newly set
  `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` for `Empire Earth.exe` on Windows 7,
  which 1.7.2 never did, without any evidence for it.
- **Make "native" the default:** no evidence that it is better on current Windows; the setup's wrapper
  defaults are the community's current practice.

## Amendment 2026-10-07 (setup 1.1.0: dgVoodoo 2.87.5, the window keys of K1, the configurations in the repository, intro videos by default)

### Context

The laptop matrix of the runs 5c and 5d (Windows 11, Intel graphics, screen 1920x1200 at 100 %, dgVoodoo 2.87.5 x86
`DDraw.dll` and `D3DImm.dll` in the game folder) found how the window settings of dgVoodoo decide three things the
players report: the multiplayer lobby, Alt+Tab and the mouse at the start.

- Real fullscreen with `DeferredScreenModeSwitch = false` and the game at 1920x1080 (a real display mode change at the
  start): the mouse works at the start (rows B, H, the stock configuration). With Alt+Enter disabled (B) the multiplayer
  lobby minimizes the game (dgVoodoo's lost-mode emulation minimizes a covered real fullscreen window, which hides the
  lobby); with Alt+Enter enabled (H) the lobby is fine, but the restore after Alt+Tab fails or comes back shifted (a mode
  change 1080 to 1200 and back).
- Fake fullscreen (`FullscreenAttributes = fake`, Alt+Enter disabled) at 1080 (rows E, F) and at 1200 (K1): lobby, scenario
  editor and Alt+Tab work; bars at 1080, none at 1200. The mouse is dead at the start in every fake case.
- K2 = H at 1200 (real fullscreen without a mode change): lobby and Alt+Tab work, the mouse is dead at the start.
- With the intro videos installed (`Data\Movies` with `Sierra.bik`, `SSSI.bik`, `Empire Earth.bik`) the mouse is still
  dead at the start, even during the intro (a click cannot skip it), until Alt+Tab; afterwards it works and skips the
  intro. A direct start (double-click on `Empire Earth.exe`) is as dead as a start from launcher 1.0.0.

The mechanism: the game acquires its DirectInput 7 devices (exclusive, foreground) during its start-up and acquires them
again only when it is activated (`WM_ACTIVATE` not `WA_INACTIVE` and not minimized, or `WM_ACTIVATEAPP(TRUE)`). Only a real
display mode change during the start-up happened to give it a valid activation. No dgVoodoo setting gives a live mouse
together with a working lobby and Alt+Tab.

### Decision

1. The dgVoodoo levels install dgVoodoo **2.87.5** (official release; `DDraw.dll` and `D3DImm.dll` x86, the control panel
   `dgVoodooCpl.exe` x64 only, 2.86.3 dropped the x86 one, so only on 64-bit Windows). `InstallDelete` still removes the
   2.82.1 files; 32-bit Windows has no control panel afterwards. Windows 10 on ARM64 cannot start the x64 control panel
   (it is optional).
2. **The window keys of K1 in every level** (the tier keys `OutputAPI` and `VRAM`, the video card, the vendor IDs, the
   watermark and `WindowedAttributes` stay as they were):

   | Section | Key | Value |
   |---|---|---|
   | (none) | `Version` | `0x287` |
   | `[General]` | `FullScreenMode` | `true` |
   | `[DirectX]` | `AppControlledScreenMode` | `true` |
   | `[DirectX]` | `DisableAltEnterToToggleScreenMode` | `true` |
   | `[DirectXExt]` | `DeferredScreenModeSwitch` | `false` |
   | `[GeneralExt]` | `FullscreenAttributes` | `fake` |

   Fake fullscreen trades the bars at 1080 (gone at 1200, contract 3.3 revision 6) and the dead mouse at the start (no
   dgVoodoo setting fixes it; the launcher's activation signal, launcher ADR 0010 amendment A1b, is expected to; TP-25 (b) checks it) for a working lobby,
   editor and Alt+Tab. K1 is preferred over K2 because it needs no Alt+Enter-enabled restyling and no display mode change,
   which K2 would need on every screen larger than the game.
3. **The five configurations are in the repository** (`config/dgVoodoo/dgVoodoo_<LEVEL>.conf`, byte for byte as tested,
   `-text` in `.gitattributes`), the three dgVoodoo files are **pinned** (`pins/dgvoodoo.txt`: SHA-256, size and the path in
   the official archive). Why files: the values become reviewable as the very bytes that were tested (a diff of a
   configuration is the review), and the real-data end-to-end test needs a source for them (they are in no official setup
   and no download). Rejected: `[INI]` entries (Inno's `[INI]` rewrites a found line as `Key=value`, cannot write the
   top-level `Version` key before `[General]`, makes two sources of truth, and whether dgVoodoo 2.87.5 parses the rewritten
   lines the same way is not verified) and a pin table of the keys while the configurations stay in `data\` (the same
   review value, but the end-to-end job would still have no source for them). `ci/dgvoodoo_pins.ps1` (every push) checks the
   window keys, the tier keys and that the five files differ only in `OutputAPI` and `VRAM`; `ci/build.ps1` compares the
   files of `data\` with the pins (a release build stops, a test build warns).
4. The intro videos belong to the types `full` and `compact`; an installation with custom components gets them once on
   the first update (install record value `ComponentDefaults`, [ADR 0004](0004-install-record-and-integrity-manifest.md)
   amendment). `dreXmod` options stay (`SkipIntroMovie 0`).
5. dgVoodoo's terms allow shipping individual files with a game or mod, not bundling it in launchers or frameworks for
   general use (`THIRD-PARTY-NOTICES.md`): dgVoodoo stays in the setups; the launcher neither contains nor downloads it.

### Evidence

- The rows of the matrix above (A, B, D to H, K1, K2, stock, direct start; test configurations in the maintainers'
  scratch folder, not committed), measured by hand on one laptop.
- CI: `ci/dgvoodoo_pins.ps1` and its 53 self-test cases (50 changed copies or files that must fail), the tests of `ci/build_helpers.ps1`, the end-to-end
  step D5 (files and configuration of a level, byte for byte). The behaviour on the laptop is the test case TP-25.

### Consequences

- The dx12 levels stay "experimental": fake fullscreen uses a flip-model window there, untested on NVIDIA and AMD.
- "Keine Rückmeldung" during long loads is possible with the borderless window (Dege).
- Screens larger than 1920 x 1200 show the capped game through dgVoodoo's scaling, untested.
- The README "Known issues" texts changed (mouse, notification, `dgVoodoo.conf`).
- A user's own edits of `dgVoodoo.conf` are replaced by every run, as before.
