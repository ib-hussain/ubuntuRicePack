#!/usr/bin/env bash
# Install Ubuntu repository packages plus explicitly supported external packages.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_normal_user
require_ubuntu

INSTALL_MODE="${RICE_INSTALL_MODE:-desktop}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            INSTALL_MODE="${2:?Missing value for --mode}"
            shift 2
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

case "$INSTALL_MODE" in
    desktop)
        PACKAGE_FILE="$REPO_ROOT/packages/ubuntu-packages.txt"
        ;;
    wsl)
        PACKAGE_FILE="$REPO_ROOT/packages/wsl-packages.txt"
        ;;
    *)
        fail "Unsupported package mode: $INSTALL_MODE"
        ;;
esac

[[ -f "$PACKAGE_FILE" ]] || fail "Package manifest is missing: $PACKAGE_FILE"

log "Refreshing Ubuntu package metadata."
run_root env DEBIAN_FRONTEND=noninteractive apt-get update
run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl gpg software-properties-common

if command -v add-apt-repository >/dev/null 2>&1; then
    run_root add-apt-repository -y universe >/dev/null 2>&1 || true
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update
fi

declare -a requested_packages=()
declare -a available_packages=()
declare -A seen_packages=()

while IFS= read -r package_name || [[ -n "$package_name" ]]; do
    package_name="${package_name%%#*}"
    package_name="${package_name//$'\r'/}"
    package_name="${package_name#"${package_name%%[![:space:]]*}"}"
    package_name="${package_name%"${package_name##*[![:space:]]}"}"

    [[ -n "$package_name" ]] || continue
    [[ "$package_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9+._:-]*$ ]] ||
        fail "Invalid package entry in $PACKAGE_FILE: $package_name"

    if [[ -z "${seen_packages[$package_name]:-}" ]]; then
        requested_packages+=("$package_name")
        seen_packages["$package_name"]=1
    fi
done < "$PACKAGE_FILE"

for package_name in "${requested_packages[@]}"; do
    if apt_package_exists "$package_name"; then
        available_packages+=("$package_name")
    else
        warn "Not available for this Ubuntu release; skipped: $package_name"
    fi
done

if ((${#available_packages[@]} > 0)); then
    log "Installing ${#available_packages[@]} package(s) from Ubuntu repositories."
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${available_packages[@]}"
fi

install_eza() {
    command -v eza >/dev/null 2>&1 && return 0

    if apt_package_exists eza; then
        run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y eza
        return 0
    fi

    log "Adding the eza project's signed Debian repository."
    local key_file=""
    key_file="$(mktemp "${TMPDIR:-/tmp}/eza-key.XXXXXX")"
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
        gpg --dearmor >"$key_file"
    run_root install -Dm644 "$key_file" /etc/apt/keyrings/gierens.gpg
    rm -f -- "$key_file"

    printf '%s\n' \
        'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' |
        run_root tee /etc/apt/sources.list.d/gierens.list >/dev/null
    run_root chmod 0644 \
        /etc/apt/keyrings/gierens.gpg \
        /etc/apt/sources.list.d/gierens.list
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y eza
}

install_vscode() {
    command -v code >/dev/null 2>&1 && return 0

    log "Adding Microsoft's signed Visual Studio Code repository."
    local key_file=""
    local architecture=""
    key_file="$(mktemp "${TMPDIR:-/tmp}/microsoft-key.XXXXXX")"
    architecture="$(dpkg --print-architecture)"

    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
        gpg --dearmor >"$key_file"
    run_root install -Dm644 "$key_file" /usr/share/keyrings/microsoft.gpg
    rm -f -- "$key_file"

    printf '%s\n' \
        "Types: deb" \
        "URIs: https://packages.microsoft.com/repos/code" \
        "Suites: stable" \
        "Components: main" \
        "Architectures: $architecture" \
        "Signed-By: /usr/share/keyrings/microsoft.gpg" |
        run_root tee /etc/apt/sources.list.d/vscode.sources >/dev/null

    run_root env DEBIAN_FRONTEND=noninteractive apt-get update
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y code
}

install_chrome() {
    command -v google-chrome-stable >/dev/null 2>&1 && return 0

    if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
        warn "Google Chrome's official Linux package is amd64-only; skipped."
        return 0
    fi

    log "Installing Google's official Chrome .deb package."
    local chrome_deb=""
    chrome_deb="$(mktemp "${TMPDIR:-/tmp}/google-chrome.XXXXXX.deb")"
    curl -fL \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o "$chrome_deb"
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$chrome_deb"
    rm -f -- "$chrome_deb"
}

install_starship() {
    command -v starship >/dev/null 2>&1 && return 0

    log "Installing Starship in ~/.local/bin from its official installer."
    local installer=""
    installer="$(mktemp "${TMPDIR:-/tmp}/starship-install.XXXXXX")"
    curl -fsSL https://starship.rs/install.sh -o "$installer"
    sh "$installer" -y -b "$HOME/.local/bin"
    rm -f -- "$installer"
}

remove_snap_stack() {
    [[ "${REMOVE_SNAP:-1}" == "1" ]] || return 0

    log "Enforcing the Snap-free UbuntuRicePack configuration."
    local package_name=""
    local -a installed_snap_packages=()

    if is_systemd_running; then
        run_root systemctl disable --now snapd.socket snapd.service \
            snapd.seeded.service 2>/dev/null || true
    fi

    for package_name in firefox snapd snapd-desktop-integration; do
        if dpkg-query -W -f='${db:Status-Abbrev}' "$package_name" \
                2>/dev/null | grep -q '^ii'; then
            installed_snap_packages+=("$package_name")
        fi
    done

    if ((${#installed_snap_packages[@]} > 0)); then
        run_root env DEBIAN_FRONTEND=noninteractive apt-get purge -y \
            "${installed_snap_packages[@]}"
    fi

    printf '%s\n' \
        'Package: snapd' \
        'Pin: release a=*' \
        'Pin-Priority: -10' |
        run_root tee /etc/apt/preferences.d/ubuntu-rice-pack-no-snap.pref \
            >/dev/null
}

if [[ "$INSTALL_MODE" == "desktop" ]]; then
    [[ "${INSTALL_EZA:-1}" == "1" ]] && install_eza
    [[ "${INSTALL_VSCODE:-1}" == "1" ]] && install_vscode
    [[ "${INSTALL_CHROME:-1}" == "1" ]] && install_chrome
    [[ "${INSTALL_STARSHIP:-1}" == "1" ]] && install_starship
    remove_snap_stack
else
    [[ "${INSTALL_EZA:-1}" == "1" ]] && install_eza
    [[ "${INSTALL_STARSHIP:-1}" == "1" ]] && install_starship
fi

log "Package installation is complete."

