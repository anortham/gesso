#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

for command in 'default browser firefox' 'default terminal konsole' 'pkg add firefox'; do
  read -r -a argv <<< "$command"
  rm -f "$HOME/gesso-stub.log"
  if gesso "${argv[@]}" unexpected >"$HOME/argument-error" 2>&1; then
    fail "$command rejects extra arguments"
  fi
  [[ $(<"$HOME/argument-error") == *Usage:* ]] || fail "$command shows usage for extra arguments"
  [[ ! -f $HOME/gesso-stub.log ]] || fail "$command rejects extra arguments before side effects"
  pass "$command rejects extra arguments before side effects"
done
