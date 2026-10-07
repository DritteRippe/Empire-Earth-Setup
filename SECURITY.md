# Security policy

## Reporting a vulnerability

Report a vulnerability **privately**, not in an issue or a pull request: open the **Security** tab of this repository, choose **Report a vulnerability** and describe it there (GitHub private vulnerability reporting). If the button is not there, the maintainer has not switched it on yet; then open an issue that only says that you have a security report, without any detail, so that a private way can be arranged.

Say which file or workflow is affected, the version or commit, what an attacker needs and what they get, and how to reproduce it. Never attach game files, CD keys or the private package.

The project is maintained by volunteers, so there is no guaranteed response time; every report is read and answered as soon as possible.

## Supported versions

Only the latest release (the newest release tag on `main`) and the code on `main` get fixes. Older versions do not.

## Scope

In scope: the code and the CI of this repository: the setup scripts (`*.iss`), the suite installer (`suite/`), the build and test scripts (`ci/`), the workflows (`.github/`) and what they install or leave on a computer. The decisions behind the checks are in [docs/adr](docs/adr/README.md); the README section "Security" lists what the setup guards against and what it cannot cover.

Out of scope: the games themselves, third-party components (Inno Setup, dgVoodoo, dreXmod, NeoEE), the community's file servers and websites (their operators are the contact; see [docs/SERVER-OPERATIONS.md](docs/SERVER-OPERATIONS.md)), the separate launcher repository (report there), and problems that need an administrator who already controls the computer.

There is no bug bounty.
