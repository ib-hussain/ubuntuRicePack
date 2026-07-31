#!/usr/bin/env bash
# Restore VS Code data and the Nautilus "Open with Code" integration.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_gnome_session

command -v code >/dev/null 2>&1 ||
    fail "Visual Studio Code is not installed. Run scripts/01-install-packages.sh first."

VSCODE_SOURCE="$REPO_ROOT/configs/vscode"
VSCODE_USER_SOURCE="$VSCODE_SOURCE/User"
VSCODE_EXTENSION_LIST="$VSCODE_SOURCE/extensions.txt"
VSCODE_USER_DEST="$HOME/.config/Code/User"
VSCODE_EXTENSIONS_DEST="$HOME/.vscode/extensions"
NAUTILUS_DEST="$HOME/.local/share/nautilus-python/extensions"
REPORT_DIR="$STATE_DIR/reports"
REPORT_FILE="$REPORT_DIR/vscode-$RUN_ID.tsv"
EXTENSION_REPORT="$REPORT_DIR/vscode-$RUN_ID-extensions.txt"
EXTENSION_FAILURES=0

log "Restoring Visual Studio Code and Nautilus integration."
mkdir -p "$REPORT_DIR"
printf 'asset\tpath\tstatus\n' >"$REPORT_FILE"

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
    installed_extensions="$(code --list-extensions 2>/dev/null || true)"
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
code --version | head -n 1 | tee -a "$LOG_FILE"
code --list-extensions --show-versions 2>/dev/null |
    sort >"$EXTENSION_REPORT" || true

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
log "Visual Studio Code setup is complete."
