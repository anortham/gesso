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

1. Build `~/.local/state/gesso/current/next-theme` from the first-party theme, then overlay the user theme.
2. Render `$GESSO_PATH/default/themed/*.tpl` and `~/.config/gesso/themed/*.tpl` (user templates win on output filename). Do not overwrite a file the theme already shipped.
3. `flock`, then swap next-theme to `~/.local/state/gesso/current/theme` and write `theme.name`.
4. Write a Plasma color scheme to `~/.local/share/color-schemes/Gesso.colors` and run `plasma-apply-colorscheme Gesso` when a session is available.
5. Write Konsole (and other terminal) configs under `~/.local/share` / `~/.config` as each template specifies.
6. Set GTK `org.gnome.desktop.interface color-scheme` to `prefer-dark` or `prefer-light` from `mode`.
7. Run `post_theme` retints in parallel (terminals that are running, VS Code, browser chrome). Missing binaries are skipped, not errors.
8. Run `~/.config/gesso/hooks/theme-set*` with the theme name as `$1`.

Headless / tests set `GESSO_THEME_HEADLESS=1` and skip Plasma, GTK, and retints. Staging and file generation still run.

`gesso theme set` is idempotent. A second apply of the same theme must not fail.

## Live destinations (phase 1)

| Template | Output basename | Live destination after swap |
|---|---|---|
| `Gesso.colors.tpl` | `Gesso.colors` | `~/.local/share/color-schemes/Gesso.colors` |
| `Gesso.colorscheme.tpl` | `Gesso.colorscheme` | `~/.local/share/konsole/Gesso.colorscheme` |
| `kitty.conf.tpl` | `kitty.conf` | `~/.config/kitty/gesso-theme.conf` when `kitty` is on `PATH` or `~/.config/kitty` already exists; otherwise staged theme only |
| `vscode.json.tpl` | `vscode.json` | `~/.config/Code/User/gesso-theme.json` when that `User` directory exists; otherwise staged theme only |

Gesso does not replace the user's main Kitty or VS Code config. It does not write `kitty.conf` or `settings.json`. Users may `include gesso-theme.conf` from their own Kitty config.

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
