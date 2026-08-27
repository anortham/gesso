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

if gesso theme restore --help >/dev/null 2>&1; then
  :
else
  fail "gesso theme restore --help exits 0"
fi
pass "gesso theme restore --help exits 0"

export GESSO_THEME_HEADLESS=1
gesso theme restore
pass "headless restore with no theme exits 0"

gesso theme set tokyo-night
gesso theme restore
pass "headless restore after tokyo-night exits 0"

unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night
rm -f "$HOME/gesso-stub.log"
gesso theme restore
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"plasma-apply-colorscheme BreezeDark"* ]] || fail "restore applies BreezeDark" "$log"
pass "restore applies BreezeDark for dark theme"
export GESSO_THEME_HEADLESS=1
