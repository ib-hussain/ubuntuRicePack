# UbuntuRicePack refactor

Copy each supplied file to the matching path in the repository, then remove the
superseded files:

```bash
git rm -f \
  wsl-install.sh \
  installation/basic-install.sh \
  scripts/06-wsl.sh \
  scripts/07-setup-assets-grub-gdm-wallpaper.sh \
  scripts/08-finalize-and-verify.sh \
  scripts/11-apply-custom-icon.sh \
  scripts/12-chroot-preinstall.sh \
  scripts/13-user-session-apply.sh \
  scripts/15-install-power-profiles.sh
```

If any listed path was already removed, omit it from the command. The new
replacement names are:

- `scripts/07-setup-assets-grub-wallpapers.sh`
- `scripts/11-finalize-desktop.sh`

Make the entry point and scripts executable:

```bash
chmod +x install-rice.sh scripts/*.sh
```

Validate all shell files:

```bash
for file in install-rice.sh scripts/*.sh; do
    bash -n "$file" || exit 1
done
```

Run the complete Ubuntu GNOME or dual-boot configuration from a logged-in GNOME
terminal:

```bash
./install-rice.sh
```

On Ubuntu WSL, the same entry point detects WSL:

```bash
./install-rice.sh
```

If `/etc/wsl.conf` changed, run `wsl --shutdown` from PowerShell before using
system services.

Local AI is intentionally excluded from the main installation. Install it only
when wanted:

```bash
bash scripts/10-setup-local-ai-ollama-openwebui.sh
```

That optional script installs only `gemma3:1b` and `deepseek-r1`, configures
Ollama and Open WebUI, preserves Open WebUI data across container recreation,
and creates the Open WebUI launcher.

The new asset script contains no GDM logo or GDM background configuration.
Finalization also removes the exact GDM dconf files created by earlier
UbuntuRicePack revisions.
