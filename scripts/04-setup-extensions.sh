#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Restoring GNOME Shell extensions."

mkdir -p "$HOME/.local/share/extensions/extensions"
copy_dir_contents "$REPO_ROOT/configs/extensions" "$HOME/.local/share/extensions/extensions"

for ext in "$HOME/.local/share/extensions/extensions/"*; do
    [[ -d "$ext/schemas" ]] || continue
    glib-compile-schemas "$ext/schemas" || true
done

mkdir -p "$HOME/.local/share/gnome-shell/extensions"
copy_dir_contents "$REPO_ROOT/configs/extensions" "$HOME/.local/share/gnome-shell/extensions"
for ext in "$HOME/.local/share/gnome-shell/extensions/"*; do
    [[ -d "$ext/schemas" ]] || continue
    glib-compile-schemas "$ext/schemas" || true
done

for uuid in \
    "arch-dock-icon@ib-hussain" \
    "dash-to-dock@micxgx.gmail.com" \
    "hidetopbar@mathieu.bidon.ca" \
    "launch-new-instance@gnome-shell-extensions.gcampax.github.com" \
    "places-menu@gnome-shell-extensions.gcampax.github.com" \
    "start-overlay-in-application-view@Hex_cz" \
    "system-monitor@gnome-shell-extensions.gcampax.github.com" \
    "user-theme@gnome-shell-extensions.gcampax.github.com" \
do
    if gnome-extensions list | grep -qx "$uuid"; then
        gnome-extensions enable "$uuid" || warn "Could not enable extension: $uuid"
    else
        warn "Extension not indexed yet, may appear after logout/login: $uuid"
    fi
done
