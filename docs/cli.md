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

A command whose `args` metadata has a required token, invoked with no args, prints usage instead of running.

## Metadata

Scan the first 80 lines of each `bin/gesso-*` file, stop at the first non-comment line.

| Key | Meaning |
|---|---|
| `# gesso:summary=` | One-line help. Required for user-facing commands |
| `# gesso:args=` | Usage tokens. `[optional]`. Required tokens mean bare invocation prints help |
| `# gesso:examples=` | Pipe-separated examples. Only when args need showing |
| `# gesso:group=` | Override group inferred from the filename |
| `# gesso:name=` | Override name inferred from the filename |
| `# gesso:hidden=true` | Callable, omitted from default listings |
| `# gesso:requires-sudo=true` | Privilege marker for help text |

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

`gesso theme current` prints the name in `~/.local/state/gesso/current/theme.name`, or `unset` when that file is missing or empty.

`gesso theme restore` applies `BreezeDark` or `Breeze` when Gesso last set a theme. `light` mode selects `Breeze`. Otherwise `BreezeDark`. Missing `theme.name` exits 0. Headless tests skip Plasma and still exit 0. It does not delete `~/.config/gesso` or `~/.local/state/gesso`. Run it before `dnf remove` if Gesso is the active scheme.

`gesso default browser firefox` installs Firefox when it is missing, then sets the XDG default browser to `firefox.desktop`. `gesso default terminal [id]` and `gesso default editor [id]` use the same catalog loop for `xdg-terminals.list` and `~/.local/state/gesso/defaults/editor`. No id prints the current catalog id, or `unset`.

`gesso pkg add firefox` installs that catalog row: dnf first, then Flatpak if dnf is empty or the command is still missing. Skip install when the catalog `command` is already on `PATH`. Ids match `data/apps.toml` (`firefox`, not `Firefox`).

`gesso default agent grok` installs Grok with `mise use -g` when the launch binary is missing, then writes `grok` to `~/.config/gesso/defaults/agent`. No id prints the current id, or `unset`. Unknown ids exit 1 with `Unknown agent:`.

`gesso agent` launches that default with the skip-prompt argv from `data/agents.toml`. With no default it exits 1 and prints `gesso default agent`. If `$PWD` is `$HOME` and `$HOME/Work` exists, launch changes to that directory. `GESSO_AGENT_DRY_RUN=1` prints `cwd=` and `argv=` instead of `exec`. Tests use that. Production launch uses `exec`.

`gesso setup` opens the Kirigami Setup window. `--help` works with no Qt. If the compiled binary is missing, stderr prints `cmake -S setup -B setup/build && cmake --build setup/build` and the command exits 1. The window has Theme, Defaults, Install, and Agents pages. Every action execs `gesso-*`. The Agents page lists catalog ids, sets the default with `gesso default agent <id>`, and launches via Konsole when present.

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

`gesso commands --json` is optional until something needs to parse it. Phase 0 can print text only.
