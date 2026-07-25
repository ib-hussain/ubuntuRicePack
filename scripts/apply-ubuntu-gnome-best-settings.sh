#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# Ibrahim's GNOME 50 "best settings" importer — Ubuntu edition
#
# Source snapshot:
#   Arch Linux, GNOME Shell 50.2, exported 2026-07-24.
#
# This is intentionally a curated, schema-aware importer. It does NOT run
# `dconf load /`, because a root dconf import would also copy stale application
# state, obsolete distro folders, hardware connector names, command histories,
# absolute /home/ibrahim paths, and settings for schemas absent on Ubuntu.
#
# What this script does:
#   - Applies the complete portable desktop, input, privacy, power, window,
#     keybinding, Nautilus, terminal, application, and extension preferences.
#   - Translates Dash-to-Dock intent to Ubuntu Dock.
#   - Resolves installed desktop IDs and terminal/browser commands at runtime.
#   - Creates all seven custom keyboard shortcuts.
#   - Uses an installed rice wallpaper instead of a hard-coded source hostname.
#   - Enables/disables extensions only when their code is already installed.
#   - Backs up the current dconf database before making changes.
#
# Usage:
#   ./apply-ubuntu-gnome-best-settings.sh
#   ./apply-ubuntu-gnome-best-settings.sh --dry-run
#   ./apply-ubuntu-gnome-best-settings.sh --no-backup
#   ./apply-ubuntu-gnome-best-settings.sh --no-extensions
#   ./apply-ubuntu-gnome-best-settings.sh --force
#
# Run this as the target desktop user from a logged-in GNOME session. Do not
# run it with sudo.
###############################################################################

TARGET_PLATFORM="ubuntu"
SCRIPT_VERSION="1.0.0"

DRY_RUN=0
MAKE_BACKUP=1
APPLY_EXTENSIONS=1
FORCE_PLATFORM=0

APPLIED=0
UNCHANGED=0
SKIPPED=0
FAILED=0

declare -A FIXED_SCHEMAS=()
declare -A RELOCATABLE_SCHEMAS=()

log() {
    printf '[GNOME-BEST] %s\n' "$*"
}

warn() {
    printf '[GNOME-BEST] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[GNOME-BEST] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage:
  ./apply-ubuntu-gnome-best-settings.sh [options]

Options:
  --dry-run        Show changes without writing them.
  --no-backup      Do not export the current dconf database first.
  --no-extensions  Apply extension preferences but do not change states.
  --force          Allow use on a distro not identified as Ubuntu.
  --version        Print the script version.
  --help           Show this help.

Run as the target desktop user from a logged-in GNOME session. Do not use sudo.
USAGE
}

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                ;;
            --no-backup)
                MAKE_BACKUP=0
                ;;
            --no-extensions)
                APPLY_EXTENSIONS=0
                ;;
            --force)
                FORCE_PLATFORM=1
                ;;
            --version)
                printf '%s\n' "$SCRIPT_VERSION"
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
        shift
    done
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command is unavailable: $1"
}

validate_environment() {
    if [[ "$EUID" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
        die "Run this script as the GNOME desktop user, not as root."
    fi

    require_command gsettings
    require_command dconf
    require_command grep
    require_command sort

    if [[ "$DRY_RUN" -eq 0 &&
        -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]
    then
        die "No desktop D-Bus session was detected. Log into GNOME and run it in a terminal."
    fi

    local distro_id=""
    local distro_like=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-}"
        distro_like="${ID_LIKE:-}"
    fi

    case "$TARGET_PLATFORM" in
        ubuntu)
            if [[ "$distro_id" != "ubuntu" &&
                " $distro_like " != *" ubuntu "* &&
                "$FORCE_PLATFORM" -eq 0 ]]
            then
                die "This is the Ubuntu edition (detected ID=${distro_id:-unknown}). Use --force only if intentional."
            fi
            ;;
        arch)
            if [[ "$distro_id" != "arch" &&
                " $distro_like " != *" arch "* &&
                "$FORCE_PLATFORM" -eq 0 ]]
            then
                die "This is the Arch edition (detected ID=${distro_id:-unknown}). Use --force only if intentional."
            fi
            ;;
    esac

    if command -v gnome-shell >/dev/null 2>&1; then
        local shell_version=""
        shell_version="$(gnome-shell --version 2>/dev/null || true)"
        log "Detected ${shell_version:-GNOME Shell}"
        if [[ "$shell_version" != *" 50."* ]]; then
            warn "The source snapshot was GNOME 50. Unsupported keys will be skipped."
        fi
    fi
}

load_schema_cache() {
    local schema=""

    while IFS= read -r schema; do
        [[ -n "$schema" ]] && FIXED_SCHEMAS["$schema"]=1
    done < <(gsettings list-schemas)

    while IFS= read -r schema; do
        [[ -n "$schema" ]] && RELOCATABLE_SCHEMAS["$schema"]=1
    done < <(gsettings list-relocatable-schemas)
}

backup_current_settings() {
    [[ "$MAKE_BACKUP" -eq 1 ]] || return 0

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] Would back up the current dconf database."
        return 0
    fi

    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local backup_dir="$state_home/ubuntuRicePack/gnome-settings-backups"
    local stamp=""
    local backup_file=""

    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_file="$backup_dir/${TARGET_PLATFORM}-before-best-settings-$stamp.dconf"

    umask 077
    mkdir -p "$backup_dir"
    dconf dump / > "$backup_file"

    log "Backup written to: $backup_file"
    log "Rollback command: dconf load / < '$backup_file'"
}

schema_has_key() {
    local schema="$1"
    local key="$2"

    gsettings list-keys "$schema" 2>/dev/null | grep -Fqx "$key"
}

relocatable_schema_has_key() {
    local schema="$1"
    local path="$2"
    local key="$3"

    gsettings list-keys "$schema:$path" 2>/dev/null | grep -Fqx "$key"
}

set_fixed() {
    local schema="$1"
    local key="$2"
    local value="$3"
    local current=""

    if [[ -z "${FIXED_SCHEMAS[$schema]+x}" ]]; then
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if ! schema_has_key "$schema" "$key"; then
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ "$(gsettings writable "$schema" "$key" 2>/dev/null || true)" != "true" ]]; then
        warn "Key is locked by policy: $schema $key"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    current="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [[ "$current" == "$value" ]]; then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[GNOME-BEST] [dry-run] %s %s: %s -> %s\n' \
            "$schema" "$key" "$current" "$value"
        APPLIED=$((APPLIED + 1))
        return 0
    fi

    if gsettings set "$schema" "$key" "$value" >/dev/null 2>&1; then
        APPLIED=$((APPLIED + 1))
    else
        warn "Rejected value for: $schema $key = $value"
        FAILED=$((FAILED + 1))
    fi
}

set_relocatable() {
    local schema="$1"
    local path="$2"
    local key="$3"
    local value="$4"
    local target="$schema:$path"
    local current=""

    if [[ -z "${RELOCATABLE_SCHEMAS[$schema]+x}" ]]; then
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if ! relocatable_schema_has_key "$schema" "$path" "$key"; then
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ "$(gsettings writable "$target" "$key" 2>/dev/null || true)" != "true" ]]; then
        warn "Relocatable key is locked by policy: $target $key"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    current="$(gsettings get "$target" "$key" 2>/dev/null || true)"
    if [[ "$current" == "$value" ]]; then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[GNOME-BEST] [dry-run] %s %s: %s -> %s\n' \
            "$target" "$key" "$current" "$value"
        APPLIED=$((APPLIED + 1))
        return 0
    fi

    if gsettings set "$target" "$key" "$value" >/dev/null 2>&1; then
        APPLIED=$((APPLIED + 1))
    else
        warn "Rejected relocatable value for: $target $key = $value"
        FAILED=$((FAILED + 1))
    fi
}

apply_table() {
    local schema=""
    local key=""
    local value=""

    while IFS='|' read -r schema key value; do
        [[ -z "$schema" || "$schema" == \#* ]] && continue
        set_fixed "$schema" "$key" "$value"
    done
}

desktop_id_exists() {
    local desktop_id="$1"
    local directory=""

    for directory in \
        "$HOME/.local/share/applications" \
        /usr/local/share/applications \
        /usr/share/applications
    do
        [[ -f "$directory/$desktop_id" ]] && return 0
    done

    return 1
}

first_desktop_id() {
    local desktop_id=""

    for desktop_id in "$@"; do
        if desktop_id_exists "$desktop_id"; then
            printf '%s\n' "$desktop_id"
            return 0
        fi
    done

    return 1
}

first_command() {
    local candidate=""

    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

gvariant_string_array() {
    local result="["
    local separator=""
    local item=""

    for item in "$@"; do
        result+="${separator}'$item'"
        separator=", "
    done

    result+="]"
    printf '%s\n' "$result"
}

set_extension_state() {
    local uuid="$1"
    local desired="$2"

    command -v gnome-extensions >/dev/null 2>&1 || {
        SKIPPED=$((SKIPPED + 1))
        return 0
    }

    if ! gnome-extensions list 2>/dev/null | grep -Fqx "$uuid"; then
        if [[ "$desired" == "enable" ]]; then
            warn "Extension is not installed; cannot enable: $uuid"
        fi
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ "$desired" == "enable" ]] &&
        gnome-extensions list --enabled 2>/dev/null | grep -Fqx "$uuid"
    then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$desired" == "disable" ]] &&
        ! gnome-extensions list --enabled 2>/dev/null | grep -Fqx "$uuid"
    then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] Would $desired extension: $uuid"
        APPLIED=$((APPLIED + 1))
        return 0
    fi

    if gnome-extensions "$desired" "$uuid" >/dev/null 2>&1; then
        APPLIED=$((APPLIED + 1))
    else
        warn "Could not $desired extension: $uuid"
        FAILED=$((FAILED + 1))
    fi
}

apply_core_desktop_settings() {
    log "Applying appearance, desktop, input, privacy, power, and window behavior."

    apply_table <<'SETTINGS'
# Accessibility
org.gnome.desktop.a11y|always-show-text-caret|false
org.gnome.desktop.a11y|always-show-universal-access-status|false
org.gnome.desktop.a11y.magnifier|cross-hairs-length|58
org.gnome.desktop.a11y.magnifier|mag-factor|1.0

# Background and screensaver; the URI itself is resolved later.
org.gnome.desktop.background|color-shading-type|'solid'
org.gnome.desktop.background|picture-opacity|100
org.gnome.desktop.background|picture-options|'scaled'
org.gnome.desktop.background|primary-color|'#000000'
org.gnome.desktop.background|secondary-color|'#000000'
org.gnome.desktop.background|show-desktop-icons|false
org.gnome.desktop.screensaver|color-shading-type|'solid'
org.gnome.desktop.screensaver|embedded-keyboard-command|''
org.gnome.desktop.screensaver|embedded-keyboard-enabled|false
org.gnome.desktop.screensaver|idle-activation-enabled|true
org.gnome.desktop.screensaver|lock-delay|uint32 3600
org.gnome.desktop.screensaver|lock-enabled|false
org.gnome.desktop.screensaver|logout-command|''
org.gnome.desktop.screensaver|logout-delay|uint32 7200
org.gnome.desktop.screensaver|logout-enabled|false
org.gnome.desktop.screensaver|picture-opacity|100
org.gnome.desktop.screensaver|picture-options|'scaled'
org.gnome.desktop.screensaver|primary-color|'#000000'
org.gnome.desktop.screensaver|restart-enabled|false
org.gnome.desktop.screensaver|secondary-color|'#000000'
org.gnome.desktop.screensaver|show-full-name-in-top-bar|true
org.gnome.desktop.screensaver|status-message-enabled|true
org.gnome.desktop.screensaver|user-switch-enabled|true

# Break reminders, date, time, language, and keyboard source.
org.gnome.desktop.break-reminders|selected-breaks|@as []
org.gnome.desktop.break-reminders.eyesight|play-sound|true
org.gnome.desktop.break-reminders.movement|duration-seconds|uint32 300
org.gnome.desktop.break-reminders.movement|interval-seconds|uint32 1800
org.gnome.desktop.break-reminders.movement|play-sound|true
org.gnome.desktop.calendar|show-weekdate|true
org.gnome.desktop.calendar|week-start-day|'monday'
org.gnome.desktop.datetime|automatic-timezone|true
org.gnome.desktop.input-sources|current|uint32 0
org.gnome.desktop.input-sources|mru-sources|@a(ss) []
org.gnome.desktop.input-sources|per-window|false
org.gnome.desktop.input-sources|show-all-sources|false
org.gnome.desktop.input-sources|sources|[('xkb', 'us')]
org.gnome.desktop.input-sources|xkb-model|'pc105+inet'
org.gnome.desktop.input-sources|xkb-options|@as []

# Interface and theme.
org.gnome.desktop.interface|accent-color|'blue'
org.gnome.desktop.interface|avatar-directories|@as []
org.gnome.desktop.interface|can-change-accels|false
org.gnome.desktop.interface|clock-format|'24h'
org.gnome.desktop.interface|clock-show-date|true
org.gnome.desktop.interface|clock-show-seconds|false
org.gnome.desktop.interface|clock-show-weekday|true
org.gnome.desktop.interface|color-scheme|'prefer-dark'
org.gnome.desktop.interface|cursor-blink|true
org.gnome.desktop.interface|cursor-blink-time|1200
org.gnome.desktop.interface|cursor-blink-timeout|10
org.gnome.desktop.interface|cursor-size|24
org.gnome.desktop.interface|cursor-theme|'Adwaita'
org.gnome.desktop.interface|document-font-name|'Adwaita Sans 12'
org.gnome.desktop.interface|enable-animations|true
org.gnome.desktop.interface|enable-hot-corners|true
org.gnome.desktop.interface|font-antialiasing|'grayscale'
org.gnome.desktop.interface|font-hinting|'slight'
org.gnome.desktop.interface|font-name|'Adwaita Sans 11'
org.gnome.desktop.interface|font-rendering|'automatic'
org.gnome.desktop.interface|font-rgba-order|'rgb'
org.gnome.desktop.interface|gtk-enable-primary-paste|false
org.gnome.desktop.interface|gtk-im-module|''
org.gnome.desktop.interface|gtk-im-preedit-style|'callback'
org.gnome.desktop.interface|gtk-im-status-style|'callback'
org.gnome.desktop.interface|gtk-key-theme|'Default'
org.gnome.desktop.interface|gtk-theme|'MacTahoe-Dark-blue'
org.gnome.desktop.interface|gtk-timeout-initial|200
org.gnome.desktop.interface|gtk-timeout-repeat|20
org.gnome.desktop.interface|icon-theme|'Papirus-Dark'
org.gnome.desktop.interface|locate-pointer|false
org.gnome.desktop.interface|menubar-accel|'F10'
org.gnome.desktop.interface|menubar-detachable|false
org.gnome.desktop.interface|menus-have-tearoff|false
org.gnome.desktop.interface|monospace-font-name|'Adwaita Mono 11'
org.gnome.desktop.interface|overlay-scrolling|true
org.gnome.desktop.interface|scaling-factor|uint32 0
org.gnome.desktop.interface|show-battery-percentage|true
org.gnome.desktop.interface|text-scaling-factor|1.0
org.gnome.desktop.interface|toolbar-detachable|false
org.gnome.desktop.interface|toolbar-icons-size|'large'
org.gnome.desktop.interface|toolbar-style|'both-horiz'
org.gnome.desktop.interface|toolkit-accessibility|false

# Lockdown and removable-media behavior.
org.gnome.desktop.lockdown|disable-application-handlers|false
org.gnome.desktop.lockdown|disable-command-line|false
org.gnome.desktop.lockdown|disable-lock-screen|false
org.gnome.desktop.lockdown|disable-log-out|false
org.gnome.desktop.lockdown|disable-print-setup|false
org.gnome.desktop.lockdown|disable-printing|false
org.gnome.desktop.lockdown|disable-save-to-disk|false
org.gnome.desktop.lockdown|disable-show-password|false
org.gnome.desktop.lockdown|disable-user-switching|false
org.gnome.desktop.lockdown|mount-removable-storage-devices-as-read-only|false
org.gnome.desktop.lockdown|user-administration-disabled|false
org.gnome.desktop.media-handling|automount|true
org.gnome.desktop.media-handling|automount-open|true
org.gnome.desktop.media-handling|autorun-never|true
org.gnome.desktop.media-handling|autorun-x-content-ignore|@as []
org.gnome.desktop.media-handling|autorun-x-content-open-folder|@as []
org.gnome.desktop.media-handling|autorun-x-content-start-app|['x-content/unix-software', 'x-content/ostree-repository']

# Notifications and privacy.
org.gnome.desktop.notifications|show-banners|true
org.gnome.desktop.notifications|show-in-lock-screen|false
org.gnome.desktop.privacy|disable-camera|false
org.gnome.desktop.privacy|disable-microphone|false
org.gnome.desktop.privacy|disable-sound-output|false
org.gnome.desktop.privacy|hide-identity|false
org.gnome.desktop.privacy|old-files-age|uint32 30
org.gnome.desktop.privacy|privacy-screen|false
org.gnome.desktop.privacy|recent-files-max-age|-1
org.gnome.desktop.privacy|remember-app-usage|true
org.gnome.desktop.privacy|remember-recent-files|true
org.gnome.desktop.privacy|remove-old-temp-files|false
org.gnome.desktop.privacy|remove-old-trash-files|false
org.gnome.desktop.privacy|report-technical-problems|false
org.gnome.desktop.privacy|send-software-usage-stats|false
org.gnome.desktop.privacy|show-full-name-in-top-bar|true
org.gnome.desktop.privacy|usb-protection|true
org.gnome.desktop.privacy|usb-protection-level|'lockscreen'

# Keyboard, mouse, and touchpad.
org.gnome.desktop.peripherals.keyboard|delay|uint32 500
org.gnome.desktop.peripherals.keyboard|numlock-state|false
org.gnome.desktop.peripherals.keyboard|remember-numlock-state|true
org.gnome.desktop.peripherals.keyboard|repeat|true
org.gnome.desktop.peripherals.keyboard|repeat-interval|uint32 30
org.gnome.desktop.peripherals.mouse|accel-profile|'default'
org.gnome.desktop.peripherals.mouse|double-click|400
org.gnome.desktop.peripherals.mouse|drag-threshold|8
org.gnome.desktop.peripherals.mouse|left-handed|false
org.gnome.desktop.peripherals.mouse|middle-click-emulation|false
org.gnome.desktop.peripherals.mouse|natural-scroll|false
org.gnome.desktop.peripherals.mouse|speed|1.0
org.gnome.desktop.peripherals.touchpad|accel-profile|'default'
org.gnome.desktop.peripherals.touchpad|click-method|'fingers'
org.gnome.desktop.peripherals.touchpad|disable-while-typing|true
org.gnome.desktop.peripherals.touchpad|disable-while-typing-timeout|uint32 500
org.gnome.desktop.peripherals.touchpad|edge-scrolling-enabled|false
org.gnome.desktop.peripherals.touchpad|left-handed|'mouse'
org.gnome.desktop.peripherals.touchpad|middle-click-emulation|false
org.gnome.desktop.peripherals.touchpad|natural-scroll|true
org.gnome.desktop.peripherals.touchpad|send-events|'enabled'
org.gnome.desktop.peripherals.touchpad|speed|0.0
org.gnome.desktop.peripherals.touchpad|tap-and-drag|true
org.gnome.desktop.peripherals.touchpad|tap-and-drag-lock|false
org.gnome.desktop.peripherals.touchpad|tap-button-map|'default'
org.gnome.desktop.peripherals.touchpad|tap-to-click|true
org.gnome.desktop.peripherals.touchpad|two-finger-scrolling-enabled|true

# Session, screen-time, search, sound, and thumbnails.
org.gnome.desktop.screen-time-limits|daily-limit-enabled|false
org.gnome.desktop.screen-time-limits|daily-limit-seconds|uint32 28800
org.gnome.desktop.screen-time-limits|grayscale|true
org.gnome.desktop.screen-time-limits|history-enabled|true
org.gnome.desktop.search-providers|disable-external|false
org.gnome.desktop.search-providers|disabled|@as []
org.gnome.desktop.search-providers|enabled|@as []
org.gnome.desktop.search-providers|sort-order|['org.gnome.Settings.desktop', 'org.gnome.Contacts.desktop', 'org.gnome.Nautilus.desktop']
org.gnome.desktop.session|idle-delay|uint32 0
org.gnome.desktop.session|save-restore|true
org.gnome.desktop.session|session-name|'gnome'
org.gnome.desktop.sound|allow-volume-above-100-percent|false
org.gnome.desktop.sound|event-sounds|true
org.gnome.desktop.sound|input-feedback-sounds|false
org.gnome.desktop.sound|theme-name|'freedesktop'
org.gnome.desktop.thumbnail-cache|maximum-age|180
org.gnome.desktop.thumbnail-cache|maximum-size|512
org.gnome.desktop.thumbnailers|disable|@as []
org.gnome.desktop.thumbnailers|disable-all|false

# Window manager and Mutter behavior.
org.gnome.desktop.wm.preferences|action-double-click-titlebar|'toggle-maximize'
org.gnome.desktop.wm.preferences|action-middle-click-titlebar|'none'
org.gnome.desktop.wm.preferences|action-right-click-titlebar|'menu'
org.gnome.desktop.wm.preferences|audible-bell|true
org.gnome.desktop.wm.preferences|auto-raise|false
org.gnome.desktop.wm.preferences|auto-raise-delay|500
org.gnome.desktop.wm.preferences|button-layout|':minimize,maximize,close'
org.gnome.desktop.wm.preferences|disable-workarounds|false
org.gnome.desktop.wm.preferences|focus-mode|'click'
org.gnome.desktop.wm.preferences|focus-new-windows|'smart'
org.gnome.desktop.wm.preferences|mouse-button-modifier|'disabled'
org.gnome.desktop.wm.preferences|num-workspaces|1
org.gnome.desktop.wm.preferences|raise-on-click|true
org.gnome.desktop.wm.preferences|resize-with-right-button|false
org.gnome.desktop.wm.preferences|theme|'Adwaita'
org.gnome.desktop.wm.preferences|titlebar-font|'Adwaita Sans Bold 11'
org.gnome.desktop.wm.preferences|titlebar-uses-system-font|true
org.gnome.desktop.wm.preferences|visual-bell|false
org.gnome.desktop.wm.preferences|visual-bell-type|'fullscreen-flash'
org.gnome.desktop.wm.preferences|workspace-names|@as []
org.gnome.mutter|attach-modal-dialogs|true
org.gnome.mutter|auto-maximize|true
org.gnome.mutter|center-new-windows|true
org.gnome.mutter|check-alive-timeout|uint32 5000
org.gnome.mutter|draggable-border-width|10
org.gnome.mutter|dynamic-workspaces|false
org.gnome.mutter|edge-tiling|true
org.gnome.mutter|experimental-features|@as []
org.gnome.mutter|focus-change-on-pointer-rest|true
org.gnome.mutter|locate-pointer-key|'Control_L'
org.gnome.mutter|overlay-key|'Super_L'
org.gnome.mutter|workspaces-only-on-primary|true
org.gnome.mutter.wayland|xwayland-allow-byte-swapped-clients|false
org.gnome.mutter.wayland|xwayland-allow-grabs|false
org.gnome.mutter.wayland|xwayland-disable-extension|@as []
org.gnome.mutter.wayland|xwayland-grab-access-rules|@as []
org.gnome.mutter.wayland|xwayland-scaling-factor|0.0

# GNOME Shell behavior. Extension state and favorites are handled later.
org.gnome.shell|allow-extension-installation|true
org.gnome.shell|always-show-log-out|false
org.gnome.shell|development-tools|true
org.gnome.shell|disable-extension-version-validation|false
org.gnome.shell|disable-user-extensions|false
org.gnome.shell|last-selected-power-profile|'performance'
org.gnome.shell|remember-mount-password|false
org.gnome.shell.app-switcher|current-workspace-only|false
org.gnome.shell.window-switcher|app-icon-mode|'both'
org.gnome.shell.window-switcher|current-workspace-only|true

# Power, color, and housekeeping.
org.gnome.settings-daemon.plugins.color|night-light-enabled|false
org.gnome.settings-daemon.plugins.color|night-light-schedule-automatic|false
org.gnome.settings-daemon.plugins.color|night-light-schedule-from|20.0
org.gnome.settings-daemon.plugins.color|night-light-schedule-to|6.0
org.gnome.settings-daemon.plugins.color|night-light-temperature|uint32 2700
org.gnome.settings-daemon.plugins.color|recalibrate-display-threshold|uint32 0
org.gnome.settings-daemon.plugins.color|recalibrate-printer-threshold|uint32 0
org.gnome.settings-daemon.plugins.housekeeping|donation-reminder-enabled|true
org.gnome.settings-daemon.plugins.housekeeping|free-percent-notify|0.050000000000000003
org.gnome.settings-daemon.plugins.housekeeping|free-percent-notify-again|0.01
org.gnome.settings-daemon.plugins.housekeeping|free-size-gb-no-notify|1
org.gnome.settings-daemon.plugins.housekeeping|ignore-paths|@as []
org.gnome.settings-daemon.plugins.housekeeping|min-notify-period|10
org.gnome.settings-daemon.plugins.power|ambient-enabled|true
org.gnome.settings-daemon.plugins.power|idle-brightness|30
org.gnome.settings-daemon.plugins.power|idle-dim|true
org.gnome.settings-daemon.plugins.power|power-button-action|'interactive'
org.gnome.settings-daemon.plugins.power|power-saver-profile-on-low-battery|true
org.gnome.settings-daemon.plugins.power|sleep-inactive-ac-timeout|900
org.gnome.settings-daemon.plugins.power|sleep-inactive-ac-type|'suspend'
org.gnome.settings-daemon.plugins.power|sleep-inactive-battery-timeout|900
org.gnome.settings-daemon.plugins.power|sleep-inactive-battery-type|'suspend'
org.gnome.settings-daemon.plugins.xsettings|disabled-gtk-modules|@as []
org.gnome.settings-daemon.plugins.xsettings|enabled-gtk-modules|@as []
org.gnome.settings-daemon.plugins.xsettings|overrides|@a{sv} {}

# Default terminal routing.
org.gnome.desktop.default-applications.terminal|exec|'xdg-terminal-exec'
org.gnome.desktop.default-applications.terminal|exec-arg|'--'
SETTINGS
}

apply_window_and_shell_keybindings() {
    log "Applying the complete window-manager, Shell, and Mutter keymap."

    apply_table <<'SETTINGS'
# Window-manager keybindings
org.gnome.desktop.wm.keybindings|activate-window-menu|['<Alt>space']
org.gnome.desktop.wm.keybindings|always-on-top|@as []
org.gnome.desktop.wm.keybindings|begin-move|['<Alt>F7']
org.gnome.desktop.wm.keybindings|begin-resize|['<Alt>F8']
org.gnome.desktop.wm.keybindings|close|['<Shift><Control>w']
org.gnome.desktop.wm.keybindings|cycle-group|['<Alt>F6']
org.gnome.desktop.wm.keybindings|cycle-group-backward|['<Shift><Alt>F6']
org.gnome.desktop.wm.keybindings|cycle-panels|['<Control><Alt>Escape']
org.gnome.desktop.wm.keybindings|cycle-panels-backward|['<Shift><Control><Alt>Escape']
org.gnome.desktop.wm.keybindings|cycle-windows|['<Alt>Escape']
org.gnome.desktop.wm.keybindings|cycle-windows-backward|['<Shift><Alt>Escape']
org.gnome.desktop.wm.keybindings|lower|@as []
org.gnome.desktop.wm.keybindings|maximize|['<Super>Up']
org.gnome.desktop.wm.keybindings|maximize-horizontally|@as []
org.gnome.desktop.wm.keybindings|maximize-vertically|@as []
org.gnome.desktop.wm.keybindings|minimize|['<Super>q']
org.gnome.desktop.wm.keybindings|move-to-center|@as []
org.gnome.desktop.wm.keybindings|move-to-corner-ne|@as []
org.gnome.desktop.wm.keybindings|move-to-corner-nw|@as []
org.gnome.desktop.wm.keybindings|move-to-corner-se|@as []
org.gnome.desktop.wm.keybindings|move-to-corner-sw|@as []
org.gnome.desktop.wm.keybindings|move-to-monitor-down|['<Super><Shift>Down']
org.gnome.desktop.wm.keybindings|move-to-monitor-left|['<Super><Shift>Left']
org.gnome.desktop.wm.keybindings|move-to-monitor-right|['<Super><Shift>Right']
org.gnome.desktop.wm.keybindings|move-to-monitor-up|['<Super><Shift>Up']
org.gnome.desktop.wm.keybindings|move-to-side-e|@as []
org.gnome.desktop.wm.keybindings|move-to-side-n|@as []
org.gnome.desktop.wm.keybindings|move-to-side-s|@as []
org.gnome.desktop.wm.keybindings|move-to-side-w|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-1|['<Super><Shift>Home']
org.gnome.desktop.wm.keybindings|move-to-workspace-2|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-3|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-4|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-5|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-6|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-7|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-8|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-9|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-10|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-11|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-12|@as []
org.gnome.desktop.wm.keybindings|move-to-workspace-down|['<Control><Shift><Alt>Down']
org.gnome.desktop.wm.keybindings|move-to-workspace-last|['<Super><Shift>End']
org.gnome.desktop.wm.keybindings|move-to-workspace-left|['<Super><Shift>Page_Up', '<Super><Shift>KP_Prior', '<Super><Shift><Alt>Left', '<Control><Shift><Alt>Left']
org.gnome.desktop.wm.keybindings|move-to-workspace-right|['<Super><Shift>Page_Down', '<Super><Shift>KP_Next', '<Super><Shift><Alt>Right', '<Control><Shift><Alt>Right']
org.gnome.desktop.wm.keybindings|move-to-workspace-up|['<Control><Shift><Alt>Up']
org.gnome.desktop.wm.keybindings|panel-main-menu|@as []
org.gnome.desktop.wm.keybindings|panel-run-dialog|['<Alt>F2']
org.gnome.desktop.wm.keybindings|raise|@as []
org.gnome.desktop.wm.keybindings|raise-or-lower|@as []
org.gnome.desktop.wm.keybindings|set-spew-mark|@as []
org.gnome.desktop.wm.keybindings|show-desktop|['<Super>d']
org.gnome.desktop.wm.keybindings|switch-applications|['<Alt>Tab']
org.gnome.desktop.wm.keybindings|switch-applications-backward|['<Shift><Super>Tab', '<Shift><Alt>Tab']
org.gnome.desktop.wm.keybindings|switch-group|['<Super>Above_Tab', '<Alt>Above_Tab']
org.gnome.desktop.wm.keybindings|switch-group-backward|['<Shift><Super>Above_Tab', '<Shift><Alt>Above_Tab']
org.gnome.desktop.wm.keybindings|switch-input-source|['<Super>space', 'XF86Keyboard']
org.gnome.desktop.wm.keybindings|switch-input-source-backward|['<Shift><Super>space', '<Shift>XF86Keyboard']
org.gnome.desktop.wm.keybindings|switch-panels|['<Control><Alt>Tab']
org.gnome.desktop.wm.keybindings|switch-panels-backward|['<Shift><Control><Alt>Tab']
org.gnome.desktop.wm.keybindings|switch-to-workspace-1|['<Super>Home']
org.gnome.desktop.wm.keybindings|switch-to-workspace-2|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-3|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-4|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-5|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-6|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-7|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-8|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-9|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-10|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-11|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-12|@as []
org.gnome.desktop.wm.keybindings|switch-to-workspace-down|['<Control><Alt>Down']
org.gnome.desktop.wm.keybindings|switch-to-workspace-last|['<Super>End']
org.gnome.desktop.wm.keybindings|switch-to-workspace-left|['<Super>Page_Up', '<Super>KP_Prior', '<Super><Alt>Left', '<Control><Alt>Left']
org.gnome.desktop.wm.keybindings|switch-to-workspace-right|['<Super>Page_Down', '<Super>KP_Next', '<Super><Alt>Right', '<Control><Alt>Right']
org.gnome.desktop.wm.keybindings|switch-to-workspace-up|['<Control><Alt>Up']
org.gnome.desktop.wm.keybindings|switch-windows|@as []
org.gnome.desktop.wm.keybindings|switch-windows-backward|@as []
org.gnome.desktop.wm.keybindings|toggle-above|@as []
org.gnome.desktop.wm.keybindings|toggle-fullscreen|['<Super>f']
org.gnome.desktop.wm.keybindings|toggle-maximized|['<Alt>F10']
org.gnome.desktop.wm.keybindings|toggle-on-all-workspaces|@as []
org.gnome.desktop.wm.keybindings|unmaximize|['<Super>Down']

# GNOME Shell keybindings
org.gnome.shell.keybindings|focus-active-notification|['<Super>n']
org.gnome.shell.keybindings|open-new-window-application-1|['<Super><Control>1']
org.gnome.shell.keybindings|open-new-window-application-2|['<Super><Control>2']
org.gnome.shell.keybindings|open-new-window-application-3|['<Super><Control>3']
org.gnome.shell.keybindings|open-new-window-application-4|['<Super><Control>4']
org.gnome.shell.keybindings|open-new-window-application-5|['<Super><Control>5']
org.gnome.shell.keybindings|open-new-window-application-6|['<Super><Control>6']
org.gnome.shell.keybindings|open-new-window-application-7|['<Super><Control>7']
org.gnome.shell.keybindings|open-new-window-application-8|['<Super><Control>8']
org.gnome.shell.keybindings|open-new-window-application-9|['<Super><Control>9']
org.gnome.shell.keybindings|screen-brightness-cycle|['XF86MonBrightnessCycle']
org.gnome.shell.keybindings|screen-brightness-cycle-monitor|['<Shift>XF86MonBrightnessCycle']
org.gnome.shell.keybindings|screen-brightness-down|['XF86MonBrightnessDown']
org.gnome.shell.keybindings|screen-brightness-down-monitor|['<Shift>XF86MonBrightnessDown']
org.gnome.shell.keybindings|screen-brightness-up|['XF86MonBrightnessUp']
org.gnome.shell.keybindings|screen-brightness-up-monitor|['<Shift>XF86MonBrightnessUp']
org.gnome.shell.keybindings|screenshot|@as []
org.gnome.shell.keybindings|screenshot-window|['Print']
org.gnome.shell.keybindings|shift-overview-down|['<Super><Alt>Down']
org.gnome.shell.keybindings|shift-overview-up|['<Super><Alt>Up']
org.gnome.shell.keybindings|show-screen-recording-ui|['<Shift><Super>r']
org.gnome.shell.keybindings|show-screenshot-ui|@as []
org.gnome.shell.keybindings|switch-to-application-1|['<Super>1']
org.gnome.shell.keybindings|switch-to-application-2|['<Super>2']
org.gnome.shell.keybindings|switch-to-application-3|['<Super>3']
org.gnome.shell.keybindings|switch-to-application-4|['<Super>4']
org.gnome.shell.keybindings|switch-to-application-5|['<Super>5']
org.gnome.shell.keybindings|switch-to-application-6|['<Super>6']
org.gnome.shell.keybindings|switch-to-application-7|['<Super>7']
org.gnome.shell.keybindings|switch-to-application-8|['<Super>8']
org.gnome.shell.keybindings|switch-to-application-9|['<Super>9']
org.gnome.shell.keybindings|toggle-application-view|['<Super>s']
org.gnome.shell.keybindings|toggle-message-tray|@as []
org.gnome.shell.keybindings|toggle-overview|['<Super>Tab']
org.gnome.shell.keybindings|toggle-quick-settings|['<Super>a']

# Mutter keybindings
org.gnome.mutter.keybindings|cancel-input-capture|['<Super><Shift>Escape']
org.gnome.mutter.keybindings|rotate-monitor|['XF86RotateWindows']
org.gnome.mutter.keybindings|switch-monitor|['<Super>p', 'XF86Display']
org.gnome.mutter.keybindings|toggle-tiled-left|['<Super>Left']
org.gnome.mutter.keybindings|toggle-tiled-right|['<Super>Right']
org.gnome.mutter.wayland.keybindings|restore-shortcuts|@as []
org.gnome.mutter.wayland.keybindings|switch-to-session-1|['<Primary><Alt>F1']
org.gnome.mutter.wayland.keybindings|switch-to-session-2|['<Primary><Alt>F2']
org.gnome.mutter.wayland.keybindings|switch-to-session-3|['<Primary><Alt>F3']
org.gnome.mutter.wayland.keybindings|switch-to-session-4|['<Primary><Alt>F4']
org.gnome.mutter.wayland.keybindings|switch-to-session-5|['<Primary><Alt>F5']
org.gnome.mutter.wayland.keybindings|switch-to-session-6|['<Primary><Alt>F6']
org.gnome.mutter.wayland.keybindings|switch-to-session-7|['<Primary><Alt>F7']
org.gnome.mutter.wayland.keybindings|switch-to-session-8|['<Primary><Alt>F8']
org.gnome.mutter.wayland.keybindings|switch-to-session-9|['<Primary><Alt>F9']
org.gnome.mutter.wayland.keybindings|switch-to-session-10|['<Primary><Alt>F10']
org.gnome.mutter.wayland.keybindings|switch-to-session-11|['<Primary><Alt>F11']
org.gnome.mutter.wayland.keybindings|switch-to-session-12|['<Primary><Alt>F12']
SETTINGS
}

apply_media_keybindings() {
    log "Applying the complete media-key map."

    apply_table <<'SETTINGS'
org.gnome.settings-daemon.plugins.media-keys|battery-status|['']
org.gnome.settings-daemon.plugins.media-keys|battery-status-static|['XF86Battery']
org.gnome.settings-daemon.plugins.media-keys|calculator|['']
org.gnome.settings-daemon.plugins.media-keys|calculator-static|['XF86Calculator']
org.gnome.settings-daemon.plugins.media-keys|control-center|['']
org.gnome.settings-daemon.plugins.media-keys|control-center-static|['XF86Tools']
org.gnome.settings-daemon.plugins.media-keys|decrease-text-size|['']
org.gnome.settings-daemon.plugins.media-keys|eject|['']
org.gnome.settings-daemon.plugins.media-keys|eject-static|['XF86Eject']
org.gnome.settings-daemon.plugins.media-keys|email|['']
org.gnome.settings-daemon.plugins.media-keys|email-static|['XF86Mail']
org.gnome.settings-daemon.plugins.media-keys|help|['', '<Super>F1']
org.gnome.settings-daemon.plugins.media-keys|hibernate|['']
org.gnome.settings-daemon.plugins.media-keys|hibernate-static|['XF86Suspend', 'XF86Hibernate']
org.gnome.settings-daemon.plugins.media-keys|home|['']
org.gnome.settings-daemon.plugins.media-keys|home-static|['XF86Explorer']
org.gnome.settings-daemon.plugins.media-keys|increase-text-size|['']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-down|['']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-down-static|['XF86KbdBrightnessDown']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-toggle|['']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-toggle-static|['XF86KbdLightOnOff']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-up|['']
org.gnome.settings-daemon.plugins.media-keys|keyboard-brightness-up-static|['XF86KbdBrightnessUp']
org.gnome.settings-daemon.plugins.media-keys|logout|['<Control><Alt>Delete']
org.gnome.settings-daemon.plugins.media-keys|magnifier|['<Alt><Super>8']
org.gnome.settings-daemon.plugins.media-keys|magnifier-zoom-in|['<Control>equal']
org.gnome.settings-daemon.plugins.media-keys|magnifier-zoom-out|['<Control>minus']
org.gnome.settings-daemon.plugins.media-keys|media|['']
org.gnome.settings-daemon.plugins.media-keys|media-static|['XF86AudioMedia']
org.gnome.settings-daemon.plugins.media-keys|mic-mute|['']
org.gnome.settings-daemon.plugins.media-keys|mic-mute-static|['XF86AudioMicMute']
org.gnome.settings-daemon.plugins.media-keys|next|['AudioNext']
org.gnome.settings-daemon.plugins.media-keys|next-static|['XF86AudioNext', '<Ctrl>XF86AudioNext']
org.gnome.settings-daemon.plugins.media-keys|on-screen-keyboard|['']
org.gnome.settings-daemon.plugins.media-keys|pause|@as []
org.gnome.settings-daemon.plugins.media-keys|pause-static|['XF86AudioPause']
org.gnome.settings-daemon.plugins.media-keys|play|['AudioPlay']
org.gnome.settings-daemon.plugins.media-keys|play-static|['XF86AudioPlay', '<Ctrl>XF86AudioPlay']
org.gnome.settings-daemon.plugins.media-keys|playback-forward|['']
org.gnome.settings-daemon.plugins.media-keys|playback-forward-static|['XF86AudioForward']
org.gnome.settings-daemon.plugins.media-keys|playback-random|['']
org.gnome.settings-daemon.plugins.media-keys|playback-random-static|['XF86AudioRandomPlay']
org.gnome.settings-daemon.plugins.media-keys|playback-repeat|['']
org.gnome.settings-daemon.plugins.media-keys|playback-repeat-static|['XF86AudioRepeat']
org.gnome.settings-daemon.plugins.media-keys|playback-rewind|['']
org.gnome.settings-daemon.plugins.media-keys|playback-rewind-static|['XF86AudioRewind']
org.gnome.settings-daemon.plugins.media-keys|power|['']
org.gnome.settings-daemon.plugins.media-keys|power-static|['XF86PowerOff']
org.gnome.settings-daemon.plugins.media-keys|previous|['AudioPrev']
org.gnome.settings-daemon.plugins.media-keys|previous-static|['XF86AudioPrev', '<Ctrl>XF86AudioPrev']
org.gnome.settings-daemon.plugins.media-keys|reboot|['']
org.gnome.settings-daemon.plugins.media-keys|rfkill|['']
org.gnome.settings-daemon.plugins.media-keys|rfkill-bluetooth|['']
org.gnome.settings-daemon.plugins.media-keys|rfkill-bluetooth-static|['XF86Bluetooth']
org.gnome.settings-daemon.plugins.media-keys|rfkill-static|['XF86WLAN', 'XF86UWB', 'XF86RFKill']
org.gnome.settings-daemon.plugins.media-keys|rotate-video-lock|['']
org.gnome.settings-daemon.plugins.media-keys|rotate-video-lock-static|['<Super>o', 'XF86RotationLockToggle']
org.gnome.settings-daemon.plugins.media-keys|screenreader|['<Alt><Super>s']
org.gnome.settings-daemon.plugins.media-keys|screensaver|['<Super>l']
org.gnome.settings-daemon.plugins.media-keys|screensaver-static|['XF86ScreenSaver']
org.gnome.settings-daemon.plugins.media-keys|search|['']
org.gnome.settings-daemon.plugins.media-keys|search-static|['XF86Search']
org.gnome.settings-daemon.plugins.media-keys|shutdown|['']
org.gnome.settings-daemon.plugins.media-keys|stop|['']
org.gnome.settings-daemon.plugins.media-keys|stop-static|['XF86AudioStop']
org.gnome.settings-daemon.plugins.media-keys|suspend|['']
org.gnome.settings-daemon.plugins.media-keys|suspend-static|['XF86Sleep']
org.gnome.settings-daemon.plugins.media-keys|toggle-contrast|['']
org.gnome.settings-daemon.plugins.media-keys|touchpad-off|['']
org.gnome.settings-daemon.plugins.media-keys|touchpad-off-static|['XF86TouchpadOff']
org.gnome.settings-daemon.plugins.media-keys|touchpad-on|['']
org.gnome.settings-daemon.plugins.media-keys|touchpad-on-static|['XF86TouchpadOn']
org.gnome.settings-daemon.plugins.media-keys|touchpad-toggle|['']
org.gnome.settings-daemon.plugins.media-keys|touchpad-toggle-static|['XF86TouchpadToggle', '<Ctrl><Super>XF86TouchpadToggle']
org.gnome.settings-daemon.plugins.media-keys|volume-down|['AudioLowerVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-down-precise|['']
org.gnome.settings-daemon.plugins.media-keys|volume-down-precise-static|['<Shift>XF86AudioLowerVolume', '<Ctrl><Shift>XF86AudioLowerVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-down-quiet|['']
org.gnome.settings-daemon.plugins.media-keys|volume-down-quiet-static|['<Alt>XF86AudioLowerVolume', '<Alt><Ctrl>XF86AudioLowerVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-down-static|['XF86AudioLowerVolume', '<Ctrl>XF86AudioLowerVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-mute|['AudioMute']
org.gnome.settings-daemon.plugins.media-keys|volume-mute-quiet|['']
org.gnome.settings-daemon.plugins.media-keys|volume-mute-quiet-static|['<Alt>XF86AudioMute']
org.gnome.settings-daemon.plugins.media-keys|volume-mute-static|['XF86AudioMute']
org.gnome.settings-daemon.plugins.media-keys|volume-step|6
org.gnome.settings-daemon.plugins.media-keys|volume-up|['AudioRaiseVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-up-precise|['']
org.gnome.settings-daemon.plugins.media-keys|volume-up-precise-static|['<Shift>XF86AudioRaiseVolume', '<Ctrl><Shift>XF86AudioRaiseVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-up-quiet|['']
org.gnome.settings-daemon.plugins.media-keys|volume-up-quiet-static|['<Alt>XF86AudioRaiseVolume', '<Alt><Ctrl>XF86AudioRaiseVolume']
org.gnome.settings-daemon.plugins.media-keys|volume-up-static|['XF86AudioRaiseVolume', '<Ctrl>XF86AudioRaiseVolume']
org.gnome.settings-daemon.plugins.media-keys|www|['']
org.gnome.settings-daemon.plugins.media-keys|www-static|['XF86WWW']
SETTINGS
}

apply_application_preferences() {
    log "Applying Nautilus and installed GNOME application preferences."

    apply_table <<'SETTINGS'
# Nautilus / Files
org.gnome.nautilus.compression|default-compression-format|'zip'
org.gnome.nautilus.icon-view|captions|['size', 'date_modified', 'none']
org.gnome.nautilus.icon-view|default-zoom-level|'small-plus'
org.gnome.nautilus.list-view|default-column-order|['name', 'size', 'type', 'owner', 'group', 'permissions', 'mime_type', 'where', 'date_modified', 'date_modified_with_time', 'date_accessed', 'date_created', 'recency', 'starred']
org.gnome.nautilus.list-view|default-visible-columns|['name', 'size', 'date_modified']
org.gnome.nautilus.list-view|default-zoom-level|'medium'
org.gnome.nautilus.list-view|use-tree-view|false
org.gnome.nautilus.preferences|always-use-location-entry|false
org.gnome.nautilus.preferences|click-policy|'double'
org.gnome.nautilus.preferences|date-time-format|'simple'
org.gnome.nautilus.preferences|default-folder-viewer|'icon-view'
org.gnome.nautilus.preferences|default-sort-in-reverse-order|false
org.gnome.nautilus.preferences|default-sort-order|'type'
org.gnome.nautilus.preferences|fts-enabled|true
org.gnome.nautilus.preferences|mouse-back-button|uint32 8
org.gnome.nautilus.preferences|mouse-forward-button|uint32 9
org.gnome.nautilus.preferences|mouse-use-extra-buttons|true
org.gnome.nautilus.preferences|open-folder-on-dnd-hover|true
org.gnome.nautilus.preferences|recursive-search|'local-only'
org.gnome.nautilus.preferences|search-filter-time-type|'last_modified'
org.gnome.nautilus.preferences|show-create-link|false
org.gnome.nautilus.preferences|show-delete-permanently|false
org.gnome.nautilus.preferences|show-directory-item-counts|'local-only'
org.gnome.nautilus.preferences|show-hidden-files|false
org.gnome.nautilus.preferences|show-image-thumbnails|'local-only'
org.gnome.nautilus.preferences|thumbnail-limit|uint64 50

# Gedit
org.gnome.gedit.preferences.editor|auto-indent|true
org.gnome.gedit.preferences.editor|auto-save|true
org.gnome.gedit.preferences.editor|auto-save-interval|uint32 1
org.gnome.gedit.preferences.editor|bracket-matching|true
org.gnome.gedit.preferences.editor|create-backup-copy|false
org.gnome.gedit.preferences.editor|display-line-numbers|true
org.gnome.gedit.preferences.editor|display-right-margin|false
org.gnome.gedit.preferences.editor|editor-font|'Monospace 10'
org.gnome.gedit.preferences.editor|ensure-trailing-newline|true
org.gnome.gedit.preferences.editor|highlight-current-line|true
org.gnome.gedit.preferences.editor|insert-spaces|false
org.gnome.gedit.preferences.editor|max-file-size|uint64 200000000
org.gnome.gedit.preferences.editor|max-undo-actions|2000
org.gnome.gedit.preferences.editor|restore-cursor-position|true
org.gnome.gedit.preferences.editor|right-margin-position|uint32 80
org.gnome.gedit.preferences.editor|search-highlighting|true
org.gnome.gedit.preferences.editor|smart-home-end|'after'
org.gnome.gedit.preferences.editor|style-scheme-for-dark-theme-variant|'solarized-light'
org.gnome.gedit.preferences.editor|style-scheme-for-light-theme-variant|'solarized-light'
org.gnome.gedit.preferences.editor|syntax-highlighting|true
org.gnome.gedit.preferences.editor|tabs-size|uint32 4
org.gnome.gedit.preferences.editor|use-default-font|false
org.gnome.gedit.preferences.editor|wrap-last-split-mode|'word'
org.gnome.gedit.preferences.editor|wrap-mode|'none'
org.gnome.gedit.preferences.ui|bottom-panel-visible|false
org.gnome.gedit.preferences.ui|show-tabs-mode|'auto'
org.gnome.gedit.preferences.ui|side-panel-visible|false
org.gnome.gedit.preferences.ui|statusbar-visible|true
org.gnome.gedit.preferences.ui|theme-variant|'light'

# GNOME System Monitor
org.gnome.gnome-system-monitor|cpu-smooth-graph|true
org.gnome.gnome-system-monitor|cpu-stacked-area-chart|false
org.gnome.gnome-system-monitor|current-tab|'processes'
org.gnome.gnome-system-monitor|disk-read-color|'#3584e4'
org.gnome.gnome-system-monitor|disk-write-color|'#e66100'
org.gnome.gnome-system-monitor|disks-interval|5000
org.gnome.gnome-system-monitor|graph-data-points|60
org.gnome.gnome-system-monitor|graph-update-interval|1000
org.gnome.gnome-system-monitor|kill-dialog|true
org.gnome.gnome-system-monitor|logarithmic-scale|false
org.gnome.gnome-system-monitor|mem-color|'#e01b24'
org.gnome.gnome-system-monitor|net-in-color|'#3584e4'
org.gnome.gnome-system-monitor|net-out-color|'#e66100'
org.gnome.gnome-system-monitor|network-in-bits|false
org.gnome.gnome-system-monitor|network-total-in-bits|false
org.gnome.gnome-system-monitor|process-memory-in-iec|false
org.gnome.gnome-system-monitor|resources-cpu-expanded|true
org.gnome.gnome-system-monitor|resources-disk-expanded|true
org.gnome.gnome-system-monitor|resources-mem-expanded|true
org.gnome.gnome-system-monitor|resources-memory-in-iec|false
org.gnome.gnome-system-monitor|resources-net-expanded|true
org.gnome.gnome-system-monitor|show-all-fs|false
org.gnome.gnome-system-monitor|show-dependencies|false
org.gnome.gnome-system-monitor|show-whose-processes|'user'
org.gnome.gnome-system-monitor|smooth-refresh|true
org.gnome.gnome-system-monitor|solaris-mode|true
org.gnome.gnome-system-monitor|swap-color|'#33d17a'
org.gnome.gnome-system-monitor|update-interval|3000
org.gnome.gnome-system-monitor.proctree|col-0-visible|true
org.gnome.gnome-system-monitor.proctree|col-0-width|472
org.gnome.gnome-system-monitor.proctree|col-24-visible|true
org.gnome.gnome-system-monitor.proctree|col-24-width|407
org.gnome.gnome-system-monitor.proctree|col-26-visible|false
org.gnome.gnome-system-monitor.proctree|col-26-width|0
org.gnome.gnome-system-monitor.proctree|col-8-visible|true
org.gnome.gnome-system-monitor.proctree|col-8-width|111
org.gnome.gnome-system-monitor.proctree|columns-order|[0, 12, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
org.gnome.gnome-system-monitor.proctree|sort-col|12
org.gnome.gnome-system-monitor.proctree|sort-order|1

# Papers document viewer
org.gnome.Papers|allow-links-change-zoom|true
org.gnome.Papers|night-mode|false
org.gnome.Papers|override-restrictions|true
org.gnome.Papers|page-cache-size|uint32 200
org.gnome.Papers.Default|annot-color|'yellow'
org.gnome.Papers.Default|continuous|true
org.gnome.Papers.Default|dual-page|false
org.gnome.Papers.Default|dual-page-odd-left|false
org.gnome.Papers.Default|enable-spellchecking|true
org.gnome.Papers.Default|eraser-mode-objects|'true'
org.gnome.Papers.Default|highlight-color|'yellow'
org.gnome.Papers.Default|highlight-stroke|2.0
org.gnome.Papers.Default|pen-color|'blue'
org.gnome.Papers.Default|pen-stroke|1.0
org.gnome.Papers.Default|show-sidebar|true
org.gnome.Papers.Default|sizing-mode|'automatic'
org.gnome.Papers.Default|text-color|'blue'

# Celluloid
io.github.celluloid-player.Celluloid|always-append-to-playlist|false
io.github.celluloid-player.Celluloid|always-autohide-cursor|false
io.github.celluloid-player.Celluloid|always-open-new-window|false
io.github.celluloid-player.Celluloid|always-show-title-buttons|false
io.github.celluloid-player.Celluloid|always-use-floating-controls|false
io.github.celluloid-player.Celluloid|autofit-enable|true
io.github.celluloid-player.Celluloid|controls-dead-zone-size|0.0
io.github.celluloid-player.Celluloid|controls-unhide-cursor-speed|0.0
io.github.celluloid-player.Celluloid|csd-enable|true
io.github.celluloid-player.Celluloid|dark-theme-enable|true
io.github.celluloid-player.Celluloid|draggable-video-area-enable|false
io.github.celluloid-player.Celluloid|graphics-offload-enable|false
io.github.celluloid-player.Celluloid|ignore-playback-errors|false
io.github.celluloid-player.Celluloid|inhibit-idle|true
io.github.celluloid-player.Celluloid|last-folder-enable|false
io.github.celluloid-player.Celluloid|menubar-accel-enable|true
io.github.celluloid-player.Celluloid|mpris-enable|true
io.github.celluloid-player.Celluloid|mpv-config-enable|false
io.github.celluloid-player.Celluloid|mpv-config-file|''
io.github.celluloid-player.Celluloid|mpv-input-config-enable|false
io.github.celluloid-player.Celluloid|mpv-input-config-file|''
io.github.celluloid-player.Celluloid|mpv-options|''
io.github.celluloid-player.Celluloid|prefetch-metadata|true
io.github.celluloid-player.Celluloid|present-window-on-file-open|false
io.github.celluloid-player.Celluloid|show-durations-in-playlist|true
io.github.celluloid-player.Celluloid|use-skip-buttons-for-playlist|true

# GTK 3 and GTK 4 file chooser preferences; geometry and last folders omitted.
org.gtk.Settings.FileChooser|clock-format|'24h'
org.gtk.Settings.FileChooser|date-format|'regular'
org.gtk.Settings.FileChooser|expand-folders|false
org.gtk.Settings.FileChooser|location-mode|'path-bar'
org.gtk.Settings.FileChooser|show-hidden|false
org.gtk.Settings.FileChooser|show-size-column|true
org.gtk.Settings.FileChooser|show-type-column|true
org.gtk.Settings.FileChooser|sort-column|'name'
org.gtk.Settings.FileChooser|sort-directories-first|false
org.gtk.Settings.FileChooser|sort-order|'ascending'
org.gtk.Settings.FileChooser|startup-mode|'recent'
org.gtk.Settings.FileChooser|type-format|'category'
org.gtk.gtk4.Settings.FileChooser|clock-format|'24h'
org.gtk.gtk4.Settings.FileChooser|date-format|'regular'
org.gtk.gtk4.Settings.FileChooser|expand-folders|false
org.gtk.gtk4.Settings.FileChooser|location-mode|'path-bar'
org.gtk.gtk4.Settings.FileChooser|show-hidden|true
org.gtk.gtk4.Settings.FileChooser|show-size-column|true
org.gtk.gtk4.Settings.FileChooser|show-type-column|true
org.gtk.gtk4.Settings.FileChooser|sort-column|'name'
org.gtk.gtk4.Settings.FileChooser|sort-directories-first|false
org.gtk.gtk4.Settings.FileChooser|sort-order|'ascending'
org.gtk.gtk4.Settings.FileChooser|startup-mode|'recent'
org.gtk.gtk4.Settings.FileChooser|type-format|'category'
org.gtk.gtk4.Settings.FileChooser|view-type|'list'

# Utilities
ca.desrt.dconf-editor.Settings|behaviour|'always-confirm-implicit'
ca.desrt.dconf-editor.Settings|mouse-back-button|8
ca.desrt.dconf-editor.Settings|mouse-forward-button|9
ca.desrt.dconf-editor.Settings|mouse-use-extra-buttons|true
ca.desrt.dconf-editor.Settings|refresh-settings-schema-source|true
ca.desrt.dconf-editor.Settings|restore-view|true
ca.desrt.dconf-editor.Settings|show-warning|true
ca.desrt.dconf-editor.Settings|small-keys-list-rows|false
ca.desrt.dconf-editor.Settings|sort-case-sensitive|false
ca.desrt.dconf-editor.Settings|use-shortpaths|false
com.mattjakeman.ExtensionManager|sort-enabled-first|false
org.gnome.tweaks|show-extensions-notice|false
SETTINGS
}

apply_terminal_settings() {
    log "Applying the IB Glass GNOME Terminal profile and terminal shortcuts."

    apply_table <<'SETTINGS'
org.gnome.Terminal.Legacy.Settings|always-check-default-terminal|true
org.gnome.Terminal.Legacy.Settings|confirm-close|true
org.gnome.Terminal.Legacy.Settings|context-info|['numbers']
org.gnome.Terminal.Legacy.Settings|default-show-menubar|true
org.gnome.Terminal.Legacy.Settings|headerbar|@mb nothing
org.gnome.Terminal.Legacy.Settings|menu-accelerator-enabled|true
org.gnome.Terminal.Legacy.Settings|mnemonics-enabled|false
org.gnome.Terminal.Legacy.Settings|new-tab-position|'last'
org.gnome.Terminal.Legacy.Settings|new-terminal-mode|'window'
org.gnome.Terminal.Legacy.Settings|schema-version|uint32 3
org.gnome.Terminal.Legacy.Settings|shell-integration-enabled|true
org.gnome.Terminal.Legacy.Settings|shortcuts-enabled|true
org.gnome.Terminal.Legacy.Settings|tab-policy|'automatic'
org.gnome.Terminal.Legacy.Settings|tab-position|'top'
org.gnome.Terminal.Legacy.Settings|theme-variant|'system'
org.gnome.Terminal.Legacy.Settings|unified-menu|true
org.gnome.Terminal.Legacy.Keybindings|close-tab|'<Control><Shift>w'
org.gnome.Terminal.Legacy.Keybindings|close-window|'<Control><Shift>q'
org.gnome.Terminal.Legacy.Keybindings|copy|'<Control><Shift>c'
org.gnome.Terminal.Legacy.Keybindings|copy-html|'disabled'
org.gnome.Terminal.Legacy.Keybindings|detach-tab|'disabled'
org.gnome.Terminal.Legacy.Keybindings|export|'disabled'
org.gnome.Terminal.Legacy.Keybindings|find|'<Control><Shift>F'
org.gnome.Terminal.Legacy.Keybindings|find-clear|'<Control><Shift>J'
org.gnome.Terminal.Legacy.Keybindings|find-next|'<Control><Shift>G'
org.gnome.Terminal.Legacy.Keybindings|find-previous|'<Control><Shift>H'
org.gnome.Terminal.Legacy.Keybindings|full-screen|'F11'
org.gnome.Terminal.Legacy.Keybindings|header-menu|'disabled'
org.gnome.Terminal.Legacy.Keybindings|help|'disabled'
org.gnome.Terminal.Legacy.Keybindings|move-tab-left|'<Control><Shift>Page_Up'
org.gnome.Terminal.Legacy.Keybindings|move-tab-right|'<Control><Shift>Page_Down'
org.gnome.Terminal.Legacy.Keybindings|new-tab|'<Control><Shift>t'
org.gnome.Terminal.Legacy.Keybindings|new-window|'<Control><Shift>n'
org.gnome.Terminal.Legacy.Keybindings|next-tab|'<Control>Page_Down'
org.gnome.Terminal.Legacy.Keybindings|paste|'<Control><Shift>v'
org.gnome.Terminal.Legacy.Keybindings|preferences|'disabled'
org.gnome.Terminal.Legacy.Keybindings|prev-tab|'<Control>Page_Up'
org.gnome.Terminal.Legacy.Keybindings|print|'disabled'
org.gnome.Terminal.Legacy.Keybindings|read-only|'disabled'
org.gnome.Terminal.Legacy.Keybindings|reset|'disabled'
org.gnome.Terminal.Legacy.Keybindings|reset-and-clear|'disabled'
org.gnome.Terminal.Legacy.Keybindings|save-contents|'disabled'
org.gnome.Terminal.Legacy.Keybindings|select-all|'<Primary><Shift>a'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-1|'<Alt>1'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-2|'<Alt>2'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-3|'<Alt>3'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-4|'<Alt>4'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-5|'<Alt>5'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-6|'<Alt>6'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-7|'<Alt>7'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-8|'<Alt>8'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-9|'<Alt>9'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-10|'<Alt>0'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-11|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-12|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-13|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-14|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-15|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-16|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-17|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-18|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-19|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-20|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-21|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-22|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-23|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-24|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-25|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-26|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-27|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-28|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-29|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-30|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-31|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-32|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-33|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-34|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-35|'disabled'
org.gnome.Terminal.Legacy.Keybindings|switch-to-tab-last|'disabled'
org.gnome.Terminal.Legacy.Keybindings|toggle-menubar|'disabled'
org.gnome.Terminal.Legacy.Keybindings|zoom-in|'<Control>plus'
org.gnome.Terminal.Legacy.Keybindings|zoom-normal|'<Control>0'
org.gnome.Terminal.Legacy.Keybindings|zoom-out|'<Control>minus'

# Ubuntu's Ptyxis receives the portable parts of the same terminal design.
org.gnome.Ptyxis|cursor-shape|'ibeam'
org.gnome.Ptyxis|font-name|'Noto Sans Mono 12'
org.gnome.Ptyxis|use-system-font|false
org.gnome.Ptyxis|window-size|(uint32 110, uint32 28)
SETTINGS

    local profile_uuid="fc74a141-e2ae-4f89-8a21-5b02e8cd73aa"
    local profile_path="/org/gnome/terminal/legacy/profiles:/:$profile_uuid/"
    local profile_schema="org.gnome.Terminal.Legacy.Profile"

    set_fixed \
        org.gnome.Terminal.ProfilesList \
        default \
        "'$profile_uuid'"
    set_fixed \
        org.gnome.Terminal.ProfilesList \
        list \
        "['$profile_uuid']"

    set_relocatable "$profile_schema" "$profile_path" \
        background-color "'#2e3440'"
    set_relocatable "$profile_schema" "$profile_path" \
        bold-is-bright true
    set_relocatable "$profile_schema" "$profile_path" \
        cursor-blink-mode "'on'"
    set_relocatable "$profile_schema" "$profile_path" \
        cursor-shape "'ibeam'"
    set_relocatable "$profile_schema" "$profile_path" \
        default-size-columns 110
    set_relocatable "$profile_schema" "$profile_path" \
        default-size-rows 28
    set_relocatable "$profile_schema" "$profile_path" \
        font "'Noto Sans Mono 12'"
    set_relocatable "$profile_schema" "$profile_path" \
        foreground-color "'#eceff4'"
    set_relocatable "$profile_schema" "$profile_path" \
        palette "['#2e3440', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#88c0d0', '#eceff4', '#4c566a', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#8fbcbb', '#eceff4']"
    set_relocatable "$profile_schema" "$profile_path" \
        scroll-on-output false
    set_relocatable "$profile_schema" "$profile_path" \
        scrollback-unlimited true
    set_relocatable "$profile_schema" "$profile_path" \
        scrollbar-policy "'always'"
    set_relocatable "$profile_schema" "$profile_path" \
        use-system-font false
    set_relocatable "$profile_schema" "$profile_path" \
        use-theme-colors false
    set_relocatable "$profile_schema" "$profile_path" \
        visible-name "'IB Glass Terminal'"
}

apply_extension_preferences() {
    log "Applying dock and GNOME Shell extension preferences."

    apply_table <<'SETTINGS'
# Dash-to-Dock schema shared by upstream Dash-to-Dock and Ubuntu Dock.
org.gnome.shell.extensions.dash-to-dock|activate-single-window|true
org.gnome.shell.extensions.dash-to-dock|always-center-icons|true
org.gnome.shell.extensions.dash-to-dock|animation-time|0.16
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-1|['<Ctrl><Super>1']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-2|['<Ctrl><Super>2']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-3|['<Ctrl><Super>3']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-4|['<Ctrl><Super>4']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-5|['<Ctrl><Super>5']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-6|['<Ctrl><Super>6']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-7|['<Ctrl><Super>7']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-8|['<Ctrl><Super>8']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-9|['<Ctrl><Super>9']
org.gnome.shell.extensions.dash-to-dock|app-ctrl-hotkey-10|['<Ctrl><Super>0']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-1|['<Super>1']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-2|['<Super>2']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-3|['<Super>3']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-4|['<Super>4']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-5|['<Super>5']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-6|['<Super>6']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-7|['<Super>7']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-8|['<Super>8']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-9|['<Super>9']
org.gnome.shell.extensions.dash-to-dock|app-hotkey-10|['<Super>0']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-1|['<Shift><Super>1']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-2|['<Shift><Super>2']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-3|['<Shift><Super>3']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-4|['<Shift><Super>4']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-5|['<Shift><Super>5']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-6|['<Shift><Super>6']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-7|['<Shift><Super>7']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-8|['<Shift><Super>8']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-9|['<Shift><Super>9']
org.gnome.shell.extensions.dash-to-dock|app-shift-hotkey-10|['<Shift><Super>0']
org.gnome.shell.extensions.dash-to-dock|application-counter-overrides-notifications|true
org.gnome.shell.extensions.dash-to-dock|apply-custom-theme|false
org.gnome.shell.extensions.dash-to-dock|apply-glossy-effect|true
org.gnome.shell.extensions.dash-to-dock|autohide|true
org.gnome.shell.extensions.dash-to-dock|autohide-in-fullscreen|false
org.gnome.shell.extensions.dash-to-dock|background-color|'#ffffff'
org.gnome.shell.extensions.dash-to-dock|background-opacity|0.80000000000000004
org.gnome.shell.extensions.dash-to-dock|bolt-support|true
org.gnome.shell.extensions.dash-to-dock|click-action|'minimize-or-previews'
org.gnome.shell.extensions.dash-to-dock|custom-background-color|false
org.gnome.shell.extensions.dash-to-dock|custom-theme-customize-running-dots|false
org.gnome.shell.extensions.dash-to-dock|custom-theme-running-dots-border-color|'#ffffff'
org.gnome.shell.extensions.dash-to-dock|custom-theme-running-dots-border-width|0
org.gnome.shell.extensions.dash-to-dock|custom-theme-running-dots-color|'#ffffff'
org.gnome.shell.extensions.dash-to-dock|custom-theme-shrink|true
org.gnome.shell.extensions.dash-to-dock|customize-alphas|false
org.gnome.shell.extensions.dash-to-dock|dance-urgent-applications|true
org.gnome.shell.extensions.dash-to-dock|dash-max-icon-size|48
org.gnome.shell.extensions.dash-to-dock|default-windows-preview-to-open|false
org.gnome.shell.extensions.dash-to-dock|disable-overview-on-startup|true
org.gnome.shell.extensions.dash-to-dock|dock-fixed|false
org.gnome.shell.extensions.dash-to-dock|dock-position|'BOTTOM'
org.gnome.shell.extensions.dash-to-dock|extend-height|false
org.gnome.shell.extensions.dash-to-dock|force-straight-corner|false
org.gnome.shell.extensions.dash-to-dock|height-fraction|0.81000000000000005
org.gnome.shell.extensions.dash-to-dock|hide-delay|0.17999999999999999
org.gnome.shell.extensions.dash-to-dock|hide-tooltip|false
org.gnome.shell.extensions.dash-to-dock|hot-keys|true
org.gnome.shell.extensions.dash-to-dock|hotkeys-overlay|true
org.gnome.shell.extensions.dash-to-dock|hotkeys-show-dock|true
org.gnome.shell.extensions.dash-to-dock|icon-size-fixed|false
org.gnome.shell.extensions.dash-to-dock|intellihide|true
org.gnome.shell.extensions.dash-to-dock|intellihide-mode|'ALL_WINDOWS'
org.gnome.shell.extensions.dash-to-dock|isolate-locations|true
org.gnome.shell.extensions.dash-to-dock|isolate-monitors|false
org.gnome.shell.extensions.dash-to-dock|isolate-workspaces|false
org.gnome.shell.extensions.dash-to-dock|manualhide|false
org.gnome.shell.extensions.dash-to-dock|max-alpha|0.80000000000000004
org.gnome.shell.extensions.dash-to-dock|middle-click-action|'launch'
org.gnome.shell.extensions.dash-to-dock|min-alpha|0.20000000000000001
org.gnome.shell.extensions.dash-to-dock|minimize-shift|true
org.gnome.shell.extensions.dash-to-dock|multi-monitor|true
org.gnome.shell.extensions.dash-to-dock|preferred-monitor|-2
org.gnome.shell.extensions.dash-to-dock|pressure-threshold|0.0
org.gnome.shell.extensions.dash-to-dock|preview-size-scale|0.0
org.gnome.shell.extensions.dash-to-dock|require-pressure-to-show|false
org.gnome.shell.extensions.dash-to-dock|running-indicator-dominant-color|false
org.gnome.shell.extensions.dash-to-dock|running-indicator-style|'DASHES'
org.gnome.shell.extensions.dash-to-dock|scroll-action|'cycle-windows'
org.gnome.shell.extensions.dash-to-dock|scroll-switch-workspace|true
org.gnome.shell.extensions.dash-to-dock|scroll-to-focused-application|true
org.gnome.shell.extensions.dash-to-dock|shift-click-action|'minimize'
org.gnome.shell.extensions.dash-to-dock|shift-middle-click-action|'launch'
org.gnome.shell.extensions.dash-to-dock|shortcut|['<Super>q']
org.gnome.shell.extensions.dash-to-dock|shortcut-text|'<Super>q'
org.gnome.shell.extensions.dash-to-dock|shortcut-timeout|2.0
org.gnome.shell.extensions.dash-to-dock|show-apps-always-in-the-edge|true
org.gnome.shell.extensions.dash-to-dock|show-apps-at-top|true
org.gnome.shell.extensions.dash-to-dock|show-delay|0.0
org.gnome.shell.extensions.dash-to-dock|show-dock-urgent-notify|true
org.gnome.shell.extensions.dash-to-dock|show-favorites|true
org.gnome.shell.extensions.dash-to-dock|show-icons-emblems|true
org.gnome.shell.extensions.dash-to-dock|show-icons-notifications-counter|true
org.gnome.shell.extensions.dash-to-dock|show-mounts|false
org.gnome.shell.extensions.dash-to-dock|show-mounts-network|false
org.gnome.shell.extensions.dash-to-dock|show-mounts-only-mounted|true
org.gnome.shell.extensions.dash-to-dock|show-running|true
org.gnome.shell.extensions.dash-to-dock|show-show-apps-button|true
org.gnome.shell.extensions.dash-to-dock|show-trash|true
org.gnome.shell.extensions.dash-to-dock|show-windows-preview|true
org.gnome.shell.extensions.dash-to-dock|transparency-mode|'DEFAULT'
org.gnome.shell.extensions.dash-to-dock|unity-backlit-items|false
org.gnome.shell.extensions.dash-to-dock|workspace-agnostic-urgent-windows|true

# Remaining extension schemas.
org.gnome.shell.extensions.apps-menu|apps-menu-toggle-menu|['<Alt>F1']
org.gnome.shell.extensions.auto-move-windows|application-list|@as []
org.gnome.shell.extensions.hidetopbar|show-in-overview|true
org.gnome.shell.extensions.native-window-placement|use-more-screen|true
org.gnome.shell.extensions.native-window-placement|window-captions-on-top|true
org.gnome.shell.extensions.screenshot-window-sizer|cycle-screenshot-sizes|['<Alt><Control>s']
org.gnome.shell.extensions.screenshot-window-sizer|cycle-screenshot-sizes-backward|['<Shift><Alt><Control>s']
org.gnome.shell.extensions.system-monitor|show-cpu|true
org.gnome.shell.extensions.system-monitor|show-download|true
org.gnome.shell.extensions.system-monitor|show-memory|true
org.gnome.shell.extensions.system-monitor|show-swap|true
org.gnome.shell.extensions.system-monitor|show-upload|true
org.gnome.shell.extensions.user-theme|name|'MacTahoe-Dark-blue'
org.gnome.shell.extensions.window-list|display-all-workspaces|false
org.gnome.shell.extensions.window-list|embed-previews|true
org.gnome.shell.extensions.window-list|grouping-mode|'never'
org.gnome.shell.extensions.window-list|show-on-all-monitors|false
org.gnome.shell.extensions.workspace-indicator|embed-previews|true
SETTINGS

    if [[ "$TARGET_PLATFORM" == "ubuntu" ]]; then
        # DING provides the Windows-style desktop icons requested for Ubuntu.
        apply_table <<'SETTINGS'
org.gnome.shell.extensions.ding|show-trash|true
org.gnome.shell.extensions.ding|show-home|false
org.gnome.shell.extensions.ding|show-volumes|false
org.gnome.shell.extensions.ding|show-network-volumes|false
org.gnome.shell.extensions.ding|show-link-emblem|true
SETTINGS
    fi
}

apply_custom_keybindings() {
    log "Creating the seven custom application shortcuts."

    local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
    local terminal_command=""
    local browser_command=""

    terminal_command="$(
        first_command gnome-terminal ptyxis kgx gnome-console ||
            printf '%s\n' gnome-terminal
    )"
    browser_command="$(
        first_command google-chrome-stable google-chrome chromium ||
            printf '%s\n' google-chrome-stable
    )"

    set_relocatable "$schema" "$base/browser/" \
        binding "'<Super>b'"
    set_relocatable "$schema" "$base/browser/" \
        command "'$browser_command'"
    set_relocatable "$schema" "$base/browser/" \
        name "'Open Browser'"

    set_relocatable "$schema" "$base/code/" \
        binding "'<Super>c'"
    set_relocatable "$schema" "$base/code/" \
        command "'code'"
    set_relocatable "$schema" "$base/code/" \
        name "'Open VS Code'"

    set_relocatable "$schema" "$base/custom0/" \
        binding "'<Shift><Super>s'"
    set_relocatable "$schema" "$base/custom0/" \
        command "'flameshot gui --clipboard'"
    set_relocatable "$schema" "$base/custom0/" \
        name "'Flameshot Clipboard Snip'"

    set_relocatable "$schema" "$base/files/" \
        binding "'<Super>e'"
    set_relocatable "$schema" "$base/files/" \
        command "'nautilus'"
    set_relocatable "$schema" "$base/files/" \
        name "'Open Files'"

    set_relocatable "$schema" "$base/settings/" \
        binding "'<Super>i'"
    set_relocatable "$schema" "$base/settings/" \
        command "'gnome-control-center'"
    set_relocatable "$schema" "$base/settings/" \
        name "'Open Settings'"

    set_relocatable "$schema" "$base/task-manager/" \
        binding "'<Control><Shift>Escape'"
    set_relocatable "$schema" "$base/task-manager/" \
        command "'gnome-system-monitor'"
    set_relocatable "$schema" "$base/task-manager/" \
        name "'Open System Monitor'"

    set_relocatable "$schema" "$base/terminal/" \
        binding "'<Control><Alt>t'"
    set_relocatable "$schema" "$base/terminal/" \
        command "'$terminal_command'"
    set_relocatable "$schema" "$base/terminal/" \
        name "'Open Terminal'"

    set_fixed \
        org.gnome.settings-daemon.plugins.media-keys \
        custom-keybindings \
        "['$base/terminal/', '$base/files/', '$base/browser/', '$base/code/', '$base/task-manager/', '$base/settings/', '$base/custom0/']"
}

apply_app_folders() {
    log "Applying the System and Utilities application folders."

    local schema="org.gnome.desktop.app-folders.folder"
    local base="/org/gnome/desktop/app-folders/folders"

    set_fixed \
        org.gnome.desktop.app-folders \
        folder-children \
        "['System', 'Utilities']"

    set_relocatable "$schema" "$base/System/" \
        apps \
        "['nm-connection-editor.desktop', 'org.gnome.tweaks.desktop']"
    set_relocatable "$schema" "$base/System/" \
        name \
        "'X-GNOME-Shell-System.directory'"
    set_relocatable "$schema" "$base/System/" \
        translate \
        true

    set_relocatable "$schema" "$base/Utilities/" \
        apps \
        "['org.gnome.Papers.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.Loupe.desktop']"
    set_relocatable "$schema" "$base/Utilities/" \
        name \
        "'X-GNOME-Shell-Utilities.directory'"
    set_relocatable "$schema" "$base/Utilities/" \
        translate \
        true
}

apply_notifications_and_favorites() {
    log "Resolving notification applications and dock favorites."

    local notification_children=""
    local desktop_id=""
    local -a favorites=()

    if [[ "$TARGET_PLATFORM" == "ubuntu" ]]; then
        notification_children="['gnome-about-panel', 'org-gnome-systemmonitor', 'gnome-power-panel', 'google-chrome', 'code', 'org-gnome-nautilus', 'org-flameshot-flameshot', 'org-gnome-terminal-preferences', 'org-gnome-extensions']"
    else
        notification_children="['gnome-about-panel', 'org-gnome-systemmonitor', 'firefox', 'gnome-power-panel', 'google-chrome', 'code', 'org-gnome-nautilus', 'org-flameshot-flameshot', 'org-gnome-terminal-preferences', 'org-gnome-extensions']"
    fi
    set_fixed \
        org.gnome.desktop.notifications \
        application-children \
        "$notification_children"

    desktop_id="$(first_desktop_id org.gnome.Nautilus.desktop || true)"
    [[ -z "$desktop_id" ]] || favorites+=("$desktop_id")

    desktop_id="$(first_desktop_id code.desktop visual-studio-code.desktop || true)"
    [[ -z "$desktop_id" ]] || favorites+=("$desktop_id")

    desktop_id="$(
        first_desktop_id \
            org.gnome.Terminal.desktop \
            org.gnome.Ptyxis.desktop \
            org.gnome.Console.desktop ||
            true
    )"
    [[ -z "$desktop_id" ]] || favorites+=("$desktop_id")

    desktop_id="$(first_desktop_id audacious.desktop || true)"
    [[ -z "$desktop_id" ]] || favorites+=("$desktop_id")

    desktop_id="$(
        first_desktop_id \
            google-chrome.desktop \
            google-chrome-stable.desktop ||
            true
    )"
    [[ -z "$desktop_id" ]] || favorites+=("$desktop_id")

    if [[ "${#favorites[@]}" -gt 0 ]]; then
        set_fixed \
            org.gnome.shell \
            favorite-apps \
            "$(gvariant_string_array "${favorites[@]}")"
    else
        warn "No preferred application desktop IDs were found; favorites were unchanged."
    fi
}

picker_page() {
    local result="{"
    local separator=""
    local position=0
    local item=""

    for item in "$@"; do
        if [[ "$item" != "System" &&
            "$item" != "Utilities" &&
            ! -f "$HOME/.local/share/applications/$item" &&
            ! -f "/usr/local/share/applications/$item" &&
            ! -f "/usr/share/applications/$item" ]]
        then
            continue
        fi

        result+="${separator}'$item': <{'position': <$position>}>"
        separator=", "
        position=$((position + 1))
    done

    result+="}"
    printf '%s\n' "$result"
}

apply_app_picker_layout() {
    log "Rebuilding the saved app-grid order with desktop IDs present on this system."

    local -a first_page=(
        bssh.desktop
        blueman-manager.desktop
        ca.desrt.dconf-editor.desktop
        com.mattjakeman.ExtensionManager.desktop
        org.flameshot.Flameshot.desktop
        htop.desktop
        bvnc.desktop
        org.gnome.Screenshot.desktop
        btop.desktop
        org.pulseaudio.pavucontrol.desktop
        System
        org.gnome.Settings.desktop
        org.gnome.SystemMonitor.desktop
    )
    local -a first_page_tail=(
        avahi-discover.desktop
        io.github.celluloid_player.Celluloid.desktop
        org.gnome.Papers.desktop
        Utilities
        org.gnome.Extensions.desktop
        gparted.desktop
        org.gnome.gThumb.desktop
        mpv.desktop
    )
    local -a second_page=(
        qv4l2.desktop
        qvidcap.desktop
        ventoy.desktop
        vlc.desktop
        org.gnome.Software.desktop
        org.gnome.baobab.desktop
        org.gnome.DiskUtility.desktop
        org.gnome.gedit.desktop
        org.gnome.TextEditor.desktop
        org.qbittorrent.qBittorrent.desktop
    )
    local page_one=""
    local page_two=""

    if [[ "$TARGET_PLATFORM" == "arch" ]]; then
        first_page+=(firefox.desktop)
    fi
    first_page+=("${first_page_tail[@]}")

    page_one="$(picker_page "${first_page[@]}")"
    page_two="$(picker_page "${second_page[@]}")"

    set_fixed \
        org.gnome.shell \
        app-picker-layout \
        "[$page_one, $page_two]"
}

apply_wallpaper_uri() {
    local wallpaper_dir="$HOME/.local/share/backgrounds/rice/wallpapers"
    local wallpaper=""
    local uri=""

    [[ -d "$wallpaper_dir" ]] || {
        warn "Rice wallpaper directory is absent; wallpaper URI was left unchanged."
        return 0
    }

    while IFS= read -r -d '' wallpaper; do
        break
    done < <(
        find "$wallpaper_dir" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) \
            -print0 |
            sort -z
    )

    [[ -n "$wallpaper" ]] || {
        warn "Rice wallpaper directory contains no supported images."
        return 0
    }

    if command -v python3 >/dev/null 2>&1; then
        uri="$(
            python3 -c \
                'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
                "$wallpaper"
        )"
    else
        uri="file://$wallpaper"
    fi

    set_fixed org.gnome.desktop.background picture-uri "'$uri'"
    set_fixed org.gnome.desktop.background picture-uri-dark "'$uri'"
    set_fixed org.gnome.desktop.screensaver picture-uri "'$uri'"
}

apply_extension_states() {
    [[ "$APPLY_EXTENSIONS" -eq 1 ]] || {
        log "Extension state changes were disabled by --no-extensions."
        return 0
    }

    log "Applying the enabled/disabled extension set."

    local -a active_common=(
        arch-dock-icon@ib-hussain
        hidetopbar@mathieu.bidon.ca
        start-overlay-in-application-view@Hex_cz
        launch-new-instance@gnome-shell-extensions.gcampax.github.com
        places-menu@gnome-shell-extensions.gcampax.github.com
        system-monitor@gnome-shell-extensions.gcampax.github.com
        user-theme@gnome-shell-extensions.gcampax.github.com
    )
    local -a disabled_snapshot=(
        apps-menu@gnome-shell-extensions.gcampax.github.com
        auto-move-windows@gnome-shell-extensions.gcampax.github.com
        drive-menu@gnome-shell-extensions.gcampax.github.com
        light-style@gnome-shell-extensions.gcampax.github.com
        native-window-placement@gnome-shell-extensions.gcampax.github.com
        screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com
        status-icons@gnome-shell-extensions.gcampax.github.com
        workspace-indicator@gnome-shell-extensions.gcampax.github.com
        windowsNavigator@gnome-shell-extensions.gcampax.github.com
        window-list@gnome-shell-extensions.gcampax.github.com
    )
    local uuid=""

    for uuid in "${active_common[@]}"; do
        set_extension_state "$uuid" enable
    done

    for uuid in "${disabled_snapshot[@]}"; do
        set_extension_state "$uuid" disable
    done

    if [[ "$TARGET_PLATFORM" == "ubuntu" ]]; then
        # Ubuntu Dock replaces upstream Dash-to-Dock while sharing its schema.
        set_extension_state dash-to-dock@micxgx.gmail.com disable
        set_extension_state ubuntu-dock@ubuntu.com enable
        set_extension_state ding@rastersoft.com enable
        # Arch uses Mutter's edge tiling and Super+Left/Right directly.
        # Ubuntu's Tiling Assistant overrides those exact settings.
        set_extension_state tiling-assistant@ubuntu.com disable
        set_extension_state ubuntu-appindicators@ubuntu.com enable
        set_extension_state web-search-provider@ubuntu.com enable

        # The Ubuntu build is intentionally Snap-free.
        set_extension_state snapd-prompting@canonical.com disable
        set_extension_state snapd-search-provider@canonical.com disable
    else
        set_extension_state dash-to-dock@micxgx.gmail.com enable
    fi
}

apply_power_profile() {
    command -v powerprofilesctl >/dev/null 2>&1 || {
        warn "powerprofilesctl is unavailable; performance profile selection was skipped."
        SKIPPED=$((SKIPPED + 1))
        return 0
    }

    if ! powerprofilesctl list 2>/dev/null | grep -q 'performance'; then
        warn "This machine does not expose a performance power profile."
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ "$(powerprofilesctl get 2>/dev/null || true)" == "performance" ]]; then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] Would select the performance power profile."
        APPLIED=$((APPLIED + 1))
        return 0
    fi

    if powerprofilesctl set performance >/dev/null 2>&1; then
        APPLIED=$((APPLIED + 1))
    else
        warn "Could not select the performance power profile."
        FAILED=$((FAILED + 1))
    fi
}

print_summary() {
    log "Completed ${TARGET_PLATFORM^} GNOME settings import."
    log "Changed/planned: $APPLIED"
    log "Already matched: $UNCHANGED"
    log "Unsupported or unavailable: $SKIPPED"
    log "Rejected or failed: $FAILED"

    if [[ "$DRY_RUN" -eq 0 ]]; then
        log "Log out and back in once so Shell extensions and theme changes reload cleanly."
    fi

    if [[ "$FAILED" -gt 0 ]]; then
        warn "Some installed schemas rejected snapshot values; review the warnings above."
    fi
}

main() {
    parse_arguments "$@"
    validate_environment
    load_schema_cache
    backup_current_settings

    log "Applying Ibrahim's GNOME 50 snapshot for $TARGET_PLATFORM."

    apply_core_desktop_settings
    apply_window_and_shell_keybindings
    apply_media_keybindings
    apply_custom_keybindings
    apply_application_preferences
    apply_terminal_settings
    apply_app_folders
    apply_notifications_and_favorites
    apply_app_picker_layout
    apply_wallpaper_uri
    apply_extension_preferences
    apply_extension_states
    apply_power_profile

    print_summary
}

main "$@"
