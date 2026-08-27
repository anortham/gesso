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
