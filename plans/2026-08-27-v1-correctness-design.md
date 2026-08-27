# v1 correctness design

Date: 2026-08-27

Status: approved spec. Implementation plan: `plans/2026-08-27-v1-correctness.md`.

This is the post-phase-5 fix round from the Codex whole-tree review of `fac0009`. It is not a new product phase. It makes the claimed v1 paths work, and it revises claims that this round will not implement.

## Purpose

A Fedora KDE 44 user who installs Gesso can:

- Install a Flatpak-only catalog app and have Setup and `gesso pkg add` treat it as present.
- Set that app as the default browser using the Flatpak desktop id.
- Install Helix from Fedora and launch `hx`.
- Pick and launch a coding agent from Setup without a pre-installed `mise` on PATH, using real skip-prompt flags.
- Keep the Setup window usable while a command runs, and keep using Setup after Launch Agent.
- Apply a theme without publishing partial state when Plasma apply fails.
- Apply VS Code colors by merging `workbench.colorCustomizations` into `settings.json` when that User dir exists.

## Constraints

- CLI remains the API. Setup only execs `gesso-*`.
- No `/etc`. No Hyprland. No Omarchy copy. No COPR owner invented.
- Catalogs stay in `data/apps.toml` and `data/agents.toml`. No app ids in QML.
- `./test/cli` stays green with stubs. No real `dnf`, `flatpak`, `mise`, Plasma, or `rpmbuild`.
- Do not tag, push, or publish COPR in this work. Tag `v0.1.0` is a human step after merge.
- Do not add a plugin host or a second catalog format.

## Success

- `gesso pkg add chrome` succeeds when the Flatpak stub records `com.google.Chrome` and no `google-chrome` host binary exists.
- `gesso default browser chrome` then calls `xdg-settings set default-web-browser com.google.Chrome.desktop`.
- Helix catalog `command` is `hx`. Desktop id is `Helix.desktop` (Fedora 44 `helix` RPM ships `/usr/bin/hx` and `application(Helix.desktop)`).
- `gesso default agent grok` installs `mise` via dnf when missing, runs `mise use -g`, then verifies with `mise which grok` before writing the default file.
- `gesso agent` launches through `mise exec --` when `mise` is present.
- Codex launch argv uses `--ask-for-approval never`, not `--approve-for-me`. Source: [Codex CLI reference](https://developers.openai.com/codex/cli/reference).
- Setup Launch Agent uses detached Konsole. `GessoCli` does not `waitForFinished(-1)`.
- `gesso theme set` with a bad name, missing palette key, leftover `{{`, or failed Plasma apply leaves `current/theme` unchanged.
- VS Code: if `~/.config/Code/User` exists, merge Gesso colors into `settings.json` `workbench.colorCustomizations`. `gesso theme restore` puts the previous `workbench.colorCustomizations` back from Gesso state.
- Product and theming docs match what the code does. Ghostty/Foot templates, browser chrome retint, live theme preview, `theme install`, and `pkg drop` stay out of this round and are marked later.
- `./test/all` stays green.

## Architecture Quality

**Affected modules:** catalog presence, `pkg add` / default commands, agent install/launch, `GessoCli` + Setup QML, theme set/restore, tests stubs, packaging Recommends, docs.

**Caller-facing interface:** still `gesso pkg add`, `gesso default …`, `gesso default agent`, `gesso agent`, `gesso theme set`, `gesso theme restore`, `gesso setup`. New hidden helper: `gesso-app-present`. New QML-visible methods on `GessoCli`: async run and detached start. No new user-facing group.

**Depth/locality check:** Presence logic lives in one helper. Callers stop checking raw `command` on PATH. Agent launch goes through `mise exec --` in `gesso-agent`. Theme validation stays in `gesso-theme-set` / `gesso-theme-set-templates`. Setup does not grow a second installer.

**Test surface:** `gesso-app-present`, `gesso pkg add chrome` without a host binary, default browser desktop id, helix `hx`, agent `mise which` / `mise exec`, theme name reject and failed-apply rollback, router `--` and bare `gesso theme`, spec Recommends text. Setup C++ is not compiled in `./test/cli`; prove detach and no infinite wait by source contract plus QML calling `startDetached` / `runAsync`.

**Seams/adapters:** host command vs Flatpak; `mise` vs raw PATH; sync CLI vs async GUI; staged `next-theme` vs live `$HOME` files.

**Rejected shortcuts:** Flatpak stub that plants a host binary. `gesso-plasma` hard-Requires `gesso-agents`. Infinite `waitForFinished`. Theme swap before Plasma apply. Writing VS Code `settings.json` with no restore. Leaving `--approve-for-me` in the catalog. Inventing extra catalog formats.

**Architecture risk:** medium. The trap is a second presence model in QML or a second agent launcher. Keep one helper and one launch path.

### Presence interface lanes

**Lane: hidden helper (chosen).** `gesso-app-present <id>` is the only presence API. Optional `--desktop` prints the desktop file for the backend that is actually installed. Test through that binary. Callers: `gesso-pkg-add`, `gesso-default-browser`, `gesso-default-terminal`, `gesso-default-editor`, Setup Defaults and Install pages.

**Lane: computed catalog-get fields.** Mixes TOML reads with live system state. Rejected. `gesso-catalog-get` stays a file reader.

**Lane: extra TOML fields per backend.** `flatpak_command`, `flatpak_desktop_id` on every row. Rejected as speculative. Derive Flatpak desktop as `<flatpak>.desktop`. Host `desktop_id` and `command` stay as today.

## 1. App install and presence

Add hidden `bin/gesso-app-present`:

```
gesso-app-present <id>           # exit 0 if host command or Flatpak is present
gesso-app-present --desktop <id> # print desktop file for the installed backend
```

Rules:

- Host present: `gesso-cmd-present` on catalog `command`.
- Else Flatpak present: catalog `flatpak` is non-empty and `flatpak info <flatpak>` exits 0.
- `--desktop`: if host present, print `desktop_id`. Else if Flatpak present, print `<flatpak>.desktop`. Else exit 1.
- Unknown id exits 1 with `Unknown app:`.

`gesso-pkg-add`:

- Skip install when `gesso-app-present <id>` is already 0.
- After dnf, succeed if app-present (do not require the host command if only Flatpak landed).
- After Flatpak, succeed if app-present, even when the host command is missing.
- Still fail if neither backend is present.

`gesso-default-browser` (and terminal, when it uses a desktop file):

- Install via `gesso pkg add` when not present.
- Set XDG using `gesso-app-present --desktop <id>`, not raw `desktop_id`.

`gesso-default-editor` still writes catalog `id` to state. Presence uses `gesso-app-present`. Launch command stays catalog `command` (`hx` for Helix).

Catalog edits in `data/apps.toml`:

- Helix: `command = "hx"`, `desktop_id = "Helix.desktop"`.
- No other command renames unless a Fedora 44 file list proves a mismatch.

Setup `DefaultsPage.qml` and `InstallPage.qml`: `present` comes from `gesso-app-present <id>`, not `gesso-cmd-present` on `command`.

### Test stub rewrite

`test/lib.sh`:

- `dnf` stub still creates a host binary named after each package argument (firefox, konsole, kate, helix → still need `hx` mapping). The dnf stub must create `hx` when the package name is `helix`.
- `flatpak` stub records the Flatpak id under `$HOME/.local/state/gesso-flatpak/` and does **not** create a host command. `flatpak info <id>` exits 0 only for recorded ids. `flatpak install` records the id.
- `mise` stub does **not** write `grok` into the stub PATH. `mise use -g` records the spec. `mise which <bin>` and `mise exec --` succeed only after that record. `gesso-cmd-present grok` stays 1 until a host binary exists by other means.

Update `docs/catalog.md` and `docs/testing.md` to match.

## 2. Agents

`gesso-plasma` **Recommends** `gesso-agents` so a default Fedora install of Setup also pulls `mise`. Do not hard-Require it. CLI-only `gesso` stays usable without `mise`.

`gesso default agent <id>`:

1. Resolve the row.
2. If `mise` is missing, elevate `dnf install -y mise` (same sudo/pkexec split as pkg-add).
3. If `mise which <launch_bin>` fails, run `mise use -g <mise spec>`.
4. Recheck `mise which <launch_bin>`. Fail if still missing. Do not write the default file on that failure.
5. Write `~/.config/gesso/defaults/agent` and notify.

`gesso agent`:

- If `mise` is on PATH, `exec mise exec -- "${argv[@]}"` (plus prompt args as today).
- Else `exec "${argv[@]}"` as today, so a host-installed binary still works.
- Dry-run prints the final argv, including `mise exec --` when used.

Catalog `data/agents.toml` Codex row:

```
launch = ["codex", "--ask-for-approval", "never"]
```

Do not use `--yolo` for the default skip-prompt. That flag also disables the sandbox. Other rows stay unless current official docs prove they are invalid. Grok and Claude flags already match their `--permission-mode` shape; leave them.

Grounding URLs for the implementer:

- Codex: https://developers.openai.com/codex/cli/reference
- Fedora Helix files: https://packages.fedoraproject.org/pkgs/helix/helix/fedora-44.html

## 3. Setup process execution

`GessoCli` today is sync and calls `waitForFinished(-1)`. That freezes the GUI for `dnf` and holds it for the whole Konsole session.

New C++ contract (`setup/GessoCli.hpp`):

```
Q_INVOKABLE QVariantMap run(const QStringList &args);
Q_INVOKABLE QVariantMap runBinary(const QString &program, const QStringList &args);
Q_INVOKABLE void runAsync(const QStringList &args);
Q_INVOKABLE void runBinaryAsync(const QString &program, const QStringList &args);
Q_INVOKABLE bool startDetached(const QString &program, const QStringList &args);
signals:
  void finished(const QVariantMap &result);
```

Rules:

- Sync `run` / `runBinary` keep a bounded wait (30 seconds). They stay for catalog-get and other short reads. Never pass `-1`.
- `runAsync` / `runBinaryAsync` use `QProcess` finished/errorOccurred and emit `finished`. Used for `pkg add` and `default …` from QML.
- One async call in flight per `GessoCli`. QML disables Apply, Set default, and Launch until `finished`. Do not queue overlapping runs.
- `startDetached` uses `QProcess::startDetached`. Launch Agent calls `startDetached("konsole", ["-e", "gesso", "agent"])` after `gesso-app-present konsole`.
- QML shows a busy/error state while an async call is in flight.
- Still argv-based. No shell.

Qt docs: https://doc.qt.io/qt-6/qprocess.html (`waitForFinished`, `startDetached`).

`./test/cli` still does not compile the GUI. Tests: QML contains `runAsync` or `startDetached` at the Launch Agent and default/pkg call sites, and `waitForFinished(-1)` is absent from `setup/`.

## 4. Theme set: validate, then publish

Theme names: `^[a-z0-9]+(-[a-z0-9]+)*$`. Reject `.`, `..`, slashes, and anything else before any path join.

After overlay, the theme directory must resolve inside `$GESSO_PATH/themes` or `$HOME/.config/gesso/themes` (canonical path containment).

Lock file: `${XDG_RUNTIME_DIR:-$HOME/.local/state/gesso}/gesso-theme-set.lock`. Do not fall back to `/tmp`.

Required `colors.toml` keys before render: `mode` (`dark` or `light`), `accent`, `background`, `foreground`. Missing or empty fails. Do not swap.

After `gesso-theme-set-templates`, fail if any rendered file still contains `{{`. Do not swap.

Publish order:

1. Render into `next-theme`. Validate.
2. If not headless: copy `Gesso.colors` into `~/.local/share/color-schemes/Gesso.colors` (keep the previous file aside), run `plasma-apply-colorscheme Gesso`. On failure, restore the previous colors file if any, delete `next-theme`, exit 1. `current/theme` is untouched.
3. Copy Konsole, Kitty, and VS Code live files.
4. `mv next-theme` onto `current/theme` and write `theme.name`.
5. GTK `color-scheme`, Kitty live retint, user hooks — same as today. Missing binaries stay non-errors.

Headless (`GESSO_THEME_HEADLESS=1`) skips step 2 session calls but still validates and swaps files.

### VS Code

Today `vscode.json` is copied to `Code/User/gesso-theme.json`. VS Code does not load that file.

When `~/.config/Code/User` exists:

- Keep writing `gesso-theme.json` (artifact).
- Merge the `colors` object from that file into `settings.json` key `workbench.colorCustomizations`.
- Save the previous `workbench.colorCustomizations` value (or a marker that it was absent) to `~/.local/state/gesso/vscode-colorCustomizations.json`.
- Merge with Python `json`. Do not rewrite unrelated keys. Invalid existing `settings.json` is a hard error, not a clobber.
- `gesso theme restore` restores that backup key when the backup file exists, then applies Breeze as today.

Update `docs/theming.md`: Gesso may write `workbench.colorCustomizations` and must restore it. It still does not replace the rest of `settings.json` or `kitty.conf`.

Do not ship a VS Code extension in this round.

## 5. Docs vs code, and dropped v1 claims

Implement documented router behavior that is missing:

- `--` in leftover args ends the `--help` / `-h` scan. Later `--help` is passed through.
- Bare `gesso theme` lists that group's commands (list, set, current, restore) and exits 0. Same for other groups that have children (`default`, `pkg`) if the scan is cheap; at least `theme` because `docs/cli.md` names it.

Revise claims, do not implement in this round:

- Live theme preview in Setup. Theme page stays a name list plus Apply.
- Ghostty/Foot template apply and browser chrome retint. Kitty live update and GTK prefer-dark/light stay.
- Curated Install “services” list. Install page stays the union of catalog browsers, terminals, and editors. `kind = "extra"` remains allowed in the catalog schema and unused.
- `gesso theme install` and `gesso pkg drop`.
- Look-and-Feel art, SDDM, GNOME, bootc, remix ISO.

Edit `plans/2026-08-26-product.md`, `docs/theming.md`, `docs/cli.md`, `docs/catalog.md`, `AGENTS.md` only where they would otherwise lie.

## 6. Packaging gate

Keep `Source0` as the tagged GitHub tarball `v%{version}`. Do not create the git tag in this branch.

`packaging/README.md` human checklist gains, in order:

1. Merge this branch.
2. Tag `v0.1.0` on that commit.
3. Create the COPR for Fedora 44.
4. Build and inspect the three RPMs.
5. Replace `<owner>` in README and docs.

`gesso-plasma` Recommends `gesso-agents`.

Packaging tests still must not run `rpmbuild` / `mock` / `copr-cli`. Add assertions: Recommends `gesso-agents`, Source0 contains `v%{version}`, no `/etc`. Optional: if `rpmbuild` exists, a lead-only note in packaging README, not `./test/all`.

## Out of scope

- COPR create/build/publish.
- Compiling Setup in `./test/all`.
- QML/C++ unit test harness.
- Ghostty, Foot, Chromium/Firefox chrome templates.
- Live Plasma preview.
- Aurora/Kinoite install path beyond “untested”.
- Tag, push, or release.

## Work order

Serial. Shared files (`test/lib.sh`, catalogs, docs) make parallel batches unsafe.

1. Presence helper, catalog Helix, stub rewrite, pkg-add, defaults, Setup present checks.
2. Agent mise verify/launch, Codex flag, plasma Recommends.
3. GessoCli async + detached Launch Agent + QML busy state.
4. Theme name/lock/validate/atomic publish + VS Code settings merge + restore.
5. Router `--` and bare group list; doc claim edits.
6. Packaging README checklist + spec Recommends tests.

## Acceptance

- [ ] Flatpak-only chrome installs and sets `com.google.Chrome.desktop` without a host `google-chrome`.
- [ ] Helix command is `hx`.
- [ ] Agent default does not write the file when `mise which` fails; launch uses `mise exec --` when mise exists.
- [ ] Codex argv is `--ask-for-approval never`.
- [ ] No `waitForFinished(-1)` in `setup/`. Launch Agent is detached.
- [ ] Invalid theme name or failed Plasma apply does not replace `current/theme`.
- [ ] VS Code `settings.json` merge and restore are tested with a fake User dir.
- [ ] Product/theming/cli/catalog docs match the code.
- [ ] `./test/all` is green.
