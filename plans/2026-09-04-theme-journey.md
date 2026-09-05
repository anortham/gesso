# Theme Journey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use razorback:subagent-driven-development when subagent delegation is available. Fall back to razorback:executing-plans for single-task, tightly-sequential, or no-delegation runs. Follow razorback:test-driven-development on every task: write the failing test first, run it, implement, run it again.

**Goal:** Implement the complete mouse-first theme journey on Fedora KDE: visual theme preview cards in Setup, wallpaper controls, safe terminal enablement, robust undo and baseline restore, backed by an asynchronous Setup bridge.

**Architecture:** The CLI remains the API. Theme metadata, wallpaper handling, terminal enablement, and undo/restore state are implemented in `bin/gesso-theme-*` and exposed via CLI arguments and JSON flags. The Setup app (`setup/GessoCli` and `setup/qml/ThemePage.qml`) consumes these CLI interfaces asynchronously without blocking the UI thread, rendering rich visual preview cards, operation progress, and recovery actions.

**Tech Stack:** Bash 5, Python 3 tomllib/json, Qt 6 / Kirigami 6, C++20, TAP test suite (`test/cli.d/`).

**Architecture Quality:** Spec: `plans/2026-09-04-theme-journey-design.md`. The CLI is the single source of truth for theming, wallpaper state, and terminal activation. `setup/GessoCli` owns process execution lifecycle without embedding theme policy. Risk: Medium (handling diverse terminal configuration syntaxes and reversible edits safely).

## Global Constraints

- Spec: `plans/2026-09-04-theme-journey-design.md`. Follow it. Report a plan mismatch instead of redesigning.
- CLI is the API. Setup only executes `gesso-*`. No palette colors, wallpaper paths, or config merge rules hardcoded in QML.
- Never write to `/etc`. Keep all runtime and recovery state in `$HOME/.local/state/gesso/` and configuration in `$HOME/.config/`.
- Preserve existing plain-text output and exit codes for all existing CLI commands when new flags (`--json`, etc.) are not passed.
- Bash 5: `[[ ]]` for string/file tests, `(( ))` for numeric tests. Quote paths with spaces. Indentation: 2 spaces, no tabs. Shebangs: `#!/bin/bash`.
- Add `# gesso:summary=` and `# gesso:args=` metadata to every new `bin/gesso-*` binary within the first 80 lines.
- Unit tests use stubs (`test/lib.sh`). No real dnf, Flatpak, Plasma, or live desktop mutations in automated tests.
- Worktree: `/home/murphy/source/gesso/.worktrees/theme-journey` on branch `theme-journey`.

---

## Verification Strategy

**Project source of truth:** `docs/testing.md`, `AGENTS.md`, `plans/2026-09-04-theme-journey-design.md`.

**Worker red/green scope:** The specific test suite file covering the changed area:
- Theme engine & CLI: `test/cli.d/theme-test.sh`
- Setup bridge & QML: `test/cli.d/setup-test.sh`

**Worker ceiling:** The assigned test suite (`theme-test.sh` or `setup-test.sh`). Workers in parallel batches do not run `./test/all` because sibling edits are in flight.

**Worker gate invariant:** The assigned suite prints only `ok -` lines and exits with code 0.

**Lead affected-change scope:** `./test/all` after each coherent batch or task.

**Branch gate:** `./test/all` passes with 100% ok checks, and `cmake -S setup -B setup/build && cmake --build setup/build` compiles cleanly without errors.

**Security scope:** none declared

**Replay/metric evidence:** none

**Escalation triggers:** none

**Assigned verification failure:** Stop. Do not weaken test assertions.

**Verification ledger:** Record invariant, command, scope label, commit SHA, and result.

---

## Parallel Execution Contract

| Task | Parallel batch | File ownership | Serialization required | Dependency reason |
|---|---|---|---|---|
| Task 1: Theme Metadata & JSON Query | Batch A | Modify `bin/gesso-theme-list`, `test/cli.d/theme-test.sh` | No | None - safe parallel batch. |
| Task 2: Setup Async Bridge Contract | Batch A | Modify `setup/GessoCli.hpp`, `setup/GessoCli.cpp`, `test/cli.d/setup-test.sh` | No | None - safe parallel batch. |
| Task 3: Terminal Enablement & Wallpaper Modes | Batch B | Modify `bin/gesso-theme-set`, `test/cli.d/theme-test.sh` | Yes | Depends on Task 1 theme structure. |
| Task 4: Theme Undo & Baseline Restore | Batch B | Create `bin/gesso-theme-undo`, modify `bin/gesso-theme-restore`, `test/cli.d/theme-test.sh` | Yes | Depends on undo state recorded by Task 3. |
| Task 5: Theme Gallery & Recovery UI | Batch C | Modify `setup/qml/ThemePage.qml`, `setup/qml/Main.qml`, `test/cli.d/setup-test.sh` | Yes | Consumes async bridge from Task 2 and theme CLI from Tasks 1, 3, 4. |
| Task 6: Documentation & Final Sweep | None - serial | Modify `docs/theming.md`, `docs/cli.md`, `AGENTS.md` | Yes | Documents the delivered interfaces and behavior. |

---

### Task 1: Theme Metadata & JSON Query

**Files:**
- Modify: `bin/gesso-theme-list`, `test/cli.d/theme-test.sh`

**What to build:**
Add `--json` flag to `gesso-theme-list` that inspects each theme's `colors.toml` (both built-in and user overlays) and outputs a JSON array with palette details:
- `id`: theme folder name
- `name`: human-readable name (derived or from folder name)
- `mode`: `"dark"` or `"light"`
- `accent`, `background`, `foreground`, `selection`, `muted`: color hex codes
- `palette`: list of primary terminal colors (`red`, `green`, `yellow`, `blue`, `magenta`, `cyan`)
- `has_wallpaper`: boolean (true if `backgrounds/` has images)
Preserve existing newline-delimited output when `--json` is not passed.

**Approach:**
Use Python with `tomllib` and `json` embedded in `bin/gesso-theme-list` when `--json` is passed, following the pattern in `bin/gesso-catalog-get`.

**Acceptance criteria:**
- [x] `gesso theme list --json` outputs valid JSON containing all themes with color swatches and wallpaper flags
- [x] `gesso theme list` without `--json` retains exact existing behavior
- [x] Tests in `test/cli.d/theme-test.sh` verify `--json` schema and data integrity

---

### Task 2: Setup Async Bridge Contract

**Files:**
- Modify: `setup/GessoCli.hpp`, `setup/GessoCli.cpp`, `test/cli.d/setup-test.sh`

**What to build:**
Upgrade `GessoCli` to prevent blocking the Qt event loop and eliminate single-process lockouts:
- Provide non-blocking asynchronous execution for both mutations and read queries.
- Support request-based async execution: `runAsync(args, callback)` or signal-based execution that associates finished results with the request.
- Manage concurrent reads gracefully without corrupting or dropping results if a background mutation is running.
- Ensure `busy` property accurately reflects active mutation tasks.

**Approach:**
Refactor `GessoCli` to manage active `QProcess` instances dynamically rather than relying on a single blocking wait or single `m_process` pointer. Expose QML-callable methods that do not freeze the UI.

**Acceptance criteria:**
- [x] `GessoCli` does not call blocking `waitForFinished` on the main UI thread during standard queries
- [x] Multiple queries or tab switches do not drop results or crash
- [x] `setup/` builds cleanly with CMake
- [x] Tests in `test/cli.d/setup-test.sh` verify async bridge behavior

---

### Task 3: Terminal Enablement & Wallpaper Modes

**Files:**
- Modify: `bin/gesso-theme-set`, `test/cli.d/theme-test.sh`

**What to build:**
Extend `gesso-theme-set`:
- Wallpaper control: `--wallpaper keep|theme|<image-path>` (default: `keep`).
  - `keep`: does not change wallpaper.
  - `theme`: applies first wallpaper from `$current/backgrounds/` (if present).
  - `<image-path>`: copies image to `$HOME/.local/state/gesso/wallpapers/` and applies it.
- Terminal enablement (reversible and non-destructive):
  - Kitty: writes `~/.config/kitty/gesso-theme.conf`, ensures `include gesso-theme.conf` is in `~/.config/kitty/kitty.conf` (creating file if needed).
  - Ghostty: writes `~/.config/ghostty/themes/Gesso`, ensures `theme = Gesso` is configured in `~/.config/ghostty/config`.
  - Foot: writes `~/.config/foot/gesso-theme.ini`, ensures `include = ~/.config/foot/gesso-theme.ini` is in `~/.config/foot/foot.ini`.
- Record undo state into `$HOME/.local/state/gesso/undo/`:
  - Record previous theme name, previous wallpaper (if detectable), previous terminal configuration states before modification.

**Approach:**
Follow existing atomic replacement and staged update patterns. Ensure sed/grep modifications to user configs are idempotent and easily rolled back.

**Acceptance criteria:**
- [x] `gesso theme set <name> --wallpaper keep` preserves current wallpaper
- [x] `gesso theme set <name> --wallpaper theme` applies bundled wallpaper
- [x] Terminal config files for Kitty, Ghostty, and Foot receive appropriate includes without duplicating lines
- [x] Prior state is saved in `$HOME/.local/state/gesso/undo/`
- [x] Tests in `test/cli.d/theme-test.sh` pass

---

### Task 4: Theme Undo & Baseline Restore

**Files:**
- Create: `bin/gesso-theme-undo`
- Modify: `bin/gesso-theme-restore`, `bin/gesso`, `test/cli.d/theme-test.sh`

**What to build:**
- Create `bin/gesso-theme-undo`:
  - Reads `$HOME/.local/state/gesso/undo/`.
  - Restores previous theme, wallpaper, and terminal configuration states.
  - Removes undo state upon successful rollback.
  - Exits non-zero with user-friendly error if no undo state is present.
- Upgrade `bin/gesso-theme-restore`:
  - Restores baseline Plasma color scheme (Breeze / BreezeDark).
  - Restores baseline Konsole profile and GTK color scheme.
  - Reverts VS Code colorCustomizations.
  - Reverts terminal includes from `kitty.conf`, `ghostty/config`, and `foot.ini`.
  - Clears `current/theme.name` and undo state.

**Approach:**
Add `gesso-theme-undo` with `# gesso:summary=Undo the last applied Gesso theme`. Ensure `gesso theme restore` handles clean removal of includes without corrupting surrounding config options.

**Acceptance criteria:**
- [x] `gesso theme undo` reverts desktop, wallpaper, and terminal configs to the immediate prior state
- [x] `gesso theme undo` without prior state exits with error message
- [x] `gesso theme restore` cleans up all Gesso modifications and resets to baseline Breeze
- [x] `gesso theme` lists `undo` and `restore`
- [x] Tests in `test/cli.d/theme-test.sh` pass

---

### Task 5: Theme Gallery & Recovery UI

**Files:**
- Modify: `setup/qml/ThemePage.qml`, `setup/qml/Main.qml`, `test/cli.d/setup-test.sh`

**What to build:**
Revamp `ThemePage.qml` into a visual theme gallery:
- Grid/flow of theme preview cards with color swatches (background, foreground, accent, palette dots).
- Theme selection with clear highlight.
- Wallpaper selector options: "Keep Current Wallpaper", "Use Theme Wallpaper" (enabled when theme has wallpaper), "Custom Image...".
- Clear actions: "Apply Theme", "Undo", "Restore Defaults".
- Operation feedback: show busy indicator during apply/undo, clear success message, or error message with expandable diagnostic details.

**Approach:**
Query `gesso theme list --json` asynchronously on page load. Use Kirigami Card / ItemDelegate components with custom color rectangles for preview swatches. Wire Apply/Undo/Restore buttons to async CLI calls.

**Acceptance criteria:**
- [ ] Theme preview cards display colors and metadata visually
- [ ] Wallpaper choice is selectable and passed to `gesso theme set`
- [ ] "Undo" button triggers `gesso theme undo` and refreshes current theme
- [ ] "Restore Defaults" button triggers `gesso theme restore`
- [ ] Operation status and error messages are rendered clearly
- [ ] `test/cli.d/setup-test.sh` passes and validates ThemePage wiring

---

### Task 6: Documentation & Final Sweep

**Files:**
- Modify: `docs/theming.md`, `docs/cli.md`, `AGENTS.md`

**What to build:**
- Update `docs/theming.md` with:
  - `--json` metadata format for `theme list`
  - Wallpaper modes (`keep`, `theme`, `<path>`)
  - Terminal activation details for Kitty, Ghostty, Foot
  - Undo vs. Restore semantics
- Update `docs/cli.md` with `gesso theme undo` and updated flag documentation.
- Update `AGENTS.md` if any command groups or descriptions changed.
- Run full branch verification: `./test/all` and CMake build of `setup`.

**Acceptance criteria:**
- [ ] Documentation accurately reflects all new CLI flags, commands, and Setup UI behavior
- [ ] `./test/all` exits 0 with all checks passing
- [ ] `setup` compiles cleanly with CMake
