#!/bin/bash

gesso_test_init() {
  local libdir stub
  libdir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  ROOT=$(cd -- "$libdir/.." && pwd)
  export ROOT
  export GESSO_PATH=$ROOT
  export HOME
  HOME=$(mktemp -d)
  stub=$HOME/gesso-stubs
  mkdir -p "$stub"
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 0' >"$stub/plasma-apply-colorscheme"
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 0' >"$stub/gsettings"
  chmod +x "$stub/plasma-apply-colorscheme" "$stub/gsettings"
  export PATH="$stub:$ROOT/bin:$PATH"
}

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  if (($# > 1)); then
    printf '%s\n' "$2" >&2
  fi
  exit 1
}
