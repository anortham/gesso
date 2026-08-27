#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

if grep -q '/usr/libexec/gesso/gesso-setup' "$ROOT/bin/gesso-setup"; then
  :
else
  fail "launcher mentions libexec gesso-setup"
fi
pass "launcher mentions libexec gesso-setup"

if grep -q 'path_dirs' "$ROOT/bin/gesso-setup"; then
  fail "launcher must not scan PATH for gesso-setup"
fi
pass "launcher does not scan PATH"

if GESSO_SETUP_BIN=/no/such/gesso-setup gesso setup >/tmp/gesso-setup-missing 2>&1; then
  fail "missing setup binary exits non-zero"
fi
pass "missing setup binary still exits non-zero"
