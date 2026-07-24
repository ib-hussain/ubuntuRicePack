#!/usr/bin/env bash
# Finalize terminal aliases, compatibility command names, fonts, and Fastfetch.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_normal_user

log "Finalizing the UbuntuRicePack terminal environment."

mkdir -p "$HOME/.local/bin" "$HOME/.config/fastfetch"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"

if [[ -f "$REPO_ROOT/configs/.bashrc" ]]; then
    bash -n "$REPO_ROOT/configs/.bashrc" ||
        fail "The repository's configs/.bashrc has a syntax error."
fi

if [[ -f "$HOME/.bashrc" ]]; then
    bash -n "$HOME/.bashrc" ||
        fail "The installed ~/.bashrc has a syntax error."
fi

create_compatibility_link() {
    local target_command="$1"
    local compatibility_name="$2"
    local target_path=""
    local link_path="$HOME/.local/bin/$compatibility_name"

    command -v "$compatibility_name" >/dev/null 2>&1 && return 0
    [[ ! -e "$link_path" && ! -L "$link_path" ]] || return 0

    target_path="$(command -v "$target_command" 2>/dev/null || true)"
    if [[ -n "$target_path" ]]; then
        ln -s "$target_path" "$link_path"
        log "Created compatibility command: $compatibility_name -> $target_path"
    fi
}

create_compatibility_link batcat bat
create_compatibility_link fdfind fd

if [[ ! -x "$HOME/.local/bin/ff-blue" ]] &&
        command -v fastfetch >/dev/null 2>&1; then
    tee "$HOME/.local/bin/ff-blue" >/dev/null <<'FASTFETCH_WRAPPER'
#!/usr/bin/env bash
exec fastfetch \
    --logo arch \
    --logo-color-1 blue \
    --logo-color-2 blue \
    --logo-color-3 blue \
    "$@"
FASTFETCH_WRAPPER
    chmod 0755 "$HOME/.local/bin/ff-blue"
fi

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
fi

for expected_command in fastfetch eza zoxide fzf rg; do
    command -v "$expected_command" >/dev/null 2>&1 ||
        warn "Optional terminal command is unavailable: $expected_command"
done

log "Terminal setup is complete. New shells will use the restored Bash configuration."

