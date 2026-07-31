#!/usr/bin/env bash
# Install the curated Bash environment, Fastfetch helpers, and Nerd Fonts.
#
# pyenv itself comes from the package stage and the requested Python runtime is
# installed once by install-rice.sh through the shared helper in 00-common.sh.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

INSTALL_NERD_FONTS="${INSTALL_NERD_FONTS:-1}"
RICE_NERD_FONTS="${RICE_NERD_FONTS:-JetBrainsMono Noto NerdFontsSymbolsOnly}"
STRICT_NERD_FONTS="${STRICT_NERD_FONTS:-0}"
REPORT_FILE=""
NERD_FONT_FAILURES=0

install_shell_configuration() {
    local source_bashrc="$REPO_ROOT/configs/.bashrc"

    [[ -f "$source_bashrc" ]] ||
        fail "Curated Bash configuration is missing: $source_bashrc"
    bash -n "$source_bashrc" ||
        fail "Repository Bash configuration failed syntax validation."

    backup_path "$TARGET_HOME/.bashrc"
    backup_path "$TARGET_HOME/.bash_profile"
    backup_path "$TARGET_HOME/.bash_logout"

    # Install complete files. Never append: appending made every rerun duplicate
    # aliases, PATH changes, pyenv initialization, and Fastfetch startup.
    copy_file "$source_bashrc" "$TARGET_HOME/.bashrc" 0644
    copy_file \
        "$REPO_ROOT/configs/.bash_profile" \
        "$TARGET_HOME/.bash_profile" \
        0644
    copy_file \
        "$REPO_ROOT/configs/.bash_logout" \
        "$TARGET_HOME/.bash_logout" \
        0644

    bash -n "$TARGET_HOME/.bashrc"
    if [[ -f "$TARGET_HOME/.bash_profile" ]]; then
        bash -n "$TARGET_HOME/.bash_profile"
    fi
    if [[ -f "$TARGET_HOME/.bash_logout" ]]; then
        bash -n "$TARGET_HOME/.bash_logout"
    fi

    log "Installed and validated the curated Bash startup files."
}

install_fastfetch_and_helpers() {
    local local_bin="$TARGET_HOME/.local/bin"
    local fastfetch_config="$TARGET_HOME/.config/fastfetch"
    local ff_blue_source="$REPO_ROOT/configs/local-bin/ff-blue"
    local temporary=""
    local target_command=""

    backup_path "$fastfetch_config"
    mkdir -p -- "$fastfetch_config" "$local_bin"
    copy_dir_contents \
        "$REPO_ROOT/configs/fastfetch" \
        "$fastfetch_config"

    if [[ -f "$ff_blue_source" ]]; then
        copy_file "$ff_blue_source" "$local_bin/ff-blue" 0755
    else
        temporary="$(make_temp_file)"
        register_temp_path "$temporary"
        cat >"$temporary" <<'EOF_FF_BLUE'
#!/usr/bin/env bash
set -Eeuo pipefail
exec fastfetch "$@"
EOF_FF_BLUE
        install -m 0755 "$temporary" "$local_bin/ff-blue"
        warn "configs/local-bin/ff-blue was absent; installed a minimal Fastfetch wrapper."
    fi

    # Ubuntu retains historical binary names for these two Debian packages.
    # Stable per-user links let the existing Arch-style aliases keep working.
    if target_command="$(command -v batcat 2>/dev/null)"; then
        ln -sfn -- "$target_command" "$local_bin/bat"
    elif target_command="$(command -v bat 2>/dev/null)"; then
        ln -sfn -- "$target_command" "$local_bin/bat"
    else
        warn "Neither batcat nor bat is installed."
    fi

    if target_command="$(command -v fdfind 2>/dev/null)"; then
        ln -sfn -- "$target_command" "$local_bin/fd"
    elif target_command="$(command -v fd 2>/dev/null)"; then
        ln -sfn -- "$target_command" "$local_bin/fd"
    else
        warn "Neither fdfind nor fd is installed."
    fi

    if command -v fastfetch >/dev/null 2>&1; then
        fastfetch --version | head -n 1 | tee -a "$LOG_FILE"
    else
        warn "Fastfetch is unavailable after the package stage."
    fi
}

record_nerd_font_problem() {
    warn "$1"
    NERD_FONT_FAILURES=$((NERD_FONT_FAILURES + 1))
}

install_nerd_fonts() {
    local checksums_file=""
    local checksums_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SHA-256.txt"
    local releases_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    local font_name=""
    local asset_name=""
    local asset_url=""
    local archive=""
    local archive_listing=""
    local cache_dir="$TARGET_HOME/.cache/ubuntuRicePack/nerd-fonts"
    local expected_sha=""
    local destination=""
    local marker=""
    local installed_sha=""
    local extract_dir=""
    local font_file=""
    local cached_sha=""
    local -a font_families=()

    [[ "$INSTALL_NERD_FONTS" == "1" ]] || {
        log "Nerd Font installation disabled by INSTALL_NERD_FONTS=$INSTALL_NERD_FONTS."
        return 0
    }

    checksums_file="$(make_temp_file)"
    register_temp_path "$checksums_file"

    # Use GitHub's release-download endpoint directly. Unlike the REST API,
    # this is the upstream-supported scripted download path and is not subject
    # to the low anonymous API quota that broke earlier installer runs.
    log "Downloading the official Nerd Fonts SHA-256 manifest."
    if ! (
        download_file "$checksums_url" "$checksums_file"
    ); then
        record_nerd_font_problem \
            "Could not download the official Nerd Fonts SHA-256 manifest."
        if [[ "$STRICT_NERD_FONTS" == "1" ]]; then
            fail "Nerd Fonts checksum download failed."
        fi
        return 0
    fi

    mkdir -p -- "$cache_dir"
    IFS=' ' read -r -a font_families <<<"$RICE_NERD_FONTS"
    for font_name in "${font_families[@]}"; do
        [[ -n "$font_name" ]] || continue
        if [[ ! "$font_name" =~ ^[A-Za-z0-9._+-]+$ ]]; then
            warn "Unsafe Nerd Font asset name; skipped: $font_name"
            continue
        fi

        asset_name="$font_name.tar.xz"
        asset_url="$releases_url/$asset_name"
        expected_sha="$(
            awk -v name="$asset_name" '
                $2 == name {print $1; exit}
                $1 == "SHA256" && $2 == "(" name ")" && $3 == "=" {
                    print $4
                    exit
                }
            ' "$checksums_file"
        )"

        if [[ ! "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
            record_nerd_font_problem \
                "The checksum manifest has no valid digest for $asset_name."
            continue
        fi

        destination="$TARGET_HOME/.local/share/fonts/NerdFonts/$font_name"
        marker="$destination/.ubuntu-rice-sha256"
        installed_sha=""
        [[ -f "$marker" ]] && installed_sha="$(<"$marker")"
        font_file="$(
            find "$destination" -maxdepth 1 -type f \
                \( -iname '*.ttf' -o -iname '*.otf' \) \
                -print -quit 2>/dev/null
        )"
        if [[ "$installed_sha" == "$expected_sha" ]] &&
            [[ -n "$font_file" ]]
        then
            log "Nerd Font is current: $font_name (${expected_sha:0:12})."
            continue
        fi

        archive="$cache_dir/${expected_sha}-${asset_name}"
        archive_listing="$(make_temp_file)"
        register_temp_path "$archive_listing"

        cached_sha=""
        [[ -s "$archive" ]] &&
            cached_sha="$(sha256sum "$archive" | awk '{print $1}')"
        if [[ "$cached_sha" == "$expected_sha" ]]; then
            log "Using cached Nerd Font archive: $asset_name"
        else
            rm -f -- "$archive"
            log "Downloading verified Nerd Font: $font_name."
            if ! (download_file "$asset_url" "$archive"); then
                record_nerd_font_problem \
                    "Could not download Nerd Font archive: $asset_name"
                rm -f -- "$archive"
                continue
            fi
        fi

        if ! (verify_sha256 "$archive" "$expected_sha"); then
            record_nerd_font_problem \
                "Checksum verification failed for Nerd Font: $asset_name"
            rm -f -- "$archive"
            continue
        fi

        if ! tar -tJf "$archive" >"$archive_listing"; then
            record_nerd_font_problem \
                "Could not inspect Nerd Font archive: $asset_name"
            continue
        fi
        if grep -Eq '(^/|(^|/)\.\.(/|$))' "$archive_listing"; then
            record_nerd_font_problem \
                "$asset_name contains an unsafe path; refusing to extract it."
            continue
        fi

        extract_dir="$(make_temp_dir)"
        register_temp_path "$extract_dir"
        if ! tar -xJf "$archive" -C "$extract_dir"; then
            record_nerd_font_problem \
                "Could not extract Nerd Font archive: $asset_name"
            continue
        fi

        backup_path "$destination"
        rm -rf -- "$destination"
        mkdir -p -- "$(dirname -- "$destination")"
        mv -- "$extract_dir" "$destination"
        printf '%s\n' "$expected_sha" >"$marker"
        log "Installed verified Nerd Font: $font_name (${expected_sha:0:12})."
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$TARGET_HOME/.local/share/fonts"
    else
        warn "fc-cache is unavailable; the new fonts will be discovered later."
    fi

    if ((NERD_FONT_FAILURES > 0)); then
        if [[ "$STRICT_NERD_FONTS" == "1" ]]; then
            fail "Nerd Fonts installation had $NERD_FONT_FAILURES failure(s)."
        fi
        warn "Nerd Fonts installation had $NERD_FONT_FAILURES failure(s)."
    fi
}

verify_terminal_environment() {
    local expected_command=""
    local status=""
    local actual=""
    local report_dir="$STATE_DIR/reports"

    mkdir -p -- "$report_dir"
    REPORT_FILE="$report_dir/terminal-$RUN_ID.tsv"
    printf 'category\tsubject\tstatus\tdetail\n' >"$REPORT_FILE"

    for expected_command in fastfetch eza zoxide starship pyenv; do
        if command -v "$expected_command" >/dev/null 2>&1; then
            log "Terminal command available: $expected_command"
            status="PASS"
            actual="$(command -v "$expected_command")"
        else
            warn "Terminal command unavailable: $expected_command"
            status="WARN"
            actual="not found"
        fi
        printf 'command\t%s\t%s\t%s\n' \
            "$expected_command" "$status" "$actual" >>"$REPORT_FILE"
    done

    if command -v fc-match >/dev/null 2>&1; then
        actual="$(fc-match -f '%{family}\n' 'Noto Sans Mono' 2>/dev/null)"
        log "Noto monospace match: $actual"
        printf 'font\tNoto Sans Mono\tPASS\t%s\n' \
            "$actual" >>"$REPORT_FILE"
    else
        printf 'font\tNoto Sans Mono\tWARN\tfc-match unavailable\n' \
            >>"$REPORT_FILE"
    fi

    for actual in \
        "JetBrainsMono Nerd Font" \
        "NotoSansM Nerd Font" \
        "Symbols Nerd Font"
    do
        if font_family_available "$actual"; then
            printf 'font\t%s\tPASS\tinstalled\n' \
                "$actual" >>"$REPORT_FILE"
        else
            printf 'font\t%s\tWARN\tnot matched by fontconfig\n' \
                "$actual" >>"$REPORT_FILE"
            warn "Fontconfig did not match expected Nerd Font family: $actual"
        fi
    done

    log "Terminal verification report: $REPORT_FILE"
    log "Open a new terminal or run: exec bash"
}

main() {
    require_regular_user
    require_ubuntu
    assert_repo_path "configs"

    log "Installing the curated terminal environment."
    install_shell_configuration
    install_fastfetch_and_helpers
    install_nerd_fonts
    verify_terminal_environment
    log "Terminal setup stage complete."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
