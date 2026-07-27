# UbuntuRicePack

Ibrahim Hussain's reproducible Ubuntu GNOME 50 desktop configuration, with a
cross-distribution Rice Dock and Rice Top Bar that also run on Arch GNOME 50.

## Quick start

```bash
bash tests/validate-rice-product.sh
./install-rice.sh --mode desktop
```

Run as the normal logged-in GNOME user. Log out and back in when installation
finishes.

To install only the two custom extensions on Ubuntu or Arch:

```bash
bash scripts/install-rice-shell-extensions.sh
```

To diagnose the native password stack and set a short local password through
the privileged system prompt:

```bash
bash scripts/09-set-local-password.sh
```

If the current PAM stack produces duplicate current-password prompts or an
authentication-token error, use the explicit backed-up repair path:

```bash
bash scripts/09-set-local-password.sh --repair-pam
```
Implemented and packaged. The new build replaces the three-extension combination with two cross-distribution products:

* `rice-dock@ib-hussain`: Ubuntu Dock/Dash-to-Dock v106 with one direct `media/logo.png` icon—no symbolic icon or CSS image underneath.
* `rice-top-bar@ib-hussain`: Hide Top Bar v126 plus explicit, reversible transparency.
* Both disable the old Arch icon patch, Ubuntu Dock, upstream Dash-to-Dock, and upstream Hide Top Bar to prevent conflicts.
* Lifecycle failures are written to the GNOME Shell journal.
* The password helper now includes an explicit backed-up PAM repair.
* Super+E/Super+I, wallpaper caching, strict verification, package coverage, and previous installer fixes remain included.

The dock is based on the official [Dash-to-Dock v106 release](https://github.com/micheleg/dash-to-dock/releases/tag/extensions.gnome.org-v106) and its [Ubuntu Dock branch](https://github.com/micheleg/dash-to-dock/tree/ubuntu-dock). The top-bar product uses [Hide Top Bar 126](https://gitlab.gnome.org/tuxor1337/hidetopbar/-/tags/extensions.gnome.org-126).

### Downloads

* [Complete UbuntuRicePack](sandbox:/workspace/scratch/dd34d5e3920e/UbuntuRicePack-GNOME50-engineered.zip)
* [Arch/Ubuntu extension-only bundle](sandbox:/workspace/scratch/dd34d5e3920e/Rice-Shell-Extensions-1.0.0.zip)
* [SHA256 checksums](sandbox:/workspace/scratch/dd34d5e3920e/SHA256SUMS.txt)

### Install on Ubuntu

```bash
unzip UbuntuRicePack-GNOME50-engineered.zip
cd ubuntuRicePack-engineered

bash tests/validate-rice-product.sh
./install-rice.sh --mode desktop
```

Log out and back in afterward. A reboot also works.

### Fix the password failure

Your failure happens during PAM’s current-password stage, before minimum length is evaluated. Ubuntu documents that root can bypass the old-password step, and `passwd` uses PAM for the change. [Ubuntu passwd documentation](https://manpages.ubuntu.com/manpages/noble/man1/passwd.1.html)

Run:

```bash
bash scripts/09-set-local-password.sh --repair-pam
```

This:

1. Backs up `/etc/pam.d/passwd` and `common-*`.
2. Regenerates Ubuntu’s packaged PAM stack using `pam-auth-update --force`.
3. Diagnoses account database, permissions, filesystem and PAM state.
4. Opens `sudo passwd ibrahim`, which should request only the new password twice.

`pam-auth-update --force` is intentionally opt-in because it replaces locally modified PAM configuration; Ubuntu documents that overwritten files are retained with a `.pam-old` suffix, and the script creates an additional timestamped backup. [pam-auth-update documentation](https://manpages.ubuntu.com/manpages/noble/man8/pam-auth-update.8.html)

A four-character password is substantially weaker, but privileged `passwd` can accept it unless `enforce_for_root` was explicitly configured. [pam_pwquality documentation](https://manpages.ubuntu.com/manpages/jammy/man8/pam_pwquality.8.html)

### Install only the extensions on Arch or Ubuntu

```bash
unzip Rice-Shell-Extensions-1.0.0.zip
cd rice-shell-extensions-1.0.0

bash tests/validate-extensions.sh
bash scripts/install-rice-shell-extensions.sh
```

Then log out and back in.

Verify both are active:

```bash
gnome-extensions info rice-dock@ib-hussain
gnome-extensions info rice-top-bar@ib-hussain
```

Inspect runtime messages:

```bash
journalctl --user -b -o cat |
  grep -E '\[(rice-dock|rice-top-bar)@ib-hussain\]'
```

All static, schema, JavaScript, import, XML, generated-script, mock lifecycle, archive-integrity, and checksum tests pass. The remaining validation boundary is loading them inside your actual GNOME 50 session after logout/login.




See [APPLY-INSTRUCTIONS.md](APPLY-INSTRUCTIONS.md) for operating instructions
and [ENGINEERING-AUDIT.md](ENGINEERING-AUDIT.md) for the supplied-extension
analysis, root causes, provenance, conflict policy, and validation record.



