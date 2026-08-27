#!/bin/bash
set -euo pipefail
# shellcheck source=../lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

if [[ ! -x $ROOT/bin/gesso ]]; then
  fail "bin/gesso is executable" "phase 0 router is missing"
fi

pass "bin/gesso is executable"

help_out=$(gesso --help)
[[ $help_out == *theme* ]] || fail "gesso --help mentions theme" "$help_out"
pass "gesso --help mentions theme"

if gesso not-a-command >/tmp/gesso-unknown 2>&1; then
  fail "unknown command exits non-zero"
fi
pass "unknown command exits non-zero"

list_out=$(gesso theme list)
[[ $list_out == *tokyo-night* ]] || fail "gesso theme list prints tokyo-night" "$list_out"
pass "gesso theme list prints tokyo-night"

mkdir -p "$HOME/.config/gesso/themes/user-red"
printf 'mode = "dark"\naccent = "#ff0000"\nbackground = "#000000"\nforeground = "#ffffff"\n' >"$HOME/.config/gesso/themes/user-red/colors.toml"
list_out=$(gesso theme list)
[[ $list_out == *user-red* ]] || fail "gesso theme list includes user themes" "$list_out"
pass "gesso theme list includes user themes"

mkdir -p "$HOME/.config/gesso/themes/tokyo-night"
printf 'mode = "dark"\naccent = "#0000ff"\n' >"$HOME/.config/gesso/themes/tokyo-night/colors.toml"
count=$(gesso theme list | grep -c '^tokyo-night$' || true)
(( count == 1 )) || fail "duplicate theme names print once" "count=$count"
pass "duplicate theme names print once"

if gesso theme list --help >/dev/null 2>&1; then
  :
else
  fail "gesso theme list --help exits 0"
fi
pass "gesso theme list --help exits 0"

shopt -s nullglob
for cmd in "$ROOT/bin"/gesso-*; do
  [[ -x $cmd ]] || continue
  if ! head -n 80 "$cmd" | grep -q '^# gesso:summary='; then
    fail "command has gesso:summary metadata" "$cmd"
  fi
done
pass "every gesso-* command has summary metadata"

theme_cmds=$(gesso theme 2>&1) || fail "gesso theme exits 0" "$theme_cmds"
[[ $theme_cmds == *"theme list"* ]] || fail "gesso theme lists theme list" "$theme_cmds"
[[ $theme_cmds == *"theme set"* ]] || fail "gesso theme lists theme set" "$theme_cmds"
[[ $theme_cmds == *"theme current"* ]] || fail "gesso theme lists theme current" "$theme_cmds"
[[ $theme_cmds == *"theme restore"* ]] || fail "gesso theme lists theme restore" "$theme_cmds"
[[ $theme_cmds != *set-templates* ]] || fail "gesso theme omits hidden set-templates" "$theme_cmds"
pass "gesso theme lists non-hidden theme commands"

current_out=$(gesso theme current -- --help 2>&1) || fail "gesso theme current -- --help exits 0" "$current_out"
[[ $current_out != *Usage* ]] || fail "-- after leftover stops the help scan" "$current_out"
[[ $current_out == "unset" ]] || fail "gesso theme current -- --help prints the current theme" "$current_out"
pass "leftover -- stops the help scan"
