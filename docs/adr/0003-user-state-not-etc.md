# ADR-0003: User state, not /etc

## Context

Omarchy's `omarchy-settings` clobbers `/etc` for a full OS. Aurora's `/usr` is read-only. Gesso must uninstall cleanly on mutable Fedora and remain usable on Kinoite later.

## Decision

Gesso writes generated theme and app files under `~/.local/state/gesso`, `~/.local/share`, and `~/.config/gesso`. It does not ship `/etc` drop-ins, SDDM, or bootloader config. RPM payload is `/usr/bin` and `/usr/share/gesso` only.

## Consequences

Uninstall cannot fully un-theme a user without a documented restore step (apply Breeze). Atomic desktops can run the same theme engine. We never fight `rpm` file conflicts on `/etc`.

## Applies To

Theme set, packaging, Setup app.

## Future Agents

A pull request that writes to `/etc` is out of scope unless the product brief is explicitly revised.
