# Security policy

## Supported versions

| Version | Supported |
|---|---|
| The latest suite release ([releases](https://github.com/DritteRippe/Empire-Earth-Setup/releases), tags `suite-vX.Y.Z`) and `main` | Yes |
| Older suite releases, and setups up to 1.7.2 of the upstream project | No, please update |

Fixes are published as a new suite release and reach players with the next package
[Empire Earth Community](https://github.com/DritteRippe/Empire-Earth-Community/releases/latest). The product setups have no
release of their own: they ship inside the suite.

## Reporting a vulnerability

Please do **not** report a security problem in a public issue, a pull request or a forum post.

Report it privately instead:
**[Report a vulnerability](https://github.com/DritteRippe/Empire-Earth-Setup/security/advisories/new)**
(the *Security* tab of this repository, GitHub private vulnerability reporting). Please include:

- the affected file, workflow or program, and the version or commit,
- the steps to reproduce it,
- what an attacker needs and what they gain.

Never attach game files, CD keys or the package.

If that link does not work for you, use the issue form
[Private contact for a security report](https://github.com/DritteRippe/Empire-Earth-Setup/issues/new?template=security_contact.yml).
It asks for no details, and a private way is arranged with you.

This is a volunteer project: you get an answer as soon as the maintainer can. If the report is confirmed, the fix comes
in a new release, and the advisory credits you if you wish.

## Scope

In scope: the code and the CI of this repository: the setup scripts (`*.iss`), the suite installer (`suite/`), the build
and test scripts (`ci/`), the workflows (`.github/`) and what they install or leave on a computer. The decisions behind
the checks are in [docs/adr](docs/adr/README.md); the README section [Security](README.md#security) lists what the setup
guards against and what it cannot cover.

Not in scope: the games themselves, third-party components (Inno Setup, dgVoodoo, BASS, dreXmod, NeoEE; see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)), the community's file servers and websites (their operators are the
contact, see [docs/SERVER-OPERATIONS.md](docs/SERVER-OPERATIONS.md)), the launcher (report that in the
[launcher repository](https://github.com/DritteRippe/Empire-Earth-Launcher/security)), and problems that need an
administrator who already controls the computer.

There is no bug bounty.
