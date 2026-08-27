# Phase 4 agents design

Date: 2026-08-27

Status: draft spec. Not an implementation plan. Implementation waits on this file's approval, then `plans/2026-08-27-phase-4.md`.

## Purpose

A user picks a coding agent once. `gesso default agent grok` installs it with `mise` and stores the id. `gesso agent` launches that agent with its skip-prompt flags. No agent is default until chosen. The Setup Agents page calls the same commands.

## Constraints

- Catalog is the only source of mise packages and launch argv. No `case` of skip-prompt flags in bash.
- Default file: `~/.config/gesso/defaults/agent` (one id, trailing newline).
- Never call real `mise` in unit tests. Stub it on PATH.
- `GESSO_AGENT_DRY_RUN=1` prints cwd and argv instead of `exec`. Tests use that. Production launch `exec`s.
- If `$PWD` is `$HOME` and `$HOME/Work` exists, launch `cd`s there.
- QML must not hard-code agent ids or mise package names.
- The `gesso-agents` RPM is phase 5. Phase 4 ships these commands in the main `gesso` tree.
- Shebang `#!/bin/bash`. Two-space indent. `# gesso:summary=` on every `bin/gesso-*`.
- Do not copy Omarchy files. Steal the unset-until-chosen loop only.

## Success

- `gesso default agent` with no pick prints `unset`.
- `gesso default agent grok` logs `mise use -g npm:@xai-official/grok` (stub) and writes `grok` to the default file.
- `gesso agent` with no default exits 1 and prints `gesso default agent` on stderr.
- `gesso agent` with grok chosen and `GESSO_AGENT_DRY_RUN=1` prints a command line that contains `grok --permission-mode bypassPermissions`.
- From `$HOME` with a `Work` directory, dry-run cwd is `$HOME/Work`.
- Setup Agents page lists ids from the catalog CLI, Set default runs `gesso default agent <id>`, and has no `npm:@xai-official/grok` in QML.
- `./test/all` stays green. No real network. No real mise install.

## Architecture Quality

**Affected modules:** `data/agents.toml`, hidden agent reader, `gesso-default-agent`, `gesso-agent`, `setup/qml/AgentsPage.qml`, `test/cli.d/agent-test.sh`.

**Caller-facing interface:** `gesso default agent [id]`, `gesso agent`.

**Depth/locality check:** Parse in `gesso-agent-get`. Install in `default agent` via `mise`. Launch in `gesso-agent`. QML only execs.

**Test surface:** those commands plus dry-run. Setup grep forbids mise package strings in QML.

**Seams/adapters:** `data/agents.toml`. `mise` is an adapter behind a stub.

**Rejected shortcuts:** Bash `case` of skip-prompt flags. Hard-coded Grok in QML. Real `mise use` in CI.

**Architecture risk:** medium. Launch flags drift if they live in two places. Keep them only in TOML.

## Components

### `data/agents.toml`

One `[[agent]]` table per id. Fields:

- `id` — CLI name
- `label` — notify and Setup text
- `mise` — `mise use -g` argument
- `launch` — argv with no prompt (includes skip-prompt flags)
- `prompt_flag` — optional token inserted before a prompt (example `--`)
- `prompt_launch` — optional full argv used instead of `launch` when a prompt is passed (crush)

Present-check command is `launch[0]`.

### `bin/gesso-agent-get` (hidden)

```
# gesso:summary=Read a field from the agent catalog
# gesso:hidden=true
# gesso:args=<id> <field>|--list
```

`gesso-agent-get grok mise` prints the mise spec. `gesso-agent-get grok launch` prints space-separated argv. `--list` prints ids, one per line, catalog order. Missing id exits 1 with `Unknown agent:`. Parse with `python3` and `tomllib`.

### `bin/gesso-default-agent`

```
# gesso:summary=Set or print the default coding agent
# gesso:args=[id]
```

No args: print the file contents, or `unset`. With id: look up the row; run `mise use -g <mise>`; write the id; notify with `label` if `notify-send` exists. Unknown id: `Unknown agent: <id>` stderr, exit 1. `mise` failure: stderr, exit 1. Idempotent second set still runs `mise use -g` (mise is cheap when present) or may skip if `gesso-cmd-present` for `launch[0]` — **skip mise when the launch binary is already on PATH**, still write the default file.

### `bin/gesso-agent`

```
# gesso:summary=Launch the default coding agent
# gesso:args=
```

1. Read the default file. Missing/empty: `Choose a default agent with: gesso default agent <name>` stderr, exit 1.
2. Load `launch` (or `prompt_launch` if a prompt was passed after `--`).
3. If `gesso-cmd-present` fails for `launch[0]`: stderr that it is not installed, exit 1.
4. If `$PWD` is `$HOME` and `$HOME/Work` is a directory, `cd "$HOME/Work"`.
5. If `GESSO_AGENT_DRY_RUN` is set: print `cwd=<pwd>` and `argv=...` on stdout, exit 0.
6. Else `exec` the argv.

`--help` exits 0. This phase does not take a prompt on the CLI except via `--` leftover. If leftover args exist after a `--`, join them as one prompt: append `prompt_flag` if set, then the prompt, unless `prompt_launch` is set.

### Setup Agents page

Replace the empty state. Load ids with `gessoCli.runBinary("gesso-agent-get", ["--list"])`. Labels from `gesso-agent-get <id> label`. Current from `gesso default agent`. Set default: `gessoCli.run(["default", "agent", id])`. Launch: if `konsole` is on PATH, `gessoCli.runBinary("konsole", ["-e", "gesso", "agent"])`; else show a banner to run `gesso agent` in a terminal. No mise package strings in QML.

## Catalog rows (v1)

| id | label | mise | launch |
|---|---|---|---|
| grok | Grok | npm:@xai-official/grok | grok --permission-mode bypassPermissions |
| claude | Claude | claude | claude --permission-mode auto |
| codex | Codex | codex | codex --approve-for-me |
| opencode | OpenCode | opencode | opencode --auto |
| copilot | Copilot | copilot | copilot --allow-all |
| crush | Crush | crush | crush --yolo |
| pi | Pi | pi | pi |

Crush also sets `prompt_launch = ["crush", "run"]`. Grok and Claude set `prompt_flag = "--"`.

Do not add omp, ori, or agy in this phase (mise specs are less stable). Add them later as extra rows.

## Testing

`test/cli.d/agent-test.sh`. Extend `gesso_test_init` with a `mise` stub that logs `mise $*` and, on `use -g npm:@xai-official/grok` or `use -g grok`, writes an executable `$HOME/gesso-stubs/grok`. Same pattern: last path segment or known map; minimal: if any arg contains `grok`, write `grok`; if any arg equals `claude`, write `claude`.

Cover:

- `gesso default agent` prints `unset`
- `--help` exits 0
- `gesso default agent not-an-agent` exits 1
- `gesso default agent grok` logs mise and writes the default file; then no-args prints `grok`
- `gesso agent` before a default exits 1 and mentions `gesso default agent`
- after grok is default, `GESSO_AGENT_DRY_RUN=1 gesso agent` stdout contains `grok` and `--permission-mode bypassPermissions`
- `HOME` + `Work` dir: dry-run `cwd=` is `$HOME/Work`
- Setup: `AgentsPage.qml` has no `npm:@xai-official` and no empty-state "not in this build"
- Existing suites stay green

No network. No real mise.

## Docs this spec updates (in the implementation plan)

- `docs/cli.md`: `gesso agent`, `gesso default agent`
- `docs/catalog.md`: phase 4 ships `data/agents.toml`
- `docs/testing.md`: agent suite and mise stub
- `docs/cli.md` Setup Agents sentence: no longer empty state
- `plans/README.md`, `AGENTS.md` start-here

## Out of scope

`gesso-agents` RPM, omp/ori/agy, floating terminal installer UI, agent usage/cost commands, JSON listings.
