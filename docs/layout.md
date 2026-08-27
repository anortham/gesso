# File layout

How this repo is shaped, and where files land on a Fedora KDE machine.

## Repo (source)

```
gesso/
  bin/gesso                 CLI router
  bin/gesso-*               one executable per command
  data/apps.toml            browser/terminal/editor/install catalog (phase 2)
  data/agents.toml          coding-agent catalog (phase 4)
  default/themed/*.tpl      templates rendered by theme set (phase 1)
  themes/<name>/colors.toml first-party palettes
  setup/                    Kirigami Gesso Setup (phase 3)
  setup/org.gesso.setup.desktop  Exec=gesso setup
  test/cli                  router + theme tests
  test/all                  aggregate runner
  docs/                     how the system is shaped
  plans/                    product brief and implementation plans
  packaging/                RPM spec later (phase 5)
```

Phase 0 creates `bin/`, `themes/tokyo-night/colors.toml`, and `test/`. Phase 3 adds `setup/` and `setup/org.gesso.setup.desktop`. Later phases add the rest. Do not create empty directories ahead of the plan that owns them.

## Installed (Fedora)

The `gesso` RPM:

| Source | Installed at |
|---|---|
| `bin/gesso`, `bin/gesso-*` | `/usr/bin/` |
| `themes/`, `default/`, `data/` | `/usr/share/gesso/` |

The `gesso-plasma` RPM (phase 3+):

| Source | Installed at |
|---|---|
| Setup binary | `/usr/bin/gesso-setup` |
| `setup/org.gesso.setup.desktop` | `/usr/share/applications/` |
| Look-and-Feel, if any | `~/.local/share/plasma/look-and-feel/` at apply time, not `/usr`, so uninstall and Aurora both work |

`$GESSO_PATH` is `/usr/share/gesso` on an installed system. A git checkout of `bin/gesso` may default it to the repo root when the env var is unset.

## User machine

| Kind | Path |
|---|---|
| User themes, hooks, template overrides | `~/.config/gesso/` |
| Generated current theme, editor default | `~/.local/state/gesso/` |
| Default agent name | `~/.config/gesso/defaults/agent` |
| Plasma color scheme Gesso wrote | `~/.local/share/color-schemes/` |
| Konsole scheme Gesso wrote | `~/.local/share/konsole/` |

Gesso does not own `/etc`, SDDM, the bootloader, or `/usr/share/plasma` except via the user's `~/.local/share` overlay.
