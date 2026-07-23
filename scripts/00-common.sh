#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$HOME/.local/state/arch-rice-pack"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/install-rice-$(date +%Y%m%d-%H%M%S).log}"
TARGET_USER="ibrahim"
# USER="ibrahim"

log() {
    echo "[INFO] $*" | tee -a "$LOG_FILE"
}

warn() {
    echo "[WARN] $*" | tee -a "$LOG_FILE"
}

fail() {
    echo "[ERROR] $*" | tee -a "$LOG_FILE"
    exit 1
}

require_user_session() {
    if [[ "$EUID" -eq 0 ]]; then
        fail "Do not run as root. Run as your normal desktop user."
    fi

    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
        fail "GNOME session variables missing. Log into GNOME and run from GNOME Terminal."
    fi
}

schema_exists() {
    gsettings list-schemas | grep -qx "$1"
}

schema_key_exists() {
    local schema="$1"
    local key="$2"
    schema_exists "$schema" || return 1
    gsettings list-keys "$schema" 2>/dev/null | grep -qx "$key"
}

gs_set() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if schema_key_exists "$schema" "$key"; then
        gsettings set "$schema" "$key" "$value" 2>>"$LOG_FILE" && log "gsettings set $schema $key $value" || warn "Could not set $schema $key"
    else
        warn "Missing gsettings key: $schema $key"
    fi
}

dconf_write() {
    local path="$1"
    local value="$2"
    dconf write "$path" "$value" 2>>"$LOG_FILE" && log "dconf write $path $value" || warn "Could not write $path"
}

backup_path() {
    local path="$1"
    local backup_root="$HOME/rice-install-backups/$(date +%Y%m%d-%H%M%S)"

    if [[ -e "$path" || -L "$path" ]]; then
        mkdir -p "$backup_root/$(dirname "${path#$HOME/}")"
        cp "$path" "$backup_root/${path#$HOME/}" 2>/dev/null || true
        log "Backed up $path to $backup_root"
    fi
}

copy_dir_contents() {
    local src="$1"
    local dest="$2"

    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "$src"/. "$dest"/
        log "Copied $src -> $dest"
    else
        warn "Directory missing, skipped: $src"
    fi
}

copy_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        log "Copied $src -> $dest"
    else
        warn "File missing, skipped: $src"
    fi
}

detect_command() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done
    return 1
}

install_pacman_package() {
    local pkg="$1"
    [[ -n "$pkg" ]] || return 0
    sudo pacman -S --needed --noconfirm "$pkg" || warn "pacman failed for package: $pkg"
}

ensure_yay() {
    if command -v yay >/dev/null 2>&1; then
        log "yay already installed."
        return 0
    fi
    sudo chown -R "$USER:$USER" "/home/$USER"

    log "Installing yay from AUR."
    sudo pacman -S --needed --noconfirm git base-devel
    local build_dir="$HOME/.cache/rice-aur-builds/yay"
    rm -rf "$build_dir"
    sudo mkdir -p "$(dirname "$build_dir")"
    sudo chown -R "$USER:$USER" "$(dirname "$build_dir")"
    git clone https://aur.archlinux.org/yay-bin.git "$build_dir"
    cd "$build_dir" 
    (chown -R "$USER:$USER" "$build_dir" && MAKEFLAGS=\"-j4\" makepkg -si  --noconfirm)
}

install_aur_package() {
    local pkg="$1"
    [[ -n "$pkg" ]] || return 0

    ensure_yay

    if pacman -Qq "$pkg" >/dev/null 2>&1; then
        log "AUR package already installed: $pkg"
    else
        yay -S --needed --noconfirm "$pkg" || warn "yay failed for package: $pkg"
    fi
}
