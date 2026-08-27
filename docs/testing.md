# Testing

Non-graphical tests must run on a machine with no Plasma session. That includes CI and a distrobox.

## Runners

| Command | Owns |
|---|---|
| `./test/cli` | Router, metadata lint, theme list/set against a fake `$HOME` |
| `./test/all` | Runs `./test/cli`, later other suites, continues after a failure, non-zero if any failed |

There is no graphical acceptance suite in v1. Do not open a nested Plasma to prove theme set. File generation plus a stub `plasma-apply-colorscheme` on `PATH` is the proof.

## Contract

`./test/cli` is a bash script. It:

- Resolves `ROOT` from its own location
- Exports `GESSO_PATH=$ROOT` and a temp `HOME`
- Puts `$ROOT/bin` and a stub `PATH` directory first
- Uses `pass "description"` / `fail "description"` (first fail exits the script)

Phase 0 keeps all CLI assertions in `./test/cli`. When that file is painful to scroll, split to `test/cli.d/*-test.sh` and a thin `./test/cli` driver. Do not split before the second suite exists.

## Stubs

Never call real `dnf`, `flatpak`, `pkexec`, `plasma-apply-colorscheme`, or `gsettings` in unit tests. Drop executable stubs in the test `PATH` that record their argv to a log file.

`GESSO_THEME_HEADLESS=1` skips session retints. Theme tests that check generated files still run the stager.

## What not to test in v1

Live Plasma color apply, Discover, COPR, NVIDIA, Aurora rebase. Those are manual checks on a Fedora KDE 44 box after phase 1.
