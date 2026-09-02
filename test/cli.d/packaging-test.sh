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

[[ -f $ROOT/LICENSE ]] || fail "LICENSE exists"
[[ -f $ROOT/packaging/gesso.spec ]] || fail "gesso.spec exists"
spec=$(cat "$ROOT/packaging/gesso.spec")
[[ $spec == *"%package plasma"* ]] || fail "spec has plasma subpackage"
[[ $spec == *"%package plasma"*"Requires: kf6-qqc2-desktop-style"*"%description plasma"* ]] || fail "plasma Requires kf6-qqc2-desktop-style"
[[ $spec == *"Requires: xdg-utils"* ]] || fail "spec Requires xdg-utils"
[[ $spec == *"%package agents"* ]] && fail "spec must not have an agents subpackage"
[[ $spec == *"gesso-agents"* ]] && fail "spec must not mention gesso-agents"
[[ $spec == *"qtquickcontrols2"* ]] && fail "spec must not BuildRequire qtquickcontrols2"
[[ $spec == *"Name: gesso"* ]] || fail "spec Name is gesso"
[[ $spec == *"Source0: %{url}/archive/v%{version}/%{name}-%{version}.tar.gz"* ]] || fail "spec Source0 uses v%{version}"
[[ $spec == *"/etc/"* ]] && fail "spec must not ship /etc"
[[ $spec == *libexec*gesso/gesso-setup* || $spec == *"%{_libexecdir}/gesso/gesso-setup"* ]] || fail "spec installs libexec gesso-setup"
pass "spec has two packages, Source0 tag, and no /etc"

desktop=$(cat "$ROOT/setup/org.gesso.setup.desktop")
[[ $desktop == *"Icon=preferences-desktop-theme"* ]] || fail "desktop file has Icon"
pass "desktop file has Icon"

[[ -f $ROOT/.github/workflows/ci.yml ]] || fail "ci workflow exists"
ci=$(cat "$ROOT/.github/workflows/ci.yml")
[[ $ci == *"registry.fedoraproject.org/fedora:44"* ]] || fail "ci runs on Fedora 44"
[[ $ci == *"./test/all"* ]] || fail "ci runs ./test/all"
[[ $ci == *"cmake --build build"* ]] || fail "ci builds setup"
pass "ci workflow runs tests and cmake on Fedora 44"
