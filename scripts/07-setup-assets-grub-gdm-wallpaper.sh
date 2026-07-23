#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

###############################################################################
# 07-setup-assets-grub-gdm-wallpaper.sh
#
# Handles:
#   - GRUB background: assets/bg.png -> /boot/grub/bg.png
#   - GDM/login background: assets/ib.png -> /usr/share/backgrounds/rice/ib.png
#   - user face image: assets/ib.png -> ~/.face
#   - wallpaper import from assets/wallpapers/
#   - 5-second wallpaper rotation
#
# Wallpaper behaviour:
#   - DO NOT physically resize/crop images.
#   - DO NOT generate scaled images.
#   - Use GNOME picture-options='scaled'.
#   - This fits the whole image on screen while preserving aspect ratio.
#   - Empty space is black:
#       tall image  -> black bars left/right
#       wide image  -> black bars top/bottom
###############################################################################

log "Applying assets: GRUB background, GDM background, fit-to-screen wallpaper rotation."

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

has_user_session() {
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" && "${EUID}" -ne 0 ]]
}

detect_target_user() {
    if [[ -n "${TARGET_USER:-}" ]]; then
        printf '%s\n' "$TARGET_USER"
        return 0
    fi

    if [[ -n "${RICE_TARGET_USER:-}" ]]; then
        printf '%s\n' "$RICE_TARGET_USER"
        return 0
    fi

    if [[ "${EUID}" -ne 0 ]]; then
        id -un
        return 0
    fi

    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf '%s\n' "$SUDO_USER"
        return 0
    fi

    if getent passwd ibrahim >/dev/null 2>&1; then
        printf '%s\n' "ibrahim"
        return 0
    fi

    printf '%s\n' "root"
}

target_home_for_user() {
    local user="$1"
    local home_dir=""

    home_dir="$(getent passwd "$user" | awk -F: '{print $6}' || true)"

    if [[ -z "$home_dir" ]]; then
        if [[ "$user" == "root" ]]; then
            home_dir="/root"
        else
            home_dir="/home/$user"
        fi
    fi

    printf '%s\n' "$home_dir"
}

safe_chown_user() {
    local user="$1"
    local path="$2"

    if [[ "$user" != "root" && -e "$path" ]]; then
        run_root chown -R "$user:$user" "$path" || true
    fi
}

safe_gsettings() {
    if has_user_session && command -v gsettings >/dev/null 2>&1; then
        gsettings set "$@" || true
    fi
}

apply_fit_wallpaper_settings_now() {
    if ! has_user_session; then
        return 0
    fi

    log "Applying GNOME wallpaper fit mode: scaled with black background."

    safe_gsettings org.gnome.desktop.background picture-options scaled
    safe_gsettings org.gnome.desktop.background primary-color "#000000"
    safe_gsettings org.gnome.desktop.background secondary-color "#000000"
    safe_gsettings org.gnome.desktop.background color-shading-type solid

    safe_gsettings org.gnome.desktop.screensaver picture-options scaled
    safe_gsettings org.gnome.desktop.screensaver primary-color "#000000"
    safe_gsettings org.gnome.desktop.screensaver secondary-color "#000000"
    safe_gsettings org.gnome.desktop.screensaver color-shading-type solid
}

install_grub_background() {
    if [[ -f "$REPO_ROOT/assets/bg.png" ]]; then
        log "Installing GRUB background from assets/bg.png."

        run_root mkdir -p /boot/grub
        run_root cp "$REPO_ROOT/assets/bg.png" /boot/grub/bg.png
        run_root chmod 644 /boot/grub/bg.png

        if [[ -f /etc/default/grub ]]; then
            if command -v grub-mkconfig >/dev/null 2>&1; then
                run_root grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
            fi
        else
            warn "/etc/default/grub missing. Skipping GRUB config update."
        fi
    else
        warn "assets/bg.png missing. Skipping GRUB background."
    fi
}

install_gdm_background() {
    local target_user="$1"
    local target_home="$2"

    if [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
        log "Installing GDM/login background from assets/ib.png."

        run_root mkdir -p /usr/share/backgrounds/rice
        run_root cp -a "$REPO_ROOT/assets/ib.png" /usr/share/backgrounds/rice/ib.png
        run_root chmod 644 /usr/share/backgrounds/rice/ib.png

        if [[ -n "$target_home" && -d "$target_home" ]]; then
            cp -a "$REPO_ROOT/assets/ib.png" "$target_home/.face" || run_root cp -a "$REPO_ROOT/assets/ib.png" "$target_home/.face" || true
            chmod 644 "$target_home/.face" 2>/dev/null || true
            safe_chown_user "$target_user" "$target_home/.face"
            log "Installed user face image at $target_home/.face"

            mkdir -p /var/lib/AccountsService/icons/
            mkdir -p /var/lib/AccountsService/users/
            sudo cp -a "$REPO_ROOT/assets/ib.png" /var/lib/AccountsService/icons/ibrahim     || true
            # sudo cp -a "$REPO_ROOT/assets/ib.png" /var/lib/AccountsService/users/ibrahim     || true
            sudo cp -a "$REPO_ROOT/assets/ib.png" /var/lib/AccountsService/icons/ibrahim.png || true

        fi

        run_root mkdir -p /etc/dconf/db/gdm.d
        run_root tee /etc/dconf/db/gdm.d/90-rice-login-background >/dev/null <<'GDMBG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/rice/ib.png'
picture-uri-dark='file:///usr/share/backgrounds/rice/ib.png'
picture-options='scaled'
primary-color='#000000'
secondary-color='#000000'
color-shading-type='solid'

[org/gnome/login-screen]
logo='file:///usr/share/backgrounds/rice/ib.png'
GDMBG

        run_root dconf update || warn "GDM dconf update failed."
    else
        warn "assets/ib.png missing. Skipping GDM/login background."
    fi
}

install_wallpapers_raw_only() {
    local target_user="$1"
    local target_home="$2"

    local wall_src="$REPO_ROOT/assets/wallpapers"
    local wall_dest="$target_home/.local/share/backgrounds/rice/wallpapers"

    mkdir -p "$wall_dest"

    mapfile -t source_images < <(
        find "$wall_src" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            | sort
    )

    if [[ "${#source_images[@]}" -eq 0 ]]; then
        warn "No wallpaper images found in assets/wallpapers. Wallpaper rotation will not be changed."
        safe_chown_user "$target_user" "$wall_dest"
        return 0
    fi

    log "Installing ${#source_images[@]} wallpaper image(s) without resizing."

    rm -rf "$wall_dest"
    mkdir -p "$wall_dest"

    local img=""
    for img in "${source_images[@]}"; do
        cp -a "$img" "$wall_dest/"
    done

    safe_chown_user "$target_user" "$wall_dest"

    log "Wallpaper files installed:"
    find "$wall_dest" -maxdepth 1 -type f | sort | sed 's/^/[WALLPAPER] /' | tee -a "$LOG_FILE" || true
}

write_wallpaper_rotator() {
    local target_user="$1"
    local target_home="$2"

    local bin_dir="$target_home/.local/bin"
    local service_dir="$target_home/.config/systemd/user"
    local autostart_dir="$target_home/.config/autostart"

    mkdir -p "$bin_dir" "$service_dir" "$autostart_dir"

    cat > "$bin_dir/rice-wallpaper-rotator" <<'ROTATOR'
#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$HOME/.local/share/backgrounds/rice/wallpapers"
INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"

apply_fit_mode() {
    gsettings set org.gnome.desktop.background picture-options 'scaled' || true
    gsettings set org.gnome.desktop.background primary-color '#000000' || true
    gsettings set org.gnome.desktop.background secondary-color '#000000' || true
    gsettings set org.gnome.desktop.background color-shading-type 'solid' || true

    gsettings set org.gnome.desktop.screensaver picture-options 'scaled' || true
    gsettings set org.gnome.desktop.screensaver primary-color '#000000' || true
    gsettings set org.gnome.desktop.screensaver secondary-color '#000000' || true
    gsettings set org.gnome.desktop.screensaver color-shading-type 'solid' || true
}

while true; do
    mapfile -t files < <(
        find "$DIR" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            | sort
    )

    if [[ "${#files[@]}" -eq 0 ]]; then
        sleep "$INTERVAL"
        continue
    fi

    for img in "${files[@]}"; do
        uri="file://$img"

        apply_fit_mode

        gsettings set org.gnome.desktop.background picture-uri "$uri" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$uri" || true
        gsettings set org.gnome.desktop.screensaver picture-uri "$uri" || true

        sleep "$INTERVAL"
    done
done
ROTATOR

    chmod +x "$bin_dir/rice-wallpaper-rotator"

    cat > "$service_dir/rice-wallpaper-rotator.service" <<'SERVICE'
[Unit]
Description=Rice wallpaper rotator

[Service]
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
SERVICE

    cat > "$autostart_dir/rice-wallpaper-rotator.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Rice Wallpaper Rotator
Comment=Rotate archRicePack wallpapers every 5 seconds using fit-to-screen mode
Exec=$target_home/.local/bin/rice-wallpaper-rotator
X-GNOME-Autostart-enabled=true
Terminal=false
Hidden=false
DESKTOP

    safe_chown_user "$target_user" "$bin_dir/rice-wallpaper-rotator"
    safe_chown_user "$target_user" "$service_dir/rice-wallpaper-rotator.service"
    safe_chown_user "$target_user" "$autostart_dir/rice-wallpaper-rotator.desktop"

    if has_user_session; then
        log "Enabling wallpaper rotator as user systemd service."

        systemctl --user daemon-reload || true
        systemctl --user enable --now rice-wallpaper-rotator.service || warn "Could not enable wallpaper rotator user service."

        apply_fit_wallpaper_settings_now

        local first_wallpaper
        first_wallpaper="$(find "$target_home/.local/share/backgrounds/rice/wallpapers" -maxdepth 1 -type f | sort | head -n 1 || true)"

        if [[ -n "$first_wallpaper" ]]; then
            local uri="file://$first_wallpaper"
            safe_gsettings org.gnome.desktop.background picture-uri "$uri"
            safe_gsettings org.gnome.desktop.background picture-uri-dark "$uri"
            safe_gsettings org.gnome.desktop.screensaver picture-uri "$uri"
            log "Applied initial fit-to-screen wallpaper: $first_wallpaper"
        fi
    else
        warn "No active GNOME user session. Wallpaper rotator installed through autostart and will activate on first login."
    fi
}

main() {
    local target_user
    local target_home

    target_user="$(detect_target_user)"
    target_home="$(target_home_for_user "$target_user")"

    log "Target user: $target_user"
    log "Target home: $target_home"

    install_grub_background
    install_gdm_background "$target_user" "$target_home"
    install_wallpapers_raw_only "$target_user" "$target_home"
    write_wallpaper_rotator "$target_user" "$target_home"

    log "Asset, GDM, GRUB, and fit-to-screen wallpaper setup complete."
}

main "$@"