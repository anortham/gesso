# File layout

How this repo is shaped, and where files land on a Fedora KDE machine.

## Repo (source)

```
gesso/
  .github/workflows/ci.yml  GitHub Actions: ./test/all and a cmake build on Fedora 44
  bin/gesso                 CLI router
  bin/gesso-*               one executable per command, hidden helpers included
  data/apps.toml            browser/terminal/editor/install catalog (phase 2)
  data/agents.toml          coding-agent catalog (phase 4)
  default/themed/*.tpl      templates rendered by theme set: Plasma, Konsole, Kitty, Ghostty, Foot, VS Code
  themes/<name>/colors.toml first-party palettes (five in v1)
  setup/                    Kirigami Gesso Setup (phase 3)
  setup/org.gesso.setup.desktop  Exec=gesso setup
  test/cli                  driver for test/cli.d/*-test.sh
  test/cli.d/               one suite per area
  test/all                  aggregate runner
  docs/                     how the system is shaped
  plans/                    product brief and implementation plans
  packaging/gesso.spec      RPM spec (phase 5)
  packaging/README.md       Human COPR steps
```

Phase 0 creates `bin/`, `themes/tokyo-night/colors.toml`, and `test/`. Phase 3 adds `setup/` and `setup/org.gesso.setup.desktop`. Phase 5 adds `packaging/gesso.spec`. The v1 gaps plan adds `.github/workflows/ci.yml`, `bin/gesso-vscode-colors`, the Ghostty and Foot templates, and four palettes. Do not create empty directories ahead of the plan that owns them.

A development build of the Setup app (`cmake -S setup -B setup/build && cmake --build setup/build`) lands at `setup/build/bin/gesso-setup`. `setup/build/` is not committed.

## Installed (Fedora)

Two RPMs ship: `gesso` and `gesso-plasma`. There is no `gesso-agents` package.

The `gesso` RPM:

| Source | Installed at |
|---|---|
| `bin/gesso`, `bin/gesso-*` | `/usr/bin/` |
| `themes/`, `default/`, `data/` | `/usr/share/gesso/` |

The `gesso-plasma` RPM:

| Source | Installed at |
|---|---|
| Setup binary | `/usr/libexec/gesso/gesso-setup` |
| `setup/org.gesso.setup.desktop` | `/usr/share/applications/` |
| Look-and-Feel, if any | `~/.local/share/plasma/look-and-feel/` at apply time, not `/usr`, so uninstall and Aurora both work |

The bash launcher stays `/usr/bin/gesso-setup` in the `gesso` package. It execs `/usr/libexec/gesso/gesso-setup`. It does not search `PATH` for another `gesso-setup`.

`$GESSO_PATH` is `/usr/share/gesso` on an installed system. A git checkout of `bin/gesso` may default it to the repo root when the env var is unset.

## User machine

| Kind | Path |
|---|---|
| User themes, hooks, template overrides | `~/.config/gesso/` |
| Generated current theme, editor default | `~/.local/state/gesso/` |
| Default agent name | `~/.config/gesso/defaults/agent` |
| Plasma color scheme Gesso wrote | `~/.local/share/color-schemes/` |
| Konsole scheme and profile Gesso wrote | `~/.local/share/konsole/` |
| Kitty theme file | `~/.config/kitty/gesso-theme.conf` |
| Ghostty theme file | `~/.config/ghostty/themes/Gesso` |
| Foot theme file | `~/.config/foot/gesso-theme.ini` |
| VS Code theme file and merged `settings.json` | `~/.config/Code/User/` |
| Flatpak VS Code theme file and merged `settings.json` | `~/.var/app/com.visualstudio.code/config/Code/User/` |
| VS Code color backup | `~/.local/state/gesso/vscode-colorCustomizations.json` |
| Flatpak VS Code color backup | `~/.local/state/gesso/vscode-flatpak-colorCustomizations.json` |
| Konsole `DefaultProfile=` backup | `~/.local/state/gesso/konsole-default-profile` |
| GTK color scheme backup | `~/.local/state/gesso/gtk-color-scheme` |
| `mise`, installed per user by `gesso default agent` | `~/.local/bin/mise` |
| Per-user Flatpaks from the user `flathub` remote | `~/.local/share/flatpak/` (Flatpak owns this path) |

`gesso theme restore` consumes the four backup files. Gesso does not own `/etc`, SDDM, the bootloader, or `/usr/share/plasma` except via the user's `~/.local/share` overlay.
