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

json_out=$(gesso theme list --json)
validated=$(python3 -c '
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception as e:
    sys.exit(1)
if not isinstance(data, list) or len(data) != 5:
    sys.exit(2)
ids = [t["id"] for t in data]
if ids != sorted(ids) or "tokyo-night" not in ids or "catppuccin-latte" not in ids:
    sys.exit(3)
for t in data:
    for req in ("id", "name", "mode", "accent", "background", "foreground", "selection", "muted", "palette", "has_wallpaper"):
        if req not in t:
            sys.exit(4)
    if t["mode"] not in ("dark", "light"):
        sys.exit(5)
    for c in ("accent", "background", "foreground", "selection", "muted"):
        if not t[c].startswith("#"):
            sys.exit(6)
    if not isinstance(t["palette"], list) or len(t["palette"]) != 6:
        sys.exit(7)
    for c in t["palette"]:
        if not c.startswith("#"):
            sys.exit(8)
    if not isinstance(t["has_wallpaper"], bool) or t["has_wallpaper"] is not False:
        sys.exit(9)

tokyo = next(t for t in data if t["id"] == "tokyo-night")
if tokyo["name"] != "Tokyo Night" or tokyo["mode"] != "dark" or tokyo["accent"] != "#7aa2f7":
    sys.exit(10)
if tokyo["palette"] != ["#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab"]:
    sys.exit(11)

latte = next(t for t in data if t["id"] == "catppuccin-latte")
if latte["name"] != "Catppuccin Latte" or latte["mode"] != "light" or latte["accent"] != "#8839ef":
    sys.exit(12)

print("valid")
' "$json_out" 2>/dev/null || true)
[[ $validated == "valid" ]] || fail "theme list --json schema and data integrity" "$json_out"
pass "theme list --json schema and data integrity"

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

overlay_accent=$(gesso theme list --json | python3 -c 'import json, sys; print(next(t for t in json.load(sys.stdin) if t["id"] == "tokyo-night")["accent"])')
[[ $overlay_accent == "#ff00aa" ]] || fail "theme list --json reflects user overlay" "$overlay_accent"
pass "theme list --json reflects user overlay"

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
[[ -f $HOME/.config/kitty/kitty.conf ]] || fail "Kitty creates kitty.conf if missing"
kitty_conf_content=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kitty_conf_content == *"include gesso-theme.conf"* ]] || fail "kitty.conf includes gesso-theme.conf" "$kitty_conf_content"
pass "Kitty theme file copied and enabled in kitty.conf"

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
wall_has_bg=$(gesso theme list --json | python3 -c 'import json, sys; print(next(t for t in json.load(sys.stdin) if t["id"] == "wall-night")["has_wallpaper"])')
[[ $wall_has_bg == "True" ]] || fail "theme list --json detects wallpaper availability" "$wall_has_bg"
pass "theme list --json detects wallpaper availability"
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night --wallpaper theme
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-a.png"* ]] || fail "wallpaper applies first sorted background" "$stub"
pass "theme with backgrounds applies the first wallpaper"

export GESSO_THEME_HEADLESS=1
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night --wallpaper theme
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

# --- Task 3 tests: Wallpaper Modes, Terminal Enablement, Undo State ---

unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night
if [[ -f $HOME/gesso-stub.log ]] && grep -q 'plasma-apply-wallpaperimage' "$HOME/gesso-stub.log"; then
  fail "default wallpaper mode keep does not run plasma-apply-wallpaperimage" "$(cat "$HOME/gesso-stub.log")"
fi
pass "default wallpaper mode keep does not run plasma-apply-wallpaperimage"

rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night --wallpaper keep
if [[ -f $HOME/gesso-stub.log ]] && grep -q 'plasma-apply-wallpaperimage' "$HOME/gesso-stub.log"; then
  fail "explicit --wallpaper keep does not run plasma-apply-wallpaperimage" "$(cat "$HOME/gesso-stub.log")"
fi
pass "explicit --wallpaper keep does not run plasma-apply-wallpaperimage"

rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night --wallpaper theme
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-a.png"* ]] || fail "--wallpaper theme applies bundled wallpaper" "$stub"
pass "--wallpaper theme applies bundled wallpaper"

custom_img=$HOME/my-custom-bg.png
touch "$custom_img"
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night --wallpaper "$custom_img"
shopt -s nullglob
matches=("$HOME"/.local/state/gesso/wallpapers/*-my-custom-bg.png)
(( ${#matches[@]} == 1 )) || fail "custom wallpaper copied to state dir"
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-my-custom-bg.png"* ]] || fail "custom wallpaper applied via plasma-apply-wallpaperimage" "$stub"
pass "custom wallpaper copied and applied"

custom_img2=$HOME/custom2.jpg
touch "$custom_img2"
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night --wallpaper custom "$custom_img2"
matches=("$HOME"/.local/state/gesso/wallpapers/*-custom2.jpg)
(( ${#matches[@]} == 1 )) || fail "--wallpaper custom copied to state dir"
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-custom2.jpg"* ]] || fail "--wallpaper custom applied via plasma-apply-wallpaperimage" "$stub"
pass "--wallpaper custom copied and applied"

# Terminal enablement and deduplication: Kitty
mkdir -p "$HOME/.config/kitty"
printf 'font_size 12.0\n' >"$HOME/.config/kitty/kitty.conf"
gesso theme set tokyo-night
kconf=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kconf == *"font_size 12.0"* ]] || fail "kitty.conf preserves existing settings" "$kconf"
[[ $kconf == *"include gesso-theme.conf"* ]] || fail "kitty.conf receives include" "$kconf"
gesso theme set nord
kconf_after=$(cat "$HOME/.config/kitty/kitty.conf")
k_count=$(grep -c 'include gesso-theme.conf' "$HOME/.config/kitty/kitty.conf")
((k_count == 1)) || fail "kitty.conf has exactly one include line without duplication" "$k_count"
pass "kitty.conf receives include and does not duplicate"

# Terminal enablement and deduplication: Ghostty
mkdir -p "$HOME/.config/ghostty"
printf 'font-size = 14\ntheme = Dracula\n' >"$HOME/.config/ghostty/config"
gesso theme set tokyo-night
gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf == *"font-size = 14"* ]] || fail "ghostty config preserves existing settings" "$gconf"
[[ $gconf == *"theme = Gesso"* ]] || fail "ghostty config replaces theme with Gesso" "$gconf"
[[ -f $HOME/.local/state/gesso/undo/ghostty-theme ]] || fail "undo/ghostty-theme exists"
[[ $(cat "$HOME/.local/state/gesso/undo/ghostty-theme") == "Dracula" ]] || fail "undo/ghostty-theme contains Dracula" "$(cat "$HOME/.local/state/gesso/undo/ghostty-theme")"
gesso theme set nord
g_count=$(grep -c 'theme = Gesso' "$HOME/.config/ghostty/config")
((g_count == 1)) || fail "ghostty config has exactly one theme = Gesso line without duplication" "$g_count"
pass "ghostty config replaces theme and does not duplicate"

# Terminal enablement and deduplication: Foot
mkdir -p "$HOME/.config/foot"
printf '[main]\nfont=monospace:size=11\n\n[scrollback]\nlines=500\n' >"$HOME/.config/foot/foot.ini"
gesso theme set tokyo-night
fconf=$(cat "$HOME/.config/foot/foot.ini")
[[ $fconf == *"font=monospace:size=11"* ]] || fail "foot.ini preserves existing settings" "$fconf"
[[ $fconf == *"include = ~/.config/foot/gesso-theme.ini"* ]] || fail "foot.ini receives include under main" "$fconf"
gesso theme set nord
f_count=$(grep -c 'gesso-theme.ini' "$HOME/.config/foot/foot.ini")
((f_count == 1)) || fail "foot.ini has exactly one include line without duplication" "$f_count"
pass "foot.ini receives include under [main] and does not duplicate"

# Undo state
gesso theme set tokyo-night
gesso theme set nord
[[ -f $HOME/.local/state/gesso/undo/previous-theme.name ]] || fail "undo/previous-theme.name exists"
[[ $(cat "$HOME/.local/state/gesso/undo/previous-theme.name") == "tokyo-night" ]] || fail "undo/previous-theme.name contains tokyo-night" "$(cat "$HOME/.local/state/gesso/undo/previous-theme.name")"
pass "undo records previous theme name"

gesso theme set wall-night --wallpaper theme
gesso theme set tokyo-night --wallpaper keep
[[ -f $HOME/.local/state/gesso/undo/wallpaper ]] || fail "undo/wallpaper exists"
[[ $(cat "$HOME/.local/state/gesso/undo/wallpaper") == "$HOME/.local/state/gesso/wallpapers/"*"-a.png" ]] || fail "undo/wallpaper records previous wallpaper" "$(cat "$HOME/.local/state/gesso/undo/wallpaper")"
pass "undo records previous wallpaper"

[[ -f $HOME/.local/state/gesso/undo/kitty-state ]] || fail "undo/kitty-state exists"
[[ -f $HOME/.local/state/gesso/undo/ghostty-state ]] || fail "undo/ghostty-state exists"
[[ -f $HOME/.local/state/gesso/undo/foot-state ]] || fail "undo/foot-state exists"
pass "undo records terminal state markers"

export GESSO_THEME_HEADLESS=1

# --- Task 4 tests: Theme Undo & Baseline Restore ---

theme_cmds=$(gesso theme)
[[ $theme_cmds == *"theme undo"* ]] || fail "gesso theme lists undo" "$theme_cmds"
[[ $theme_cmds == *"theme restore"* ]] || fail "gesso theme lists restore" "$theme_cmds"
pass "gesso theme lists undo and restore"

undo_help=$(gesso theme undo --help)
[[ $undo_help == *"Usage: gesso theme undo"* ]] || fail "gesso theme undo --help prints usage" "$undo_help"
pass "gesso theme undo --help prints usage"

rm -rf "$HOME/.local/state/gesso/undo"
if gesso theme undo >/tmp/gesso-theme-undo-nostate 2>&1; then
  fail "gesso theme undo without undo state exits non-zero"
fi
nostate=$(cat /tmp/gesso-theme-undo-nostate)
[[ $nostate == *"No previous theme to undo"* ]] || fail "gesso theme undo error message" "$nostate"
pass "gesso theme undo without undo state exits non-zero with error message"

mkdir -p "$HOME/.local/state/gesso/undo"
if gesso theme undo >/tmp/gesso-theme-undo-empty 2>&1; then
  fail "gesso theme undo with empty undo dir exits non-zero"
fi
empty_err=$(cat /tmp/gesso-theme-undo-empty)
[[ $empty_err == *"No previous theme to undo"* ]] || fail "gesso theme undo empty error message" "$empty_err"
pass "gesso theme undo with empty undo dir exits non-zero"

# Set-then-undo theme rollback (theme-to-theme)
mkdir -p "$HOME/.config/kitty" "$HOME/.config/ghostty" "$HOME/.config/foot"
printf 'font_size 12.0\n' >"$HOME/.config/kitty/kitty.conf"
printf 'font-size = 14\ntheme = Dracula\n' >"$HOME/.config/ghostty/config"
printf '[main]\nfont=monospace:size=11\n' >"$HOME/.config/foot/foot.ini"

unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night --wallpaper "$custom_img"
[[ $(cat "$HOME/.local/state/gesso/current/theme.name") == "tokyo-night" ]] || fail "theme is tokyo-night"

rm -f "$HOME/gesso-stub.log"
gesso theme set nord --wallpaper "$custom_img2"
[[ $(cat "$HOME/.local/state/gesso/current/theme.name") == "nord" ]] || fail "theme is nord"
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-custom2.jpg"* ]] || fail "nord wallpaper applied" "$stub"

rm -f "$HOME/gesso-stub.log"
gesso theme undo
[[ $(cat "$HOME/.local/state/gesso/current/theme.name") == "tokyo-night" ]] || fail "theme restored to tokyo-night" "$(cat "$HOME/.local/state/gesso/current/theme.name")"
[[ $(cat "$HOME/.local/state/gesso/current/wallpaper") == "$HOME/.local/state/gesso/wallpapers/"*"-my-custom-bg.png" ]] || fail "wallpaper restored to my-custom-bg.png"
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $HOME/.local/state/gesso/wallpapers/"*"-my-custom-bg.png"* ]] || fail "wallpaper reapplied on undo" "$stub"

kconf=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kconf == *"include gesso-theme.conf"* ]] || fail "kitty.conf has include" "$kconf"
ktpl=$(cat "$HOME/.config/kitty/gesso-theme.conf")
[[ $ktpl == *"#1a1b26"* ]] || fail "kitty theme conf is tokyo-night" "$ktpl"

gtpl=$(cat "$HOME/.config/ghostty/themes/Gesso")
[[ $gtpl == *"background = #1a1b26"* ]] || fail "ghostty theme is tokyo-night" "$gtpl"

ftpl=$(cat "$HOME/.config/foot/gesso-theme.ini")
[[ $ftpl == *"background=1a1b26"* ]] || fail "foot theme is tokyo-night" "$ftpl"

[[ -d $HOME/.local/state/gesso/undo ]] && fail "undo directory removed after successful undo"
pass "gesso theme set followed by undo restores previous theme name, wallpaper, and terminal configs"

# Undo from first theme restores baseline
gesso theme restore
[[ $(gesso theme current) == "unset" ]] || fail "theme current is unset"

printf 'font_size 12.0\n' >"$HOME/.config/kitty/kitty.conf"
printf 'font-size = 14\ntheme = Dracula\n' >"$HOME/.config/ghostty/config"
printf '[main]\nfont=monospace:size=11\n' >"$HOME/.config/foot/foot.ini"

gesso theme set tokyo-night
gesso theme undo
[[ $(gesso theme current) == "unset" ]] || fail "theme current is unset after undo to baseline"
kconf=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kconf != *"include gesso-theme.conf"* ]] || fail "kitty.conf include removed on undo to baseline" "$kconf"
[[ $kconf == *"font_size 12.0"* ]] || fail "kitty.conf font_size preserved" "$kconf"

gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf != *"theme = Gesso"* ]] || fail "ghostty config theme = Gesso removed on undo to baseline" "$gconf"
[[ $gconf == *"theme = Dracula"* ]] || fail "ghostty config restored to Dracula" "$gconf"

fconf=$(cat "$HOME/.config/foot/foot.ini")
[[ $fconf != *"gesso-theme.ini"* ]] || fail "foot.ini include removed on undo to baseline" "$fconf"
[[ $fconf == *"font=monospace:size=11"* ]] || fail "foot.ini font preserved" "$fconf"

[[ -d $HOME/.local/state/gesso/undo ]] && fail "undo dir removed"
pass "undo from first theme restores baseline and terminal configs"

# Restore cleans up terminal configs and removes undo state
printf 'font_size 12.0\n' >"$HOME/.config/kitty/kitty.conf"
printf 'font-size = 14\ntheme = Dracula\n' >"$HOME/.config/ghostty/config"
printf '[main]\nfont=monospace:size=11\n' >"$HOME/.config/foot/foot.ini"
gesso theme set tokyo-night
[[ -d $HOME/.local/state/gesso/undo ]] || fail "undo dir exists after set"

gesso theme restore
[[ $(gesso theme current) == "unset" ]] || fail "theme current is unset after restore"
[[ -d $HOME/.local/state/gesso/undo ]] && fail "undo dir removed after restore"
[[ -f $HOME/.local/state/gesso/current/wallpaper ]] && fail "current/wallpaper removed after restore"

kconf=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kconf != *"include gesso-theme.conf"* ]] || fail "restore removes include from kitty.conf" "$kconf"
[[ $kconf == *"font_size 12.0"* ]] || fail "restore keeps other kitty settings" "$kconf"

gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf != *"theme = Gesso"* ]] || fail "restore removes theme = Gesso from ghostty/config" "$gconf"
[[ $gconf == *"theme = Dracula"* ]] || fail "restore puts back saved ghostty theme" "$gconf"
[[ $gconf == *"font-size = 14"* ]] || fail "restore keeps other ghostty settings" "$gconf"

fconf=$(cat "$HOME/.config/foot/foot.ini")
[[ $fconf != *"gesso-theme.ini"* ]] || fail "restore removes include from foot.ini" "$fconf"
[[ $fconf == *"font=monospace:size=11"* ]] || fail "restore keeps other foot settings" "$fconf"

pass "gesso theme restore cleans up terminal configs and removes undo state"

# Wallpaper restoration on baseline undo
printf '%s\n' '[Containments][1][Wallpaper][org.kde.image][General]' "Image=file://$custom_img" >"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night --wallpaper "$custom_img2"
[[ -f $HOME/.local/state/gesso/undo/wallpaper ]] || fail "undo wallpaper saved from desktop-appletsrc"
[[ $(cat "$HOME/.local/state/gesso/undo/wallpaper") == "$custom_img" ]] || fail "undo wallpaper matches desktop-appletsrc"

rm -f "$HOME/gesso-stub.log"
gesso theme undo
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $custom_img"* ]] || fail "undo to baseline reapplies baseline wallpaper" "$stub"
[[ ! -f $HOME/.local/state/gesso/current/wallpaper ]] || fail "current/wallpaper removed on baseline undo"
pass "undo to baseline reapplies baseline wallpaper"

export GESSO_THEME_HEADLESS=1

# --- Pre-Merge Review Regression Tests ---

# 1. Ghostty sed escaping & command injection defense
mkdir -p "$HOME/.config/ghostty"
printf 'theme = x/;e printf GESSO_COMMAND_INJECTION_FAIL #\n' >"$HOME/.config/ghostty/config"
gesso theme set tokyo-night
gesso theme restore
gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf == *"theme = x/;e printf GESSO_COMMAND_INJECTION_FAIL #"* ]] || fail "Ghostty restore literally restores theme with special characters" "$gconf"
pass "Ghostty restore literally restores theme with special characters without command execution"

# 2. Trailing newline safety on Kitty and Ghostty configs
printf 'font_size 12.0' >"$HOME/.config/kitty/kitty.conf"
printf 'font-size = 14' >"$HOME/.config/ghostty/config"
gesso theme set tokyo-night
kconf=$(cat "$HOME/.config/kitty/kitty.conf")
[[ $kconf == *"font_size 12.0"* ]] || fail "kitty.conf has font_size 12.0" "$kconf"
[[ $kconf != *"font_size 12.0include"* ]] || fail "kitty.conf did not concatenate include onto previous line" "$kconf"
gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf == *"font-size = 14"* ]] || fail "ghostty config has font-size = 14" "$gconf"
[[ $gconf != *"font-size = 14theme"* ]] || fail "ghostty config did not concatenate theme onto previous line" "$gconf"
pass "terminal appends respect line boundaries when files lack trailing newlines"

# 3. Foot include section placement when no [main] section exists
printf '[colors]\nbackground=000000\n' >"$HOME/.config/foot/foot.ini"
gesso theme set tokyo-night
fconf=$(cat "$HOME/.config/foot/foot.ini")
[[ $fconf == *"[main]"* ]] || fail "foot.ini contains [main] header" "$fconf"
main_idx=$(python3 -c 'import sys; c=open(sys.argv[1]).read(); print(c.index("[main]"))' "$HOME/.config/foot/foot.ini")
colors_idx=$(python3 -c 'import sys; c=open(sys.argv[1]).read(); print(c.index("[colors]"))' "$HOME/.config/foot/foot.ini")
(( main_idx < colors_idx )) || fail "[main] appears before other sections in foot.ini" "$fconf"
pass "foot include is placed under [main] and does not leak into other sections"

# 4. Multi-apply baseline restore (preserves pre-Gesso baseline across repeated applies)
gesso theme restore
printf 'theme = OriginalGhostty\n' >"$HOME/.config/ghostty/config"
initial_wp=$HOME/original-wp.png
touch "$initial_wp"
printf '%s\n' '[Containments][1][Wallpaper][org.kde.image][General]' "Image=file://$initial_wp" >"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
wp1=$HOME/wp1.png
touch "$wp1"
wp2=$HOME/wp2.png
touch "$wp2"
unset GESSO_THEME_HEADLESS
rm -f "$HOME/gesso-stub.log"
gesso theme set tokyo-night --wallpaper "$wp1"
gesso theme set nord --wallpaper "$wp2"
rm -f "$HOME/gesso-stub.log"
gesso theme restore
stub=$(cat "$HOME/gesso-stub.log")
[[ $stub == *"plasma-apply-wallpaperimage $initial_wp"* ]] || fail "multi-apply restore recovers pre-Gesso baseline wallpaper" "$stub"
gconf=$(cat "$HOME/.config/ghostty/config")
[[ $gconf == *"theme = OriginalGhostty"* ]] || fail "multi-apply restore recovers pre-Gesso Ghostty theme" "$gconf"
pass "multi-apply restore preserves pre-Gesso wallpaper and Ghostty baseline"

# 5. Keeping a theme wallpaper does not delete backing image when switching themes
rm -f "$HOME/gesso-stub.log"
gesso theme set wall-night --wallpaper theme
current_wp=$(cat "$HOME/.local/state/gesso/current/wallpaper")
[[ -f $current_wp ]] || fail "applied theme wallpaper exists"
gesso theme set tokyo-night --wallpaper keep
[[ -f $current_wp ]] || fail "theme wallpaper file still exists after switching themes with --wallpaper keep"
[[ $(cat "$HOME/.local/state/gesso/current/wallpaper") == "$current_wp" ]] || fail "wallpaper path preserved with --wallpaper keep"
pass "keeping theme wallpaper preserves backing image across theme changes"

# 6. Unique wallpaper storage (no overwrite when different files share the same filename)
dir_a=$HOME/dir_a
dir_b=$HOME/dir_b
mkdir -p "$dir_a" "$dir_b"
printf 'IMG_A_CONTENT' >"$dir_a/photo.jpg"
printf 'IMG_B_CONTENT' >"$dir_b/photo.jpg"
gesso theme set tokyo-night --wallpaper "$dir_a/photo.jpg"
wp_a_dest=$(cat "$HOME/.local/state/gesso/current/wallpaper")
gesso theme set nord --wallpaper "$dir_b/photo.jpg"
wp_b_dest=$(cat "$HOME/.local/state/gesso/current/wallpaper")
[[ $wp_a_dest != "$wp_b_dest" ]] || fail "distinct images with same basename get unique stored destinations"
[[ $(cat "$wp_a_dest") == "IMG_A_CONTENT" ]] || fail "first wallpaper retains original content"
[[ $(cat "$wp_b_dest") == "IMG_B_CONTENT" ]] || fail "second wallpaper has new content"
gesso theme undo
[[ $(cat "$HOME/.local/state/gesso/current/wallpaper") == "$wp_a_dest" ]] || fail "undo restores first wallpaper path"
[[ $(cat "$wp_a_dest") == "IMG_A_CONTENT" ]] || fail "undo restores first wallpaper bytes"
pass "custom wallpapers with identical filenames are uniquely stored and recoverable"

# 7. First-apply undo resets to baseline
gesso theme restore
gesso theme set tokyo-night
[[ $(gesso theme current) == "tokyo-night" ]] || fail "theme set to tokyo-night"
gesso theme undo
[[ $(gesso theme current) == "unset" ]] || fail "first apply undo resets current theme to unset"
pass "first-apply undo cleanly resets to baseline"

# 8. Failed restoration preserves recovery state
gesso theme set tokyo-night
printf '%s\n' '#!/bin/bash' 'exit 1' >"$HOME/gesso-stubs/plasma-apply-colorscheme"
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"
if gesso theme restore >/dev/null 2>&1; then
  fail "failing plasma-apply-colorscheme in restore exits non-zero"
fi
[[ -d $HOME/.local/state/gesso/undo ]] || fail "undo dir preserved when restore fails"
[[ -f $HOME/.local/state/gesso/current/theme.name ]] || fail "current theme.name preserved when restore fails"
printf '%s\n' '#!/bin/bash' 'exit 0' >"$HOME/gesso-stubs/plasma-apply-colorscheme"
chmod +x "$HOME/gesso-stubs/plasma-apply-colorscheme"
gesso theme restore
[[ $(gesso theme current) == "unset" ]] || fail "subsequent restore succeeds"
pass "failed restoration retains recovery state allowing retry"

export GESSO_THEME_HEADLESS=1
