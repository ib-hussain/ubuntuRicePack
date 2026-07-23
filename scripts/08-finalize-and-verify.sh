#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Finalising installation."

gtk-update-icon-cache -f -t "$HOME/.local/share/icons/Rice-Papirus" >/dev/null 2>&1 || true

for uuid in \
    "user-theme@gnome-shell-extensions.gcampax.github.com" \
    "dash-to-dock@micxgx.gmail.com" \
    "hidetopbar@mathieu.bidon.ca" \
    "arch-dock-icon@ib-hussain"
do
    if gnome-extensions list | grep -qx "$uuid"; then
        gnome-extensions enable "$uuid" || true
    fi
done

if gnome-extensions list | grep -qx "dash-to-dock@micxgx.gmail.com"; then
    gnome-extensions disable "dash-to-dock@micxgx.gmail.com" >/dev/null 2>&1 || true
    sleep 1
    gnome-extensions enable "dash-to-dock@micxgx.gmail.com" >/dev/null 2>&1 || true
fi

nautilus -q >/dev/null 2>&1 || true

log "Verification summary:"
{
    echo "GTK=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo unavailable)"
    echo "Icons=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo unavailable)"
    echo "Shell=$(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)"
    echo "Buttons=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || echo unavailable)"
    echo "Overlay=$(gsettings get org.gnome.mutter overlay-key 2>/dev/null || echo unavailable)"
    echo "Overview=$(gsettings get org.gnome.shell.keybindings toggle-overview 2>/dev/null || echo unavailable)"
    echo "Apps=$(gsettings get org.gnome.shell.keybindings toggle-application-view 2>/dev/null || echo unavailable)"
    echo "Favourites=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo unavailable)"
    # echo "Power=$(powerprofilesctl get 2>/dev/null || echo unavailable)"
    echo
    echo "Dash-to-Dock:"
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ 2>/dev/null || true
    echo
    echo "Enabled extensions:"
    gnome-extensions list --enabled 2>/dev/null || true
} | tee -a "$LOG_FILE"

log "Install finished. Log out and back in. Reboot once if icon/theme cache looks stale."
