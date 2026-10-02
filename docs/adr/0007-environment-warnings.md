# 0007. Read-only warnings for low resolution, foreign installations and a shared EE/NeoEE folder

- Status: Accepted (implemented by S-WP5)
- Date: 2026-10-02
- Requirements: R12, R13, contract question O11

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
  removes files of the other (contract 1.4 and O11).

## Decision

All checks are **read-only**: they never delete, move or change anything, and they never block a
silent installation (silent: log only).

1. **Low resolution (R13):** if the height of the primary screen (`GetSystemMetrics(SM_CYSCREEN)`,
   physical pixels, see ARCHITECTURE O4) is below 768, `InitializeSetup` shows a notice after the
   install-mode question: the menus of the game need 768 pixels, the window is set to 1024x768, the
   game may not fit or may crash after the intro; scaling in the graphics driver or a DirectX wrapper
   can help. The clamp of the window size (1024 to 1920 x 768 to 1080) stays. The predicate and the
   clamp become pure, unit-tested functions in `utils.iss` (`ClampGameWindowWidth/Height`,
   `IsScreenTooLow`).
2. **Foreign or old installations (R12):** when the user leaves the folder page, the setup looks
   for, in this order:
   - `Software\SSSI\Empire Earth` and `Software\Mad Doc Software\EE-AOC` in HKLM, 32- and 64-bit
     view (community setups write these keys only in HKCU, retail, GOG and old patches in HKLM;
     contract 1.4 source 4);
   - the folders `<system drive>\Sierra\Empire Earth` and `{commonpf32}\Sierra\Empire Earth` (default
     folder of the retail CD, t=5825 p=39087, t=5571 p=37625);
   - where available, the folder named by the "Installed From" values of these HKLM keys, shown in
     the notice (not those of HKCU: the community setups write them there for their own
     installations).

   Findings are shown once as a notice: what was found, that the community setup installs its own
   copy and does not change the other one, that a manual cleanup of old registry keys must keep
   `Software\Sierra\CDKeys` (NeoEE CD keys), and that the launcher can help later. Nothing is
   offered for deletion. Community installations (uninstall keys with the community publishers) are
   not reported.
3. **Shared folder (O11):** when the user leaves the folder page and the chosen folder already holds
   the other product (`_setupdata_<other product>` exists, or the other product's uninstall key has
   this folder as `Inno Setup: App Path`, which also finds 1.7.2 installations), a Yes/No question
   explains the consequences and recommends another folder; "Yes" (default) stays on the folder
   page, "No" continues.
4. The folder-page checks only run when the page is shown: an update in place keeps the previous
   folder (`UsePreviousAppDir`), whose state was checked at the first installation.
5. New texts in English, German and French; every finding is logged.

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

## Alternatives considered

- **Offer to delete leftovers:** irreversible, risks `Software\Sierra\CDKeys` and player data; the
  launcher's cleanup with `.reg` backup (contract 3.8) is the right place.
- **Block the installation:** the old installation may be wanted.
- **Check at start instead of at the folder page:** the chosen folder is unknown then, so the shared
  folder case and own "Installed From" values could not be told apart.
