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

got=$(gesso-catalog-get helix command)
[[ $got == "hx" ]] || fail "catalog helix command is hx" "$got"
pass "catalog helix command is hx"

got=$(gesso-catalog-get helix desktop_id)
[[ $got == "Helix.desktop" ]] || fail "catalog helix desktop_id is Helix.desktop" "$got"
pass "catalog helix desktop_id is Helix.desktop"

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

cmd=$ROOT/bin/gesso-app-present
if [[ ! -x $cmd ]]; then
  fail "gesso-app-present is executable" "presence helper is missing"
fi
pass "gesso-app-present is executable"

if gesso-app-present not-an-app >/tmp/gesso-app-unknown 2>&1; then
  fail "unknown app-present exits non-zero"
fi
unknown=$(cat /tmp/gesso-app-unknown)
[[ $unknown == *"Unknown app: not-an-app"* ]] || fail "app-present unknown message" "$unknown"
pass "unknown app-present exits non-zero"

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

if ! gesso-app-present firefox; then
  fail "app-present firefox after dnf"
fi
desktop=$(gesso-app-present --desktop firefox)
[[ $desktop == "firefox.desktop" ]] || fail "firefox desktop is host id" "$desktop"
pass "app-present firefox uses host desktop"

rm -f "$HOME/gesso-stub.log"
gesso pkg add firefox
log=$(cat "$HOME/gesso-stub.log" 2>/dev/null || true)
[[ $log == *"dnf install"* ]] && fail "second pkg add firefox skips dnf" "$log"
pass "pkg add firefox is idempotent when present"

rm -f "$HOME/gesso-stub.log"
rm -f "$HOME/gesso-stubs/google-chrome"
gesso pkg add chrome
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"dnf install"* ]] && fail "chrome has no dnf packages" "$log"
[[ $log == *"flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"* ]] || fail "chrome adds user flathub remote" "$log"
[[ $log == *"flatpak install --user -y flathub com.google.Chrome"* ]] || fail "chrome uses user flatpak" "$log"
[[ $log == *"pkexec flatpak"* ]] && fail "chrome flatpak is not elevated with pkexec" "$log"
[[ $log == *"sudo flatpak"* ]] && fail "chrome flatpak is not elevated with sudo" "$log"
if command -v google-chrome >/dev/null; then
  fail "chrome flatpak does not create google-chrome host binary"
fi
if ! gesso-app-present chrome; then
  fail "app-present chrome after flatpak"
fi
[[ -f $HOME/.local/state/gesso-flatpak/com.google.Chrome ]] || fail "flatpak stub recorded com.google.Chrome"
desktop=$(gesso-app-present --desktop chrome)
[[ $desktop == "com.google.Chrome.desktop" ]] || fail "chrome desktop is flatpak id" "$desktop"
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

rm -f "$HOME/gesso-stub.log"
gesso default browser chrome
got=$(gesso default browser)
[[ $got == "chrome" ]] || fail "default browser chrome prints chrome" "$got"
xdg=$(xdg-settings get default-web-browser)
[[ $xdg == "com.google.Chrome.desktop" ]] || fail "xdg-settings reports com.google.Chrome.desktop" "$xdg"
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"xdg-settings set default-web-browser com.google.Chrome.desktop"* ]] || fail "xdg-settings set chrome logged" "$log"
pass "default browser chrome sets Flatpak desktop"

gesso default terminal konsole
list=$HOME/.config/xdg-terminals.list
[[ -f $list ]] || fail "xdg-terminals.list exists"
first=$(head -n1 "$list")
[[ $first == "org.kde.konsole.desktop" ]] || fail "konsole is first in xdg-terminals.list" "$first"
cur=$(gesso default terminal)
[[ $cur == "konsole" ]] || fail "default terminal prints konsole" "$cur"
pass "default terminal konsole writes xdg-terminals.list"

rm -f "$HOME/gesso-stub.log"
gesso default editor kate
ed=$HOME/.local/state/gesso/defaults/editor
[[ -f $ed ]] || fail "editor state file exists"
got=$(cat "$ed")
[[ $got == "kate" ]] || fail "editor state is kate" "$got"
cur=$(gesso default editor)
[[ $cur == "kate" ]] || fail "default editor prints kate" "$cur"
pass "default editor kate writes state file"

log=$(cat "$HOME/gesso-stub.log")
mime_line="xdg-mime default org.kde.kate.desktop text/plain text/markdown text/x-shellscript application/x-shellscript text/x-python application/json text/xml application/xml text/css text/javascript application/toml application/x-yaml"
[[ $log == *"$mime_line"* ]] || fail "default editor kate sets xdg-mime for the mime list" "$log"
pass "default editor kate sets xdg-mime defaults"

gesso default editor kate
pass "default editor kate is idempotent"

rm -f "$HOME/gesso-stub.log"
gesso pkg add code
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"flatpak install --user -y flathub com.visualstudio.code"* ]] || fail "code installs as user flatpak" "$log"
gesso default editor code
cur=$(gesso default editor)
[[ $cur == "code" ]] || fail "default editor prints code" "$cur"
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"xdg-mime default com.visualstudio.code.desktop"* ]] || fail "default editor code uses the Flatpak desktop id" "$log"
pass "default editor code sets xdg-mime with Flatpak desktop id"

rm -f "$HOME/gesso-stub.log"
rm -f "$HOME/gesso-stubs/helix" "$HOME/gesso-stubs/hx"
gesso pkg add helix
[[ -x $HOME/gesso-stubs/hx ]] || fail "dnf stub created hx command"
if [[ -e $HOME/gesso-stubs/helix ]]; then
  fail "dnf stub did not create helix host binary"
fi
if command -v helix >/dev/null; then
  fail "helix package did not leave a helix command on PATH"
fi
if ! gesso-app-present helix; then
  fail "app-present helix via hx"
fi
pass "pkg add helix is present via hx"

grep -q 'gesso-app-present' "$ROOT/setup/qml/DefaultsPage.qml" || fail "DefaultsPage uses gesso-app-present"
if grep -q 'gesso-cmd-present' "$ROOT/setup/qml/DefaultsPage.qml"; then
  fail "DefaultsPage does not use gesso-cmd-present"
fi
pass "DefaultsPage uses gesso-app-present"

grep -q 'gesso-app-present' "$ROOT/setup/qml/InstallPage.qml" || fail "InstallPage uses gesso-app-present"
if grep -q 'gesso-cmd-present' "$ROOT/setup/qml/InstallPage.qml"; then
  fail "InstallPage does not use gesso-cmd-present"
fi
pass "InstallPage uses gesso-app-present"
