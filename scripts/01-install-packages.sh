#!/usr/bin/env bash
# Install Ubuntu repository packages and approved upstream/vendor software.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

REMOVE_SNAP="${REMOVE_SNAP:-1}"
INSTALL_GOOGLE_CHROME="${INSTALL_GOOGLE_CHROME:-1}"
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_OLLAMA="${INSTALL_OLLAMA:-1}"
INSTALL_VENTOY="${INSTALL_VENTOY:-1}"
UPDATE_EXTERNAL_PACKAGES="${UPDATE_EXTERNAL_PACKAGES:-0}"
STRICT_EXTERNALS="${STRICT_EXTERNALS:-0}"

if is_wsl; then
    DEFAULT_PACKAGE_FILE="$REPO_ROOT/packages/wsl-packages.txt"
else
    DEFAULT_PACKAGE_FILE="$REPO_ROOT/packages/ubuntu-packages.txt"
fi
PACKAGE_FILE="${RICE_PACKAGE_FILE:-$DEFAULT_PACKAGE_FILE}"

enable_ubuntu_components() {
    local component=""

    if ! command -v add-apt-repository >/dev/null 2>&1; then
        apt_install software-properties-common
    fi

    for component in universe multiverse restricted; do
        if run_root add-apt-repository -y "$component" >>"$LOG_FILE" 2>&1; then
            log "Enabled Ubuntu repository component: $component"
        else
            warn "Could not enable repository component '$component'; it may already be configured."
        fi
    done
}

remove_snap_stack() {
    local snap_name=""
    local -a installed_snaps=()
    local snap_backup=""

    [[ "$REMOVE_SNAP" == "1" ]] || {
        log "Snap removal disabled by REMOVE_SNAP=$REMOVE_SNAP."
        return 0
    }

    log "Removing the Snap stack as requested by the no-Snap policy."

    if command -v snap >/dev/null 2>&1; then
        mapfile -t installed_snaps < <(
            snap list 2>/dev/null |
                awk 'NR > 1 {print $1}'
        )

        # Two passes allow applications to be removed before bases that were
        # initially reported as dependencies.
        for _pass in 1 2; do
            for snap_name in "${installed_snaps[@]}"; do
                if snap list "$snap_name" >/dev/null 2>&1; then
                    run_root snap remove --purge "$snap_name" >>"$LOG_FILE" 2>&1 ||
                        warn "Could not remove Snap package yet: $snap_name"
                fi
            done
        done
    fi

    # Ubuntu's firefox APT package is a Snap launcher. Purging both names keeps
    # it from silently restoring snapd.
    apt_purge firefox snapd >>"$LOG_FILE" 2>&1 ||
        warn "snapd/firefox were absent or could not be fully purged."

    if [[ -d "$TARGET_HOME/snap" ]]; then
        snap_backup="$BACKUP_ROOT/home/$TARGET_USER/snap"
        mkdir -p -- "$(dirname -- "$snap_backup")"
        if [[ ! -e "$snap_backup" ]]; then
            mv -- "$TARGET_HOME/snap" "$snap_backup"
            log "Moved the former user Snap data to $snap_backup"
        else
            warn "Snap backup already exists; leaving $TARGET_HOME/snap untouched."
        fi
    fi

    install_root_file /etc/apt/preferences.d/ubuntuRicePack-no-snap.pref 0644 <<'EOF_NO_SNAP'
# Managed by ubuntuRicePack.
# Prevent APT dependencies from silently reinstalling snapd.
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF_NO_SNAP
}

translate_package() {
    local package_name="$1"

    case "$package_name" in
        # Packages handled by the external installers below.
        google-chrome|google-chrome-stable|visual-studio-code-bin|code|\
        ollama|ventoy|ventoy-bin)
            return 0
            ;;

        # Explicit no-Firefox/no-Snap policy.
        firefox)
            return 0
            ;;

        # Arch package names and older Ubuntu translations.
        base)
            printf '%s\n' ubuntu-minimal
            ;;
        base-devel)
            printf '%s\n' build-essential
            ;;
        python)
            printf '%s\n' python3
            ;;
        python-gobject)
            printf '%s\n' python3-gi
            ;;
        python-pillow)
            printf '%s\n' python3-pil
            ;;
        python-pypng|python3-pypng)
            printf '%s\n' python3-png
            ;;
        gtk3|libgtk-3-0)
            printf '%s\n' libgtk-3-0t64 libgtk-3-bin
            ;;
        gtk4)
            printf '%s\n' libgtk-4-1
            ;;
        libadwaita)
            printf '%s\n' libadwaita-1-0
            ;;
        dconf)
            printf '%s\n' dconf-cli
            ;;
        gdm)
            printf '%s\n' gdm3
            ;;
        extension-manager)
            printf '%s\n' gnome-shell-extension-manager
            ;;
        chrome-gnome-shell)
            printf '%s\n' gnome-browser-connector
            ;;
        nautilus-python)
            printf '%s\n' python3-nautilus
            ;;
        sushi)
            printf '%s\n' gnome-sushi
            ;;
        evince)
            printf '%s\n' papers
            ;;
        fd)
            printf '%s\n' fd-find
            ;;
        tldr)
            printf '%s\n' tealdeer
            ;;
        p7zip|p7zip-full)
            printf '%s\n' 7zip
            ;;
        docker)
            printf '%s\n' docker.io
            ;;
        docker-compose|docker-compose-plugin)
            printf '%s\n' docker-compose-v2
            ;;
        cpupower)
            printf '%s\n' linux-tools-generic
            ;;
        conky)
            printf '%s\n' conky-all
            ;;
        bluez-utils)
            printf '%s\n' bluez
            ;;
        gvfs-afc|gvfs-gphoto2|gvfs-mtp|gvfs-smb)
            printf '%s\n' gvfs-backends
            ;;
        networkmanager)
            printf '%s\n' network-manager
            ;;
        network-manager-gnome)
            printf '%s\n' network-manager-applet
            ;;
        noto-fonts)
            printf '%s\n' fonts-noto-core fonts-noto-mono
            ;;
        noto-fonts-cjk)
            printf '%s\n' fonts-noto-cjk
            ;;
        noto-fonts-emoji)
            printf '%s\n' fonts-noto-color-emoji
            ;;
        noto-fonts-extra)
            printf '%s\n' fonts-noto-extra
            ;;
        ttf-dejavu|fonts-dejavu)
            printf '%s\n' fonts-dejavu-core
            ;;
        ttf-liberation)
            printf '%s\n' fonts-liberation
            ;;
        ttf-ubuntu-font-family)
            printf '%s\n' fonts-ubuntu
            ;;
        ttf-jetbrains-mono-nerd)
            printf '%s\n' fonts-jetbrains-mono fonts-powerline
            ;;
        ttf-noto-nerd|ttf-nerd-fonts-symbols)
            printf '%s\n' fonts-noto-mono fonts-powerline
            ;;
        linux|linux-image-generic)
            printf '%s\n' linux-generic
            ;;
        intel-ucode)
            printf '%s\n' intel-microcode
            ;;
        mesa)
            printf '%s\n' libgl1-mesa-dri mesa-vulkan-drivers
            ;;
        mesa-utils)
            printf '%s\n' mesa-utils libgl1-mesa-dri mesa-vulkan-drivers
            ;;
        grub)
            printf '%s\n' grub2-common
            ;;
        grub-efi-amd64)
            if [[ "$(dpkg --print-architecture)" == "amd64" && -d /sys/firmware/efi ]]; then
                printf '%s\n' grub-efi-amd64
            else
                printf '%s\n' grub2-common
            fi
            ;;
        xorg-xrandr)
            printf '%s\n' x11-xserver-utils
            ;;
        xorg-xwayland)
            printf '%s\n' xwayland
            ;;
        vlc-plugins-all)
            printf '%s\n' \
                vlc-plugin-access-extra \
                vlc-plugin-base \
                vlc-plugin-qt \
                vlc-plugin-samba \
                vlc-plugin-skins2 \
                vlc-plugin-video-output \
                vlc-plugin-video-splitter \
                vlc-plugin-visualization
            ;;
        yay|yay-debug|gnome-shell-extension-dash-to-dock-git)
            # No AUR helper or upstream Dash-to-Dock on Ubuntu.
            return 0
            ;;
        *)
            printf '%s\n' "$package_name"
            ;;
    esac
}

collect_repository_packages() {
    local package_file="$1"
    local raw_line=""
    local source_package=""
    local translated_package=""
    local -A seen=()
    local -a translated=()

    REPOSITORY_PACKAGES=()
    MISSING_REPOSITORY_PACKAGES=()

    [[ -f "$package_file" ]] || fail "Package list is missing: $package_file"

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        raw_line="${raw_line%%#*}"
        source_package="$(
            printf '%s' "$raw_line" |
                sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
        )"
        [[ -n "$source_package" ]] || continue

        if [[ "$source_package" =~ [[:space:]] ]]; then
            warn "Package-list entry must contain one package name: $source_package"
            continue
        fi

        mapfile -t translated < <(translate_package "$source_package")
        for translated_package in "${translated[@]}"; do
            [[ -n "$translated_package" ]] || continue
            if [[ -n "${seen[$translated_package]:-}" ]]; then
                continue
            fi
            seen["$translated_package"]=1

            if apt_package_available "$translated_package"; then
                REPOSITORY_PACKAGES+=("$translated_package")
            else
                MISSING_REPOSITORY_PACKAGES+=("$source_package -> $translated_package")
            fi
        done
    done <"$package_file"
}

install_repository_packages() {
    local package_name=""

    log "Reading APT packages from $PACKAGE_FILE"
    collect_repository_packages "$PACKAGE_FILE"

    if [[ "${#MISSING_REPOSITORY_PACKAGES[@]}" -gt 0 ]]; then
        warn "The following translated packages are unavailable for this Ubuntu release:"
        for package_name in "${MISSING_REPOSITORY_PACKAGES[@]}"; do
            warn "  $package_name"
        done
    fi

    [[ "${#REPOSITORY_PACKAGES[@]}" -gt 0 ]] ||
        fail "No valid Ubuntu repository packages were found in $PACKAGE_FILE."

    log "Installing ${#REPOSITORY_PACKAGES[@]} unique Ubuntu repository packages."
    if apt_install "${REPOSITORY_PACKAGES[@]}"; then
        return 0
    fi

    warn "The batch APT transaction failed; retrying packages individually to isolate failures."
    for package_name in "${REPOSITORY_PACKAGES[@]}"; do
        if apt_package_installed "$package_name"; then
            continue
        fi
        apt_install "$package_name" ||
            warn "APT could not install: $package_name"
    done
}

install_apt_signing_key() {
    local key_url="$1"
    local destination="$2"
    local expected_fingerprint="${3:-}"
    local armored_key=""
    local binary_key=""
    local gpg_home=""
    local fingerprints=""

    armored_key="$(make_temp_file)"
    binary_key="$(make_temp_file)"
    gpg_home="$(make_temp_dir)"
    register_temp_path "$armored_key"
    register_temp_path "$binary_key"
    register_temp_path "$gpg_home"
    chmod 0700 "$gpg_home"
    download_file "$key_url" "$armored_key"

    if [[ -n "$expected_fingerprint" ]]; then
        fingerprints="$(
            gpg \
                --homedir "$gpg_home" \
                --batch \
                --show-keys \
                --with-colons \
                "$armored_key" 2>/dev/null |
                awk -F: '$1 == "fpr" {print $10}'
        )"
        if ! grep -Fxq "$expected_fingerprint" <<<"$fingerprints"; then
            fail "The downloaded signing key did not contain the expected fingerprint."
        fi
    fi

    gpg \
        --homedir "$gpg_home" \
        --batch \
        --yes \
        --dearmor \
        --output "$binary_key" \
        "$armored_key"
    run_root install -D -m 0644 "$binary_key" "$destination"
}

configure_google_chrome_repository() {
    local architecture=""

    [[ "$INSTALL_GOOGLE_CHROME" == "1" ]] || return 0
    is_wsl && return 0

    architecture="$(dpkg --print-architecture)"
    if [[ "$architecture" != "amd64" ]]; then
        warn "Google Chrome's Linux package is not available for $architecture; skipped."
        return 0
    fi

    log "Configuring Google's signed APT repository for Chrome."
    install_apt_signing_key \
        https://dl.google.com/linux/linux_signing_key.pub \
        /usr/share/keyrings/google-chrome.gpg \
        EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796

    install_root_file /etc/apt/sources.list.d/google-chrome.sources 0644 <<'EOF_CHROME'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF_CHROME
}

configure_vscode_repository() {
    local architecture=""

    [[ "$INSTALL_VSCODE" == "1" ]] || return 0
    is_wsl && return 0

    architecture="$(dpkg --print-architecture)"
    case "$architecture" in
        amd64|arm64|armhf) ;;
        *)
            warn "Microsoft VS Code is not published for $architecture; skipped."
            return 0
            ;;
    esac

    log "Configuring Microsoft's signed APT repository for VS Code."
    install_apt_signing_key \
        https://packages.microsoft.com/keys/microsoft.asc \
        /usr/share/keyrings/microsoft.gpg \
        BC528686B50D79E339D3721CEB3E94ADBE1229CF

    install_root_file /etc/apt/sources.list.d/vscode.sources 0644 <<'EOF_VSCODE'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF_VSCODE

    install_root_file /etc/apt/preferences.d/ubuntuRicePack-vscode.pref 0644 <<'EOF_VSCODE_PIN'
Package: code
Pin: origin "packages.microsoft.com"
Pin-Priority: 9999
EOF_VSCODE_PIN
}

install_vendor_apt_packages() {
    local -a vendor_packages=()

    if [[ "$INSTALL_GOOGLE_CHROME" == "1" ]] &&
        ! is_wsl &&
        [[ "$(dpkg --print-architecture)" == "amd64" ]]
    then
        vendor_packages+=(google-chrome-stable)
    fi

    if [[ "$INSTALL_VSCODE" == "1" ]] && ! is_wsl; then
        case "$(dpkg --print-architecture)" in
            amd64|arm64|armhf)
                vendor_packages+=(code)
                ;;
        esac
    fi

    [[ "${#vendor_packages[@]}" -gt 0 ]] || return 0

    apt_update
    log "Installing vendor APT packages: ${vendor_packages[*]}"
    apt_install "${vendor_packages[@]}"
}

install_ollama_upstream() {
    local installer=""

    [[ "$INSTALL_OLLAMA" == "1" ]] || return 0
    [[ "${SKIP_LOCAL_AI:-0}" != "1" ]] || {
        log "Ollama skipped because SKIP_LOCAL_AI=1."
        return 0
    }

    if command -v ollama >/dev/null 2>&1 &&
        [[ "$UPDATE_EXTERNAL_PACKAGES" != "1" ]]
    then
        log "Ollama is already installed."
        return 0
    fi

    installer="$(make_temp_file)"
    register_temp_path "$installer"
    log "Downloading Ollama's official Linux installer."
    download_file https://ollama.com/install.sh "$installer"

    if [[ -n "${OLLAMA_VERSION:-}" ]]; then
        OLLAMA_VERSION="$OLLAMA_VERSION" sh "$installer"
    else
        sh "$installer"
    fi

    command -v ollama >/dev/null 2>&1 ||
        return 1

    if getent group ollama >/dev/null 2>&1; then
        run_root usermod -aG ollama "$TARGET_USER"
    fi

    if is_wsl && ! have_systemd; then
        warn "Ollama installed, but WSL systemd is disabled; its service cannot start automatically yet."
    fi
}

write_ventoy_launcher() {
    local destination="$1"
    local ventoy_directory="$2"
    local executable="$3"
    local temporary=""

    if [[ -d "$destination" ]]; then
        warn "Cannot install Ventoy launcher over a directory: $destination"
        return 1
    fi

    if [[ -L "$destination" ]]; then
        unlink -- "$destination"
    elif [[ -e "$destination" ]]; then
        backup_path "$destination"
    fi

    temporary="$(make_temp_file)"
    register_temp_path "$temporary"
    {
        printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
        printf 'cd -- %q\n' "$ventoy_directory"
        printf 'exec %q \"$@\"\n' "./$executable"
    } >"$temporary"
    install -m 0755 "$temporary" "$destination"
}

install_ventoy_upstream() {
    local release_json=""
    local asset_info=""
    local tag=""
    local asset_name=""
    local asset_url=""
    local digest=""
    local archive=""
    local archive_listing=""
    local extract_dir=""
    local source_dir=""
    local version=""
    local install_root="$TARGET_HOME/.local/opt/ventoy"
    local version_dir=""
    local current_link="$install_root/current"
    local gui_binary=""

    [[ "$INSTALL_VENTOY" == "1" ]] || return 0
    is_wsl && return 0

    release_json="$(make_temp_file)"
    archive="$(make_temp_file)"
    archive_listing="$(make_temp_file)"
    extract_dir="$(make_temp_dir)"
    register_temp_path "$release_json"
    register_temp_path "$archive"
    register_temp_path "$archive_listing"
    register_temp_path "$extract_dir"

    log "Resolving the latest official Ventoy Linux release."
    download_file \
        https://api.github.com/repos/ventoy/Ventoy/releases/latest \
        "$release_json"

    asset_info="$(
        python3 - "$release_json" <<'PY_VENTOY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    release = json.load(stream)

for asset in release.get("assets", []):
    name = asset.get("name", "")
    if re.fullmatch(r"ventoy-[0-9.]+-linux\.tar\.gz", name):
        print(
            release.get("tag_name", ""),
            name,
            asset.get("browser_download_url", ""),
            asset.get("digest", ""),
            sep="\t",
        )
        break
PY_VENTOY
    )"

    [[ -n "$asset_info" ]] || {
        warn "No Ventoy Linux archive was found in the latest official release."
        return 1
    }

    IFS=$'\t' read -r tag asset_name asset_url digest <<<"$asset_info"
    [[ -n "$tag" && -n "$asset_url" && "$digest" == sha256:* ]] || {
        warn "The Ventoy release did not provide complete signed asset metadata."
        return 1
    }

    log "Downloading $asset_name."
    download_file "$asset_url" "$archive"
    verify_sha256 "$archive" "$digest"

    tar -tzf "$archive" >"$archive_listing"
    if grep -Eq '(^/|(^|/)\.\.(/|$))' "$archive_listing"; then
        warn "Ventoy archive contains an unsafe path; refusing to extract it."
        return 1
    fi

    tar -xzf "$archive" -C "$extract_dir"
    source_dir="$(
        find "$extract_dir" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -name 'ventoy-*' \
            -print \
            -quit
    )"
    [[ -n "$source_dir" ]] || return 1

    version="${tag#v}"
    version_dir="$install_root/$version"
    mkdir -p -- "$install_root" "$TARGET_HOME/.local/bin"

    if [[ ! -d "$version_dir" ]]; then
        cp -a -- "$source_dir" "$version_dir"
    fi

    if [[ ! -f "$version_dir/Ventoy2Disk.sh" ]]; then
        warn "Ventoy installation directory is incomplete: $version_dir"
        return 1
    fi

    if [[ -e "$current_link" && ! -L "$current_link" ]]; then
        backup_path "$current_link"
        warn "Ventoy's managed 'current' path is not a symlink; refusing to overwrite it."
        return 1
    fi

    ln -sfn -- "$version_dir" "$current_link"
    write_ventoy_launcher \
        "$TARGET_HOME/.local/bin/ventoy2disk" \
        "$current_link" \
        Ventoy2Disk.sh
    if [[ -f "$current_link/VentoyWeb.sh" ]]; then
        write_ventoy_launcher \
            "$TARGET_HOME/.local/bin/ventoyweb" \
            "$current_link" \
            VentoyWeb.sh
    fi

    case "$(dpkg --print-architecture)" in
        amd64) gui_binary="VentoyGUI.x86_64" ;;
        i386) gui_binary="VentoyGUI.i386" ;;
        arm64) gui_binary="VentoyGUI.aarch64" ;;
    esac

    if [[ -n "$gui_binary" && -f "$current_link/$gui_binary" ]]; then
        write_ventoy_launcher \
            "$TARGET_HOME/.local/bin/ventoygui" \
            "$current_link" \
            "$gui_binary"
    fi

    log "Installed Ventoy $version under $install_root."
}

run_external_installer() {
    local label="$1"
    local external_tmp=""
    shift

    # Isolate `exit` calls from an optional upstream installer so a transient
    # vendor outage can follow STRICT_EXTERNALS instead of killing this stage.
    # Give the subshell one parent-owned temporary tree so it is still cleaned
    # even though array mutations inside a subshell do not propagate outward.
    external_tmp="$(make_temp_dir)"
    register_temp_path "$external_tmp"
    if (
        export TMPDIR="$external_tmp"
        "$@"
    ); then
        log "$label setup complete."
    elif [[ "$STRICT_EXTERNALS" == "1" ]]; then
        fail "$label setup failed."
    else
        warn "$label setup failed; continuing because STRICT_EXTERNALS=0."
    fi
}

configure_docker() {
    if ! apt_package_installed docker.io; then
        return 0
    fi

    if getent group docker >/dev/null 2>&1; then
        run_root usermod -aG docker "$TARGET_USER"
        log "Added $TARGET_USER to the docker group; a logout/login is required."
    fi

    if is_wsl; then
        if [[ "${ENABLE_WSL_DOCKER_DAEMON:-0}" == "1" ]] && have_systemd; then
            run_root systemctl enable --now docker.service
        else
            log "WSL detected; not enabling a second Docker daemon automatically."
        fi
    elif have_systemd; then
        run_root systemctl enable --now docker.service
    fi
}

main() {
    require_regular_user
    require_ubuntu
    assert_repo_path "packages"
    sudo_validate

    log "Starting Ubuntu package and external software installation."
    if is_wsl; then
        log "WSL detected; using $PACKAGE_FILE."
    else
        log "Desktop Ubuntu detected; using $PACKAGE_FILE."
    fi

    # Bootstrap only what this script itself needs.
    apt_update
    apt_install \
        ca-certificates \
        curl \
        wget \
        gnupg \
        software-properties-common \
        python3 \
        git \
        rsync \
        xz-utils

    enable_ubuntu_components
    apt_update
    remove_snap_stack
    apt_update
    install_repository_packages

    configure_google_chrome_repository
    configure_vscode_repository
    run_external_installer "Vendor APT packages" install_vendor_apt_packages
    run_external_installer "Ollama" install_ollama_upstream
    run_external_installer "Ventoy" install_ventoy_upstream
    configure_docker

    log "Package installation stage complete."
    if [[ "${#MISSING_REPOSITORY_PACKAGES[@]}" -gt 0 ]]; then
        warn "Review unavailable-package warnings in $LOG_FILE."
    fi
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi