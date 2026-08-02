#!/usr/bin/env bash
# Unified UbuntuRicePack entry point for an installed Ubuntu GNOME system or
# Ubuntu on WSL. It is a post-install configurator, not an operating-system
# partitioner.

set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$ROOT_DIR"

usage() {
    cat <<'USAGE'
ubuntuRicePack installer

Run this after Ubuntu itself is installed:
  bash ./install-rice.sh

Supported Ubuntu desktop profiles:
  Ubuntu 25.04 (Plucky, GNOME 48; archived/EOL compatibility)
  Ubuntu 26.04 (Resolute, GNOME 50)

Modes:
  -m, --mode MODE    auto, desktop, normal, dual-boot, or wsl

System options:
  -H, --host NAME      Set the hostname (default: ibLaptop)
  -K, --keep-host      Leave the existing hostname unchanged
  -t, --tz ZONE        Set timezone (default: Asia/Karachi)
  -l, --locale LOCALE  Set locale (default: en_US.UTF-8)
  -p, --python VER     pyenv Python version (default: 3.12.7)
  -r, --repair-pass    Back up and regenerate Ubuntu's packaged PAM stack,
                       then run the password workflow
  -s, --strict         Treat optional download and verification faults as fatal
  -h, --help           Show this help

Important:
  - Run as the normal user, not with sudo.
  - Desktop mode must run from a terminal inside a logged-in GNOME session.
  - This does not repartition disks or install Ubuntu itself.
  - Local AI is optional and separate:
      bash scripts/10-setup-local-ai-ollama-openwebui.sh
USAGE
}

# Help must work without creating logs, detecting a target user, or asking for
# sudo. This is useful from recovery shells and when reviewing the USB media.
for argument in "$@"; do
    case "$argument" in
        --help | -h)
            usage
            exit 0
            ;;
    esac
done
unset argument

# shellcheck source=scripts/00-common.sh
source "$ROOT_DIR/scripts/00-common.sh"
# Give every child stage one run identifier, log, backup tree, and report set.
export RICE_RUN_ID="$RUN_ID"

MODE="${RICE_INSTALL_MODE:-auto}"
HOST_NAME="${RICE_HOSTNAME:-ibLaptop}"
TIMEZONE="${RICE_TIMEZONE:-Asia/Karachi}"
LOCALE_NAME="${RICE_LOCALE:-en_US.UTF-8}"
PYTHON_VERSION="${RICE_PYTHON_VERSION:-3.12.7}"
PASSWORDLESS_SUDO="${RICE_PASSWORDLESS_SUDO:-1}"
CONFIGURE_HOSTNAME="${RICE_CONFIGURE_HOSTNAME:-1}"
INSTALL_PYENV="${RICE_INSTALL_PYENV:-1}"
SET_SHORT_PASSWORD="${RICE_SET_SHORT_PASSWORD:-${RICE_ALLOW_SHORT_PASSWORDS:-0}}"
REPAIR_PASSWORD_STACK="${RICE_REPAIR_PASSWORD_STACK:-0}"
STRICT_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m | --mode)
            MODE="${2:?Missing value for --mode}"
            shift 2
            ;;
        -H | --host | --hostname)
            HOST_NAME="${2:?Missing value for --host}"
            CONFIGURE_HOSTNAME=1
            shift 2
            ;;
        -K | --keep-host | --keep-hostname)
            CONFIGURE_HOSTNAME=0
            shift
            ;;
        -t | --tz | --timezone)
            TIMEZONE="${2:?Missing value for --tz}"
            shift 2
            ;;
        -l | --locale)
            LOCALE_NAME="${2:?Missing value for --locale}"
            shift 2
            ;;
        -p | --python | --python-version)
            PYTHON_VERSION="${2:?Missing value for --python}"
            shift 2
            ;;
        -r | --repair-pass | --repair-password-stack)
            REPAIR_PASSWORD_STACK=1
            SET_SHORT_PASSWORD=1
            shift
            ;;
        -s | --strict)
            STRICT_MODE=1
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

case "$MODE" in
    auto)
        if is_wsl; then
            MODE="wsl"
        else
            MODE="desktop"
        fi
        ;;
    normal | dual-boot)
        MODE="desktop"
        ;;
    desktop | wsl) ;;
    *) fail "Unsupported mode: $MODE" ;;
esac

export RICE_INSTALL_MODE="$MODE"
export RICE_PYTHON_VERSION="$PYTHON_VERSION"

# Ventoy is unrelated to configuring an installed Ubuntu desktop and is off
# unless an advanced user explicitly opts in through the environment.
export INSTALL_VENTOY="${INSTALL_VENTOY:-0}"
if [[ "$STRICT_MODE" == "1" ]]; then
    export STRICT_PACKAGES=1
    export STRICT_EXTERNALS=1
    export STRICT_NERD_FONTS=1
    export STRICT_GNOME_VERIFY=1
    export STRICT_FINAL_VERIFY=1
    export STRICT_VSCODE_EXTENSIONS=1
fi

require_normal_user
require_ubuntu

if [[ "$MODE" == "desktop" ]]; then
    require_gnome_session
fi

[[ "$HOST_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] ||
    fail "Invalid hostname: $HOST_NAME"
[[ -e "/usr/share/zoneinfo/$TIMEZONE" ]] ||
    fail "Unknown timezone: $TIMEZONE"

sudo -v

configure_passwordless_sudo() {
    [[ "$PASSWORDLESS_SUDO" == "1" ]] || return 0

    local sudoers_file="/etc/sudoers.d/$USER"
    local temporary_file=""
    temporary_file="$(mktemp "${TMPDIR:-/tmp}/sudoers.XXXXXX")"

    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$USER" >"$temporary_file"
    run_root install -m0440 "$temporary_file" "$sudoers_file"
    rm -f -- "$temporary_file"

    if ! run_root visudo -cf "$sudoers_file" >/dev/null; then
        run_root rm -f -- "$sudoers_file"
        fail "The generated sudoers entry did not validate."
    fi
    log "Configured validated passwordless sudo for $USER."
}

configure_locale_timezone() {
    log "Configuring timezone and locale."
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y locales

    if is_systemd_running; then
        run_root timedatectl set-timezone "$TIMEZONE"
    else
        run_root ln -sfn "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    fi

    run_root locale-gen "$LOCALE_NAME"
    run_root update-locale "LANG=$LOCALE_NAME"
}

configure_hostname_and_hosts() {
    [[ "$CONFIGURE_HOSTNAME" == "1" ]] || return 0
    log "Setting hostname to $HOST_NAME."

    if is_systemd_running; then
        run_root hostnamectl set-hostname "$HOST_NAME"
    else
        printf '%s\n' "$HOST_NAME" | run_root tee /etc/hostname >/dev/null
    fi

    run_root python3 - "$HOST_NAME" <<'PY'
from pathlib import Path
import sys

hostname = sys.argv[1]
path = Path("/etc/hosts")
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
replacement = f"127.0.1.1\t{hostname}"
updated = []
replaced = False
for line in lines:
    if line.lstrip().startswith("127.0.1.1"):
        if not replaced:
            updated.append(replacement)
            replaced = True
    else:
        updated.append(line)
if not replaced:
    updated.append(replacement)
path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY
}

configure_wsl() {
    [[ "$MODE" == "wsl" ]] || return 0
    log "Merging systemd, default-user, and hostname settings into /etc/wsl.conf."

    run_root python3 - "$USER" "$HOST_NAME" "$CONFIGURE_HOSTNAME" <<'PY'
from pathlib import Path
import configparser
import sys

username, hostname, configure_hostname = sys.argv[1:]
path = Path("/etc/wsl.conf")
config = configparser.ConfigParser()
config.optionxform = str
if path.exists():
    config.read(path)

for section in ("boot", "user"):
    if not config.has_section(section):
        config.add_section(section)
config.set("boot", "systemd", "true")
config.set("user", "default", username)

if configure_hostname == "1":
    if not config.has_section("network"):
        config.add_section("network")
    config.set("network", "hostname", hostname)

with path.open("w", encoding="utf-8") as handle:
    config.write(handle, space_around_delimiters=False)
PY
}

run_step() {
    local script_name="$1"
    shift
    local script_path="$ROOT_DIR/scripts/$script_name"

    [[ -f "$script_path" ]] || fail "Required installer step is absent: $script_path"
    log "Running $script_name"
    bash "$script_path" "$@"
}

configure_passwordless_sudo
prepare_ubuntu_package_sources
configure_locale_timezone
configure_hostname_and_hosts
configure_wsl

run_root usermod -aG sudo "$USER"

run_step 01-install-packages.sh --mode "$MODE"

run_step 02-restore-themes-and-configs.sh --mode "$MODE"
run_step 03-setup-terminal.sh

if [[ "$INSTALL_PYENV" == "1" ]]; then
    install_pyenv_python "$PYTHON_VERSION"
fi

git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global push.default simple

if [[ "$MODE" == "desktop" ]]; then
    run_step 04-setup-extensions.sh
    run_step 05-apply-gnome-settings.sh
    run_step 06-setup-assets-grub-wallpapers.sh
    run_step 07-setup-vscode.sh
    run_step 08-finalize-desktop.sh
else
    if ! is_systemd_running; then
        warn "WSL configuration changed. Run 'wsl --shutdown' in PowerShell before using system services."
    fi
fi

if [[ "$SET_SHORT_PASSWORD" == "1" ]]; then
    password_arguments=(--user "$USER")
    if [[ "$REPAIR_PASSWORD_STACK" == "1" ]]; then
        password_arguments+=(--repair-pam)
    fi
    run_step 09-set-local-password.sh "${password_arguments[@]}"
fi

log "============================================================"
log "UbuntuRicePack installation completed in $MODE mode."
log "Log file: $LOG_FILE"
log "Verification reports: $STATE_DIR/reports"
if [[ "$MODE" == "desktop" ]]; then
    log "Log out and back in once to reload GNOME Shell extensions."
fi
log "Local AI was not installed. To add it independently, run:"
log "  bash scripts/10-setup-local-ai-ollama-openwebui.sh"
log "To diagnose or set a short local password independently, run:"
log "  bash scripts/09-set-local-password.sh"
log "For duplicate current-password prompts/token errors, run:"
log "  bash scripts/09-set-local-password.sh --repair-pam"
log "============================================================"
