# Gesso next-level product plan

Date: 2026-09-04
Status: Proposed roadmap for review. This document does not authorize implementation or publication.

## Recommendation

Make the next milestone a complete mouse-first experience on Fedora KDE: choose a look visually, apply it to the apps you actually use, install useful software, and undo changes without opening a terminal.

Gesso has the right architecture and a useful first implementation. The biggest gap is the distance between generating the right files and delivering a desktop experience an ordinary user can understand and trust. Close that gap before adding another distro, dozens of themes, or a larger command set.

This extends the [original product brief](2026-08-26-product.md). The completed v1 plans remain historical records. A broader everyday audience should shape the home screen and app catalog, while coding agents remain an optional part of the product.

## Review basis

Reviewed Gesso at `46c8ba589a39460fa0610531846e6e95ff92a6da` on `main`, including the fresh Fedora install fixes merged after the v1 gaps work. The main checkout and the existing `v1-gaps` worktree were clean before this review; the latter is already merged.

Reviewed the local Omarchy checkout at `493067741e081c3b09082da6bfd51e99ec24ef00`, branch `quattro`. It had an existing untracked `.miller/` directory. This is a comparison against that checkout, not a claim about all upstream versions.

Evidence comes from source, project docs, existing tests, and the upstream references linked below. This review did not observe a live Plasma session or conduct user testing. UX conclusions are assessments of the implemented flows, not measured usability results.

Verification on the reviewed commit: `./test/all` passed with exit 0 and 145 `ok` checks. The session log is `/tmp/gesso-test-all-corrected.iJCMwr.log`. RPM build, lint, and COPR tools are absent locally, so this review did not validate built RPMs, publication, or the installed desktop. Setup compilation was not rerun for this documentation-only change.

## What exists, and where it falls short

| Area | What exists | Gap to close |
|---|---|---|
| Product architecture | A CLI shared by Kirigami and tests, TOML catalogs, user-local generated state, two RPMs. | Keep these boundaries; the product needs completion of user journeys more than a rewrite. |
| Themes | Five palettes, staging and locking, Plasma and Konsole apply, VS Code JSONC merging, GTK light/dark preference, generated Kitty/Ghostty/Foot configs, user overlays. | Visual selection, complete app activation, honest coverage reporting, wallpaper curation, and recovery are not one finished experience. |
| Software | Catalog-driven install and install-then-default, host and Flatpak detection, graphical install actions. | The catalog concentrates on browsers, terminals, and editors. Everyday users need purpose, descriptions, reliable availability, and clear install outcomes. |
| Setup | Four persistent pages with asynchronous mutations. | It needs a guided starting point, richer visual choices, responsive reads, understandable progress, and graphical behavior tests. |
| Agents | Catalog, per-user mise installation, default selection, terminal launch. | Project selection and understandable launch behavior need attention; agents should not dominate the general desktop experience. |
| Delivery | RPM spec, CLI CI and Setup compilation CI, documented release procedure. | COPR remains unpublished in repo docs. Test coverage does not establish the installed graphical experience or RPM lifecycle. |

Key evidence: [layout](../docs/layout.md), [theme behavior](../docs/theming.md), [catalogs](../docs/catalog.md), [CLI and Setup](../docs/cli.md), [test scope](../docs/testing.md), [packaging](../docs/packaging.md).

Source review confirms the UI gaps. `setup/qml/ThemePage.qml:19` loads theme names and `:56` handles apply results without a preview or recovery control. `setup/qml/InstallPage.qml:58` builds the browser/terminal/editor list. `setup/GessoCli.cpp:34` uses synchronous waits for reads, which can block the UI when a command is slow. `test/cli.d/setup-test.sh:35` checks source strings rather than running the interface.

Three gaps deserve special attention:

- Theme files for Kitty, Ghostty, and Foot do not enable themselves. The user must add an include or theme setting in the main app config. A successful file generation is not proof that the next app launch matches the desktop.
- `theme restore` restores selected settings and applies Breeze. It does not restore wallpaper or the exact previous Plasma scheme, and it is not an undo of the most recent theme choice.
- The documented `brave-origin` catalog entry requires an externally configured RPM repository. Show that prerequisite before offering installation. Preserve the `/etc` boundary instead of turning a known limitation into a failing promise. See [catalog exception](../docs/catalog.md) and [unscheduled ideas](../TODO.md).

## What to learn from Omarchy

| Useful behavior in the reference checkout | Gesso adaptation |
|---|---|
| Theme previews and wallpaper selection: `manual/06-themes.md:3`, `default/omarchy/omarchy-menu.jsonc:103`. | A visual theme gallery and wallpaper picker in Setup, with first-party or properly licensed artwork. |
| Purpose-based install menus and installed-state awareness: `manual/29-other-packages.md:5`, `default/omarchy/omarchy-menu.jsonc:190`. | A small curated app collection with search, descriptions, source information, and visible installed state. |
| Clickable audio, network, Bluetooth, and media controls: `shell/plugins/bar/README.md:59`. | Make the corresponding Plasma features easy to find. Keep Plasma's panel and controls. |
| File sharing from the file manager: `manual/22-guis.md:41`. | Guide users into KDE Connect for tested device pairs first. This does not claim parity with LocalSend's broader cross-platform workflow; evaluate remaining sharing needs separately. |
| Web apps with creation and removal: `manual/25-web-apps.md:3`. | A later optional workflow using desktop launchers, once supported browser behavior and removal are tested. |
| Small diagnostic and recovery actions: `manual/45-troubleshooting.md:25`. | Explain Gesso-owned problems and offer targeted recovery. Leave system service repair to Fedora and KDE. |

Omarchy also has mouse interactions. Its strongest lesson is that the pieces work together and useful actions are easy to find. Copy those outcomes while retaining KDE's normal windowing and navigation.

Do not carry over Hyprland, Quickshell, Arch package policy, universal shortcut remapping, boot configuration, or executable remote theme bundles.

## Alternatives considered

1. **Polish the complete Fedora KDE experience first. Recommended.** Builds on the code already present and tests the actual reason someone would choose Gesso.
2. **Expand features first.** More apps, web apps, community themes, and integrations would make the feature list larger, but multiply incomplete install and recovery paths.
3. **Port to several distros now.** Advances distribution reach before establishing the experience worth porting. Keep paths portable now; prove a second host later.

## Global Constraints

- First supported target remains Fedora KDE Plasma Desktop 44, mutable, `dnf`. Aurora/Kinoite follows its own acceptance gate.
- Gesso remains an add-on. No replacement shell, panel, launcher, clipboard manager, ISO, bootloader, SDDM, NVIDIA ownership, or `/etc` writes.
- The CLI is the API. Every new Gesso-owned action must work through a `gesso-*` command; QML renders state and invokes actions.
- Keep catalogs in `data/`, palettes in `themes/`, templates in `default/themed/`, user overlays in `~/.config/gesso/`, and generated state in the existing user paths.
- Preserve existing command behavior when adding machine-readable status. New command names in later implementation plans must be explicitly marked as additions.
- Required actions are discoverable with a mouse. Preserve keyboard navigation, visible focus, readable contrast, scaling, and accessible labels.
- Do not promise identical theming in every app. Report whether each supported target is applied, needs restart, is unavailable, or supports only light/dark preference.
- Use supported app configuration mechanisms. Do not replace whole user configs, weaken Flatpak isolation for appearance, or silently run imported scripts.
- Keep coding agents available and optional. Do not silently change their existing launch flags as part of a UI refresh.
- Do not add a catalog row without verifying its Fedora install path. Missing external prerequisites must be visible before installation.
- Publishing, pushing, releasing, spending money, and changes to the agreed product boundaries require explicit approval.

## Architecture Quality

**Affected modules:** Setup QML and `GessoCli`, theme application and restore commands, catalog queries and package operations, packaging and acceptance tests.

**Caller-facing interface:** Existing CLI commands remain the behavior contract. Add bounded structured query/result output where Setup needs to distinguish installed state, applicability, progress, warnings, and failure. Preserve ordinary CLI text output.

**Depth and locality:** Package policy belongs with the existing package/catalog commands. Theme activation and recovery belong with the existing theme commands. The Qt bridge owns process execution and lifecycle, not installation or theme policy.

**Seams:** Keep the current TOML and template boundaries. Extract shared logic only when a delivered second caller needs it. A small explicit host policy can be introduced for Atomic support when that milestone starts; no general plugin framework.

**Test surface:** Exercise CLI contracts with stubs, Qt process behavior with controlled fake commands, QML interactions with a built app, and desktop effects in a disposable Fedora KDE session.

**Main risk:** Medium. The likely failure is expanding Setup into a replacement control center or leaving the GUI and CLI with different interpretations of success. Keep each slice tied to a concrete user action and let KDE own its existing features.

This preserves [ADR-0001](../docs/adr/0001-add-on-not-distro.md), [ADR-0002](../docs/adr/0002-cli-is-the-api.md), and the no-`/etc` decision in [ADR-0003](../docs/adr/0003-user-state-not-etc.md). Reconcile that ADR's older install-path wording with the current layout during documentation work; it predates the documented libexec and app-config destinations.

## Delivery sequence

These are proposed milestones, not claims of approved scope or implementation-ready patches. Each should get a bounded implementation plan before execution. Finish one user-visible slice at a time.

Use two tracks. Milestone 1 gathers evidence for the existing release while feature work begins with milestone 2 and the focused theme journey in milestone 3. The next experience release must pass milestones 2–4 and repeat the installed-system gate for that final commit. Publishing the existing version is an independent decision, not a prerequisite for feature development.

### 1. Establish an installable, testable release candidate

**Outcome:** The existing implementation has a verified RPM lifecycle on fresh Fedora KDE. This is a technical release candidate, not yet acceptance of the proposed mouse-first experience.

**Primary files:** `packaging/gesso.spec`, `packaging/README.md`, `.github/workflows/ci.yml`, `README.md`, `docs/packaging.md`, `docs/testing.md`. Add a documented graphical acceptance record under `docs/`.

**Work:** Build actual RPMs, inspect the payload and runtime dependencies, and test installation, upgrade, restore, removal, and reinstall in a disposable Fedora KDE 44 machine. This gate uses the existing documented CLI baseline restore, including its Breeze fallback and lack of wallpaper restoration. Milestone 3 supplies graphical recovery and the stronger restoration contract. Fix failures found here through bounded correction packets for the affected files. Cover graphical authorization, denied authorization, offline package operations, and native/Flatpak defaults. Replace the placeholder install instructions only after the real COPR exists.

- [ ] Fresh installation launches Setup from KDE without a terminal.
- [ ] Core theme, app-install, and default-selection journeys pass on the installed RPMs.
- [ ] Upgrade preserves user settings; restore and removal leave Plasma usable.
- [ ] Evidence names the package version, commit, Fedora/Plasma versions, and any remaining limitations.
- [ ] A concrete release candidate is ready for publication approval. COPR publication is a separate authorized action.

**Dependency:** The release-evidence track starts immediately and can run alongside feature development. Packaging defects belong here; feature gaps belong to their named milestones. A broader correction gets its own explicit file ownership before dispatch. Publication need not block local development.

### 2. Make Setup communicate and recover

**Outcome:** The user can tell what Gesso is doing, what changed, and what to do if an operation fails.

**Primary files:** `setup/GessoCli.cpp`, `setup/GessoCli.hpp`, `setup/qml/Main.qml`, `setup/qml/ThemePage.qml`, `setup/qml/DefaultsPage.qml`, `setup/qml/InstallPage.qml`, `setup/qml/AgentsPage.qml`, `setup/CMakeLists.txt`, `test/cli.d/setup-test.sh`. Add focused bridge and QML behavior tests under `setup/`.

**Work:** Add a small welcome/status view with direct entry points into appearance and apps. Make reads as well as mutations asynchronous. Show the current operation, useful output, a plain-language result, and expandable diagnostics. Report partial success explicitly. Define what happens on tab changes, window close, process start failure, and retry. Never offer cancellation of an active package transaction unless the backend supports it safely.

- [ ] A slow or missing command leaves the window responsive and produces a visible result.
- [ ] Tab changes and repeated clicks cannot launch conflicting mutations or attach results to the wrong action.
- [ ] Existing selections refresh after changes made elsewhere.
- [ ] Every normal path is usable with a mouse and keyboard at increased display scaling.
- [ ] Automated tests exercise running QML and bridge behavior, rather than only matching source text.

**Dependency:** Establish the process/result contract first. Later appearance and app work share it.

### 3. Deliver the visual theming experience

**Outcome:** A user chooses a look visually, sees it applied to supported apps, and can revert it without editing files.

**Primary files:** `setup/qml/ThemePage.qml`, `bin/gesso-theme-list`, `bin/gesso-theme-set`, `bin/gesso-theme-restore`, `bin/gesso-theme-set-templates`, `bin/gesso-vscode-colors`, `default/themed/`, `themes/`, `test/cli.d/theme-test.sh`, `docs/theming.md`. Add small theme metadata/query support only as needed by the gallery.

**Work:** Turn the five existing palettes into preview cards showing desktop, terminal, and editor samples. Add licensed wallpaper assets and a chooser with a keep-my-wallpaper option. Previewing must not apply changes. Add opt-in, reversible enablement for Kitty, Ghostty, and Foot through their supported settings. Before implementation, each adapter's slice plan must define its exact setting/include, conflict detection, and rollback. Unsupported config shapes must produce guidance without rewriting the file.

Wallpaper has three explicit choices: keep the current wallpaper, use the selected theme's wallpaper, or use a user-selected image. Keep is the initial choice. A custom image is copied into Gesso's user-local data so moving its source does not break the desktop. Store the choice independently of the palette. Undo records the previous choice and wallpaper mapping; baseline restore records the original mapping. Preserve per-screen/activity state where supported, and leave unsupported layouts unchanged with an explanation. Do not delete an image while current or recovery state references it. If the user changes wallpaper outside Gesso, restoration must detect that change and ask before replacing it.

Separate three operations: preview without writes, undo the last apply, and restore the pre-Gesso baseline. Record enough prior state for the exact Plasma scheme, wallpaper, and settings Gesso changes. If the user edits a managed setting afterward, preserve it and explain the conflict. Keep recovery data when restoration fails.

Start coverage with Plasma, Konsole, and the existing editor/terminal targets. Treat browser chrome, GTK, and Flatpak support as named targets with verified capabilities. GTK dark preference is not a full palette adapter. Flatpak themes depend on runtime support and desktop settings integration; follow [Flatpak's integration guidance](https://docs.flatpak.org/en/latest/desktop-integration.html).

- [ ] Every bundled theme has a useful visual preview and documented artwork rights.
- [ ] Apply shows the result for each supported installed app, including restart requirements.
- [ ] Supported terminal theming survives closing and reopening the app without manual config editing.
- [ ] A failed apply cannot report full success or discard the recovery data needed to recover.
- [ ] Undo returns to the previous Gesso selection; baseline restore returns Gesso-owned settings to their recorded prior values.
- [ ] Wallpaper restore, light/dark transitions, user edits, repeated applies, and partial failures have explicit tests.
- [ ] Gallery controls retain readable theme-aware colors, following [Kirigami color guidance](https://develop.kde.org/docs/getting-started/kirigami/style-colors/).

**Dependency:** Milestone 2's result contract. Recovery must land before adding more theme targets.

### 4. Make the software collection useful beyond coding

**Outcome:** A user can find a useful app by purpose, understand the choice, install it, and launch it.

**Primary files:** `data/apps.toml`, `bin/gesso-catalog-get`, `bin/gesso-app-present`, `bin/gesso-pkg-add`, `bin/gesso-default-browser`, `bin/gesso-default-terminal`, `bin/gesso-default-editor`, `setup/qml/InstallPage.qml`, `setup/qml/DefaultsPage.qml`, `test/cli.d/catalog-test.sh`, `test/cli.d/default-test.sh`, `docs/catalog.md`.

**Work:** Add descriptions, standard icons, purpose categories, source and prerequisite information. Keep default role separate from browsing category. Curate a small collection across office, communication, media, creativity, and utilities after checking each install path. Retain developer tools without making them the whole catalog.

Offer Install, Open, and Set default only where each action is valid. Re-read actual default and installed state. Explain package-source fallback and external prerequisites. Handle denied authorization as cancellation, not as permission to silently try a different installer. Link to Discover for the wider catalog and package maintenance.

- [ ] Search works by label and purpose; rows explain what the app is for.
- [ ] Each shipped recommendation has recorded fresh-Fedora installation evidence.
- [ ] Native, user Flatpak, system Flatpak, already-installed, and unavailable cases show accurate state.
- [ ] Known repository prerequisites appear before the user starts installation.
- [ ] Failed installation cannot change a default; failed default setting does not show success.
- [ ] Open works for both host and Flatpak apps.
- [ ] Users can reach Discover for updates and removal; Gesso does not duplicate a full package manager.

**Dependency:** Milestone 2. Can run alongside milestone 3 after shared navigation and result contracts are settled.

### 5. Add a small set of KDE-native integrations

**Outcome:** Gesso helps users find everyday KDE capabilities and connects its own features to the places people already work.

**Primary existing files:** `setup/qml/Main.qml`, `setup/qml/AgentsPage.qml`, `bin/gesso-agent`, `setup/org.gesso.setup.desktop`, `data/apps.toml`, `test/cli.d/agent-test.sh`, `test/cli.d/packaging-test.sh`. New integration UI and desktop actions should get exact ownership in their slice plans.

**Work:** Add concise entry points for phone pairing/file sharing through KDE Connect, screenshots through Spectacle, software updates through Discover, and the relevant System Settings pages. Detect missing tools and offer the existing catalog install flow where supported. Keep these as links and guidance where KDE already owns the workflow. KDE Connect already provides pairing and file transfer; see [KDE's guidance](https://userbase.kde.org/KDEConnect/en).

For coding users, add a folder chooser before launching an agent and an optional Dolphin action to open the chosen agent in that folder. Show the configured permission behavior before launch and retain existing flags unless a separate product decision changes them. Use [KDE's service-menu mechanism](https://develop.kde.org/docs/apps/dolphin/service-menus/) with argument-safe paths.

Explain any provider account or subscription requirement before installation and link to the provider's own sign-in flow. Gesso should not become a credential store. Verify catalog install identifiers and launch flags against current provider documentation before shipping changes.

- [ ] Every integration opens the intended installed KDE tool and handles its absence.
- [ ] Pairing, screenshots, and updates use KDE's existing controls.
- [ ] Folder paths containing spaces and non-ASCII characters reach the agent unchanged.
- [ ] Agent launch does not require the user to know or arrange the terminal's current directory.
- [ ] Disabling Gesso's optional desktop integration removes only Gesso-owned entries.

**Dependency:** Milestones 2 and 4. Keep this collection small; do not add background service management, firewall changes, or PAM changes.

### 6. Prove the second host

**Outcome:** The same user journeys work on a named Aurora or Kinoite release with an explicit support policy.

**Primary files:** `bin/gesso-pkg-add`, catalog/query helpers, `packaging/gesso.spec`, `docs/packaging.md`, `docs/catalog.md`, `test/cli.d/default-test.sh`, and the graphical acceptance record.

**Work:** Detect the supported host and available package mechanisms before mutation. Exercise a Flatpak/mise app path on an Atomic host, and document how Gesso's own RPMs are installed and updated there. Catalog choices without a supported install path must show unavailable or externally managed state. Reuse the theme engine without a distro-specific fork.

- [ ] No app-install action attempts host `dnf` on an Atomic system.
- [ ] Install, theme, default, recovery, upgrade, and removal journeys pass on the named second host.
- [ ] Unsupported hosts receive clear guidance before any unsupported mutation.
- [ ] Support claims name tested OS versions and package channels.

**Dependency:** Fedora experience accepted first. Other desktops and unrelated distros remain deferred.

## Verification Strategy

**Source of truth:** [docs/testing.md](../docs/testing.md), [packaging instructions](../packaging/README.md), and the CI workflow.

**Worker scope:** Run the affected `bash test/cli.d/<area>-test.sh` suite for CLI behavior. New Qt/QML tests must prove process and interaction behavior using fake commands. No real package manager, network installer, or user-session mutation in unit tests.

**Worker ceiling:** Assigned suites and the relevant Setup build/tests. Workers report failures with evidence and fix in-scope causes without weakening assertions.

**Lead affected-change scope:** Review the combined CLI/GUI contract after each coherent batch; build Setup after changes to its bridge, QML, or CMake configuration.

**Branch gate:** `./test/all`, `cmake -S setup -B setup/build`, and `cmake --build setup/build`, plus the graphical tests added by milestone 2. Run each required scope once per unchanged tree.

**Installed-system gate:** A disposable Fedora KDE 44 VM using the built RPMs. Require evidence for launching from KDE, graphical authorization, native and Flatpak defaults, theme activation on app restart, recovery, upgrade, removal, and reinstall. Test increased scaling, keyboard focus, and at least one light and one dark palette. Atomic support adds its own VM gate.

**Catalog maintenance:** Before each release, run live install checks in a disposable environment for every supported app path and verify agent install identifiers and launch flags. Keep these separate from deterministic unit tests. Do not automate paid provider calls or authenticate personal accounts in CI.

**Security scope:** None declared as a standalone scan or dependency-audit command in current repo docs. Review imported theme data, command arguments, package privileges, and config ownership in the relevant changes; do not claim that as a completed security audit.

**Usability gate:** Before calling the next experience release ready, test with five people unfamiliar with Gesso. At least four should independently choose/apply/undo a theme and find/install/open an app without terminal instructions. Record assistance, wrong turns, and failures. Time-to-completion is report-only and should separate download time.

**Verification ledger:** Record invariant, command or manual scenario, commit, package version, environment, timestamp, result, and evidence location. Stub tests never count as proof of a live desktop effect.

## Parallel Execution Contract

Astra owns milestone design, contract decisions, final review, and integration verification. Sol workers own bounded implementation/evidence packets and must not redesign or broaden them.

| Work | Parallel batch | File ownership | Serialization required | Dependency reason |
|---|---|---|---|---|
| Release evidence and delivery fixes | A | Packaging/CI/docs paths in milestone 1; individual fixes get bounded ownership | Yes for shared docs | Release evidence defines real prerequisites. |
| Setup process/result contract | B | Bridge, Main.qml, initial GUI tests from milestone 2 | Yes | Theme and software pages depend on this behavior. |
| Theme experience | C | Theme commands/templates/assets, ThemePage.qml, theme tests/docs from milestone 3 | No | Safe alongside app work after contract agreement. |
| Software experience | C | App catalog/commands, InstallPage.qml, DefaultsPage.qml, catalog/default tests/docs from milestone 4 | No | Safe alongside theme work; shared Main.qml and bridge edits stay with the lead's separate packet. |
| KDE integrations | D | Dedicated integration UI/actions and agent paths from milestone 5 | Yes | Reuses the accepted navigation and install flows. |
| Atomic host support | E | Package policy, packaging docs and Atomic tests from milestone 6 | Yes | Starts after Fedora acceptance; touches previously owned package files. |

Each slice plan must replace directory-level ownership with exact create/modify/test paths before dispatch. Workers hand back verified changes without committing during parallel batches. The lead reviews the combined result before any commit or release action.

## Defer deliberately

- Community theme installation, remote theme registries, and image-generated palettes until local themes have complete validation and recovery.
- Browser chrome adapters until a named browser/configuration has a supported, tested approach.
- Web-app creation until the core app lifecycle is dependable.
- Automatic day/night schedules and additional palettes until preview/apply/undo works.
- Gesso-owned package removal until ownership and native/system/user Flatpak distinctions justify the maintenance burden. Discover covers the immediate need.
- Fingerprint/PAM setup, third-party repository mutation, firewall ownership, and service restarts. These exceed Gesso's existing boundaries.
- A plugin host, custom desktop shell, broad distro framework, or OS image.

## First implementation slice

Start with one complete journey: open Setup, choose a preview, apply it, see the actual result, and undo it. Establish the shared process/result behavior and theme recovery required by that journey. Gather RPM/VM evidence alongside it.

That gives the project a visible improvement and a concrete acceptance test. Expand app discovery next, then add the KDE integrations and the second host.
