# Releasing the suite

How a version of the suite installer "Empire Earth Community" is released, from the last merge to the package that
players download. Work through it top to bottom; every box is one step.

Background in one paragraph: this repository publishes no installer. A release here is a **tag** `suite-vX.Y.Z` on
`main` with release notes and no binaries. The product setups (EE and NeoEE) have no release of their own: they ship
inside the suite and keep the setup version 1.7.2 (`MySetupVersion`, [ARCHITECTURE.md](ARCHITECTURE.md), section 10);
their builds are told apart by their `SetupBuild`. The suite is built locally from the tag with the private inputs (the
game data, the real AppIds, the launcher of its own release) and goes into the package
[Empire Earth Community](https://github.com/DritteRippe/Empire-Earth-Community/releases/latest), which is where players
get it. The launcher is released first, by the [checklist of the launcher repository](https://github.com/DritteRippe/Empire-Earth-Launcher/blob/main/docs/RELEASING.md).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

| Step | Where | Result |
|---|---|---|
| [1. Ready to release?](#1-ready-to-release) | this repository, the laptop | the scope and the tests are clear |
| [2. Version commit](#2-version-commit) | a release branch | every file names the new version |
| [3. Merge and a green build](#3-merge-and-a-green-build) | `main` | a commit with a green run of *Build* |
| [4. Tag](#4-tag) | `main` | `suite-vX.Y.Z` on exactly that commit |
| [5. Build the suite](#5-build-the-suite) | a Windows computer with the private inputs | `out\Suite\` with `SHA256SUMS.txt` and `BUILD-INFO.txt` |
| [6. Release notes](#6-release-notes) | GitHub *Releases* | the release page of the tag |
| [7. The package](#7-the-package) | the package repository | the release that players download |
| [8. After the release](#8-after-the-release) | all three repositories | the record, the pins, the next `## Unreleased` |

## 1. Ready to release?

- [ ] Every change of the version is merged into `main`, and `## Unreleased` of [CHANGELOG.md](../CHANGELOG.md) lists
      it in the right category (Added, Changed, Fixed, Security, ...).
- [ ] The release criterion of the [test plan](TEST-PLAN.de.md) (section 8, Block 9, "Freigabekriterium") is met on
      real hardware: for suite 1.1.1 the criterion of 1.1.0 (TP-93, TP-94 (c), TP-95, TP-97, TP-98, TP-99 with all
      variants, TP-25 (a) to (d), TP-27 (a)) with the job `suite-e2e` from S1 to S15. Every result goes into the record of
      section 10 of the test plan. Releasing with cases that did not run is a decision of the maintainer; it is then
      written into the test plan (Block 9), the README ("Empire Earth Community suite installer") and the introduction
      of the version in the CHANGELOG, case by case, as for 1.1.0.
- [ ] The servers: [TP-00](TEST-PLAN.de.md#tp-00-server-vorabprüfung) finds a file server that serves the pinned files,
      and `pins/online-files.txt` matches it ([SERVER-OPERATIONS.md](SERVER-OPERATIONS.md), sections 5 and 6). A
      mismatch is a release blocker on the server side.
- [ ] The launcher version that the suite packages is released (its tag `vX.Y.Z` exists and has a green build).
- [ ] [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) matches the shipped components and their versions (dgVoodoo:
      `DgVoodooVersion` and `pins/dgvoodoo.txt`; BASS).
- [ ] If the version completes a revision of [CONTRACT.md](CONTRACT.md): both copies and the byte samples are identical
      (`python ci/compare_contract.py <launcher clone>`), and the launcher releases its part at the same time.

## 2. Version commit

On a short-lived branch (for example `release/suite-1.1.1`), one commit "Set the suite version to X.Y.Z" that changes
every place with the version number:

| File | What changes | For 1.1.1 |
|---|---|---|
| `suite/suite.iss` | `#define SuiteVersion` (the version resource of the setup program, the version of its entry in Windows "Apps", the suite record and the first log line take it from there; `suite\build_suite.ps1` writes it into `BUILD-INFO.txt`) | `1.1.1` |
| `setup_is6.iss` | nothing: `MySetupVersion` stays `1.7.2` until the update API is ready for another version | stays |
| `README.md` | "Status" (the released suite version and its tag), "Empire Earth Community suite installer" (the criterion and what ran), the `-SetupBuild` example in "Build switches", "Build script" and "Suite build script" | 1.1.1 |
| `docs/ARCHITECTURE.md` | section 11 (the criterion and what ran) | 1.1.1 |
| `docs/TEST-PLAN.de.md` | Block 9: the record of the release and the criterion of the next version | 1.1.1 |
| `docs/CONTRACT.md` | only when a revision is released with it: the row of the revision in the history (the tags instead of "(planned)") and the row "Status", in both repositories at once | revision 7 |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | the example of the version | Package 1.1.1 (suite 1.1.1, launcher 1.1.1) |

Then a second commit "Document suite X.Y.Z as released in the CHANGELOG and the README":

- [ ] `## Unreleased` becomes `## Suite X.Y.Z - YYYY-MM-DD` with a short introduction (what the version is for, the
      launcher it packages, what ran on real hardware), and a new empty `## Unreleased` goes above it. **The date is the
      day of the tag**, not the day the number was set.
- [ ] The README status says what is released and what ran on real hardware.

Run the checks the change touches before you push (README, [Verify](../README.md#verify)); `ci/check_test_plan.py`
checks every test case id the documents name.

## 3. Merge and a green build

- [ ] Open a pull request from the release branch into `main`. Merge it with a **merge commit**, not with squash or
      rebase: `docs/CONTRACT.md` ("Based on") names commits that must stay on `main`.
- [ ] The push to `main` starts the workflow *Build*. Wait until its run for exactly the merge commit is green in
      **every job**: `compile` (the checks, the unit tests, the build of all variants and of the placeholder suite) and
      `suite-e2e` (the scenarios S1 to S15).
- [ ] A red run is never "probably flaky": find the cause and fix it in a new commit, then wait for its green run.

> [!IMPORTANT]
> **Tags do not start a build** (`build.yml` runs for pushes to `main`, pull requests and by hand). Only tag a commit
> that has a complete green run of *Build* on `main`. Suite 1.1.0 was published while the only finished run on its
> commit was red (run 48); the green run 49 came from the tag itself, which no longer starts a run.

## 4. Tag

```sh
git fetch origin
git switch --detach <merge commit with the green run>
git tag -a suite-vX.Y.Z -m "Empire Earth Community (Suite) X.Y.Z"
git push origin suite-vX.Y.Z
```

- Tags are named `suite-vX.Y.Z` (`suite-v1.0.0`, `suite-v1.1.0`). Annotated tags (`-a`, or `-s` to sign) carry the
  date and the person who tagged; the tags up to `suite-v1.1.0` are lightweight.
- **A published tag is never moved or deleted.** A mistake after the tag gets a new patch version. The package names
  the tag and its commit as the source of the setups (`Quellcode.txt`, `BUILD-INFO.txt`).
- `main` is never rewritten either (no force push).
- The settings of the repository enforce both once they are switched on (see
  [Protection of main, the tags and the releases](#protection-of-main-the-tags-and-the-releases)).

## 5. Build the suite

On Windows with Inno Setup 6.2.2, in a clean checkout of the tag, with the private inputs (README,
[Assets](../README.md#assets) and [Suite build script](../README.md#suite-build-script)). The result contains game data:
it is never committed, never attached to a release of this repository and never uploaded to a public place.

```powershell
git switch --detach suite-vX.Y.Z
git status --porcelain            # must print nothing, or BUILD-INFO.txt says "with uncommitted changes"
# 1. the product setups, release builds (TestID 0) with the official AppIds and the SetupBuild of this release
.\ci\build.ps1 -EEAppID <GUID> -NeoEEAppID <GUID> -Variants EE/Regular,NeoEE/Regular -SetupBuild suite-X.Y.Z-<short commit> -RequireVersion 6.2.2
# 2. the suite, from those setups and the launcher release
.\suite\build_suite.ps1 -SuiteAppID <GUID> -EEAppID <GUID> -NeoEEAppID <GUID> `
  -EESetup out\EE_Regular\<EE setup>.exe -NeoEESetup out\NeoEE_Regular\<NeoEE setup>.exe `
  -LauncherDir <launcher output> -ModCreatorDir <mod creator output> -LicenseDir <license folder> `
  -LauncherCommit <full commit of the launcher tag> -ModCreatorCommit <full commit of the launcher tag> -RequireVersion 6.2.2
```

- [ ] Step 1 writes `<setup>.exe.sha256` and `<setup>.exe.setupbuild` next to each setup; step 2 refuses a release build
      without a `SetupBuild` record or with a record of other bytes. A release build also stops on a missing or wrong pin
      of an online file and on dgVoodoo files that are not those of `pins/dgvoodoo.txt`.
- [ ] The license folder holds `LICENSE`, `THIRD-PARTY-NOTICES.md` and `licenses\` of the launcher **at its tag**, and the
      `Quellcode.txt` of the package, which names both repositories with their tags and commits, never a branch.
- [ ] `out\Suite\BUILD-INFO.txt`: `Empire Earth Community Setup X.Y.Z`, `Setup repository:` the commit of the tag
      without "uncommitted changes", the launcher and mod creator commits of the launcher tag,
      `ISCC: 6.2.2`, `Build kind: release build (TestID 0)`, `Product SetupBuild: EE suite-X.Y.Z-..., NeoEE
      suite-X.Y.Z-...`.
- [ ] `out\Suite\SHA256SUMS.txt` lists the setup program and every slice; every file is at most 50,000,000 bytes.
- [ ] Run the cases of step 1 that need the built package (Block 9) with exactly these files, if they did not run
      with them already.

## 6. Release notes

*Releases* > *Draft a new release*, choose the tag `suite-vX.Y.Z`, title `Empire Earth Community (Suite) X.Y.Z`:

- [ ] The notes say what the version is for, which launcher it packages and where players get it: the package release
      page.
- [ ] **No branch names.** Branches are deleted after the merge (the notes of 1.1.0 pointed to the branch `v2`, which is
      gone). Link the tag, its commit or a file at the tag, for example
      `https://github.com/DritteRippe/Empire-Earth-Setup/blob/suite-vX.Y.Z/CHANGELOG.md`.
- [ ] Say what ran on real hardware and what did not, and which CI run was green for the commit (its number).
- [ ] No binaries are attached: the suite contains game data and ships only in the package.
- [ ] *Set as the latest release*, then *Publish release*.

A template:

```markdown
Empire Earth Community (Suite) X.Y.Z is the suite installer "Empire Earth Community Setup" X.Y.Z: one setup that
installs Empire Earth with The Art of Conquest and Neo Empire Earth by running the EE and NeoEE setups of this
repository, together with Empire Earth Launcher X.Y.Z (tag `vX.Y.Z` of Empire-Earth-Launcher) and the Mod Creator.
The product setups keep the setup version 1.7.2; their builds carry the SetupBuild `suite-X.Y.Z-<commit>`.

**Players:** get it with the package: https://github.com/DritteRippe/Empire-Earth-Community/releases/latest

### Main changes
- ...

### Testing
- Laptop: ...
- CI: run <number> of *Build* on <commit>, every job green (scenarios S1 to S15).

### Downloads
No binaries are attached. The suite embeds the game setups and their game data, so it ships only in the package.
Source code: this tag (commit <full SHA>), GPL-3.0.

All changes: [CHANGELOG at suite-vX.Y.Z](https://github.com/DritteRippe/Empire-Earth-Setup/blob/suite-vX.Y.Z/CHANGELOG.md).
```

## 7. The package

The package "Empire Earth Community" is released last, in its own repository, after the launcher and the suite:

- [ ] It contains the files of `out\Suite\` unchanged, with `SHA256SUMS.txt` and `BUILD-INFO.txt` of this build.
- [ ] Its README, `LIES-MICH.txt` and CHANGELOG name the suite and launcher versions and commits; `Quellcode.txt` names the
      tags, never a branch.
- [ ] Its release becomes the page that the launcher's repair advice and "Open release page" open, and that the
      Support and Updates links of the suite's entry in Windows "Apps" lead to (`releases/latest`).

## 8. After the release

- [ ] The test plan (Block 9 and the record of section 10), the README status and the CHANGELOG introduction say what
      ran on real hardware.
- [ ] Delete the release branch.
- [ ] Move `LAUNCHER_COMMIT` in `.github/workflows/e2e-realdata.yml` to the commit of the launcher tag that the suite
      packages (it must be on the launcher's `main`), so that the real-data test runs the checks of the released
      launcher.
- [ ] The description of the repository (*About*) names no branch and no outdated state.
- [ ] Anything left for the next version goes under `## Unreleased`.

## Protection of main, the tags and the releases

The rules above (never rewrite `main`, never move or delete a tag, never change a published package) are what the
contract ("Based on"), `Quellcode.txt` and the end-to-end pins rely on. The maintainer enforces them in the settings of
the repository:

| Setting | Where | What it does |
|---|---|---|
| Branch ruleset `main` | *Settings* > *Rules* > *Rulesets* > *New branch ruleset* | `main` cannot be deleted or force-pushed; a change needs a pull request with a green *Build* |
| Tag ruleset `suite-v*` | *Settings* > *Rules* > *Rulesets* > *New tag ruleset* | a release tag cannot be moved or deleted |
| Immutable releases | *Settings* > *General* > *Releases* | the tag and the assets of a published release can no longer change |

## What is pinned on purpose

| Pin | Where | Moved by |
|---|---|---|
| Inno Setup 6.2.2 | `build.yml` (Chocolatey), `-RequireVersion 6.2.2`, [ADR 0002](adr/0002-stay-on-inno-setup-6.2.2.md) | a new ADR |
| The online files (SHA-256 and size) | `pins/online-files.txt` | `ci/online_pins.ps1 -Update` after a change on the servers ([SERVER-OPERATIONS.md](SERVER-OPERATIONS.md), section 6) |
| dgVoodoo | `pins/dgvoodoo.txt`, `DgVoodooVersion`, the `Version` line of the five configurations | by hand, all together, then `ci\dgvoodoo_pins.ps1` and TP-25 (README, [Assets](../README.md#assets)) |
| The product setups in the suite (SHA-256 and size) | compiled in by `suite\build_suite.ps1` from `<setup>.exe.sha256` | every build |
| GitHub Actions (commit SHA with the version as a comment) | `.github/workflows/*.yml` | Dependabot, one grouped pull request a month |
| The launcher commit of the real-data test | `LAUNCHER_COMMIT` in `.github/workflows/e2e-realdata.yml` | a commit here (step 8) |
| The official setups 1.7.2 and innoextract of the real-data test | `OFFICIAL_*_SHA256`, `INNOEXTRACT_COMMIT` in `.github/workflows/e2e-realdata.yml` | by hand, with a reason |
| The commits of the contract | "Based on" in `docs/CONTRACT.md` (both copies) | a contract revision |
