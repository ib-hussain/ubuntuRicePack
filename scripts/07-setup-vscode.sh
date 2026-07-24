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
VSCODE_EXTENSIONS_SOURCE="$VSCODE_SOURCE/extensions"
VSCODE_EXTENSION_LIST="$VSCODE_SOURCE/extensions.txt"
VSCODE_USER_DEST="$HOME/.config/Code/User"
VSCODE_EXTENSIONS_DEST="$HOME/.vscode/extensions"
NAUTILUS_DEST="$HOME/.local/share/nautilus-python"
REPORT_DIR="$STATE_DIR/reports"
REPORT_FILE="$REPORT_DIR/vscode-$RUN_ID.tsv"
EXTENSION_REPORT="$REPORT_DIR/vscode-$RUN_ID-extensions.txt"

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
    rsync -a --delete "$VSCODE_USER_SOURCE/" "$VSCODE_USER_DEST/"
    printf 'vscode-user\t%s\trestored\n' \
        "$VSCODE_USER_DEST" >>"$REPORT_FILE"
else
    warn "VS Code User configuration is absent: $VSCODE_USER_SOURCE"
    printf 'vscode-user\t%s\tsource missing\n' \
        "$VSCODE_USER_SOURCE" >>"$REPORT_FILE"
fi

# Preserve the complete extension data requested by the user. The preferred
# long-term representation is extensions.txt, but existing extension folders
# are restored too so no repository-captured data is lost.
if [[ -d "$VSCODE_EXTENSIONS_SOURCE" ]]; then
    backup_path "$VSCODE_EXTENSIONS_DEST"
    mkdir -p "$VSCODE_EXTENSIONS_DEST"
    rsync -a "$VSCODE_EXTENSIONS_SOURCE/" "$VSCODE_EXTENSIONS_DEST/"
    printf 'vscode-extension-data\t%s\trestored\n' \
        "$VSCODE_EXTENSIONS_DEST" >>"$REPORT_FILE"
else
    printf 'vscode-extension-data\t%s\tnot captured\n' \
        "$VSCODE_EXTENSIONS_SOURCE" >>"$REPORT_FILE"
fi

if [[ -f "$VSCODE_EXTENSION_LIST" ]]; then
    while IFS= read -r extension_id || [[ -n "$extension_id" ]]; do
        extension_id="${extension_id//$'\r'/}"
        [[ -n "$extension_id" && "$extension_id" != \#* ]] || continue
        code --install-extension "$extension_id" --force ||
            warn "VS Code could not install extension: $extension_id"
    done < "$VSCODE_EXTENSION_LIST"
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
log "Visual Studio Code setup is complete."
