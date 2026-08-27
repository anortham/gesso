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
