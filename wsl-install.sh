#!/bin/bash
# ==========================================================
# wsl-install.sh — entry point, repo root
#
# Root-phase provisioning for a fresh Arch WSL instance:
# timezone, locale, hostname, wsl.conf (systemd + default
# user), user creation, pyenv/Python. Then hands off to the
# numbered scripts/ under the target user via `su`, since
# those use `sudo` internally and expect a normal user shell.
#
# Run as root, from the repo root, right after first launch:
#   cd /path/to/archRicePack
#   ./wsl-install.sh
# ==========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
LOG_FILE="$REPO_ROOT/install.log"

USER_NAME="ibrahim"
HOST_NAME="IbLaptop"
TIMEZONE="Asia/Karachi"
LOCALE="en_US.UTF-8"
PYTHON_VERSION="3.12.7"

log()  { echo "[INFO] $*"  | tee -a "$LOG_FILE"; }
warn() { echo "[WARN] $*"  | tee -a "$LOG_FILE"; }
fail() { echo "[ERROR] $*" | tee -a "$LOG_FILE"; exit 1; }

[[ $EUID -eq 0 ]] || fail "Run this as root (fresh Arch WSL instances log in as root by default)."

# ----------------------------------------------------------
# Timezone & clock
# ----------------------------------------------------------
log "Setting timezone to ${TIMEZONE}"
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc 2>/dev/null || warn "hwclock failed (expected under WSL — the Windows host clock is authoritative)"

# ----------------------------------------------------------
# Locale
# ----------------------------------------------------------
log "Generating locale ${LOCALE}"
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# ----------------------------------------------------------
# Hostname
# ----------------------------------------------------------
log "Setting hostname to ${HOST_NAME}"
echo "$HOST_NAME" > /etc/hostname
grep -q "127.0.1.1" /etc/hosts || cat >> /etc/hosts <<EOF
127.0.1.1   ${HOST_NAME}.localdomain ${HOST_NAME}
EOF

# ----------------------------------------------------------
# WSL-specific config: systemd + default user.
# Needs `wsl --shutdown` (from PowerShell) + relaunch to
# actually take effect.
# ----------------------------------------------------------
log "Writing /etc/wsl.conf (systemd + default user)"
cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[user]
default=${USER_NAME}
EOF

# ----------------------------------------------------------
# Essential system tools
# ----------------------------------------------------------
log "Syncing repos and installing sudo, nano, git, base-devel"
pacman -Syu --needed --noconfirm sudo nano git base-devel

# ----------------------------------------------------------
# User setup
# ----------------------------------------------------------
if ! id "$USER_NAME" &>/dev/null; then
    log "Creating user ${USER_NAME}"
    useradd -m -G wheel "$USER_NAME"
    echo "Set password for ${USER_NAME}:"
    passwd "$USER_NAME"
else
    log "User ${USER_NAME} already exists, skipping useradd"
fi

log "Granting passwordless sudo to ${USER_NAME}"
cat > "/etc/sudoers.d/${USER_NAME}" <<EOF
${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/${USER_NAME}"

# ----------------------------------------------------------
# pyenv + Python — built AS the target user, never as root
# ----------------------------------------------------------
log "Building Python ${PYTHON_VERSION} via pyenv as ${USER_NAME}"
pacman -S --needed --noconfirm pyenv openssl zlib xz bzip2 libffi readline sqlite tk ncurses curl
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" PATH=\"\$HOME/.pyenv/bin:\$PATH\" pyenv install -s ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" PATH=\"\$HOME/.pyenv/bin:\$PATH\" pyenv global ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" PATH=\"\$HOME/.pyenv/bin:\$PATH\" pyenv rehash"
PYVER_CHECK=$(su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" PATH=\"\$HOME/.pyenv/bin:\$PATH\" pyenv exec python --version")
log "pyenv sanity check: ${PYVER_CHECK}"

# ----------------------------------------------------------
# Hand off to user-phase script (they use sudo internally,
# so they run as ibrahim, not root)
# ----------------------------------------------------------
log "Running scripts/06-wsl.sh"
su - "$USER_NAME" -c "REPO_ROOT='$REPO_ROOT' bash '$REPO_ROOT/scripts/06-wsl.sh'"


log ""
log ""
log "Base provisioning complete. Restart later."
log ""
log ""
log "Next steps (from PowerShell, not inside WSL):"
log "  wsl --shutdown"
log "  wsl -d archlinux         # should now log in as ${USER_NAME}, not root"
log "  whoami                   # confirm it prints '${USER_NAME}'"
log ""
log "ONLY after that restart, with systemd confirmed active (systemctl status),"
log "run this as ${USER_NAME} — it needs a live systemd to talk to:"
log "  bash scripts/10-setup-local-ai-ollama-openwebui.sh"