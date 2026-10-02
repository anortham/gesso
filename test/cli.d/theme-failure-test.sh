#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

gesso theme set tokyo-night

native_user=$HOME/.config/Code/User
flatpak_user=$HOME/.var/app/com.visualstudio.code/config/Code/User
live_colors=$HOME/.local/share/color-schemes/Gesso.colors
current_colors=$HOME/.local/state/gesso/current/theme/colors.toml
theme_name=$HOME/.local/state/gesso/current/theme.name
native_backup=$HOME/.local/state/gesso/vscode-colorCustomizations.json
flatpak_backup=$HOME/.local/state/gesso/vscode-flatpak-colorCustomizations.json
konsolerc=$HOME/.config/konsolerc
konsole_profile=$HOME/.local/share/konsole/Gesso.profile

cp "$live_colors" "$HOME/live-colors.before"
cp "$current_colors" "$HOME/current-colors.before"
printf '%s\n' '[Desktop Entry]' 'DefaultProfile=KeepMe.profile' >"$konsolerc"
printf '%s\n' '[General]' 'Name=KeepMe' >"$konsole_profile"
cp "$konsolerc" "$HOME/konsolerc.before"
cp "$konsole_profile" "$HOME/konsole-profile.before"

mkdir -p "$native_user"
printf '%s\n' '{ not json' >"$native_user/settings.json"
cp "$native_user/settings.json" "$HOME/native-settings.before"
: >"$HOME/gesso-stub.log"
if gesso theme set nord >"$HOME/native-invalid.out" 2>&1; then
  fail "invalid native VS Code settings fail theme apply"
fi
[[ ! -s $HOME/gesso-stub.log ]] || fail "invalid native VS Code settings do not call desktop stubs"
cmp -s "$HOME/live-colors.before" "$live_colors" || fail "invalid native VS Code settings preserve live Plasma colors"
cmp -s "$HOME/current-colors.before" "$current_colors" || fail "invalid native VS Code settings preserve current theme files"
[[ $(<"$theme_name") == "tokyo-night" ]] || fail "invalid native VS Code settings preserve current theme state"
cmp -s "$HOME/native-settings.before" "$native_user/settings.json" || fail "invalid native VS Code settings remain untouched"
cmp -s "$HOME/konsolerc.before" "$konsolerc" || fail "invalid native VS Code settings preserve Konsole configuration"
cmp -s "$HOME/konsole-profile.before" "$konsole_profile" || fail "invalid native VS Code settings preserve Konsole profile"
[[ ! -e $native_backup && ! -e $flatpak_backup ]] || fail "invalid native VS Code settings do not create color backups"
pass "invalid native VS Code settings fail before desktop or terminal changes"

printf '%s\n' '{"editor.fontSize": 14}' >"$native_user/settings.json"
cp "$native_user/settings.json" "$HOME/native-settings.before"
mkdir -p "$flatpak_user"
printf '%s\n' '{ not json' >"$flatpak_user/settings.json"
cp "$flatpak_user/settings.json" "$HOME/flatpak-settings.before"
: >"$HOME/gesso-stub.log"
if gesso theme set nord >"$HOME/flatpak-invalid.out" 2>&1; then
  fail "invalid later Flatpak VS Code settings fail theme apply"
fi
[[ ! -s $HOME/gesso-stub.log ]] || fail "invalid later Flatpak VS Code settings do not call desktop stubs"
cmp -s "$HOME/live-colors.before" "$live_colors" || fail "invalid later Flatpak VS Code settings preserve live Plasma colors"
cmp -s "$HOME/current-colors.before" "$current_colors" || fail "invalid later Flatpak VS Code settings preserve current theme files"
[[ $(<"$theme_name") == "tokyo-night" ]] || fail "invalid later Flatpak VS Code settings preserve current theme state"
cmp -s "$HOME/native-settings.before" "$native_user/settings.json" || fail "valid first VS Code target remains untouched"
cmp -s "$HOME/flatpak-settings.before" "$flatpak_user/settings.json" || fail "invalid later Flatpak VS Code settings remain untouched"
cmp -s "$HOME/konsolerc.before" "$konsolerc" || fail "invalid later Flatpak VS Code settings preserve Konsole configuration"
cmp -s "$HOME/konsole-profile.before" "$konsole_profile" || fail "invalid later Flatpak VS Code settings preserve Konsole profile"
[[ ! -e $native_backup && ! -e $flatpak_backup ]] || fail "invalid later Flatpak VS Code settings do not create color backups"
pass "invalid later Flatpak VS Code settings leave all targets and baselines untouched"
