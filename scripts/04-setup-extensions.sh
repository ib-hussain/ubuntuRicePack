#!/usr/bin/env bash
# Install and configure Ibrahim's GNOME extension inventory on Ubuntu.
#
# Repository policy:
#   - Keep Rice Dock and Rice Top Bar in the repository because both contain
#     reviewed rice-specific code.
#   - Install official GNOME extensions from Ubuntu packages.
#   - Download the remaining unmodified third-party extension from the reviewed
#     GNOME Extensions service.
#   - Disable Ubuntu Dock, upstream Dash-to-Dock, the retired Arch icon patch,
#     and upstream Hide Top Bar so only one dock and one top-bar controller run.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

readonly EXTENSION_SOURCE="$REPO_ROOT/configs/extensions"
readonly EXTENSION_LIST="$EXTENSION_SOURCE/extension-list.txt"
readonly EXTENSION_DEST="$TARGET_HOME/.local/share/gnome-shell/extensions"
readonly RICE_DOCK_UUID="rice-dock@ib-hussain"
readonly RICE_TOP_BAR_UUID="rice-top-bar@ib-hussain"
readonly RETIRED_ICON_UUID="arch-dock-icon@ib-hussain"
readonly HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"
readonly DASH_TO_DOCK_UUID="dash-to-dock@micxgx.gmail.com"
readonly UBUNTU_DOCK_UUID="ubuntu-dock@ubuntu.com"

declare -A EGO_URLS=(
    ["start-overlay-in-application-view@Hex_cz"]="https://extensions.gnome.org/download-extension/start-overlay-in-application-view@Hex_cz.shell-extension.zip"
)

readonly -a CUSTOM_UUIDS=(
    "$RICE_DOCK_UUID"
    "$RICE_TOP_BAR_UUID"
)

readonly -a OFFICIAL_GNOME_UUIDS=(
    "apps-menu@gnome-shell-extensions.gcampax.github.com"
    "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com"
    "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "light-style@gnome-shell-extensions.gcampax.github.com"
    "native-window-placement@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
    "status-icons@gnome-shell-extensions.gcampax.github.com"
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "window-list@gnome-shell-extensions.gcampax.github.com"
    "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
)

# These seven effective extensions reproduce the enabled Arch snapshot. Rice
# Dock replaces both Dash-to-Dock and the old icon patch; Rice Top Bar replaces
# the upstream Hide Top Bar build.
readonly -a ACTIVE_SNAPSHOT_UUIDS=(
    "$RICE_DOCK_UUID"
    "$RICE_TOP_BAR_UUID"
    "start-overlay-in-application-view@Hex_cz"
    "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

# They remain installed because they were in the export, but the configured
# Arch desktop had them disabled.
readonly -a DISABLED_SNAPSHOT_UUIDS=(
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
)

readonly -a SHARED_ACTIVE_UBUNTU_UUIDS=(
    "ding@rastersoft.com"
    "ubuntu-appindicators@ubuntu.com"
)

readonly -a BASE_DISABLED_UBUNTU_UUIDS=(
    "$RETIRED_ICON_UUID"
    "$HIDE_TOP_BAR_UUID"
    "$DASH_TO_DOCK_UUID"
    "$UBUNTU_DOCK_UUID"
    "tiling-assistant@ubuntu.com"
    "snapd-prompting@canonical.com"
    "snapd-search-provider@canonical.com"
)

declare -a MANIFEST_UUIDS=()
declare -a INSTALL_FAILURES=()
declare -a ACTIVE_UBUNTU_UUIDS=()
declare -a DISABLED_UBUNTU_UUIDS=()
STATE_ONLY=0

usage() {
    cat <<'USAGE'
Usage: 04-setup-extensions.sh [--state-only]

Options:
  --state-only   Do not download or replace extension code. Reapply the
                 curated enabled/disabled state and regenerate reports.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --state-only | --enable-only)
            STATE_ONLY=1
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

array_contains() {
    local needle="$1"
    shift
    local candidate=""

    for candidate in "$@"; do
        [[ "$candidate" == "$needle" ]] && return 0
    done
    return 1
}

configure_release_specific_extension_policy() {
    ACTIVE_UBUNTU_UUIDS=("${SHARED_ACTIVE_UBUNTU_UUIDS[@]}")
    DISABLED_UBUNTU_UUIDS=("${BASE_DISABLED_UBUNTU_UUIDS[@]}")

    case "$RICE_UBUNTU_VERSION" in
        25.04)
            # Ubuntu added this provider in 26.04. Keep a stray newer copy
            # disabled rather than failing because Plucky does not ship it.
            DISABLED_UBUNTU_UUIDS+=("web-search-provider@ubuntu.com")
            log "Ubuntu 25.04 profile: web-search-provider is not required."
            ;;
        26.04)
            ACTIVE_UBUNTU_UUIDS+=("web-search-provider@ubuntu.com")
            ;;
        *)
            fail "No Ubuntu-native extension policy exists for $RICE_UBUNTU_VERSION."
            ;;
    esac
}

detect_gnome_major() {
    local version_output=""

    require_command gnome-shell
    version_output="$(gnome-shell --version 2>/dev/null)" ||
        fail "Could not read the GNOME Shell version."

    if [[ "$version_output" =~ ([0-9]+)(\.[0-9]+)+ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        fail "Could not parse GNOME Shell version: $version_output"
    fi
}

extension_present() {
    local uuid="$1"

    [[ -f "$EXTENSION_DEST/$uuid/metadata.json" ]] ||
        [[ -f "/usr/share/gnome-shell/extensions/$uuid/metadata.json" ]] ||
        gnome-extensions list 2>/dev/null |
            grep -Fx "$uuid" >/dev/null
}

extension_enabled() {
    local uuid="$1"

    gnome-extensions list --enabled 2>/dev/null |
        grep -Fx "$uuid" >/dev/null ||
        gsettings get org.gnome.shell enabled-extensions 2>/dev/null |
            grep -Fq "'$uuid'"
}

extension_info_field() {
    local uuid="$1"
    local field="$2"

    gnome-extensions info "$uuid" 2>/dev/null |
        sed -n "s/^[[:space:]]*$field:[[:space:]]*//p" |
        head -n 1
}

install_required_packages() {
    local package_name=""
    local -a required_packages=(
        gnome-shell-extensions
        gnome-shell-ubuntu-extensions
        libglib2.0-bin
        python3
        rsync
        unzip
    )
    local -a missing_packages=()

    for package_name in "${required_packages[@]}"; do
        if ! apt_package_installed "$package_name"; then
            missing_packages+=("$package_name")
        fi
    done

    if [[ "${#missing_packages[@]}" -eq 0 ]]; then
        log "All Ubuntu GNOME extension packages are already installed."
        return 0
    fi

    log "Installing required Ubuntu GNOME extension packages."
    sudo_validate
    apt_update
    apt_install "${missing_packages[@]}"
}

load_and_validate_manifest() {
    local raw_line=""
    local uuid=""
    local official_uuid=""
    local -A known=()
    local -A seen=()

    [[ -f "$EXTENSION_LIST" ]] ||
        fail "Missing extension inventory: $EXTENSION_LIST"

    for uuid in "${CUSTOM_UUIDS[@]}"; do
        known["$uuid"]=1
    done
    for uuid in "${!EGO_URLS[@]}"; do
        known["$uuid"]=1
    done
    for official_uuid in "${OFFICIAL_GNOME_UUIDS[@]}"; do
        known["$official_uuid"]=1
    done

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        raw_line="${raw_line%%#*}"
        uuid="$(trim "$raw_line")"
        [[ -n "$uuid" ]] || continue

        [[ "$uuid" != *[[:space:]]* ]] ||
            fail "Invalid manifest entry containing whitespace: $uuid"
        [[ -n "${known[$uuid]:-}" ]] ||
            fail "Unknown extension in manifest: $uuid"
        [[ -z "${seen[$uuid]:-}" ]] ||
            fail "Duplicate extension in manifest: $uuid"

        seen["$uuid"]=1
        MANIFEST_UUIDS+=("$uuid")
    done <"$EXTENSION_LIST"

    [[ "${#MANIFEST_UUIDS[@]}" -eq 17 ]] ||
        fail "Expected 17 effective extension UUIDs; found ${#MANIFEST_UUIDS[@]}."

    for uuid in "${!known[@]}"; do
        [[ -n "${seen[$uuid]:-}" ]] ||
            fail "The exported extension inventory is missing: $uuid"
    done

    log "Validated the complete 17-entry effective extension inventory."
}

validate_extension_metadata() {
    local metadata_file="$1"
    local expected_uuid="$2"
    local shell_major="$3"

    python3 - "$metadata_file" "$expected_uuid" "$shell_major" <<'PY_METADATA'
import json
import pathlib
import sys

metadata_path = pathlib.Path(sys.argv[1])
expected_uuid = sys.argv[2]
shell_major = sys.argv[3]

try:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid metadata.json: {error}")

if metadata.get("uuid") != expected_uuid:
    raise SystemExit(
        f"metadata UUID is {metadata.get('uuid')!r}, expected {expected_uuid!r}"
    )

supported = {str(value) for value in metadata.get("shell-version", [])}
if shell_major not in supported:
    raise SystemExit(
        f"{expected_uuid} does not declare GNOME Shell {shell_major} support"
    )

print(metadata.get("version-name", metadata.get("version", "unknown")))
PY_METADATA
}

install_extension_tree() {
    local source_dir="$1"
    local uuid="$2"
    local source_label="$3"
    local shell_major="$4"
    local destination="$EXTENSION_DEST/$uuid"
    local version=""

    [[ -f "$source_dir/metadata.json" ]] ||
        fail "Extension metadata is missing for $uuid in $source_dir"

    if ! version="$(
        validate_extension_metadata \
            "$source_dir/metadata.json" \
            "$uuid" \
            "$shell_major"
    )"; then
        fail "Rejected extension metadata for $uuid."
    fi

    if [[ -e "$destination" || -L "$destination" ]]; then
        backup_path "$destination"
    fi

    mkdir -p -- "$destination"
    rsync -a --delete -- "$source_dir/" "$destination/"

    if [[ -d "$destination/schemas" ]]; then
        rm -f -- "$destination/schemas/gschemas.compiled"
        glib-compile-schemas "$destination/schemas" ||
            fail "Could not compile extension schemas for $uuid."
    fi

    printf '%s\n' "$source_label" >"$destination/.ubuntuRicePack-source"
    log "Installed $uuid version $version from $source_label."
}

archive_is_safe() {
    local archive="$1"

    python3 - "$archive" <<'PY_ARCHIVE'
import pathlib
import stat
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])

try:
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise ValueError("CRC validation failed")

        for item in bundle.infolist():
            name = item.filename
            path = pathlib.PurePosixPath(name)
            mode = (item.external_attr >> 16) & 0xFFFF

            if (
                path.is_absolute()
                or ".." in path.parts
                or "\\" in name
                or stat.S_ISLNK(mode)
            ):
                raise ValueError(f"unsafe archive entry: {name}")
except (OSError, ValueError, zipfile.BadZipFile) as error:
    print(error, file=sys.stderr)
    raise SystemExit(1)
PY_ARCHIVE
}

download_ego_archive() {
    local url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl \
            --fail \
            --location \
            --show-error \
            --silent \
            --retry 3 \
            --retry-all-errors \
            --connect-timeout 20 \
            --output "$destination" \
            "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget \
            --tries=3 \
            --timeout=20 \
            --output-document="$destination" \
            "$url"
    else
        return 1
    fi

    [[ -s "$destination" ]]
}

install_ego_extension() {
    local uuid="$1"
    local shell_major="$2"
    local base_url="${EGO_URLS[$uuid]}"
    local url="${base_url}?shell_version=${shell_major}"
    local work_dir=""
    local archive=""
    local extracted=""

    work_dir="$(make_temp_dir)"
    register_temp_path "$work_dir"
    archive="$work_dir/$uuid.zip"
    extracted="$work_dir/extracted"
    mkdir -p -- "$extracted"

    log "Downloading the reviewed GNOME Shell $shell_major build of $uuid."
    if ! download_ego_archive "$url" "$archive"; then
        if extension_present "$uuid"; then
            warn "Download failed; keeping the already-installed copy of $uuid."
            return 0
        fi
        INSTALL_FAILURES+=("$uuid: download failed")
        return 0
    fi

    if ! archive_is_safe "$archive"; then
        INSTALL_FAILURES+=("$uuid: downloaded archive failed validation")
        return 0
    fi

    unzip -q "$archive" -d "$extracted"
    if ! install_extension_tree \
        "$extracted" \
        "$uuid" \
        "extensions.gnome.org" \
        "$shell_major"
    then
        INSTALL_FAILURES+=("$uuid: installation failed")
    fi
}

install_custom_extensions() {
    local shell_major="$1"
    local uuid=""
    local source_dir=""

    for uuid in "${CUSTOM_UUIDS[@]}"; do
        source_dir="$EXTENSION_SOURCE/$uuid"
        [[ -d "$source_dir" ]] ||
            fail "The custom extension must remain in the repository: $source_dir"

        install_extension_tree \
            "$source_dir" \
            "$uuid" \
            "ubuntuRicePack repository" \
            "$shell_major"
    done
}

set_extension_state_fallback() {
    local uuid="$1"
    local desired="$2"

    python3 - "$uuid" "$desired" <<'PY_STATE'
import ast
import subprocess
import sys

uuid, desired = sys.argv[1:3]
schema = "org.gnome.shell"


def get_array(key):
    result = subprocess.run(
        ["gsettings", "get", schema, key],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    if result.startswith("@as "):
        result = result[4:]
    value = ast.literal_eval(result)
    return list(value) if isinstance(value, list) else []


def set_array(key, values):
    rendered = "[" + ", ".join(repr(value) for value in values) + "]"
    subprocess.run(
        ["gsettings", "set", schema, key, rendered],
        check=True,
    )


enabled = get_array("enabled-extensions")
disabled = get_array("disabled-extensions")

if desired == "enable":
    if uuid not in enabled:
        enabled.append(uuid)
    disabled = [value for value in disabled if value != uuid]
else:
    enabled = [value for value in enabled if value != uuid]
    if uuid not in disabled:
        disabled.append(uuid)

set_array("enabled-extensions", enabled)
set_array("disabled-extensions", disabled)
PY_STATE
}

set_extension_state() {
    local uuid="$1"
    local desired="$2"

    if ! extension_present "$uuid"; then
        if [[ "$desired" == "enable" ]]; then
            INSTALL_FAILURES+=("$uuid: required extension is not installed")
        else
            log "Optional disabled extension is not installed: $uuid"
        fi
        return 0
    fi

    if gnome-extensions "$desired" "$uuid" >/dev/null 2>&1; then
        log "Configured extension state: $desired $uuid"
        return 0
    fi

    # A freshly copied extension may not enter the current Shell process until
    # the next login. Persist the state directly so it starts then.
    if set_extension_state_fallback "$uuid" "$desired"; then
        log "Persisted extension state for next login: $desired $uuid"
    else
        INSTALL_FAILURES+=("$uuid: could not persist '$desired' state")
    fi
}

verify_official_extensions() {
    local uuid=""

    for uuid in "${OFFICIAL_GNOME_UUIDS[@]}"; do
        if extension_present "$uuid"; then
            log "Ubuntu GNOME extension available: $uuid"
        else
            INSTALL_FAILURES+=("$uuid: missing from gnome-shell-extensions")
        fi
    done

    if extension_present "$UBUNTU_DOCK_UUID"; then
        log "Ubuntu Dock is available but will be disabled in favor of Rice Dock."
    else
        log "Ubuntu Dock is not installed; Rice Dock needs no system-dock fallback."
    fi
}

apply_extension_states() {
    local uuid=""

    gs_set org.gnome.shell disable-user-extensions false

    for uuid in "${ACTIVE_SNAPSHOT_UUIDS[@]}"; do
        set_extension_state "$uuid" enable
    done
    for uuid in "${DISABLED_SNAPSHOT_UUIDS[@]}"; do
        set_extension_state "$uuid" disable
    done
    for uuid in "${ACTIVE_UBUNTU_UUIDS[@]}"; do
        set_extension_state "$uuid" enable
    done
    for uuid in "${DISABLED_UBUNTU_UUIDS[@]}"; do
        set_extension_state "$uuid" disable
    done
}

write_extension_report() {
    local report_dir="$STATE_DIR/reports"
    local report_file="$report_dir/extensions-$RUN_ID.tsv"
    local all_file="$report_dir/extensions-$RUN_ID-all.txt"
    local enabled_file="$report_dir/extensions-$RUN_ID-enabled.txt"
    local shell_state_file="$report_dir/extensions-$RUN_ID-shell-state.txt"
    local info_file="$report_dir/extensions-$RUN_ID-info.txt"
    local journal_file="$report_dir/extensions-$RUN_ID-journal.txt"
    local uuid=""
    local effective_uuid=""
    local installed="no"
    local enabled="no"
    local desired="disabled"
    local source="Ubuntu package"
    local metadata=""
    local version="unavailable"
    local location="not installed"
    local runtime_state="not-loaded"
    local runtime_error=""

    mkdir -p -- "$report_dir"
    : >"$info_file"
    printf 'inventory_uuid\teffective_uuid\tsource\tlocation\tversion\tinstalled\tdesired\tenabled\truntime_state\truntime_error\n' \
        >"$report_file"

    for uuid in "${MANIFEST_UUIDS[@]}"; do
        effective_uuid="$uuid"
        source="Ubuntu package"
        desired="disabled"

        if array_contains "$uuid" "${CUSTOM_UUIDS[@]}"; then
            source="repository"
        elif [[ -n "${EGO_URLS[$uuid]:-}" ]]; then
            source="extensions.gnome.org"
        fi

        if array_contains "$uuid" "${ACTIVE_SNAPSHOT_UUIDS[@]}"; then
            desired="enabled"
        fi

        installed="no"
        enabled="no"
        metadata=""
        version="unavailable"
        location="not installed"
        runtime_state="not-loaded"
        runtime_error=""
        extension_present "$effective_uuid" && installed="yes"
        extension_enabled "$effective_uuid" && enabled="yes"
        runtime_state="$(
            extension_info_field "$effective_uuid" State || true
        )"
        runtime_state="${runtime_state:-not-loaded}"
        runtime_error="$(
            extension_info_field "$effective_uuid" Error || true
        )"

        if [[ -f "$EXTENSION_DEST/$effective_uuid/metadata.json" ]]; then
            metadata="$EXTENSION_DEST/$effective_uuid/metadata.json"
            location="$EXTENSION_DEST/$effective_uuid"
        elif [[ -f "/usr/share/gnome-shell/extensions/$effective_uuid/metadata.json" ]]; then
            metadata="/usr/share/gnome-shell/extensions/$effective_uuid/metadata.json"
            location="/usr/share/gnome-shell/extensions/$effective_uuid"
        fi

        if [[ -n "$metadata" ]]; then
            version="$(
                python3 - "$metadata" <<'PY_REPORT_VERSION'
import json
import pathlib
import sys

try:
    value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    print("unreadable")
else:
    print(value.get("version-name", value.get("version", "unknown")))
PY_REPORT_VERSION
            )"
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$uuid" \
            "$effective_uuid" \
            "$source" \
            "$location" \
            "$version" \
            "$installed" \
            "$desired" \
            "$enabled" \
            "$runtime_state" \
            "$runtime_error" >>"$report_file"

        {
            printf '===== %s =====\n' "$effective_uuid"
            gnome-extensions info "$effective_uuid" 2>&1 || true
            printf '\n'
        } >>"$info_file"

        if array_contains "$uuid" "${CUSTOM_UUIDS[@]}" &&
            [[ "$runtime_state" == "ERROR" ]]
        then
            INSTALL_FAILURES+=(
                "$uuid: GNOME Shell reports ERROR: ${runtime_error:-unknown error}"
            )
        fi
    done

    # Ubuntu-specific extensions are not part of the effective Arch export, but
    # they still need an explicit state audit on an Ubuntu installation.
    for uuid in \
        "ding@rastersoft.com" \
        "tiling-assistant@ubuntu.com" \
        "ubuntu-appindicators@ubuntu.com" \
        "web-search-provider@ubuntu.com" \
        "$RETIRED_ICON_UUID" \
        "$HIDE_TOP_BAR_UUID" \
        "$DASH_TO_DOCK_UUID" \
        "$UBUNTU_DOCK_UUID" \
        "snapd-prompting@canonical.com" \
        "snapd-search-provider@canonical.com"
    do
        installed="no"
        enabled="no"
        desired="disabled"
        metadata=""
        version="unavailable"
        location="not installed"
        runtime_state="not-loaded"
        runtime_error=""

        if array_contains "$uuid" "${ACTIVE_UBUNTU_UUIDS[@]}"; then
            desired="enabled"
        fi
        extension_present "$uuid" && installed="yes"
        extension_enabled "$uuid" && enabled="yes"
        runtime_state="$(extension_info_field "$uuid" State || true)"
        runtime_state="${runtime_state:-not-loaded}"
        runtime_error="$(extension_info_field "$uuid" Error || true)"

        if [[ -f "$EXTENSION_DEST/$uuid/metadata.json" ]]; then
            metadata="$EXTENSION_DEST/$uuid/metadata.json"
            location="$EXTENSION_DEST/$uuid"
        elif [[ -f "/usr/share/gnome-shell/extensions/$uuid/metadata.json" ]]; then
            metadata="/usr/share/gnome-shell/extensions/$uuid/metadata.json"
            location="/usr/share/gnome-shell/extensions/$uuid"
        fi

        if [[ -n "$metadata" ]]; then
            version="$(
                python3 - "$metadata" <<'PY_UBUNTU_VERSION'
import json
import pathlib
import sys

try:
    value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    print("unreadable")
else:
    print(value.get("version-name", value.get("version", "unknown")))
PY_UBUNTU_VERSION
            )"
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "ubuntu-native:$uuid" \
            "$uuid" \
            "Ubuntu package" \
            "$location" \
            "$version" \
            "$installed" \
            "$desired" \
            "$enabled" \
            "$runtime_state" \
            "$runtime_error" >>"$report_file"
    done

    gnome-extensions list 2>/dev/null | sort >"$all_file"
    gnome-extensions list --enabled 2>/dev/null | sort >"$enabled_file"
    {
        printf 'GNOME Shell: '
        gnome-shell --version 2>/dev/null || true
        printf 'enabled-extensions='
        gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true
        printf 'disabled-extensions='
        gsettings get org.gnome.shell disabled-extensions 2>/dev/null || true
    } >"$shell_state_file"

    if command -v journalctl >/dev/null 2>&1; then
        journalctl --user -b -o short-iso --no-pager 2>/dev/null |
            grep -E \
                '\[(rice-dock|rice-top-bar)@ib-hussain\]|GNOME Shell.*extension' \
                >"$journal_file" || :
    else
        printf 'journalctl is unavailable\n' >"$journal_file"
    fi

    log "Extension verification report: $report_file"
    log "Detailed extension metadata/state: $info_file"
    log "Rice extension journal excerpt: $journal_file"
    log "Complete extension inventory: $all_file"
    log "Enabled extension inventory: $enabled_file"
    log "GNOME Shell extension state snapshot: $shell_state_file"
}

main() {
    local shell_major=""
    local expected_shell_major=""

    require_user_session
    require_ubuntu
    require_command gnome-extensions
    require_command gsettings
    assert_repo_path "configs/extensions/$RICE_DOCK_UUID"
    assert_repo_path "configs/extensions/$RICE_TOP_BAR_UUID"

    shell_major="$(detect_gnome_major)"
    expected_shell_major="${RICE_GNOME_MAJOR:-${RICE_EXPECTED_GNOME_MAJOR:-}}"
    [[ -n "$expected_shell_major" ]] ||
        fail "No GNOME compatibility profile is defined for this Ubuntu release."

    if [[ "$shell_major" != "$expected_shell_major" &&
        "${ALLOW_UNSUPPORTED_GNOME:-0}" != "1" ]]
    then
        fail "Ubuntu $RICE_UBUNTU_VERSION expects GNOME $expected_shell_major; detected GNOME $shell_major."
    fi

    log "Preparing the Ubuntu $RICE_UBUNTU_VERSION GNOME $shell_major extension set."
    configure_release_specific_extension_policy
    load_and_validate_manifest

    if [[ "$STATE_ONLY" == "0" ]]; then
        install_required_packages
        mkdir -p -- "$EXTENSION_DEST"

        install_custom_extensions "$shell_major"
        install_ego_extension \
            "start-overlay-in-application-view@Hex_cz" \
            "$shell_major"
    else
        log "State-only mode: extension downloads and code replacement were skipped."
    fi

    verify_official_extensions
    apply_extension_states
    write_extension_report

    if [[ "${#INSTALL_FAILURES[@]}" -gt 0 ]]; then
        warn "Extension setup completed with ${#INSTALL_FAILURES[@]} problem(s):"
        printf '  - %s\n' "${INSTALL_FAILURES[@]}" | tee -a "$LOG_FILE" >&2
        fail "Resolve the extension errors above before applying GNOME settings."
    fi

    log "GNOME extension setup complete. Log out and back in after all stages finish."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
