# 0007. Read-only warnings for low resolution, foreign installations and a shared EE/NeoEE folder

- Status: Accepted, implemented by S-WP8 (see [Implementation](#implementation))
- Date: 2026-10-02
- Requirements: R12, R13, contract question O11
- Revised: 2026-10-02, plan review before implementation (installing into the folder of a retail or
  GOG installation is asked like the shared folder; the shared-folder question names the firewall
  rules); second plan review (old NeoEE keys in HKLM and foreign uninstall entries are found too;
  the notice advises against deleting registry keys by hand; screen size and DPI are logged);
  implementation of S-WP8 (the order of the checks; Empire Earth II and III are not reported; a
  folder counts for point 4 only if it exists and is not the root of a drive, and the
  `InstallLocation` of a foreign uninstall entry counts too; point 3 also finds the `<AppId>` setup
  data folder of a setup up to 1.7.2; notices and questions are not shown with `/SUPPRESSMSGBOXES`
  either; a height of 0 is unknown and gives no notice); contract revision 3 (contract O11 names the
  `<AppId>` setup data folder of point 3 too)

## Context

The forum study found recurring problems the setup could point out before installing:

- **Small screens** (netbooks with 1024x600): the game crashes after the intro (t=3863, t=5475); the
  setup silently raises the default window to 1024x768 (`GetScreenResolutionHeight`).
- **Leftovers of other installations** (retail CD, GOG, old patch chains, InstallShield entries):
  AoC started the wrong installation or not at all, setups offered only "repair/remove"
  (report 4.5, 4.7, 4.8; t=1036 p=4756, t=2847 p=19589, t=12082 p=49553). The usual advice was to
  delete registry keys by hand, which also deletes the NeoEE CD keys below `Software\Sierra\CDKeys`
  (report 4.19).
- **EE and NeoEE in one folder:** the setup allows it (separate setup data folders), but the
  integrity manifest of the product installed first becomes unreliable and uninstalling one product
  removes files of the other (contract 1.4 and O11), and also its firewall rules: they are deleted by
  program path (`netsh advfirewall firewall delete rule program="{app}\...\Empire Earth.exe"
  name=all` in `[Run]` and `[UninstallRun]`), which is the same path for both products.
- **Installing into the folder of another installation** (retail CD, GOG): players did it on purpose
  (t=5825 p=39087: the game copied to `X:\Sierra\Empire Earth` so that an installer found it). The
  result is a mix of file versions, and the uninstaller of the community setup later removes files
  that belong to the other installation.

## Decision

All checks are **read-only**: they never delete, move or change anything, and they never block a
silent installation (silent: log only).

1. **Low resolution (R13):** if the height of the primary screen (`GetSystemMetrics(SM_CYSCREEN)`,
   physical pixels, see ARCHITECTURE O4) is below 768 (and above 0, which means unknown),
   `InitializeSetup` shows a notice after the
   install-mode question: the menus of the game need 768 pixels, the window is set to at least
   1024 x 768 (width and height clamped separately, e.g. 1280 x 768 on a 1280 x 720 screen), the
   game may not fit or may crash after the intro; scaling in the graphics driver or a DirectX wrapper
   can help. The clamp of the window size (1024 to 1920 x 768 to 1080) stays. The predicate and the
   clamp become pure, unit-tested functions in `utils.iss` (`ClampGameWindowWidth/Height`,
   `IsScreenTooLow`). `InitializeSetup` always logs `SM_CXSCREEN`, `SM_CYSCREEN`, the DPI of the
   screen (`GetDeviceCaps(LOGPIXELSX)`) and the clamped window size, so that contract question O4
   and a support case can be decided from the setup log.
2. **Foreign or old installations (R12):** when the user leaves the folder page, the setup looks
   for (the notice lists the findings in the order of these checks: keys with their "Installed
   From" folder, the retail folders, the uninstall entries):
   - `Software\SSSI\Empire Earth` and `Software\Mad Doc Software\EE-AOC` in HKLM, 32- and 64-bit
     view (community setups write these keys only in HKCU, retail, GOG and old patches in HKLM;
     contract 1.4 source 4);
   - `Software\Neo\Empire Earth` and `Software\Neo\Art of Conquest` in HKLM, 32- and 64-bit view:
     the community NeoEE setup writes them only in HKCU (`config_neoee.iss`, `BaseRegEE`/`BaseRegAoC`
     in `[Registry]` `Root: HKCU`), so an HKLM key belongs to an old NeoEE installation from before
     the community setup (t=10577 p=46302: the key that had to go was 'in a "Neo" directory';
     report 4.6: t=11088 p=48257);
   - the uninstall entries of HKLM (32- and 64-bit view, `RegGetSubkeyNames` of
     `Software\Microsoft\Windows\CurrentVersion\Uninstall`): an entry whose `DisplayName` contains
     `Empire Earth` or `NeoEE` (case-insensitive) is reported with `DisplayName` and
     `InstallLocation`, unless its key is `{<AppId>}_is1` of one of the two community products or
     its `Publisher` is one of the two community publishers (`MyAppPublisher` of `config_ee.iss`
     and `config_neoee.iss`), and unless `Empire Earth` is followed by ` II` (Empire Earth II and
     III are other games with their own folders and keys). This finds InstallShield/MSI entries of
     the retail version and old NeoEE installers, which made later installers offer only
     "repair/remove" (report 4.7, 4.8, forum report section 8 item 22). The match is a pure helper
     `IsForeignUninstallEntry` (unit tests: community AppIds and publishers excluded, case, empty or
     missing values);
   - the folders `<system drive>\Sierra\Empire Earth` and `{commonpf32}\Sierra\Empire Earth` (default
     folder of the retail CD, t=5825 p=39087, t=5571 p=37625);
   - where available, the folder named by the "Installed From" values of these HKLM keys, shown in
     the notice (not those of HKCU: the community setups write them there for their own
     installations).

   Findings are shown once as a notice: what was found, that the community setup installs its own
   copy and does not change the other one, and then, without approving any manual cleanup: "Never
   delete the registry key `Software\Sierra` or one of its parent keys: `Software\Sierra\CDKeys`
   holds the NeoEE CD keys. To remove the other installation, use its own uninstaller (Windows "Apps"
   or "Programs and Features"), if it has one. The Empire Earth Launcher removes old game settings
   of your user account with a backup. If you are unsure, ask the community and attach the setup
   log." (deleting `Software\Sierra` by hand is what lost the CD keys in t=10950 and t=11021).
   Nothing is offered for deletion. Community installations (uninstall keys with the community
   AppIds or publishers) are not reported. The notice promises only what the launcher does
   (launcher `CleanupCandidates` and `CleanupAdvice`, L-WP8): it removes stale game keys of HKCU
   and their VirtualStore copies with a `.reg` backup, lists only `Software\SSSI\Empire Earth` and
   `Software\Mad Doc Software\EE-AOC` of HKLM, with the advice for a stale one to export it in the
   Registry Editor before deleting it, and knows neither the HKLM `Neo` keys nor the uninstall
   entries nor the retail folders. The first wording
   ("Please do not delete registry keys by hand ... The Empire Earth Launcher offers a cleanup with a
   backup", decision K15 of the plan revision) promised a cleanup of exactly these findings and
   contradicted the launcher's advice for the SSSI and Mad Doc keys; the review with real data
   replaced it.
3. **Shared folder (O11):** when the user leaves the folder page and the chosen folder already holds
   the other product (`_setupdata_<other product>` exists, or `<AppId of the other product>`, the
   setup data folder of setups up to 1.7.2, or the other product's uninstall key in HKLM (both
   views) or HKCU has this folder as `Inno Setup: App Path`, which also finds 1.7.2 installations),
   a Yes/No question
   (`SharedFolderQuestion`) explains the consequences (the integrity check of the other product,
   uninstalling one removes files **and the firewall rules** of the other) and recommends another
   folder; "Yes" (default) stays on the folder page, "No" continues.
4. **Folder of another installation (R12):** the same kind of question (`ForeignFolderQuestion`,
   default "choose another folder") when `{app}\Empire Earth` or `{app}\Empire Earth - The Art of
   Conquest` is the same as or inside a folder found in point 2 (the folder of an HKLM
   "Installed From" value, `<system drive>\Sierra\Empire Earth`, `{commonpf32}\Sierra\Empire
   Earth`, the `InstallLocation` of a foreign uninstall entry such as the GOG folder; only folders
   that exist and are not the root of a drive), or the other way round. The comparison is a pure,
   unit-tested helper
   `IsSameOrInside(Root, Candidate)` (case-insensitive, normalized separators and trailing
   backslash, `C:\Sierra2` is not inside `C:\Sierra`).
5. The folder-page checks only run when the page is shown: an update in place keeps the previous
   folder (`UsePreviousAppDir`), whose state was checked at the first installation. In silent mode
   and with `/SUPPRESSMSGBOXES` (like the other notices of the setup) the notices and questions are
   not shown: the findings are logged and the installation continues.
6. New texts in English, German and French; every finding is logged.

## Evidence

- Netbooks: t=3863 p=26167 (Asus Eee PC, 1024x600, Windows 7, crash after the intro), t=5475; the
  contract asks for the warning in setup and launcher (3.3).
- Retail folder `C:\Sierra\...`: t=5571 p=37625 (setup could not create "C:/Sierra/..."), t=5825
  p=39087 (copying the game to `X:\Sierra\Empire Earth` made the NeoEE installer find it).
- Registry leftovers: t=1036 p=4756 (keys of Empire Earth, AoC, Mad Doc, Stainless Steel Studios,
  SSSI and Sierra), t=12082 p=49553 (`HKLM\Software\Sierra` or `SSSI\Empire Earth`, "sometimes this
  helped"); deleting `Software\Sierra` removes the NeoEE CD keys (t=10950, t=11021).
- Where the community setups write the game keys: `[Registry]` `GameSettings`, `Root: "HKCU"` only.

## Consequences

- Players with old installations get a hint instead of a silent conflict; nothing is removed
  automatically, so no CD key or player data can be lost.
- False positives are possible (an old retail installation the player keeps on purpose); the notice
  is informative and appears once per run.
- The exact keys and folders are listed in `environment.iss` and in the test plan (case "old
  installation present").

## Implementation

S-WP8, 2026-10-02, in this order: the pure helpers with their unit tests (`ad4fcee`), the check of
the community publishers (`82974d4`), the screen in the log and the notice for a low screen
(`15a7e3e`), the checks of the folder page (`1e1e8ee`), the test cases and this documentation.

- **Point 1:** `environment.iss` (new, included after `randommaps.iss`) has the screen API that was in
  `setup_is6.iss` (`GetSystemMetrics`, `SM_CXSCREEN`, `SM_CYSCREEN`) and the new external imports
  `GetDC`, `GetDeviceCaps` (`LOGPIXELSX`) and `ReleaseDC`. `LogScreenMetrics` runs in `InitializeSetup`
  on every run, before the update check, and logs `FormatScreenMetrics`: `Screen: <w> x <h> pixels
  (primary screen, SM_CXSCREEN x SM_CYSCREEN), <dpi> DPI (LOGPIXELSX, <p> % scaling), game window
  <w> x <h>`. `ShowLowScreenResolutionNotice` follows `ConfirmInstallMode`: `IsScreenTooLow` (below
  768, 0 is unknown) gives the notice `LowScreenResolution` with the screen and the game window.
  `ClampGameWindowWidth/Height` replace the inline clamp of `GetScreenResolutionWidth/Height`; a unit
  test compares them with the old code for every size from -10 to 4000. The limits
  `MinGameWindowWidth` ... `MaxGameWindowHeight` moved to `utils.iss`; `ci/check_contract.py` checks
  table 3.3 against them there (its self-test cases now change `utils.iss`).
- **Point 2:** `CheckForeignInstallations`, once per run on the first Next of the folder page: the
  four keys in HKLM32 and, on 64-bit Windows, HKLM64 (named as regedit shows them,
  `FormatHklmKeyName`, with the folder of their "Installed From" values, `InstalledFromFolder`,
  unless it is a drive root), the two retail folders (named once if a key named the same folder),
  and the uninstall entries of both views (`RegGetSubkeyNames`, `DisplayName`, `Publisher`,
  `InstallLocation`; `Checked <n> uninstall entries of HKLM in <ms> ms` in the log).
  `IsForeignUninstallEntry` excludes the keys `{<AppID>}_is1` and `{<OtherAppID>}_is1`, the
  publishers `CommunityPublisherEE` and `CommunityPublisherNeoEE` of `utils.iss` and Empire Earth
  II/III. The publishers exist three times (contract 0, `MyAppPublisher` of both configurations,
  `utils.iss`); `ci/check_contract.py` rule "0" checks that they match. Every finding is logged; the
  notice `ForeignInstallFound` lists at most twelve (`FormatFindingList`, then `... (+n)`). It holds
  the wording of this decision; nothing is offered for deletion. No key below `Software\Sierra` is
  read.
- **Points 3 and 4:** `CheckSelectedFolder` (`NextButtonClick(wpSelectDir)` returns it; every other
  page still continues): `IsFolderOfForeignInstallation` compares `{app}\Empire Earth` and the AoC
  folder with every existing folder of point 2 in both directions (`IsSameOrInside`);
  `IsOtherProductInFolder` looks for `_setupdata_<other product>`, `<OtherAppID>` and the
  `Inno Setup: App Path` of the other product's uninstall key in HKLM32, HKCU and HKLM64
  (`IsSameFolder`). Contract O11 named only the first and the last of these triggers; contract
  revision 3 (both repositories) added the `<AppId>` folder, so contract and code agree.
  `AskForAnotherFolder` asks with `MB_YESNO` (Yes is the default button) and logs
  the answer; Yes keeps the wizard on the folder page, No continues. `ForeignFolderQuestion` comes
  before `SharedFolderQuestion`.
- **Point 5:** silent and `/SUPPRESSMSGBOXES`: `Notice ... not shown` / `Question ... not asked ...,
  the installation continues` in the log, `CheckSelectedFolder` returns True. An exception in a
  check is logged and counts as nothing found.
- **Point 6:** `LowScreenResolution`, `ForeignInstallFound`, `ForeignFolderQuestion` and
  `SharedFolderQuestion` in English, German and French (111 custom messages).
- **Read-only:** `environment.iss` contains none of `RegWrite`, `RegDelete`, `DeleteFile`, `DelTree`,
  `RenameFile`, `Exec`, `SaveString` (grep), and no `Sierra\CDKeys`.
- **Tests:** 113 new unit tests, 543 in all (the screens 1024x600, 1366x768, 1920x1080, 2560x1440
  and every limit with its neighbours, `C:\Sierra2` against `C:\Sierra`, community AppIds and
  publishers, Empire Earth II/III, drive roots, UNC paths, umlauts); 4 new self-test cases of
  `ci/check_contract.py` (64). Test plan block 6: TP-60 to TP-63.
- **Wine probe** (analysis only, not in the repository): a small probe setup with `utils.iss`,
  `extension.iss` and `environment.iss` unchanged and the four messages cut out of `messages.iss`,
  in a new 64-bit and a new 32-bit Wine prefix, test keys and entries created with `reg add`
  (removed again), no network. Results: the screen line at 1024x600, 1366x768 and 1920x1080 (96 DPI);
  the low-screen notice in German and French, none when silent; with nothing installed `No foreign
  or old installation`; in the 64-bit prefix both views are read (`Checked 5 uninstall entries`, 3 in
  HKLM64 and 2 in HKLM32, `WOW6432Node` in the names of the 32-bit view), in the 32-bit prefix one;
  a community entry with another AppId, an entry with the other product's AppId and `Empire Earth II`
  are not reported, the GOG and the old NeoEE entry are; `C:\Sierra` and the GOG folder lead to
  `ForeignFolderQuestion`, `C:\Sierra2` does not; the `App Path` of the other product's uninstall key
  and its `_setupdata_NeoEE` folder lead to `SharedFolderQuestion`; silent runs install. Driven by key
  presses and clicks in German: the notice once, the question, "Yes" (`NextButtonClick` False, still
  on the folder page), Next again (the question, no second notice), "No", installation succeeded.
- **Real-data comparison** (local only, nothing committed): EE and NeoEE built from the reconstructed
  1.7.2 data at `1e1e8ee` against the S-WP7 builds at `4eafaed`: only the compiled code (EE 148571 ->
  170389 bytes, NeoEE 153282 -> 175116 bytes) and the 12 new messages (4 messages in English, German,
  French) differ; `[Files]`, `[Registry]`, `[Run]`, `[UninstallRun]`, `[InstallDelete]` and all
  other sections and the data are identical.
- **Open:** whether `authtools.dll` writes `HKLM\Software\Neo` when it registers the CD keys is unknown
  (contract O8); TP-61 (e) checks it before a release. Whether the launcher should also list the
  HKLM `Neo` keys with the advice it gives for the SSSI and Mad Doc keys (export first, never
  `Software\Sierra` or one of its parents) is a question for the launcher; the notice of the setup
  does not depend on it (point 2).

## Alternatives considered

- **Offer to delete leftovers:** irreversible, risks `Software\Sierra\CDKeys` and player data; the
  launcher's cleanup with `.reg` backup (contract 3.8) is the right place.
- **Block the installation:** the old installation may be wanted.
- **Only a notice for the retail/GOG folder:** too weak for the one case that mixes files and lets the
  uninstaller delete files of another installation.
- **Check at start instead of at the folder page:** the chosen folder is unknown then, so the shared
  folder case and own "Installed From" values could not be told apart.

## Amendment 2026-10-07 (setup 1.1.0: game window up to 1200 high, the wide-screen limit)

Point 1 ("The clamp of the window size (1024 to 1920 x 768 to 1080) stays") is superseded: the height limit is 1200, and on
a screen wider than 1920 the height is in addition at most the larger of 1080 and the screen height scaled to the width 1920
(`WideScreenGameWindowHeight`, `GameWindowHeight` in `utils.iss`, contract 3.3 revision 6). Why: the test laptop is 1920 x
1200, and a game window of the size of the screen needs no display mode change (ADR 0005, amendment 2026-10-07). The limit
for wide screens keeps what revision 5 gave them: a limit of 1200 per dimension would turn every 2560 x 1440 and 4K screen
(16:9) into a 16:10 window of 1920 x 1200. Examples: 1920 x 1200 gives 1920 x 1200, 1600 x 1200 stays, 2560 x 1600 and
3840 x 2400 give 1920 x 1200, 2560 x 1440, 3840 x 2160, 3440 x 1440 and 2560 x 1080 give 1920 x 1080, everything up to 1080
high is unchanged. Evidence: the unit tests (`TestGameWindow`, including a sweep over wide screens), rule 3.3 of
`ci/check_contract.py` with its mutants, the end-to-end check K5, TP-26; the forum crash reports are about 2560-wide modes,
empireearth.eu names 1920x1200 as the upper limit.
