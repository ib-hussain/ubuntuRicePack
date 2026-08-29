### screen freeze issues after full installation

### Line 170      [scripts/00-common.sh](scripts/00-common.sh)
Adding component(s) 'restricted' to all repositories.
2026-08-25 00:37:16 [INFO] Enabled Ubuntu repository component: restricted
2026-08-25 00:37:16 [INFO] Refreshing APT package metadata.
2026-08-25 00:37:18 [INFO] Enforcing the repository's no-Snap/no-Firefox policy.
2026-08-25 00:37:37 [WARN] Command failed with status 100 at line 170: command sudo -- "$@" 
2026-08-25 00:37:37 [WARN] Command failed with status 100 at line 270: bash "$script_path" "$@"

Fixes:
- Run again
- Add `    return 0` at line 70 [scripts/01-install-packages.sh](scripts/01-install-packages.sh) and run again
- Comment out Line 116 [scripts/01-install-packages.sh](scripts/01-install-packages.sh) and run again

### Line 185-189  [scripts/03-setup-terminal.sh](scripts/03-setup-terminal.sh)
2026-08-25 01:48:39 [INFO] Copied directory contents: /home/ibrahim/ubuntuRicePack/configs/fastfetch -> /home/ibrahim/.config/fastfetch
2026-08-25 01:48:39 [INFO] Copied file: /home/ibrahim/ubuntuRicePack/configs/local-bin/ff-blue -> /home/ibrahim/.local/bin/ff-blue
fastfetch 2.57.1 (x86_64)
2026-08-25 01:48:39 [INFO] Downloading the official Nerd Fonts SHA-256 manifest.
2026-08-25 01:48:40 [WARN] Command failed with status 1 at line 189: find "$destination" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -quit 2> /dev/null
2026-08-25 01:48:40 [WARN] Command failed with status 1 at line 189: font_file="$(find "$destination" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -quit 2> /dev/null)"
2026-08-25 01:48:40 [WARN] Command failed with status 1 at line 270: bash "$script_path" "$@"

Fixes:
- Comment out Line 326 [scripts/03-setup-terminal.sh](scripts/03-setup-terminal.sh)

### Line 920      [scripts/08-finalize-desktop.sh](scripts/08-finalize-desktop.sh)
2026-08-25 02:22:44 [ERROR] Final verification found 1 failure(s).
2026-08-25 02:22:44 [WARN] Command failed with status 1 at line 270: bash "$script_path" "$@"

Fixes:
- Hopefullly this will not happen because it is solved at Line 452 [scripts/08-finalize-desktop.sh](scripts/08-finalize-desktop.sh)
