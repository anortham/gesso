# Installed-system agent skill

Gesso ships `default/agents/skills/gesso/SKILL.md` in the CLI package, installed under `/usr/share/gesso/default/agents/skills/gesso/`. It teaches agents to customize an installed Fedora KDE desktop through Gesso’s commands, user palettes, template overrides, and hooks, then verify or recover the result. Repository development continues to use `AGENTS.md`.

## Registration

`gesso default agent <id>` registers the skill after verifying the selected executable and before saving the default. A real `gesso agent` launch also registers it, covering users who selected their agent before this feature was installed. Current-choice queries, help, and `GESSO_AGENT_DRY_RUN=1` do not register skills.

Run `gesso agent skills` to register it without selecting or launching an agent. It links the skill directory from `$GESSO_PATH`; no provider request, agent installation, or elevation is involved. Package upgrades update the linked instructions in place. Restart an existing agent session to refresh its skill discovery.

Existing files, directories, and foreign symlinks named `gesso` are preserved, with a diagnostic identifying the skipped location. Gesso does not overwrite them or replace an earlier checkout’s symlink; reconcile a reported collision explicitly if you want the packaged skill there.

## Discovery locations

| Agents | Global location |
|---|---|
| Codex, OpenCode, Copilot CLI, Grok, Cursor Agent, Pi, Crush | `~/.agents/skills/gesso` |
| Claude Code | `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/gesso` |
| Antigravity CLI (`agy`) | `~/.gemini/antigravity-cli/skills/gesso` |
| Oh My Pi | Active native agent directory’s `skills/gesso`; normally `~/.omp/agent/skills/gesso` |

These are supported by current agent documentation: [Codex](https://developers.openai.com/codex/skills), [OpenCode](https://opencode.ai/docs/skills), [Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference), [Grok](https://docs.x.ai/build/features/skills-plugins-marketplaces), [Cursor](https://prod.cursor.com/docs/skills), [Pi](https://pi.dev/docs/latest/skills), [Crush](https://github.com/charmbracelet/crush/blob/main/README.md), [Claude](https://code.claude.com/docs/en/skills), and [Antigravity CLI](https://antigravity.google/docs/cli/plugins).

Oh My Pi’s shared foreign-provider discovery is optional, so Gesso uses its native directory. Following its [directory resolver](https://github.com/can1357/oh-my-pi/blob/main/packages/utils/src/dirs.ts), the base is `$HOME/${PI_CONFIG_DIR:-.omp}`. `OMP_PROFILE` takes precedence over `PI_PROFILE`, including an explicitly empty value. A trimmed empty or `default` profile uses `${PI_CODING_AGENT_DIR:-<base>/agent}`; named profiles use `<base>/profiles/<name>/agent` and ignore that override. Registration and removal use the currently configured directory; repeat removal with any earlier custom home/profile settings if you registered there too.

Antigravity’s IDE has a separate discovery location; Gesso’s catalog selects its CLI. No IDE configuration is changed. Old agent versions may require updating before they recognize these skill locations.

Ori Code has no independently documented global discovery location. Ask it to read the packaged skill explicitly, for example `gesso agent -- "Read /usr/share/gesso/default/agents/skills/gesso/SKILL.md and help customize my desktop"` when Ori is selected. Substitute your install root when using a checkout. Gesso does not fabricate an Ori skill directory or change the agent’s prompts automatically.

## Removal

Run `gesso agent skills --remove` before uninstalling Gesso. It removes only discovery symlinks pointing to this install’s skill, including dangling links when the source disappeared. User-authored skills and links to other locations remain. Agent directories and unrelated configuration remain intact. RPM uninstall scriptlets do not modify users’ homes.

If Gesso’s theme is active, also run `gesso theme restore` before package removal. Skill registration and removal do not alter palettes, app defaults, provider credentials, or agent approval settings.
