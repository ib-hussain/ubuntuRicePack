#!/usr/bin/env bash
# Install only the two cross-distribution Rice Shell extensions.
#
# This entry point intentionally has no apt or pacman dependency. It is usable
# from this repository on either Ubuntu or Arch after GNOME Shell, rsync,
# Python, and glib-compile-schemas are installed.

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SOURCE_ROOT="$REPO_ROOT/configs/extensions"
DEST_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/rice-shell-extensions"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_ROOT="$STATE_ROOT/backups/$RUN_ID"
REPORT_ROOT="$STATE_ROOT/reports"
LOG_FILE="$STATE_ROOT/install-$RUN_ID.log"
EXPECTED_GNOME_MAJOR="${RICE_GNOME_MAJOR:-50}"
STATE_ONLY=0
ENABLE_EXTENSIONS=1
FAILURES=0

readonly JOURNAL_TAG="rice-shell-installer"
readonly -a RICE_UUIDS=(
    "rice-dock@ib-hussain"
    "rice-top-bar@ib-hussain"
)
readonly -a CONFLICT_UUIDS=(
    "arch-dock-icon@ib-hussain"
    "dash-to-dock@micxgx.gmail.com"
    "hidetopbar@mathieu.bidon.ca"
    "ubuntu-dock@ubuntu.com"
)

usage() {
    cat <<'USAGE'
Usage: install-rice-shell-extensions.sh [options]

Options:
  --state-only    Do not copy extension source; only reapply states/reports
  --install-only  Copy and compile the extensions without changing states
  --help          Show this help

Run this as the logged-in GNOME user, never with sudo. The same command works
on Ubuntu and Arch Linux with GNOME Shell 50.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --state-only)
            STATE_ONLY=1
            shift
            ;;
        --install-only)
            ENABLE_EXTENSIONS=0
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

mkdir -p -- "$STATE_ROOT" "$BACKUP_ROOT" "$REPORT_ROOT"

journal_note() {
    command -v logger >/dev/null 2>&1 || return 0
    logger --tag "$JOURNAL_TAG" -- "$*" || true
}

log() {
    local message="$*"
    printf '%s [INFO] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" |
        tee -a "$LOG_FILE"
    journal_note "INFO: $message"
}

warn() {
    local message="$*"
    printf '%s [WARN] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" |
        tee -a "$LOG_FILE" >&2
    journal_note "WARN: $message"
}

fail() {
    local message="$*"
    printf '%s [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" |
        tee -a "$LOG_FILE" >&2
    journal_note "ERROR: $message"
    exit 1
}

on_error() {
    local status="$1"
    local line="$2"
    local command="$3"
    journal_note "ERROR: status=$status line=$line command=$command"
    return "$status"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "Required command is missing: $1"
}

detect_gnome_major() {
    local output=""
    output="$(gnome-shell --version 2>/dev/null)" ||
        fail "Could not read the GNOME Shell version."

    if [[ "$output" =~ ([0-9]+)(\.[0-9]+)+ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        fail "Could not parse GNOME Shell version: $output"
    fi
}

validate_source() {
    local uuid="$1"
    local metadata="$SOURCE_ROOT/$uuid/metadata.json"

    python3 - "$metadata" "$uuid" "$EXPECTED_GNOME_MAJOR" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
uuid = sys.argv[2]
major = sys.argv[3]

try:
    metadata = json.loads(path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"{path}: {error}")

if metadata.get("uuid") != uuid:
    raise SystemExit(f"{path}: expected UUID {uuid!r}")
versions = {str(value) for value in metadata.get("shell-version", [])}
if major not in versions:
    raise SystemExit(f"{uuid}: GNOME Shell {major} is not declared")
PY
}

install_extension() {
    local uuid="$1"
    local source="$SOURCE_ROOT/$uuid"
    local destination="$DEST_ROOT/$uuid"

    [[ -d "$source" ]] || fail "Extension source is missing: $source"
    validate_source "$uuid" ||
        fail "Extension source validation failed for $uuid."

    if [[ -e "$destination" || -L "$destination" ]]; then
        mkdir -p -- "$BACKUP_ROOT"
        cp -a -- "$destination" "$BACKUP_ROOT/$uuid"
        log "Backed up the previous $uuid installation."
    fi

    mkdir -p -- "$destination"
    rsync -a --delete -- "$source/" "$destination/"

    if [[ -d "$destination/schemas" ]]; then
        find "$destination/schemas" \
            -maxdepth 1 \
            -type f \
            -name gschemas.compiled \
            -delete
        glib-compile-schemas --strict "$destination/schemas" ||
            fail "Schema compilation failed for $uuid."
    fi

    printf '%s\n' \
        "Installed by install-rice-shell-extensions.sh at $(date --iso-8601=seconds)" \
        >"$destination/.rice-shell-source"
    log "Installed and validated $uuid."
}

extension_present() {
    local uuid="$1"
    [[ -f "$DEST_ROOT/$uuid/metadata.json" ]] ||
        [[ -f "/usr/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        gnome-extensions list 2>/dev/null | grep -Fx "$uuid" >/dev/null
}

set_state_fallback() {
    local uuid="$1"
    local desired="$2"

    python3 - "$uuid" "$desired" <<'PY'
import ast
import subprocess
import sys

uuid, desired = sys.argv[1:]
schema = "org.gnome.shell"


def read_array(key):
    output = subprocess.run(
        ["gsettings", "get", schema, key],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    if output.startswith("@as "):
        output = output[4:]
    value = ast.literal_eval(output)
    return list(value) if isinstance(value, list) else []


def write_array(key, value):
    rendered = "[" + ", ".join(repr(item) for item in value) + "]"
    subprocess.run(["gsettings", "set", schema, key, rendered], check=True)


enabled = read_array("enabled-extensions")
disabled = read_array("disabled-extensions")
if desired == "enable":
    if uuid not in enabled:
        enabled.append(uuid)
    disabled = [item for item in disabled if item != uuid]
else:
    enabled = [item for item in enabled if item != uuid]
    if uuid not in disabled:
        disabled.append(uuid)

write_array("enabled-extensions", enabled)
write_array("disabled-extensions", disabled)
PY
}

set_extension_state() {
    local uuid="$1"
    local desired="$2"

    if ! extension_present "$uuid"; then
        if [[ "$desired" == "enable" ]]; then
            warn "Cannot enable missing extension: $uuid"
            FAILURES=$((FAILURES + 1))
        fi
        return 0
    fi

    if gnome-extensions "$desired" "$uuid" >/dev/null 2>&1; then
        log "Configured $uuid: $desired"
    elif set_state_fallback "$uuid" "$desired"; then
        log "Persisted $uuid state for the next login: $desired"
    else
        warn "Could not persist $desired state for $uuid."
        FAILURES=$((FAILURES + 1))
    fi
}

write_report() {
    local report="$REPORT_ROOT/extensions-$RUN_ID.txt"
    local uuid=""

    {
        printf 'GNOME Shell: '
        gnome-shell --version 2>&1 || true
        printf 'Distribution: '
        (
            # shellcheck disable=SC1091
            source /etc/os-release
            printf '%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
        )
        printf 'Enabled extensions:\n'
        gnome-extensions list --enabled 2>&1 || true
        printf '\nConfigured extension details:\n'
        for uuid in "${RICE_UUIDS[@]}" "${CONFLICT_UUIDS[@]}"; do
            printf '\n===== %s =====\n' "$uuid"
            gnome-extensions info "$uuid" 2>&1 || true
        done
        printf '\nPersisted enabled-extensions:\n'
        gsettings get org.gnome.shell enabled-extensions 2>&1 || true
        printf '\nPersisted disabled-extensions:\n'
        gsettings get org.gnome.shell disabled-extensions 2>&1 || true
    } >"$report"

    log "Extension report: $report"
    log "Installer log: $LOG_FILE"
}

main() {
    local shell_major=""
    local uuid=""

    [[ "$EUID" -ne 0 ]] ||
        fail "Run this as the logged-in GNOME user, not with sudo."
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] ||
        fail "No user D-Bus session was detected. Run this inside GNOME."

    require_command gnome-shell
    require_command gnome-extensions
    require_command gsettings
    require_command glib-compile-schemas
    require_command python3
    require_command rsync

    shell_major="$(detect_gnome_major)"
    [[ "$shell_major" == "$EXPECTED_GNOME_MAJOR" ]] ||
        fail "Rice Shell targets GNOME $EXPECTED_GNOME_MAJOR; found $shell_major."

    log "Starting cross-distribution Rice Shell installation."
    if [[ "$STATE_ONLY" == "0" ]]; then
        mkdir -p -- "$DEST_ROOT"
        for uuid in "${RICE_UUIDS[@]}"; do
            install_extension "$uuid"
        done
    else
        log "State-only mode: source copying was skipped."
    fi

    if [[ "$ENABLE_EXTENSIONS" == "1" ]]; then
        for uuid in "${CONFLICT_UUIDS[@]}"; do
            set_extension_state "$uuid" disable
        done
        for uuid in "${RICE_UUIDS[@]}"; do
            set_extension_state "$uuid" enable
        done
    else
        log "Install-only mode: extension states were left unchanged."
    fi

    write_report
    ((FAILURES == 0)) ||
        fail "Rice Shell installation completed with $FAILURES error(s)."

    log "Rice Shell is installed. Log out and back in to load fresh code."
}

main "$@"
