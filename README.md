# Gesso

A Fedora KDE add-on. One palette, install-then-set-default, and a coding-agent picker.

Not a distro. Not Hyprland. Not a fork of Omarchy or Aurora.

```bash
dnf copr enable <owner>/gesso
dnf install gesso-plasma
gesso setup
```

`<owner>` is a placeholder until the COPR exists. Do not invent a COPR user. If Gesso is the active scheme, run `gesso theme restore` before `dnf remove`.

## New session

Open this repo and follow `AGENTS.md`.

## Docs

| File | What it is |
|---|---|
| [plans/2026-08-26-product.md](plans/2026-08-26-product.md) | Product brief |
| [AGENTS.md](AGENTS.md) | How to work in this repo |
| [docs/layout.md](docs/layout.md) | File tree and install paths |
| [docs/cli.md](docs/cli.md) | Router and command metadata |
| [docs/theming.md](docs/theming.md) | Palette, templates, Plasma apply |
| [docs/catalog.md](docs/catalog.md) | App / default / agent catalog |
| [docs/packaging.md](docs/packaging.md) | RPMs, COPR, uninstall |
| [docs/testing.md](docs/testing.md) | Test suites |
| [docs/adr/](docs/adr/) | Locked decisions |
