#!/usr/bin/env bash
# Restore user configuration and fetch the wallpaper collection at runtime.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

WALLPAPER_REPO_URL="${RICE_WALLPAPER_REPO_URL:-https://github.com/ib-hussain/archRicePack.git}"
WALLPAPER_REF="${RICE_WALLPAPER_REF:-main}"
WALLPAPER_REPO_PATH="${RICE_WALLPAPER_REPO_PATH:-assets/wallpapers}"
WALLPAPER_INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"
INSTALL_WALLPAPER_ROTATOR="${INSTALL_WALLPAPER_ROTATOR:-1}"
COPY_CLUSTER_WORK="${COPY_CLUSTER_WORK:-1}"

restore_user_files() {
    local source_face=""
    local theme_root="$TARGET_HOME/.local/share/themes"
    local icon_root="$TARGET_HOME/.local/share/icons"

    log "Backing up existing user configuration before merging repository files."
    backup_path "$TARGET_HOME/.config/gtk-3.0"
    backup_path "$TARGET_HOME/.config/gtk-4.0"
    backup_path "$theme_root"
    backup_path "$icon_root"
    backup_path "$TARGET_HOME/.local/bin"
    backup_path "$TARGET_HOME/.config/autostart"
    backup_path "$TARGET_HOME/.local/share/nautilus-python"
    backup_path "$TARGET_HOME/.face"
    backup_path "$TARGET_HOME/.face.icon"

    mkdir -p -- \
        "$TARGET_HOME/.config" \
        "$TARGET_HOME/.config/autostart" \
        "$TARGET_HOME/.local/bin" \
        "$TARGET_HOME/.local/share" \
        "$theme_root" \
        "$icon_root"

    # Modern per-user XDG locations. Keep ~/.themes as a compatibility symlink
    # only when the user has not already created a real directory there.
    copy_dir_contents "$REPO_ROOT/configs/themes" "$theme_root"
    if [[ ! -e "$TARGET_HOME/.themes" && ! -L "$TARGET_HOME/.themes" ]]; then
        ln -s -- "$theme_root" "$TARGET_HOME/.themes"
        log "Created compatibility link: ~/.themes -> ~/.local/share/themes"
    fi

    copy_dir_contents \
        "$REPO_ROOT/configs/gtk-3.0" \
        "$TARGET_HOME/.config/gtk-3.0"
    copy_dir_contents \
        "$REPO_ROOT/configs/gtk-4.0" \
        "$TARGET_HOME/.config/gtk-4.0"
    copy_dir_contents \
        "$REPO_ROOT/configs/local-bin" \
        "$TARGET_HOME/.local/bin"
    copy_dir_contents \
        "$REPO_ROOT/configs/autostart" \
        "$TARGET_HOME/.config/autostart"
    
    # Nautilus Python extensions belong below an `extensions` directory. Accept
    # either repository layout without creating extensions/extensions.
    if [[ -d "$REPO_ROOT/configs/nautilus-python/extensions" ]]; then
        copy_dir_contents \
            "$REPO_ROOT/configs/nautilus-python/extensions" \
            "$TARGET_HOME/.local/share/nautilus-python/extensions"
    else
        copy_dir_contents \
            "$REPO_ROOT/configs/nautilus-python" \
            "$TARGET_HOME/.local/share/nautilus-python/extensions"
    fi

    if [[ "$COPY_CLUSTER_WORK" == "1" && -d "$REPO_ROOT/cluster-work" ]]; then
        mkdir -p -- "$TARGET_HOME/Downloads/cluster-work"
        copy_dir_contents \
            "$REPO_ROOT/cluster-work" \
            "$TARGET_HOME/Downloads/cluster-work"
    fi

    if [[ -f "$REPO_ROOT/configs/.face" ]]; then
        source_face="$REPO_ROOT/configs/.face"
    elif [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
        source_face="$REPO_ROOT/assets/ib.png"
    fi

    if [[ -n "$source_face" ]]; then
        copy_file "$source_face" "$TARGET_HOME/.face" 0644
        copy_file "$source_face" "$TARGET_HOME/.face.icon" 0644
    else
        warn "No user-face image was found in configs/.face or assets/ib.png."
    fi

    find "$TARGET_HOME/.local/bin" \
        -maxdepth 1 \
        -type f \
        -exec chmod 0755 {} + 2>/dev/null || true
}

fetch_and_install_wallpapers() {
    local work_dir=""
    local checkout_dir=""
    local source_dir=""
    local destination="$TARGET_HOME/.local/share/backgrounds/rice/wallpapers"
    local image_count=0

    case "$WALLPAPER_REPO_PATH" in
        /*|../*|*/../*|*/..)
            fail "Unsafe wallpaper repository path: $WALLPAPER_REPO_PATH"
            ;;
    esac

    require_command git
    require_command rsync

    work_dir="$(make_temp_dir)"
    register_temp_path "$work_dir"
    checkout_dir="$work_dir/source"

    log "Fetching only $WALLPAPER_REPO_PATH from $WALLPAPER_REPO_URL ($WALLPAPER_REF)."
    if ! GIT_TERMINAL_PROMPT=0 git clone \
        --depth 1 \
        --filter=blob:none \
        --sparse \
        --branch "$WALLPAPER_REF" \
        --single-branch \
        "$WALLPAPER_REPO_URL" \
        "$checkout_dir"
    then
        warn "Wallpaper repository download failed; keeping any installed collection."
        return 0
    fi

    if ! git -C "$checkout_dir" sparse-checkout set "$WALLPAPER_REPO_PATH"; then
        warn "Could not select the wallpaper directory from the remote repository."
        return 0
    fi

    source_dir="$checkout_dir/$WALLPAPER_REPO_PATH"
    if [[ ! -d "$source_dir" ]]; then
        warn "Remote repository does not contain $WALLPAPER_REPO_PATH."
        return 0
    fi

    image_count="$(
        find "$source_dir" \
            -type f \
            \( \
                -iname '*.png' -o \
                -iname '*.jpg' -o \
                -iname '*.jpeg' -o \
                -iname '*.webp' \
            \) \
            -printf '.' |
            wc -c
    )"

    if [[ "$image_count" -eq 0 ]]; then
        warn "The remote wallpaper directory contains no supported images."
        return 0
    fi

    mkdir -p -- "$destination"
    rsync \
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
        "$source_dir/" \
        "$destination/"

    log "Installed $image_count remote wallpaper image(s) into $destination."
}

write_wallpaper_rotator() {
    local bin_dir="$TARGET_HOME/.local/bin"
    local config_dir="$TARGET_HOME/.config/ubuntuRicePack"
    local service_dir="$TARGET_HOME/.config/systemd/user"
    local rotator_file="$bin_dir/rice-wallpaper-rotator"
    local environment_file="$config_dir/wallpaper.env"
    local service_file="$service_dir/rice-wallpaper-rotator.service"
    local temporary=""

    [[ "$INSTALL_WALLPAPER_ROTATOR" == "1" ]] || {
        log "Wallpaper rotator disabled by INSTALL_WALLPAPER_ROTATOR=$INSTALL_WALLPAPER_ROTATOR."
        return 0
    }

    if ! [[ "$WALLPAPER_INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
        fail "RICE_WALLPAPER_INTERVAL must be a positive integer."
    fi

    mkdir -p -- "$bin_dir" "$config_dir" "$service_dir"

    temporary="$(make_temp_file)"
    register_temp_path "$temporary"
    cat >"$temporary" <<'EOF_ROTATOR'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

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

apply_image() {
    local image="$1"
    local uri=""

    uri="$(
        python3 -c \
            'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' \
            "$image"
    )"

    gsettings set org.gnome.desktop.background picture-options scaled
    gsettings set org.gnome.desktop.background primary-color '#000000'
    gsettings set org.gnome.desktop.background secondary-color '#000000'
    gsettings set org.gnome.desktop.background color-shading-type solid
    gsettings set org.gnome.desktop.background picture-uri "$uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$uri"

    gsettings set org.gnome.desktop.screensaver picture-options scaled
    gsettings set org.gnome.desktop.screensaver primary-color '#000000'
    gsettings set org.gnome.desktop.screensaver secondary-color '#000000'
    gsettings set org.gnome.desktop.screensaver color-shading-type solid
    gsettings set org.gnome.desktop.screensaver picture-uri "$uri"
}

while true; do
    mapfile -d '' -t images < <(
        find "$WALLPAPER_DIR" \
            -type f \
            \( \
                -iname '*.png' -o \
                -iname '*.jpg' -o \
                -iname '*.jpeg' -o \
                -iname '*.webp' \
            \) \
            -print0 2>/dev/null |
            sort -z
    )

    if [[ "${#images[@]}" -eq 0 ]]; then
        sleep "$INTERVAL"
        continue
    fi

    for image in "${images[@]}"; do
        apply_image "$image" || true
        sleep "$INTERVAL"
    done
done
EOF_ROTATOR
    install -m 0755 "$temporary" "$rotator_file"

    temporary="$(make_temp_file)"
    register_temp_path "$temporary"
    printf \
        '# Seconds between wallpaper changes.\nRICE_WALLPAPER_INTERVAL=%s\n' \
        "$WALLPAPER_INTERVAL" >"$temporary"
    install -m 0644 "$temporary" "$environment_file"

    temporary="$(make_temp_file)"
    register_temp_path "$temporary"
    cat >"$temporary" <<'EOF_SERVICE'
[Unit]
Description=ubuntuRicePack wallpaper rotator
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF_SERVICE
    install -m 0644 "$temporary" "$service_file"

    # An older revision used an autostart desktop file as well as systemd.
    # Keep only one startup mechanism.
    rm -f -- \
        "$TARGET_HOME/.config/autostart/rice-wallpaper-rotator.desktop"

    if have_user_session && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload
        systemctl --user enable rice-wallpaper-rotator.service
        systemctl --user restart rice-wallpaper-rotator.service ||
            warn "The wallpaper rotator will be retried at the next login."
    else
        mkdir -p -- "$service_dir/default.target.wants"
        ln -sfn \
            ../rice-wallpaper-rotator.service \
            "$service_dir/default.target.wants/rice-wallpaper-rotator.service"
        log "Wallpaper rotator installed and will start at the next user login."
    fi
}

apply_first_wallpaper() {
    local wallpaper_dir="$TARGET_HOME/.local/share/backgrounds/rice/wallpapers"
    local first_wallpaper=""
    local candidate=""
    local uri=""

    have_user_session || {
        log "No live GNOME session; the wallpaper will be applied at login by the rotator."
        return 0
    }
    [[ -d "$wallpaper_dir" ]] || return 0

    while IFS= read -r -d '' candidate; do
        first_wallpaper="$candidate"
        break
    done < <(
        find "$wallpaper_dir" \
            -type f \
            \( \
                -iname '*.png' -o \
                -iname '*.jpg' -o \
                -iname '*.jpeg' -o \
                -iname '*.webp' \
            \) \
            -print0 |
            sort -z
    )

    [[ -n "$first_wallpaper" ]] || return 0
    uri="$(
        python3 -c \
            'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' \
            "$first_wallpaper"
    )"

    gs_set org.gnome.desktop.background picture-options "'scaled'"
    gs_set org.gnome.desktop.background primary-color "'#000000'"
    gs_set org.gnome.desktop.background secondary-color "'#000000'"
    gs_set org.gnome.desktop.background color-shading-type "'solid'"
    gs_set org.gnome.desktop.background picture-uri "'$uri'"
    gs_set org.gnome.desktop.background picture-uri-dark "'$uri'"

    gs_set org.gnome.desktop.screensaver picture-options "'scaled'"
    gs_set org.gnome.desktop.screensaver primary-color "'#000000'"
    gs_set org.gnome.desktop.screensaver secondary-color "'#000000'"
    gs_set org.gnome.desktop.screensaver color-shading-type "'solid'"
    gs_set org.gnome.desktop.screensaver picture-uri "'$uri'"
}

refresh_icon_caches() {
    local icon_dir=""

    command -v gtk-update-icon-cache >/dev/null 2>&1 || return 0
    [[ -d "$TARGET_HOME/.local/share/icons" ]] || return 0

    while IFS= read -r -d '' icon_dir; do
        if [[ -f "$icon_dir/index.theme" ]]; then
            gtk-update-icon-cache -f -t "$icon_dir" >/dev/null 2>&1 ||
                warn "Could not refresh icon cache: $icon_dir"
        fi
    done < <(
        find "$TARGET_HOME/.local/share/icons" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -print0
    )
}

apply_basic_appearance() {
    gs_set org.gnome.desktop.interface gtk-theme "'MacTahoe-Dark-blue'"
    gs_set org.gnome.desktop.interface color-scheme "'prefer-dark'"
    gs_set org.gnome.desktop.interface icon-theme "'Papirus-Dark'"
    gs_set \
        org.gnome.desktop.wm.preferences \
        button-layout \
        "':minimize,maximize,close'"

    if schema_exists org.gnome.shell.extensions.user-theme; then
        gs_set \
            org.gnome.shell.extensions.user-theme \
            name \
            "'MacTahoe-Dark-blue'"
    fi
}

main() {
    require_regular_user
    require_ubuntu
    assert_repo_path "configs"

    log "Restoring themes, GTK configuration, local tools, and runtime wallpapers."
    restore_user_files
    fetch_and_install_wallpapers
    write_wallpaper_rotator
    apply_first_wallpaper
    refresh_icon_caches
    apply_basic_appearance

    log "Theme, configuration, and wallpaper stage complete."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi