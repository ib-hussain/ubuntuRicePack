#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

source "$ROOT_DIR/scripts/00-common.sh"

MODE="normal"
TARGET_USER="${SUDO_USER:-${USER:-ibrahim}}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chroot)
            MODE="chroot"
            shift
            ;;
        --user-session|--postlogin|--post-login)
            MODE="user-session"
            shift
            ;;
        --target-user)
            TARGET_USER="${2:?Missing value for --target-user}"
            shift 2
            ;;
        --help|-h)
            cat <<EOF_HELP
archRicePack installer

Usage:
  ./install-rice.sh
      Run the full installer from inside a logged-in GNOME session.

  sudo ./install-rice.sh --chroot --target-user ibrahim
      Run the chroot-safe stage from arch-chroot.
      This installs/copies everything possible and creates a first-login
      autostart entry for GNOME user-session settings.

  ./install-rice.sh --user-session
      Run only the GNOME user-session stage.
      This is normally launched automatically on first GNOME login after chroot.

Environment:
  SKIP_LOCAL_AI=1       Skip Ollama/Open WebUI setup.
EOF_HELP
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

log "============================================================"
log "archRicePack installer started"
log "Mode: $MODE"
log "Repository: $ROOT_DIR"
log "Target user: $TARGET_USER"
log "Log file: $LOG_FILE"
log "============================================================"

case "$MODE" in
    chroot)
        if [[ "$EUID" -ne 0 ]]; then
            fail "Chroot mode must be run as root from arch-chroot."
        fi
        bash "$ROOT_DIR/scripts/12-chroot-preinstall.sh" --target-user "$TARGET_USER"
        ;;
    user-session)
        require_user_session
        bash "$ROOT_DIR/scripts/13-user-session-apply.sh"
        ;;
    normal)
        require_user_session
        STEPS=(
            "01-install-packages.sh"
            "02-restore-themes-and-configs.sh"
            "03-setup-terminal.sh"
            "04-setup-extensions.sh"
            "05-apply-gnome-settings.sh"
            "07-setup-assets-grub-gdm-wallpaper.sh"
            "08-finalize-and-verify.sh"
            "09-setup-vscode.sh"
            "10-setup-local-ai-ollama-openwebui.sh"
            "11-apply-custom-showapps-icon.sh"
            "05-apply-gnome-settings.sh"
            "14-system-stability.sh"
            "15-install-power-profiles.sh"
            "08-finalize-and-verify.sh"
        )

        for step in "${STEPS[@]}"; do
            if [[ "${SKIP_LOCAL_AI:-0}" == "1" && "$step" == "10-setup-local-ai-ollama-openwebui.sh" ]]; then
                warn "Skipping $step because SKIP_LOCAL_AI=1."
                continue
            fi

            log "Running $step"
            bash "$ROOT_DIR/scripts/$step"
        done
        ;;
esac

log "============================================================"
log "archRicePack installation stage complete"
log "============================================================"