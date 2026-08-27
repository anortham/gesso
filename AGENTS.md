# Gesso

A Fedora KDE add-on. One palette, install-then-set-default, and a coding-agent picker. Not a distro. Not Hyprland.

Read [`plans/2026-08-26-product.md`](plans/2026-08-26-product.md) for why. Read [`docs/layout.md`](docs/layout.md) for where files go. Phase 4 is done. Do not start phase 5 until `./test/all` is green.

## Start here (new session)

1. Product brief: `plans/2026-08-26-product.md`
2. This file
3. `docs/layout.md`, `docs/cli.md`, `docs/catalog.md`, `docs/theming.md`, `docs/testing.md`
4. Phase 4 is done (`plans/2026-08-27-phase-4.md`)
5. Do not start phase 5 until `./test/all` is green on this tree

Omarchy (`~/source/omarchy`) is a behavior reference. Steal ideas. Do not copy trees, names, Hyprland, or Quickshell.

## Style

- In markdown (`plans/`, `docs/`), write full lines. Break only at headings and list items.
- Two spaces for indentation, no tabs.
- Bash 5: `[[ ]]` for string/file tests, `(( ))` for numeric tests.
- In `[[ ]]`, do not quote variables. Do quote string literals (`[[ $branch == "dev" ]]`).
- Prefer a full `if`/`else` for two-path control flow.
- Quote paths with spaces. Do not escape spaces with `\ `.
- Shebangs: `#!/bin/bash` only.

## Commands

All commands start with `gesso-`. `bin/gesso` maps `gesso theme list` to `bin/gesso-theme-list`. See [`docs/cli.md`](docs/cli.md).

User-facing groups in v1: `theme`, `default`, `pkg`, `agent`, `setup`. Do not add a group until a command needs it.

Metadata lives in the first 80 comment lines of each `bin/gesso-*` file:

```bash
# gesso:summary=List installed Gesso themes
# gesso:args=
```

## Paths

- `$GESSO_PATH` is the install root (`/usr/share/gesso` when packaged). Commands must use it. Do not derive the root from `$HOME` or the script's location except for the router setting a repo-checkout default when `$GESSO_PATH` is unset and `bin/gesso` is running from a git checkout.
- Built-in themes and templates: `$GESSO_PATH/themes/`, `$GESSO_PATH/default/themed/`
- User overlays: `~/.config/gesso/`
- Generated state: `~/.local/state/gesso/`
- Runtime Plasma/Konsole/app files Gesso writes: `~/.local/share/` (so Kinoite/Aurora can use the same code)
- Never write to `/etc`

## Privilege

- `sudo` when the caller has a terminal that can take a password.
- `pkexec` when there is no TTY (Setup app, agent, systemd).
- Do not wrap a command that already elevates.

## Tests

See [`docs/testing.md`](docs/testing.md).

- `./test/cli` — router, metadata, theme list/set, default apps, pkg add, setup, and agent against a fake `$HOME`
- `./test/all` — runs `./test/cli` (more suites later)
- New command tests: `test/cli.d/<area>-test.sh`
- No Plasma, no DBus, no `dnf` in unit tests. Stub binaries on `PATH`.

## Hard no

- Hyprland, Quickshell as a desktop, a Fedora remix/ISO, `/etc` drop-ins, bootloader, NVIDIA, replacing plasmashell/Kickoff/Klipper
- Hard-coding app lists in QML; catalogs live in `data/`
- Vendoring Omarchy files

## Architecture

The CLI is the API. The Kirigami Setup app (phase 3) only execs `gesso-*`. Tests talk to the same binaries.

**Caller-facing interface:** `gesso <group> <name> [args]` and the matching `gesso-*` binary.

**Seams:** catalog TOML (`data/apps.toml`) for install/default; `colors.toml` plus templates for theming; `mise` for agents. Do not add a plugin host in v1.

**Architecture risk:** medium. The trap is growing a desktop shell. Keep Gesso a command pack plus one Setup window.
