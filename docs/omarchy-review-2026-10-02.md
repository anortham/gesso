# Omarchy comparison and Gesso polish

Reviewed on 2026-10-02. Omarchy checkout: `quattro`, `821ae589` (2026-10-02). Gesso baseline: `main`, `f25cf38`, after the September theme journey. The comparison concentrates on changes since 2026-09-04, with older behaviors used as references where relevant. Omarchy was inspected locally without fetching, modifying, or vendoring files.

## What changed upstream

| Upstream change | What Gesso learns |
|---|---|
| Cursor CLI and Muse added on September 6; Antigravity, Oh My Pi, and Ori are also in the current agent selector | Keep the agent catalog current, and handle each CLI’s prompt syntax explicitly. |
| Cursor vendor installations preserved instead of being shadowed by mise | Detect native agent executables before installing or launching through mise. A mise shim is insufficient proof of a native install. |
| Per-theme wallpaper memory and cycling on September 23 | Keep wallpaper choice independent of palette application. Gesso already defaults to keeping the current wallpaper and stores copied custom images. |
| Theme picker caching and template rendering improvements on September 27 | Keep expensive work out of interactive actions; measure Gesso before adopting renderer changes. Quickshell caches do not transfer to Kirigami. |
| Hunk live retint on September 28 | Gesso’s existing theme-set hooks provide the extension point until an application becomes a supported built-in target. |
| Agent account switching and Grok usage tracking on October 1–2 | A useful future direction, requiring provider-specific state and UI beyond the current default-agent picker. |

References are Omarchy’s `bin/omarchy-agent`, `bin/omarchy-default-agent`, `bin/omarchy-theme-set`, and commits `a62e34ea`, `0385610c`, `24f12431`, `7e8d35ef`, `4ba4a532`, `c05d9019`, and `821ae589` in the local checkout.

## Applied to Gesso

- Added Cursor CLI, Antigravity, Oh My Pi, and Ori through the existing agent TOML catalog. The [current mise registry](https://mise.jdx.dev/registry) supplies their install identifiers; old mise releases may lack newly added entries.
- Corrected OpenCode prompt forwarding to its [documented `--prompt` option](https://opencode.ai/v2/docs/cli). Cursor’s explicit `agent` subcommand protects prompts that resemble management commands; Ori’s `--interactive` keeps prompted sessions in its terminal UI.
- Preserved native agent installs, including executables under `~/.local/bin`, instead of installing a second copy or forcing them through an unrelated mise installation.
- Added a custom wallpaper Browse button using [Qt’s file dialog](https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html) and native file-URL conversion.
- Validated every VS Code settings target before applying Plasma colors or changing terminal files. New baseline backups stay staged until publication, so an invalid later target cannot leave an earlier backup behind.
- Saved editor state only after a successful MIME-default update. Rejected excess command arguments before installation or default changes.
- Kept Setup controls busy while refreshed state loads and supplied visible error feedback when failed commands return empty stderr.

Cursor, Antigravity, and Oh My Pi launch flags were checked against the installed binaries’ `--help`. Ori’s official `cli-0.15.5-74c4cf2` Linux release was downloaded into a temporary path, checked against its published SHA256SUMS, and inspected with `code --help`; it confirms `--interactive` and `--prompt`. These checks do not launch paid agent sessions or establish login credentials. Agent installation and argv behavior are regression-tested with stubs; installing every agent on a real Fedora desktop remains a manual check.

## Scope retained

Muse requires a custom launcher backend; Hermes uses a desktop-owned runtime and installer; OpenClaw needs a gateway lifecycle. Those integrations need their own product decision rather than an unverified catalog row. Account panels, remote theme sync, video wallpaper, and wallpaper cycling remain unscheduled. Gesso ships no wallpaper collection, so cycling adds little today.

Hyprland, Quickshell, Pacman/AUR, snapshot and boot management, and `/etc` ownership remain excluded. Gesso stays a Fedora KDE command pack with one Setup window. COPR publication remains a separate release task.
