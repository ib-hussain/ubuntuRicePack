# MEMORY.md — ubuntuRicePack and archRicePack

## Durable identity

- Owner: Ibrahim Hussain.
- Ubuntu repository historically: `ib-hussain/ubuntuRicePack`.
- Source/migration project: `archRicePack`.
- Git defaults recorded in installer history: user `Ibrahim Hussain`, email `ibrahimbeaconarion@gmail.com`, default branch `main`, editor `nano`, `push.default simple`.

## Durable decisions

- Ubuntu rice is post-install only.
- No partitioning, formatting, or `arch-chroot` in the rice installer.
- No GDM logo/branding customisation in the approved Ubuntu migration.
- No Snap and no Firefox in the Ubuntu package plan.
- Ubuntu Dock on Ubuntu; Dash to Dock may remain an Arch implementation.
- Local AI is optional and independent.
- Preserve the rich GNOME/Bash/Fastfetch/VS Code/theme behaviour and detailed verification; do not aggressively shorten it.
- Downloads/assets should be cached and validated across reruns.
- Failures should be journal/logged and surfaced.
- Replacement-only ZIPs include only changed files while the full repository is tested.

## Historical GNOME environment

- Ubuntu GNOME 50.1.
- Arch GNOME 50.2.
- Later compatibility request: Ubuntu 25.04/GNOME 48 and Ubuntu 26.04/GNOME 50.
- Ubuntu Dock baseline historically used bottom position, 48 px maximum icon size, autohide, and all-windows intellihide; re-read current Dconf before applying.

## Historical repository areas

- autostart
- dconf
- extensions
- fastfetch
- gnome-shell
- gtk-3.0 / gtk-4.0
- local-bin
- nautilus-python
- power-menu
- themes
- vscode
- Bash/profile
- WSL and optional local AI

## Dock design memory — September 2026

- New visual reference: `dev+production-mockup.html`.
- Replace the old dock styling; do not keep two competing modes.
- Top panel is out of scope.
- Running indicator remains DOTS.
- Roundness is dynamic, historically derived from `dashMaxIconSize × dockRoundness`.
- `backdrop-filter` is unsupported in GNOME St; use translucent tint/border fallback.
- Dead PointerWatcher/Gaussian continuous magnification was replaced with per-icon enter/leave hover.
- Scale neighbourhood: `1.1, 1.2, 1.5, 1.2, 1.1`.
- Vertical translation neighbourhood: `0, -6, -10, -6, 0`.
- Hover spacing must be implemented with magnification; browser reference used 13 px side margins.
- Production surfaces include `_stylesheet.scss`, `stylesheet.css`, and `theming.js::_adjustTheme()` plus hover logic.

## Installer evidence

- Main orchestrator uses `run_step` and `run_root` with required-script checks.
- Logs and verification reports are written to named user-state paths.
- WSL configuration historically wrote `/etc/wsl.conf` with systemd and default user, optionally hostname, and a bounded hosts entry.
- After WSL changes, the user is instructed to run `wsl --shutdown` in PowerShell.
- Normal mode can continue on documented non-critical issues; `--strict` elevates package/external-installer/Nerd Font/GNOME/final-audit mismatches.

## Autoinstall snapshot — July 2026

- Storage and network were required to remain interactive.
- SSH server enabled.
- Root SSH disabled.
- Password login enabled for the approved scenario.
- First-login terminal/bootstrap remains visible and retryable.
- A historical pinned commit was `7e7269acecbda4545b1ff89864e6178475b28e12`; verify the intended current pin before generating a new installer.

## Historical failures/corrections

- `scripts/00-common.sh` `run_root()` required repair.
- `code .` returned immediately without error and required a real package/profile/session diagnosis.
- Dock continuous magnification logic silently failed and was replaced by discrete hover handling.
- Unsupported browser CSS blur needed a production fallback.
- Pipeline patterns such as `producer | grep -q` under `pipefail` were identified as false-failure risks.

## Status interpretation

Historical “passed” claims may cover parsing, schemas, JavaScript, CSS/Sass, installer tests, and ZIP extraction while leaving actual GNOME-session behaviour untested. Always state that boundary.
