#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Starting archRicePack GNOME user-session stage."

STEPS=(
    "02-restore-themes-and-configs.sh"
    "03-setup-terminal.sh"
    "04-setup-extensions.sh"
    "05-apply-gnome-settings.sh"
    "07-setup-assets-grub-gdm-wallpaper.sh"
    "08-finalize-and-verify.sh"
    "09-setup-vscode.sh"
    "10-setup-local-ai-ollama-openwebui.sh"
    "11-apply-custom-showapps-icon.sh"
    "08-finalize-and-verify.sh"
)

for step in "${STEPS[@]}"; do
    if [[ "${SKIP_LOCAL_AI:-0}" == "1" && "$step" == "10-setup-local-ai-ollama-openwebui.sh" ]]; then
        warn "Skipping $step because SKIP_LOCAL_AI=1."
        continue
    fi

    log "Running user-session step: $step"
    bash "$REPO_ROOT/scripts/$step"
done

if [[ -f "$HOME/.config/autostart/arch-rice-postlogin.desktop" ]]; then
    mv "$HOME/.config/autostart/arch-rice-postlogin.desktop" "$HOME/.config/autostart/arch-rice-postlogin.desktop.done" || true
fi

log "GNOME user-session stage complete."
log "Recommended: log out/in once, or reboot if icon/theme caches look stale."