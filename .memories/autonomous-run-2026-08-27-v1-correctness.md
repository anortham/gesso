# Autonomous Execution Report - v1 correctness

**Status:** Complete
**Plan:** plans/2026-08-27-v1-correctness.md
**Branch:** v1-correctness
**PR:** pending — filled in after PR creation
**Duration:** this session
**Phases:** 1/1 complete
**Tasks:** 6/6 complete

Worktree: `/home/murphy/source/gesso/.worktrees/v1-correctness`
HEAD: `92e3eaa`
Base: `main` at `fac0009`

## What shipped
- `gesso-app-present` treats host commands and Flatpaks as installed. Chrome sets `com.google.Chrome.desktop`. Helix is `hx`.
- Agents install through `mise which` / `mise use -g` and launch with `mise exec --`. Codex skip-prompt is `--ask-for-approval never`. `gesso-plasma` Recommends `gesso-agents`.
- Setup CLI calls are async. Launch Agent detaches Konsole. No `waitForFinished(-1)`.
- Theme set validates names, required keys, and leftover `{{`, then publishes. Failed Plasma apply leaves `current/theme` unchanged.
- VS Code merge writes `workbench.colorCustomizations`. Backup is kept across applies and restored once.
- Router: `gesso theme` lists children. Leftover `--` ends the help scan. Product brief matches v1.
- Packaging README: merge, tag `v0.1.0`, then COPR. No tag created on this branch.

## Judgment calls (non-blocking decisions made)
- `bin/gesso-default-browser` GET matches catalog `desktop_id` or `<flatpak>.desktop` instead of only `--desktop`, so a stored Flatpak XDG id still maps to `chrome`.
- `test/lib.sh` dnf stub maps package `helix` to host binary `hx`.
- No missing-mise e2e: the dnf stub would overwrite the mise stub. Production still installs mise when it is missing.
- `# gesso:requires-sudo=true` on `gesso-default-agent` because it can elevate `dnf install -y mise`.
- Theme canonical paths use `pwd -P`, not `realpath -m` (not on the test PATH).
- JSONC rewrite drops comments. Unrelated keys still merge. Documented in `docs/theming.md`.
- VS Code backup is written only when the backup file is missing, and restore deletes it.

## External review (codex, adversarial)

- **Findings:** 3
- **Verified real, fixed:** 3 (commits: `92e3eaa`)
  - Repeated theme applies overwrote the VS Code restore point — backup now written once; restore consumes it.
  - Failed apply left live Konsole/Kitty on the rejected theme — VS Code settings are staged before those copies.
  - Strict `json.loads` rejected JSONC settings — stdlib comment/trailing-comma strip, then parse.
- **Dismissed:** 0
- **Flagged for your review:** 0

Codex token counts: not reported by codex-cli.

## Tests
- Branch-gate `./test/all` on `92e3eaa`: `PASS test/cli`, 96 `ok -` lines, exit 0.

## Blockers hit
- None for the PR. COPR publish, tag `v0.1.0`, and `<owner>` stay human steps after merge.

## Files changed
```
 bin/gesso                                 |  29 ++++
 bin/gesso-agent                           |  12 +-
 bin/gesso-app-present                     |  42 +++++
 bin/gesso-default-agent                   |  32 +++-
 bin/gesso-default-browser                 |  10 +-
 bin/gesso-default-editor                  |   3 +-
 bin/gesso-default-terminal                |  11 +-
 bin/gesso-pkg-add                         |   7 +-
 bin/gesso-theme-restore                   |  42 +++++
 bin/gesso-theme-set                       | 276 +++++++++++++++++++++++++-----
 bin/gesso-theme-set-templates             |   5 +
 data/agents.toml                          |   2 +-
 data/apps.toml                            |   4 +-
 docs/catalog.md                           |  13 +-
 docs/cli.md                               |   8 +-
 docs/packaging.md                         |   8 +-
 docs/testing.md                           |   2 +-
 docs/theming.md                           |  28 +--
 packaging/README.md                       |  11 +-
 packaging/gesso.spec                      |   1 +
 plans/2026-08-26-product.md               |  18 +-
 plans/2026-08-27-v1-correctness-design.md | 277 ++++++++++++++++++++++++++++++
 plans/2026-08-27-v1-correctness.md        | 259 ++++++++++++++++++++++++++++
 setup/GessoCli.cpp                        |  90 ++++++++--
 setup/GessoCli.hpp                        |  15 ++
 setup/qml/AgentsPage.qml                  |  36 ++--
 setup/qml/DefaultsPage.qml                |  32 ++--
 setup/qml/InstallPage.qml                 |  32 ++--
 test/cli.d/agent-test.sh                  |  32 ++++
 test/cli.d/cli-test.sh                    |  13 ++
 test/cli.d/default-test.sh                |  75 ++++++++
 test/cli.d/packaging-test.sh              |   4 +-
 test/cli.d/setup-test.sh                  |  13 ++
 test/cli.d/theme-test.sh                  |  85 ++++++++-
 test/lib.sh                               |  73 +++++++-
 35 files changed, 1444 insertions(+), 144 deletions(-)
```

## Next steps
- Review PR: pending — filled in after PR creation
- Human: merge, then tag `v0.1.0`, then create COPR for Fedora 44. Do not invent `<owner>`.
- Live KDE check of Setup is still untested here (no Kirigami devel / no cmake in `./test/all`).
