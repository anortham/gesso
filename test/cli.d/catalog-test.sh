#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

got=$(gesso-catalog-get --json --kind browser | python3 -c '
import json, sys
rows = json.load(sys.stdin)
row = next(r for r in rows if r["id"] == "firefox")
print(row["desktop_id"], row["kind"], row["command"], " ".join(row["dnf"]), row["flatpak"])
')
[[ $got == "firefox.desktop browser firefox firefox org.mozilla.firefox" ]] || fail "catalog json browser carries every firefox key" "$got"
pass "catalog json browser carries every firefox key"

got=$(gesso-catalog-get --json --kind editor | python3 -c '
import json, sys
print(" ".join(r["id"] for r in json.load(sys.stdin)))
')
[[ $got == "code kate nvim helix zed" ]] || fail "catalog json editor keeps catalog order" "$got"
pass "catalog json editor keeps catalog order"

got=$(gesso-catalog-get --json --kind nothing)
[[ $got == "[]" ]] || fail "catalog json unknown kind prints []" "$got"
pass "catalog json unknown kind prints []"

got=$(gesso-catalog-get --kind browser)
[[ $got == *firefox* ]] || fail "catalog --kind still lists ids" "$got"
got=$(gesso-catalog-get firefox label)
[[ $got == "Firefox" ]] || fail "catalog id field still works" "$got"
pass "catalog single-id and --kind paths unchanged"

got=$(gesso-agent-get --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)
print(len(rows), " ".join(r["id"] for r in rows))
')
[[ $got == "7 grok claude codex opencode copilot crush pi" ]] || fail "agent json lists seven agents with grok" "$got"
pass "agent json lists seven agents with grok"

got=$(gesso-agent-get --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)
row = next(r for r in rows if r["id"] == "grok")
print(row["mise"], " ".join(row["launch"]), row["prompt_flag"])
')
[[ $got == "grok grok --permission-mode bypassPermissions --" ]] || fail "agent json carries every grok key" "$got"
pass "agent json carries every grok key"

got=$(gesso-agent-get --list)
[[ $got == *grok* ]] || fail "agent --list still lists ids" "$got"
got=$(gesso-agent-get grok label)
[[ $got == "Grok" ]] || fail "agent id field still works" "$got"
pass "agent single-id and --list paths unchanged"

if ! got=$(gesso-app-present --list --kind editor); then
  fail "app-present --list exits 0 with nothing present"
fi
[[ -z $got ]] || fail "app-present --list prints nothing before install" "$got"
pass "app-present --list exits 0 with nothing present"

if gesso-app-present --list >/tmp/gesso-present-list-usage 2>&1; then
  fail "app-present --list without --kind exits non-zero"
fi
pass "app-present --list without --kind exits non-zero"

gesso pkg add kate >/dev/null
got=$(gesso-app-present --list --kind editor)
[[ $got == "kate" ]] || fail "app-present --list prints kate after dnf install" "$got"
pass "app-present --list prints kate after dnf install"

gesso pkg add code >/dev/null
got=$(gesso-app-present --list --kind editor)
[[ $got == $'code\nkate' ]] || fail "app-present --list prints code then kate in catalog order" "$got"
pass "app-present --list prints code then kate in catalog order"

got=$(gesso-app-present --list --kind browser)
[[ -z $got ]] || fail "app-present --list scopes to the kind" "$got"
pass "app-present --list scopes to the kind"

if ! gesso-app-present kate; then
  fail "app-present single id still works"
fi
got=$(gesso-app-present --desktop code)
[[ $got == "com.visualstudio.code.desktop" ]] || fail "app-present --desktop still works for flatpak" "$got"
pass "app-present single-id path unchanged"

# Brave Origin ships only from Brave's own RPM repo, so it has no Flatpak
# fallback. See TODO.md.
got=$(gesso-catalog-get brave-origin dnf)
[[ $got == "brave-origin" ]] || fail "brave-origin dnf package" "$got"
got=$(gesso-catalog-get brave-origin command)
[[ $got == "brave-origin" ]] || fail "brave-origin command" "$got"
got=$(gesso-catalog-get brave-origin desktop_id)
[[ $got == "brave-origin.desktop" ]] || fail "brave-origin desktop_id" "$got"
got=$(gesso-catalog-get brave-origin flatpak)
[[ -z $got ]] || fail "brave-origin has no flatpak fallback" "$got"
kinds=$(gesso-catalog-get --kind browser)
[[ $kinds == *brave-origin* ]] || fail "kind browser lists brave-origin" "$kinds"
pass "brave-origin row has a dnf package and no flatpak fallback"
