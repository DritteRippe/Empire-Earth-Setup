# Contributing to Empire Earth Community Setup

Thank you for helping! This project is maintained by volunteers for the Empire Earth community. Reports, tests on real
Windows computers, translations and code are all welcome.

> [!NOTE]
> Just want to play? You do not need this repository: the package
> [Empire Earth Community](https://github.com/DritteRippe/Empire-Earth-Community/releases/latest) installs the games
> and the launcher. Questions about the package go to its
> [issues](https://github.com/DritteRippe/Empire-Earth-Community/issues).

## Ways to help

| You want to ... | Go to |
|---|---|
| Report a bug of the setups or the suite installer | [New issue](https://github.com/DritteRippe/Empire-Earth-Setup/issues/new/choose) (the form asks for the logs; see [Support](README.md#support)) |
| Report a bug of the launcher or the mod creator | [Empire-Earth-Launcher issues](https://github.com/DritteRippe/Empire-Earth-Launcher/issues) |
| Report a security problem | **Privately**, see [SECURITY.md](SECURITY.md), never in a public issue |
| Test on a real Windows computer | The German [test plan](docs/TEST-PLAN.de.md): section 7 is the short run before a release, Block 9 the cases of the suite. Still open from suite 1.1.0: TP-93, TP-95, TP-97, TP-98 (b) to (d), TP-99 and TP-25 (d) |
| Translate the setup | [TRANSLATING.md](TRANSLATING.md) (Brazilian Portuguese, Traditional Chinese, and every text added after 1.7.2 in the languages other than English, German and French) |
| Change code or documentation | Read on |

For a larger change, please open an issue first, so that we can agree on the approach before you invest the time.

## Before you start

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (sections 1 to 3) and skim the
[decision records](docs/adr/README.md). The rules that matter most:

- **Inno Setup 6.2.2 and Pascal Script** ([ADR 0001](docs/adr/0001-keep-inno-setup-and-pascal-script.md),
  [ADR 0002](docs/adr/0002-stay-on-inno-setup-6.2.2.md)): no feature of a newer Inno Setup, all variables in the `var`
  block, no generics. CI compiles with exactly 6.2.2.
- **The own `.iss` files are UTF-8 with BOM and CRLF**: Inno Setup 6.2 reads a file without BOM as ANSI
  ([Conventions](README.md#conventions)). `ci/check_messages.py` finds a missing BOM or a wrong line end.
- **No game data in this repository**, ever: `data\` and the media folders are in `.gitignore`, and a placeholder build
  is all you need ([Contributing without the game data](README.md#contributing-without-the-game-data)). Never commit,
  upload or attach game files, CD keys or the package.
- **Downloads only over HTTPS, every online file pinned by its SHA-256**
  ([ADR 0012](docs/adr/0012-pinned-downloads-despite-invalid-certificates.md)). The suite installer downloads nothing at
  all; `ci/check_tls_policy.py` enforces both.
- **Nothing ever touches `Software\Sierra\CDKeys`**, the NeoEE CD keys.
- **Elevated code is security code.** An installation for all users runs as administrator in folders that every user
  may change: read [ADR 0009](docs/adr/0009-no-installation-through-links.md) before you touch the link check, the
  uninstaller or any deletion.
- **What the setup leaves for the launcher** is specified in [docs/CONTRACT.md](docs/CONTRACT.md) and its byte samples
  `docs/contract-samples`. Both exist identically in the
  [launcher repository](https://github.com/DritteRippe/Empire-Earth-Launcher); a change of them is one change in both
  repositories (same text, same commit subject), checked with `python ci/compare_contract.py <launcher clone>`.
- **Every new message in English, German and French** at least (`messages.iss`, `suite/suite_messages.iss`; the suite
  has exactly these three). The other languages fall back to English until a translator helps
  ([TRANSLATING.md](TRANSLATING.md)).

## Workflow

1. Fork the repository and create a short-lived branch from `main` (for example `fix/uninstall-link-check`).
2. Make the change, with tests (see below) and the documentation it touches.
3. Run the local checks.
4. Open a pull request into `main`. The template asks for what and why, the checks and the docs.
5. The CI workflow *Build* runs every check, compiles all variants with Inno Setup 6.2.2 and runs the end-to-end
   scenarios of the suite on Windows (job `suite-e2e`). A pull request is merged only with a green build, with a
   merge commit.

`main` is never rewritten (no force push, no rebase of published commits): the contract names commits of `main` in
"Based on", and the release tags point into it.

## Local checks

Most checks need neither Windows nor Inno Setup. Run the ones your change touches; CI runs all of them, with
`PYTHONWARNINGS=error::SyntaxWarning`:

```sh
python ci/check_messages.py            # messages, BOM and CRLF of every own script
python ci/check_test_plan.py           # the German test plan and every test case id the docs name
python ci/check_contract.py            # the tables of the contract against the script
python ci/check_suite.py               # the frame of the suite installer
python ci/check_suite_texts.py         # the legal texts the suite shows
python ci/check_tls_policy.py          # certificate errors only for pinned files, no network code in the suite
python -m unittest discover -s ci/e2e/tests -p "test_*.py"
pwsh ci/online_pins.ps1                # the pins of the online files
pwsh ci/dgvoodoo_pins.ps1              # the dgVoodoo pins and configurations
pwsh ci/tests/build_helpers.tests.ps1  # the build script, with a fake ISCC
pwsh ci/tests/suite_build.tests.ps1    # the suite build script, with a fake ISCC
```

Every Python check has a `--self-test` and every PowerShell check a `-SelfTest`; run it when you change the check
itself. On Windows with Inno Setup 6.2.2:

```powershell
powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders   # all four variants compile
powershell -ExecutionPolicy Bypass -File ci\run_unit_tests.ps1        # the unit tests of the [Code] helpers
```

The complete list, with what each check covers, is in the README section [Verify](README.md#verify).

- A helper that only computes something belongs into `utils.iss` (or `suite/suite_common.iss`) with a unit test in
  `ci/tests/unit_tests.iss` (or `ci/tests/suite_tests.iss`) ([Unit tests](README.md#unit-tests)).
- A rule that no compiler checks (a flag, an order, who may call what) gets a rule in the matching check with a
  mutant in its self-test that must fail.
- What only a real Windows computer can show gets a case in the German [test plan](docs/TEST-PLAN.de.md); a case id that
  a document names must exist there (`ci/check_test_plan.py`).
- The installers never run on your own computer by script: the end-to-end tests run on throwaway GitHub runners
  ([Testing on Windows](README.md#testing-on-windows)).

## Commits

- English, one logical change per commit.
- Subject in the imperative, often with the area first, for example
  `Suite: check each user data folder for links again right before it is deleted` or
  `CI: pin every action by its commit`.
- The body explains what changed and why: the problem, the cause, the decision and how it is tested.

## Changelog and documentation

- Every change that a player or a developer notices gets an entry under `## Unreleased` in
  [CHANGELOG.md](CHANGELOG.md), in the category where a reader looks for it (*Added*, *Changed*, *Removed*, *Fixed*,
  *Security*, *Internal*; [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)).
- Keep the README, [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the test plan in step with the code. A decision gets
  a new ADR; a refinement of an accepted one gets a dated *Amendment* section (rules in
  [docs/adr/README.md](docs/adr/README.md)).

## License

By contributing you agree that your contribution is licensed under the
[GNU General Public License v3.0](LICENSE), like the rest of the setup scripts.

Please be friendly and patient with each other: everybody here gives their free time to an old game they love.
