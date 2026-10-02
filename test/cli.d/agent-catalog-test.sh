#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

cat >"$HOME/gesso-stubs/mise" <<'STUB'
#!/bin/bash
if [[ $1 == "exec" ]]; then
  shift 2
  printf '%s\n' "$@" >"$HOME/agent-argv"
  exit 0
fi
if [[ $1 == "which" ]]; then
  printf '/managed/%s\n' "$2"
  exit 0
fi
exit 1
STUB
chmod +x "$HOME/gesso-stubs/mise"

mkdir -p "$HOME/.config/gesso/defaults"

prompt='--help a path with spaces % # café'
for id in cursor-agent agy omp ori opencode; do
  printf '%s\n' "$id" >"$HOME/.config/gesso/defaults/agent"
  gesso agent -- "$prompt"
  mapfile -t argv <"$HOME/agent-argv"
  case "$id" in
    cursor-agent) expected=(cursor-agent --force --trust agent -- "$prompt") ;;
    agy) expected=(agy --dangerously-skip-permissions --prompt-interactive "$prompt") ;;
    omp) expected=(omp --auto-approve -- "$prompt") ;;
    ori) expected=(ori code --interactive --prompt "$prompt") ;;
    opencode) expected=(opencode --auto --prompt "$prompt") ;;
  esac
  [[ ${#argv[@]} == ${#expected[@]} ]] || fail "$id passes the expected number of arguments"
  for i in "${!expected[@]}"; do
    [[ ${argv[i]} == "${expected[i]}" ]] || fail "$id passes argument $i unchanged" "${argv[i]}"
  done
  pass "$id passes a literal prompt as one argument"
done
