# Packaging

v1 ships as COPR RPMs for Fedora 44. Not a remix, not a bootc image.

The spec is [`packaging/gesso.spec`](../packaging/gesso.spec). Human COPR steps are in [`packaging/README.md`](../packaging/README.md).

## RPMs

| Package | Contents | Requires |
|---|---|---|
| `gesso` | `bin/gesso*`, `themes/`, `default/`, `data/` | bash, python3. Recommends plasma-workspace |
| `gesso-plasma` | `/usr/libexec/gesso/gesso-setup`, desktop file | `gesso`, Kirigami/Qt6. Recommends `gesso-agents` |
| `gesso-agents` | no files (metapackage) | `gesso`, `mise` |

`dnf install gesso-plasma` is the user-facing install. It pulls `gesso`. It Recommends `gesso-agents`, so Fedora also pulls `mise` when Recommends are on. `gesso-agents` exists so `dnf install gesso-agents` pulls `mise`. Agent scripts already live in `gesso`. Do not hard-Require `gesso-agents` on `gesso-plasma`.

## Install paths

See [`layout.md`](layout.md). Data goes to `/usr/share/gesso`. Binaries go to `/usr/bin`. The Kirigami binary goes to `/usr/libexec/gesso/gesso-setup`. The bash launcher stays `/usr/bin/gesso-setup` and execs that path. User state stays in `$HOME`.

Do not ship `/etc` or `environment.d`. The router sets `$GESSO_PATH=/usr/share/gesso` when the env var is unset and the checkout probe fails.

## Uninstall

If Gesso is the active color scheme, run `gesso theme restore` before `dnf remove gesso-plasma gesso`. Restore applies `BreezeDark` or `Breeze` from the last theme `mode`, or `BreezeDark` if unknown. RPM scriptlets do not call restore.

`dnf remove gesso-plasma gesso` must leave Plasma usable.

- Do not delete `~/.config/gesso` or `~/.local/state/gesso` unless the user passes a documented purge command.
- Do not leave a broken default browser; XDG defaults pointing at a removed app are the user's problem only if they removed that app, not Gesso.

## Aurora / Kinoite

Same files. Do not write `/usr` except the RPM payload. Theme apply writes `~/.local/share`. Aurora is untested in v1. App install on Atomic hosts is Flatpak and `mise` only. v1 tests run on mutable Fedora KDE.

## COPR

```bash
dnf copr enable <owner>/gesso
dnf install gesso-plasma
```

`<owner>` is a placeholder until someone creates the project. Do not invent an owner. Creating and building the COPR is a human step. See [`packaging/README.md`](../packaging/README.md).
