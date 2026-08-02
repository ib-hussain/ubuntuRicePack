#!/usr/bin/env bash
# Shared helpers for ubuntuRicePack.
#
# This file is sourced by the numbered installer stages. It deliberately
# contains no Arch/pacman/AUR logic.

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

if [[ -n "${UBUNTU_RICE_COMMON_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly UBUNTU_RICE_COMMON_LOADED=1

COMMON_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${ROOT_DIR:-$(cd -- "$COMMON_SCRIPT_DIR/.." && pwd)}"
export REPO_ROOT

RELEASE_COMPAT_SCRIPT="$COMMON_SCRIPT_DIR/ubuntu-release-compat.sh"
if [[ ! -r "$RELEASE_COMPAT_SCRIPT" ]]; then
    printf 'Ubuntu release compatibility library is missing: %s\n' \
        "$RELEASE_COMPAT_SCRIPT" >&2
    exit 1
fi
# shellcheck source=ubuntu-release-compat.sh
source "$RELEASE_COMPAT_SCRIPT"

PROJECT_NAME="ubuntuRicePack"
RUN_ID="${RICE_RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"

detect_target_user() {
    local candidate="${RICE_TARGET_USER:-${TARGET_USER:-}}"

    if [[ -z "$candidate" && "$EUID" -ne 0 ]]; then
        candidate="$(id -un)"
    elif [[ -z "$candidate" && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        candidate="$SUDO_USER"
    fi

    if [[ -z "$candidate" ]] || ! id "$candidate" >/dev/null 2>&1; then
        printf 'Unable to determine the target user. Set RICE_TARGET_USER.\n' >&2
        return 1
    fi

    printf '%s\n' "$candidate"
}

TARGET_USER="$(detect_target_user)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
TARGET_HOME="$(
    getent passwd "$TARGET_USER" |
        awk -F: 'NR == 1 {print $6}'
)"

if [[ -z "$TARGET_HOME" || "$TARGET_HOME" != /* ]]; then
    printf 'Unable to determine a valid home directory for %s.\n' "$TARGET_USER" >&2
    exit 1
fi

if [[ "$EUID" -ne 0 && "$(id -un)" == "$TARGET_USER" ]]; then
    USER_STATE_HOME="${XDG_STATE_HOME:-$TARGET_HOME/.local/state}"
else
    USER_STATE_HOME="$TARGET_HOME/.local/state"
fi

STATE_DIR="$USER_STATE_HOME/$PROJECT_NAME"
LOG_DIR="$STATE_DIR/logs"
BACKUP_ROOT="${RICE_BACKUP_ROOT:-$STATE_DIR/backups/$RUN_ID}"

mkdir -p -- "$LOG_DIR" "$BACKUP_ROOT"
LOG_FILE="${LOG_FILE:-$LOG_DIR/install-$RUN_ID.log}"

export PROJECT_NAME RUN_ID TARGET_USER TARGET_GROUP TARGET_HOME
export STATE_DIR LOG_DIR BACKUP_ROOT LOG_FILE

# Compatibility names used by the newer consolidated stages.
RICE_NAME="$PROJECT_NAME"
RICE_TARGET_USER="$TARGET_USER"
RICE_TARGET_HOME="$TARGET_HOME"
RICE_STATE_DIR="$STATE_DIR"
RICE_BACKUP_ROOT="$BACKUP_ROOT"
export RICE_NAME RICE_TARGET_USER RICE_TARGET_HOME
export RICE_STATE_DIR RICE_BACKUP_ROOT

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    printf '%s [INFO] %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE"
}

warn() {
    printf '%s [WARN] %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE" >&2
}

fail() {
    printf '%s [ERROR] %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE" >&2
    exit 1
}

on_error() {
    local status="$1"
    local line="$2"
    local command="$3"

    warn "Command failed with status $status at line $line: $command"
    return "$status"
}

trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

declare -a RICE_TEMP_PATHS=()

register_temp_path() {
    local path="$1"
    [[ -n "$path" ]] || return 0
    RICE_TEMP_PATHS+=("$path")
}

cleanup_temp_paths() {
    local path=""
    local temp_root="${TMPDIR:-/tmp}"

    for path in "${RICE_TEMP_PATHS[@]}"; do
        [[ -n "$path" ]] || continue
        case "$path" in
            "$temp_root"/ubuntuRicePack.*|/tmp/ubuntuRicePack.*)
                rm -rf -- "$path"
                ;;
            *)
                warn "Refusing to remove unexpected temporary path: $path"
                ;;
        esac
    done
}

trap cleanup_temp_paths EXIT

make_temp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/ubuntuRicePack.XXXXXX"
}

make_temp_file() {
    mktemp "${TMPDIR:-/tmp}/ubuntuRicePack.XXXXXX"
}

run_root() {
    (($# > 0)) || {
        printf 'run_root: no command was supplied.\n' >&2
        return 64
    }

    if [[ "$EUID" -eq 0 ]]; then
        # `command` bypasses a same-named shell function or alias while still
        # allowing ordinary builtins such as `test`.
        command "$@"
        return
    fi

    command -v sudo >/dev/null 2>&1 || {
        printf 'run_root: sudo is not installed or is not in PATH.\n' >&2
        return 127
    }

    # The explicit `--` prevents a command name beginning with a dash from
    # being parsed as another sudo option. Keep redirections at the call site;
    # run_root deliberately executes an argv array, never an eval string.
    command sudo -- "$@"
}

as_target_user() {
    if [[ "$EUID" -eq 0 && "$TARGET_USER" != "root" ]]; then
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" USER="$TARGET_USER" "$@"
    else
        "$@"
    fi
}

require_regular_user() {
    if [[ "$EUID" -eq 0 ]]; then
        fail "Run this stage as the target user, not with sudo."
    fi

    if [[ "$(id -un)" != "$TARGET_USER" ]]; then
        fail "Current user $(id -un) does not match target user $TARGET_USER."
    fi
}

have_user_session() {
    [[ "$EUID" -ne 0 &&
        -n "${DBUS_SESSION_BUS_ADDRESS:-}" &&
        -n "${XDG_RUNTIME_DIR:-}" ]]
}

require_user_session() {
    require_regular_user
    if ! have_user_session; then
        fail "GNOME session variables are missing. Log into GNOME and run this stage from a terminal."
    fi
}

require_normal_user() {
    require_regular_user
}

has_gnome_session() {
    have_user_session &&
        command -v gsettings >/dev/null 2>&1 &&
        command -v gnome-extensions >/dev/null 2>&1
}

require_gnome_session() {
    require_user_session
    has_gnome_session ||
        fail "GNOME tools are unavailable. Install the package stage and run this inside GNOME."
}

is_wsl() {
    [[ -n "${WSL_INTEROP:-}" ]] ||
        grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease /proc/version 2>/dev/null
}

have_systemd() {
    [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" == "systemd" ]]
}

is_systemd_running() {
    have_systemd
}

require_ubuntu() {
    local distro_id=""
    local distro_like=""
    local release_id=""
    local release_codename=""
    local release_profile=""

    [[ -r /etc/os-release ]] || fail "/etc/os-release is unavailable."
    # shellcheck disable=SC1091
    source /etc/os-release
    distro_id="${ID:-}"
    distro_like="${ID_LIKE:-}"
    release_id="${VERSION_ID:-}"
    release_codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

    if [[ "$distro_id" != "ubuntu" && " $distro_like " != *" ubuntu "* ]]; then
        if [[ "${ALLOW_UNSUPPORTED_DISTRO:-0}" == "1" ]]; then
            warn "Unsupported distribution '$distro_id' allowed by ALLOW_UNSUPPORTED_DISTRO=1."
        else
            fail "This installer targets Ubuntu; detected '${PRETTY_NAME:-$distro_id}'."
        fi
    fi

    if release_profile="$(
        ubuntu_release_profile "$release_id" "$release_codename"
    )"; then
        IFS=$'\t' read -r \
            RICE_UBUNTU_VERSION \
            RICE_UBUNTU_CODENAME \
            RICE_EXPECTED_GNOME_MAJOR \
            RICE_UBUNTU_SUPPORT_STATUS \
            <<<"$release_profile"
        export RICE_UBUNTU_VERSION RICE_UBUNTU_CODENAME
        export RICE_EXPECTED_GNOME_MAJOR RICE_UBUNTU_SUPPORT_STATUS
    elif [[ "${ALLOW_UNSUPPORTED_UBUNTU_RELEASE:-0}" == "1" ]]; then
        RICE_UBUNTU_VERSION="$release_id"
        RICE_UBUNTU_CODENAME="$release_codename"
        RICE_EXPECTED_GNOME_MAJOR=""
        RICE_UBUNTU_SUPPORT_STATUS="unsupported"
        export RICE_UBUNTU_VERSION RICE_UBUNTU_CODENAME
        export RICE_EXPECTED_GNOME_MAJOR RICE_UBUNTU_SUPPORT_STATUS
        warn "Unsupported Ubuntu release allowed: $release_id ($release_codename)."
    else
        fail "Supported Ubuntu releases are 25.04 (Plucky/GNOME 48) and 26.04 (Resolute/GNOME 50); detected $release_id ($release_codename)."
    fi

    log "Detected ${PRETTY_NAME:-Ubuntu} ($release_codename; expected GNOME ${RICE_EXPECTED_GNOME_MAJOR:-unknown})."
    if [[ "$RICE_UBUNTU_SUPPORT_STATUS" == "eol" ]]; then
        warn "Ubuntu $RICE_UBUNTU_VERSION is end-of-life; archive compatibility does not restore security support."
    fi
}

prepare_ubuntu_package_sources() {
    local migration_output=""
    local status=""
    local detail=""

    [[ "${RICE_UBUNTU_SUPPORT_STATUS:-}" == "eol" ]] || return 0
    [[ "${RICE_UBUNTU_CODENAME:-}" == "plucky" ]] ||
        fail "No archived-source migration is defined for ${RICE_UBUNTU_CODENAME:-unknown}."

    warn "Using Ubuntu's signed old-releases archive for Plucky package access."
    migration_output="$(
        run_root bash "$RELEASE_COMPAT_SCRIPT" \
            --rewrite-eol-sources \
            /etc/apt \
            "$RICE_UBUNTU_CODENAME"
    )" || fail "Could not migrate Plucky APT sources to old-releases.ubuntu.com."

    while IFS=$'\t' read -r status detail; do
        [[ -n "$status" ]] || continue
        case "$status" in
            changed)
                log "Migrated archived Ubuntu source: $detail"
                ;;
            unchanged)
                log "$detail"
                ;;
            *)
                warn "Unexpected archive-migration result: $status $detail"
                ;;
        esac
    done <<<"$migration_output"
}

ubuntu_web_search_provider_expected() {
    # Ubuntu introduced this GNOME Shell provider in 26.04. It must not be a
    # required enabled extension on the GNOME 48 desktop shipped by 25.04.
    [[ "${RICE_UBUNTU_VERSION:-}" == "26.04" ]]
}

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 ||
        fail "Required command is unavailable: $command_name"
}

detect_command() {
    local command_name=""

    for command_name in "$@"; do
        if command -v "$command_name" >/dev/null 2>&1; then
            printf '%s\n' "$command_name"
            return 0
        fi
    done

    return 1
}

sudo_validate() {
    if [[ "$EUID" -ne 0 ]]; then
        sudo -v || fail "sudo authentication failed."
    fi
}

apt_get() {
    run_root env DEBIAN_FRONTEND=noninteractive \
        apt-get \
        -o Dpkg::Options::=--force-confold \
        -o Acquire::Retries=3 \
        "$@"
}

apt_update() {
    log "Refreshing APT package metadata."
    apt_get update
}

apt_install() {
    [[ "$#" -gt 0 ]] || return 0
    apt_get install -y "$@"
}

apt_purge() {
    [[ "$#" -gt 0 ]] || return 0
    apt_get purge -y "$@"
}

# apt_package_available() {
#     local package_name="$1"
#     apt-cache show --no-all-versions "$package_name" 2>/dev/null |
#         grep -q '^Package:'
# }
apt_package_available() {
    local package_name="$1"
    apt-cache show --no-all-versions "$package_name" >/dev/null 2>&1
}
apt_package_exists() {
    apt_package_available "$1"
}

apt_package_installed() {
    local package_name="$1"
    dpkg-query -W -f='${db:Status-Status}\n' "$package_name" 2>/dev/null |
        grep -qx 'installed'
}

font_family_match() {
    local expected_family="$1"
    local font_families=""

    command -v fc-list >/dev/null 2>&1 || return 1

    # Consume all fc-list output before searching it. This avoids SIGPIPE
    # false negatives caused by `fc-list | grep -q` under `pipefail`.
    font_families="$(fc-list : family 2>/dev/null)" || return 1

    grep -F -i -m 1 -- "$expected_family" <<<"$font_families"
}

font_family_available() {
    font_family_match "$1" >/dev/null
}

download_file() {
    local url="$1"
    local destination="$2"

    
    if command -v wget >/dev/null 2>&1; then
        wget --tries=3 --timeout=20 --output-document="$destination" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl  --fail  --location --show-error  --silent \
            --retry 3  --retry-all-errors  --connect-timeout 20 --output "$destination"  "$url"
    else
        fail "Neither curl nor wget is available for downloading $url."
    fi

    [[ -s "$destination" ]] || fail "Downloaded file is empty: $url"
}

verify_sha256() {
    local file="$1"
    local expected="${2#sha256:}"
    local actual=""

    [[ -n "$expected" ]] || fail "No SHA-256 digest was supplied for $file."
    actual="$(sha256sum "$file" | awk '{print $1}')"

    if [[ "$actual" != "$expected" ]]; then
        fail "SHA-256 verification failed for $(basename "$file")."
    fi

    log "Verified SHA-256 for $(basename "$file")."
}

install_root_file() {
    local destination="$1"
    local mode="${2:-0644}"
    local temporary=""

    temporary="$(make_temp_file)"
    register_temp_path "$temporary"
    cat >"$temporary"
    run_root install -D -m "$mode" "$temporary" "$destination"
}

schema_exists() {
    local schema="$1"
    command -v gsettings >/dev/null 2>&1 &&
        gsettings list-schemas 2>/dev/null |
            grep -Fx "$schema" >/dev/null
}

schema_key_exists() {
    local schema="$1"
    local key="$2"

    schema_exists "$schema" || return 1
    gsettings list-keys "$schema" 2>/dev/null |
        grep -Fx "$key" >/dev/null
}

gs_set() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if ! have_user_session; then
        warn "No graphical user session; deferred gsettings value: $schema $key"
        return 0
    fi

    if schema_key_exists "$schema" "$key"; then
        if gsettings set "$schema" "$key" "$value" 2>>"$LOG_FILE"; then
            log "Applied gsettings value: $schema $key"
        else
            warn "Could not set gsettings value: $schema $key"
        fi
    else
        warn "Missing gsettings key: $schema $key"
    fi
}

dconf_write() {
    local path="$1"
    local value="$2"

    if ! have_user_session; then
        warn "No graphical user session; deferred dconf value: $path"
        return 0
    fi

    if dconf write "$path" "$value" 2>>"$LOG_FILE"; then
        log "Applied dconf value: $path"
    else
        warn "Could not write dconf value: $path"
    fi
}

backup_path() {
    local source_path="$1"
    local relative_path=""
    local destination=""

    [[ -e "$source_path" || -L "$source_path" ]] || return 0
    [[ "$source_path" == /* ]] || fail "backup_path requires an absolute path: $source_path"

    relative_path="${source_path#/}"
    destination="$BACKUP_ROOT/$relative_path"
    mkdir -p -- "$(dirname -- "$destination")"

    if [[ -e "$destination" || -L "$destination" ]]; then
        return 0
    fi

    cp -a -- "$source_path" "$destination"
    log "Backed up $source_path -> $destination"
}

copy_dir_contents() {
    local source_dir="$1"
    local destination_dir="$2"

    if [[ ! -d "$source_dir" ]]; then
        warn "Directory is absent; skipped: $source_dir"
        return 0
    fi

    mkdir -p -- "$destination_dir"
    cp -a -- "$source_dir"/. "$destination_dir"/
    log "Copied directory contents: $source_dir -> $destination_dir"
}

copy_file() {
    local source_file="$1"
    local destination_file="$2"
    local mode="${3:-}"

    if [[ ! -f "$source_file" ]]; then
        warn "File is absent; skipped: $source_file"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$destination_file")"
    cp -a -- "$source_file" "$destination_file"
    if [[ -n "$mode" ]]; then
        chmod "$mode" "$destination_file"
    fi
    log "Copied file: $source_file -> $destination_file"
}

safe_chown_target() {
    local path="$1"

    [[ -e "$path" || -L "$path" ]] || return 0
    if [[ "$EUID" -eq 0 && "$TARGET_USER" != "root" ]]; then
        chown -R "$TARGET_USER:$TARGET_GROUP" "$path"
    fi
}

assert_repo_path() {
    local relative_path="$1"
    [[ -e "$REPO_ROOT/$relative_path" ]] ||
        fail "Required repository path is missing: $relative_path"
}

desktop_file_exists() {
    local desktop_id="$1"
    local directory=""

    for directory in \
        "$TARGET_HOME/.local/share/applications" \
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
            "$TARGET_HOME/.local/share/applications" \
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
    local pyenv_root="$TARGET_HOME/.pyenv"
    local jobs="${PYTHON_BUILD_JOBS:-}"
    local output=""

    if ! command -v pyenv >/dev/null 2>&1; then
        if [[ ! -x "$pyenv_root/bin/pyenv" ]]; then
            log "Ubuntu pyenv package is unavailable; installing pyenv from its upstream Git repository."
            git clone --depth 1 https://github.com/pyenv/pyenv.git "$pyenv_root"
        fi
        export PATH="$pyenv_root/bin:$PATH"
    fi

    command -v pyenv >/dev/null 2>&1 ||
        fail "pyenv is unavailable after installation."

    export PYENV_ROOT="$pyenv_root"
    eval "$(pyenv init - bash)"

    if [[ -z "$jobs" ]]; then
        jobs="$(nproc 2>/dev/null || printf '2')"
        ((jobs > 4)) && jobs=4
        ((jobs < 1)) && jobs=1
    fi
    [[ "$jobs" =~ ^[1-9][0-9]*$ ]] ||
        fail "PYTHON_BUILD_JOBS must be a positive integer."

    if pyenv versions --bare |
        sed 's/^[[:space:]]*//' |
        grep -Fxq "$python_version"
    then
        log "pyenv Python $python_version is already installed."
    else
        log "Building Python $python_version through pyenv with $jobs job(s)."
        MAKE_OPTS="-j$jobs" pyenv install "$python_version"
    fi

    pyenv global "$python_version"
    pyenv rehash
    output="$(pyenv exec python --version 2>&1)"
    [[ "$output" == "Python $python_version" ]] ||
        fail "pyenv verification failed: $output"
    log "Configured pyenv global Python: $output"
}

log "Loaded shared helpers for $PROJECT_NAME."
log "Repository: $REPO_ROOT"
log "Target user: $TARGET_USER ($TARGET_HOME)"
log "Log file: $LOG_FILE"
