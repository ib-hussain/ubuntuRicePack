#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# Ibrahim's GNOME settings importer — Ubuntu GNOME 48/50 edition
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
UBUNTU_RELEASE_VERSION=""

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
        UBUNTU_RELEASE_VERSION="${VERSION_ID:-}"
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
        if [[ "$shell_version" != *" 48."* &&
            "$shell_version" != *" 50."* ]]
        then
            warn "This importer is validated on GNOME 48 and 50. Unsupported keys will be skipped."
        elif [[ "$shell_version" == *" 48."* ]]; then
            log "Adapting the GNOME 50 source snapshot to GNOME 48 through schema-aware writes."
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

    gsettings list-keys "$schema" 2>/dev/null |
        grep -Fx "$key" >/dev/null
}

relocatable_schema_has_key() {
    local schema="$1"
    local path="$2"
    local key="$3"

    gsettings list-keys "$schema:$path" 2>/dev/null |
        grep -Fx "$key" >/dev/null
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

    if ! gnome-extensions list 2>/dev/null |
        grep -Fx "$uuid" >/dev/null
    then
        if [[ "$desired" == "enable" ]]; then
            warn "Extension is not installed; cannot enable: $uuid"
        fi
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ "$desired" == "enable" ]] &&
        gnome-extensions list --enabled 2>/dev/null |
            grep -Fx "$uuid" >/dev/null
    then
        UNCHANGED=$((UNCHANGED + 1))
        return 0
    fi

    if [[ "$desired" == "disable" ]] &&
        ! gnome-extensions list --enabled 2>/dev/null |
            grep -Fx "$uuid" >/dev/null
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
org.gnome.desktop.a11y|always-show-text-caret|false
org.gnome.desktop.a11y|always-show-universal-access-status|false
org.gnome.desktop.a11y.magnifier|brightness-blue|0.0
org.gnome.desktop.a11y.magnifier|brightness-green|0.0
org.gnome.desktop.a11y.magnifier|brightness-red|0.0
org.gnome.desktop.a11y.magnifier|caret-tracking|'centered'
org.gnome.desktop.a11y.magnifier|color-saturation|1.0
org.gnome.desktop.a11y.magnifier|contrast-blue|0.0
org.gnome.desktop.a11y.magnifier|contrast-green|0.0
org.gnome.desktop.a11y.magnifier|contrast-red|0.0
org.gnome.desktop.a11y.magnifier|cross-hairs-clip|false
org.gnome.desktop.a11y.magnifier|cross-hairs-color|'#ff0000'
org.gnome.desktop.a11y.magnifier|cross-hairs-length|58
org.gnome.desktop.a11y.magnifier|cross-hairs-opacity|0.66000000000000003
org.gnome.desktop.a11y.magnifier|cross-hairs-thickness|8
org.gnome.desktop.a11y.magnifier|focus-tracking|'proportional'
org.gnome.desktop.a11y.magnifier|invert-lightness|false
org.gnome.desktop.a11y.magnifier|lens-mode|false
org.gnome.desktop.a11y.magnifier|mag-factor|1.0
org.gnome.desktop.a11y.magnifier|mouse-tracking|'proportional'
org.gnome.desktop.a11y.magnifier|screen-position|'full-screen'
org.gnome.desktop.a11y.magnifier|scroll-at-edges|false
org.gnome.desktop.a11y.magnifier|show-cross-hairs|false
org.gnome.desktop.background|color-shading-type|'solid'
org.gnome.desktop.background|picture-opacity|100
org.gnome.desktop.background|picture-options|'scaled'
org.gnome.desktop.background|picture-uri|'file:///home/ibrahim/.local/share/backgrounds/rice/wallpapers/IMG_4816%20%282%29.PNG'
org.gnome.desktop.background|picture-uri-dark|'file:///home/ibrahim/.local/share/backgrounds/rice/wallpapers/IMG_4816%20%282%29.PNG'
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
org.gnome.desktop.screensaver|picture-uri|'file:///home/ibrahim/.local/share/backgrounds/rice/wallpapers/IMG_4816%20%282%29.PNG'
org.gnome.desktop.screensaver|primary-color|'#000000'
org.gnome.desktop.screensaver|restart-enabled|false
org.gnome.desktop.screensaver|secondary-color|'#000000'
org.gnome.desktop.screensaver|show-full-name-in-top-bar|true
org.gnome.desktop.screensaver|status-message-enabled|true
org.gnome.desktop.screensaver|ubuntu-lock-on-suspend|true
org.gnome.desktop.screensaver|user-switch-enabled|true
org.gnome.desktop.break-reminders|selected-breaks|@as []
org.gnome.desktop.break-reminders.eyesight|countdown|false
org.gnome.desktop.break-reminders.eyesight|delay-seconds|uint32 180
org.gnome.desktop.break-reminders.eyesight|duration-seconds|uint32 20
org.gnome.desktop.break-reminders.eyesight|fade-screen|true
org.gnome.desktop.break-reminders.eyesight|interval-seconds|uint32 1200
org.gnome.desktop.break-reminders.eyesight|lock-screen|false
org.gnome.desktop.break-reminders.eyesight|notify|true
org.gnome.desktop.break-reminders.eyesight|notify-overdue|true
org.gnome.desktop.break-reminders.eyesight|notify-upcoming|false
org.gnome.desktop.break-reminders.eyesight|play-sound|true
org.gnome.desktop.break-reminders.movement|countdown|false
org.gnome.desktop.break-reminders.movement|delay-seconds|uint32 180
org.gnome.desktop.break-reminders.movement|duration-seconds|uint32 300
org.gnome.desktop.break-reminders.movement|fade-screen|true
org.gnome.desktop.break-reminders.movement|interval-seconds|uint32 1800
org.gnome.desktop.break-reminders.movement|lock-screen|false
org.gnome.desktop.break-reminders.movement|notify|true
org.gnome.desktop.break-reminders.movement|notify-overdue|true
org.gnome.desktop.break-reminders.movement|notify-upcoming|true
org.gnome.desktop.break-reminders.movement|play-sound|true
org.gnome.desktop.break-reminders.eyesight|countdown|false
org.gnome.desktop.break-reminders.eyesight|delay-seconds|uint32 180
org.gnome.desktop.break-reminders.eyesight|duration-seconds|uint32 20
org.gnome.desktop.break-reminders.eyesight|fade-screen|true
org.gnome.desktop.break-reminders.eyesight|interval-seconds|uint32 1200
org.gnome.desktop.break-reminders.eyesight|lock-screen|false
org.gnome.desktop.break-reminders.eyesight|notify|true
org.gnome.desktop.break-reminders.eyesight|notify-overdue|true
org.gnome.desktop.break-reminders.eyesight|notify-upcoming|false
org.gnome.desktop.break-reminders.eyesight|play-sound|true
org.gnome.desktop.break-reminders.movement|countdown|false
org.gnome.desktop.break-reminders.movement|delay-seconds|uint32 180
org.gnome.desktop.break-reminders.movement|duration-seconds|uint32 300
org.gnome.desktop.break-reminders.movement|fade-screen|true
org.gnome.desktop.break-reminders.movement|interval-seconds|uint32 1800
org.gnome.desktop.break-reminders.movement|lock-screen|false
org.gnome.desktop.break-reminders.movement|notify|true
org.gnome.desktop.break-reminders.movement|notify-overdue|true
org.gnome.desktop.break-reminders.movement|notify-upcoming|true
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
org.gnome.desktop.interface|enable-hot-corners|false
org.gnome.desktop.interface|font-antialiasing|'grayscale'
org.gnome.desktop.interface|font-hinting|'slight'
org.gnome.desktop.interface|font-name|'Adwaita Sans 11'
org.gnome.desktop.interface|font-rendering|'automatic'
org.gnome.desktop.interface|font-rgba-order|'rgb'
org.gnome.desktop.interface|gtk-color-palette|'black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:goldenrod4:dodger blue:pink:light green:gray10:gray30:gray75:gray90'
org.gnome.desktop.interface|gtk-color-scheme|''
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
org.gnome.desktop.notifications|application-children|['gnome-about-panel', 'org-gnome-systemmonitor', 'gnome-power-panel', 'google-chrome', 'code', 'org-gnome-nautilus', 'org-flameshot-flameshot', 'org-gnome-terminal-preferences', 'org-gnome-extensions', 'org-gnome-software', 'org-gnome-ptyxis', 'org-gnome-baobab', 'audacious', 'update-manager']
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
org.gnome.desktop.peripherals.keyboard|delay|uint32 500
org.gnome.desktop.peripherals.keyboard|numlock-state|true
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
org.gnome.desktop.sound|theme-name|'Yaru'
org.gnome.desktop.thumbnail-cache|maximum-age|180
org.gnome.desktop.thumbnail-cache|maximum-size|512
org.gnome.desktop.thumbnailers|disable|@as []
org.gnome.desktop.thumbnailers|disable-all|false
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
org.gnome.mutter|output-luminance|@a(ssssud) []
org.gnome.mutter|overlay-key|'Super_L'
org.gnome.mutter|workspaces-only-on-primary|true
org.gnome.mutter.keybindings|cancel-input-capture|['<Super><Shift>Escape']
org.gnome.mutter.keybindings|rotate-monitor|['XF86RotateWindows']
org.gnome.mutter.keybindings|switch-monitor|['<Super>p', 'XF86Display']
org.gnome.mutter.keybindings|toggle-tiled-left|['<Super>Left']
org.gnome.mutter.keybindings|toggle-tiled-right|['<Super>Right']
org.gnome.mutter.wayland|xwayland-allow-byte-swapped-clients|false
org.gnome.mutter.wayland|xwayland-allow-grabs|false
org.gnome.mutter.wayland|xwayland-disable-extension|@as []
org.gnome.mutter.wayland|xwayland-grab-access-rules|@as []
org.gnome.mutter.wayland|xwayland-scaling-factor|0.0
org.gnome.mutter.wayland.keybindings|restore-shortcuts|@as []
org.gnome.mutter.wayland.keybindings|switch-to-session-1|['<Primary><Alt>F1']
org.gnome.mutter.wayland.keybindings|switch-to-session-10|['<Primary><Alt>F10']
org.gnome.mutter.wayland.keybindings|switch-to-session-11|['<Primary><Alt>F11']
org.gnome.mutter.wayland.keybindings|switch-to-session-12|['<Primary><Alt>F12']
org.gnome.mutter.wayland.keybindings|switch-to-session-2|['<Primary><Alt>F2']
org.gnome.mutter.wayland.keybindings|switch-to-session-3|['<Primary><Alt>F3']
org.gnome.mutter.wayland.keybindings|switch-to-session-4|['<Primary><Alt>F4']
org.gnome.mutter.wayland.keybindings|switch-to-session-5|['<Primary><Alt>F5']
org.gnome.mutter.wayland.keybindings|switch-to-session-6|['<Primary><Alt>F6']
org.gnome.mutter.wayland.keybindings|switch-to-session-7|['<Primary><Alt>F7']
org.gnome.mutter.wayland.keybindings|switch-to-session-8|['<Primary><Alt>F8']
org.gnome.mutter.wayland.keybindings|switch-to-session-9|['<Primary><Alt>F9']
org.gnome.shell|allow-extension-installation|true
org.gnome.shell|always-show-log-out|false
org.gnome.shell|app-picker-layout|[{'blueman-manager.desktop': <{'position': <0>}>, 'ca.desrt.dconf-editor.desktop': <{'position': <1>}>, 'com.mattjakeman.ExtensionManager.desktop': <{'position': <2>}>, 'org.flameshot.Flameshot.desktop': <{'position': <3>}>, 'htop.desktop': <{'position': <4>}>, 'org.gnome.Screenshot.desktop': <{'position': <5>}>, 'btop.desktop': <{'position': <6>}>, 'org.pulseaudio.pavucontrol.desktop': <{'position': <7>}>, 'System': <{'position': <8>}>, 'org.gnome.SystemMonitor.desktop': <{'position': <9>}>, 'io.github.celluloid_player.Celluloid.desktop': <{'position': <10>}>, 'Utilities': <{'position': <11>}>, 'gparted.desktop': <{'position': <12>}>, 'org.gnome.gThumb.desktop': <{'position': <13>}>, 'mpv.desktop': <{'position': <14>}>, 'libreoffice-math.desktop': <{'position': <15>}>, 'libreoffice-impress.desktop': <{'position': <16>}>, 'libreoffice-writer.desktop': <{'position': <17>}>}, {'vlc.desktop': <{'position': <0>}>, 'org.gnome.Software.desktop': <{'position': <1>}>, 'org.gnome.baobab.desktop': <{'position': <2>}>, 'org.gnome.DiskUtility.desktop': <{'position': <3>}>, 'org.gnome.TextEditor.desktop': <{'position': <4>}>, 'org.qbittorrent.qBittorrent.desktop': <{'position': <5>}>, 'org.gnome.Calculator.desktop': <{'position': <6>}>, 'org.gnome.Characters.desktop': <{'position': <7>}>, 'org.gnome.clocks.desktop': <{'position': <8>}>, 'cmatrix.desktop': <{'position': <9>}>, 'org.gnome.font-viewer.desktop': <{'position': <10>}>, 'org.gnome.Yelp.desktop': <{'position': <11>}>, 'display-im7.q16.desktop': <{'position': <12>}>, 'gnome-language-selector.desktop': <{'position': <13>}>, 'org.gnome.Logs.desktop': <{'position': <14>}>, 'org.gnome.seahorse.Application.desktop': <{'position': <15>}>, 'net.nokyan.Resources.desktop': <{'position': <16>}>, 'update-manager.desktop': <{'position': <17>}>, 'org.gnome.Sysprof.desktop': <{'position': <18>}>, 'libreoffice-startcenter.desktop': <{'position': <19>}>, 'libreoffice-base.desktop': <{'position': <20>}>, 'libreoffice-calc.desktop': <{'position': <21>}>, 'libreoffice-draw.desktop': <{'position': <22>}>, 'bt-connect.desktop': <{'position': <23>}>, 'org.gnome.Settings.desktop': <{'position': <24>}>}, {'ib-power-menu.desktop': <{'position': <0>}>, 'chrome-profile1.desktop': <{'position': <1>}>, 'chrome-profile2.desktop': <{'position': <2>}>, 'openwebui.desktop': <{'position': <3>}>}]
org.gnome.shell|command-history|@as []
org.gnome.shell|development-tools|true
org.gnome.shell|disable-extension-version-validation|false
org.gnome.shell|disable-user-extensions|false
org.gnome.shell|disabled-extensions|['apps-menu@gnome-shell-extensions.gcampax.github.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com', 'light-style@gnome-shell-extensions.gcampax.github.com', 'native-window-placement@gnome-shell-extensions.gcampax.github.com', 'screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com', 'status-icons@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com', 'windowsNavigator@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com', 'ubuntu-dock@ubuntu.com', 'tiling-assistant@ubuntu.com', 'snapd-prompting@canonical.com', 'snapd-search-provider@canonical.com']
org.gnome.shell|enabled-extensions|['rice-dock@ib-hussain', 'rice-top-bar@ib-hussain', 'start-overlay-in-application-view@Hex_cz', 'launch-new-instance@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com', 'system-monitor@gnome-shell-extensions.gcampax.github.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'ding@rastersoft.com', 'web-search-provider@ubuntu.com', 'ubuntu-appindicators@ubuntu.com']
org.gnome.shell|favorite-apps|['org.gnome.Nautilus.desktop', 'code.desktop', 'org.gnome.Ptyxis.desktop', 'audacious.desktop', 'google-chrome.desktop']
org.gnome.shell|last-selected-power-profile|'performance'
org.gnome.shell|looking-glass-history|@as []
org.gnome.shell|remember-mount-password|false
org.gnome.shell|start-in-overview|false
org.gnome.shell|welcome-dialog-last-shown-version|'50.1'
org.gnome.shell.app-switcher|current-workspace-only|false
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
org.gnome.shell.keybindings|screenshot|['<Shift><Super>s']
org.gnome.shell.keybindings|screenshot-window|@as []
org.gnome.shell.keybindings|shift-overview-down|['<Super><Alt>Down']
org.gnome.shell.keybindings|shift-overview-up|['<Super><Alt>Up']
org.gnome.shell.keybindings|show-screen-recording-ui|['<Shift><Super>r']
org.gnome.shell.keybindings|show-screenshot-ui|['Print']
org.gnome.shell.keybindings|switch-to-application-1|['<Super>1']
org.gnome.shell.keybindings|switch-to-application-2|['<Super>2']
org.gnome.shell.keybindings|switch-to-application-3|['<Super>3']
org.gnome.shell.keybindings|switch-to-application-4|['<Super>4']
org.gnome.shell.keybindings|switch-to-application-5|['<Super>5']
org.gnome.shell.keybindings|switch-to-application-6|['<Super>6']
org.gnome.shell.keybindings|switch-to-application-7|['<Super>7']
org.gnome.shell.keybindings|switch-to-application-8|['<Super>8']
org.gnome.shell.keybindings|switch-to-application-9|['<Super>9']
org.gnome.shell.keybindings|toggle-application-view|@as []
org.gnome.shell.keybindings|toggle-message-tray|@as []
org.gnome.shell.keybindings|toggle-overview|['<Super>Tab']
org.gnome.shell.keybindings|toggle-quick-settings|['<Super>a']
org.gnome.shell.weather|automatic-location|false
org.gnome.shell.weather|locations|@av []
org.gnome.shell.window-switcher|app-icon-mode|'both'
org.gnome.shell.window-switcher|current-workspace-only|true
org.gnome.shell.world-clocks|locations|@av []
org.gnome.shell.app-switcher|current-workspace-only|false
org.gnome.shell.window-switcher|app-icon-mode|'both'
org.gnome.shell.window-switcher|current-workspace-only|true
org.gnome.settings-daemon.plugins.color|night-light-enabled|false
org.gnome.settings-daemon.plugins.color|night-light-last-coordinates|(91.0, 181.0)
org.gnome.settings-daemon.plugins.color|night-light-schedule-automatic|false
org.gnome.settings-daemon.plugins.color|night-light-schedule-from|20.0
org.gnome.settings-daemon.plugins.color|night-light-schedule-to|6.0
org.gnome.settings-daemon.plugins.color|night-light-temperature|uint32 2700
org.gnome.settings-daemon.plugins.color|recalibrate-display-threshold|uint32 0
org.gnome.settings-daemon.plugins.color|recalibrate-printer-threshold|uint32 0
org.gnome.settings-daemon.plugins.housekeeping|donation-reminder-enabled|true
org.gnome.settings-daemon.plugins.housekeeping|donation-reminder-last-shown|int64 1787656318488855
org.gnome.settings-daemon.plugins.housekeeping|free-percent-notify|0.050000000000000003
org.gnome.settings-daemon.plugins.housekeeping|free-percent-notify-again|0.01
org.gnome.settings-daemon.plugins.housekeeping|free-size-gb-no-notify|1
org.gnome.settings-daemon.plugins.housekeeping|ignore-paths|@as []
org.gnome.settings-daemon.plugins.housekeeping|min-notify-period|10
org.gnome.settings-daemon.plugins.power|ambient-enabled|true
org.gnome.settings-daemon.plugins.power|idle-brightness|30
org.gnome.settings-daemon.plugins.power|idle-dim|true
org.gnome.settings-daemon.plugins.power|lid-close-ac-action|'suspend'
org.gnome.settings-daemon.plugins.power|lid-close-battery-action|'suspend'
org.gnome.settings-daemon.plugins.power|lid-close-suspend-with-external-monitor|false
org.gnome.settings-daemon.plugins.power|power-button-action|'interactive'
org.gnome.settings-daemon.plugins.power|power-saver-profile-on-low-battery|true
org.gnome.settings-daemon.plugins.power|sleep-inactive-ac-timeout|900
org.gnome.settings-daemon.plugins.power|sleep-inactive-ac-type|'suspend'
org.gnome.settings-daemon.plugins.power|sleep-inactive-battery-timeout|900
org.gnome.settings-daemon.plugins.power|sleep-inactive-battery-type|'suspend'
org.gnome.settings-daemon.plugins.xsettings|disabled-gtk-modules|@as []
org.gnome.settings-daemon.plugins.xsettings|enabled-gtk-modules|@as []
org.gnome.settings-daemon.plugins.xsettings|overrides|@a{sv} {}
org.gnome.desktop.default-applications.terminal|exec|'xdg-terminal-exec'
org.gnome.desktop.default-applications.terminal|exec-arg|'--'
SETTINGS    local ptyxis_profile_uuid=""
    local ptyxis_profile_path=""
    local ptyxis_profile_schema="org.gnome.Ptyxis.Profile"

    if [[ -n "${FIXED_SCHEMAS[org.gnome.Ptyxis]+x}" ]]; then
        ptyxis_profile_uuid="$(
            gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null |
                tr -d "'" || true
        )"
        if [[ -z "$ptyxis_profile_uuid" ]]; then
            ptyxis_profile_uuid="fc74a141e2ae4f898a215b02e8cd73aa"
            set_fixed \
                org.gnome.Ptyxis \
                profile-uuids \
                "['$ptyxis_profile_uuid']"
            set_fixed \
                org.gnome.Ptyxis \
                default-profile-uuid \
                "'$ptyxis_profile_uuid'"
        fi

        ptyxis_profile_path="/org/gnome/Ptyxis/Profiles/$ptyxis_profile_uuid/"
        set_relocatable \
            "$ptyxis_profile_schema" \
            "$ptyxis_profile_path" \
            palette \
            "'IB Glass'"
        set_relocatable \
            "$ptyxis_profile_schema" \
            "$ptyxis_profile_path" \
            label \
            "'IB Glass Terminal'"
        set_relocatable \
            "$ptyxis_profile_schema" \
            "$ptyxis_profile_path" \
            opacity \
            1.0
    else
        warn "Ptyxis schema is unavailable; its profile settings were skipped."
        SKIPPED=$((SKIPPED + 1))
    fi

    # Ubuntu 25.04 and later use this list for Ctrl+Alt+T and
    # xdg-terminal-exec. Ptyxis is first; GNOME Terminal remains a fallback.
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] Would select Ptyxis in ~/.config/ubuntu-xdg-terminals.list."
    else
        mkdir -p "$HOME/.config"
        printf '%s\n' \
            'org.gnome.Ptyxis.desktop:new-window' \
            'org.gnome.Terminal.desktop' \
            >"$HOME/.config/ubuntu-xdg-terminals.list"
    fi

    # Retain the source Arch GNOME Terminal profile for people who deliberately
    # launch that fallback; it is no longer Ubuntu's primary terminal.
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

        if [[ "$TARGET_PLATFORM" == "ubuntu" ]]; then
        # DING provides the Windows-style desktop icons requested for Ubuntu.
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
            org.gnome.Ptyxis.desktop \
            org.gnome.Terminal.desktop \
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
        rice-dock@ib-hussain
        rice-top-bar@ib-hussain
        start-overlay-in-application-view@Hex_cz
        launch-new-instance@gnome-shell-extensions.gcampax.github.com
        places-menu@gnome-shell-extensions.gcampax.github.com
        system-monitor@gnome-shell-extensions.gcampax.github.com
        user-theme@gnome-shell-extensions.gcampax.github.com
    )
    local -a disabled_snapshot=(
        arch-dock-icon@ib-hussain
        hidetopbar@mathieu.bidon.ca
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
        # Rice Dock is the one cross-distribution dock. Both system/upstream
        # docks share its schema but must not run alongside it.
        set_extension_state dash-to-dock@micxgx.gmail.com disable
        set_extension_state ubuntu-dock@ubuntu.com disable
        set_extension_state ding@rastersoft.com enable
        # Arch uses Mutter's edge tiling and Super+Left/Right directly.
        # Ubuntu's Tiling Assistant overrides those exact settings.
        set_extension_state tiling-assistant@ubuntu.com disable
        set_extension_state ubuntu-appindicators@ubuntu.com enable
        if [[ "$UBUNTU_RELEASE_VERSION" == "26.04" ]]; then
            set_extension_state web-search-provider@ubuntu.com enable
        else
            set_extension_state web-search-provider@ubuntu.com disable
        fi

        # The Ubuntu build is intentionally Snap-free.
        set_extension_state snapd-prompting@canonical.com disable
        set_extension_state snapd-search-provider@canonical.com disable
    else
        set_extension_state dash-to-dock@micxgx.gmail.com disable
        set_extension_state ubuntu-dock@ubuntu.com disable
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

    log "Applying Ibrahim's schema-aware GNOME 48/50 snapshot for $TARGET_PLATFORM."

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
