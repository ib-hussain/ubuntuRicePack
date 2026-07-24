#!/usr/bin/env bash
# Apply and verify Ibrahim's curated Ubuntu GNOME 50 configuration.
#
# The large, schema-aware settings importer is the single source of truth.
# This stage deliberately does not run `dconf load /`.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

readonly BEST_SETTINGS_SCRIPT="$SCRIPT_DIR/apply-ubuntu-gnome-best-settings.sh"
readonly THEME_NAME="MacTahoe-Dark-blue"
readonly ICON_THEME_NAME="Papirus-Dark"

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
    "apps-menu@gnome-shell-extensions.gcampax.github.com"
    "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com"
    "light-style@gnome-shell-extensions.gcampax.github.com"
    "native-window-placement@gnome-shell-extensions.gcampax.github.com"
    "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
    "status-icons@gnome-shell-extensions.gcampax.github.com"
    "window-list@gnome-shell-extensions.gcampax.github.com"
    "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
    "dash-to-dock@micxgx.gmail.com"
    "tiling-assistant@ubuntu.com"
    "snapd-prompting@canonical.com"
    "snapd-search-provider@canonical.com"
)

VERIFY_FAILURES=0
DRY_RUN_REQUESTED=0
REPORT_FILE=""

extension_present() {
    local uuid="$1"

    [[ -f "$TARGET_HOME/.local/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        [[ -f "/usr/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        gnome-extensions list 2>/dev/null | grep -Fxq "$uuid"
}

extension_enabled() {
    local uuid="$1"
    gnome-extensions list --enabled 2>/dev/null | grep -Fxq "$uuid"
}

find_theme_directory() {
    local candidate=""

    for candidate in \
        "$TARGET_HOME/.local/share/themes/$THEME_NAME" \
        "$TARGET_HOME/.themes/$THEME_NAME" \
        "/usr/local/share/themes/$THEME_NAME" \
        "/usr/share/themes/$THEME_NAME"
    do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_icon_theme_directory() {
    local candidate=""

    for candidate in \
        "$TARGET_HOME/.local/share/icons/$ICON_THEME_NAME" \
        "$TARGET_HOME/.icons/$ICON_THEME_NAME" \
        "/usr/local/share/icons/$ICON_THEME_NAME" \
        "/usr/share/icons/$ICON_THEME_NAME"
    do
        if [[ -f "$candidate/index.theme" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

validate_appearance_assets() {
    local theme_dir=""
    local icon_theme_dir=""

    if ! theme_dir="$(find_theme_directory)"; then
        fail "Theme '$THEME_NAME' is not installed. Run stage 02 first."
    fi
    [[ -f "$theme_dir/gtk-3.0/gtk.css" ]] ||
        fail "$THEME_NAME has no GTK 3 stylesheet: $theme_dir/gtk-3.0/gtk.css"
    [[ -f "$theme_dir/gnome-shell/gnome-shell.css" ]] ||
        fail "$THEME_NAME has no GNOME Shell stylesheet: $theme_dir/gnome-shell/gnome-shell.css"

    if [[ -f "$theme_dir/gtk-4.0/gtk.css" ||
        -f "$TARGET_HOME/.config/gtk-4.0/gtk.css" ]]
    then
        log "GTK 4 CSS is installed. Libadwaita still controls its own widgets."
    else
        warn "No GTK 4 CSS overlay was found; GTK 4 apps will use their native style."
    fi

    if ! icon_theme_dir="$(find_icon_theme_directory)"; then
        fail "Icon theme '$ICON_THEME_NAME' is not installed. Check papirus-icon-theme."
    fi

    log "Validated GTK/Shell theme: $theme_dir"
    log "Validated icon theme: $icon_theme_dir"
}

validate_extensions_installed() {
    local uuid=""

    for uuid in "${REQUIRED_ENABLED_EXTENSIONS[@]}"; do
        extension_present "$uuid" ||
            fail "Required extension is missing: $uuid. Run stage 04 first."
    done
}

write_report_line() {
    local category="$1"
    local subject="$2"
    local expected="$3"
    local actual="$4"
    local result="$5"

    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$category" \
        "$subject" \
        "$expected" \
        "$actual" \
        "$result" >>"$REPORT_FILE"
}

verify_gsettings_value() {
    local schema="$1"
    local key="$2"
    local expected="$3"
    local actual=""

    if ! schema_key_exists "$schema" "$key"; then
        write_report_line \
            "gsettings" \
            "$schema $key" \
            "$expected" \
            "schema/key unavailable" \
            "SKIP"
        warn "Verification key is unavailable: $schema $key"
        return 0
    fi

    actual="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [[ "$actual" == "$expected" ]]; then
        write_report_line \
            "gsettings" \
            "$schema $key" \
            "$expected" \
            "$actual" \
            "PASS"
    else
        write_report_line \
            "gsettings" \
            "$schema $key" \
            "$expected" \
            "$actual" \
            "FAIL"
        warn "Setting mismatch: $schema $key (expected $expected, got $actual)"
        VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    fi
}

verify_extension_state() {
    local uuid="$1"
    local expected="$2"
    local actual="not-installed"
    local result="FAIL"

    if extension_present "$uuid"; then
        if extension_enabled "$uuid"; then
            actual="enabled"
        else
            actual="disabled"
        fi
    fi

    if [[ "$actual" == "$expected" ]]; then
        result="PASS"
    elif [[ "$expected" == "disabled" && "$actual" == "not-installed" ]]; then
        # Snap extensions can disappear entirely after the no-Snap stage.
        result="PASS"
    else
        warn "Extension state mismatch: $uuid (expected $expected, got $actual)"
        VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    fi

    write_report_line \
        "extension" \
        "$uuid" \
        "$expected" \
        "$actual" \
        "$result"
}

verify_configuration() {
    local uuid=""
    local report_dir="$STATE_DIR/reports"

    mkdir -p -- "$report_dir"
    REPORT_FILE="$report_dir/gnome-settings-$RUN_ID.tsv"
    printf 'category\tsubject\texpected\tactual\tresult\n' >"$REPORT_FILE"

    verify_gsettings_value \
        org.gnome.desktop.interface \
        gtk-theme \
        "'$THEME_NAME'"
    verify_gsettings_value \
        org.gnome.desktop.interface \
        icon-theme \
        "'$ICON_THEME_NAME'"
    verify_gsettings_value \
        org.gnome.desktop.interface \
        color-scheme \
        "'prefer-dark'"
    verify_gsettings_value \
        org.gnome.desktop.wm.preferences \
        button-layout \
        "':minimize,maximize,close'"
    verify_gsettings_value \
        org.gnome.shell.extensions.user-theme \
        name \
        "'$THEME_NAME'"

    verify_gsettings_value \
        org.gnome.shell.extensions.dash-to-dock \
        dock-position \
        "'BOTTOM'"
    verify_gsettings_value \
        org.gnome.shell.extensions.dash-to-dock \
        dash-max-icon-size \
        "48"
    verify_gsettings_value \
        org.gnome.shell.extensions.dash-to-dock \
        dock-fixed \
        "false"
    verify_gsettings_value \
        org.gnome.shell.extensions.dash-to-dock \
        always-center-icons \
        "true"

    for uuid in "${REQUIRED_ENABLED_EXTENSIONS[@]}"; do
        verify_extension_state "$uuid" enabled
    done
    for uuid in "${REQUIRED_DISABLED_EXTENSIONS[@]}"; do
        verify_extension_state "$uuid" disabled
    done

    log "GNOME settings verification report: $REPORT_FILE"
}

main() {
    local argument=""

    require_user_session
    require_ubuntu
    require_command dconf
    require_command gnome-extensions
    require_command gsettings

    [[ -f "$BEST_SETTINGS_SCRIPT" ]] ||
        fail "Missing curated settings importer: $BEST_SETTINGS_SCRIPT"

    for argument in "$@"; do
        [[ "$argument" == "--dry-run" ]] && DRY_RUN_REQUESTED=1
    done

    validate_appearance_assets
    validate_extensions_installed

    log "Applying the curated Ubuntu GNOME best-settings snapshot."
    bash "$BEST_SETTINGS_SCRIPT" "$@" 2>&1 | tee -a "$LOG_FILE"

    if [[ "$DRY_RUN_REQUESTED" == "1" ]]; then
        log "Dry run complete; post-write verification was intentionally skipped."
        return 0
    fi

    verify_configuration
    if [[ "$VERIFY_FAILURES" -gt 0 ]]; then
        if [[ "${STRICT_GNOME_VERIFY:-0}" == "1" ]]; then
            fail "GNOME verification found $VERIFY_FAILURES mismatch(es)."
        fi
        warn "GNOME verification found $VERIFY_FAILURES mismatch(es)."
        warn "Review $REPORT_FILE; freshly installed Shell extensions may need one logout/login."
    else
        log "All critical appearance, dock, and extension checks passed."
    fi

    log "GNOME settings stage complete. Log out and back in once after installation."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi