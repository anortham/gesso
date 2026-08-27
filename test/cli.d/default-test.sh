#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

cmd=$ROOT/bin/gesso-catalog-get
if [[ ! -x $cmd ]]; then
  fail "gesso-catalog-get is executable" "phase 2 catalog reader is missing"
fi
pass "gesso-catalog-get is executable"

got=$(gesso-catalog-get firefox command)
[[ $got == "firefox" ]] || fail "catalog firefox command" "$got"
pass "catalog firefox command"

dnf=$(gesso-catalog-get firefox dnf)
[[ $dnf == "firefox" ]] || fail "catalog firefox dnf" "$dnf"
pass "catalog firefox dnf"

kinds=$(gesso-catalog-get --kind browser)
[[ $kinds == *firefox* ]] || fail "kind browser lists firefox" "$kinds"
[[ $kinds == *kate* ]] && fail "kind browser does not list kate" "$kinds"
pass "kind browser lists firefox only among browsers"

if gesso-catalog-get not-an-app command >/tmp/gesso-cat-unknown 2>&1; then
  fail "unknown catalog id exits non-zero"
fi
pass "unknown catalog id exits non-zero"

if gesso pkg add >/tmp/gesso-pkg-noargs 2>&1; then
  fail "pkg add without args exits non-zero"
fi
pass "pkg add without args exits non-zero"

if gesso pkg add not-an-app >/tmp/gesso-pkg-unknown 2>&1; then
  fail "pkg add unknown id exits non-zero"
fi
unknown=$(cat /tmp/gesso-pkg-unknown)
[[ $unknown == *"Unknown app: not-an-app"* ]] || fail "pkg add unknown message" "$unknown"
pass "pkg add unknown id exits non-zero"

rm -f "$HOME/gesso-stub.log"
gesso pkg add firefox
[[ -x $HOME/gesso-stubs/firefox ]] || fail "dnf stub created firefox command"
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"dnf install -y firefox"* ]] || fail "dnf install firefox logged" "$log"
pass "pkg add firefox installs via dnf"

rm -f "$HOME/gesso-stub.log"
gesso pkg add firefox
log=$(cat "$HOME/gesso-stub.log" 2>/dev/null || true)
[[ $log == *"dnf install"* ]] && fail "second pkg add firefox skips dnf" "$log"
pass "pkg add firefox is idempotent when present"

rm -f "$HOME/gesso-stub.log"
gesso pkg add chrome
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"dnf install"* ]] && fail "chrome has no dnf packages" "$log"
[[ $log == *"flatpak install -y flathub com.google.Chrome"* ]] || fail "chrome uses flatpak" "$log"
pass "pkg add chrome uses flatpak"
