#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying final custom Show Applications dock icon."

EXT_UUID="arch-dock-icon@ib-hussain"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
ICON_THEME="$HOME/.local/share/icons/Rice-Papirus"

SRC=""

for f in \
    "$REPO_ROOT/assets/arch-icons/arch-logo.png" \
    "$REPO_ROOT/assets/arch-icons/arch-logo.webp" 
do
    if [[ -f "$f" ]]; then
        SRC="$f"
        break
    fi
done

if [[ -z "$SRC" ]]; then
    warn "No custom Arch icon source found. Skipping Show Applications icon patch."
    exit 0
fi

install_pacman_package imagemagick gtk3

mkdir -p "$ICON_THEME" "$EXT_DIR/icons"

WORK="$HOME/.cache/rice-showapps-png-fix"
rm -rf "$WORK"
mkdir -p "$WORK"

MASTER="$WORK/arch-logo.png"

log "Using source icon: $SRC"
# magick "$SRC" -background none -alpha on -resize 1024x1024 -gravity center -extent 1024x1024 "$MASTER"
cp "$REPO_ROOT/assets/arch-icons/arch-logo.png" "$MASTER"

log "Writing PNG directly into GNOME Shell extension."
# magick "$MASTER" -resize 512x512 "$EXT_DIR/icons/arch-logo.png"
cp "$REPO_ROOT/assets/arch-icons/arch-logo.png" "$EXT_DIR/icons/arch-logo.png"
# magick "$MASTER" -resize 512x512 "$EXT_DIR/arch-logo.png"
cp "$REPO_ROOT/assets/arch-icons/arch-logo.png" "$EXT_DIR/arch-logo.png"

cp -r "$REPO_ROOT/configs/extensions/arch-dock-icon@ib-hussain"/* "$EXT_DIR/"

# log "Writing icon-theme PNG fallbacks."

# ICON_NAMES=(
#     "applications-all"
#     "applications-all-symbolic"
#     "applications-system-symbolic"
#     "view-app-grid"
#     "view-app-grid-symbolic"
#     "start-here"
#     "start-here-symbolic"
#     "start-here-archlinux"
#     "distributor-logo-archlinux"
# )

# SIZES=(16 22 24 32 48 64 96 128 256 512)

# for size in "${SIZES[@]}"; do
#     for context in apps actions categories places panel symbolic/actions symbolic/categories symbolic/places; do
#         dir="$ICON_THEME/${size}x${size}/$context"
#         mkdir -p "$dir"

#         for name in "${ICON_NAMES[@]}"; do
#             magick "$MASTER" -resize "${size}x${size}" "$dir/$name.png"
#             rm -f "$dir/$name.svg"
#         done
#     done
# done

dconf_write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top true
gs_set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true
gs_set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
gs_set org.gnome.desktop.interface icon-theme "Rice-Papirus"

gtk-update-icon-cache -f -t "$ICON_THEME" >/dev/null 2>&1 || true

if gnome-extensions list | grep -qx "$EXT_UUID"; then
    gnome-extensions disable "$EXT_UUID" >/dev/null 2>&1 || true
    sleep 1
    gnome-extensions enable "$EXT_UUID" >/dev/null 2>&1 || true
else
    warn "$EXT_UUID installed but GNOME may index it after logout/login."
fi

if gnome-extensions list | grep -qx "dash-to-dock@micxgx.gmail.com"; then
    gnome-extensions disable dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 || true
    sleep 1
    gnome-extensions enable dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 || true
fi

log "Custom Show Applications dock icon patch complete."
log "If it does not appear immediately, log out/in or reboot once."