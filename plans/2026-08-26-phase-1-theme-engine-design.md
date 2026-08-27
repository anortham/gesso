# Phase 1 theme engine design

Date: 2026-08-26

Status: approved spec. Implementation plan: `plans/2026-08-26-phase-1.md`.

## Purpose

`gesso theme set <name>` turns one `colors.toml` into generated app configs, then applies the Plasma color scheme and GTK light/dark preference. Phase 0 can list `tokyo-night`. Phase 1 can apply it. The CLI is the API. Tests call the same binary.

## Constraints

- Theme names are directory names (`tokyo-night`), the same strings `gesso theme list` prints. Display titles are not accepted.
- `$GESSO_PATH` is the data root. Do not derive data from `$HOME` or the script path except the existing router checkout default.
- Write generated and runtime files under `$HOME` only: `~/.local/state/gesso`, `~/.local/share`, `~/.config`. Never `/etc`.
- No Plasma session in unit tests. No real `plasma-apply-colorscheme` or `gsettings`. Stub those binaries on `PATH`.
- `GESSO_THEME_HEADLESS=1` skips Plasma apply, GTK, and retints. Staging and file generation still run.
- Do not copy Omarchy trees, names, or Hyprland/Quickshell files. Steal the stage-render-swap loop only.
- No wallpaper, no `gesso theme install`, no extra first-party palettes, no Setup app.
- Shebang `#!/bin/bash`. Two-space indent. Metadata `# gesso:summary=` in the first 80 comment lines of each `bin/gesso-*`.

## Success

- `gesso theme set tokyo-night` exits 0 against a fake `$HOME`.
- `~/.local/share/color-schemes/Gesso.colors` and `~/.local/share/konsole/Gesso.colorscheme` exist and use RGB triples from the tokyo-night palette.
- `~/.local/state/gesso/current/theme.name` contains `tokyo-night`.
- A second `gesso theme set tokyo-night` exits 0 (idempotent).
- Unknown names exit 1. Missing required args print usage and exit 1.
- Headless tests do not invoke session tools. Non-headless tests with stubs record `plasma-apply-colorscheme Gesso` and the GTK `gsettings` call.
- Missing Kitty, VS Code, or Konsole binaries are skips, not errors.
- `./test/all` stays green.

## Architecture Quality

**Affected modules:** `bin/gesso-theme-set`, `bin/gesso-theme-set-templates`, `default/themed/*.tpl`, `test/cli` plus `test/cli.d/theme-test.sh`, router help text.

**Caller-facing interface:** `gesso theme set <name>` and `gesso theme set --help`. Hidden template command is not a user API.

**Depth/locality check:** Orchestration stays in `theme-set`. Placeholder math stays in `theme-set-templates`. App file shapes stay in templates. Tests never import those helpers; they run `gesso theme set`.

**Test surface:** `./test/cli` (driver) and `test/cli.d/theme-test.sh` invoke `gesso theme set` with a fake `$HOME` and `$GESSO_PATH=$ROOT`.

**Seams/adapters:** `colors.toml` plus `default/themed/*.tpl` are the palette seam. `plasma-apply-colorscheme` and `gsettings` are session adapters behind the headless flag.

**Rejected shortcuts:** Vendoring Omarchy templates. Parsing full TOML with a new dependency. Rewriting the user's `kitty.conf` or VS Code `settings.json`. A plugin host. Writing `/usr` or `/etc` at apply time. Live Plasma in CI.

**Architecture risk:** medium. The trap is extra retints and a second apply path. Keep apply in one command. Generate Kitty and VS Code files; do not take over those apps' main config files.

## Components

### `bin/gesso-theme-set`

User-facing command.

```
# gesso:summary=Apply a Gesso theme
# gesso:args=<name>
```

Bare invocation (no args) prints usage to stderr and exits 1.

### `bin/gesso-theme-set-templates`

Hidden helper. `theme-set` execs it after staging `colors.toml` into `next-theme`.

```
# gesso:summary=Render Gesso theme templates
# gesso:hidden=true
```

Not listed in default help. Tests do not call it directly.

### Templates

Shipped under `$GESSO_PATH/default/themed/`:

| Template | Output basename | Live destination after swap |
|---|---|---|
| `Gesso.colors.tpl` | `Gesso.colors` | `~/.local/share/color-schemes/Gesso.colors` |
| `Gesso.colorscheme.tpl` | `Gesso.colorscheme` | `~/.local/share/konsole/Gesso.colorscheme` |
| `kitty.conf.tpl` | `kitty.conf` | `~/.config/kitty/gesso-theme.conf` when `kitty` is on `PATH` or `~/.config/kitty` already exists; otherwise staged theme only |
| `vscode.json.tpl` | `vscode.json` | `~/.config/Code/User/gesso-theme.json` when that `User` directory exists; otherwise staged theme only |

One Plasma scheme name: `Gesso`. Apply always replaces that file. Do not accumulate `Gesso-tokyo-night.colors` copies.

### Test harness

Phase 1 is the second CLI suite. Split per `docs/testing.md`:

- `test/cli` becomes a thin driver: resolve `ROOT`, export `GESSO_PATH` and a temp `HOME`, put `$ROOT/bin` and a stub directory first on `PATH`, then source `test/cli.d/*-test.sh` in sorted order.
- Move today's router/list/metadata assertions into `test/cli.d/cli-test.sh`.
- Add `test/cli.d/theme-test.sh` for theme set.
- `./test/all` still runs `./test/cli` only.

## Data flow

`gesso theme set tokyo-night`:

1. Require `$GESSO_PATH`. Require exactly one name argument that is not a help flag.
2. Resolve the shipped dir `$GESSO_PATH/themes/<name>` and the user dir `$HOME/.config/gesso/themes/<name>`. At least one must contain `colors.toml`. Else print `Unknown theme: <name>` to stderr and exit 1.
3. Take the lock `${XDG_RUNTIME_DIR:-/tmp}/gesso-theme-set.lock` with `flock`.
4. Build `~/.local/state/gesso/current/next-theme` empty. Copy the shipped theme directory if it exists. Overlay the user theme directory if it exists (user files win). The result must contain `colors.toml`.
5. Run `gesso-theme-set-templates`. It reads `next-theme/colors.toml`, renders `$HOME/.config/gesso/themed/*.tpl` then `$GESSO_PATH/default/themed/*.tpl`, and writes outputs into `next-theme`. Skip a template whose output basename already exists in `next-theme` (hand-written theme files win). If a user template and a shipped template share an output basename, the user template wins and the shipped one is skipped.
6. Replace `~/.local/state/gesso/current/theme` with `next-theme` (remove the old directory if present, then `mv`). Write `~/.local/state/gesso/current/theme.name` with the directory name and a trailing newline. Hold the flock until this swap finishes.
7. Copy `Gesso.colors` and `Gesso.colorscheme` from the current theme into the live destinations above. Create parent directories as needed.
8. Write Konsole default profile `~/.local/share/konsole/Gesso.profile` with `ColorScheme=Gesso`, and set `DefaultProfile=Gesso.profile` in `~/.config/konsolerc`. Phase 1 always does this (see Konsole below).
9. Copy Kitty and VS Code outputs to their live destinations only when the conditions in the template table hold.
10. If `GESSO_THEME_HEADLESS` is unset or empty: run `plasma-apply-colorscheme Gesso`; run `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` or `prefer-light` from `mode`; run retints in parallel (Kitty `kitten @ set-colors --all` when `kitty` is on `PATH`; nothing else). A missing binary is a skip. A failing optional retint is a skip. Plasma apply failure is an error unless headless.
11. Run `$HOME/.config/gesso/hooks/theme-set*` in lexical order with the theme name as `$1`. Missing hooks dir is fine. A failing hook is an error.
12. Exit 0.

Idempotent means a second successful apply of the same name also exits 0 and leaves the same live file contents.

## Palette and templates

`colors.toml` keys are the block in `docs/theming.md` (mode through `bright_magenta`). Parser: `key = "value"` lines only. Ignore blank lines and `#` comments. No nested tables in v1.

Canonical names win over legacy `bg` / `fg` pairs. Derived:

- `selection_background` = `selection`
- `selection_foreground` = `bright_foreground`

Placeholders in templates:

- `{{ accent }}` → `#7aa2f7`
- `{{ accent_strip }}` → `7aa2f7`
- `{{ accent_rgb }}` → `122,162,247`
- `{{ mix background foreground 15% }}` → mixed hex, 15% toward foreground

Every palette key gets the bare, `_strip`, and `_rgb` forms. Mix amount may be `15%` or `0.15`.

Plasma `.colors` is an INI file with `Name=Gesso` and RGB decimal triples. Map:

| Plasma key | Palette key |
|---|---|
| `Colors:Window` / `Colors:View` BackgroundNormal | `background` |
| `Colors:Window` ForegroundNormal | `foreground` |
| `Colors:Selection` BackgroundNormal | `selection` |
| `Colors:Selection` ForegroundNormal | `bright_foreground` |
| Header / complementary accent | `accent` |
| Disabled / inactive | `muted` / `dark_foreground` |

Konsole `.colorscheme` uses the ANSI set plus background/foreground from the same palette. Scheme name inside the file is `Gesso`.

`Gesso.profile` is a Konsole profile INI with at least:

```
[Appearance]
ColorScheme=Gesso

[General]
Name=Gesso
```

Kitty template writes a colors-only conf (foreground, background, cursor, color0–color15). Live file is `gesso-theme.conf`, not `kitty.conf`, so Gesso does not replace the user's main Kitty config. Users may `include gesso-theme.conf`. Phase 1 does not edit `kitty.conf`.

VS Code template writes a JSON object of workbench colors. Phase 1 does not rewrite `settings.json` and does not install an extension.

## Errors

| Case | Result |
|---|---|
| No args or `--help` / `-h` | Usage, help exits 0, missing args exit 1 |
| Name not a directory with `colors.toml` in shipped or user themes | `Unknown theme: <name>` stderr, exit 1 |
| `$GESSO_PATH` unset (command not reached via router) | `GESSO_PATH is not set` stderr, exit 1 |
| `colors.toml` missing after overlay | stderr, exit 1 |
| `plasma-apply-colorscheme` missing or fails, not headless | stderr, exit 1 |
| `gsettings` missing, not headless | skip GTK, do not fail |
| Kitty / VS Code / `kitten` missing | skip that retint |
| Hook executable fails | stderr, exit 1 |

`set -euo pipefail` on all new scripts.

## Testing

`test/cli.d/theme-test.sh` (through `./test/cli`) must cover:

- `gesso theme set` with no args exits 1 and prints `Usage`
- `gesso theme set --help` exits 0 and does not apply
- `gesso theme set not-a-theme` exits 1
- `gesso theme set tokyo-night` with `GESSO_THEME_HEADLESS=1` writes `theme.name`, `Gesso.colors`, `Gesso.colorscheme`, and the staged `current/theme` files
- `Gesso.colors` contains the tokyo-night window background RGB `26,27,38` (from `#1a1b26`)
- User overlay: a user `colors.toml` that changes `accent` shows up in generated output
- Duplicate apply exits 0
- User template `~/.config/gesso/themed/extra.conf.tpl` appears in `current/theme/extra.conf`
- Headless run does not call the `plasma-apply-colorscheme` stub
- Non-headless run with stubs logs `plasma-apply-colorscheme Gesso` and `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`
- Metadata lint still requires `# gesso:summary=` on every `bin/gesso-*`, including the hidden helper
- Existing list/router assertions still pass

Stub directory on `PATH` (ahead of real tools) provides executable `plasma-apply-colorscheme` and `gsettings` that append argv to `$HOME/gesso-stub.log`.

No DBus, no nested Plasma, no network.

## Docs this spec updates (in the implementation plan, not before)

- `docs/cli.md`: `gesso theme set tokyo-night` (directory name, not `"Tokyo Night"`). Phase 0 sentence becomes "Phase 1 adds `theme set`."
- `docs/theming.md`: already matches this flow; add the live destination table and the Kitty/VS Code non-clobber rule.
- `docs/testing.md`: record the `test/cli.d` split and the stub log.
- `plans/README.md` and `AGENTS.md` start-here: point at the phase 1 plan once it exists.

## Out of scope

Ghostty, Foot, Chromium theme JSON, wallpaper, Look-and-Feel packages, `theme install`, git-theme denylist, extra palettes, group listing for bare `gesso theme`, Setup app, RPMs.
