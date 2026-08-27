#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

if [[ ! -x $ROOT/bin/gesso-agent-get ]]; then
  fail "gesso-agent-get is executable" "phase 4 agent reader is missing"
fi
pass "gesso-agent-get is executable"

got=$(gesso-agent-get grok mise)
[[ $got == "npm:@xai-official/grok" ]] || fail "grok mise spec" "$got"
pass "grok mise spec"

launch=$(gesso-agent-get grok launch)
[[ $launch == *"bypassPermissions"* ]] || fail "grok launch flags" "$launch"
pass "grok launch flags"

ids=$(gesso-agent-get --list)
[[ $ids == *grok* ]] || fail "list includes grok" "$ids"
[[ $ids == *claude* ]] || fail "list includes claude" "$ids"
pass "agent list includes grok and claude"

if gesso-agent-get not-an-agent mise >/tmp/gesso-ag-unknown 2>&1; then
  fail "unknown agent exits non-zero"
fi
pass "unknown agent exits non-zero"

cur=$(gesso default agent)
[[ $cur == "unset" ]] || fail "no default agent is unset" "$cur"
pass "no default agent is unset"

if gesso default agent --help >/dev/null 2>&1; then
  :
else
  fail "gesso default agent --help exits 0"
fi
pass "gesso default agent --help exits 0"

if gesso default agent not-an-agent >/tmp/gesso-da-unknown 2>&1; then
  fail "unknown default agent exits non-zero"
fi
pass "unknown default agent exits non-zero"

rm -f "$HOME/gesso-stub.log" "$HOME/gesso-stubs/grok"
gesso default agent grok
got=$(gesso default agent)
[[ $got == "grok" ]] || fail "default agent grok prints grok" "$got"
[[ -f $HOME/.config/gesso/defaults/agent ]] || fail "agent default file exists"
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"mise use -g npm:@xai-official/grok"* ]] || fail "mise use grok logged" "$log"
pass "default agent grok installs with mise"

rm -f "$HOME/gesso-stub.log"
gesso default agent grok
log=$(cat "$HOME/gesso-stub.log" 2>/dev/null || true)
[[ $log == *"mise use"* ]] && fail "second default agent grok skips mise" "$log"
pass "default agent grok is idempotent when present"

rm -f "$HOME/.config/gesso/defaults/agent"
if gesso agent >/tmp/gesso-agent-none 2>&1; then
  fail "agent without default exits non-zero"
fi
none=$(cat /tmp/gesso-agent-none)
[[ $none == *"gesso default agent"* ]] || fail "agent unset message" "$none"
pass "agent without default exits non-zero"

gesso default agent grok
out=$(GESSO_AGENT_DRY_RUN=1 gesso agent)
[[ $out == *"argv="*"grok"* ]] || fail "dry-run argv has grok" "$out"
[[ $out == *bypassPermissions* ]] || fail "dry-run has skip-prompt flag" "$out"
pass "agent dry-run prints grok launch argv"

mkdir -p "$HOME/Work"
out=$(cd "$HOME" && GESSO_AGENT_DRY_RUN=1 gesso agent)
[[ $out == *"cwd=$HOME/Work"* ]] || fail "launch from HOME uses Work" "$out"
pass "launch from HOME uses Work"
