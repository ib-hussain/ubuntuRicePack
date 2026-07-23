#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

# log "Restoring themes, GTK config, icons, local binaries, and shell config."

# backup_path "$HOME/.themes"
# backup_path "$HOME/.config/gtk-3.0"
# backup_path "$HOME/.config/gtk-4.0"
# backup_path "$HOME/.local/share/icons"
# backup_path "$HOME/.bashrc"

mkdir -p "$HOME/.themes" "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/icons"

copy_dir_contents "$REPO_ROOT/configs/themes" "$HOME/.themes"
copy_dir_contents "$REPO_ROOT/configs/gtk-3.0" "$HOME/.config/gtk-3.0"
copy_dir_contents "$REPO_ROOT/cluster-work" "$HOME/Downloads/cluster-work"
copy_dir_contents "$REPO_ROOT/configs/gtk-4.0" "$HOME/.config/gtk-4.0"
copy_dir_contents "$REPO_ROOT/configs/local-bin" "$HOME/.local/bin"

chmod +x "$HOME/.local/bin/"* 2>/dev/null || true

if [[ -f "$REPO_ROOT/configs/.bashrc" ]]; then
    cp -a "$REPO_ROOT/configs/.bashrc" "$HOME/.bashrc"
    log "Restored .bashrc"
fi

if [[ -f "$REPO_ROOT/configs/.bash_profile" ]]; then
    cp -a "$REPO_ROOT/configs/.bash_profile" "$HOME/.bash_profile"
    log "Restored .bash_profile"
fi

if [[ ! -x "$HOME/.local/bin/ff-blue" ]]; then
    cat > "$HOME/.local/bin/ff-blue" <<'EOFF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOFF
    chmod +x "$HOME/.local/bin/ff-blue"
fi

gtk-update-icon-cache -f -t "$HOME/.local/share/icons/Rice-Papirus" >/dev/null 2>&1 || true

gs_set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue"
gs_set org.gnome.desktop.interface color-scheme "prefer-dark"
gs_set org.gnome.desktop.interface icon-theme "Rice-Papirus"
gs_set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"

if schema_exists org.gnome.shell.extensions.user-theme; then
    gs_set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue"
fi
