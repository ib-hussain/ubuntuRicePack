#!/usr/bin/env bash
# Restore user-owned configuration without loading GNOME's dconf database.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_normal_user

INSTALL_MODE="${RICE_INSTALL_MODE:-desktop}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            INSTALL_MODE="${2:?Missing value for --mode}"
            shift 2
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

case "$INSTALL_MODE" in
    desktop | wsl) ;;
    *) fail "Unsupported restore mode: $INSTALL_MODE" ;;
esac

log "Restoring UbuntuRicePack user configuration ($INSTALL_MODE mode)."

for managed_path in \
    "$HOME/.bashrc" \
    "$HOME/.bash_profile" \
    "$HOME/.bash_logout" \
    "$HOME/.config/fastfetch"
do
    backup_path "$managed_path"
done

mkdir -p \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications" \
    "$HOME/.local/share/icons"

copy_dir_contents "$REPO_ROOT/configs/local-bin" "$HOME/.local/bin"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"

for shell_file in .bashrc .bash_profile .bash_logout; do
    if [[ -f "$REPO_ROOT/configs/$shell_file" ]]; then
        copy_file "$REPO_ROOT/configs/$shell_file" "$HOME/$shell_file" 0644
    fi
done

if [[ "${RESTORE_CLUSTER_WORK:-1}" == "1" &&
        -d "$REPO_ROOT/cluster-work" ]]; then
    copy_dir_contents "$REPO_ROOT/cluster-work" "$HOME/Downloads/cluster-work"
fi

if [[ "$INSTALL_MODE" == "desktop" ]]; then
    for managed_path in \
        "$HOME/.themes" \
        "$HOME/.config/gtk-3.0" \
        "$HOME/.config/gtk-4.0"
    do
        backup_path "$managed_path"
    done

    mkdir -p "$HOME/.themes" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    copy_dir_contents "$REPO_ROOT/configs/themes" "$HOME/.themes"
    copy_dir_contents "$REPO_ROOT/configs/gtk-3.0" "$HOME/.config/gtk-3.0"
    copy_dir_contents "$REPO_ROOT/configs/gtk-4.0" "$HOME/.config/gtk-4.0"

    if [[ -f "$REPO_ROOT/configs/.face" ]]; then
        backup_path "$HOME/.face"
        copy_file "$REPO_ROOT/configs/.face" "$HOME/.face" 0644
    elif [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
        backup_path "$HOME/.face"
        copy_file "$REPO_ROOT/assets/ib.png" "$HOME/.face" 0644
    fi
fi

if [[ -d "$HOME/.local/bin" ]]; then
    find "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod u+x {} +
fi

log "User configuration restore is complete."

