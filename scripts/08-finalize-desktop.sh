#!/usr/bin/env bash
# Create the Windows-style desktop launchers and perform final verification.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_gnome_session

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"
APPLICATION_DIR="$HOME/.local/share/applications"

mkdir -p "$DESKTOP_DIR" "$APPLICATION_DIR"

trust_launcher() {
    local launcher="$1"
    chmod 0755 "$launcher"
    gio set "$launcher" metadata::trusted true >/dev/null 2>&1 || true
}

create_desktop_launcher() {
    local display_name="$1"
    shift

    local source_file=""
    local destination_file=""
    source_file="$(find_desktop_file "$@" || true)"

    if [[ -z "$source_file" ]]; then
        warn "No installed application launcher was found for: $display_name"
        return 0
    fi

    destination_file="$DESKTOP_DIR/$(basename "$source_file")"
    cp -a "$source_file" "$destination_file"
    trust_launcher "$destination_file"
    log "Created desktop launcher: $display_name"
}

configure_ding() {
    local schema="org.gnome.shell.extensions.ding"

    if ! schema_exists "$schema"; then
        warn "DING is unavailable; application launchers exist but desktop icons may not be displayed."
        return 0
    fi

    gs_set "$schema" show-trash "true"
    gs_set "$schema" show-home "false"
    gs_set "$schema" show-volumes "false"
    gs_set "$schema" show-network-volumes "false"
    gs_set "$schema" show-link-emblem "true"

    if gnome-extensions list | grep -Fqx "ding@rastersoft.com"; then
        gnome-extensions enable "ding@rastersoft.com" || true
    fi
}

remove_managed_gdm_branding() {
    local removed=0
    local managed_file=""

    for managed_file in \
        /etc/dconf/db/gdm.d/90-rice-login-background \
        /etc/dconf/db/gdm.d/90-ubuntuRicePack-logo \
        /etc/dconf/db/gdm.d/90-ubuntu-rice-pack-logo
    do
        if run_root test -e "$managed_file"; then
            run_root rm -f -- "$managed_file"
            removed=1
        fi
    done

    if run_root test -e /usr/local/share/ubuntuRicePack/ib.png; then
        run_root rm -f -- /usr/local/share/ubuntuRicePack/ib.png
        removed=1
    fi

    if ((removed == 1)) && command -v dconf >/dev/null 2>&1; then
        run_root dconf update
        log "Removed GDM branding left by earlier UbuntuRicePack revisions."
    fi
}

verify_installation() {
    local failure_count=0
    local command_name=""
    local uuid=""

    log "Running final UbuntuRicePack verification."

    for command_name in \
        git curl gsettings gnome-extensions fastfetch eza rg fzf zoxide \
        google-chrome-stable code nautilus gnome-terminal audacious
    do
        if command -v "$command_name" >/dev/null 2>&1; then
            log "Verified command: $command_name"
        else
            warn "Command is unavailable: $command_name"
            ((failure_count += 1))
        fi
    done

    for uuid in \
        "arch-dock-icon@ib-hussain" \
        "hidetopbar@mathieu.bidon.ca" \
        "start-overlay-in-application-view@Hex_cz" \
        "ubuntu-dock@ubuntu.com" \
        "ding@rastersoft.com"
    do
        if gnome-extensions list --enabled | grep -Fqx "$uuid"; then
            log "Verified enabled extension: $uuid"
        else
            warn "Extension is not enabled yet: $uuid"
            ((failure_count += 1))
        fi
    done

    if systemctl --user is-enabled rice-wallpaper-rotator.service \
        >/dev/null 2>&1; then
        log "Verified wallpaper rotation service."
    else
        warn "Wallpaper rotation service is not enabled."
        ((failure_count += 1))
    fi

    if ((failure_count > 0)); then
        warn "Verification completed with $failure_count warning(s). Review $LOG_FILE"
    else
        log "Every final verification check passed."
    fi
}

log "Creating Windows-style Ubuntu desktop launchers."
create_desktop_launcher \
    "Google Chrome" \
    google-chrome.desktop \
    google-chrome-stable.desktop
create_desktop_launcher \
    "Visual Studio Code" \
    code.desktop \
    visual-studio-code.desktop
create_desktop_launcher \
    "Files" \
    org.gnome.Nautilus.desktop \
    nautilus.desktop
create_desktop_launcher \
    "Terminal" \
    org.gnome.Terminal.desktop \
    gnome-terminal.desktop \
    org.gnome.Ptyxis.desktop
create_desktop_launcher "Audacious" audacious.desktop

configure_ding
remove_managed_gdm_branding

git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global push.default simple

if systemctl list-unit-files power-profiles-daemon.service \
    >/dev/null 2>&1; then
    run_root systemctl enable --now power-profiles-daemon.service || true
fi

update-desktop-database "$APPLICATION_DIR" >/dev/null 2>&1 || true
nautilus -q >/dev/null 2>&1 || true
verify_installation

log "Desktop finalization is complete. Log out and back in once."

