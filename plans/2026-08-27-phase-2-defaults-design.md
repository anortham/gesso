# Phase 2 defaults design

Date: 2026-08-27

Status: approved spec. Implementation plan: `plans/2026-08-27-phase-2.md`.

## Purpose

`gesso default browser firefox` installs Firefox if it is missing, then sets it as the XDG default browser. The same loop exists for terminal and editor. Package names live in `data/apps.toml`. The CLI is the API. Tests call the same binaries.

## Constraints

- Catalog is the only source of package names, desktop ids, and commands. No `case` lists that duplicate `data/apps.toml`.
- `$GESSO_PATH` is the data root. Catalog path is `$GESSO_PATH/data/apps.toml`.
- Never call real `dnf`, `flatpak`, `pkexec`, or `sudo` in unit tests. Stub them on `PATH`.
- Privilege: `sudo` when stdin is a TTY; `pkexec` when it is not; run the package tool directly when `EUID` is 0. Do not wrap a command that already elevates.
- Never write to `/etc`.
- No Setup app, no agents, no `pkg drop`, no extra-kind Install page.
- Shebang `#!/bin/bash`. Two-space indent. `# gesso:summary=` on every `bin/gesso-*`.
- Do not copy Omarchy files. Steal install-then-default only.

## Success

- `gesso default browser firefox` on a harness where `firefox` is missing logs a `dnf install` of `firefox`, then `xdg-settings` reports `firefox.desktop`.
- If `firefox` is already on `PATH`, install is skipped and the default is still set.
- A second `gesso default browser firefox` exits 0 (idempotent).
- Unknown ids exit 1. Missing args print usage and exit 1.
- `./test/all` stays green. No real `dnf`.

## Architecture Quality

**Affected modules:** `data/apps.toml`, hidden catalog reader, `gesso-pkg-add`, `gesso-default-browser`, `gesso-default-terminal`, `gesso-default-editor`, `test/cli.d/default-test.sh`.

**Caller-facing interface:** `gesso default browser|terminal|editor [id]`, `gesso pkg add <id>`. Hidden helpers are not a user API.

**Depth/locality check:** Catalog parse stays in the hidden reader. Privilege and install stay in `pkg add`. Default commands only: present check, maybe `pkg add`, then set handler.

**Test surface:** `gesso default browser firefox` and `gesso pkg add firefox` against a fake `$HOME` and stub PATH.

**Seams/adapters:** `data/apps.toml`. `dnf` / `flatpak` / `xdg-settings` are adapters behind stubs.

**Rejected shortcuts:** Hard-coded browser `case` like Omarchy. Real package installs in CI. Rewriting `/etc`. A second installer for the later Setup app.

**Architecture risk:** medium. Installing packages can wreck a machine if tests hit real `dnf`. Keep stubs first on PATH. Keep every package name in the catalog.

## Components

### `data/apps.toml`

Every v1 id from `docs/catalog.md`. `kind` is `browser`, `terminal`, or `editor`. Empty `dnf` means skip RPM and use Flatpak. `command` is the present-check. `desktop_id` is the XDG handler. `label` is the notify text.

### `bin/gesso-catalog-get` (hidden)

```
# gesso:summary=Read a field from the app catalog
# gesso:hidden=true
# gesso:args=<id> <field>|--kind <kind>
```

`gesso-catalog-get firefox command` prints `firefox`. `gesso-catalog-get firefox dnf` prints package names space-separated (empty if none). `gesso-catalog-get --kind browser` prints browser ids, one per line, catalog order. Missing id or field exits 1. Parse with `python3` and `tomllib` (Fedora 44). Tests call default/pkg commands, not this helper, except a small catalog-get unit in `default-test.sh` is allowed because the helper is the catalog seam.

### `bin/gesso-cmd-present` (hidden)

```
# gesso:summary=Exit 0 if every named command is on PATH
# gesso:hidden=true
```

Same contract as a `command -v` loop. Default commands and `pkg add` use it.

### `bin/gesso-pkg-add`

```
# gesso:summary=Install a catalog app with dnf, then Flatpak
# gesso:args=<id>
# gesso:requires-sudo=true
```

1. Look up the row. Unknown id: `Unknown app: <id>` stderr, exit 1.
2. If `gesso-cmd-present` for `command`, exit 0.
3. If `dnf` is non-empty, elevate `dnf install -y <packages>`. On success, exit 0 after a present-check (or if the stub created the command).
4. If dnf was empty or failed, and `flatpak` is set, elevate `flatpak install -y flathub <flatpak>`.
5. If the command is still missing, stderr and exit 1.

### `bin/gesso-default-browser`

```
# gesso:summary=Set or print the default browser
# gesso:args=[id]
```

No args: print the catalog id whose `desktop_id` matches `xdg-settings get default-web-browser`, or print that desktop file name if it is not in the catalog, or `unset` if get fails. Exit 0.

With id: require `kind = browser`. Run install-then-default. Set `env -u BROWSER xdg-settings set default-web-browser <desktop_id>`. Notify with `label`. Exit 0.

### `bin/gesso-default-terminal`

Same shape. Set default by writing `desktop_id` as the first line of `~/.config/xdg-terminals.list` (create the file and parent dir). Do not rewrite other lines except to move this id to the front if it is already present. No args: print the catalog id for the first line, or `unset`.

### `bin/gesso-default-editor`

Same shape. Write `id` plus a newline to `~/.local/state/gesso/defaults/editor`. No args: print that file, or `unset`.

## Data flow

`gesso default browser firefox`:

1. Load the firefox row. Wrong kind or missing row: exit 1.
2. If `firefox` is not on PATH, `gesso pkg add firefox`.
3. `xdg-settings set default-web-browser firefox.desktop`.
4. `notify-send` with `label` if `notify-send` exists; otherwise skip.
5. Exit 0.

## Catalog rows (v1)

Include every id `docs/catalog.md` names. Fedora 44 names:

| id | kind | command | dnf | flatpak | desktop_id |
|---|---|---|---|---|---|
| firefox | browser | firefox | firefox | org.mozilla.firefox | firefox.desktop |
| chromium | browser | chromium-browser | chromium | org.chromium.Chromium | chromium-browser.desktop |
| chrome | browser | google-chrome | (none) | com.google.Chrome | google-chrome.desktop |
| brave | browser | brave | (none) | com.brave.Browser | brave-browser.desktop |
| edge | browser | microsoft-edge | (none) | com.microsoft.Edge | microsoft-edge.desktop |
| konsole | terminal | konsole | konsole | (none) | org.kde.konsole.desktop |
| ghostty | terminal | ghostty | (none) | com.mitchellh.ghostty | com.mitchellh.ghostty.desktop |
| kitty | terminal | kitty | kitty | (none) | kitty.desktop |
| foot | terminal | foot | foot | (none) | foot.desktop |
| code | editor | code | (none) | com.visualstudio.code | code.desktop |
| kate | editor | kate | kate | (none) | org.kde.kate.desktop |
| nvim | editor | nvim | neovim | (none) | nvim.desktop |
| helix | editor | helix | helix | (none) | helix.desktop |
| zed | editor | zed | (none) | dev.zed.Zed | dev.zed.Zed.desktop |

`(none)` means omit the key or use an empty array / empty string. Glyphs and labels as in `docs/catalog.md` (Firefox example) and plain names for the rest (`Chromium`, `Chrome`, …).

Chrome, Brave, Edge, Ghostty, VS Code, and Zed have no Fedora RPM in this spec. Install is Flatpak only.

## Errors

| Case | Result |
|---|---|
| No args on `pkg add` | Usage, exit 1 |
| `--help` | Usage, exit 0 |
| Unknown catalog id | `Unknown app: <id>` or `Unknown browser: <id>` (kind-specific for default commands), exit 1 |
| Wrong kind (`gesso default browser kate`) | same unknown message, exit 1 |
| `dnf` and `flatpak` both fail / missing | stderr, exit 1 |
| `xdg-settings set` fails | stderr, exit 1 |
| `notify-send` missing | skip |

## Testing

`test/cli.d/default-test.sh` through `./test/cli`. Extend `gesso_test_init` (or the default suite) so PATH stubs include `dnf`, `flatpak`, `sudo`, `pkexec`, `xdg-settings`, and `notify-send`. They append argv to `$HOME/gesso-stub.log`.

`dnf install` stub also writes an executable `$HOME/gesso-stubs/<command>` for the catalog command of that id so a later present-check succeeds. `flatpak install` does the same. `sudo` logs and execs the remaining argv (so the `dnf` stub still runs). `xdg-settings set default-web-browser` stores the desktop id; `get` prints it.

Cover at least:

- `gesso default browser` with no args prints `unset` (or usage is wrong; no args is print current)
- `gesso default browser --help` exits 0
- `gesso default browser not-a-browser` exits 1
- `gesso default browser firefox` when firefox is missing: stub log has `dnf install -y firefox`, then `xdg-settings get` is `firefox.desktop`
- `gesso default browser firefox` when firefox is already on PATH: no `dnf install` in the log, default still set
- Second apply exits 0
- `gesso default terminal konsole` writes `org.kde.konsole.desktop` as the first line of `~/.config/xdg-terminals.list`
- `gesso default editor kate` writes `kate` to `~/.local/state/gesso/defaults/editor`
- `gesso pkg add chrome` uses Flatpak (no dnf packages)
- Metadata lint still passes for the new `gesso-*` files
- Theme and router suites still pass

No DBus, no network, no real RPM transaction.

## Docs this spec updates (in the implementation plan)

- `docs/cli.md`: `default browser|terminal|editor`, `pkg add`, phase 2 sentence.
- `docs/catalog.md`: note that phase 2 ships `data/apps.toml` and `pkg add`.
- `docs/testing.md`: default-suite stubs (`dnf`, `xdg-settings`).
- `plans/README.md` and `AGENTS.md` start-here.

## Out of scope

`pkg drop`, `kind = extra`, agents, `gesso default agent`, Setup app, live `dnf` on a Fedora box, COPR.
