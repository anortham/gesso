# Theming

A theme is a directory named in lowercase-with-hyphens that contains `colors.toml`. First-party themes live in `$GESSO_PATH/themes/<name>/`. User themes live in `~/.config/gesso/themes/<name>/` and overlay the first-party directory of the same name when both exist.

Phase 0 only lists themes. Phase 1 renders templates and applies Plasma, Konsole, Kitty, and VS Code files.

## `colors.toml`

Semantic keys first, then the ANSI set. `mode` is `dark` or `light`.

```toml
mode = "dark"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
green = "#9ece6a"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"
```

Templates may use `{{ accent }}`, `{{ accent_strip }}` (`7aa2f7`), `{{ accent_rgb }}` (`122,162,247`), and `{{ mix background foreground 15% }}`.

Canonical names win if a legacy `bg` / `fg` pair is also present. Derived: `selection_background = selection`, `selection_foreground = bright_foreground`. There is no `urgent` key; `red` fills that role.

## Activation (phase 1)

`gesso theme set <name>`:

1. Reject names that do not match `^[a-z0-9]+(-[a-z0-9]+)*$` with `Unknown theme:`. Canonical theme dirs must stay under `$GESSO_PATH/themes` or `~/.config/gesso/themes`.
2. Take a lock at `${XDG_RUNTIME_DIR:-~/.local/state/gesso}/gesso-theme-set.lock`. Never `/tmp`.
3. Build `~/.local/state/gesso/current/next-theme` from the first-party theme, then overlay the user theme. Require `mode` (`dark` or `light`), `accent`, `background`, and `foreground`.
4. Render `$GESSO_PATH/default/themed/*.tpl` and `~/.config/gesso/themed/*.tpl` (user templates win on output filename). Do not overwrite a file the theme already shipped. If any file in next-theme still contains `{{`, delete next-theme and exit 1.
5. Write `~/.local/share/color-schemes/Gesso.colors`. When a session is available, keep the previous file aside and run `plasma-apply-colorscheme Gesso`. On failure, restore the aside file, delete next-theme, and leave `current/theme` unchanged.
6. When `~/.config/Code/User` exists, parse `settings.json` (JSON or JSONC: comments and trailing commas) and stage the merged `workbench.colorCustomizations` before copying Konsole or Kitty live files. Invalid `settings.json` is a hard error and does not change those live files. Gesso rewrites `settings.json` as JSON, so comments are not kept. On success, copy Konsole, Kitty, and VS Code live files from next-theme, write `gesso-theme.json`, and publish the staged merge. Write the previous `workbench.colorCustomizations` value (JSON `null` if the key was absent) to `~/.local/state/gesso/vscode-colorCustomizations.json` only if that backup does not already exist.
7. Swap next-theme to `~/.local/state/gesso/current/theme` and write `theme.name`.
8. Set GTK `org.gnome.desktop.interface color-scheme` to `prefer-dark` or `prefer-light` from `mode`.
9. Retint a running Kitty when `kitten` is on `PATH`. Missing binaries are skipped, not errors.
10. Run `~/.config/gesso/hooks/theme-set*` with the theme name as `$1`.

Headless / tests set `GESSO_THEME_HEADLESS=1` and skip Plasma, GTK, and live retints. Validation, file swap, and the VS Code `settings.json` merge still run.

`gesso theme restore` writes the backed-up `workbench.colorCustomizations` key (or deletes it if the backup is JSON `null`) when the backup file exists, then deletes the backup file, then applies `BreezeDark` or `Breeze` from the last theme `mode`.

`gesso theme set` is idempotent. A second apply of the same theme must not fail.

## Live destinations (phase 1)

| Template | Output basename | Live destination after swap |
|---|---|---|
| `Gesso.colors.tpl` | `Gesso.colors` | `~/.local/share/color-schemes/Gesso.colors` |
| `Gesso.colorscheme.tpl` | `Gesso.colorscheme` | `~/.local/share/konsole/Gesso.colorscheme` |
| `kitty.conf.tpl` | `kitty.conf` | `~/.config/kitty/gesso-theme.conf` when `kitty` is on `PATH` or `~/.config/kitty` already exists; otherwise staged theme only |
| `vscode.json.tpl` | `vscode.json` | `~/.config/Code/User/gesso-theme.json` when that `User` directory exists, plus merge into `settings.json` `workbench.colorCustomizations`; otherwise staged theme only |

Gesso does not replace the user's main Kitty or VS Code config. It does not write `kitty.conf`. It may merge `workbench.colorCustomizations` into `settings.json` and must restore that key. It does not replace the rest of `settings.json`. Users may `include gesso-theme.conf` from their own Kitty config.

## Plasma mapping (phase 1)

Generate `~/.local/share/color-schemes/Gesso.colors`. Keep one scheme name (`Gesso`) so Apply always replaces the previous Gesso scheme rather than accumulating copies.

| Plasma key | Palette key |
|---|---|
| `Colors:Window` / `Colors:View` BackgroundNormal | `background` |
| `Colors:Window` ForegroundNormal | `foreground` |
| `Colors:Selection` BackgroundNormal | `selection` |
| `Colors:Selection` ForegroundNormal | `bright_foreground` |
| `Colors:Complementary` or header accent | `accent` |
| Disabled / inactive | `muted` / `dark_foreground` |

Use RGB decimal triples (`26,27,38`), which is what `.colors` files store.

Do not ship a custom SVG Plasma theme in v1. Color scheme plus wallpaper (optional `themes/<name>/backgrounds/`) is enough.

## Konsole (phase 1)

Write `~/.local/share/konsole/Gesso.colorscheme` from a template. Phase 1 also writes `~/.local/share/konsole/Gesso.profile` with `ColorScheme=Gesso` and sets `DefaultProfile=Gesso.profile` in `~/.config/konsolerc`.

## First-party themes

Phase 0 ships one: `tokyo-night`, palette only. Add more palettes after `theme set` works. Do not import Omarchy's Hyprland/Lua/terminal files.

## Security

A theme cloned from git (`gesso theme install <url>`, later) must not ship shell, Lua, or editor extensions. Filter the same class of files Omarchy denies (`*.lua`, terminal configs that name a program, `vscode.json`). Palette files stay.
