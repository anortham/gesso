#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/test/lib.sh"
gesso_test_init

if ! help=$(gesso default editor --help); then
  fail "default editor help exits successfully"
fi
[[ $help == *"Usage: gesso default editor [id]"* ]] || fail "default editor keeps help output" "$help"
pass "default editor keeps help output"

cat >"$HOME/gesso-stubs/xdg-mime" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
exit "${GESSO_XDG_MIME_STATUS:-0}"
EOF
chmod +x "$HOME/gesso-stubs/xdg-mime"
printf '%s\n' '#!/bin/bash' 'exit 0' >"$HOME/gesso-stubs/nvim"
chmod +x "$HOME/gesso-stubs/nvim"
gesso-app-present nvim || fail "nvim fixture is available"

editor_file=$HOME/.local/state/gesso/defaults/editor
mkdir -p "$(dirname "$editor_file")"
printf 'kate\n' >"$editor_file"
rm -f "$HOME/gesso-stub.log"
if GESSO_XDG_MIME_STATUS=1 gesso default editor nvim >/tmp/gesso-editor-mime-failure 2>&1; then
  fail "default editor reports xdg-mime failure"
fi
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"xdg-mime default "* ]] || fail "xdg-mime failure fixture was invoked" "$log"
got=$(cat "$editor_file")
[[ $got == "kate" ]] || fail "failed xdg-mime keeps previous editor" "$got"
pass "failed xdg-mime keeps previous editor"

rm -f "$editor_file"
rm -f "$HOME/gesso-stub.log"
if GESSO_XDG_MIME_STATUS=1 gesso default editor nvim >/tmp/gesso-editor-unset-failure 2>&1; then
  fail "default editor reports xdg-mime failure when unset"
fi
log=$(cat "$HOME/gesso-stub.log")
[[ $log == *"xdg-mime default "* ]] || fail "unset xdg-mime failure fixture was invoked" "$log"
[[ ! -e $editor_file ]] || fail "failed xdg-mime keeps editor unset"
pass "failed xdg-mime keeps editor unset"

rm -f "$HOME/gesso-stub.log"
if GESSO_XDG_MIME_STATUS=0 gesso default editor nvim extra >/tmp/gesso-editor-extra-args 2>&1; then
  fail "default editor rejects extra ids"
fi
[[ ! -e $editor_file ]] || fail "extra editor ids do not write state" "$(cat "$editor_file")"
[[ ! -s $HOME/gesso-stub.log ]] || fail "extra editor ids cause no package or MIME changes" "$(cat "$HOME/gesso-stub.log")"
pass "default editor rejects extra ids before side effects"
