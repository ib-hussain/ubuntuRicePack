# Restored UbuntuRicePack installer files

These are individual replacement files for the layout at commit `3640def`.
They retain the new Ubuntu numbering and restore the detailed behavior that was
lost in the compact rewrite.

## What is restored

- Explicit Ubuntu packages for ImageMagick, UnRAR, GNOME browser integration,
  GNOME Screenshot, sxhkd, and the practical Ubuntu VLC plugin set.
- Verified upstream Nerd Font downloads for JetBrains Mono, Noto, and Nerd
  Fonts Symbols Only.
- Full extension acquisition checks, metadata validation, safe extraction,
  enabled/disabled state handling, and extension inventory reports.
- GTK/Shell theme, icon theme, Ubuntu Dock, extension, wallpaper, VS Code,
  package, terminal, and final desktop reports.
- Google Chrome and VS Code signed vendor repositories.
- Runtime sparse-fetching of wallpapers from
  `ib-hussain/archRicePack/assets/wallpapers`.
- A no-Snap/no-Firefox policy and a separate optional local-AI installer.

## Intentional exclusions

- No GDM logo or GDM background customization. The finalizer removes only
  GDM override files managed by older UbuntuRicePack versions.
- No partitioning, `arch-chroot`, chroot-preinstall, or first-login chroot
  workflow.
- No separate `wsl-install.sh`; `install-rice.sh --mode wsl` is the WSL entry.
- Ollama/Open WebUI is never invoked by the main installer. Run stage 10 only
  when wanted.
- `scripts/12-install-power-profiles.sh` is not replaced by this set.

## Copy the files

From the directory containing this downloaded folder:

```bash
cd /mnt/d/Downloads/Repositories/ubuntuRicePack

cp -v /path/to/ubuntuRicePack-restored/install-rice.sh .
cp -v /path/to/ubuntuRicePack-restored/packages/*.txt packages/
cp -v /path/to/ubuntuRicePack-restored/configs/extensions/extension-list.txt \
  configs/extensions/
cp -v /path/to/ubuntuRicePack-restored/scripts/*.sh scripts/

chmod +x install-rice.sh scripts/*.sh
```

Do not remove your custom extension:

```text
configs/extensions/arch-dock-icon@ib-hussain/
```

It is the only extension source that remains repository-owned. All other
extension code is obtained from Ubuntu packages or GNOME Extensions.

## Validate before installation

```bash
bash -n install-rice.sh
for script in scripts/*.sh; do
  bash -n "$script"
done

bash scripts/04-setup-extensions.sh --help
bash scripts/apply-ubuntu-gnome-best-settings.sh --help
```

The GNOME settings dry run needs to be run in the Ubuntu GNOME VM after the
package and extension stages have installed their schemas:

```bash
bash scripts/05-apply-gnome-settings.sh --dry-run
```

## Run

Run as the normal desktop user from a terminal inside the logged-in GNOME
session:

```bash
./install-rice.sh --mode desktop
```

For WSL:

```bash
./install-rice.sh --mode wsl
```

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
```

The normal run records warnings and continues where a noncritical upstream
download or post-login GNOME state can be retried. `--strict` converts package,
external-installer, Nerd Font, GNOME, and final-audit mismatches into failures.

## Reports and backups

Detailed TSV/text reports are written to:

```text
~/.local/state/ubuntuRicePack/reports/
```

Logs and pre-change backups are written beneath:

```text
~/.local/state/ubuntuRicePack/logs/
~/.local/state/ubuntuRicePack/backups/
```

After desktop installation, log out and back in once so newly copied GNOME
Shell extensions enter the running Shell process.

## Optional local AI

This remains entirely independent:

```bash
bash scripts/10-setup-local-ai-ollama-openwebui.sh
```

It configures Ollama, pulls only its two configured models, installs Open WebUI,
and creates its desktop launcher.
