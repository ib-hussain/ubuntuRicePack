# UbuntuRicePack application guide

This repository is a post-install configurator for an already installed Ubuntu
GNOME 50 desktop or Ubuntu on WSL. It does not partition disks or install the
Ubuntu operating system.

## What this build changes

- `rice-dock@ib-hussain` replaces Ubuntu Dock, upstream Dash-to-Dock, and the
  retired Arch icon overlay. It uses exactly one image:
  `media/logo.png`.
- `rice-top-bar@ib-hussain` combines current Hide Top Bar behavior with an
  explicit, reversible transparent-panel controller.
- Both custom extensions contain reviewed source in this repository. The same
  extension source works on Ubuntu and Arch GNOME 50.
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
./install-rice.sh --mode desktop
```

Then log out and back in. A newly copied GNOME Shell extension cannot always
enter the already-running Shell process safely.

Useful options:

```text
--strict
--skip-nerd-fonts
--skip-ventoy
--skip-vscode
--skip-python
--skip-packages
--keep-hostname
--keep-sudo-password
--set-short-password
--repair-password-stack
```

`--strict` makes unavailable packages, external installers, Nerd Fonts, GNOME
mismatches, and final verification errors fatal. The final desktop audit is
already strict for genuine failures.

## Apply only Rice Dock and Rice Top Bar

This command is intentionally package-manager-independent and works from this
repository on either Ubuntu or Arch GNOME 50:

```bash
bash scripts/install-rice-shell-extensions.sh
```

It:

1. validates both extension sources and GNOME Shell 50 compatibility;
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

The main installer can run the same helper at the end:

```bash
./install-rice.sh --mode desktop --set-short-password
```

To perform the explicit PAM repair through the main installer instead:

```bash
./install-rice.sh --mode desktop --repair-password-stack
```

## WSL

Use the same entry point:

```bash
./install-rice.sh --mode wsl
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
