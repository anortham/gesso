# CLI

`bin/gesso` maps spaced commands onto `bin/gesso-*`. There is no registry file. Every executable `bin/gesso-*` is a command. Its filename is the default route.

`gesso theme list` becomes `exec bin/gesso-theme-list`. `gesso theme set tokyo-night` becomes `exec bin/gesso-theme-set tokyo-night`. `gesso theme current` becomes `exec bin/gesso-theme-current`. `gesso theme restore` becomes `exec bin/gesso-theme-restore`. `gesso default browser firefox` becomes `exec bin/gesso-default-browser firefox`. `gesso default agent grok` becomes `exec bin/gesso-default-agent grok`. `gesso pkg add firefox` becomes `exec bin/gesso-pkg-add firefox`. `gesso agent` becomes `exec bin/gesso-agent`. `gesso setup` becomes `exec bin/gesso-setup`.

## Resolution

The stem after `gesso-` splits at the first hyphen: `gesso-theme-set` is group `theme` and name `set`. Remaining hyphens become spaces (`gesso-default-browser` → group `default`, name `browser`).

Fast path: join the argument list with hyphens and probe for an executable, longest prefix first.

```
gesso theme set foo
  probe gesso-theme-set-foo
  probe gesso-theme-set     ← hit, leftover arg: foo
```

If no filename matches and the only argument is a group with non-hidden children, print that group's commands and exit 0. Hidden commands stay callable and stay out of listings.

`--help` / `-h` anywhere in the leftover arguments shows help and must not run the command. A `--` ends that scan. `--help` after `--` is passed through to the command.

A command whose `# gesso:args=` has a `<required>` token, called with no leftover arguments, does not run. The router prints that command's `--help` on stderr and exits 1.

## Generated help

`gesso --help` and `gesso commands` print the same text. The router builds the command list at run time from every executable `bin/gesso-*` that is not hidden. Each row shows the spaced name and its `# gesso:summary=`. A command with `# gesso:requires-sudo=true` gets ` (sudo)` after its summary. Rows sort by name. A static `commands` row is added at the end. There is no hand-written command list to keep in sync.

## Metadata

Scan the first 80 lines of each `bin/gesso-*` file, stop at the first non-comment line. The router reads four keys.

| Key | Meaning |
|---|---|
| `# gesso:summary=` | One-line help. Required for every command |
| `# gesso:args=` | Usage tokens. `[optional]` or `<required>`. A `<required>` token means bare invocation prints help and exits 1 |
| `# gesso:hidden=true` | Callable, omitted from `gesso --help` and group listings |
| `# gesso:requires-sudo=true` | Adds `(sudo)` to the help row |

Unknown keys are ignored. A missing summary fails `./test/cli` metadata lint.

## Groups (v1)

| Group | Purpose |
|---|---|
| `theme` | List, set, restore themes |
| `default` | Browser, terminal, editor, agent |
| `pkg` | dnf / Flatpak helpers |
| `agent` | Launch and select coding agents |
| `setup` | Open the Kirigami Setup app |

Phase 0 implements the router and `gesso theme list`. Phase 1 adds `theme set`. Phase 2 adds `default` and `pkg`. Phase 3 adds `gesso setup` and `gesso theme current`. Phase 4 adds `gesso default agent` and `gesso agent`. Phase 5 adds `gesso theme restore`.

`gesso theme list` prints first-party themes from `$GESSO_PATH/themes/` and user themes from `~/.config/gesso/themes/`. Five first-party themes ship: `tokyo-night`, `catppuccin-mocha`, `catppuccin-latte`, `gruvbox-dark`, and `nord`. `catppuccin-latte` is light. The rest are dark.

`gesso theme current` prints the name in `~/.local/state/gesso/current/theme.name`, or `unset` when that file is missing or empty.

`gesso theme restore` undoes what `gesso theme set` changed on the live system. It restores `workbench.colorCustomizations` in both VS Code locations (`~/.config/Code/User` and `~/.var/app/com.visualstudio.code/config/Code/User`) from the backups under `~/.local/state/gesso/`. It puts the previous Konsole `DefaultProfile=` back in `~/.config/konsolerc`. It deletes `theme.name`, so `gesso theme current` prints `unset`. When Gesso last set a theme and a session is available, it applies `BreezeLight` for `light` mode or `BreezeDark` otherwise, then puts the GTK color scheme back. It does not restore the wallpaper. Missing `theme.name` exits 0. Headless tests skip Plasma and GTK and still exit 0. It keeps `~/.config/gesso` and `~/.local/state/gesso/current/theme`. Run it before `dnf remove` if Gesso is the active scheme. See [`theming.md`](theming.md) for the backup files.

`gesso default browser firefox` installs Firefox when it is missing, then sets the XDG default browser to the desktop id from `gesso-app-present --desktop firefox`. `gesso default terminal [id]` uses the same catalog loop for `xdg-terminals.list`. `gesso default editor [id]` writes the id to `~/.local/state/gesso/defaults/editor`, then runs `xdg-mime default <desktop> <mime>...` for twelve text types (`text/plain`, `text/markdown`, `text/x-shellscript`, `application/x-shellscript`, `text/x-python`, `application/json`, `text/xml`, `application/xml`, `text/css`, `text/javascript`, `application/toml`, `application/x-yaml`). The desktop id comes from `gesso-app-present --desktop <id>`, so a Flatpak editor gets its Flatpak desktop id. No id prints the current catalog id, or `unset`.

`gesso pkg add firefox` installs that catalog row: dnf first, then Flatpak if dnf is empty or the command is still missing. dnf runs with `sudo` or `pkexec`. Flatpak runs per user with no elevation: `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`, then `flatpak install --user -y flathub <id>`. Skip install when the catalog `command` is already on `PATH`. Ids match `data/apps.toml` (`firefox`, not `Firefox`).

`gesso default agent grok` installs Grok with `mise use -g` when the launch binary is missing, then writes `grok` to `~/.config/gesso/defaults/agent`. `mise` is not a Fedora package. When `mise` is not on `PATH` and `~/.local/bin/mise` is missing, the command installs it per user with `curl -fsSL https://mise.run | MISE_INSTALL_PATH=$HOME/.local/bin/mise sh`. No `sudo`, no `pkexec`, no `dnf`. No id prints the current id, or `unset`. Unknown ids exit 1 with `Unknown agent:`.

`gesso agent` launches that default with the skip-prompt argv from `data/agents.toml`. It finds `mise` on `PATH`, else at `~/.local/bin/mise`, and launches with `<mise> exec -- <argv>`. With no `mise` it runs the host binary. With no default it exits 1 and prints `gesso default agent`. If `$PWD` is `$HOME` and `$HOME/Work` exists, launch changes to that directory. `GESSO_AGENT_DRY_RUN=1` prints `cwd=` and `argv=` instead of `exec`. Tests use that. Production launch uses `exec`.

`gesso setup` opens the Kirigami Setup window. `--help` works with no Qt. The launcher checks `$GESSO_SETUP_BIN`, then `setup/build/bin/gesso-setup` and `setup/build/gesso-setup` under `$GESSO_ROOT` or `$GESSO_PATH`, then `/usr/libexec/gesso/gesso-setup`. It does not scan `PATH`. If no binary is found, stderr prints `cmake -S setup -B setup/build && cmake --build setup/build` and the command exits 1. That build puts the binary at `setup/build/bin/gesso-setup`, because KDECMakeSettings sets the runtime output directory to `bin/`. The window has Theme, Defaults, Agents, and Install pages, in that order. Each page is built once and stays alive across tab switches. Every action execs `gesso-*`. Theme Apply, default changes, and installs run asynchronously. The Agents page lists catalog ids, sets the default with `gesso default agent <id>`, and launches with `konsole --hold -e gesso agent` when Konsole is present. Launch is disabled while the default is `unset`.

## Hidden helpers

These commands set `# gesso:hidden=true`. They stay callable and stay out of listings. The Setup app and the user-facing commands call them.

- `gesso-catalog-get <id> <field>`, `--kind <kind>`, or `--json --kind <kind>`: read one field, list ids of one kind, or print a JSON array of the rows of one kind from `data/apps.toml`.
- `gesso-agent-get <id> <field>`, `--list`, or `--json`: read one field, list ids, or print a JSON array of every row from `data/agents.toml`.
- `gesso-app-present [--desktop] <id>` or `--list --kind <kind>`: exit 0 when the app is on the host or as a Flatpak, print its desktop id, or print every present id of one kind in one process.
- `gesso-cmd-present <command>...`: exit 0 when every named command is on `PATH`.
- `gesso-vscode-colors merge <theme.json> <settings.json> <backup> <staged>` or `restore <settings.json> <backup>`: merge or restore `workbench.colorCustomizations`. The only JSONC parser.
- `gesso-theme-set-templates`: render the theme templates into `$GESSO_NEXT_THEME`. `gesso theme set` calls it.

## `$GESSO_PATH`

Commands read data from `$GESSO_PATH`. Packaged install uses `/usr/share/gesso`. There is no `environment.d` file. Tests export it to the repo root. The router, when `$GESSO_PATH` is unset and it can see `themes/` next to `bin/`, sets it to the checkout root so `./bin/gesso theme list` works in development. When that probe fails, the router sets `$GESSO_PATH=/usr/share/gesso`.

Do not fall back to `$HOME`.

## Help

```
gesso --help
gesso commands
gesso theme
gesso theme list --help
gesso theme current
gesso theme restore
gesso default browser --help
gesso default browser firefox
gesso default agent --help
gesso default agent grok
gesso pkg add firefox
gesso agent
gesso setup --help
gesso setup
```

`gesso commands --json` is optional until something needs to parse it. The router prints text only.
