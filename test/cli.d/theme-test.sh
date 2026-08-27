#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

if gesso theme set >/tmp/gesso-theme-set-noargs 2>&1; then
  fail "gesso theme set without args exits non-zero"
fi
noargs=$(cat /tmp/gesso-theme-set-noargs)
[[ $noargs == *Usage* ]] || fail "gesso theme set without args prints Usage" "$noargs"
pass "gesso theme set without args prints Usage"

if gesso theme set --help >/dev/null 2>&1; then
  :
else
  fail "gesso theme set --help exits 0"
fi
pass "gesso theme set --help exits 0"

if gesso theme set not-a-theme >/tmp/gesso-theme-set-unknown 2>&1; then
  fail "unknown theme exits non-zero"
fi
unknown=$(cat /tmp/gesso-theme-set-unknown)
[[ $unknown == *"Unknown theme: not-a-theme"* ]] || fail "unknown theme message" "$unknown"
pass "unknown theme exits non-zero"

export GESSO_THEME_HEADLESS=1
gesso theme set tokyo-night
name_file=$HOME/.local/state/gesso/current/theme.name
[[ -f $name_file ]] || fail "theme.name exists"
name_got=$(cat "$name_file")
[[ $name_got == "tokyo-night" ]] || fail "theme.name is tokyo-night" "$name_got"
pass "theme.name is tokyo-night"

[[ -f $HOME/.local/state/gesso/current/theme/colors.toml ]] || fail "staged colors.toml exists"
pass "staged colors.toml exists"

mkdir -p "$HOME/.config/gesso/themes/tokyo-night"
cp "$ROOT/themes/tokyo-night/colors.toml" "$HOME/.config/gesso/themes/tokyo-night/colors.toml"
sed -i 's/^accent = .*/accent = "#ff00aa"/' "$HOME/.config/gesso/themes/tokyo-night/colors.toml"
gesso theme set tokyo-night
overlay=$(cat "$HOME/.local/state/gesso/current/theme/colors.toml")
[[ $overlay == *"#ff00aa"* ]] || fail "user overlay wins on colors.toml" "$overlay"
pass "user overlay wins on colors.toml"

mkdir -p "$HOME/.config/gesso/themed"
printf 'accent={{ accent }}\nstrip={{ accent_strip }}\nrgb={{ accent_rgb }}\nmix={{ mix background foreground 15%% }}\n' >"$HOME/.config/gesso/themed/extra.conf.tpl"
gesso theme set tokyo-night
extra=$HOME/.local/state/gesso/current/theme/extra.conf
[[ -f $extra ]] || fail "user template rendered"
extra_got=$(cat "$extra")
[[ $extra_got == *"accent=#ff00aa"* ]] || fail "user template accent" "$extra_got"
[[ $extra_got == *"strip=ff00aa"* ]] || fail "user template strip" "$extra_got"
[[ $extra_got == *"rgb=255,0,170"* ]] || fail "user template rgb" "$extra_got"
[[ $extra_got == *mix=#* ]] || fail "user template mix looks like hex" "$extra_got"
pass "user template rendered with placeholders"

[[ -f $HOME/.local/share/color-schemes/Gesso.colors ]] || fail "Gesso.colors live path"
colors=$(cat "$HOME/.local/share/color-schemes/Gesso.colors")
[[ $colors == *"26,27,38"* ]] || fail "Gesso.colors has tokyo-night window RGB" "$colors"
[[ $colors == *Name=Gesso* ]] || fail "Gesso.colors Name=Gesso" "$colors"
pass "Gesso.colors has tokyo-night window RGB"

if [[ -f $HOME/gesso-stub.log ]]; then
  fail "headless apply does not call session stubs" "$(cat "$HOME/gesso-stub.log")"
fi
pass "headless apply does not call session stubs"

unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night
[[ -f $HOME/gesso-stub.log ]] || fail "non-headless stub log exists"
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-colorscheme Gesso"* ]] || fail "plasma-apply-colorscheme Gesso logged" "$stub"
[[ $stub == *"gsettings set org.gnome.desktop.interface color-scheme prefer-dark"* ]] || fail "gsettings prefer-dark logged" "$stub"
pass "non-headless stubs record Plasma and GTK"
export GESSO_THEME_HEADLESS=1
