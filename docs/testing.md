# Testing

Non-graphical tests must run on a machine with no Plasma session. That includes CI and a distrobox.

## Runners

| Command | Owns |
|---|---|
| `./test/cli` | Router, metadata lint, theme list/set, default/pkg, setup, and agent against a fake `$HOME` |
| `./test/all` | Runs `./test/cli`, later other suites, continues after a failure, non-zero if any failed |

There is no graphical acceptance suite in v1. Do not open a nested Plasma to prove theme set. File generation plus a stub `plasma-apply-colorscheme` on `PATH` is the proof. Setup tests do not open a window and do not run cmake.

## Contract

`./test/cli` is a thin driver. It runs each `test/cli.d/*-test.sh` as a subprocess and stops at the first failing suite.

Each suite sources `test/lib.sh` and calls `gesso_test_init`, which:

- Resolves `ROOT` from the lib location
- Exports `GESSO_PATH=$ROOT` and a fresh temp `HOME`
- Puts a stub directory and `$ROOT/bin` first on `PATH`
- Uses `pass "description"` / `fail "description"` (first fail exits the suite)

Suites do not share `$HOME`. Router tests in `test/cli.d/cli-test.sh` can write a user theme overlay without affecting `test/cli.d/theme-test.sh`. Default and pkg tests live in `test/cli.d/default-test.sh`. Setup tests live in `test/cli.d/setup-test.sh`. They cover `gesso theme current`, `gesso setup --help`, a missing binary, and a grep that QML has no hardcoded catalog ids and no mise package strings. The suite does not open a window. The suite does not run cmake. Agent tests live in `test/cli.d/agent-test.sh`. They cover `gesso default agent`, `gesso agent` dry-run, and the Work cwd rule.

## Stubs

Never call real `dnf`, `flatpak`, `pkexec`, `sudo`, `xdg-settings`, `plasma-apply-colorscheme`, `gsettings`, or `mise` in unit tests. Drop executable stubs in the test `PATH` that append argv to `$HOME/gesso-stub.log`.

`gesso_test_init` stubs include `dnf`, `flatpak`, `sudo`, `pkexec`, `xdg-settings`, `notify-send`, and `mise`. The `dnf` and `flatpak` stubs also create a fake command so a later present-check succeeds. The `sudo` stub logs and execs the rest of argv. The `mise` stub logs argv and, when an argument contains `grok`, writes a fake `grok` command.

`GESSO_THEME_HEADLESS=1` skips session retints. Theme tests that check generated files still run the stager.

`GESSO_AGENT_DRY_RUN=1` prints `cwd=` and `argv=` instead of `exec`. Agent tests use that. Production launch uses `exec`.

## What not to test in v1

Live Plasma color apply, Discover, COPR, NVIDIA, Aurora rebase. Those are manual checks on a Fedora KDE 44 box after phase 1.
