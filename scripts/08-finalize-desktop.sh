#!/usr/bin/env bash
# Create Windows-style desktop launchers and produce a final installation audit.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

STRICT_FINAL_VERIFY="${STRICT_FINAL_VERIFY:-0}"
FINAL_FAILURES=0
FINAL_WARNINGS=0
REPORT_FILE=""

readonly -a REQUIRED_ENABLED_EXTENSIONS=(
    "arch-dock-icon@ib-hussain"
    "hidetopbar@mathieu.bidon.ca"
    "start-overlay-in-application-view@Hex_cz"
    "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "ubuntu-dock@ubuntu.com"
    "ding@rastersoft.com"
    "ubuntu-appindicators@ubuntu.com"
    "web-search-provider@ubuntu.com"
)

readonly -a REQUIRED_DISABLED_EXTENSIONS=(
    "dash-to-dock@micxgx.gmail.com"
    "tiling-assistant@ubuntu.com"
    "snapd-prompting@canonical.com"
    "snapd-search-provider@canonical.com"
)

DESKTOP_DIR=""
APPLICATION_DIR="$TARGET_HOME/.local/share/applications"

report_line() {
    local category="$1"
    local subject="$2"
    local expected="$3"
    local actual="$4"
    local result="$5"

    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$category" "$subject" "$expected" "$actual" "$result" \
        >>"$REPORT_FILE"
}

record_failure() {
    local category="$1"
    local subject="$2"
    local expected="$3"
    local actual="$4"

    report_line "$category" "$subject" "$expected" "$actual" FAIL
    warn "$category check failed: $subject (expected $expected; got $actual)"
    FINAL_FAILURES=$((FINAL_FAILURES + 1))
}

record_warning() {
    local category="$1"
    local subject="$2"
    local expected="$3"
    local actual="$4"

    report_line "$category" "$subject" "$expected" "$actual" WARN
    warn "$category check warning: $subject (expected $expected; got $actual)"
    FINAL_WARNINGS=$((FINAL_WARNINGS + 1))
}

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

    destination_file="$DESKTOP_DIR/$(basename -- "$source_file")"
    backup_path "$destination_file"
    cp -a -- "$source_file" "$destination_file"
    trust_launcher "$destination_file"
    log "Created desktop launcher: $display_name -> $destination_file"
}

create_desktop_launchers() {
    log "Creating the requested Windows-style desktop launchers."

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
        org.gnome.Ptyxis.desktop \
        org.gnome.Terminal.desktop \
        gnome-terminal.desktop
    create_desktop_launcher \
        "Audacious" \
        audacious.desktop
}

configure_ding() {
    local schema="org.gnome.shell.extensions.ding"

    if ! schema_exists "$schema"; then
        warn "DING is unavailable; launchers exist but may not appear on the desktop."
        return 0
    fi

    gs_set "$schema" show-trash "true"
    gs_set "$schema" show-home "false"
    gs_set "$schema" show-volumes "false"
    gs_set "$schema" show-network-volumes "false"
    gs_set "$schema" show-link-emblem "true"

    if gnome-extensions list 2>/dev/null |
        grep -Fqx "ding@rastersoft.com"
    then
        gnome-extensions enable "ding@rastersoft.com" >/dev/null 2>&1 || true
    fi
}

remove_managed_gdm_branding() {
    local removed=0
    local managed_file=""

    # The requested GDM-logo value is effectively zero: no logo/background
    # override is installed. Remove only files managed by earlier rice builds.
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

    if ((removed == 1)); then
        run_root dconf update
        log "Removed GDM branding left by an earlier UbuntuRicePack revision."
    else
        log "No UbuntuRicePack GDM logo or background override is installed."
    fi
}

configure_git() {
    git config --global user.name "Ibrahim Hussain"
    git config --global user.email "ibrahimbeaconarion@gmail.com"
    git config --global init.defaultBranch main
    git config --global core.editor nano
    git config --global push.default simple
}

enable_power_profiles_daemon() {
    if ! have_systemd; then
        warn "systemd is not PID 1; power-profiles-daemon enablement was skipped."
        return 0
    fi

    if systemctl list-unit-files power-profiles-daemon.service \
        >/dev/null 2>&1
    then
        run_root systemctl enable --now power-profiles-daemon.service ||
            warn "Could not enable power-profiles-daemon."
    fi
}

verify_command() {
    local command_name="$1"
    local command_path=""

    if command_path="$(command -v "$command_name" 2>/dev/null)"; then
        report_line command "$command_name" available "$command_path" PASS
    else
        record_failure command "$command_name" available "not found"
    fi
}

verify_any_command() {
    local subject="$1"
    shift
    local command_name=""
    local command_path=""

    for command_name in "$@"; do
        if command_path="$(command -v "$command_name" 2>/dev/null)"; then
            report_line command "$subject" available "$command_path" PASS
            return 0
        fi
    done

    record_failure command "$subject" available "none of: $*"
}

verify_package() {
    local package_name="$1"
    local status=""

    status="$(
        dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null ||
            true
    )"
    if [[ "$status" == "installed" ]]; then
        report_line package "$package_name" installed installed PASS
    else
        record_failure package "$package_name" installed "${status:-not installed}"
    fi
}

verify_desktop_launcher() {
    local display_name="$1"
    shift
    local desktop_id=""

    for desktop_id in "$@"; do
        if [[ -x "$DESKTOP_DIR/$desktop_id" ]]; then
            report_line \
                desktop-launcher \
                "$display_name" \
                executable \
                "$DESKTOP_DIR/$desktop_id" \
                PASS
            return 0
        fi
    done

    record_failure \
        desktop-launcher \
        "$display_name" \
        executable \
        "not found in $DESKTOP_DIR"
}

extension_present() {
    local uuid="$1"

    [[ -f "$TARGET_HOME/.local/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        [[ -f "/usr/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        gnome-extensions list 2>/dev/null | grep -Fqx "$uuid"
}

extension_enabled() {
    local uuid="$1"

    gnome-extensions list --enabled 2>/dev/null | grep -Fqx "$uuid" ||
        gsettings get org.gnome.shell enabled-extensions 2>/dev/null |
            grep -Fq "'$uuid'"
}

verify_extension() {
    local uuid="$1"
    local desired="$2"
    local actual="not-installed"

    if extension_present "$uuid"; then
        if extension_enabled "$uuid"; then
            actual="enabled"
        else
            actual="disabled"
        fi
    fi

    if [[ "$actual" == "$desired" ||
        ("$desired" == "disabled" && "$actual" == "not-installed") ]]
    then
        report_line extension "$uuid" "$desired" "$actual" PASS
    else
        record_failure extension "$uuid" "$desired" "$actual"
    fi
}

verify_gsettings() {
    local schema="$1"
    local key="$2"
    local expected="$3"
    local actual=""

    if ! schema_key_exists "$schema" "$key"; then
        record_warning \
            gsettings \
            "$schema $key" \
            "$expected" \
            "schema/key unavailable"
        return 0
    fi

    actual="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [[ "$actual" == "$expected" ]]; then
        report_line gsettings "$schema $key" "$expected" "$actual" PASS
    else
        record_failure gsettings "$schema $key" "$expected" "$actual"
    fi
}

verify_nerd_fonts() {
    local family=""
    local match=""

    if ! command -v fc-list >/dev/null 2>&1; then
        record_failure fontconfig fc-list available "not found"
        return 0
    fi

    for family in \
        "JetBrainsMono Nerd Font" \
        "NotoSansM Nerd Font" \
        "Symbols Nerd Font"
    do
        if match="$(font_family_match "$family")"; then
            report_line font "$family" installed "$match" PASS
        else
            record_failure font "$family" installed "not matched"
        fi
    done
}

verify_wallpapers() {
    local wallpaper_dir="$TARGET_HOME/.local/share/backgrounds/rice/wallpapers"
    local count=0

    if [[ -d "$wallpaper_dir" ]]; then
        count="$(
            find "$wallpaper_dir" -type f \
                \( -iname '*.png' -o -iname '*.jpg' -o \
                    -iname '*.jpeg' -o -iname '*.webp' \) |
                wc -l
        )"
    fi

    if ((count > 0)); then
        report_line wallpaper downloaded-files ">0" "$count" PASS
    else
        record_failure wallpaper downloaded-files ">0" "$count"
    fi

    if systemctl --user is-enabled rice-wallpaper-rotator.service \
        >/dev/null 2>&1
    then
        report_line \
            service \
            rice-wallpaper-rotator.service \
            enabled \
            enabled \
            PASS
    else
        record_failure \
            service \
            rice-wallpaper-rotator.service \
            enabled \
            "not enabled"
    fi
}

verify_no_gdm_branding() {
    local managed_file=""

    for managed_file in \
        /etc/dconf/db/gdm.d/90-rice-login-background \
        /etc/dconf/db/gdm.d/90-ubuntuRicePack-logo \
        /etc/dconf/db/gdm.d/90-ubuntu-rice-pack-logo \
        /usr/local/share/ubuntuRicePack/ib.png
    do
        if run_root test -e "$managed_file"; then
            record_failure gdm "$managed_file" absent present
        else
            report_line gdm "$managed_file" absent absent PASS
        fi
    done
}

write_final_report() {
    local uuid=""
    local report_dir="$STATE_DIR/reports"

    mkdir -p -- "$report_dir"
    REPORT_FILE="$report_dir/final-desktop-$RUN_ID.tsv"
    printf 'category\tsubject\texpected\tactual\tresult\n' >"$REPORT_FILE"

    log "Running the comprehensive UbuntuRicePack desktop verification."

    for uuid in \
        git curl gsettings gnome-extensions fastfetch eza rg fzf zoxide \
        google-chrome-stable code nautilus audacious unrar \
        gnome-browser-connector gnome-screenshot sxhkd vlc
    do
        verify_command "$uuid"
    done
    verify_any_command terminal gnome-terminal ptyxis kgx gnome-console
    verify_any_command ImageMagick magick convert

    for uuid in \
        imagemagick \
        unrar \
        gnome-browser-connector \
        gnome-screenshot \
        sxhkd \
        vlc \
        vlc-plugin-access-extra \
        vlc-plugin-base \
        vlc-plugin-fluidsynth \
        vlc-plugin-jack \
        vlc-plugin-notify \
        vlc-plugin-pipewire \
        vlc-plugin-qt \
        vlc-plugin-samba \
        vlc-plugin-skins2 \
        vlc-plugin-svg \
        vlc-plugin-video-output \
        vlc-plugin-video-splitter \
        vlc-plugin-visualization \
        vlc-l10n
    do
        verify_package "$uuid"
    done

    verify_desktop_launcher \
        "Google Chrome" \
        google-chrome.desktop \
        google-chrome-stable.desktop
    verify_desktop_launcher \
        "Visual Studio Code" \
        code.desktop \
        visual-studio-code.desktop
    verify_desktop_launcher \
        "Files" \
        org.gnome.Nautilus.desktop \
        nautilus.desktop
    verify_desktop_launcher \
        "Terminal" \
        org.gnome.Ptyxis.desktop \
        org.gnome.Terminal.desktop \
        gnome-terminal.desktop
    verify_desktop_launcher "Audacious" audacious.desktop

    for uuid in "${REQUIRED_ENABLED_EXTENSIONS[@]}"; do
        verify_extension "$uuid" enabled
    done
    for uuid in "${REQUIRED_DISABLED_EXTENSIONS[@]}"; do
        verify_extension "$uuid" disabled
    done

    verify_gsettings \
        org.gnome.desktop.interface gtk-theme "'MacTahoe-Dark-blue'"
    verify_gsettings \
        org.gnome.desktop.interface icon-theme "'Papirus-Dark'"
    verify_gsettings \
        org.gnome.desktop.interface color-scheme "'prefer-dark'"
    verify_gsettings \
        org.gnome.shell.extensions.user-theme name "'MacTahoe-Dark-blue'"
    verify_gsettings \
        org.gnome.shell.extensions.dash-to-dock dock-position "'BOTTOM'"
    verify_gsettings \
        org.gnome.shell.extensions.dash-to-dock dash-max-icon-size "48"
    verify_gsettings \
        org.gnome.shell.extensions.dash-to-dock dock-fixed "false"
    verify_gsettings \
        org.gnome.shell.extensions.dash-to-dock always-center-icons "true"

    if schema_key_exists org.gnome.shell.extensions.ding show-trash; then
        verify_gsettings \
            org.gnome.shell.extensions.ding show-trash "true"
    fi

    verify_nerd_fonts
    verify_wallpapers
    verify_no_gdm_branding

    if command -v snap >/dev/null 2>&1 ||
        apt_package_installed snapd
    then
        record_failure no-snap snapd absent present
    else
        report_line no-snap snapd absent absent PASS
    fi

    log "Final desktop verification report: $REPORT_FILE"
}

main() {
    require_gnome_session
    require_ubuntu

    DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    DESKTOP_DIR="${DESKTOP_DIR:-$TARGET_HOME/Desktop}"
    mkdir -p -- "$DESKTOP_DIR" "$APPLICATION_DIR"

    create_desktop_launchers
    configure_ding
    remove_managed_gdm_branding
    configure_git
    enable_power_profiles_daemon

    update-desktop-database "$APPLICATION_DIR" >/dev/null 2>&1 || true
    nautilus -q >/dev/null 2>&1 || true
    write_final_report

    if ((FINAL_FAILURES > 0)); then
        if [[ "$STRICT_FINAL_VERIFY" == "1" ]]; then
            fail "Final verification found $FINAL_FAILURES failure(s)."
        fi
        warn "Final verification found $FINAL_FAILURES failure(s) and $FINAL_WARNINGS warning(s)."
        warn "Review $REPORT_FILE. A freshly installed Shell extension may need one logout/login."
    else
        log "Final verification passed with $FINAL_WARNINGS warning(s)."
    fi

    log "Desktop finalization is complete. Log out and back in once."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
