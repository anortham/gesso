# Phase 5 packaging design

Date: 2026-08-27

Status: approved spec. Implementation plan: `plans/2026-08-27-phase-5.md`.

## Purpose

Ship Gesso as COPR RPMs for Fedora 44. A user runs `dnf copr enable <owner>/gesso && dnf install gesso-plasma` and gets the CLI plus Setup. Uninstall leaves Plasma usable. This is not a remix, ISO, or bootc image.

## Constraints

- No `/etc` drop-ins. No SDDM, bootloader, or NVIDIA.
- Router already sets `GESSO_PATH=/usr/share/gesso` when there is no `themes/` next to `bin/`. Do not add `environment.d` in v1.
- Never call COPR or `copr-cli` from `./test/cli`. No network. No credentials in the repo.
- `./test/cli` must stay green without `rpmbuild` or Kirigami devel. Optional `rpmbuild` is lead/manual.
- License: MIT. Add a `LICENSE` file (none exists today).
- Do not vendor Omarchy. Do not write a Fedora kickstart.

## Success

- `packaging/gesso.spec` builds three packages: `gesso`, `gesso-plasma`, `gesso-agents`.
- `gesso-plasma` Requires `gesso`. User-facing install is `gesso-plasma`.
- Packaged CLI uses `$GESSO_PATH=/usr/share/gesso` via the existing router default.
- The Kirigami binary is `/usr/libexec/gesso/gesso-setup`. The bash launcher stays `/usr/bin/gesso-setup` and execs that path. The two names no longer collide on PATH.
- `gesso theme restore` applies BreezeDark or Breeze when Gesso was the last theme. Headless tests skip Plasma and still exit 0.
- Docs tell how to enable the COPR. This phase does not publish a COPR from CI.
- `./test/all` stays green.
- Aurora is documented as untested.

## Architecture Quality

**Affected modules:** `packaging/gesso.spec`, `bin/gesso-setup` search path, CMake install dest, `bin/gesso-theme-restore`, docs.

**Caller-facing interface:** `dnf install gesso-plasma`, `gesso theme restore`, `gesso setup` after plasma is installed.

**Depth/locality check:** RPM file lists only. No new plugin host. Restore is one command.

**Test surface:** launcher looks for libexec; restore is headless-safe; spec text contains the three package names and no `/etc`.

**Seams/adapters:** RPM payload vs `$HOME` state. COPR publish is a human adapter, not a test.

**Rejected shortcuts:** One fat RPM. Putting the Qt binary on PATH as `gesso-setup`. `%preun` that guesses the logged-in user's Plasma session. Checking in COPR tokens.

**Architecture risk:** medium. Scriptlets that talk to a user session are the usual RPM footgun. Keep restore as a user command.

## Packages

One spec file, three RPM names (Fedora subpackages):

| Package | Payload | Requires |
|---|---|---|
| `gesso` | `/usr/bin/gesso`, `/usr/bin/gesso-*` (all current `bin/` scripts), `/usr/share/gesso/{themes,default,data}` | `bash`, `python3`. Recommend `plasma-workspace`. |
| `gesso-plasma` | `/usr/libexec/gesso/gesso-setup`, `/usr/share/applications/org.gesso.setup.desktop` | `gesso`, `kf6-kirigami`, `qt6-qtdeclarative` |
| `gesso-agents` | no files (metapackage) | `gesso`, `mise` |

`gesso-agents` exists so `dnf install gesso-agents` pulls `mise`. Agent scripts already live in `gesso`.

Do not ship `.memories/`, `plans/`, or tests in the RPM.

## Binary layout

| Path | What |
|---|---|
| `/usr/bin/gesso` | Router |
| `/usr/bin/gesso-setup` | Bash launcher (same script as `bin/gesso-setup`) |
| `/usr/libexec/gesso/gesso-setup` | Compiled Kirigami app |
| `/usr/share/gesso/` | themes, templates, catalogs |
| `/usr/share/applications/org.gesso.setup.desktop` | `Exec=gesso setup` |

CMake `install(TARGETS gesso-setup DESTINATION ${CMAKE_INSTALL_LIBEXECDIR}/gesso)`.

Launcher search order:

1. `$GESSO_SETUP_BIN` if executable
2. Checkout `$GESSO_PATH/setup/build/gesso-setup` or `$GESSO_ROOT/setup/build/gesso-setup`
3. `/usr/libexec/gesso/gesso-setup`
4. Stop. Do not search PATH for another `gesso-setup` (that was the collision).

## `gesso theme restore`

```
# gesso:summary=Restore Breeze if Gesso last applied a color scheme
# gesso:args=
```

1. If `~/.local/state/gesso/current/theme.name` is missing, exit 0 (nothing to restore).
2. Read `mode` from `~/.local/state/gesso/current/theme/colors.toml` if present. `light` → `Breeze`. Else `BreezeDark`.
3. If `GESSO_THEME_HEADLESS` is set, skip Plasma and exit 0.
4. Else run `plasma-apply-colorscheme Breeze` or `BreezeDark`. Failure is an error.
5. Do not delete `~/.config/gesso` or `~/.local/state/gesso`.

RPM `%preun` / `%postun` do not call this. README: run `gesso theme restore` before `dnf remove gesso-plasma gesso` if Gesso is the active scheme.

## COPR

Docs only in this phase:

```
dnf copr enable <owner>/gesso
dnf install gesso-plasma
```

`<owner>` is a placeholder until someone creates the project. Do not invent an owner. `packaging/README.md` lists the human steps: create the COPR for Fedora 44, point it at this spec, build, then enable.

No GitHub Action that uploads RPMs until a COPR exists.

## Testing

`test/cli.d/packaging-test.sh`:

- `packaging/gesso.spec` exists
- spec contains `%package plasma`, `%package agents`, `Name: gesso`
- spec does not contain `/etc/`
- spec installs libexec `gesso/gesso-setup`
- `gesso theme restore --help` exits 0
- Headless restore after `theme set tokyo-night` exits 0
- Non-headless restore with stubs logs `plasma-apply-colorscheme BreezeDark` (tokyo-night is dark)
- Missing setup binary still exits 1 when libexec and `GESSO_SETUP_BIN` are absent
- Existing suites stay green

Do not run `rpmbuild` or `mock` in `./test/cli`.

## Docs this spec updates (in the implementation plan)

- `docs/packaging.md`: real spec path, three packages, libexec, restore, COPR placeholder
- `docs/layout.md`: installed paths including libexec
- `docs/cli.md`: `gesso theme restore`
- `docs/testing.md`: packaging suite
- `plans/README.md`, `AGENTS.md`, root `README.md` COPR line

## Out of scope

Creating the COPR project, signing keys, COPR tokens, Aurora variants, `gesso-agents` extra binaries, Look-and-Feel art, ISO, bootc.
