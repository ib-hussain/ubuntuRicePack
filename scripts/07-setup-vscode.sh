#!/usr/bin/env bash
# Restore VS Code data and the Nautilus "Open with Code" integration.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'USAGE'
Usage: 07-setup-vscode.sh [options]

Options:
  --repair-profile  Back up and rebuild VS Code's Linux user-data profile
  --stop-running    Gracefully stop this user's Code processes before repair
  -h, --help        Show this help

The first run of this revision performs one automatic profile migration. It
preserves ~/.vscode extension directories, but removes copied Windows session
state from ~/.config/Code after backing up the complete directory.
USAGE
}

for argument in "$@"; do
    case "$argument" in
        --help | -h)
            usage
            exit 0
            ;;
    esac
done
unset argument

# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

VSCODE_SOURCE="$REPO_ROOT/configs/vscode"
VSCODE_USER_SOURCE="$VSCODE_SOURCE/User"
VSCODE_EXTENSION_LIST="$VSCODE_SOURCE/extensions.txt"
VSCODE_CONFIG_ROOT="$(
    realpath -m -- "${XDG_CONFIG_HOME:-$TARGET_HOME/.config}/Code"
)"
VSCODE_USER_DEST="$VSCODE_CONFIG_ROOT/User"
VSCODE_EXTENSIONS_DEST="$TARGET_HOME/.vscode/extensions"
NAUTILUS_DEST="$TARGET_HOME/.local/share/nautilus-python/extensions"
REPORT_DIR="$STATE_DIR/reports"
REPORT_FILE="$REPORT_DIR/vscode-$RUN_ID.tsv"
EXTENSION_REPORT="$REPORT_DIR/vscode-$RUN_ID-extensions.txt"
MIGRATION_MARKER="$STATE_DIR/migrations/vscode-profile-v2.complete"
EXTENSION_FAILURES=0
FORCE_PROFILE_REPAIR="${RICE_VSCODE_FORCE_RESET:-0}"
STOP_RUNNING_CODE="${RICE_VSCODE_STOP_RUNNING:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repair-profile)
            FORCE_PROFILE_REPAIR=1
            shift
            ;;
        --stop-running)
            STOP_RUNNING_CODE=1
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown VS Code stage argument: $1"
            ;;
    esac
done

[[ "$FORCE_PROFILE_REPAIR" == "0" || "$FORCE_PROFILE_REPAIR" == "1" ]] ||
    fail "RICE_VSCODE_FORCE_RESET must be 0 or 1."
[[ "$STOP_RUNNING_CODE" == "0" || "$STOP_RUNNING_CODE" == "1" ]] ||
    fail "RICE_VSCODE_STOP_RUNNING must be 0 or 1."

require_gnome_session
require_command pgrep

command -v code >/dev/null 2>&1 ||
    fail "Visual Studio Code is not installed. Run scripts/01-install-packages.sh first."

CODE_COMMAND="$(command -v code)"
CODE_REAL_PATH="$(readlink -f -- "$CODE_COMMAND")"
CODE_PACKAGE_OWNER="$(dpkg-query -S "$CODE_REAL_PATH" 2>/dev/null || true)"
if ! apt_package_installed code; then
    fail "The Microsoft APT package 'code' is not installed, although $CODE_COMMAND exists."
fi
if ! grep -Eq '^code(:[^:]+)?:' <<<"$CODE_PACKAGE_OWNER"; then
    fail "The active code command is not owned by Microsoft's APT package: $CODE_REAL_PATH"
fi

code_process_ids() {
    pgrep -u "$(id -u)" -x code 2>/dev/null || true
}

stop_running_code_if_requested() {
    local -a process_ids=()
    local -a remaining=()
    local attempt=0
    local pid=""

    mapfile -t process_ids < <(code_process_ids)
    ((${#process_ids[@]} > 0)) || return 0

    if [[ "$STOP_RUNNING_CODE" != "1" ]]; then
        fail "VS Code is still running (PID(s): ${process_ids[*]}). Close it, or rerun this stage with --stop-running."
    fi

    log "Requesting a graceful stop of this user's VS Code processes: ${process_ids[*]}"
    kill -TERM "${process_ids[@]}" 2>/dev/null || true

    for attempt in {1..50}; do
        remaining=()
        for pid in "${process_ids[@]}"; do
            kill -0 "$pid" 2>/dev/null && remaining+=("$pid")
        done
        ((${#remaining[@]} == 0)) && return 0
        sleep 0.1
    done

    fail "VS Code did not stop cleanly (remaining PID(s): ${remaining[*]}). No profile files were changed."
}

repair_vscode_profile_once() {
    local needs_repair=0
    local resolved_home=""

    [[ -f "$MIGRATION_MARKER" ]] || needs_repair=1
    [[ "$FORCE_PROFILE_REPAIR" == "1" ]] && needs_repair=1
    ((needs_repair == 1)) || return 0

    resolved_home="$(realpath -m -- "$TARGET_HOME")"
    [[ "$VSCODE_CONFIG_ROOT" == "$resolved_home"/* ]] ||
        fail "Refusing to reset a VS Code profile outside $TARGET_HOME: $VSCODE_CONFIG_ROOT"
    [[ ! -L "$VSCODE_CONFIG_ROOT" ]] ||
        fail "Refusing to reset a symlinked VS Code profile: $VSCODE_CONFIG_ROOT"

    stop_running_code_if_requested

    if [[ -e "$VSCODE_CONFIG_ROOT" ]]; then
        # Older installer revisions could create root-owned files or copy
        # Windows machine/session state here. Make the user-owned backup
        # readable, then replace the profile rather than merely copying over it.
        run_root chown -R "$TARGET_USER:$TARGET_GROUP" "$VSCODE_CONFIG_ROOT"
        backup_path "$VSCODE_CONFIG_ROOT"
        rm -rf -- "$VSCODE_CONFIG_ROOT"
        log "Removed the backed-up, non-portable VS Code user-data profile."
    fi

    mkdir -p -- "$VSCODE_USER_DEST"
}

repair_vscode_extension_ownership() {
    [[ -e "$TARGET_HOME/.vscode" ]] || return 0
    [[ ! -L "$TARGET_HOME/.vscode" ]] ||
        fail "Refusing to modify a symlinked VS Code extension root."
    run_root chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.vscode"
}

log "Restoring Visual Studio Code and Nautilus integration."
mkdir -p "$REPORT_DIR"
printf 'asset\tpath\tstatus\n' >"$REPORT_FILE"
printf 'code-launcher\t%s\tpackage-owned\n' \
    "$CODE_COMMAND -> $CODE_REAL_PATH" >>"$REPORT_FILE"

repair_vscode_profile_once
repair_vscode_extension_ownership

if [[ -d "$REPO_ROOT/configs/nautilus-python" ]]; then
    backup_path "$NAUTILUS_DEST"
    mkdir -p "$NAUTILUS_DEST"
    rsync -a --delete \
        "$REPO_ROOT/configs/nautilus-python/" \
        "$NAUTILUS_DEST/"
    printf 'nautilus-python\t%s\trestored\n' \
        "$NAUTILUS_DEST" >>"$REPORT_FILE"
else
    printf 'nautilus-python\t%s\tsource missing\n' \
        "$REPO_ROOT/configs/nautilus-python" >>"$REPORT_FILE"
fi

if [[ -d "$VSCODE_USER_SOURCE" ]]; then
    backup_path "$VSCODE_USER_DEST"
    mkdir -p "$VSCODE_USER_DEST"

    # Only portable user-authored configuration belongs here. globalStorage
    # contains machine IDs, window state, and profile associations; replacing
    # it with a capture from another OS can stop VS Code from starting.
    for user_file in settings.json keybindings.json; do
        if [[ -f "$VSCODE_USER_SOURCE/$user_file" ]]; then
            copy_file \
                "$VSCODE_USER_SOURCE/$user_file" \
                "$VSCODE_USER_DEST/$user_file" \
                0644
        fi
    done
    for user_dir in snippets profiles; do
        if [[ -d "$VSCODE_USER_SOURCE/$user_dir" ]]; then
            copy_dir_contents \
                "$VSCODE_USER_SOURCE/$user_dir" \
                "$VSCODE_USER_DEST/$user_dir"
        fi
    done
    printf 'vscode-user\t%s\trestored\n' \
        "$VSCODE_USER_DEST" >>"$REPORT_FILE"
else
    warn "VS Code User configuration is absent: $VSCODE_USER_SOURCE"
    printf 'vscode-user\t%s\tsource missing\n' \
        "$VSCODE_USER_SOURCE" >>"$REPORT_FILE"
fi

sanitize_extension_state() {
    local state_file=""

    mkdir -p "$VSCODE_EXTENSIONS_DEST"
    for state_file in \
        "$VSCODE_EXTENSIONS_DEST/extensions.json" \
        "$VSCODE_EXTENSIONS_DEST/extensions-list.json"
    do
        [[ -f "$state_file" ]] || continue

        if python3 - "$state_file" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except (OSError, UnicodeDecodeError, json.JSONDecodeError):
    raise SystemExit(0)

if isinstance(data, dict) and "recommendations" in data:
    raise SystemExit(0)

if path.name == "extensions-list.json" and isinstance(data, list):
    for item in data:
        location = item.get("location", {}) if isinstance(item, dict) else {}
        captured_path = str(location.get("path", "")).lower()
        if captured_path.startswith("/c:/") or captured_path.startswith("c:/"):
            raise SystemExit(0)

raise SystemExit(1)
PY
        then
            backup_path "$state_file"
            rm -f -- "$state_file"
            warn "Removed invalid cross-platform VS Code state: $state_file"
        fi
    done
}

sanitize_extension_state

if [[ -f "$VSCODE_EXTENSION_LIST" ]]; then
    if ! installed_extensions="$(code --list-extensions 2>>"$LOG_FILE")"; then
        fail "VS Code's extension CLI could not read its Linux extension state. Review $LOG_FILE."
    fi
    while IFS= read -r extension_id || [[ -n "$extension_id" ]]; do
        extension_id="${extension_id//$'\r'/}"
        extension_id="$(
            printf '%s' "$extension_id" |
                sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
        )"
        [[ -n "$extension_id" && "$extension_id" != \#* ]] || continue

        if [[ ! "$extension_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
            warn "Invalid VS Code extension ID; skipped: $extension_id"
            EXTENSION_FAILURES=$((EXTENSION_FAILURES + 1))
            continue
        fi
        if grep -Fxi -- "$extension_id" <<<"$installed_extensions" >/dev/null; then
            log "VS Code extension already installed: $extension_id"
            continue
        fi

        if code --install-extension "$extension_id"; then
            log "Installed VS Code extension: $extension_id"
            installed_extensions+=$'\n'"$extension_id"
        else
            warn "VS Code could not install extension: $extension_id"
            EXTENSION_FAILURES=$((EXTENSION_FAILURES + 1))
        fi
    done <"$VSCODE_EXTENSION_LIST"
fi

git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait "$MERGED"'
git config --global push.default simple

nautilus -q >/dev/null 2>&1 || true
code_version=""
if ! code_version="$(code --version 2>>"$LOG_FILE")"; then
    fail "The installed code launcher failed its version check."
fi
IFS= read -r code_version_first_line <<<"$code_version"
printf '%s\n' "$code_version_first_line" | tee -a "$LOG_FILE"
if ! code --list-extensions --show-versions 2>>"$LOG_FILE" |
    sort >"$EXTENSION_REPORT"
then
    fail "VS Code could not produce a final extension inventory."
fi

if [[ -s "$EXTENSION_REPORT" ]]; then
    printf 'vscode-extension-inventory\t%s\twritten\n' \
        "$EXTENSION_REPORT" >>"$REPORT_FILE"
else
    printf 'vscode-extension-inventory\t%s\tempty\n' \
        "$EXTENSION_REPORT" >>"$REPORT_FILE"
fi

log "VS Code verification report: $REPORT_FILE"
log "VS Code extension inventory: $EXTENSION_REPORT"
if ((EXTENSION_FAILURES > 0)); then
    if [[ "${STRICT_VSCODE_EXTENSIONS:-0}" == "1" ]]; then
        fail "$EXTENSION_FAILURES VS Code extension installation(s) failed."
    fi
    warn "$EXTENSION_FAILURES VS Code extension installation(s) failed."
fi

mkdir -p -- "$(dirname -- "$MIGRATION_MARKER")"
printf '%s\n' \
    "migration=vscode-profile-v2" \
    "completed=$(date --iso-8601=seconds)" \
    "code=$CODE_COMMAND" \
    "real_path=$CODE_REAL_PATH" \
    >"$MIGRATION_MARKER"

log "Visual Studio Code setup is complete."
log "Launch it with a fresh window using: code --new-window ."
