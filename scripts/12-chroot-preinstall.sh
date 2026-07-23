#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"



while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-user)
            TARGET_USER="${2:?Missing value for --target-user}"
            shift 2
            ;;
        *)
            fail "Unknown argument for chroot preinstall: $1"
            ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    fail "12-chroot-preinstall.sh must run as root inside arch-chroot."
fi

TARGET_HOME="/home/$TARGET_USER"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    fail "Target user does not exist: $TARGET_USER"
fi

log "Starting archRicePack chroot-safe preinstall for user: $TARGET_USER"
log "Target home: $TARGET_HOME"

install_pacman_direct() {
    local pkg="$1"
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && return 0
    pacman -S --needed --noconfirm "$pkg" || warn "pacman failed for package: $pkg"
}

install_package_file_direct() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
        install_pacman_direct "$pkg"
    done < "$file"
}

run_as_user() {
    local command="$1"
    su - "$TARGET_USER" -c "$command"
}

ensure_yay_for_target_user() {
    if run_as_user "command -v yay >/dev/null 2>&1"; then
        log "yay already exists for $TARGET_USER."
        return 0
    fi

    log "Installing yay for $TARGET_USER."
    install_pacman_direct git
    install_pacman_direct base-devel

    rm -rf "$TARGET_HOME/.cache/rice-aur-builds/yay"
    
    sudo mkdir -p "$TARGET_HOME/.cache/rice-aur-builds/yay"
    sudo chown -R "$USER:$USER" "$TARGET_HOME/.cache/rice-aur-builds/"
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.cache/rice-aur-builds"
    run_as_user "git clone https://aur.archlinux.org/yay-bin.git ~/.cache/rice-aur-builds/yay"
    run_as_user "cd ~/.cache/rice-aur-builds/yay && chmod +x ~/.cache/rice-aur-builds/yay/* && MAKEFLAGS=\"-j4\" makepkg -si "

    run_as_user "git clone https://aur.archlinux.org/yay.git ~/.cache/rice-aur-builds/yay"
    run_as_user "cd ~/.cache/rice-aur-builds/yay && chmod +x ~/.cache/rice-aur-builds/yay/* && MAKEFLAGS=\"-j4\" makepkg -si --noconfirm"
}

install_aur_package_for_target_user() {
    local pkg="$1"
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && return 0

#    ensure_yay_for_target_user

    if pacman -Qq "$pkg" >/dev/null 2>&1; then
        log "AUR package already installed: $pkg"
    else
        run_as_user "yay -S --needed --noconfirm '$pkg'" || warn "yay failed for package: $pkg"
    fi
}

copy_dir_root_to_user() {
    local src="$1"
    local dest="$2"

    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "$src"/. "$dest"/
        chown -R "$TARGET_USER:$TARGET_USER" "$dest"
        log "Copied directory: $src -> $dest"
    else
        warn "Directory missing, skipped: $src"
    fi
}

copy_file_root_to_user() {
    local src="$1"
    local dest="$2"

    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        chown "$TARGET_USER:$TARGET_USER" "$dest"
        log "Copied file: $src -> $dest"
    else
        warn "File missing, skipped: $src"
    fi
}

log "Installing official repository packages."
install_package_file_direct "$REPO_ROOT/packages/rice-pacman-core.txt"

log "Installing AUR packages as $TARGET_USER."
if [[ -f "$REPO_ROOT/packages/rice-aur-core.txt" ]]; then
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
        install_aur_package_for_target_user "$pkg"
    done < "$REPO_ROOT/packages/rice-aur-core.txt"
fi

log "Restoring user-side files that do not require a GNOME DBus session."

install -d -o "$TARGET_USER" -g "$TARGET_USER" \
    "$TARGET_HOME/.config" \
    "$TARGET_HOME/.local/bin" \
    "$TARGET_HOME/.local/share/icons" \
    "$TARGET_HOME/.local/share/applications" \
    "$TARGET_HOME/.local/share/gnome-shell/extensions" \
    "$TARGET_HOME/.local/share/nautilus-python/extensions" \
    "$TARGET_HOME/.themes"

copy_dir_root_to_user "$REPO_ROOT/configs/themes"                           "$TARGET_HOME/.themes"
copy_dir_root_to_user "$REPO_ROOT/configs/gtk-3.0"                          "$TARGET_HOME/.config/gtk-3.0"
copy_dir_root_to_user "$REPO_ROOT/configs/gtk-4.0"                          "$TARGET_HOME/.config/gtk-4.0"
copy_dir_root_to_user "$REPO_ROOT/configs/fastfetch"                        "$TARGET_HOME/.config/fastfetch"
copy_dir_root_to_user "$REPO_ROOT/configs/local-bin"                        "$TARGET_HOME/.local/bin"
copy_dir_root_to_user "$REPO_ROOT/configs/nautilus-python"                  "$TARGET_HOME/.local/share/nautilus-python/extensions"
copy_dir_root_to_user "$REPO_ROOT/configs/extensions"     "$TARGET_HOME/.local/share/gnome-shell/extensions"


chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true

# everything under this is done
log "Installing GRUB/GDM assets that can be applied in chroot."

if [[ -f "$REPO_ROOT/assets/bg.png" ]]; then
    mkdir -p /boot/grub
    sudo cp "$REPO_ROOT/assets/bg.png" /boot/grub/bg.png
    chmod 644 /boot/grub/bg.png
    # if [[ -f /etc/default/grub ]]; then
    #     if grep -q '^#\?GRUB_BACKGROUND=' /etc/default/grub; then
    #         sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/bg.png"|' /etc/default/grub
    #     else
    #         echo 'GRUB_BACKGROUND="/boot/grub/bg.png"' >> /etc/default/grub
    #     fi
    #     grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
    # fi
    grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
fi

if [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
    mkdir -p /usr/share/backgrounds/rice /etc/dconf/db/gdm.d
    sudo cp "$REPO_ROOT/assets/ib.png" /usr/share/backgrounds/rice/ib.png
    chmod 644 /usr/share/backgrounds/rice/ib.png

    cat > /etc/dconf/db/gdm.d/90-rice-login-background <<'GDMBG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/rice/ib.png'
picture-uri-dark='file:///usr/share/backgrounds/rice/ib.png'
picture-options='zoom'

[org/gnome/login-screen]
logo='file:///usr/share/backgrounds/rice/ib.png'
GDMBG

    dconf update || warn "dconf update failed for GDM."
fi

log "Enabling system services for first boot."
systemctl enable NetworkManager.service || true
systemctl enable gdm.service || true
systemctl enable docker.service || true
systemctl enable ollama.service || true
systemctl set-default graphical.target || true

if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "$TARGET_USER" || true
fi

log "Creating first-login user-session autostart."

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.config/autostart" "$TARGET_HOME/.local/bin"

cat > "$TARGET_HOME/.local/bin/arch-rice-postlogin-runner" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG="$HOME/arch-rice-postlogin-$(date +%Y%m%d-%H%M%S).log"

{
    echo "[INFO] archRicePack post-login stage started."
    cd "$HOME/archRicePack"
    ./install-rice.sh --user-session
    echo "[INFO] archRicePack post-login stage complete."
} 2>&1 | tee -a "$LOG"

mkdir -p "$HOME/.config/autostart"
if [[ -f "$HOME/.config/autostart/arch-rice-postlogin.desktop" ]]; then
    mv "$HOME/.config/autostart/arch-rice-postlogin.desktop" "$HOME/.config/autostart/arch-rice-postlogin.desktop.done" || true
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "archRicePack" "Post-login rice stage completed. Reboot once if icons/cache look stale." || true
fi
RUNNER

chmod +x "$TARGET_HOME/.local/bin/arch-rice-postlogin-runner"

cat > "$TARGET_HOME/.config/autostart/arch-rice-postlogin.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=archRicePack Post-Login Apply
Comment=Apply GNOME user-session rice settings after first login
Exec=/home/ibrahim/.local/bin/arch-rice-postlogin-runner
X-GNOME-Autostart-enabled=true
Terminal=true
Hidden=false
DESKTOP

# Make Exec user-specific.
sed -i "s|/home/ibrahim|$TARGET_HOME|g" "$TARGET_HOME/.config/autostart/arch-rice-postlogin.desktop"

chown -R "$TARGET_USER:$TARGET_USER" \
    "$TARGET_HOME/.config/autostart" \
    "$TARGET_HOME/.local/bin/arch-rice-postlogin-runner"

log "Chroot preinstall complete."
log "Next: exit chroot, reboot, and log into GNOME as $TARGET_USER."
log "The user-session stage will run automatically once from autostart."
