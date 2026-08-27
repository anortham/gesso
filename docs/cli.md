# CLI

`bin/gesso` maps spaced commands onto `bin/gesso-*`. There is no registry file. Every executable `bin/gesso-*` is a command. Its filename is the default route.

`gesso theme list` becomes `exec bin/gesso-theme-list`. `gesso theme set tokyo-night` becomes `exec bin/gesso-theme-set tokyo-night`.

## Resolution

The stem after `gesso-` splits at the first hyphen: `gesso-theme-set` is group `theme` and name `set`. Remaining hyphens become spaces (`gesso-default-browser` → group `default`, name `browser`).

Fast path: join the argument list with hyphens and probe for an executable, longest prefix first.

```
gesso theme set foo
  probe gesso-theme-set-foo
  probe gesso-theme-set     ← hit, leftover arg: foo
```

If no filename matches, load metadata headers and resolve against `# gesso:name=` / `# gesso:group=` / aliases. Phase 0 only needs the fast path plus `--help`.

`--help` / `-h` anywhere in the leftover arguments shows help and must not run the command. A `--` ends that scan.

A bare group with children (`gesso theme`) prints that group's commands. A command whose `args` metadata has a required token, invoked with no args, prints usage instead of running.

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
| `theme` | List, set, install themes |
| `default` | Browser, terminal, editor |
| `pkg` | dnf / Flatpak helpers |
| `agent` | Launch and select coding agents |
| `setup` | Open the Kirigami Setup app |

Phase 0 implements the router and `gesso theme list`. Phase 1 adds `theme set`.

## `$GESSO_PATH`

Commands read data from `$GESSO_PATH`. Packaged install sets it to `/usr/share/gesso` (environment.d or the wrapper). Tests export it to the repo root. The router, when `$GESSO_PATH` is unset and it can see `themes/` next to `bin/`, sets it to the checkout root so `./bin/gesso theme list` works in development.

Do not fall back to `$HOME`.

## Help

```
gesso --help
gesso commands
gesso theme --help
gesso theme list --help
```

`gesso commands --json` is optional until something needs to parse it. Phase 0 can print text only.
