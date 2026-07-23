#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Installing pacman packages."

while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    install_pacman_package "$pkg"
done < "$REPO_ROOT/packages/rice-pacman-core.txt"

log "Installing AUR packages."

while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    install_aur_package "$pkg"
done < "$REPO_ROOT/packages/rice-aur-core.txt"
