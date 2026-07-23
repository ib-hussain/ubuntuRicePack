#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Restoring Fastfetch and terminal toolkit."

mkdir -p "$HOME/.config/fastfetch" "$HOME/.local/bin"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"

cat "$REPO_ROOT/configs/local-bin/ff-blue" > "$HOME/.local/bin/ff-blue" 
chmod +x "$HOME/.local/bin/ff-blue"

touch "$HOME/.bashrc"

cat "$REPO_ROOT/configs/.bashrc" >> "$HOME/.bashrc" 

bash -n "$HOME/.bashrc"
