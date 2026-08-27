#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

cur=$(gesso theme current)
[[ $cur == "unset" ]] || fail "theme current unset without state" "$cur"
pass "theme current unset without state"

export GESSO_THEME_HEADLESS=1
gesso theme set tokyo-night
cur=$(gesso theme current)
[[ $cur == "tokyo-night" ]] || fail "theme current after set" "$cur"
pass "theme current after set"

if gesso setup --help >/dev/null 2>&1; then
  :
else
  fail "gesso setup --help exits 0"
fi
help=$(gesso setup --help)
[[ $help == *Setup* ]] || fail "setup help mentions Setup" "$help"
pass "gesso setup --help exits 0"

if GESSO_SETUP_BIN=/no/such/gesso-setup gesso setup >/tmp/gesso-setup-missing 2>&1; then
  fail "missing setup binary exits non-zero"
fi
pass "missing setup binary exits non-zero"
