# Theming

A theme is a directory named in lowercase-with-hyphens that contains `colors.toml`. First-party themes live in `$GESSO_PATH/themes/<name>/`. User themes live in `~/.config/gesso/themes/<name>/` and overlay the first-party directory of the same name when both exist.

Phase 0 only lists themes. Phase 1 renders templates and applies Plasma, Konsole, Kitty, Ghostty, Foot, and VS Code files.

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

## Activation

`gesso theme set <name> [--wallpaper <keep|theme|path>]`:

1. Reject names that do not match `^[a-z0-9]+(-[a-z0-9]+)*$` with `Unknown theme:`. Canonical theme dirs must stay under `$GESSO_PATH/themes` or `~/.config/gesso/themes`.
2. Take a lock at `${XDG_RUNTIME_DIR:-~/.local/state/gesso}/gesso-theme-set.lock`. Never `/tmp`.
3. Build `~/.local/state/gesso/current/next-theme` from the first-party theme, then overlay the user theme. Require `mode` (`dark` or `light`), `accent`, `background`, and `foreground`.
4. Render `$GESSO_PATH/default/themed/*.tpl` and `~/.config/gesso/themed/*.tpl` (user templates win on output filename). Do not overwrite a file the theme already shipped. If any file in next-theme still contains `{{`, delete next-theme and exit 1.
5. Write `~/.local/share/color-schemes/Gesso.colors`. When a session is available, keep the previous file aside and run `plasma-apply-colorscheme Gesso`. On failure, restore the aside file, delete next-theme, and leave `current/theme` unchanged.
6. For each VS Code target that exists, run `gesso-vscode-colors merge` to parse `settings.json` (JSON or JSONC: comments and trailing commas) and stage the merged `workbench.colorCustomizations` before copying Konsole, Kitty, Ghostty, or Foot live files. The targets are `~/.config/Code/User` with backup `~/.local/state/gesso/vscode-colorCustomizations.json` and the Flatpak dir `~/.var/app/com.visualstudio.code/config/Code/User` with backup `~/.local/state/gesso/vscode-flatpak-colorCustomizations.json`. Invalid `settings.json` in any target is a hard error and does not change the live files. Gesso rewrites `settings.json` as JSON, so comments are not kept. Each target's backup stores the previous `workbench.colorCustomizations` value (JSON `null` if the key was absent) and is written only if it does not already exist.
7. Before changing `~/.config/konsolerc`, write the previous `DefaultProfile=` value to `~/.local/state/gesso/konsole-default-profile` (an empty file when there was none) if that backup does not already exist. Then copy Konsole, Kitty, Ghostty, and Foot live files from next-theme, write each `gesso-theme.json`, and publish each staged merge.
8. Enable terminal themes non-destructively: add `include gesso-theme.conf` to `~/.config/kitty/kitty.conf` (without duplicate lines), set `theme = Gesso` in `~/.config/ghostty/config` (saving prior theme setting), and add `include = ~/.config/foot/gesso-theme.ini` under `[main]` in `~/.config/foot/foot.ini`.
9. Record prior state into `~/.local/state/gesso/undo/` (including previous theme name, previous wallpaper, and terminal configuration markers) for single-step rollback.
10. Swap next-theme to `~/.local/state/gesso/current/theme` and write `theme.name`.
11. Handle wallpaper according to the selected mode (default: `keep`). Mode `keep` leaves the current wallpaper untouched. Mode `theme` applies the first sorted image in `current/theme/backgrounds/` when present using `plasma-apply-wallpaperimage`. Mode `<path>` copies the custom image to `~/.local/state/gesso/wallpapers/` and applies it.
12. Before the first `gsettings set`, write `gsettings get org.gnome.desktop.interface color-scheme` to `~/.local/state/gesso/gtk-color-scheme` if that backup does not already exist. Then set GTK `org.gnome.desktop.interface color-scheme` to `prefer-dark` or `prefer-light` from `mode`.
13. Retint a running Kitty when `kitten` is on `PATH`. Missing binaries are skipped, not errors.
14. Run `~/.config/gesso/hooks/theme-set*` with the theme name as `$1`.

Headless / tests set `GESSO_THEME_HEADLESS=1` and skip Plasma, wallpaper, GTK, and live retints. Validation, file swap, the Konsole backup, and the VS Code `settings.json` merge still run.

`gesso theme undo` reverts desktop, wallpaper, and terminal configurations to the immediate prior state recorded in `~/.local/state/gesso/undo/`, then cleans up the undo state directory. If no prior state was recorded, it exits with an error.

`gesso theme restore` undoes all Gesso customizations back to the pre-Gesso baseline. For each VS Code target whose backup file exists, `gesso-vscode-colors restore` restores the backed-up customizations and deletes the backup file. It puts the original Konsole `DefaultProfile=` back and deletes its backup. It removes Gesso theme includes from `kitty.conf`, `ghostty/config`, and `foot.ini` without damaging user settings. It deletes `theme.name`, so `gesso theme current` prints `unset`. When not headless, it applies `BreezeDark` or `BreezeLight` from `mode`, restores the GTK color scheme from backup (or resets it), and restores the baseline wallpaper if recorded. It deletes `~/.local/state/gesso/undo/` and generated theme files.

`bin/gesso-vscode-colors` is a hidden helper and the only JSONC parser. `gesso-vscode-colors merge <theme.json> <settings.json> <backup> <staged>` writes the backup when missing and stages the merged settings. `gesso-vscode-colors restore <settings.json> <backup>` puts the backed-up key back and deletes the backup.

`gesso theme set` is idempotent. A second apply of the same theme must not fail.

## Live destinations (phase 1)

| Template | Output basename | Live destination after swap |
|---|---|---|
| `Gesso.colors.tpl` | `Gesso.colors` | `~/.local/share/color-schemes/Gesso.colors` |
| `Gesso.colorscheme.tpl` | `Gesso.colorscheme` | `~/.local/share/konsole/Gesso.colorscheme` |
| `kitty.conf.tpl` | `kitty.conf` | `~/.config/kitty/gesso-theme.conf` when `kitty` is on `PATH` or `~/.config/kitty` already exists; otherwise staged theme only |
| `ghostty.tpl` | `ghostty` | `~/.config/ghostty/themes/Gesso` when `ghostty` is on `PATH` or `~/.config/ghostty` already exists; otherwise staged theme only |
| `foot.ini.tpl` | `foot.ini` | `~/.config/foot/gesso-theme.ini` when `foot` is on `PATH` or `~/.config/foot` already exists; otherwise staged theme only |
| `vscode.json.tpl` | `vscode.json` | `~/.config/Code/User/gesso-theme.json` when that `User` directory exists, plus merge into `settings.json` `workbench.colorCustomizations`; otherwise staged theme only |
| `vscode.json.tpl` | `vscode.json` | `~/.var/app/com.visualstudio.code/config/Code/User/gesso-theme.json` when that Flatpak `User` directory exists, plus merge into its `settings.json` `workbench.colorCustomizations`; otherwise staged theme only |

Gesso does not overwrite the user's main Kitty, Ghostty, Foot, or VS Code config. It merges `workbench.colorCustomizations` into `settings.json` and restores that key on restore. On theme application, Gesso safely adds `include gesso-theme.conf` to `kitty.conf`, configures `theme = Gesso` in Ghostty's config, and adds `include = ~/.config/foot/gesso-theme.ini` to `foot.ini`, cleanly removing or reverting these entries upon theme restore or undo.

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

Do not ship a custom SVG Plasma theme in v1. Color scheme plus wallpaper (optional `themes/<name>/backgrounds/`) is enough. `theme set` applies the first sorted file in `backgrounds/` with `plasma-apply-wallpaperimage`. Gesso ships no images in v1.

## Konsole (phase 1)

Write `~/.local/share/konsole/Gesso.colorscheme` from a template. Phase 1 also writes `~/.local/share/konsole/Gesso.profile` with `ColorScheme=Gesso` and sets `DefaultProfile=Gesso.profile` in `~/.config/konsolerc`. The previous `DefaultProfile=` value is kept in `~/.local/state/gesso/konsole-default-profile` until `theme restore` puts it back.

## First-party themes

Five palettes ship: `tokyo-night`, `catppuccin-mocha`, `gruvbox-dark`, and `nord` are dark; `catppuccin-latte` is light. Each uses the same key set as `themes/tokyo-night/colors.toml`. Do not import Omarchy's Hyprland/Lua/terminal files.

## Security

A theme cloned from git (`gesso theme install <url>`, later) must not ship shell, Lua, or editor extensions. Filter the same class of files Omarchy denies (`*.lua`, terminal configs that name a program, `vscode.json`). Palette files stay.
