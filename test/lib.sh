#!/bin/bash

gesso_test_init() {
  local libdir stub sys cmd path
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
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exec "$@"' >"$stub/pkexec"
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exit 0' >"$stub/notify-send"
  printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$(basename "$0") $*" >>"$HOME/gesso-stub.log"' 'exec "$@"' >"$stub/sudo"
  cat >"$stub/dnf" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
stub=$HOME/gesso-stubs
install=0
for arg in "$@"; do
  if [[ $arg == "install" ]]; then
    install=1
  fi
done
if ((install == 1)); then
  for arg in "$@"; do
    if [[ $arg == "install" || $arg == "-y" || $arg == "flathub" ]]; then
      continue
    fi
    if [[ $arg == *.* ]]; then
      continue
    fi
    name=$arg
    if [[ $arg == "helix" ]]; then
      name=hx
    fi
    printf '%s\n' '#!/bin/bash' 'exit 0' >"$stub/$name"
    chmod +x "$stub/$name"
  done
fi
exit 0
EOF
  cat >"$stub/flatpak" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
state=$HOME/.local/state/gesso-flatpak
mkdir -p "$state"
install=0
info=0
for arg in "$@"; do
  if [[ $arg == "install" ]]; then
    install=1
  fi
  if [[ $arg == "info" ]]; then
    info=1
  fi
done
if ((install == 1)); then
  for arg in "$@"; do
    if [[ $arg == "install" || $arg == "-y" || $arg == "flathub" ]]; then
      continue
    fi
    if [[ $arg == -* ]]; then
      continue
    fi
    printf '%s\n' "" >"$state/$arg"
  done
  exit 0
fi
if ((info == 1)); then
  for arg in "$@"; do
    if [[ $arg == "info" || $arg == -* ]]; then
      continue
    fi
    if [[ -f $state/$arg ]]; then
      exit 0
    fi
  done
  exit 1
fi
exit 0
EOF
  cat >"$stub/xdg-settings" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
state=$HOME/.local/state/gesso-xdg/default-web-browser
mkdir -p "$(dirname "$state")"
if [[ ${1:-} == "get" && ${2:-} == "default-web-browser" ]]; then
  if [[ -f $state ]]; then
    cat "$state"
    exit 0
  fi
  exit 1
fi
if [[ ${1:-} == "set" && ${2:-} == "default-web-browser" ]]; then
  printf '%s\n' "${3:-}" >"$state"
  exit 0
fi
exit 0
EOF
  cat >"$stub/mise" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0") $*" >>"$HOME/gesso-stub.log"
state=$HOME/.local/state/gesso-mise
mkdir -p "$state"
if [[ ${1:-} == "use" ]]; then
  for arg in "$@"; do
    if [[ $arg == "use" || $arg == -* ]]; then
      continue
    fi
    bin=${arg##*/}
    printf '%s\n' "$arg" >"$state/$bin"
  done
  exit 0
fi
if [[ ${1:-} == "which" ]]; then
  bin=${2:-}
  if [[ -n $bin && -f $state/$bin ]]; then
    printf '%s\n' "$state/$bin"
    exit 0
  fi
  exit 1
fi
if [[ ${1:-} == "exec" ]]; then
  shift
  if [[ ${1:-} == "--" ]]; then
    shift
  fi
  bin=${1:-}
  if [[ -n $bin && -f $state/$bin ]]; then
    exit 0
  fi
  exit 1
fi
exit 0
EOF
  chmod +x "$stub/plasma-apply-colorscheme" "$stub/gsettings" "$stub/pkexec" \
    "$stub/notify-send" "$stub/sudo" "$stub/dnf" "$stub/flatpak" "$stub/xdg-settings" \
    "$stub/mise"
  sys=$HOME/gesso-sys
  mkdir -p "$sys"
  for cmd in python3 awk sed grep head cut sort cat mkdir chmod cp mv rm ln \
    basename dirname mktemp flock env uname tr tee touch bash wc date sleep \
    cmp diff id; do
    path=$(type -P "$cmd" 2>/dev/null) || continue
    ln -s "$path" "$sys/$cmd"
  done
  export PATH="$stub:$ROOT/bin:$sys"
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
