## What and why

<!-- What does this pull request change, and why? Link the issue if there is one ("Fixes #123"). -->

## Checks

- [ ] The checks the change touches pass locally (README, "Verify"), or the CI of this pull request is green
- [ ] Changed `.iss` files keep UTF-8 with BOM and CRLF, and they compile with Inno Setup 6.2.2 (`ci\build.ps1 -Placeholders` or the CI)
- [ ] New or changed behaviour has a unit test, a rule in a check or a case in the test plan, or the reason why not is written above
- [ ] New messages exist in English, German and French
- [ ] No game data, CD keys or package files in the diff, and no new download, network destination or deletion outside the rules of the ADRs

## Changelog and documentation

- [ ] `CHANGELOG.md`: an entry under `## Unreleased` (not needed for a change nobody notices)
- [ ] README, `docs/ARCHITECTURE.md`, ADRs and the test plan describe the change where it matters
- [ ] A change of `docs/CONTRACT.md` or `docs/contract-samples` is made in the launcher repository too, and `python ci/compare_contract.py <launcher clone>` says identical

See [CONTRIBUTING.md](https://github.com/DritteRippe/Empire-Earth-Setup/blob/main/CONTRIBUTING.md) for the details.
