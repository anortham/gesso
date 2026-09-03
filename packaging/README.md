# COPR packaging

Gesso ships as COPR RPMs for Fedora 44. The spec is `packaging/gesso.spec`. This file is the human checklist. The repo does not create the COPR or upload RPMs.

`<owner>` is a placeholder until someone creates the project. Do not invent a COPR user.

## Packages

`dnf install gesso-plasma` is the user-facing install. It pulls `gesso`. There is no `gesso-agents` package. `mise` is not a Fedora package, so `gesso default agent` installs it per user into `~/.local/bin/mise` on first use.

| Package | What it is |
|---|---|
| `gesso` | CLI, themes, templates, catalogs. Bash `gesso-setup` stays in `/usr/bin`. |
| `gesso-plasma` | Kirigami Setup at `/usr/libexec/gesso/gesso-setup` and the desktop file |

There is no `/etc` payload. There is no `environment.d` file. The router sets `$GESSO_PATH=/usr/share/gesso` when the checkout probe fails.

## Create the COPR (human)

Do these steps in order after the branch lands. Do not tag from this branch.

1. Merge this branch.
2. Tag `v0.1.0` on that commit.
3. Create a COPR project named `gesso` for Fedora 44. Point it at this repository and `packaging/gesso.spec`.
4. Build the packages for Fedora 44 and confirm the two RPMs exist: `gesso`, `gesso-plasma`.
5. Replace `<owner>` in README and docs.

## Enable and install

```bash
dnf copr enable <owner>/gesso
dnf install gesso-plasma
```

Then run `gesso setup` or `gesso theme list` from a Fedora KDE 44 session.

Coding agents need `mise`. `gesso default agent <id>` installs it per user with the official installer when it is missing. No RPM pulls it.

## Uninstall

If Gesso is the active color scheme, restore Breeze first:

```bash
gesso theme restore
dnf remove gesso-plasma gesso
```

`gesso theme restore` applies `BreezeDark` or `BreezeLight` from the last theme `mode`. It does not delete `~/.config/gesso` or `~/.local/state/gesso`. RPM `%preun` and `%postun` do not call restore.

## Tests

`./test/cli` reads the spec text, the desktop file, and `.github/workflows/ci.yml`. It does not run `rpmbuild`, `mock`, or `copr-cli`.

GitHub Actions runs `./test/all` and a cmake build of `setup/` in a `registry.fedoraproject.org/fedora:44` container on every push and pull request. See `.github/workflows/ci.yml`.
