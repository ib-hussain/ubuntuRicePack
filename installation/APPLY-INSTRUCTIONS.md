# UbuntuRicePack application guide

This repository can be used either as a post-install configurator or through
the hybrid Ubuntu Desktop autoinstall template in
`installation/autoinstall.yaml`. The autoinstall deliberately leaves network
and storage interactive and never contains an automated disk recipe.

## Install Ubuntu Desktop with the hybrid autoinstall

First commit and push the exact revision you want the new machine to run. The
helper refuses a dirty tree or a local commit that is not `origin/main`; this
prevents an autoinstall file from pointing at code GitHub cannot fetch.

Then create a private, ready-to-import copy. The helper prompts locally and
stores a SHA-512 password hash plus the immutable pushed Git commit:

```bash
git status
git push origin main
bash installation/prepare-autoinstall.sh
bash tests/validate-autoinstall.sh installation/autoinstall-ready.yaml
```

Then boot the Ubuntu Desktop installer, choose Automated Installation, and
import `installation/autoinstall-ready.yaml`.

The installer will still stop for:

1. network selection; and
2. the complete Ubuntu storage page.

Select a working Internet connection. The Desktop ISO must reach Ubuntu's
archive to install OpenSSH Server and the requested updates, drivers, and
codecs. The rice repository itself is no longer downloaded inside Subiquity's
fatal late-command phase; it is fetched with retries after the first login.

The template supports Ubuntu 26.04 through the normal archive and can fall
back to `old-releases.ubuntu.com` for an Ubuntu 25.04 ISO. Plucky is end of
life; this fallback restores package access, not security maintenance.

At the storage page, make the real-machine decision yourself: erase the
selected disk, install alongside another operating system, or use manual
partitioning. The YAML contains no disk match, wipe, partition, filesystem, or
mount recipe. Check the target device by model and capacity, and never select
the USB stick that contains the live installer.

After the installer finishes it reboots. Log in as `ibrahim`; a visible
terminal starts the pinned UbuntuRicePack revision exactly once. On success it
removes its own autostart entry. On failure it leaves the entry in place,
records the failure, and retries at a future login.

The autoinstall also installs and enables OpenSSH Server. Verify it after the
first boot:

```bash
systemctl status ssh
sshd -T | grep -E '^(permitrootlogin|passwordauthentication) '
hostname -I
```

Direct root SSH login is disabled. Password SSH login is enabled as requested.
If the selected password is short, keep port 22 off the public Internet; add an
SSH key and disable password authentication before exposing the machine.

The helper inserts the current pushed `origin/main` commit in both bootstrap
audit locations. No moving branch is checked out.

The generated `installation/autoinstall-ready.yaml` is ignored by Git because
its password hash is reusable authentication material.

If Subiquity fails, preserve
`/var/log/installer/subiquity-server-debug.log` and
`/var/log/installer/curtin-install.log` before leaving the live session. When
the target filesystem exists, the error handler also writes
`/var/log/installer/ubuntu-rice-live-installer-logs.tar.gz` into the installed
target. A failed shell late command cannot rewrite the live ISO; persistent
failure before partitioning normally points to the imported YAML, installer
state, or the USB media rather than a rice script modifying the ISO.

## What this build changes

- `rice-dock@ib-hussain` replaces Ubuntu Dock, upstream Dash-to-Dock, and the
  retired Arch icon overlay. It uses exactly one image:
  `media/logo.png`.
- `rice-top-bar@ib-hussain` combines current Hide Top Bar behavior with an
  explicit, reversible transparent-panel controller.
- Both custom extensions contain reviewed source in this repository. The same
  extension source works on Ubuntu and Arch GNOME 48/50.
- Ubuntu Dock, Dash-to-Dock, the old Arch icon patch, and the old Hide Top Bar
  UUID are disabled to prevent competing actors or styles.
- Password resetting uses a separate privileged interactive helper. It does
  not weaken password policy globally or read/store the password.
- Extension lifecycle messages go to the GNOME Shell journal, and installer
  diagnostics go to both a normal log and journald.

The installer retains package setup, Nerd Fonts, themes, terminal tools,
wallpaper caching, GRUB assets, VS Code data, desktop launchers, GNOME
configuration, detailed verification, and the no-Snap/no-Firefox policy.

## Validate the downloaded tree

From the repository root:

```bash
bash tests/validate-rice-product.sh
```

This checks shell and JavaScript syntax, extension metadata, relative imports,
strict GSettings schema compilation, XML/UI parsing, the single-logo
invariant, transparency controls, and removal of retired extension source.

## Apply everything on Ubuntu GNOME

Run as the normal logged-in desktop user:

```bash
bash ./install-rice.sh -m desktop
```

Then log out and back in. A newly copied GNOME Shell extension cannot always
enter the already-running Shell process safely.

Useful options:

```text
-m, --mode MODE
-H, --host NAME
-K, --keep-host
-t, --tz ZONE
-l, --locale LOCALE
-p, --python VERSION
-r, --repair-pass
-s, --strict
```

`--strict` makes unavailable packages, external installers, Nerd Fonts, GNOME
mismatches, and final verification errors fatal. The final desktop audit is
already strict for genuine failures.

## Apply only Rice Dock and Rice Top Bar

This command is intentionally package-manager-independent and works from this
repository on either Ubuntu or Arch GNOME 48/50:

```bash
bash scripts/install-rice-shell-extensions.sh
```

It:

1. validates both extension sources against the running GNOME Shell version;
2. backs up previous installations;
3. installs and strictly compiles schemas;
4. disables the four conflicting dock/top-bar UUIDs;
5. enables Rice Dock and Rice Top Bar;
6. writes state and journal reports.

Log out and back in afterward.

To copy source without changing extension states:

```bash
bash scripts/install-rice-shell-extensions.sh --install-only
```

To reapply only the enabled/disabled state:

```bash
bash scripts/install-rice-shell-extensions.sh --state-only
```

## Set a four-character local password

The observed error occurs during the current-password/PAM phase, before
password-length policy is evaluated. Use the repository helper:

```bash
bash scripts/09-set-local-password.sh
```

If ordinary `passwd` displays two current-password prompts or ends with
`Authentication token manipulation error`, repair the packaged Ubuntu PAM
stack and set the password in one controlled workflow:

```bash
bash scripts/09-set-local-password.sh --repair-pam
```

That option copies the current `/etc/pam.d/passwd` and `common-*` files into a
timestamped directory under `~/.local/state/ubuntuRicePack/backups/`, then runs
Ubuntu's `pam-auth-update --force`. The original configuration remains
recoverable even though the packaged profiles are regenerated.

The helper checks:

- the local account and password status;
- root-filesystem writability;
- the setuid `passwd` executable;
- `/etc/passwd`, `/etc/group`, `/etc/shadow`, and `/etc/gshadow`;
- account-database consistency;
- `/etc/pam.d/passwd` and the `pam_unix` password stack;
- whether root password-quality enforcement is explicitly enabled.

After the audit, it runs:

```bash
sudo passwd ibrahim
```

Enter the new password twice. Because `passwd` runs as root, no current-password
prompt is expected and ordinary quality warnings are advisory unless the
administrator explicitly configured `enforce_for_root`.

To collect diagnostics without opening the prompt:

```bash
bash scripts/09-set-local-password.sh --diagnose-only
```

To perform the explicit PAM repair through the main installer:

```bash
bash ./install-rice.sh -m desktop -r
```

## WSL

Use the same entry point:

```bash
bash ./install-rice.sh -m wsl
```

Desktop GNOME stages and extensions are not run in WSL. If `/etc/wsl.conf`
changes, run `wsl --shutdown` from Windows PowerShell afterward.

## Optional local AI

Ollama and Open WebUI remain independent of the main installer:

```bash
bash scripts/10-setup-local-ai-ollama-openwebui.sh
```

It installs the configured services, downloads only the first two configured
models, and creates the Open WebUI desktop launcher.

## Logs, reports, and backups

UbuntuRicePack writes:

```text
~/.local/state/ubuntuRicePack/logs/
~/.local/state/ubuntuRicePack/reports/
~/.local/state/ubuntuRicePack/backups/
```

The cross-distribution extension-only installer writes:

```text
~/.local/state/rice-shell-extensions/
```

Inspect the custom extension lifecycle after logging back in:

```bash
journalctl --user -b -o cat |
  grep -E '\[(rice-dock|rice-top-bar)@ib-hussain\]'
```

Inspect the password helper:

```bash
journalctl -b -t ubuntuRicePack-password --no-pager
```

## Intentional exclusions

- No GDM logo or GDM background customization.
- No chroot, `arch-chroot`, partitioning, or boot-media installer.
- No duplicate wallpaper archive; wallpapers are fetched and cached at
  runtime.
- No bundled unmodified GNOME extensions other than the two repository-owned
  custom products.
- No automatic local-AI installation.
