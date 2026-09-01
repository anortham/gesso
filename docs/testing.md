# Testing

Non-graphical tests must run on a machine with no Plasma session. That includes CI and a distrobox.

## Runners

| Command | Owns |
|---|---|
| `./test/cli` | Router, metadata lint, theme list/set/restore, default/pkg, catalog helpers, setup, agent, and packaging against a fake `$HOME` |
| `./test/all` | Runs `./test/cli`, later other suites, continues after a failure, non-zero if any failed |

There is no graphical acceptance suite in v1. Do not open a nested Plasma to prove theme set. File generation plus a stub `plasma-apply-colorscheme` on `PATH` is the proof. Setup tests do not open a window and do not run cmake.

## Contract

`./test/cli` is a thin driver. It runs each `test/cli.d/*-test.sh` as a subprocess and stops at the first failing suite.

Each suite sources `test/lib.sh` and calls `gesso_test_init`, which:

- Resolves `ROOT` from the lib location
- Exports `GESSO_PATH=$ROOT` and a fresh temp `HOME`
- Puts a stub directory (`$HOME/gesso-stubs`) and `$ROOT/bin` first on `PATH`
- Uses `pass "description"` / `fail "description"` (first fail exits the suite)

Suites do not share `$HOME`.

| Suite | Covers |
|---|---|
| `test/cli.d/cli-test.sh` | Router resolution, generated `gesso --help`, `(sudo)` marker, hidden commands, group listings, metadata lint, the required-arg rule, a user theme overlay |
| `test/cli.d/theme-test.sh` | `theme set` files, both VS Code targets, Konsole and GTK backups, wallpaper, Ghostty and Foot outputs, all five palettes, `theme restore` |
| `test/cli.d/default-test.sh` | Default browser, terminal, editor (`xdg-mime`), `pkg add` with dnf then per-user Flatpak |
| `test/cli.d/catalog-test.sh` | `gesso-catalog-get --json --kind`, `--kind`, and single-field reads |
| `test/cli.d/setup-test.sh` | `gesso theme current`, `gesso setup --help`, a missing binary, QML greps: no hardcoded catalog ids, no mise package strings, `--json` and `--list` loads, `runAsync`, `konsole --hold`, Launch disabled without a default, pages built once |
| `test/cli.d/agent-test.sh` | `gesso default agent`, the per-user mise install, `gesso agent` dry-run, the Work cwd rule |
| `test/cli.d/packaging-test.sh` | `packaging/gesso.spec` (two packages, libexec, `xdg-utils`, no `gesso-agents`, no `qtquickcontrols2`, no `/etc`), the desktop file icon, `gesso theme restore`, the libexec launcher, `.github/workflows/ci.yml` |

The setup suite does not open a window and does not run cmake. The packaging suite does not run `rpmbuild`, `mock`, or `copr-cli`.

## Stubs

Never call real `dnf`, `flatpak`, `pkexec`, `sudo`, `xdg-settings`, `xdg-mime`, `plasma-apply-colorscheme`, `plasma-apply-wallpaperimage`, `gsettings`, `curl`, or `mise` in unit tests. Drop executable stubs in the test `PATH` that append argv to `$HOME/gesso-stub.log`.

`gesso_test_init` stubs include `dnf`, `flatpak`, `sudo`, `pkexec`, `xdg-settings`, `xdg-mime`, `gsettings`, `plasma-apply-colorscheme`, `notify-send`, and `mise`. The `dnf` stub creates a host binary named after each package, except `helix`, which creates `hx` and never a `helix` binary. The `flatpak` stub records ids under `$HOME/.local/state/gesso-flatpak/`. `flatpak remote-add` exits 0. `flatpak install` skips `--user`, `-y`, and `flathub` and records the id. `flatpak info` exits 0 only for a recorded id. It never creates a host binary such as `google-chrome`. The `sudo` stub logs and execs the rest of argv. The `xdg-mime` stub logs argv and exits 0. The `mise` stub logs argv. `mise use -g` records the spec under `$HOME/.local/state/gesso-mise/`. `mise which` and `mise exec --` succeed only after that record. It never writes a `grok` binary into the stub PATH.

Three stubs are suite-local. `test/cli.d/agent-test.sh` moves the `mise` stub aside, then adds `curl` and `sh` stubs so `curl -fsSL https://mise.run | ... sh` copies the saved stub to `$MISE_INSTALL_PATH`. The agent suite puts the `mise` stub back and removes `curl` and `sh` when done. `test/cli.d/theme-test.sh` adds `plasma-apply-wallpaperimage` for the wallpaper checks and keeps it for the rest of that suite.

`GESSO_THEME_HEADLESS=1` skips session retints. Theme tests that check generated files still run the stager.

`GESSO_AGENT_DRY_RUN=1` prints `cwd=` and `argv=` instead of `exec`. Agent tests use that. Production launch uses `exec`.

## CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on push to `main` and on pull requests. Both jobs run in a `registry.fedoraproject.org/fedora:44` container. Job `cli` installs `bash`, `python3`, `util-linux`, and `git`, then runs `./test/all`. Job `setup` installs `cmake`, `extra-cmake-modules`, `gcc-c++`, `kf6-kirigami-devel`, `qt6-qtbase-devel`, and `qt6-qtdeclarative-devel`, then runs `cmake -S setup -B build` and `cmake --build build`. Neither job runs `rpmbuild` or COPR.

## What not to test in v1

Live Plasma color apply, Discover, COPR, NVIDIA, Aurora rebase, `rpmbuild`. Those are manual checks on a Fedora KDE 44 box.
