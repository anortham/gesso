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

if gesso default browser --help >/dev/null 2>&1; then
  :
else
  fail "gesso default browser --help exits 0"
fi
pass "gesso default browser --help exits 0"

cur=$(gesso default browser)
[[ $cur == "unset" ]] || fail "no default browser is unset" "$cur"
pass "no default browser is unset"

if gesso default browser kate >/tmp/gesso-def-wrong 2>&1; then
  fail "default browser kate exits non-zero"
fi
pass "default browser rejects non-browser id"

rm -f "$HOME/gesso-stub.log"
# ensure firefox command is missing
rm -f "$HOME/gesso-stubs/firefox"
gesso default browser firefox
got=$(gesso default browser)
[[ $got == "firefox" ]] || fail "default browser firefox prints firefox" "$got"
xdg=$(xdg-settings get default-web-browser)
[[ $xdg == "firefox.desktop" ]] || fail "xdg-settings reports firefox.desktop" "$xdg"
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"dnf install -y firefox"* ]] || fail "missing firefox is installed" "$log"
[[ $log == *"xdg-settings set default-web-browser firefox.desktop"* ]] || fail "xdg-settings set logged" "$log"
pass "default browser firefox installs and sets XDG"

rm -f "$HOME/gesso-stub.log"
gesso default browser firefox
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"dnf install"* ]] && fail "second apply skips dnf" "$log"
pass "default browser firefox is idempotent"

gesso default terminal konsole
list=$HOME/.config/xdg-terminals.list
[[ -f $list ]] || fail "xdg-terminals.list exists"
first=$(head -n1 "$list")
[[ $first == "org.kde.konsole.desktop" ]] || fail "konsole is first in xdg-terminals.list" "$first"
cur=$(gesso default terminal)
[[ $cur == "konsole" ]] || fail "default terminal prints konsole" "$cur"
pass "default terminal konsole writes xdg-terminals.list"

gesso default editor kate
ed=$HOME/.local/state/gesso/defaults/editor
[[ -f $ed ]] || fail "editor state file exists"
got=$(cat "$ed")
[[ $got == "kate" ]] || fail "editor state is kate" "$got"
cur=$(gesso default editor)
[[ $cur == "kate" ]] || fail "default editor prints kate" "$cur"
pass "default editor kate writes state file"

gesso default editor kate
pass "default editor kate is idempotent"
