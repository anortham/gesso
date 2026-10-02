---
name: gesso
description: Customize an installed Gesso Fedora KDE desktop using its CLI, user themes, and hooks. Use for Gesso palettes, wallpaper, default apps, catalog installs, coding-agent selection, and recovering Gesso customizations. For Gesso source development, follow the repository instructions instead.
---

# Gesso desktop customization

Gesso is an add-on for Fedora KDE, with one palette, install-then-set-default commands, and a coding-agent picker. Plasma remains the desktop; Gesso does not own the panel, window manager, bootloader, or system configuration.

## Discover before changing

Use `gesso commands` and the relevant command’s `--help` to discover the installed version’s capabilities. Inspect the current choice before changing it:

```bash
gesso theme list --json
gesso theme current
gesso default browser
gesso default terminal
gesso default editor
gesso default agent
```

Read app choices with `gesso catalog get --json --kind browser` (or `terminal` or `editor`) and agent choices with `gesso agent get --json`. These are hidden catalog helpers, so they do not appear in the command listing. Use catalog ids rather than guessing package names or desktop ids.

## Change through the CLI

- Apply a palette with `gesso theme set <name>`. It keeps the wallpaper unless requested otherwise. `gesso theme set <name> --wallpaper theme` selects a theme image when available; `--wallpaper "/path/to/image.jpg"` copies and applies a custom image. Gesso currently ships palettes without wallpapers.
- Set an app with `gesso default browser <id>`, `gesso default terminal <id>`, or `gesso default editor <id>`. These commands install a missing catalog app before setting its default. Do not implement a second installer or edit MIME defaults directly.
- Install an app without changing defaults with `gesso pkg add <id>`. Gesso tries catalog RPMs, then a per-user Flatpak fallback when listed. It handles elevation itself; do not wrap these commands in `sudo` or `pkexec`. A catalog entry can require an existing vendor repository; report the failed install rather than adding repositories or writing `/etc`.
- Select a coding agent with `gesso default agent <id>`; it preserves existing native executables and installs missing tools with per-user mise. This does not supply provider credentials. `gesso agent` launches the selection, and `gesso agent -- "prompt"` seeds an interactive session. Launching can use the user’s paid provider account, so do it only when requested. Approval flags come from the catalog; do not change the user’s security policy as part of an unrelated desktop task.

## Custom palettes and hooks

Packaged files under `${GESSO_PATH:-/usr/share/gesso}` are reference material. Do not edit them: package updates replace them. Put customizations under `~/.config/gesso/`.

For a new palette, copy a complete built-in theme’s `colors.toml` into `~/.config/gesso/themes/<name>/colors.toml`, then edit the copy. Names use lowercase letters and digits separated by single hyphens. Keep the complete semantic and ANSI color set; use double-quoted six-digit `#RRGGBB` colors and `mode = "dark"` or `mode = "light"`. A same-named user theme overlays built-in files, but its `colors.toml` replaces the entire built-in palette file; a partial palette is not a key-level merge. Optional images live in the theme’s `backgrounds/` directory.

User template overrides belong in `~/.config/gesso/themed/*.tpl`. Templates support `{{ accent }}`, `{{ accent_strip }}`, `{{ accent_rgb }}`, and `{{ mix background foreground 15% }}`; unresolved placeholders reject application. Executable hooks in `~/.config/gesso/hooks/theme-set*` receive the applied theme name as their first argument. Add hooks only for requested integrations, and preserve existing hooks.

Do not edit generated files under `~/.local/state/gesso/current/` or the Gesso output files in terminal, VS Code, or Plasma directories. Change the palette or user template and reapply through the CLI. Preserve unrelated app settings and existing user files. Do not use Omarchy commands, Hyprland/Quickshell configuration, or system-wide `/etc` changes for a Gesso task.

## Verify and recover

Check the command’s exit status, then read the current theme or default again. On error, report the diagnostic and inspect the relevant input; do not claim that a setting changed or discard recovery files. A theme apply validates VS Code settings before changing the desktop; invalid JSON/JSONC must be repaired without overwriting unrelated editor settings.

Use `gesso theme undo` for the immediately previous application, or `gesso theme restore` to remove Gesso customizations and restore the recorded baseline. Restore uses a Breeze scheme for Plasma; it does not recover an arbitrary earlier Plasma color scheme. Keep the user’s `~/.config/gesso` and recovery state. Run restore before removing Gesso if its theme is active; use `gesso agent skills --remove` before uninstalling to unlink only its packaged skill.

`GESSO_THEME_HEADLESS=1` is for file-generation tests, not proof that a live desktop changed. `GESSO_AGENT_DRY_RUN=1 gesso agent` prints the selected cwd and argv without launching an agent. Neither is a substitute for the requested live action.
