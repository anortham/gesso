#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

gesso default agent grok
source_skill=$GESSO_PATH/default/agents/skills/gesso
[[ -f $HOME/.agents/skills/gesso/SKILL.md ]] || fail "agent selection makes the Gesso skill discoverable"
[[ $(readlink "$HOME/.agents/skills/gesso") == "$source_skill" ]] || fail "agent skills link to the install root"
for dir in "$HOME/.claude/skills" "$HOME/.gemini/antigravity-cli/skills" "$HOME/.omp/agent/skills"; do
  [[ -f $dir/gesso/SKILL.md ]] || fail "registration covers the dedicated skill directory $dir"
done
pass "agent selection makes the Gesso skill discoverable"

gesso agent skills
gesso agent skills
[[ $(readlink "$HOME/.agents/skills/gesso") == "$source_skill" ]] || fail "skill registration is idempotent"
pass "skill registration is idempotent"

rm "$HOME/.agents/skills/gesso"
mkdir "$HOME/.agents/skills/gesso"
printf 'user skill\n' >"$HOME/.agents/skills/gesso/SKILL.md"
gesso agent skills >"$HOME/skill-conflict" 2>&1
[[ $(<"$HOME/.agents/skills/gesso/SKILL.md") == "user skill" ]] || fail "registration preserves a user skill directory"
pass "registration preserves a user skill directory"

gesso agent skills --remove
[[ -f $HOME/.agents/skills/gesso/SKILL.md ]] || fail "removal preserves a user skill directory"
[[ ! -L $HOME/.claude/skills/gesso ]] || fail "removal unlinks the packaged skill"
pass "removal unlinks only the packaged skill"

rm -rf "$HOME/.agents/skills/gesso"
mkdir -p "$HOME/foreign-skill"
ln -s "$HOME/foreign-skill" "$HOME/.agents/skills/gesso"
gesso agent skills >"$HOME/skill-conflict" 2>&1
gesso agent skills --remove
[[ $(readlink "$HOME/.agents/skills/gesso") == "$HOME/foreign-skill" ]] || fail "registration and removal preserve a foreign symlink"
pass "registration and removal preserve a foreign symlink"

rm "$HOME/.agents/skills/gesso"
gesso agent
[[ -f $HOME/.agents/skills/gesso/SKILL.md ]] || fail "launch registers skills for an existing default"
pass "launch registers skills for an existing default"

gesso agent skills --remove
mkdir -p "$HOME/installed root"
cp -a "$ROOT/default" "$HOME/installed root/"
GESSO_PATH="$HOME/installed root" gesso agent skills
[[ $(readlink "$HOME/.agents/skills/gesso") == "$HOME/installed root/default/agents/skills/gesso" ]] || fail "registration honors a packaged root with spaces"
pass "registration honors a packaged root with spaces"

mv "$HOME/installed root/default/agents/skills/gesso" "$HOME/removed-skill"
GESSO_PATH="$HOME/installed root" gesso agent skills --remove
[[ ! -L $HOME/.agents/skills/gesso ]] || fail "removal works after the skill payload disappears"
pass "removal works after the skill payload disappears"

if GESSO_PATH="$HOME/missing root" gesso agent skills >"$HOME/skill-missing" 2>&1; then
  fail "registration rejects a missing skill payload"
fi
[[ ! -e $HOME/.agents/skills/gesso && ! -L $HOME/.agents/skills/gesso ]] || fail "missing payload does not create dangling discovery links"
pass "missing payload does not create dangling discovery links"

if gesso agent skills unexpected >"$HOME/skill-usage" 2>&1; then
  fail "skill registration rejects unknown arguments"
fi
pass "skill registration rejects unknown arguments"

custom_claude="$HOME/custom claude"
CLAUDE_CONFIG_DIR="$custom_claude" gesso agent skills
[[ -f $custom_claude/skills/gesso/SKILL.md ]] || fail "registration honors Claude's configured skill directory"
pass "registration honors Claude's configured skill directory"

ignored_agent="$HOME/ignored agent"
OMP_PROFILE="work" PI_PROFILE="other" PI_CODING_AGENT_DIR="$ignored_agent" gesso agent skills
[[ -f $HOME/.omp/profiles/work/agent/skills/gesso/SKILL.md ]] || fail "registration honors the active OMP profile"
[[ ! -e $ignored_agent/skills/gesso ]] || fail "named OMP profiles ignore the default agent-directory override"
pass "registration honors the active OMP profile"

custom_agent="$HOME/custom agent"
OMP_PROFILE="" PI_PROFILE="other" PI_CODING_AGENT_DIR="$custom_agent" gesso agent skills
[[ -f $custom_agent/skills/gesso/SKILL.md ]] || fail "an empty OMP profile selects its configured default directory"
pass "an empty OMP profile selects its configured default directory"
