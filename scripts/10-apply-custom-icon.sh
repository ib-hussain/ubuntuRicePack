#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Creating Windows-style Ubuntu desktop application launchers."

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
if [[ -z "$DESKTOP_DIR" ]]; then
    DESKTOP_DIR="$HOME/Desktop"
fi

APPLICATION_DIR="$HOME/.local/share/applications"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

mkdir -p "$DESKTOP_DIR" "$APPLICATION_DIR" "$LOCAL_BIN" "$LOCAL_ICON_DIR"

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

trust_desktop_launcher() {
    local launcher="$1"

    chmod u+x "$launcher"

    if command -v gio >/dev/null 2>&1; then
        gio set "$launcher" metadata::trusted true >/dev/null 2>&1 || true
    fi
}

install_application_launcher() {
    local display_name="$1"
    shift

    local source_file=""
    source_file="$(find_desktop_file "$@" || true)"

    if [[ -z "$source_file" ]]; then
        warn "No installed desktop file found for: $display_name"
        return 0
    fi

    local desktop_id
    desktop_id="$(basename "$source_file")"

    cp -a "$source_file" "$DESKTOP_DIR/$desktop_id"
    trust_desktop_launcher "$DESKTOP_DIR/$desktop_id"

    log "Created desktop launcher: $display_name ($desktop_id)"
}

install_openwebui_launcher() {
    local wrapper="$LOCAL_BIN/open-openwebui"
    local desktop_file="$APPLICATION_DIR/ib-openwebui.desktop"
    local desktop_copy="$DESKTOP_DIR/ib-openwebui.desktop"
    local icon_name="applications-internet"
    local icon_source=""

    for candidate in \
        "$REPO_ROOT/assets/arch-icons/open-webui.svg" \
        "$REPO_ROOT/assets/open-webui.svg" \
        "$REPO_ROOT/assets/openwebui.svg"
    do
        if [[ -f "$candidate" ]]; then
            icon_source="$candidate"
            break
        fi
    done

    if [[ -n "$icon_source" ]]; then
        cp -a "$icon_source" "$LOCAL_ICON_DIR/ib-openwebui.svg"
        icon_name="ib-openwebui"
    fi

    cat > "$wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ubuntuRicePack/openwebui.env"

if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-8080}"
OPEN_WEBUI_URL="${OPEN_WEBUI_URL:-http://127.0.0.1:${OPEN_WEBUI_PORT}}"

exec xdg-open "$OPEN_WEBUI_URL"
WRAPPER
    chmod +x "$wrapper"

    cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Open WebUI
Comment=Open the local Open WebUI interface
Exec=$wrapper
Icon=$icon_name
Terminal=false
Categories=Network;Utility;
StartupNotify=true
DESKTOP

    cp -a "$desktop_file" "$desktop_copy"
    trust_desktop_launcher "$desktop_copy"

    log "Created desktop launcher: Open WebUI"
}

ding_has_key() {
    local key="$1"

    gsettings list-keys org.gnome.shell.extensions.ding 2>/dev/null |
        grep -Fqx "$key"
}

set_ding_boolean() {
    local key="$1"
    local value="$2"

    if ding_has_key "$key"; then
        gsettings set org.gnome.shell.extensions.ding "$key" "$value" || true
    fi
}

configure_ding() {
    if ! gsettings list-schemas |
            grep -Fqx "org.gnome.shell.extensions.ding"; then
        warn "DING settings schema is unavailable; desktop launchers were still created."
        return 0
    fi

    # Use DING's real Trash icon so opening, emptying, and drag-to-trash work.
    set_ding_boolean show-trash true
    set_ding_boolean show-home false
    set_ding_boolean show-volumes false
    set_ding_boolean show-network-volumes false
    set_ding_boolean show-link-emblem true

    if gnome-extensions list | grep -Fqx "ding@rastersoft.com"; then
        gnome-extensions enable "ding@rastersoft.com" || true
    fi
}

install_application_launcher \
    "Google Chrome" \
    "google-chrome.desktop" \
    "google-chrome-stable.desktop"

install_application_launcher \
    "Visual Studio Code" \
    "code.desktop" \
    "visual-studio-code.desktop"

install_application_launcher \
    "Files" \
    "org.gnome.Nautilus.desktop"

install_application_launcher \
    "Terminal" \
    "org.gnome.Ptyxis.desktop" \
    "org.gnome.Console.desktop" \
    "org.gnome.Terminal.desktop"

install_application_launcher \
    "Audacious" \
    "audacious.desktop"

install_openwebui_launcher
configure_ding

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATION_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" \
        >/dev/null 2>&1 || true
fi

log "Windows-style desktop launcher setup complete."
