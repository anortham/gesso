# ADR-0002: The CLI is the API

## Context

Omarchy's menu, keybinds, and shell all call `omarchy-*` binaries. A second implementation in the GUI would drift.

## Decision

Every user action is a `gesso-*` command. The Kirigami Setup app only execs those commands. Tests call the same binaries.

## Consequences

Headless tests cover the product. A GUI bug cannot invent a different installer. The CLI must be pleasant enough to use without the app.

## Applies To

`bin/`, `setup/`, tests.

## Future Agents

Do not put install/theme/default logic in QML. If the app needs a new behavior, add a command first.
