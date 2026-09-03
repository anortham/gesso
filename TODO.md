# TODO

Ideas not yet scheduled. Nothing here is committed to v1.

## Fingerprint auth for sudo

On first run, check whether the machine has a fingerprint sensor and offer to set it up for `sudo` authentication.

Gesso already elevates for `gesso pkg add` and the dnf path in `gesso default editor`, so a fingerprint prompt would remove the password typing from the most common install flows. Detection is `fprintd-list "$USER"` or a `lsusb`/`/sys` probe for a supported reader. Enrollment is `fprintd-enroll`. Enabling it for `sudo` is a PAM change, which conflicts with the "never write to `/etc`" rule in `AGENTS.md`, so this needs a decision before any code: either the rule gets a documented exception for `authselect enable-feature with-fingerprint`, or Gesso only detects the sensor and points the user at the KDE Users settings module.

## Third-party dnf repositories

`brave-origin` is in `data/apps.toml`, but `gesso pkg add brave-origin` only works if the user has already added Brave's RPM repository by hand.

Brave Origin ships nowhere else. There is no Flathub build, and Fedora does not carry it. Adding the repo means writing `/etc/yum.repos.d/brave-browser.repo`, which `AGENTS.md` forbids twice, under Paths ("Never write to `/etc`") and under Hard no ("`/etc` drop-ins"). The same wall blocks the fingerprint item above, so this is really one decision about whether Gesso ever touches `/etc`.

Three ways out, in rough order of how much they cost:

1. Leave it. `gesso pkg add brave-origin` exits 1 with `failed to install brave-origin` on a stock machine, and `gesso default browser brave-origin` works for people who installed Brave Origin themselves. Honest, and nothing new to maintain.
2. Add a `repo` field to the catalog and a `gesso pkg repo <id>` command that writes the vendor `.repo` file with `pkexec`. This needs an ADR amending the `/etc` rule, plus a matching uninstall path, because leaving a Brave repo behind after `dnf remove gesso` breaks the promise in `docs/packaging.md` that removal leaves the system as it was.
3. Detect the missing repo and print the exact `dnf config-manager addrepo` line for the user to run. No `/etc` write by Gesso, and the user stays in control. Probably the right v1 answer.
