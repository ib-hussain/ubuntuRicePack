#!/usr/bin/env bash
# Install the account picture, GRUB artwork, and runtime-fetched wallpapers.
# This script intentionally does not configure a GDM logo or GDM background.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_gnome_session
require_ubuntu

if is_wsl; then
    log "Skipping desktop artwork in WSL."
    exit 0
fi

WALLPAPER_REPO_URL="${RICE_WALLPAPER_REPO_URL:-https://github.com/ib-hussain/archRicePack.git}"
WALLPAPER_REF="${RICE_WALLPAPER_REF:-main}"
WALLPAPER_REPO_PATH="${RICE_WALLPAPER_REPO_PATH:-assets/wallpapers}"
WALLPAPER_INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"
REFRESH_WALLPAPERS="${RICE_REFRESH_WALLPAPERS:-0}"
WALLPAPER_DEST="$HOME/.local/share/backgrounds/rice/wallpapers"
WALLPAPER_MANIFEST="$HOME/.local/share/backgrounds/rice/source.tsv"
FETCH_ROOT=""

[[ "$WALLPAPER_INTERVAL" =~ ^[1-9][0-9]*$ ]] ||
    fail "RICE_WALLPAPER_INTERVAL must be a positive integer."
[[ "$REFRESH_WALLPAPERS" == "0" || "$REFRESH_WALLPAPERS" == "1" ]] ||
    fail "RICE_REFRESH_WALLPAPERS must be either 0 or 1."
[[ "$WALLPAPER_REPO_PATH" != /* &&
    "$WALLPAPER_REPO_PATH" != *".."* &&
    "$WALLPAPER_REPO_PATH" != -* ]] ||
    fail "RICE_WALLPAPER_REPO_PATH must be a safe relative repository path."

cleanup_fetch() {
    if [[ -n "$FETCH_ROOT" &&
        -d "$FETCH_ROOT" &&
        "$FETCH_ROOT" == "${TMPDIR:-/tmp}"/ubuntuRicePack-wallpapers.* ]]; then
        rm -rf -- "$FETCH_ROOT"
    fi
}
trap cleanup_fetch EXIT

wallpaper_images_exist() {
    local image=""

    [[ -d "$WALLPAPER_DEST" ]] || return 1
    image="$(
        find "$WALLPAPER_DEST" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) \
            -print -quit 2>/dev/null
    )"
    [[ -n "$image" ]]
}

wallpaper_source_matches() {
    local expected=""

    [[ -f "$WALLPAPER_MANIFEST" ]] || return 1
    expected="$(
        printf '%s\t%s\t%s\n' \
            "$WALLPAPER_REPO_URL" \
            "$WALLPAPER_REF" \
            "$WALLPAPER_REPO_PATH"
    )"
    [[ "$(<"$WALLPAPER_MANIFEST")" == "$expected" ]]
}

write_wallpaper_manifest() {
    mkdir -p "$(dirname "$WALLPAPER_MANIFEST")"
    printf '%s\t%s\t%s\n' \
        "$WALLPAPER_REPO_URL" \
        "$WALLPAPER_REF" \
        "$WALLPAPER_REPO_PATH" \
        >"$WALLPAPER_MANIFEST"
}

install_account_picture() {
    local source_image=""
    local accounts_icon="/var/lib/AccountsService/icons/$USER"
    local accounts_record="/var/lib/AccountsService/users/$USER"

    for candidate in \
        "$REPO_ROOT/configs/.face" \
        "$REPO_ROOT/assets/ib.png"
    do
        if [[ -f "$candidate" ]]; then
            source_image="$candidate"
            break
        fi
    done

    if [[ -z "$source_image" ]]; then
        warn "No account-picture asset was found."
        return 0
    fi

    install -Dm644 "$source_image" "$HOME/.face"
    run_root install -Dm644 "$source_image" "$accounts_icon"
    run_root mkdir -p "$(dirname "$accounts_record")"

    run_root python3 - "$accounts_record" "$accounts_icon" <<'PY'
from pathlib import Path
import configparser
import sys

record_path = Path(sys.argv[1])
icon_path = sys.argv[2]
config = configparser.ConfigParser()
config.optionxform = str
if record_path.exists():
    config.read(record_path)
if not config.has_section("User"):
    config.add_section("User")
config.set("User", "Icon", icon_path)
with record_path.open("w", encoding="utf-8") as handle:
    config.write(handle, space_around_delimiters=False)
PY

    run_root chmod 0644 "$accounts_icon" "$accounts_record"
    log "Installed the account picture. No GDM branding was installed."
}

install_grub_artwork() {
    local source_image="$REPO_ROOT/assets/bg.png"
    local grub_dropin="/etc/default/grub.d/99-ubuntu-rice-pack.cfg"

    if [[ ! -f "$source_image" ]]; then
        warn "assets/bg.png is absent; skipping GRUB artwork."
        return 0
    fi

    if [[ ! -f /etc/default/grub ]]; then
        warn "This installation does not use Ubuntu's GRUB configuration."
        return 0
    fi

    run_root install -Dm644 "$source_image" /boot/grub/bg.png
    run_root mkdir -p /etc/default/grub.d
    run_root tee "$grub_dropin" >/dev/null <<'GRUB_CONFIG'
# Managed by ubuntuRicePack.
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=3
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_INIT_TUNE="480 440 1"
GRUB_BACKGROUND="/boot/grub/bg.png"
GRUB_CONFIG

    if command -v update-grub >/dev/null 2>&1; then
        run_root update-grub
    else
        warn "update-grub is unavailable; GRUB was not regenerated."
    fi
}

fetch_wallpapers() {
    local checkout_dir=""

    if [[ "$REFRESH_WALLPAPERS" == "0" ]] && wallpaper_images_exist; then
        if [[ ! -f "$WALLPAPER_MANIFEST" ]]; then
            # Older UbuntuRicePack revisions downloaded this exact collection
            # but did not record its source. Adopt it without a one-time
            # 395-MiB redownload.
            write_wallpaper_manifest
            log "Adopted the existing wallpaper collection; download skipped."
            log "Set RICE_REFRESH_WALLPAPERS=1 to replace it from the remote source."
            return 0
        fi

        if wallpaper_source_matches; then
            log "Installed wallpapers already match the configured source; download skipped."
            log "Set RICE_REFRESH_WALLPAPERS=1 to force a fresh wallpaper download."
            return 0
        fi
    fi

    FETCH_ROOT="$(
        mktemp -d "${TMPDIR:-/tmp}/ubuntuRicePack-wallpapers.XXXXXX"
    )"
    checkout_dir="$FETCH_ROOT/source"

    log "Fetching only $WALLPAPER_REPO_PATH from the Arch rice repository."
    GIT_TERMINAL_PROMPT=0 git clone \
        --depth 1 \
        --filter=blob:none \
        --sparse \
        --branch "$WALLPAPER_REF" \
        --single-branch \
        "$WALLPAPER_REPO_URL" \
        "$checkout_dir"
    git -C "$checkout_dir" sparse-checkout set "$WALLPAPER_REPO_PATH"

    [[ -d "$checkout_dir/$WALLPAPER_REPO_PATH" ]] ||
        fail "The remote wallpaper path is absent: $WALLPAPER_REPO_PATH"

    mkdir -p "$WALLPAPER_DEST"
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
        "$checkout_dir/$WALLPAPER_REPO_PATH/" \
        "$WALLPAPER_DEST/"

    if ! wallpaper_images_exist; then
        fail "The downloaded wallpaper directory contains no supported images."
    fi

    write_wallpaper_manifest
}

write_wallpaper_rotator() {
    local config_dir="$HOME/.config/ubuntuRicePack"
    local service_dir="$HOME/.config/systemd/user"

    mkdir -p "$HOME/.local/bin" "$config_dir" "$service_dir"

    tee "$config_dir/wallpaper.env" >/dev/null <<CONFIG
# Managed by ubuntuRicePack.
RICE_WALLPAPER_INTERVAL=$WALLPAPER_INTERVAL
CONFIG

    tee "$HOME/.local/bin/rice-wallpaper-rotator" >/dev/null <<'ROTATOR'
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
[[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]] || INTERVAL=5

apply_image() {
    local image="$1"
    local uri=""

    uri="$(
        python3 -c \
            'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
            "$image"
    )"

    gsettings set org.gnome.desktop.background picture-options 'scaled'
    gsettings set org.gnome.desktop.background primary-color '#000000'
    gsettings set org.gnome.desktop.background secondary-color '#000000'
    gsettings set org.gnome.desktop.background color-shading-type 'solid'
    gsettings set org.gnome.desktop.background picture-uri "$uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
    gsettings set org.gnome.desktop.screensaver picture-options 'scaled'
    gsettings set org.gnome.desktop.screensaver picture-uri "$uri"
}

while true; do
    mapfile -d '' -t images < <(
        find "$WALLPAPER_DIR" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
            -o -iname '*.webp' \) \
            -print0 2>/dev/null |
            sort -z
    )

    if ((${#images[@]} == 0)); then
        sleep "$INTERVAL"
        continue
    fi

    for image in "${images[@]}"; do
        apply_image "$image" || true
        sleep "$INTERVAL"
    done
done
ROTATOR
    chmod 0755 "$HOME/.local/bin/rice-wallpaper-rotator"

    tee "$service_dir/rice-wallpaper-rotator.service" >/dev/null <<'SERVICE'
[Unit]
Description=UbuntuRicePack wallpaper rotator
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
SERVICE

    rm -f "$HOME/.config/autostart/rice-wallpaper-rotator.desktop"
    systemctl --user daemon-reload
    systemctl --user enable --now rice-wallpaper-rotator.service
}

apply_first_wallpaper() {
    local first_image=""
    local uri=""

    while IFS= read -r -d '' first_image; do
        break
    done < <(
        find "$WALLPAPER_DEST" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) \
            -print0 |
            sort -z
    )
    [[ -n "$first_image" ]] || return 0

    uri="$(
        python3 -c \
            'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
            "$first_image"
    )"
    gs_set org.gnome.desktop.background picture-options "'scaled'"
    gs_set org.gnome.desktop.background primary-color "'#000000'"
    gs_set org.gnome.desktop.background secondary-color "'#000000'"
    gs_set org.gnome.desktop.background picture-uri "'$uri'"
    gs_set org.gnome.desktop.background picture-uri-dark "'$uri'"
    gs_set org.gnome.desktop.screensaver picture-uri "'$uri'"
}

write_asset_report() {
    local report_dir="$STATE_DIR/reports"
    local report_file="$report_dir/assets-wallpapers-$RUN_ID.tsv"
    local wallpaper_count=0
    local service_state="not-enabled"
    local account_state="missing"
    local grub_state="not-configured"

    mkdir -p -- "$report_dir"
    wallpaper_count="$(
        find "$WALLPAPER_DEST" -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) 2>/dev/null |
            wc -l
    )"
    [[ -f "$HOME/.face" ]] && account_state="installed"
    if run_root test -f /boot/grub/bg.png &&
        run_root test -f /etc/default/grub.d/99-ubuntu-rice-pack.cfg
    then
        grub_state="configured"
    fi
    if systemctl --user is-enabled rice-wallpaper-rotator.service \
        >/dev/null 2>&1
    then
        service_state="enabled"
    fi

    {
        printf 'asset\tsource\tdestination\tstatus\n'
        printf 'account-picture\t%s\t%s\t%s\n' \
            "$REPO_ROOT/configs/.face or assets/ib.png" \
            "$HOME/.face" \
            "$account_state"
        printf 'grub-artwork\t%s\t%s\t%s\n' \
            "$REPO_ROOT/assets/bg.png" \
            "/boot/grub/bg.png" \
            "$grub_state"
        printf 'wallpapers\t%s@%s:%s\t%s\t%s files\n' \
            "$WALLPAPER_REPO_URL" \
            "$WALLPAPER_REF" \
            "$WALLPAPER_REPO_PATH" \
            "$WALLPAPER_DEST" \
            "$wallpaper_count"
        printf 'wallpaper-service\tgenerated\t%s\t%s\n' \
            "$HOME/.config/systemd/user/rice-wallpaper-rotator.service" \
            "$service_state"
        printf 'gdm-branding\tintentionally absent\tGDM\tabsent\n'
    } >"$report_file"

    log "Assets and wallpaper verification report: $report_file"
}

install_account_picture
install_grub_artwork
fetch_wallpapers
write_wallpaper_rotator
apply_first_wallpaper
write_asset_report

log "Account picture, GRUB artwork, and wallpapers are configured."
