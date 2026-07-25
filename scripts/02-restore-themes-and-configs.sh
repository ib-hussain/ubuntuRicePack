#!/usr/bin/env bash
# Restore repository-owned user configuration and appearance assets.
#
# This stage copies files only. GNOME/dconf settings are applied by stage 05,
# terminal startup files by stage 03, wallpapers by stage 06, and VS Code data
# by stage 07. Keeping those responsibilities separate makes reruns predictable.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

INSTALL_MODE="${RICE_INSTALL_MODE:-auto}"
RESTORE_CLUSTER_WORK="${RESTORE_CLUSTER_WORK:-1}"
REPORT_FILE=""

usage() {
    cat <<'USAGE'
Usage: 02-restore-themes-and-configs.sh [--mode auto|desktop|wsl]

Environment:
  RESTORE_CLUSTER_WORK=0   Do not copy cluster-work into ~/Downloads.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            INSTALL_MODE="${2:?Missing value for --mode}"
            shift 2
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

case "$INSTALL_MODE" in
    auto)
        if is_wsl; then
            INSTALL_MODE="wsl"
        else
            INSTALL_MODE="desktop"
        fi
        ;;
    normal | dual-boot)
        INSTALL_MODE="desktop"
        ;;
    desktop | wsl) ;;
    *)
        fail "Unsupported restore mode: $INSTALL_MODE"
        ;;
esac

report_path() {
    local label="$1"
    local path="$2"
    local required="${3:-no}"
    local state="missing"

    if [[ -L "$path" ]]; then
        state="symlink"
    elif [[ -d "$path" ]]; then
        state="directory"
    elif [[ -f "$path" ]]; then
        state="file"
    fi

    printf '%s\t%s\t%s\t%s\n' \
        "$label" "$path" "$required" "$state" >>"$REPORT_FILE"

    if [[ "$required" == "yes" && "$state" == "missing" ]]; then
        fail "Required restored path is missing: $path"
    fi
}

restore_common_configuration() {
    local destination=""

    log "Restoring configuration shared by desktop Ubuntu and WSL."

    destination="$TARGET_HOME/.local/bin"
    backup_path "$destination"
    copy_dir_contents "$REPO_ROOT/configs/local-bin" "$destination"

    destination="$TARGET_HOME/.config/fastfetch"
    backup_path "$destination"
    copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$destination"

    if [[ -d "$TARGET_HOME/.local/bin" ]]; then
        find "$TARGET_HOME/.local/bin" \
            -maxdepth 1 \
            -type f \
            -exec chmod u+x {} +
    fi

    if [[ "$RESTORE_CLUSTER_WORK" == "1" &&
        -d "$REPO_ROOT/cluster-work" ]]
    then
        destination="$TARGET_HOME/Downloads/cluster-work"
        backup_path "$destination"
        copy_dir_contents "$REPO_ROOT/cluster-work" "$destination"
    else
        log "cluster-work restore was disabled or the source directory is absent."
    fi
}

install_theme_assets() {
    local source="$REPO_ROOT/configs/themes"
    local canonical="$TARGET_HOME/.local/share/themes"
    local legacy="$TARGET_HOME/.themes"

    [[ -d "$source" ]] ||
        fail "Repository theme directory is missing: $source"

    backup_path "$canonical"
    copy_dir_contents "$source" "$canonical"

    # ~/.local/share/themes is the canonical copy. A compatibility symlink
    # supports software that still looks only in ~/.themes without storing the
    # large MacTahoe theme twice.
    if [[ ! -e "$legacy" && ! -L "$legacy" ]]; then
        ln -s -- ".local/share/themes" "$legacy"
        log "Created compatibility theme link: $legacy -> .local/share/themes"
    elif [[ -L "$legacy" ]]; then
        log "Existing legacy theme symlink was preserved: $legacy"
    else
        warn "$legacy already exists as a real directory; it was preserved."
        warn "The curated theme was installed canonically under $canonical."
    fi
}

restore_desktop_configuration() {
    local source=""
    local destination=""
    local face_source=""

    log "Restoring Ubuntu GNOME desktop configuration files."

    install_theme_assets

    for config_name in gtk-3.0 gtk-4.0; do
        source="$REPO_ROOT/configs/$config_name"
        destination="$TARGET_HOME/.config/$config_name"
        backup_path "$destination"
        copy_dir_contents "$source" "$destination"
    done

    source="$REPO_ROOT/configs/autostart"
    destination="$TARGET_HOME/.config/autostart"
    backup_path "$destination"
    copy_dir_contents "$source" "$destination"

    # These entries belonged to the removed Arch/chroot first-login workflow.
    # Removing only these known managed files prevents a broken post-login job
    # while preserving every other repository and user autostart entry.
    rm -f -- \
        "$destination/arch-rice-postlogin.desktop" \
        "$TARGET_HOME/.local/bin/arch-rice-postlogin-runner"

    source="$REPO_ROOT/configs/nautilus-python"
    destination="$TARGET_HOME/.local/share/nautilus-python"
    backup_path "$destination"
    copy_dir_contents "$source" "$destination"

    if [[ -f "$REPO_ROOT/configs/.face" ]]; then
        face_source="$REPO_ROOT/configs/.face"
    elif [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
        face_source="$REPO_ROOT/assets/ib.png"
    fi

    if [[ -n "$face_source" ]]; then
        backup_path "$TARGET_HOME/.face"
        copy_file "$face_source" "$TARGET_HOME/.face" 0644

        if [[ -e "$TARGET_HOME/.face.icon" ||
            -L "$TARGET_HOME/.face.icon" ]]
        then
            backup_path "$TARGET_HOME/.face.icon"
            rm -f -- "$TARGET_HOME/.face.icon"
        fi
        ln -s -- ".face" "$TARGET_HOME/.face.icon"
    else
        warn "No account face image exists in configs/.face or assets/ib.png."
    fi

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        while IFS= read -r -d '' destination; do
            gtk-update-icon-cache -q -f "$destination" >/dev/null 2>&1 || true
        done < <(
            find "$TARGET_HOME/.local/share/icons" \
                -mindepth 1 \
                -maxdepth 1 \
                -type d \
                -print0 2>/dev/null
        )
    fi
}

write_restore_report() {
    local report_dir="$STATE_DIR/reports"

    mkdir -p -- "$report_dir"
    REPORT_FILE="$report_dir/restored-config-$RUN_ID.tsv"
    printf 'asset\tpath\trequired\tstate\n' >"$REPORT_FILE"

    report_path local-bin "$TARGET_HOME/.local/bin" yes
    report_path fastfetch "$TARGET_HOME/.config/fastfetch" yes

    if [[ "$INSTALL_MODE" == "desktop" ]]; then
        report_path themes "$TARGET_HOME/.local/share/themes" yes
        report_path gtk3 "$TARGET_HOME/.config/gtk-3.0" yes
        report_path gtk4 "$TARGET_HOME/.config/gtk-4.0" yes
        report_path autostart "$TARGET_HOME/.config/autostart" no
        report_path nautilus-python \
            "$TARGET_HOME/.local/share/nautilus-python" no
        report_path account-face "$TARGET_HOME/.face" no
    fi

    log "Configuration restore report: $REPORT_FILE"
}

main() {
    require_regular_user
    require_ubuntu
    assert_repo_path "configs"

    restore_common_configuration
    if [[ "$INSTALL_MODE" == "desktop" ]]; then
        restore_desktop_configuration
    fi
    write_restore_report

    log "Configuration restore stage complete ($INSTALL_MODE mode)."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
