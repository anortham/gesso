# COPR packaging

Gesso ships as COPR RPMs for Fedora 44. The spec is `packaging/gesso.spec`. This file is the human checklist. The repo does not create the COPR or upload RPMs.

`<owner>` is a placeholder until someone creates the project. Do not invent a COPR user.

## Packages

`dnf install gesso-plasma` is the user-facing install. It pulls `gesso`. `gesso-agents` is optional and pulls `mise`.

| Package | What it is |
|---|---|
| `gesso` | CLI, themes, templates, catalogs. Bash `gesso-setup` stays in `/usr/bin`. |
| `gesso-plasma` | Kirigami Setup at `/usr/libexec/gesso/gesso-setup` and the desktop file |
| `gesso-agents` | Metapackage that requires `mise` |

There is no `/etc` payload. There is no `environment.d` file. The router sets `$GESSO_PATH=/usr/share/gesso` when the checkout probe fails.

## Create the COPR (human)

1. Create a COPR project named `gesso` for Fedora 44.
2. Point that project at this repository and `packaging/gesso.spec`.
3. Build the packages for Fedora 44.
4. Confirm the three RPMs exist: `gesso`, `gesso-plasma`, `gesso-agents`.

## Enable and install

```bash
dnf copr enable <owner>/gesso
dnf install gesso-plasma
```

Then run `gesso setup` or `gesso theme list` from a Fedora KDE 44 session.

Optional:

```bash
dnf install gesso-agents
```

## Uninstall

If Gesso is the active color scheme, restore Breeze first:

```bash
gesso theme restore
dnf remove gesso-plasma gesso
```

`gesso theme restore` applies `BreezeDark` or `Breeze` from the last theme `mode`. It does not delete `~/.config/gesso` or `~/.local/state/gesso`. RPM `%preun` and `%postun` do not call restore.

## Tests

`./test/cli` reads the spec text. It does not run `rpmbuild`, `mock`, or `copr-cli`.
