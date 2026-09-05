# Theme Journey Design: Setup Communication and Visual Theming

Date: 2026-09-04
Status: Proposed design for review
Roadmap reference: `plans/2026-09-04-next-level-product.md` (Milestones 2 & 3)

## Goal

Deliver an end-to-end, mouse-first theme journey on Fedora KDE: browse theme preview cards visually in Setup, configure wallpaper preferences, apply themes cleanly across desktop and terminal apps with honest per-target status, and revert changes via either immediate Undo or pre-Gesso Baseline Restore without opening a terminal.

## Findings & Current Architecture Shortcomings

1. **Synchronous Bridge Reads**: `GessoCli::run` and `GessoCli::runBinary` invoke `waitForStarted(30000)` and `waitForFinished(30000)`, freezing the Qt event loop during page loads or command execution.
2. **Single Process Slot**: `GessoCli::runBinaryAsync` uses a single `m_process` pointer. Starting an asynchronous mutation or query while another is in flight fails silently (`if (m_process) return;`).
3. **Missing Theme Previews**: `gesso theme list` outputs bare theme names. `ThemePage.qml` shows a simple text `ListView` with no color swatches, palette info, or previews.
4. **Terminal Themes Not Activated**: `bin/gesso-theme-set` writes config fragments (`~/.config/kitty/gesso-theme.conf`, `~/.config/ghostty/themes/Gesso`, `~/.config/foot/gesso-theme.ini`) but does not enable them in the apps' primary configuration files (`kitty.conf`, `ghostty/config`, `foot/foot.ini`).
5. **Lossy Restore & Missing Undo**: `gesso theme restore` resets to Breeze and deletes `theme.name`. It does not restore the previous wallpaper or previous Plasma color scheme, and there is no single-step "undo last apply".
6. **No Visual Progress or Diagnostics**: When `ThemePage.qml` applies a theme, it disables buttons but gives no granular indication of which targets succeeded, which failed, or what manual steps are required.

## Key Decisions

### 1. Setup Bridge Contract (`setup/GessoCli`)

- **Asynchronous Execution**:
  - Deprecate synchronous blocking reads on the UI thread.
  - Provide asynchronous execution with unique request IDs or dedicated worker instances: `runCommandAsync(requestId, args)` emitting `commandFinished(requestId, exitCode, stdout, stderr)`.
  - Maintain a global `busy` indicator for mutations, while allowing non-interfering background read queries.
- **Action Guarding**:
  - Disable conflicting UI actions while a mutation is running.
  - Decouple async result dispatch from specific page lifetimes so changing tabs does not lose error reporting or corrupt page state.
- **Structured Error & Diagnostics**:
  - Return standardized output containing `exitCode`, `stdout`, `stderr`.
  - Support structured JSON output from CLI queries.

### 2. Theme Metadata & Query (`bin/gesso-theme-list`)

- **Structured Output**:
  - `gesso theme list --json` outputs an array of JSON objects containing:
    - `id`: theme folder name (e.g. `tokyo-night`)
    - `name`: human-readable label
    - `mode`: `"dark"` or `"light"`
    - `accent`, `background`, `foreground`: hex color values
    - `palette`: sample color swatches (e.g., terminal color slots)
    - `has_wallpaper`: boolean indicating whether `backgrounds/` has images.
- Plain `gesso theme list` retains exact existing newline-delimited behavior.

### 3. Theme Application & Terminal Enablement (`bin/gesso-theme-set`)

- **Terminal Activation (Opt-in & Safe)**:
  - **Kitty**: If `~/.config/kitty/kitty.conf` exists, ensure `include gesso-theme.conf` is present (or offer opt-in activation); if `kitty.conf` does not exist, create it with the include.
  - **Ghostty**: If `~/.config/ghostty/config` exists, ensure `theme = Gesso` is present; record previous theme setting for rollback.
  - **Foot**: If `~/.config/foot/foot.ini` exists, ensure `include = ~/.config/foot/gesso-theme.ini` is present under `[main]`.
  - Any app config modification must be safe, parse cleanly, avoid duplicating includes, and be tracked in state for clean rollback.
- **Structured Apply Reporting**:
  - `gesso theme set --json <name>` outputs a JSON status report detailing per-target status:
    - Plasma color scheme (`applied`, `failed`, or `headless`)
    - Konsole (`applied`, `failed`)
    - VS Code / Flatpak Code (`applied`, `skipped`, `failed`)
    - Kitty / Ghostty / Foot (`applied`, `needs_restart`, `skipped`)
    - Wallpaper (`applied`, `kept`, `failed`)
    - GTK color preference (`applied`, `skipped`)
- **Wallpaper Modes**:
  - Option 1: `keep` (default) — retain user's current wallpaper.
  - Option 2: `theme` — apply bundled wallpaper from `$current/backgrounds/`.
  - Option 3: `custom <path>` — copy user image to `~/.local/state/gesso/wallpapers/` and apply.

### 4. Recovery: Undo vs. Baseline Restore

- **Theme Undo (`gesso theme undo`)**:
  - Records the immediate prior theme state before any apply into `~/.local/state/gesso/undo/`:
    - Previous theme name and mode
    - Previous wallpaper path/settings
    - Previous terminal config states
    - Previous VS Code customizations
  - Calling `gesso theme undo` restores that exact prior state and updates the current theme state.
- **Baseline Restore (`gesso theme restore`)**:
  - Reverts Gesso-managed settings back to the initial pre-Gesso state recorded on first run:
    - Plasma scheme (Breeze / BreezeDark / recorded baseline)
    - Original Konsole default profile
    - Original GTK color-scheme preference
    - Reverts terminal app config includes / settings
    - Restores VS Code original backup
    - Removes `~/.local/state/gesso/current/theme.name`.

### 5. Setup UI: Visual Theme Gallery & Operations (`setup/qml/ThemePage.qml`)

- **Visual Theme Cards**:
  - Display theme preview cards in a GridView/Flow layout.
  - Each card shows: theme name, light/dark indicator, color swatches (background, foreground, accent, secondary colors), and a mini desktop/terminal preview representation.
- **Wallpaper Chooser**:
  - Radio/selector controls: "Keep Current Wallpaper", "Use Theme Wallpaper" (when available), "Choose Image...".
- **Operation Feedback & Recovery Buttons**:
  - "Apply Theme" button with loading spinner when busy.
  - "Undo" button (active when undo state is available).
  - "Restore Defaults" button with confirmation prompt.
  - Expandable status/diagnostics banner showing per-target outcome (e.g. "Plasma applied", "Konsole updated", "Kitty (restart required)").

## Architecture Quality

- **Interface Seam**: The CLI is the API. `gesso-theme-*` owns all logic, config updates, and filesystem state. Setup QML only renders UI and executes CLI commands via `GessoCli`.
- **Modularity**: Terminal enablement logic lives in modular helper routines or a dedicated helper script (`bin/gesso-theme-terminals`), ensuring `bin/gesso-theme-set` remains clean and maintainable.
- **Complexity**: Keeps state in `~/.local/state/gesso/` without writing to `/etc` or overriding non-Gesso user configurations without permission.
- **Risk Assessment**: Medium. Terminal configuration formats differ (Kitty, Ghostty, Foot INI/custom syntax). Safe parsing and idempotent include insertion/removal are essential.

## Acceptance Criteria

1. `gesso theme list --json` returns valid JSON with palette swatches and wallpaper availability.
2. `gesso theme set` supports wallpaper modes (`--wallpaper keep|theme|<path>`) and records complete undo state.
3. Supported terminals (Kitty, Ghostty, Foot) have their Gesso themes activated cleanly and reversibly.
4. `gesso theme undo` reverts to the exact previous theme and wallpaper state.
5. `gesso theme restore` cleanly removes Gesso hooks/includes and restores baseline settings.
6. `GessoCli` supports asynchronous execution without freezing the UI or dropping concurrent read results.
7. `ThemePage.qml` displays visual preview cards, wallpaper controls, operation progress, per-target status, and working Undo / Restore buttons.
8. `./test/all` and newly added unit tests for CLI and Setup bridge pass with 100% success.
