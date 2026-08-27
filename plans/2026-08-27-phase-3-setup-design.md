# Phase 3 Setup app design

Date: 2026-08-27

Status: draft spec. Not an implementation plan. Implementation waits on this file's approval, then `plans/2026-08-27-phase-3.md`.

## Purpose

Gesso Setup is one Kirigami window. A Fedora KDE user can list themes, apply one, set the default browser, and install catalog apps with a mouse. Every action execs `gesso-*`. The CLI stays complete without the GUI.

## Constraints

- The CLI is the API (ADR-0002). QML and C++ must not install packages, parse `colors.toml`, or duplicate `data/apps.toml`.
- No hard-coded app ids, package names, or Flatpak ids in QML. Lists come from `gesso theme list` and `gesso-catalog-get`.
- No `/etc`. No Plasma, DBus, or `dnf` in `./test/cli`.
- There is no graphical acceptance suite in v1 (`docs/testing.md`). Tests cover the launcher, help, and a grep that QML does not embed catalog ids.
- Privilege: Setup has no TTY, so `gesso pkg add` already uses `pkexec`. The app does not wrap elevation again.
- Agents CLI is phase 4. The Agents page is an empty state, not a second installer.
- Shebang `#!/bin/bash` for new `bin/gesso-*`. Two-space indent. `# gesso:summary=` on every `bin/gesso-*`.
- Qt 6 + Kirigami 6. CMake. Mouse first. Keyboard still works because Kirigami.

## Success

- `gesso setup --help` exits 0.
- `gesso setup` execs `gesso-setup` (checkout build or `/usr/bin/gesso-setup`).
- Theme page: names from `gesso theme list`, current from `gesso theme current`, Apply runs `gesso theme set <name>`.
- Defaults page: browser/terminal/editor rows from `gesso-catalog-get --kind …`. Set default runs `gesso default <kind> <id>`.
- Install page: every catalog id. Install runs `gesso pkg add <id>`. Rows look disabled when `gesso-cmd-present` succeeds for that row's `command`.
- Agents page: short empty state. No `mise`, no agent ids in QML.
- A user can apply `tokyo-night` and set Firefox without typing. Picking Grok waits for phase 4.
- `./test/all` stays green without a display.

This narrows the product-brief line "pick Grok without a terminal". That line needs phase 4.

## Architecture Quality

**Affected modules:** `bin/gesso-setup`, `bin/gesso-theme-current`, `setup/` Kirigami app, desktop file, `test/cli.d/setup-test.sh`.

**Caller-facing interface:** `gesso setup`, `gesso theme current`. Pages call existing `theme list|set`, `default browser|terminal|editor`, `pkg add`, hidden `catalog-get` and `cmd-present`.

**Depth/locality check:** Process exec stays in a small C++ helper. Pages only pass argv and show stdout/stderr. No business logic in QML.

**Test surface:** `gesso setup --help`, `gesso theme current`, QML must not contain catalog ids from `data/apps.toml`.

**Seams/adapters:** CLI text output (one id per line). No JSON until a page cannot parse lines.

**Rejected shortcuts:** Reading `apps.toml` from QML. Hard-coded Firefox row. Embedding `dnf` in the app. Live Plasma in tests. Implementing agents in the GUI first.

**Architecture risk:** medium. The trap is a second installer in QML. Keep every mutation as one `gesso` argv list.

## Components

### `bin/gesso-theme-current`

```
# gesso:summary=Print the current Gesso theme name
# gesso:args=
```

Prints `~/.local/state/gesso/current/theme.name` or `unset`. Exit 0. `--help` exits 0.

### `bin/gesso-setup`

```
# gesso:summary=Open Gesso Setup
# gesso:args=
```

`--help` prints usage and exits 0. Otherwise exec the Kirigami binary:

1. `$GESSO_SETUP_BIN` if set and executable.
2. `$GESSO_ROOT/setup/build/gesso-setup` when the router checkout root exists.
3. `gesso-setup` on `PATH` (packaged `/usr/bin/gesso-setup`).

If none exist: `Gesso Setup is not built. cmake -S setup -B setup/build && cmake --build setup/build` on stderr, exit 1.

Do not open a window in unit tests. Tests only use `--help` and the missing-binary path (by pointing `GESSO_SETUP_BIN` at a missing file, or running with PATH that has the launcher only).

### `setup/` Kirigami app

CMake project `gesso-setup`. Qt6 Quick, Kirigami. One `Kirigami.ApplicationWindow`. A top or side row of four pages: Theme, Defaults, Agents, Install.

C++ type `GessoCli` with `run(list of args) -> { exitCode, stdout, stderr }`. It execs `gesso` from PATH (the router already injected `bin/` when the user typed `gesso setup`). Inherit `GESSO_PATH`.

QML must not import `data/apps.toml`.

### Desktop file

`setup/org.gesso.setup.desktop` with `Exec=gesso setup` and `Name=Gesso Setup`. Installed later by `gesso-plasma`. In the checkout it lives next to the sources.

## Pages

### Theme

- Load: `gesso theme list` (one name per line). Current: `gesso theme current`.
- Apply: `gesso theme set <name>`. Headless is not set; a real session should retint. Errors show stderr in a banner.
- No color-scheme preview widget in this phase. Apply is the preview.

### Defaults

Three groups: Browser, Terminal, Editor.

- Ids: `gesso-catalog-get --kind browser` (and terminal, editor).
- Labels: `gesso-catalog-get <id> label`.
- Installed: `gesso-cmd-present $(gesso-catalog-get <id> command)`.
- Current: `gesso default browser` (and terminal, editor), which prints an id or `unset`.
- Button: `gesso default browser <id>` (install-then-set). Same for terminal and editor.

### Install

- Union of `--kind browser`, `--kind terminal`, `--kind editor` (no `extra` rows yet).
- Button: `gesso pkg add <id>`. Dim or disable when `gesso-cmd-present` is true.
- Not Discover. Short catalog only.

### Agents

Title plus two sentences: coding agents are not in this build. Phase 4 adds `gesso agent`. No launch button.

## Errors

| Case | Result |
|---|---|
| `gesso setup --help` | Usage, exit 0 |
| Setup binary missing | Message on stderr, exit 1 |
| CLI child non-zero | Page shows stderr, does not crash |
| Empty theme list | Empty list, Apply disabled |

## Testing

`test/cli.d/setup-test.sh`:

- `gesso theme current` with no state file prints `unset`
- After `GESSO_THEME_HEADLESS=1 gesso theme set tokyo-night`, `gesso theme current` prints `tokyo-night`
- `gesso setup --help` exits 0 and mentions Setup
- `GESSO_SETUP_BIN=/no/such/gesso-setup gesso setup` exits 1
- `grep` of `setup/*.qml` (and `setup/**/*.qml`) must not match `firefox.desktop`, `org.mozilla.firefox`, `org.chromium.Chromium`, or `com.google.Chrome`
- Existing suites stay green

Do not run the GUI. Do not require `cmake` in `./test/cli`. Building the app is a lead or Fedora KDE check: `cmake -S setup -B setup/build && cmake --build setup/build`.

## Docs this spec updates (in the implementation plan)

- `docs/cli.md`: `gesso setup`, `gesso theme current`
- `docs/layout.md`: `setup/` is no longer future-only
- `docs/testing.md`: setup suite, no GUI
- `plans/README.md`, `AGENTS.md` start-here

## Out of scope

Agent install/launch, `pkg drop`, extra-kind rows, Look-and-Feel art, live Plasma preview, RPM spec, JSON command listings, QML unit tests under offscreen if they need extra packages.
