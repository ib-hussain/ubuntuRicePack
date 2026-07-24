#!/usr/bin/env bash
# Install the custom extension locally, obtain supported third-party extensions
# from extensions.gnome.org, and use Ubuntu packages for official extensions.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_gnome_session

ENABLE_ONLY=0
if [[ "${1:-}" == "--enable-only" ]]; then
    ENABLE_ONLY=1
    shift
fi
[[ $# -eq 0 ]] || fail "Unknown extension setup argument: $1"

EXTENSION_SOURCE="$REPO_ROOT/configs/extensions"
EXTENSION_LIST="$EXTENSION_SOURCE/extension-list.txt"
EXTENSION_DEST="$HOME/.local/share/gnome-shell/extensions"
CUSTOM_UUID="arch-dock-icon@ib-hussain"

[[ -f "$EXTENSION_LIST" ]] ||
    fail "Missing extension manifest: $EXTENSION_LIST"

mkdir -p "$EXTENSION_DEST"

extension_is_installed() {
    gnome-extensions list 2>/dev/null | grep -Fqx "$1"
}

normalize_uuid() {
    case "$1" in
        dash-to-dock@micxgx.gmail.com)
            printf '%s\n' "ubuntu-dock@ubuntu.com"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

install_custom_extension() {
    local source_dir="$EXTENSION_SOURCE/$CUSTOM_UUID"
    local destination_dir="$EXTENSION_DEST/$CUSTOM_UUID"

    [[ -d "$source_dir" ]] ||
        fail "The custom extension source is missing: $source_dir"
    [[ -f "$source_dir/metadata.json" ]] ||
        fail "The custom extension metadata is missing."

    mkdir -p "$destination_dir"
    rsync -a --delete "$source_dir/" "$destination_dir/"

    if [[ -d "$destination_dir/schemas" ]]; then
        glib-compile-schemas "$destination_dir/schemas"
    fi

    log "Installed the repository's custom extension: $CUSTOM_UUID"
}

install_extension_from_ego() {
    local uuid="$1"
    local shell_major=""
    local encoded_uuid=""
    local metadata_url=""
    local download_path=""
    local extension_url=""
    local archive=""

    extension_is_installed "$uuid" && return 0

    shell_major="$(
        gnome-shell --version |
            awk '{print $NF}' |
            cut -d. -f1
    )"
    encoded_uuid="$(
        python3 -c \
            'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' \
            "$uuid"
    )"
    metadata_url="https://extensions.gnome.org/extension-info/?uuid=${encoded_uuid}&shell_version=${shell_major}"

    log "Resolving the GNOME $shell_major build for: $uuid"
    download_path="$(
        curl -fsSL "$metadata_url" |
            python3 -c \
                'import json,sys; print(json.load(sys.stdin).get("download_url", ""))'
    )"

    [[ -n "$download_path" ]] ||
        fail "extensions.gnome.org has no compatible GNOME $shell_major build for $uuid"

    if [[ "$download_path" == http://* || "$download_path" == https://* ]]; then
        extension_url="$download_path"
    else
        extension_url="https://extensions.gnome.org$download_path"
    fi

    archive="$(mktemp "${TMPDIR:-/tmp}/gnome-extension.XXXXXX.zip")"
    curl -fL "$extension_url" -o "$archive"
    gnome-extensions install --force "$archive"
    rm -f -- "$archive"

    extension_is_installed "$uuid" ||
        fail "GNOME did not index the installed extension: $uuid"
    log "Installed from extensions.gnome.org: $uuid"
}

declare -A EGO_EXTENSIONS=(
    ["hidetopbar@mathieu.bidon.ca"]=1
    ["start-overlay-in-application-view@Hex_cz"]=1
)

declare -a ENABLED_EXTENSIONS=(
    "arch-dock-icon@ib-hussain"
    "hidetopbar@mathieu.bidon.ca"
    "start-overlay-in-application-view@Hex_cz"
    "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "ubuntu-dock@ubuntu.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "ding@rastersoft.com"
    "tiling-assistant@ubuntu.com"
    "ubuntu-appindicators@ubuntu.com"
)

declare -A should_enable=()
for uuid in "${ENABLED_EXTENSIONS[@]}"; do
    should_enable["$uuid"]=1
done

declare -a manifest_extensions=()
while IFS= read -r raw_uuid || [[ -n "$raw_uuid" ]]; do
    raw_uuid="${raw_uuid//$'\r'/}"
    [[ -n "$raw_uuid" && "$raw_uuid" != \#* ]] || continue
    manifest_extensions+=("$(normalize_uuid "$raw_uuid")")
done < "$EXTENSION_LIST"

if [[ "$ENABLE_ONLY" -eq 0 ]]; then
    install_custom_extension

    for uuid in "${manifest_extensions[@]}"; do
        [[ "$uuid" == "$CUSTOM_UUID" ]] && continue
        extension_is_installed "$uuid" && continue

        if [[ -n "${EGO_EXTENSIONS[$uuid]:-}" ]]; then
            install_extension_from_ego "$uuid"
        else
            warn "Expected Ubuntu GNOME extension is not installed: $uuid"
        fi
    done
fi

# Ubuntu Dock replaces upstream Dash-to-Dock and must never run beside it.
if extension_is_installed "dash-to-dock@micxgx.gmail.com"; then
    gnome-extensions disable "dash-to-dock@micxgx.gmail.com" || true
fi

# The rice is Snap-free; these providers are not part of the desired session.
for uuid in \
    "snapd-prompting@canonical.com" \
    "snapd-search-provider@canonical.com"
do
    if extension_is_installed "$uuid"; then
        gnome-extensions disable "$uuid" || true
    fi
done

# Reproduce the actual enabled/disabled state from the Arch export. Extensions
# that were merely installed on Arch remain installed but disabled here.
for uuid in "${manifest_extensions[@]}"; do
    if ! extension_is_installed "$uuid"; then
        continue
    fi

    if [[ -n "${should_enable[$uuid]:-}" ]]; then
        gnome-extensions enable "$uuid" ||
            warn "Could not enable extension immediately: $uuid"
    else
        gnome-extensions disable "$uuid" || true
    fi
done

for uuid in \
    "ding@rastersoft.com" \
    "tiling-assistant@ubuntu.com" \
    "ubuntu-appindicators@ubuntu.com"
do
    if extension_is_installed "$uuid"; then
        gnome-extensions enable "$uuid" ||
            warn "Could not enable Ubuntu system extension: $uuid"
    fi
done

log "GNOME extension setup is complete."
log "A logout/login is required for newly installed Shell code to become active."

