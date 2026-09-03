# Packaging

v1 ships as COPR RPMs for Fedora 44. Not a remix, not a bootc image.

The spec is [`packaging/gesso.spec`](../packaging/gesso.spec). Human COPR steps are in [`packaging/README.md`](../packaging/README.md).

## RPMs

| Package | Contents | Requires |
|---|---|---|
| `gesso` | `bin/gesso*`, `themes/`, `default/`, `data/` | bash, python3, xdg-utils. Recommends plasma-workspace, libnotify, flatpak |
| `gesso-plasma` | `/usr/libexec/gesso/gesso-setup`, desktop file | `gesso`, kf6-kirigami, qt6-qtdeclarative, kf6-qqc2-desktop-style |

`dnf install gesso-plasma` is the user-facing install. It pulls `gesso`. Agent scripts live in `gesso`. There is no `gesso-agents` package. `mise` is not a Fedora package, so no RPM can Require it. `gesso default agent` installs `mise` per user into `~/.local/bin/mise` on first use with `curl -fsSL https://mise.run`.

Every `BuildRequires` and `Requires` name exists in Fedora 44. `qt6-qtdeclarative-devel` provides QuickControls2, so the spec does not list `qt6-qtquickcontrols2-devel`.

## Install paths

See [`layout.md`](layout.md). Data goes to `/usr/share/gesso`. Binaries go to `/usr/bin`. The Kirigami binary goes to `/usr/libexec/gesso/gesso-setup`. The bash launcher stays `/usr/bin/gesso-setup` and execs that path. User state stays in `$HOME`.

Do not ship `/etc` or `environment.d`. The router sets `$GESSO_PATH=/usr/share/gesso` when the env var is unset and the checkout probe fails.

## Uninstall

If Gesso is the active color scheme, run `gesso theme restore` before `dnf remove gesso-plasma gesso`. Restore applies `BreezeDark` or `BreezeLight` from the last theme `mode`, or `BreezeDark` if unknown. RPM scriptlets do not call restore.

`dnf remove gesso-plasma gesso` must leave Plasma usable.

- Do not delete `~/.config/gesso` or `~/.local/state/gesso` unless the user passes a documented purge command.
- Do not leave a broken default browser; XDG defaults pointing at a removed app are the user's problem only if they removed that app, not Gesso.

## Aurora / Kinoite

Same files. Do not write `/usr` except the RPM payload. Theme apply writes `~/.local/share`. Aurora is untested in v1. App install on Atomic hosts is Flatpak and `mise` only. v1 tests run on mutable Fedora KDE.

## COPR

Tag `v0.1.0` is a human step after merge. Do not create the tag from this branch. Then create the COPR for Fedora 44, build, and inspect the two RPMs. See [`packaging/README.md`](../packaging/README.md).

```bash
dnf copr enable <owner>/gesso
dnf install gesso-plasma
```

`<owner>` is a placeholder until someone creates the project. Do not invent an owner.

## CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs two jobs in a `registry.fedoraproject.org/fedora:44` container. Job `cli` installs `bash`, `python3`, `util-linux`, and `git`, then runs `./test/all`. Job `setup` installs the spec's `BuildRequires` list and runs `cmake -S setup -B build` and `cmake --build build`. Neither job runs `rpmbuild` or COPR.
