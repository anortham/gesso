# v1 correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use razorback:subagent-driven-development when subagent delegation is available. Fall back to razorback:executing-plans for single-task, tightly-sequential, or no-delegation runs. Follow razorback:test-driven-development on every task: write the failing test first, run it, implement, run it again.

**Goal:** Make the claimed v1 install, default, agent, theme, and Setup paths work, and make the docs match the code.

**Architecture:** One hidden helper (`gesso-app-present`) is the host-vs-Flatpak presence API. Agents install and launch through `mise`. Setup talks to the CLI asynchronously and detaches Konsole. Theme set validates, then publishes. VS Code colors merge into `workbench.colorCustomizations` and restore from Gesso state.

**Tech Stack:** Bash 5, Python 3 tomllib/json, Kirigami 6 / Qt 6 QProcess, TAP `./test/cli`, RPM spec text.

**Architecture Quality:** Spec `plans/2026-08-27-v1-correctness-design.md`. Presence helper is the chosen lane. Risk medium. Do not add a second presence model in QML or a second agent launcher.

## Global Constraints

- Spec: `plans/2026-08-27-v1-correctness-design.md`. Follow it. Report a plan mismatch instead of redesigning.
- CLI is the API. Setup only execs `gesso-*`. No app ids in QML.
- No `/etc`. No Hyprland. No Omarchy copy. No COPR owner. Do not tag, push, or publish.
- `gesso-app-present <id>` exits 0 for host `command` or `flatpak info`. `--desktop` prints host `desktop_id` or `<flatpak>.desktop`.
- Helix: `command = "hx"`, `desktop_id = "Helix.desktop"`.
- Codex launch: `["codex", "--ask-for-approval", "never"]`. Source: https://developers.openai.com/codex/cli/reference
- Theme names: `^[a-z0-9]+(-[a-z0-9]+)*$`. Lock: `${XDG_RUNTIME_DIR:-$HOME/.local/state/gesso}/gesso-theme-set.lock`. Never `/tmp`.
- `GessoCli` must not call `waitForFinished(-1)`. One async call in flight. Launch Agent is `startDetached`.
- `./test/cli` uses stubs. No real dnf, flatpak, mise, Plasma, or rpmbuild.
- Two-space indent. `#!/bin/bash`. `# gesso:summary=` on every `bin/gesso-*`. Hidden helpers set `# gesso:hidden=true`.
- Worktree: `/home/murphy/source/gesso/.worktrees/v1-correctness` on branch `v1-correctness`.

---

## File structure

| Path | Responsibility |
|---|---|
| `bin/gesso-app-present` | Hidden presence + `--desktop` |
| `bin/gesso-pkg-add` | Install until app-present |
| `bin/gesso-default-browser` | Present-check and XDG desktop from helper |
| `bin/gesso-default-terminal` | Same for `xdg-terminals.list` |
| `bin/gesso-default-editor` | Present-check; still writes catalog id |
| `data/apps.toml` | Helix `hx` / `Helix.desktop` |
| `test/lib.sh` | Honest dnf/flatpak/mise stubs |
| `bin/gesso-default-agent` | Install mise, `mise which`, then write default |
| `bin/gesso-agent` | `mise exec --` when mise exists |
| `data/agents.toml` | Codex flag |
| `packaging/gesso.spec` | plasma Recommends gesso-agents |
| `setup/GessoCli.hpp` `setup/GessoCli.cpp` | Bounded sync wait, async, startDetached |
| `setup/qml/*.qml` | Present helper, async default/pkg, detached launch |
| `bin/gesso-theme-set` | Name, lock, validate, atomic publish, VS Code merge |
| `bin/gesso-theme-set-templates` | Fail on leftover `{{` |
| `bin/gesso-theme-restore` | Restore VS Code colorCustomizations |
| `bin/gesso` | `--` ends help scan; bare group lists children |
| `docs/*` `plans/2026-08-26-product.md` `AGENTS.md` | Match the code |
| `packaging/README.md` | Tag-then-COPR human steps |

## Verification Strategy

**Project source of truth:** `docs/testing.md`, `AGENTS.md`, the v1 correctness spec

**Worker red/green scope:** `./test/cli`

**Worker ceiling:** `./test/all`

**Worker gate invariant:** `./test/cli` prints only `ok -` lines and exits 0. Existing suites stay green at the end of every task.

**Lead affected-change scope:** `./test/all` after each task, plus a read of the owned files against the spec.

**Branch gate:** `./test/all`

**Replay/metric evidence:** none

**Escalation triggers:** none. Do not run `rpmbuild`, cmake, or a Plasma session.

**Assigned verification failure:** Stop. Do not weaken assertions. The VS Code test that forbids `settings.json` must be replaced with merge/restore assertions, not deleted without a replacement.

**Verification ledger:** Record command, HEAD, result after each task commit.

TDD: failing test first for each new behavior. Do not implement before the test fails.

Commit mode: `serial-worker-commit`. After `./test/cli` is green, commit owned files and tick this plan's checkboxes for that task.

## Parallel Execution Contract

| Task | Parallel batch | File ownership | Serialization required | Dependency reason |
|---|---|---|---|---|
| Task 1: App presence | None - serial | Create `bin/gesso-app-present`. Modify `bin/gesso-pkg-add`, `bin/gesso-default-browser`, `bin/gesso-default-terminal`, `bin/gesso-default-editor`, `data/apps.toml`, `test/lib.sh` (dnf + flatpak stubs only; leave mise stub), `test/cli.d/default-test.sh`, `setup/qml/DefaultsPage.qml`, `setup/qml/InstallPage.qml`, `docs/catalog.md` (apps/presence), `docs/testing.md` (dnf/flatpak stub paragraphs). Tick Task 1 in this plan. | Yes | Later tasks need the helper and honest Flatpak stubs. |
| Task 2: Agents | None - serial | Modify `bin/gesso-default-agent`, `bin/gesso-agent`, `data/agents.toml`, `packaging/gesso.spec`, `test/lib.sh` (mise stub only), `test/cli.d/agent-test.sh`, `test/cli.d/packaging-test.sh` (Recommends assertion), `docs/catalog.md` (agents), `docs/testing.md` (mise stub paragraph), `docs/packaging.md` (Recommends). Tick Task 2 in this plan. | Yes | Mise stub rewrite would break agent tests if done in Task 1. |
| Task 3: Setup async | None - serial | Modify `setup/GessoCli.hpp`, `setup/GessoCli.cpp`, `setup/qml/DefaultsPage.qml`, `setup/qml/InstallPage.qml`, `setup/qml/AgentsPage.qml`, `test/cli.d/setup-test.sh`. Tick Task 3 in this plan. | Yes | Present calls from Task 1 stay; this task changes how QML waits. |
| Task 4: Theme + VS Code | None - serial | Modify `bin/gesso-theme-set`, `bin/gesso-theme-set-templates`, `bin/gesso-theme-restore`, `test/cli.d/theme-test.sh`, `docs/theming.md`. Tick Task 4 in this plan. | Yes | Independent of agents, but docs and restore must land together. |
| Task 5: Router + claims | None - serial | Modify `bin/gesso`, `test/cli.d/cli-test.sh`, `docs/cli.md`, `plans/2026-08-26-product.md`, `AGENTS.md`. Tick Task 5 in this plan. | Yes | After behavior exists so the product brief does not lie. |
| Task 6: Packaging checklist | None - serial | Modify `packaging/README.md`, `docs/packaging.md`, `test/cli.d/packaging-test.sh` (Source0 / checklist assertions), `README.md` only if the COPR steps need the tag line. Tick Task 6 in this plan. | Yes | After Recommends exists. |

---

### Task 1: App presence

**Files:**
- Create: `bin/gesso-app-present`
- Modify: `bin/gesso-pkg-add:23-58`, `bin/gesso-default-browser:16-55`, `bin/gesso-default-terminal:18-60`, `bin/gesso-default-editor:44-49`, `data/apps.toml:117-123`, `test/lib.sh:19-53`, `test/cli.d/default-test.sh`, `setup/qml/DefaultsPage.qml:104-108`, `setup/qml/InstallPage.qml:83-87`, `docs/catalog.md:23-31`, `docs/testing.md:27-31`

**Interfaces:**
- Consumes: `gesso-catalog-get`, `gesso-cmd-present`, catalog `command` / `desktop_id` / `flatpak`
- Produces: `gesso-app-present <id>` exit 0/1; `gesso-app-present --desktop <id>` prints one desktop file; pkg-add succeeds without a host binary when Flatpak is recorded; default browser/terminal set that desktop file

**Contract inputs:** Hidden helper. Unknown id: `Unknown app: <id>` on stderr, exit 1. Flatpak desktop is `<flatpak>.desktop`. Helix command `hx`.

**File ownership:** Create `bin/gesso-app-present`. Modify `bin/gesso-pkg-add`, `bin/gesso-default-browser`, `bin/gesso-default-terminal`, `bin/gesso-default-editor`, `data/apps.toml`, `test/lib.sh` (dnf + flatpak stubs only; leave mise stub), `test/cli.d/default-test.sh`, `setup/qml/DefaultsPage.qml`, `setup/qml/InstallPage.qml`, `docs/catalog.md` (apps/presence), `docs/testing.md` (dnf/flatpak stub paragraphs). Tick Task 1 in this plan.

**Serialization required:** Yes

**Dependency reason:** Later tasks need the helper and honest Flatpak stubs.

**What to build:** Host-or-Flatpak presence, Helix `hx`, and defaults that set the desktop file for the backend that is actually installed.

**Approach:** Follow `gesso-cmd-present` / `gesso-catalog-get` style. Presence: host command, else `flatpak info "$flatpak"`. `--desktop`: host `desktop_id` if host present, else `<flatpak>.desktop`. `gesso-pkg-add` uses app-present before and after each backend. Browser/terminal GET must recognize both catalog `desktop_id` and `<flatpak>.desktop` so `gesso default browser` prints `chrome` after a Flatpak install. dnf stub: package `helix` creates `hx`, not `helix`; other packages still create a same-named host binary. flatpak stub: record ids under `$HOME/.local/state/gesso-flatpak/`; `install` records; `info` exits 0 only for recorded ids; never create `google-chrome`. QML present checks call `gesso-app-present` with the catalog id. Leave the mise stub unchanged.

**Acceptance criteria:**
- [x] `gesso pkg add chrome` succeeds with no `google-chrome` on PATH when Flatpak id `com.google.Chrome` is recorded
- [x] `gesso default browser chrome` runs `xdg-settings set default-web-browser com.google.Chrome.desktop` and later `gesso default browser` prints `chrome`
- [x] `gesso pkg add helix` makes `gesso-app-present helix` exit 0 via `hx`
- [x] DefaultsPage and InstallPage use `gesso-app-present` with the app id
- [x] Existing firefox/dnf tests still pass
- [x] Worker-scope verification passes and the change is committed (`serial-worker-commit`)

### Task 2: Agents

**Files:**
- Modify: `bin/gesso-default-agent:40-50`, `bin/gesso-agent:50-60`, `data/agents.toml:16-19`, `packaging/gesso.spec:25-29`, `test/lib.sh` mise stub, `test/cli.d/agent-test.sh`, `test/cli.d/packaging-test.sh:48-56`, `docs/catalog.md:53-62`, `docs/testing.md:31`, `docs/packaging.md:11`

**Interfaces:**
- Consumes: `gesso-agent-get`, Task 1 PATH/stubs
- Produces: default file only after `mise which <launch_bin>` succeeds; `gesso agent` argv starts with `mise exec --` when mise exists; Codex `--ask-for-approval never`; plasma Recommends gesso-agents

**Contract inputs:** If mise is missing, elevate `dnf install -y mise` with the same sudo/pkexec split as pkg-add. Do not use `--yolo` for Codex. Grounding: https://developers.openai.com/codex/cli/reference

**File ownership:** Modify `bin/gesso-default-agent`, `bin/gesso-agent`, `data/agents.toml`, `packaging/gesso.spec`, `test/lib.sh` (mise stub only), `test/cli.d/agent-test.sh`, `test/cli.d/packaging-test.sh` (Recommends assertion), `docs/catalog.md` (agents), `docs/testing.md` (mise stub paragraph), `docs/packaging.md` (Recommends). Tick Task 2 in this plan.

**Serialization required:** Yes

**Dependency reason:** Mise stub rewrite would break agent tests if done in Task 1.

**What to build:** Reliable agent install/launch from a machine that has no agent binary on PATH, plus a valid Codex skip-prompt flag.

**Approach:** Rewrite the mise stub: `mise use -g` records the spec; `mise which <bin>` and `mise exec --` succeed only after that record; do not write `grok` into the stub PATH. `gesso-cmd-present grok` stays 1. `gesso default agent` uses `mise which`, not `gesso-cmd-present`. After a failed which, run `mise use -g` and recheck; do not write the default file if which still fails. Launch: if `command -v mise`, exec `mise exec -- "${argv[@]}"`. Dry-run prints that argv. Tests: grok is not on PATH after default-agent; dry-run contains `mise exec --`; Codex catalog line contains `--ask-for-approval never`; spec text contains `Recommends: gesso-agents` on the plasma package.

**Acceptance criteria:**
- [x] Default agent does not write `~/.config/gesso/defaults/agent` when `mise which` fails
- [x] After a successful grok default, `gesso-cmd-present grok` is still 1 and `GESSO_AGENT_DRY_RUN=1 gesso agent` includes `mise exec --` and `grok`
- [x] Codex launch field is `codex --ask-for-approval never`
- [x] `packaging/gesso.spec` plasma package Recommends `gesso-agents`
- [x] Worker-scope verification passes and the change is committed (`serial-worker-commit`)

### Task 3: Setup async

**Files:**
- Modify: `setup/GessoCli.hpp:8-16`, `setup/GessoCli.cpp:11-40`, `setup/qml/DefaultsPage.qml:91-111` and `applyDefault`, `setup/qml/InstallPage.qml:93-100`, `setup/qml/AgentsPage.qml:91-115`, `test/cli.d/setup-test.sh:34-62`

**Interfaces:**
- Consumes: Task 1 `gesso-app-present`; existing `run` / `runBinary`
- Produces: `runAsync`, `runBinaryAsync`, `startDetached`, signal `finished(QVariantMap)`; no `waitForFinished(-1)`

**Contract inputs:** Qt 6 `QProcess`: https://doc.qt.io/qt-6/qprocess.html. Sync wait cap 30 seconds. One async in flight. Launch Agent: `startDetached("konsole", ["-e", "gesso", "agent"])` after `gesso-app-present konsole`. Still argv, no shell.

**File ownership:** Modify `setup/GessoCli.hpp`, `setup/GessoCli.cpp`, `setup/qml/DefaultsPage.qml`, `setup/qml/InstallPage.qml`, `setup/qml/AgentsPage.qml`, `test/cli.d/setup-test.sh`. Tick Task 3 in this plan.

**Serialization required:** Yes

**Dependency reason:** Present calls from Task 1 stay; this task changes how QML waits.

**What to build:** Setup stays usable during pkg/default, and Launch Agent does not block the GUI on Konsole.

**Approach:** Keep sync `run`/`runBinary` for catalog-get and other short reads, with `waitForFinished(30000)`. Async methods start QProcess on the heap, emit `finished`. QML disables Apply / Set default / Launch while busy and reconnects on `finished`. Short list/load calls may stay sync. Tests grep: `waitForFinished(-1)` absent from `setup/`; Launch Agent calls `startDetached`; default/pkg call sites use `runAsync`. Do not add a C++ test harness. Do not run cmake.

**Acceptance criteria:**
- [x] `setup/` contains no `waitForFinished(-1)`
- [x] AgentsPage Launch Agent uses `startDetached` and `gesso-app-present konsole`
- [x] Defaults and Install apply/install paths use `runAsync`
- [x] Setup tests still pass (no hardcoded catalog ids)
- [x] Worker-scope verification passes and the change is committed (`serial-worker-commit`)

### Task 4: Theme validate, atomic publish, VS Code merge

**Files:**
- Modify: `bin/gesso-theme-set:26-116`, `bin/gesso-theme-set-templates:65-86`, `bin/gesso-theme-restore:12-34`, `test/cli.d/theme-test.sh:20-97`, `docs/theming.md:48-73`

**Interfaces:**
- Consumes: existing overlay + templates
- Produces: rejected bad names; no leftover `{{`; failed Plasma apply leaves `current/theme` unchanged; `settings.json` `workbench.colorCustomizations` merge + restore backup at `~/.local/state/gesso/vscode-colorCustomizations.json`

**Contract inputs:** Required keys: `mode` (`dark` or `light`), `accent`, `background`, `foreground`. Canonical path of the theme dir must stay under `$GESSO_PATH/themes` or `$HOME/.config/gesso/themes`. Headless still validates and swaps files, skips Plasma.

**File ownership:** Modify `bin/gesso-theme-set`, `bin/gesso-theme-set-templates`, `bin/gesso-theme-restore`, `test/cli.d/theme-test.sh`, `docs/theming.md`. Tick Task 4 in this plan.

**Serialization required:** Yes

**Dependency reason:** Independent of agents, but docs and restore must land together.

**What to build:** Theme set that does not publish a half-applied theme, plus a VS Code retint that actually affects the editor.

**Approach:** Reject names that do not match `^[a-z0-9]+(-[a-z0-9]+)*$` with `Unknown theme:`. Resolve `realpath` and check prefix. Lock under `${XDG_RUNTIME_DIR:-$HOME/.local/state/gesso}/gesso-theme-set.lock`. After templates, if any rendered file contains `{{`, delete next-theme and exit 1. Non-headless: copy `Gesso.colors` aside, write new file, `plasma-apply-colorscheme Gesso`; on failure restore the aside file, `rm -rf` next-theme, exit 1 without moving current. Then copy Konsole/Kitty/VS Code live files and `mv` next to current. VS Code: keep `gesso-theme.json`; Python-merge `colors` into `settings.json` `workbench.colorCustomizations`; backup previous value (or a JSON null meaning absent). Invalid `settings.json` is a hard error. Restore reapplies the backup key then Breeze. Tests: `../foo`, `Tokyo Night`, leftover placeholder, failing plasma stub leaves previous `theme.name`; `settings.json` gains colorCustomizations and keeps unrelated keys; restore puts the old key back. Replace the assertion `does not write settings.json`.

**Acceptance criteria:**
- [x] `gesso theme set ../foo` and `gesso theme set 'Tokyo Night'` exit 1 and do not create `current/theme`
- [x] A leftover `{{` in a rendered file fails and does not swap current
- [x] A failing `plasma-apply-colorscheme` after a successful tokyo-night leaves `theme.name` as `tokyo-night`
- [x] With `Code/User` present, `settings.json` contains merged `workbench.colorCustomizations` and a pre-existing unrelated key
- [x] `gesso theme restore` restores that backup key
- [x] Worker-scope verification passes and the change is committed (`serial-worker-commit`)

### Task 5: Router contract and claim edits

**Files:**
- Modify: `bin/gesso:80-86` (and usage if group listing needs it), `test/cli.d/cli-test.sh`, `docs/cli.md:19-23`, `plans/2026-08-26-product.md` (preview, retints, Install services, theme install / pkg drop), `AGENTS.md` only if a sentence still claims unfinished v1 work as done without the caveats in the spec

**Interfaces:**
- Consumes: existing `gesso-*` filenames and `# gesso:hidden=true`
- Produces: `--` ends help scan; `gesso theme` lists non-hidden theme commands and exits 0

**Contract inputs:** `docs/cli.md` already requires both behaviors. Hidden commands (`gesso-theme-set-templates`, `gesso-catalog-get`, `gesso-app-present`, `gesso-cmd-present`, `gesso-agent-get`) stay omitted from listings.

**File ownership:** Modify `bin/gesso`, `test/cli.d/cli-test.sh`, `docs/cli.md`, `plans/2026-08-26-product.md`, `AGENTS.md`. Tick Task 5 in this plan.

**Serialization required:** Yes

**Dependency reason:** After behavior exists so the product brief does not lie.

**What to build:** Router matches its docs. Product brief stops claiming live preview, Ghostty/Foot/browser chrome, curated services, `theme install`, and `pkg drop` as v1.

**Approach:** Help scan: leftover `--` stops the `-h`/`--help` scan; a `--help` after `--` is passed through to the command. Bare group: if no binary matches and one word is a group with children, print that group's non-hidden commands (`theme list`, `theme set`, …) and exit 0. Tests: `gesso theme` includes list/set/current/restore and excludes `set-templates`; `gesso theme set -- --help` runs `gesso-theme-set` with those args instead of the router help path. Keep this small. Product.md: Theme page is a list plus Apply; applied retints are Plasma, Konsole, GTK prefer-dark/light, Kitty if present, VS Code colorCustomizations if User exists; Install page is catalog browsers/terminals/editors; `theme install` and `pkg drop` are later. Do not implement those later items.

**Acceptance criteria:**
- [ ] `gesso theme` exits 0 and lists list/set/current/restore, not hidden templates
- [ ] `--` stops the router help scan
- [ ] Product brief no longer claims live preview, Ghostty/Foot/browser chrome, extra services, `theme install`, or `pkg drop` as v1
- [ ] Worker-scope verification passes and the change is committed (`serial-worker-commit`)

### Task 6: Packaging checklist

**Files:**
- Modify: `packaging/README.md:19-24`, `docs/packaging.md:36-43`, `test/cli.d/packaging-test.sh:48-56`, `README.md:7-13` only if a tag sentence is missing

**Interfaces:**
- Consumes: Task 2 Recommends line
- Produces: human checklist that starts with merge, then tag `v0.1.0`, then COPR; tests still grep spec text only

**Contract inputs:** Do not create a git tag. `Source0` stays `%{url}/archive/v%{version}/%{name}-%{version}.tar.gz`. `<owner>` stays a placeholder.

**File ownership:** Modify `packaging/README.md`, `docs/packaging.md`, `test/cli.d/packaging-test.sh` (Source0 / checklist assertions), `README.md` only if the COPR steps need the tag line. Tick Task 6 in this plan.

**Serialization required:** Yes

**Dependency reason:** After Recommends exists.

**What to build:** A packaging README that a human can follow after merge, and tests that the spec still points at a version tag without requiring rpmbuild.

**Approach:** README create-COPR list becomes: merge this branch; tag `v0.1.0` on that commit; create COPR for Fedora 44; build; inspect three RPMs; replace `<owner>`. Tests: spec contains `v%{version}` in Source0; still no `/etc`; still three packages. Do not run rpmbuild.

**Acceptance criteria:**
- [ ] `packaging/README.md` lists tag `v0.1.0` before COPR create
- [ ] packaging tests assert Source0 uses `v%{version}`
- [ ] No tag is created in this branch
- [ ] Worker-scope verification passes and the change is committed (`serial-worker-commit`)
