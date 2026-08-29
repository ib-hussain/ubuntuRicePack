#!/usr/bin/env bash
# Install Ibrahim's custom five-mode power profile system.
#
# This script is intentionally independent and can be run on a new Ubuntu
# installation after cloning the ubuntuRicePack repository.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
POWER_MENU_SRC="$REPO_ROOT/configs/power-menu"

# Minimal logging functions (do not depend on 00-common.sh)
LOG_FILE="${LOG_FILE:-$HOME/.local/state/ubuntuRicePack/logs/install-power-profiles.log}"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    printf '%s [INFO] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

warn() {
    printf '%s [WARN] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2
}

fail() {
    printf '%s [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2
    exit 1
}

# Check we are running as a normal user, not root
if [[ $EUID -eq 0 ]]; then
    fail "Run this script as your normal user, without sudo."
fi

# Check repository path
[[ -f "$POWER_MENU_SRC/ib-power-mode" ]] ||
    fail "Missing power-mode source file: $POWER_MENU_SRC/ib-power-mode"

log "Installing power profile system from $POWER_MENU_SRC"

# ----------------------------------------------------------------------
# 1. Install required packages
# ----------------------------------------------------------------------
log "Installing required packages (linux-tools, brightnessctl, hdparm, util-linux)."
sudo apt-get update
sudo apt-get install -y \
    linux-tools-common \
    linux-tools-"$(uname -r)" \
    brightnessctl \
    hdparm \
    util-linux

# ----------------------------------------------------------------------
# 2. Install ib-power-mode to /usr/local/bin (root-owned)
# ----------------------------------------------------------------------
log "Installing ib-power-mode to /usr/local/bin"
sudo install -m 0755 "$POWER_MENU_SRC/ib-power-mode" /usr/local/bin/ib-power-mode

# ----------------------------------------------------------------------
# 3. Install user scripts and desktop entry
# ----------------------------------------------------------------------
USER_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
LOG_DIR="$HOME/.local/state/ubuntuRicePack/logs"

mkdir -p "$USER_BIN" "$APPS_DIR" "$LOG_DIR"

log "Installing ib-power-menu and launcher to $USER_BIN"
install -m 0755 "$POWER_MENU_SRC/ib-power-menu" "$USER_BIN/ib-power-menu"
install -m 0755 "$POWER_MENU_SRC/ib-power-menu-launcher" "$USER_BIN/ib-power-menu-launcher"

log "Installing desktop entry to $APPS_DIR"
install -m 0644 "$POWER_MENU_SRC/ib-power-menu.desktop" "$APPS_DIR/ib-power-menu.desktop"

# ----------------------------------------------------------------------
# 4. Set up logging directory and file
# ----------------------------------------------------------------------
touch "$LOG_DIR/power-profiles.log"
chmod 644 "$LOG_DIR/power-profiles.log"

# ----------------------------------------------------------------------
# 5. Desktop integration (GNOME)
# ----------------------------------------------------------------------
if command -v gio >/dev/null 2>&1 && command -v update-desktop-database >/dev/null 2>&1; then
    log "Updating desktop database and trusting launcher"
    update-desktop-database "$APPS_DIR"
    # Also copy to Desktop if it exists
    if [[ -d "$HOME/Desktop" ]]; then
        cp "$APPS_DIR/ib-power-menu.desktop" "$HOME/Desktop/"
        chmod +x "$HOME/Desktop/ib-power-menu.desktop"
        gio set "$HOME/Desktop/ib-power-menu.desktop" metadata::trusted true 2>/dev/null || true
    fi
else
    warn "gio or update-desktop-database not found; desktop integration skipped."
fi

# ----------------------------------------------------------------------
# 6. Optional sudoers rule for passwordless ib-power-mode
# ----------------------------------------------------------------------
read -r -p "Do you want to enable passwordless sudo for ib-power-mode? (y/N) " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    SUDOERS_TMP="$(mktemp)"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/ib-power-mode" > "$SUDOERS_TMP"
    sudo install -m 0440 "$SUDOERS_TMP" "/etc/sudoers.d/ib-power-mode"
    rm -f "$SUDOERS_TMP"
    log "Passwordless sudo for ib-power-mode enabled."
else
    log "Passwordless sudo not enabled; you will be prompted for password when switching modes."
fi

# ----------------------------------------------------------------------
# 7. Summary
# ----------------------------------------------------------------------
log "Power profile installation complete."
log "Usage:"
log "  - Run 'ib-power-menu' to interactively switch profiles."
log "  - Or use 'sudo ib-power-mode <mode>' directly."
log "Modes: ultrasaver | saver | balanced | performance | maximum"
log "Logs are written to: $LOG_DIR/power-profiles.log"
log "A desktop launcher 'Power Mode Switcher' has been installed."
