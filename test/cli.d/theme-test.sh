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

listed=$(gesso theme list)
for want in catppuccin-latte catppuccin-mocha gruvbox-dark nord tokyo-night; do
  [[ $listed == *"$want"* ]] || fail "theme list prints $want" "$listed"
done
pass "theme list prints the five first-party themes"

if gesso theme set not-a-theme >/tmp/gesso-theme-set-unknown 2>&1; then
  fail "unknown theme exits non-zero"
fi
unknown=$(cat /tmp/gesso-theme-set-unknown)
[[ $unknown == *"Unknown theme: not-a-theme"* ]] || fail "unknown theme message" "$unknown"
pass "unknown theme exits non-zero"

if gesso theme set ../foo >/tmp/gesso-theme-set-dotdot 2>&1; then
  fail "path theme name exits non-zero"
fi
dotdot=$(cat /tmp/gesso-theme-set-dotdot)
[[ $dotdot == *"Unknown theme: ../foo"* ]] || fail "path theme name message" "$dotdot"
[[ -e $HOME/.local/state/gesso/current/theme ]] && fail "path theme name does not create current/theme"
pass "rejects ../foo and does not create current/theme"

if gesso theme set 'Tokyo Night' >/tmp/gesso-theme-set-space 2>&1; then
  fail "spaced theme name exits non-zero"
fi
spaced=$(cat /tmp/gesso-theme-set-space)
[[ $spaced == *"Unknown theme: Tokyo Night"* ]] || fail "spaced theme name message" "$spaced"
[[ -e $HOME/.local/state/gesso/current/theme ]] && fail "spaced theme name does not create current/theme"
pass "rejects Tokyo Night and does not create current/theme"

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

printf 'oops={{ missing_key }}\n' >"$HOME/.config/gesso/themed/broken.conf.tpl"
if gesso theme set tokyo-night >/tmp/gesso-theme-set-leftover 2>&1; then
  fail "leftover placeholder exits non-zero"
fi
[[ -f $HOME/.local/state/gesso/current/theme/broken.conf ]] && fail "leftover placeholder does not swap current"
name_got=$(cat "$name_file")
[[ $name_got == "tokyo-night" ]] || fail "leftover placeholder leaves theme.name" "$name_got"
[[ -f $HOME/.local/state/gesso/current/theme/extra.conf ]] || fail "leftover placeholder keeps previous current"
rm -f "$HOME/.config/gesso/themed/broken.conf.tpl"
pass "leftover placeholder fails and does not swap"

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

printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 1' >"$HOME/gesso-stubs/plasma-apply-colorscheme"
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"
mkdir -p "$HOME/.config/gesso/themes/other-night"
cp "$ROOT/themes/tokyo-night/colors.toml" "$HOME/.config/gesso/themes/other-night/colors.toml"
if gesso theme set other-night >/tmp/gesso-theme-set-plasma-fail 2>&1; then
  fail "failing plasma-apply-colorscheme exits non-zero"
fi
name_got=$(cat "$name_file")
[[ $name_got == "tokyo-night" ]] || fail "failing plasma leaves theme.name as tokyo-night" "$name_got"
[[ -f $HOME/.local/state/gesso/current/theme/colors.toml ]] || fail "failing plasma leaves current colors.toml"
overlay=$(cat "$HOME/.local/state/gesso/current/theme/colors.toml")
[[ $overlay == *"#ff00aa"* ]] || fail "failing plasma does not swap current" "$overlay"
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 0' >"$HOME/gesso-stubs/plasma-apply-colorscheme"
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"
pass "failing plasma leaves theme.name as tokyo-night"
export GESSO_THEME_HEADLESS=1

[[ -f $HOME/.local/share/konsole/Gesso.colorscheme ]] || fail "Konsole scheme live path"
[[ -f $HOME/.local/share/konsole/Gesso.profile ]] || fail "Konsole profile exists"
profile=$(cat "$HOME/.local/share/konsole/Gesso.profile")
[[ $profile == *ColorScheme=Gesso* ]] || fail "Konsole profile ColorScheme" "$profile"
krc=$(cat "$HOME/.config/konsolerc")
[[ $krc == *DefaultProfile=Gesso.profile* ]] || fail "konsolerc DefaultProfile" "$krc"
pass "Konsole scheme and profile applied"

mkdir -p "$HOME/.config/kitty"
gesso theme set tokyo-night
[[ -f $HOME/.config/kitty/gesso-theme.conf ]] || fail "Kitty gesso-theme.conf copied when config dir exists"
[[ -f $HOME/.config/kitty/kitty.conf ]] && fail "does not write kitty.conf"
pass "Kitty theme file copied without clobbering kitty.conf"

mkdir -p "$HOME/.config/Code/User"
printf '%s\n' '{"editor.fontSize": 14, "workbench.colorCustomizations": {"editor.background": "#111111"}}' >"$HOME/.config/Code/User/settings.json"
gesso theme set tokyo-night
[[ -f $HOME/.config/Code/User/gesso-theme.json ]] || fail "VS Code gesso-theme.json when User dir exists"
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *"editor.fontSize"* ]] || fail "settings.json keeps unrelated key" "$settings"
[[ $settings == *"workbench.colorCustomizations"* ]] || fail "settings.json has colorCustomizations" "$settings"
[[ $settings == *"#1a1b26"* ]] || fail "settings.json merged editor.background" "$settings"
[[ -f $HOME/.local/state/gesso/vscode-colorCustomizations.json ]] || fail "VS Code colorCustomizations backup exists"
backup=$(cat "$HOME/.local/state/gesso/vscode-colorCustomizations.json")
[[ $backup == *"#111111"* ]] || fail "backup stores previous colorCustomizations" "$backup"
pass "VS Code settings.json merges colorCustomizations and keeps unrelated keys"

gesso theme set tokyo-night
backup=$(cat "$HOME/.local/state/gesso/vscode-colorCustomizations.json")
[[ $backup == *"#111111"* ]] || fail "second apply keeps original colorCustomizations backup" "$backup"
gesso theme restore
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *"editor.fontSize"* ]] || fail "restore keeps unrelated key" "$settings"
[[ $settings == *"#111111"* ]] || fail "restore puts previous colorCustomizations back" "$settings"
[[ $settings == *"#1a1b26"* ]] && fail "set-set-restore does not leave Gesso editor.background" "$settings"
[[ -f $HOME/.local/state/gesso/vscode-colorCustomizations.json ]] && fail "restore consumes VS Code colorCustomizations backup"
pass "set-set-restore restores original VS Code colors"

mkdir -p "$HOME/.config/gesso/hooks"
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$1" >"$HOME/gesso-hook.out"' >"$HOME/.config/gesso/hooks/theme-set-record"
chmod +x "$HOME/.config/gesso/hooks/theme-set-record"
gesso theme set tokyo-night
hook=$(cat "$HOME/gesso-hook.out")
[[ $hook == "tokyo-night" ]] || fail "hook receives theme name" "$hook"
pass "theme-set hook runs with theme name"

gesso theme set tokyo-night
pass "second apply exits 0"

scheme=$(cat "$HOME/.local/share/konsole/Gesso.colorscheme")
[[ $scheme == *Description=Gesso* ]] || fail "Konsole scheme named Gesso" "$scheme"
pass "Konsole scheme named Gesso"

sed -i 's/^background = .*/background = "#000000"/' "$HOME/.config/gesso/themes/other-night/colors.toml"
printf '%s\n' '{ not json' >"$HOME/.config/Code/User/settings.json"
if gesso theme set other-night >/tmp/gesso-theme-set-vscode-fail 2>&1; then
  fail "invalid settings.json exits non-zero"
fi
name_got=$(cat "$name_file")
[[ $name_got == "tokyo-night" ]] || fail "invalid settings.json leaves theme.name as tokyo-night" "$name_got"
scheme=$(cat "$HOME/.local/share/konsole/Gesso.colorscheme")
[[ $scheme == *"26,27,38"* ]] || fail "invalid settings.json leaves Konsole on tokyo-night RGB" "$scheme"
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *'{ not json'* ]] || fail "invalid settings.json is not clobbered" "$settings"
pass "invalid settings.json fails without changing live Konsole"

printf '%s\n' '{' '  // comment' '  "editor.fontSize": 14,' '  "workbench.colorCustomizations": {"editor.background": "#111111"},' '}' >"$HOME/.config/Code/User/settings.json"
gesso theme set tokyo-night
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *"editor.fontSize"* ]] || fail "JSONC settings.json keeps unrelated key" "$settings"
[[ $settings == *"#1a1b26"* ]] || fail "JSONC settings.json merged editor.background" "$settings"
pass "JSONC settings.json with comment and trailing comma still merges"

printf '%s\n' '{' '  // comment' '  "editor.fontSize": 14,' '  "workbench.colorCustomizations": {"editor.background": "#1a1b26"}' '}' >"$HOME/.config/Code/User/settings.json"
gesso theme restore
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *"editor.fontSize"* ]] || fail "JSONC restore keeps unrelated key" "$settings"
[[ $settings == *"#111111"* ]] || fail "JSONC restore puts previous colorCustomizations back" "$settings"
[[ $settings == *"#1a1b26"* ]] && fail "JSONC restore removes Gesso editor.background" "$settings"
pass "JSONC settings.json after set still restores"

current=$(gesso theme current)
[[ $current == "unset" ]] || fail "theme current prints unset after restore" "$current"
pass "theme current prints unset after restore"

flatpak_user=$HOME/.var/app/com.visualstudio.code/config/Code/User
flatpak_backup=$HOME/.local/state/gesso/vscode-flatpak-colorCustomizations.json
mkdir -p "$flatpak_user"
printf '%s\n' '{"editor.fontSize": 12, "workbench.colorCustomizations": {"editor.background": "#222222"}}' >"$flatpak_user/settings.json"
gesso theme set tokyo-night
[[ -f $flatpak_user/gesso-theme.json ]] || fail "Flatpak VS Code gesso-theme.json when User dir exists"
settings=$(cat "$flatpak_user/settings.json")
[[ $settings == *"editor.fontSize"* ]] || fail "Flatpak settings.json keeps unrelated key" "$settings"
[[ $settings == *"#1a1b26"* ]] || fail "Flatpak settings.json merged editor.background" "$settings"
[[ -f $flatpak_backup ]] || fail "Flatpak VS Code colorCustomizations backup exists"
backup=$(cat "$flatpak_backup")
[[ $backup == *"#222222"* ]] || fail "Flatpak backup stores previous colorCustomizations" "$backup"
backup=$(cat "$HOME/.local/state/gesso/vscode-colorCustomizations.json")
[[ $backup == *"#111111"* ]] || fail "host backup stays separate from Flatpak backup" "$backup"
gesso theme restore
settings=$(cat "$flatpak_user/settings.json")
[[ $settings == *"#222222"* ]] || fail "Flatpak restore puts previous colorCustomizations back" "$settings"
[[ $settings == *"#1a1b26"* ]] && fail "Flatpak restore removes Gesso editor.background" "$settings"
[[ -f $flatpak_backup ]] && fail "restore consumes Flatpak VS Code backup"
settings=$(cat "$HOME/.config/Code/User/settings.json")
[[ $settings == *"#111111"* ]] || fail "host restore puts previous colorCustomizations back" "$settings"
pass "Flatpak VS Code merges and restores with its own backup"

konsole_backup=$HOME/.local/state/gesso/konsole-default-profile
[[ -f $konsole_backup ]] && fail "restore consumes Konsole DefaultProfile backup"
printf '%s\n' '[Desktop Entry]' 'DefaultProfile=Konsole.profile' >"$HOME/.config/konsolerc"
gesso theme set tokyo-night
[[ -f $konsole_backup ]] || fail "Konsole DefaultProfile backup exists"
prev_profile=$(cat "$konsole_backup")
[[ $prev_profile == "Konsole.profile" ]] || fail "Konsole backup stores previous DefaultProfile" "$prev_profile"
krc=$(cat "$HOME/.config/konsolerc")
[[ $krc == *DefaultProfile=Gesso.profile* ]] || fail "konsolerc DefaultProfile is Gesso.profile" "$krc"
gesso theme set tokyo-night
prev_profile=$(cat "$konsole_backup")
[[ $prev_profile == "Konsole.profile" ]] || fail "second apply keeps Konsole backup" "$prev_profile"
gesso theme restore
krc=$(cat "$HOME/.config/konsolerc")
[[ $krc == *DefaultProfile=Konsole.profile* ]] || fail "restore puts DefaultProfile=Konsole.profile back" "$krc"
[[ $krc == *Gesso.profile* ]] && fail "restore removes Gesso.profile from konsolerc" "$krc"
[[ -f $konsole_backup ]] && fail "restore deletes Konsole DefaultProfile backup"
pass "konsolerc DefaultProfile comes back after restore"

printf '%s\n' '[Desktop Entry]' >"$HOME/.config/konsolerc"
gesso theme set tokyo-night
gesso theme restore
krc=$(cat "$HOME/.config/konsolerc")
[[ $krc == *DefaultProfile=* ]] && fail "restore deletes DefaultProfile line when backup is empty" "$krc"
pass "restore deletes DefaultProfile line when backup is empty"

unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gtk_backup=$HOME/.local/state/gesso/gtk-color-scheme
gesso theme set catppuccin-latte
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"gsettings set org.gnome.desktop.interface color-scheme prefer-light"* ]] || fail "catppuccin-latte logs prefer-light" "$stub"
[[ -f $gtk_backup ]] || fail "GTK color-scheme backup exists"
gesso theme restore
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-colorscheme BreezeLight"$'\n'* ]] || fail "restore after light theme logs BreezeLight" "$stub"
[[ $stub == *"gsettings reset org.gnome.desktop.interface color-scheme"* ]] || fail "restore resets GTK color-scheme when backup is empty" "$stub"
[[ -f $gtk_backup ]] && fail "restore deletes GTK color-scheme backup"
current=$(gesso theme current)
[[ $current == "unset" ]] || fail "theme current prints unset after non-headless restore" "$current"
pass "catppuccin-latte sets prefer-light and restore applies BreezeLight"

rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night
printf '%s\n' "'default'" >"$gtk_backup"
gesso theme restore
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"gsettings set org.gnome.desktop.interface color-scheme 'default'"* ]] || fail "restore sets GTK color-scheme from backup" "$stub"
pass "restore sets GTK color-scheme from a non-empty backup"

printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 0' >"$HOME/gesso-stubs/plasma-apply-wallpaperimage"
chmod +x "$HOME/gesso-stubs/plasma-apply-wallpaperimage"
mkdir -p "$HOME/.config/gesso/themes/wall-night/backgrounds"
cp "$ROOT/themes/tokyo-night/colors.toml" "$HOME/.config/gesso/themes/wall-night/colors.toml"
touch "$HOME/.config/gesso/themes/wall-night/backgrounds/b.png" "$HOME/.config/gesso/themes/wall-night/backgrounds/a.png"
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/current/theme/backgrounds/a.png"* ]] || fail "wallpaper applies first sorted background" "$stub"
pass "theme with backgrounds applies the first wallpaper"

export GESSO_THEME_HEADLESS=1
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night
[[ -f $HOME/gesso-stub.log ]] && fail "headless apply skips wallpaper" "$(cat "$HOME/gesso-stub.log")"
pass "headless apply skips wallpaper"

mkdir -p "$HOME/.config/ghostty" "$HOME/.config/foot"
gesso theme set tokyo-night
[[ -f $HOME/.config/ghostty/themes/Gesso ]] || fail "Ghostty theme file copied when config dir exists"
ghostty=$(cat "$HOME/.config/ghostty/themes/Gesso")
[[ $ghostty == *"background = #1a1b26"* ]] || fail "Ghostty background" "$ghostty"
[[ $ghostty == *"palette = 15=#c0caf5"* ]] || fail "Ghostty palette 15" "$ghostty"
[[ -f $HOME/.config/foot/gesso-theme.ini ]] || fail "Foot theme file copied when config dir exists"
foot=$(cat "$HOME/.config/foot/gesso-theme.ini")
[[ $foot == *"[colors]"* ]] || fail "Foot colors section" "$foot"
[[ $foot == *$'\n'"background=1a1b26"$'\n'* ]] || fail "Foot background without hash" "$foot"
[[ $foot == *"selection-background=292e42"* ]] || fail "Foot derived selection-background strip" "$foot"
[[ $foot == *"bright7=c0caf5"* ]] || fail "Foot bright7" "$foot"
pass "Ghostty and Foot theme files render"

unset GESSO_THEME_HEADLESS
cat >"$HOME/gesso-stubs/plasma-apply-colorscheme" <<'STUB'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
if [[ ${1:-} == "-l" ]]; then
  printf '%s\n' 'You have the following color schemes on your system:' ' * BreezeDark' ' * BreezeLight' ' * Gesso (current color scheme)'
fi
exit 0
STUB
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"

rm -f "$HOME/gesso-stub.log"
gesso theme set catppuccin-latte
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-colorscheme BreezeLight"$'\n'* ]] || fail "Gesso-to-Gesso light switch bounces through BreezeLight" "$stub"
[[ ${stub%%plasma-apply-colorscheme Gesso*} == *"plasma-apply-colorscheme BreezeLight"* ]] || fail "bounce precedes the Gesso apply" "$stub"
pass "switching between Gesso themes re-applies the scheme"

rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-colorscheme BreezeDark"$'\n'* ]] || fail "Gesso-to-Gesso dark switch bounces through BreezeDark" "$stub"
pass "dark switch bounces through BreezeDark"

cat >"$HOME/gesso-stubs/plasma-apply-colorscheme" <<'STUB'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
if [[ ${1:-} == "-l" ]]; then
  printf '%s\n' 'You have the following color schemes on your system:' ' * BreezeDark' ' * BreezeLight (current color scheme)'
fi
exit 0
STUB
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"
rm -f "$HOME/gesso-stub.log"
gesso theme set nord
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub != *"plasma-apply-colorscheme BreezeDark"* ]] || fail "first apply does not bounce" "$stub"
pass "first apply from Breeze does not bounce"
export GESSO_THEME_HEADLESS=1
