#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
gesso_test_init

make_agent() {
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0")" "$@" >"$HOME/host-argv"' >"$1"
  chmod +x "$1"
}

cat >"$HOME/gesso-stubs/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$HOME/curl.log"
exit 1
EOF
cat >"$HOME/gesso-stubs/mise" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'mise' >>"$HOME/mise.log"
printf ' %s' "$@" >>"$HOME/mise.log"
printf '\n' >>"$HOME/mise.log"
case ${1:-} in
  which)
    bin=${2##*/}
    [[ -x $HOME/gesso-managed/$bin ]] || exit 1
    printf '%s\n' "$HOME/gesso-managed/$bin"
    ;;
  use)
    bin=${@: -1}
    mkdir -p "$HOME/gesso-managed"
    printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0")" "$@" >"$HOME/host-argv"' >"$HOME/gesso-managed/$bin"
    chmod +x "$HOME/gesso-managed/$bin"
    ;;
  exec)
    shift
    [[ ${1:-} == "--" ]] && shift
    bin=$1
    shift
    exec "$HOME/gesso-managed/$bin" "$@"
    ;;
esac
EOF
chmod +x "$HOME/gesso-stubs/curl" "$HOME/gesso-stubs/mise"

make_agent "$HOME/gesso-stubs/grok"
gesso default agent grok
[[ $(gesso default agent) == grok ]] || fail "native PATH agent becomes default"
[[ ! -e $HOME/mise.log ]] || fail "native PATH agent skips mise" "$(cat "$HOME/mise.log")"
[[ ! -e $HOME/curl.log ]] || fail "native PATH agent skips downloads" "$(cat "$HOME/curl.log")"
gesso agent
got=$(cat "$HOME/host-argv")
expected=$(printf '%s\n' grok --permission-mode bypassPermissions)
[[ $got == "$expected" ]] || fail "native PATH agent launches with its catalog arguments" "$got"
pass "native PATH agent skips mise and launches directly"

mkdir -p "$HOME/relative-tools" "$HOME/Work"
make_agent "$HOME/relative-tools/pi"
if ! (cd "$HOME" && PATH="relative-tools:$PATH" gesso default agent pi && PATH="relative-tools:$PATH" gesso agent); then
  fail "relative PATH agent launches after switching to Work"
fi
[[ $(<"$HOME/host-argv") == "pi" ]] || fail "relative PATH agent receives its catalog arguments"
pass "relative PATH agent launches after switching to Work"
gesso default agent grok

if gesso default agent grok extra >/dev/null 2>&1; then
  fail "default agent rejects extra arguments"
fi
[[ $(gesso default agent) == grok ]] || fail "extra default-agent arguments preserve the selected agent"
rm -f "$HOME/host-argv"
if gesso agent ignored >/dev/null 2>&1; then
  fail "agent rejects arguments without separator"
fi
[[ ! -e $HOME/host-argv ]] || fail "invalid agent arguments do not launch"
pass "agent commands reject unsupported extra arguments"

mv "$HOME/gesso-stubs/mise" "$HOME/mise-disabled"
make_agent "$HOME/gesso-stubs/claude"
gesso default agent claude
gesso agent
got=$(cat "$HOME/host-argv")
expected=$(printf '%s\n' claude --permission-mode auto)
[[ $got == "$expected" ]] || fail "native PATH agent launches without mise" "$got"
[[ ! -e $HOME/curl.log ]] || fail "native PATH agent without mise skips downloads" "$(cat "$HOME/curl.log")"
pass "native PATH agent launches without mise on PATH"

mkdir -p "$HOME/.local/bin"
make_agent "$HOME/.local/bin/codex"
[[ $PATH != *"$HOME/.local/bin"* ]] || fail "per-user binary fixture is off PATH"
gesso default agent codex
gesso agent
got=$(cat "$HOME/host-argv")
expected=$(printf '%s\n' codex --ask-for-approval never)
[[ $got == "$expected" ]] || fail "per-user agent launches from .local/bin" "$got"
[[ ! -e $HOME/curl.log ]] || fail "per-user agent skips downloads" "$(cat "$HOME/curl.log")"
pass "per-user executable launches even when it is off PATH"

mv "$HOME/mise-disabled" "$HOME/gesso-stubs/mise"
export MISE_DATA_DIR=$HOME/mise-data
mkdir -p "$MISE_DATA_DIR/shims"
make_agent "$MISE_DATA_DIR/shims/opencode"
export PATH="$MISE_DATA_DIR/shims:$PATH"
gesso default agent opencode
log=$(cat "$HOME/mise.log")
[[ $log == *"mise use -g opencode"* ]] || fail "a mise shim does not satisfy default-agent installation" "$log"
[[ -x $HOME/gesso-managed/opencode ]] || fail "mise installs the managed agent"
gesso agent
got=$(cat "$HOME/host-argv")
expected=$(printf '%s\n' opencode --auto)
[[ $got == "$expected" ]] || fail "managed agent executes with catalog arguments" "$got"
log=$(cat "$HOME/mise.log")
[[ $log == *"mise exec -- opencode --auto"* ]] || fail "managed agent launches through mise" "$log"
pass "mise shims are checked with mise which and managed launch is preserved"
