# Packaging

v1 ships as COPR RPMs for Fedora 44. Not a remix, not a bootc image.

## RPMs

| Package | Contents | Requires |
|---|---|---|
| `gesso` | `bin/gesso*`, `themes/`, `default/`, `data/` | bash, plasma-workspace (for `plasma-apply-colorscheme` at theme-set time; the CLI still runs without a session) |
| `gesso-plasma` | Setup app, desktop file | `gesso`, Kirigami/Qt6 |
| `gesso-agents` | agent catalog extras if any launch helpers are not in `gesso` | `gesso`, `mise` |

`dnf install gesso-plasma` is the user-facing install. It pulls `gesso`.

## Install paths

See [`layout.md`](layout.md). Data goes to `/usr/share/gesso`. Binaries to `/usr/bin`. User state stays in `$HOME`.

Provide `/usr/lib/environment.d/gesso.conf` with `GESSO_PATH=/usr/share/gesso` only if a session needs it; prefer the router defaulting to `/usr/share/gesso` when the env var is unset and the checkout probe fails.

## Uninstall

`dnf remove gesso-plasma gesso` must leave Plasma usable.

- If the active color scheme is `Gesso`, apply `BreezeDark` or `Breeze` according to the last `mode`, or BreezeDark if unknown.
- Do not delete `~/.config/gesso` or `~/.local/state/gesso` unless the user passes a documented purge command.
- Do not leave a broken default browser; XDG defaults pointing at a removed app are the user's problem only if they removed that app, not Gesso.

## Aurora / Kinoite

Same files. Do not write `/usr` except the RPM payload. Theme apply writes `~/.local/share`. App install on Atomic hosts is phase 5+ (Flatpak and `mise` only). v1 tests run on mutable Fedora KDE.

## COPR

Phase 5. Until then, `./bin/gesso` from a git checkout is the development install. Do not add a spec file before the CLI works.
