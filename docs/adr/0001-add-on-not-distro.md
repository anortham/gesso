# ADR-0001: Add-on, not a distro

## Context

Omarchy ships the last-mile UX (one palette, install-then-default, agents) as an Arch + Hyprland OS. Aurora already is an opinionated Fedora KDE OS (bootc image, NVIDIA variants, Flatpak+brew). Cloning either as a Fedora remix would mean owning installers, kernels, and rebases.

## Decision

Gesso is COPR RPMs plus a Setup app on stock Fedora KDE 44. It is not a remix, spin, or bootc image in v1.

## Consequences

Easier to try and to uninstall. Cannot change Fedora's first-boot defaults. Aurora can consume the same RPMs later if files stay under `/usr/share/gesso` and `$HOME`.

## Applies To

Packaging, install paths, product scope.

## Future Agents

Refuse ISO, kickstart, and `FROM aurora` work until phase 5 of the product brief is done and someone explicitly asks for an image channel.
