#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

###############################################################################
# Install local branding assets and fetch the wallpaper collection at runtime.
#
# The wallpaper images are deliberately not stored in ubuntuRicePack. Only the
# assets/wallpapers directory from archRicePack is sparse-checked out into a
# temporary directory, copied to the target user's backgrounds directory, and
# then removed.
#
# Optional overrides:
#   RICE_WALLPAPER_REPO_URL  Git repository containing the wallpaper directory
#   RICE_WALLPAPER_REF       Branch or tag to fetch (default: main)
#   RICE_WALLPAPER_REPO_PATH Directory inside that repository
#   RICE_WALLPAPER_INTERVAL  Rotation interval in seconds (default: 5)
###############################################################################

WALLPAPER_REPO_URL="${RICE_WALLPAPER_REPO_URL:-https://github.com/ib-hussain/archRicePack.git}"
WALLPAPER_REF="${RICE_WALLPAPER_REF:-main}"
WALLPAPER_REPO_PATH="${RICE_WALLPAPER_REPO_PATH:-assets/wallpapers}"
WALLPAPER_INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"

FETCH_WORK_DIR=""
FETCHED_WALLPAPER_DIR=""

run_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

has_user_session() {
    [[ "$EUID" -ne 0 &&
        -n "${DBUS_SESSION_BUS_ADDRESS:-}" &&
        -n "${XDG_RUNTIME_DIR:-}" ]]
}

detect_target_user() {
    local detected=""

    if [[ -n "${TARGET_USER:-}" ]]; then
        detected="$TARGET_USER"
    elif [[ -n "${RICE_TARGET_USER:-}" ]]; then
        detected="$RICE_TARGET_USER"
    elif [[ "$EUID" -ne 0 ]]; then
        detected="$(id -un)"
    elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        detected="$SUDO_USER"
    else
        detected="$(
            getent passwd |
                awk -F: \
                    '$3 >= 1000 && $3 < 65534 &&
                     $7 !~ /(nologin|false)$/ {print $1; exit}'
        )"
    fi

    if [[ -z "$detected" ]] || ! id "$detected" >/dev/null 2>&1; then
        fail "Could not determine a valid target user. Set RICE_TARGET_USER."
    fi

    printf '%s\n' "$detected"
}

target_home_for_user() {
    local user="$1"
    local home_dir=""

    home_dir="$(getent passwd "$user" | awk -F: '{print $6}')"
    if [[ -z "$home_dir" ]]; then
        fail "Could not determine the home directory for: $user"
    fi

    printf '%s\n' "$home_dir"
}

safe_chown_user() {
    local user="$1"
    local path="$2"
    local group=""

    [[ -e "$path" || -L "$path" ]] || return 0
    [[ "$user" != "root" ]] || return 0

    group="$(id -gn "$user")"
    run_root chown -R "$user:$group" "$path"
}

safe_gsettings() {
    if has_user_session && command -v gsettings >/dev/null 2>&1; then
        gsettings set "$@" || true
    fi
}

cleanup_fetch_work_dir() {
    if [[ -n "$FETCH_WORK_DIR" &&
        -d "$FETCH_WORK_DIR" &&
        "$FETCH_WORK_DIR" == "${TMPDIR:-/tmp}"/ubuntuRicePack-wallpapers.* ]]
    then
        rm -rf -- "$FETCH_WORK_DIR"
    fi
}

trap cleanup_fetch_work_dir EXIT

apply_fit_wallpaper_settings_now() {
    has_user_session || return 0

    safe_gsettings org.gnome.desktop.background picture-options scaled
    safe_gsettings org.gnome.desktop.background primary-color "#000000"
    safe_gsettings org.gnome.desktop.background secondary-color "#000000"
    safe_gsettings org.gnome.desktop.background color-shading-type solid

    safe_gsettings org.gnome.desktop.screensaver picture-options scaled
    safe_gsettings org.gnome.desktop.screensaver primary-color "#000000"
    safe_gsettings org.gnome.desktop.screensaver secondary-color "#000000"
    safe_gsettings org.gnome.desktop.screensaver color-shading-type solid
}

install_login_and_face_assets() {
    local target_user="$1"
    local target_home="$2"
    local source_image="$REPO_ROOT/assets/ib.png"
    local accounts_icon="/var/lib/AccountsService/icons/$target_user"

    if [[ ! -f "$source_image" ]]; then
        warn "assets/ib.png is missing; skipping login and face assets."
        return 0
    fi

    log "Installing the login background and user face."

    run_root install -Dm644 \
        "$source_image" \
        /usr/share/backgrounds/rice/ib.png

    run_root install -Dm644 "$source_image" "$target_home/.face"
    safe_chown_user "$target_user" "$target_home/.face"

    run_root install -Dm644 "$source_image" "$accounts_icon"
    run_root install -Dm644 "$source_image" "$accounts_icon.png"

    run_root mkdir -p /etc/dconf/db/gdm.d
    run_root tee /etc/dconf/db/gdm.d/90-rice-login-background \
        >/dev/null <<'GDM_CONFIG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/rice/ib.png'
picture-uri-dark='file:///usr/share/backgrounds/rice/ib.png'
picture-options='scaled'
primary-color='#000000'
secondary-color='#000000'
color-shading-type='solid'

[org/gnome/login-screen]
logo='file:///usr/share/backgrounds/rice/ib.png'
GDM_CONFIG

    if command -v dconf >/dev/null 2>&1; then
        run_root dconf update || warn "GDM dconf update failed."
    fi
}

fetch_wallpapers() {
    local checkout_dir=""

    if ! command -v git >/dev/null 2>&1; then
        warn "Git is unavailable; wallpapers cannot be downloaded."
        return 1
    fi

    FETCH_WORK_DIR="$(
        mktemp -d "${TMPDIR:-/tmp}/ubuntuRicePack-wallpapers.XXXXXX"
    )"
    checkout_dir="$FETCH_WORK_DIR/source"

    log "Fetching $WALLPAPER_REPO_PATH from $WALLPAPER_REPO_URL ($WALLPAPER_REF)."

    if ! GIT_TERMINAL_PROMPT=0 git clone \
        --depth 1 \
        --filter=blob:none \
        --sparse \
        --branch "$WALLPAPER_REF" \
        --single-branch \
        "$WALLPAPER_REPO_URL" \
        "$checkout_dir"
    then
        warn "Wallpaper repository download failed."
        return 1
    fi

    if ! git -C "$checkout_dir" sparse-checkout set "$WALLPAPER_REPO_PATH"; then
        warn "Could not select the remote wallpaper directory."
        return 1
    fi

    FETCHED_WALLPAPER_DIR="$checkout_dir/$WALLPAPER_REPO_PATH"
    if [[ ! -d "$FETCHED_WALLPAPER_DIR" ]]; then
        warn "The fetched repository does not contain: $WALLPAPER_REPO_PATH"
        return 1
    fi

    return 0
}

install_fetched_wallpapers() {
    local target_user="$1"
    local target_home="$2"
    local destination="$target_home/.local/share/backgrounds/rice/wallpapers"
    local image_count=0

    if ! fetch_wallpapers; then
        if find "$destination" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) -print -quit 2>/dev/null |
                grep -q .
        then
            warn "Keeping the previously installed wallpaper collection."
        else
            warn "No wallpapers are available; the rotator will wait for them."
        fi
        return 0
    fi

    image_count="$(
        find "$FETCHED_WALLPAPER_DIR" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) |
            wc -l
    )"

    if [[ "$image_count" -eq 0 ]]; then
        warn "The remote wallpaper directory contains no supported images."
        return 0
    fi

    log "Installing $image_count wallpaper image(s) without resizing."

    run_root mkdir -p "$destination"
    run_root rsync \
        -a \
        --delete \
        --delete-excluded \
        --prune-empty-dirs \
        --include='*/' \
        --include='*.png' \
        --include='*.PNG' \
        --include='*.jpg' \
        --include='*.JPG' \
        --include='*.jpeg' \
        --include='*.JPEG' \
        --include='*.webp' \
        --include='*.WEBP' \
        --exclude='*' \
        "$FETCHED_WALLPAPER_DIR/" \
        "$destination/"

    safe_chown_user "$target_user" "$destination"
}

write_wallpaper_rotator() {
    local target_user="$1"
    local target_home="$2"
    local bin_dir="$target_home/.local/bin"
    local config_dir="$target_home/.config/ubuntuRicePack"
    local service_dir="$target_home/.config/systemd/user"
    local wants_dir="$service_dir/default.target.wants"
    local old_autostart="$target_home/.config/autostart/rice-wallpaper-rotator.desktop"

    run_root mkdir -p "$bin_dir" "$config_dir" "$service_dir" "$wants_dir"

    run_root tee "$bin_dir/rice-wallpaper-rotator" >/dev/null <<'ROTATOR'
#!/usr/bin/env bash
set -Eeuo pipefail

WALLPAPER_DIR="$HOME/.local/share/backgrounds/rice/wallpapers"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ubuntuRicePack/wallpaper.env"

if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"

if ! [[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
    INTERVAL=5
fi

apply_fit_mode() {
    gsettings set org.gnome.desktop.background picture-options scaled || true
    gsettings set org.gnome.desktop.background primary-color '#000000' || true
    gsettings set org.gnome.desktop.background secondary-color '#000000' || true
    gsettings set org.gnome.desktop.background color-shading-type solid || true

    gsettings set org.gnome.desktop.screensaver picture-options scaled || true
    gsettings set org.gnome.desktop.screensaver primary-color '#000000' || true
    gsettings set org.gnome.desktop.screensaver secondary-color '#000000' || true
    gsettings set org.gnome.desktop.screensaver color-shading-type solid || true
}

while true; do
    mapfile -d '' -t files < <(
        find "$WALLPAPER_DIR" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) \
            -print0 2>/dev/null |
            sort -z
    )

    if [[ "${#files[@]}" -eq 0 ]]; then
        sleep "$INTERVAL"
        continue
    fi

    for image in "${files[@]}"; do
        uri="$(
            python3 -c \
                'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
                "$image"
        )"

        apply_fit_mode
        gsettings set org.gnome.desktop.background picture-uri "$uri" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$uri" || true
        gsettings set org.gnome.desktop.screensaver picture-uri "$uri" || true

        sleep "$INTERVAL"
    done
done
ROTATOR

    run_root chmod 755 "$bin_dir/rice-wallpaper-rotator"

    if [[ ! -e "$config_dir/wallpaper.env" ]]; then
        run_root tee "$config_dir/wallpaper.env" >/dev/null <<CONFIG
# Seconds between wallpaper changes.
RICE_WALLPAPER_INTERVAL=$WALLPAPER_INTERVAL
CONFIG
    fi

    run_root tee "$service_dir/rice-wallpaper-rotator.service" \
        >/dev/null <<'SERVICE'
[Unit]
Description=UbuntuRicePack wallpaper rotator
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
SERVICE

    # Remove the old duplicate autostart path if an earlier version created it.
    run_root rm -f -- "$old_autostart"

    run_root ln -sfn \
        ../rice-wallpaper-rotator.service \
        "$wants_dir/rice-wallpaper-rotator.service"

    safe_chown_user "$target_user" "$bin_dir/rice-wallpaper-rotator"
    safe_chown_user "$target_user" "$config_dir"
    safe_chown_user "$target_user" "$service_dir"

    if has_user_session && [[ "$(id -un)" == "$target_user" ]]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now rice-wallpaper-rotator.service ||
            warn "Could not start the wallpaper rotator immediately."
    else
        log "Wallpaper rotator will start for $target_user at login."
    fi
}

apply_first_wallpaper_now() {
    local target_home="$1"
    local wallpaper_dir="$target_home/.local/share/backgrounds/rice/wallpapers"
    local first_wallpaper=""
    local uri=""

    has_user_session || return 0
    [[ -d "$wallpaper_dir" ]] || return 0

    first_wallpaper="$(
        find "$wallpaper_dir" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) |
            sort |
            head -n 1
    )"

    [[ -n "$first_wallpaper" ]] || return 0

    uri="$(
        python3 -c \
            'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
            "$first_wallpaper"
    )"

    apply_fit_wallpaper_settings_now
    safe_gsettings org.gnome.desktop.background picture-uri "$uri"
    safe_gsettings org.gnome.desktop.background picture-uri-dark "$uri"
    safe_gsettings org.gnome.desktop.screensaver picture-uri "$uri"
}

main() {
    local target_user=""
    local target_home=""

    target_user="$(detect_target_user)"
    target_home="$(target_home_for_user "$target_user")"

    log "Applying UbuntuRicePack assets for $target_user."

    install_login_and_face_assets "$target_user" "$target_home"
    install_fetched_wallpapers "$target_user" "$target_home"
    write_wallpaper_rotator "$target_user" "$target_home"
    apply_first_wallpaper_now "$target_home"

    log "Asset, GRUB, login, and wallpaper setup complete."
}

main "$@"
