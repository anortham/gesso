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
grep -Fq '"theme", "list"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme list"
grep -Fq '"theme", "set"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme set"
grep -q 'runAsync' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage apply uses runAsync"
pass "ThemePage wires list and async set"

grep -Fq '"theme", "list", "--json"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme list with --json"
grep -Fq '"theme", "undo"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme undo"
grep -Fq '"theme", "restore"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage calls theme restore"
grep -Fq '"--wallpaper"' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage supports wallpaper selection"
pass "ThemePage wires visual gallery and recovery actions"

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
grep -q 'agent-get' "$ROOT/setup/qml/AgentsPage.qml" || fail "AgentsPage uses agent-get"
grep -q 'default' "$ROOT/setup/qml/AgentsPage.qml" || fail "AgentsPage calls default agent"
if grep -Eq 'npm:@xai-official|not in this build' "$ROOT/setup/qml/AgentsPage.qml"; then
  fail "AgentsPage has no mise specs or empty-state copy"
fi
pass "AgentsPage uses agent catalog CLI"

hits=$(grep -REq 'firefox\.desktop|org\.mozilla\.firefox|org\.chromium\.Chromium|com\.google\.Chrome' "$ROOT/setup" && echo yes || echo no)
[[ $hits == "no" ]] || fail "setup tree has no hardcoded catalog ids"
pass "setup tree has no hardcoded catalog ids"

if grep -RFq 'waitForFinished' "$ROOT/setup"; then
  fail "setup has no blocking waitForFinished"
fi
pass "setup has no blocking waitForFinished"

if grep -RFq 'waitForStarted' "$ROOT/setup"; then
  fail "setup has no blocking waitForStarted"
fi
pass "setup has no blocking waitForStarted"

if grep -RFq 'if (m_process) return;' "$ROOT/setup"; then
  fail "GessoCli does not lock out on single active process"
fi
pass "GessoCli does not lock out on single active process"

grep -Fq 'commandFinished(' "$ROOT/setup/GessoCli.hpp" || fail "GessoCli declares commandFinished signal"
pass "GessoCli declares commandFinished signal"

grep -Fq 'QJSValue' "$ROOT/setup/GessoCli.hpp" || fail "GessoCli supports QJSValue callback"
pass "GessoCli supports QJSValue callback"

grep -Fq 'runQueryAsync(' "$ROOT/setup/GessoCli.hpp" || fail "GessoCli declares runQueryAsync"
pass "GessoCli declares runQueryAsync"

if grep -REq 'tokyo-night|breeze|firefox|chromium|konsole|ghostty|kitty' "$ROOT/setup/GessoCli."*; then
  fail "GessoCli has no hardcoded theme, app, or terminal policy"
fi
pass "GessoCli has no hardcoded theme, app, or terminal policy"

grep -q 'startDetached' "$ROOT/setup/qml/AgentsPage.qml" || fail "Launch Agent uses startDetached"
grep -q 'gesso-app-present' "$ROOT/setup/qml/AgentsPage.qml" || fail "Launch Agent uses gesso-app-present"
pass "Launch Agent detaches Konsole"

grep -q 'runAsync' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage apply uses runAsync"
grep -q 'runAsync' "$ROOT/setup/qml/InstallPage.qml" || fail "InstallPage install uses runAsync"
pass "Defaults and Install apply asynchronously"

grep -Fq '"--json"' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage loads rows with --json"
grep -Fq '"--list"' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage loads presence with --list"
grep -Fq '"--json"' "$ROOT/setup/qml/InstallPage.qml" || fail "InstallPage loads rows with --json"
grep -Fq '"--list"' "$ROOT/setup/qml/InstallPage.qml" || fail "InstallPage loads presence with --list"
grep -Fq '"--json"' "$ROOT/setup/qml/AgentsPage.qml" || fail "AgentsPage loads rows with --json"
pass "pages load rows and presence with list commands"

if grep -RFq '[id, "label"]' "$ROOT/setup/qml"; then
  fail "no page reads labels one id at a time"
fi
pass "no page reads labels one id at a time"

grep -Fq '"--hold"' "$ROOT/setup/qml/AgentsPage.qml" || fail "Launch Agent keeps Konsole open with --hold"
grep -Fq 'page.current !== "unset"' "$ROOT/setup/qml/AgentsPage.qml" || fail "Launch is disabled without a default agent"
pass "Launch Agent holds Konsole and needs a default"

if grep -Fq 'Component {' "$ROOT/setup/qml/Main.qml"; then
  fail "Main.qml instantiates pages once"
fi
grep -Fq 'pageStack.replace(' "$ROOT/setup/qml/Main.qml" || fail "Main.qml replaces pages on the stack"
pass "Main.qml instantiates pages once"

grep -Fq '"Current: " + page.currentTheme' "$ROOT/setup/qml/ThemePage.qml" || fail "ThemePage labels the current theme"
grep -Fq '"Current: " + groupBox.group.current' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage labels the current default"
grep -Fq '"Current: " + page.current' "$ROOT/setup/qml/AgentsPage.qml" || fail "AgentsPage labels the current agent"
pass "current-value labels read Current:"
