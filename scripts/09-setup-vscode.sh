#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Setting up Nautilus Open with Code."

mkdir -p "$HOME/.local/share/nautilus-python/extensions"
if [[ -d "$REPO_ROOT/configs/nautilus-python" ]]; then
    copy_dir_contents "$REPO_ROOT/configs/nautilus-python" "$HOME/.local/share/nautilus-python/extensions"
fi
nautilus -q >/dev/null 2>&1 || true

log "Setting up Visual Studio Code from archRicePack assets."

install_aur_package visual-studio-code-bin

VSCODE_ASSET_DIR="$REPO_ROOT/configs/vscode"
VSCODE_USER_SRC="$VSCODE_ASSET_DIR/User"
VSCODE_EXT_SRC="$VSCODE_ASSET_DIR/extensions"

VSCODE_USER_DEST="$HOME/.config/Code/User"
VSCODE_EXT_DEST="$HOME/.vscode/extensions"

log "Replacing VS Code User config."
if [[ -d "$VSCODE_USER_SRC" ]]; then
    # backup_path "$VSCODE_USER_DEST"
    mkdir -p "$VSCODE_USER_DEST"
    cp -r "$VSCODE_USER_SRC"/. "$VSCODE_USER_DEST"/
else
    warn "VS Code User config asset missing: $VSCODE_USER_SRC"
fi

log "Replacing VS Code extensions folder."
if [[ -d "$VSCODE_EXT_SRC" ]]; then
    # backup_path "$VSCODE_EXT_DEST"
    mkdir -p "$VSCODE_EXT_DEST"
    cp -r "$VSCODE_EXT_SRC"/. "$VSCODE_EXT_DEST"/
else
    warn "VS Code extensions asset missing: $VSCODE_EXT_SRC"
fi

if command -v code >/dev/null 2>&1; then
    code --version | head -n 1 | tee -a "$LOG_FILE" || true
else
    warn "code command not found after visual-studio-code-bin install."
fi

log "VS Code setup complete."
