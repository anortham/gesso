# v1 gaps design

Date: 2026-09-01

A whole-project review found that the first COPR build would fail and that several v1 features stop halfway. This design records the decisions for closing every finding. The implementation plan is `2026-09-01-v1-gaps.md`.

## Findings

Verified on a Fedora 44 host with `dnf repoquery`, `mise registry`, and the agent CLIs:

- `mise` is not a Fedora package. `dnf install -y mise` fails. `gesso-agents` `Requires: mise` cannot resolve.
- `qt6-qtquickcontrols2-devel` does not exist in Fedora 44. `qt6-qtdeclarative-devel` provides QuickControls2.
- The Setup app has never been compiled.
- `gesso default editor` writes a state file that nothing reads.
- The VS Code merge reads `~/.config/Code/User`. Gesso installs VS Code only as a Flatpak, which keeps config under `~/.var/app/com.visualstudio.code/config/Code/User`.
- Stock Fedora ships Flathub as a filtered system remote. Chrome, Brave, Edge, Zed, Ghostty, and Code Flatpak installs fail until the user enables full Flathub.
- One theme only. No light theme. No wallpaper support. Ghostty and Foot are catalog terminals but the theme engine does not render them.
- `theme restore` leaves `theme.name`, the Konsole default profile, and the GTK color scheme. Its JSON parse is strict while `theme set` accepts JSONC.
- Setup Agents page Launch opens Konsole for `gesso agent` even with no default. Theme Apply is synchronous. Tab switches rebuild pages and spawn about sixty processes.
- Router help is hardcoded. Metadata keys other than `hidden` are documented but unused.
- `data/agents.toml` uses `npm:@xai-official/grok`. The mise registry has `grok`.
- No CI.

## Decisions

### Packaging

- Drop `qt6-qtquickcontrols2-devel` from `BuildRequires`. Keep `qt6-qtdeclarative-devel`.
- `gesso` gains `Requires: xdg-utils` and `Recommends: libnotify`, `Recommends: flatpak`.
- `gesso-plasma` gains `Requires: kf6-qqc2-desktop-style`.
- Remove the `gesso-agents` subpackage and the `Recommends: gesso-agents` line. `mise` cannot be a package dependency on Fedora. Agent commands already live in `gesso`. Two RPMs ship: `gesso` and `gesso-plasma`.
- Add `Icon=preferences-desktop-theme` to `setup/org.gesso.setup.desktop`.
- Add `.github/workflows/ci.yml`. Job `cli` runs `./test/all` in a `registry.fedoraproject.org/fedora:44` container. Job `setup` installs `cmake`, `extra-cmake-modules`, `gcc-c++`, `kf6-kirigami-devel`, `qt6-qtbase-devel`, `qt6-qtdeclarative-devel` and runs `cmake -S setup -B build && cmake --build build`.

### Agents

- `mise` installs per user with the official installer: `curl -fsSL https://mise.run | MISE_INSTALL_PATH=$HOME/.local/bin/mise sh`. No `dnf`, no `sudo`, no `pkexec`, no `/etc`. This also works on Kinoite and Aurora.
- `gesso-default-agent` and `gesso-agent` locate mise with `command -v mise`, then `$HOME/.local/bin/mise`. Both use that path for `mise which`, `mise use -g`, and `mise exec --`.
- Grok mise spec becomes `grok`. Copilot keeps `--allow-all`. Claude keeps `--permission-mode auto`. Codex keeps `--ask-for-approval never`. Crush keeps `--yolo` and `crush run`. Grok keeps `--permission-mode bypassPermissions`. All verified on 2026-09-01.
- `gesso-default-agent` drops `# gesso:requires-sudo=true`.

### Flatpak

- `gesso pkg add` installs Flatpaks per user. Before install it runs `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`, then `flatpak install --user -y flathub <id>`. No elevation for Flatpak. The filtered system remote is left alone.
- `gesso-app-present` keeps `flatpak info`, which sees user and system installs.

### Default editor

- `gesso default editor <id>` installs when missing, writes `~/.local/state/gesso/defaults/editor`, then runs `xdg-mime default <desktop> <mime>...` for these types: `text/plain`, `text/markdown`, `text/x-shellscript`, `application/x-shellscript`, `text/x-python`, `application/json`, `text/xml`, `application/xml`, `text/css`, `text/javascript`, `application/toml`, `application/x-yaml`.
- The desktop file comes from `gesso-app-present --desktop <id>`, so a Flatpak editor gets its Flatpak desktop id.
- `gesso default editor` with no id prints the state file id, else `unset`.

### Theme engine

- VS Code targets are a list: `~/.config/Code/User` with backup `~/.local/state/gesso/vscode-colorCustomizations.json`, and `~/.var/app/com.visualstudio.code/config/Code/User` with backup `~/.local/state/gesso/vscode-flatpak-colorCustomizations.json`. Each existing target gets the merge, `gesso-theme.json`, and its own backup.
- A hidden helper `bin/gesso-vscode-colors` owns the JSONC-tolerant Python. `gesso-vscode-colors merge <theme.json> <settings.json> <backup> <staged>` and `gesso-vscode-colors restore <settings.json> <backup>`. Both `theme set` and `theme restore` call it.
- On the first `theme set`, before changing `~/.config/konsolerc`, write the previous `DefaultProfile=` value to `~/.local/state/gesso/konsole-default-profile` (empty file when there was none). Restore puts that value back or deletes the line, then deletes the backup.
- On the first non-headless `theme set`, before `gsettings set`, write `gsettings get org.gnome.desktop.interface color-scheme` to `~/.local/state/gesso/gtk-color-scheme`. Restore sets that value back, or runs `gsettings reset` when the backup is empty, then deletes the backup.
- `theme restore` deletes `theme.name`, so `theme current` prints `unset`. It keeps `current/theme` for the mode lookup and keeps `~/.config/gesso`.
- Wallpaper: after the swap, when not headless and `plasma-apply-wallpaperimage` is on `PATH`, apply the first sorted file in `current/theme/backgrounds/` when that directory has one. Restore does not change the wallpaper. Gesso ships no images in v1.
- New templates: `default/themed/ghostty.tpl` renders to `~/.config/ghostty/themes/Gesso` when `ghostty` is on `PATH` or `~/.config/ghostty` exists. `default/themed/foot.ini.tpl` renders to `~/.config/foot/gesso-theme.ini` under the same rule for `foot`. Users opt in with `theme = Gesso` and `include=~/.config/foot/gesso-theme.ini`.
- New first-party palettes: `catppuccin-mocha` (dark), `catppuccin-latte` (light), `gruvbox-dark` (dark), `nord` (dark). Same key set as `tokyo-night`.
- Remove the dead trailing-newline block in `gesso-theme-set-templates`.

### Setup app

- `gesso-catalog-get --json --kind <kind>` prints a JSON array of catalog rows. `gesso-agent-get --json` prints a JSON array of agent rows. `gesso-app-present --list --kind <kind>` prints one present id per line in one process.
- Pages use those three calls. Defaults page: three calls per kind. Install page: two calls per kind. Agents page: two calls.
- `Main.qml` instantiates each page once and passes the item to `pageStack.replace`, so a tab switch does not reload.
- Theme Apply runs through `runAsync` like the other pages.
- Agents Launch is disabled when the current default is `unset`. Launch runs `konsole --hold -e gesso agent` so errors stay visible.
- Current-value labels read `Current: <value>`.

### Router

- `gesso --help` and `gesso commands` build the command list from `# gesso:summary=` in every non-hidden `bin/gesso-*` file. A `# gesso:requires-sudo=true` row shows `(sudo)`.
- When a command's `# gesso:args=` has a `<required>` token and the leftover argument list is empty, the router execs the command with `--help` and exits 1.
- `docs/cli.md` drops the `examples`, `group`, and `name` keys. Nothing reads them.

### Docs

- `AGENTS.md` and `README.md` say v1 is complete aside from COPR publish only after this plan lands, and name the two RPMs.
- `docs/layout.md`, `docs/cli.md`, `docs/catalog.md`, `docs/theming.md`, `docs/packaging.md`, and `docs/testing.md` match the code above.

## Not in this plan

- Retinting a running Konsole, Ghostty, or Foot.
- Restoring the wallpaper.
- Shipping wallpaper images.
- A theme install command.
