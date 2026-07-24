#!/usr/bin/env bash
# Shared helpers for UbuntuRicePack scripts. Source this file; do not execute it.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
RICE_NAME="ubuntuRicePack"
RICE_TARGET_USER="${RICE_TARGET_USER:-${SUDO_USER:-$(id -un)}}"

if ! RICE_TARGET_HOME="$(getent passwd "$RICE_TARGET_USER" | cut -d: -f6)" ||
        [[ -z "$RICE_TARGET_HOME" ]]; then
    RICE_TARGET_HOME="$HOME"
fi

RICE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ubuntu-rice-pack"
mkdir -p "$RICE_STATE_DIR"
LOG_FILE="${LOG_FILE:-$RICE_STATE_DIR/install-$(date +%Y%m%d-%H%M%S).log}"
RICE_BACKUP_ROOT="${RICE_BACKUP_ROOT:-$HOME/rice-install-backups/$(date +%Y%m%d-%H%M%S)}"

log() {
    printf '[INFO] %s\n' "$*" | tee -a "$LOG_FILE"
}

warn() {
    printf '[WARN] %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

fail() {
    printf '[ERROR] %s\n' "$*" | tee -a "$LOG_FILE" >&2
    exit 1
}

run_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

is_wsl() {
    [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]] ||
        grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

is_systemd_running() {
    [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" == "systemd" ]]
}

require_ubuntu() {
    [[ -r /etc/os-release ]] || fail "Cannot identify this Linux distribution."

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* &&
            "${ID_LIKE:-}" != *debian* ]]; then
        fail "This installer supports Ubuntu and Ubuntu-based WSL distributions, not ${PRETTY_NAME:-this system}."
    fi

    command -v apt-get >/dev/null 2>&1 ||
        fail "apt-get is required but was not found."
}

require_normal_user() {
    [[ "$EUID" -ne 0 ]] ||
        fail "Run this as your normal user, without sudo. The scripts request sudo only when needed."
}

has_gnome_session() {
    [[ "$EUID" -ne 0 &&
        -n "${DBUS_SESSION_BUS_ADDRESS:-}" &&
        -n "${XDG_RUNTIME_DIR:-}" ]] &&
        command -v gsettings >/dev/null 2>&1 &&
        command -v gnome-extensions >/dev/null 2>&1
}

require_gnome_session() {
    require_normal_user
    has_gnome_session ||
        fail "Log into Ubuntu GNOME and run this from a terminal inside that desktop session."
}

schema_exists() {
    command -v gsettings >/dev/null 2>&1 &&
        gsettings list-schemas 2>/dev/null | grep -Fqx "$1"
}

schema_key_exists() {
    local schema="$1"
    local key="$2"

    schema_exists "$schema" &&
        gsettings list-keys "$schema" 2>/dev/null | grep -Fqx "$key"
}

gs_set() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if ! schema_key_exists "$schema" "$key"; then
        warn "Skipping unavailable GNOME setting: $schema $key"
        return 0
    fi

    if gsettings set "$schema" "$key" "$value" 2>>"$LOG_FILE"; then
        log "Set $schema $key"
    else
        warn "Could not set $schema $key"
    fi
}

backup_path() {
    local source_path="$1"
    local relative_path=""
    local backup_path=""

    [[ -e "$source_path" || -L "$source_path" ]] || return 0

    if [[ "$source_path" == "$HOME"/* ]]; then
        relative_path="${source_path#"$HOME"/}"
    else
        relative_path="system${source_path}"
    fi

    backup_path="$RICE_BACKUP_ROOT/$relative_path"
    mkdir -p "$(dirname "$backup_path")"
    cp -a -- "$source_path" "$backup_path"
    log "Backed up $source_path to $backup_path"
}

copy_dir_contents() {
    local source_dir="$1"
    local destination_dir="$2"

    if [[ ! -d "$source_dir" ]]; then
        warn "Directory is absent; skipped: $source_dir"
        return 0
    fi

    mkdir -p "$destination_dir"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a "$source_dir/" "$destination_dir/"
    else
        cp -a "$source_dir"/. "$destination_dir"/
    fi
    log "Copied $source_dir -> $destination_dir"
}

copy_file() {
    local source_file="$1"
    local destination_file="$2"
    local mode="${3:-0644}"

    if [[ ! -f "$source_file" ]]; then
        warn "File is absent; skipped: $source_file"
        return 0
    fi

    install -Dm"$mode" "$source_file" "$destination_file"
    log "Copied $source_file -> $destination_file"
}

apt_package_exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

desktop_file_exists() {
    local desktop_id="$1"
    local directory=""

    for directory in \
        "$HOME/.local/share/applications" \
        /usr/local/share/applications \
        /usr/share/applications
    do
        [[ -f "$directory/$desktop_id" ]] && return 0
    done

    return 1
}

find_desktop_file() {
    local desktop_id=""
    local directory=""

    for desktop_id in "$@"; do
        for directory in \
            "$HOME/.local/share/applications" \
            /usr/local/share/applications \
            /usr/share/applications
        do
            if [[ -f "$directory/$desktop_id" ]]; then
                printf '%s\n' "$directory/$desktop_id"
                return 0
            fi
        done
    done

    return 1
}

wait_for_url() {
    local url="$1"
    local attempts="${2:-60}"
    local pause_seconds="${3:-2}"
    local attempt=""

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$pause_seconds"
    done

    return 1
}

install_pyenv_python() {
    local python_version="${1:-3.12.7}"
    local pyenv_root="$HOME/.pyenv"

    if [[ ! -x "$pyenv_root/bin/pyenv" ]]; then
        log "Installing pyenv in $pyenv_root."
        git clone --depth 1 https://github.com/pyenv/pyenv.git "$pyenv_root"
    else
        log "pyenv is already installed."
    fi

    export PYENV_ROOT="$pyenv_root"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - bash)"

    log "Ensuring Python $python_version is installed through pyenv."
    pyenv install -s "$python_version"
    pyenv global "$python_version"
    pyenv rehash
    log "Active pyenv Python: $(pyenv exec python --version)"

