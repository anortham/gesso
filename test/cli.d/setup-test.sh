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

[[ -f $ROOT/setup/CMakeLists.txt ]] || fail "setup CMakeLists exists"
[[ -f $ROOT/setup/qml/Main.qml ]] || fail "setup Main.qml exists"
pass "setup skeleton files exist"

[[ -f $ROOT/setup/qml/ThemePage.qml ]] || fail "ThemePage.qml exists"
grep -q 'theme list' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme list"
grep -q 'theme set' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme set"
pass "ThemePage wires list and set"

[[ -f $ROOT/setup/qml/DefaultsPage.qml ]] || fail "DefaultsPage.qml exists"
grep -q 'catalog-get' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage uses catalog-get"
grep -q 'default' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage calls default"
if grep -Eq 'firefox\.desktop|org\.mozilla\.firefox' "$ROOT/setup/qml/DefaultsPage.qml"; then
  fail "DefaultsPage has no hardcoded firefox ids"
fi
pass "DefaultsPage uses catalog CLI"

[[ -f $ROOT/setup/org.gesso.setup.desktop ]] || fail "desktop file exists"
desktop=$(cat "$ROOT/setup/org.gesso.setup.desktop")
[[ $desktop == *'Exec=gesso setup'* ]] || fail "desktop Exec is gesso setup" "$desktop"
pass "desktop Exec is gesso setup"

[[ -f $ROOT/setup/qml/AgentsPage.qml ]] || fail "AgentsPage.qml exists"
if grep -Eq 'mise|gesso agent' "$ROOT/setup/qml/AgentsPage.qml"; then
  fail "Agents page does not install agents"
fi
pass "Agents page is empty state"

hits=$(grep -REq 'firefox\.desktop|org\.mozilla\.firefox|org\.chromium\.Chromium|com\.google\.Chrome' "$ROOT/setup" && echo yes || echo no)
[[ $hits == "no" ]] || fail "setup tree has no hardcoded catalog ids"
pass "setup tree has no hardcoded catalog ids"
