# Catalogs

Install, default-app, and agent rows come from data files. The Setup app and the CLI read the same files. Do not hard-code package names in QML or in `case` lists that duplicate the catalog.

Phase 2 ships `data/apps.toml`. Default commands and `gesso pkg add` read it. Phase 4 ships `data/agents.toml`. `gesso default agent` and `gesso agent` read it. Do not invent a second format.

## `data/apps.toml`

One table per app. `id` is the Gesso name used on the CLI (`gesso default browser firefox`). The file lives at `$GESSO_PATH/data/apps.toml`. `gesso default browser|terminal|editor` and `gesso pkg add` look up rows by that `id`.

```toml
[[app]]
id = "firefox"
kind = "browser"          # browser | terminal | editor | extra
label = "Firefox"
glyph = "󰈹"
desktop_id = "firefox.desktop"
command = "firefox"
dnf = ["firefox"]
flatpak = "org.mozilla.firefox"
```

Rules:

- `kind` decides which default command owns the row (`gesso default browser` only lists `kind = "browser"`).
- `dnf` is tried first, in order, with `sudo` or `pkexec`. If every RPM is missing from Fedora/RPM Fusion and `flatpak` is set, install that Flatpak per user with no elevation: `gesso pkg add` runs `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`, then `flatpak install --user -y flathub <flatpak>`. The filtered system Flathub remote that stock Fedora ships is left alone.
- `gesso-app-present <id>` is the presence check. Host first: `gesso-cmd-present` on `command`. Else `flatpak info` on `flatpak`.
- `command` is the host binary. Helix is `hx`.
- `desktop_id` is the host desktop file. When only Flatpak is present, defaults use `<flatpak>.desktop`. `gesso-app-present --desktop` returns `desktop_id` when that file exists in the XDG application directories, and falls back to `<flatpak>.desktop` when it does not, because Fedora 44 renamed some desktop files to reverse-DNS ids (`firefox.desktop` became `org.mozilla.firefox.desktop`).
- `gesso default editor <id>` writes `id` to `~/.local/state/gesso/defaults/editor`, then runs `xdg-mime default <desktop> <mime>...` with the desktop id from `gesso-app-present --desktop <id>` for these types: `text/plain`, `text/markdown`, `text/x-shellscript`, `application/x-shellscript`, `text/x-python`, `application/json`, `text/xml`, `application/xml`, `text/css`, `text/javascript`, `application/toml`, `application/x-yaml`. The launch command is `command`.

v1 browser ids: `firefox`, `chromium`, `chrome`, `brave`, `brave-origin`, `edge`. Terminal ids: `konsole`, `ghostty`, `kitty`, `foot`. Editor ids: `code`, `kate`, `nvim`, `helix`, `zed`.

Do not add a row without a tested install path on Fedora 44.

`brave-origin` is the one row that does not meet that bar. Brave Origin ships only from Brave's own RPM repository, and `gesso pkg add brave-origin` therefore succeeds only on a machine where the user has already run `dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo`. Gesso cannot add that repository itself, because writing `/etc/yum.repos.d/` is a hard no in [`../AGENTS.md`](../AGENTS.md). With the repo absent, `dnf install` fails, the empty `flatpak` field skips the Flatpak fallback, and `gesso pkg add` prints `failed to install brave-origin` and exits 1. `gesso default browser brave-origin` still works once the browser is installed by any means. See [`../TODO.md`](../TODO.md).

## `data/agents.toml`

The file lives at `$GESSO_PATH/data/agents.toml`. `gesso default agent` and `gesso agent` look up rows by `id`.

```toml
[[agent]]
id = "grok"
label = "Grok"
mise = "grok"
launch = ["grok", "--permission-mode", "bypassPermissions"]
prompt_flag = "--"
```

- No agent is default until the user runs `gesso default agent <id>`.
- If `mise` is missing from `PATH` and `~/.local/bin/mise`, `gesso default agent` installs it per user with `curl -fsSL https://mise.run | MISE_INSTALL_PATH=$HOME/.local/bin/mise sh`. No `dnf`, `sudo`, or `pkexec`.
- If `mise which <launch_bin>` fails, install is `mise use -g <mise>`. Recheck `mise which`. Write the default file only after that check succeeds.
- Launch is `mise exec -- <launch...>` when `mise` is on PATH. Else the host binary.
- Launch cwd: if `$PWD` is `$HOME` and `$HOME/Work` exists, `cd` there (agents refuse to trust `$HOME`).
- `gesso agent` with none chosen exits 1 and prints `gesso default agent <name>`. The Setup app opens the Agents page instead.

Launch flags (keep in the TOML, not in a `case`):

| id | skip-prompt shape |
|---|---|
| claude | `--permission-mode auto` |
| grok | `--permission-mode bypassPermissions` |
| codex | `--ask-for-approval never` |
| opencode | `--auto` |
| copilot | `--allow-all` |
| crush | `--yolo` / `crush run` when a prompt is passed |

## Install-then-default

For defaults and extra apps:

1. If `gesso-app-present <id>` exits 0, skip install.
2. Else run `gesso pkg add` for `dnf` (elevated), or a per-user Flatpak from the user `flathub` remote (no elevation), as the row says.
3. Then set the default (XDG or state file).
4. Notify with `label`.

The Setup GUI must not implement a second installer. It calls `gesso default browser firefox` and `gesso pkg add …`.
