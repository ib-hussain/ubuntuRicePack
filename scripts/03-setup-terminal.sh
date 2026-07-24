#!/usr/bin/env bash
# Install the curated Bash environment, Fastfetch, fonts, and pyenv Python.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

INSTALL_NERD_FONTS="${INSTALL_NERD_FONTS:-1}"
RICE_NERD_FONTS="${RICE_NERD_FONTS:-JetBrainsMono Noto}"
INSTALL_PYENV_PYTHON="${INSTALL_PYENV_PYTHON:-1}"
PYTHON_VERSION="${RICE_PYTHON_VERSION:-3.12.7}"
PYTHON_BUILD_JOBS="${PYTHON_BUILD_JOBS:-}"

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

release_asset_url() {
    local release_json="$1"
    local asset_name="$2"

    python3 - "$release_json" "$asset_name" <<'PY_ASSET_URL'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    release = json.load(stream)

for asset in release.get("assets", []):
    if asset.get("name") == sys.argv[2]:
        print(asset.get("browser_download_url", ""))
        break
PY_ASSET_URL
}

install_nerd_fonts() {
    local release_json=""
    local checksums_file=""
    local checksums_url=""
    local tag=""
    local font_name=""
    local asset_name=""
    local asset_url=""
    local archive=""
    local archive_listing=""
    local expected_sha=""
    local destination=""
    local -a font_families=()

    [[ "$INSTALL_NERD_FONTS" == "1" ]] || {
        log "Nerd Font installation disabled by INSTALL_NERD_FONTS=$INSTALL_NERD_FONTS."
        return 0
    }

    release_json="$(make_temp_file)"
    checksums_file="$(make_temp_file)"
    register_temp_path "$release_json"
    register_temp_path "$checksums_file"

    log "Resolving the latest official Nerd Fonts release."
    download_file \
        https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
        "$release_json"

    tag="$(
        python3 - "$release_json" <<'PY_RELEASE_TAG'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    print(json.load(stream).get("tag_name", ""))
PY_RELEASE_TAG
    )"
    [[ -n "$tag" ]] || {
        warn "Could not determine the latest Nerd Fonts release tag."
        return 1
    }

    checksums_url="$(release_asset_url "$release_json" SHA-256.txt)"
    [[ -n "$checksums_url" ]] || {
        warn "The Nerd Fonts release does not contain SHA-256.txt."
        return 1
    }
    download_file "$checksums_url" "$checksums_file"

    IFS=' ' read -r -a font_families <<<"$RICE_NERD_FONTS"
    for font_name in "${font_families[@]}"; do
        [[ -n "$font_name" ]] || continue
        if [[ ! "$font_name" =~ ^[A-Za-z0-9._+-]+$ ]]; then
            warn "Unsafe Nerd Font asset name; skipped: $font_name"
            continue
        fi

        asset_name="$font_name.tar.xz"
        asset_url="$(release_asset_url "$release_json" "$asset_name")"
        expected_sha="$(
            awk -v name="$asset_name" '$2 == name {print $1; exit}' "$checksums_file"
        )"

        if [[ -z "$asset_url" || -z "$expected_sha" ]]; then
            warn "Release $tag does not provide a verified $asset_name asset."
            continue
        fi

        destination="$TARGET_HOME/.local/share/fonts/NerdFonts/$tag/$font_name"
        if [[ -d "$destination" ]]; then
            log "Nerd Font already installed: $font_name ($tag)"
            continue
        fi

        archive="$(make_temp_file)"
        archive_listing="$(make_temp_file)"
        register_temp_path "$archive"
        register_temp_path "$archive_listing"
        log "Downloading verified Nerd Font: $font_name ($tag)."
        download_file "$asset_url" "$archive"
        verify_sha256 "$archive" "$expected_sha"

        tar -tJf "$archive" >"$archive_listing"
        if grep -Eq '(^/|(^|/)\.\.(/|$))' "$archive_listing"; then
            warn "$asset_name contains an unsafe path; refusing to extract it."
            continue
        fi

        mkdir -p -- "$destination"
        tar -xJf "$archive" -C "$destination"
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$TARGET_HOME/.local/share/fonts"
    else
        warn "fc-cache is unavailable; the new fonts will be discovered later."
    fi
}

configure_pyenv_python() {
    local jobs=""
    local python_version_output=""

    [[ "$INSTALL_PYENV_PYTHON" == "1" ]] || {
        log "pyenv Python installation disabled by INSTALL_PYENV_PYTHON=$INSTALL_PYENV_PYTHON."
        return 0
    }

    if ! command -v pyenv >/dev/null 2>&1; then
        warn "pyenv is unavailable; Python $PYTHON_VERSION was not installed."
        return 0
    fi

    export PYENV_ROOT="$TARGET_HOME/.pyenv"
    mkdir -p -- "$PYENV_ROOT"

    if [[ -z "$PYTHON_BUILD_JOBS" ]]; then
        jobs="$(nproc 2>/dev/null || printf '2')"
        if ((jobs > 4)); then
            jobs=4
        elif ((jobs < 1)); then
            jobs=1
        fi
    else
        jobs="$PYTHON_BUILD_JOBS"
    fi

    if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
        fail "PYTHON_BUILD_JOBS must be a positive integer."
    fi

    if pyenv versions --bare |
        sed 's/^[[:space:]]*//' |
        grep -Fxq "$PYTHON_VERSION"
    then
        log "pyenv Python $PYTHON_VERSION is already installed."
    else
        log "Building Python $PYTHON_VERSION through pyenv with $jobs job(s)."
        MAKE_OPTS="-j$jobs" pyenv install "$PYTHON_VERSION"
    fi

    pyenv global "$PYTHON_VERSION"
    pyenv rehash
    python_version_output="$(pyenv exec python --version 2>&1)"
    if [[ "$python_version_output" != "Python $PYTHON_VERSION" ]]; then
        fail "pyenv verification failed: $python_version_output"
    fi

    log "Configured pyenv global Python: $python_version_output"
}

verify_terminal_environment() {
    local expected_command=""

    for expected_command in fastfetch eza zoxide starship pyenv; do
        if command -v "$expected_command" >/dev/null 2>&1; then
            log "Terminal command available: $expected_command"
        else
            warn "Terminal command unavailable: $expected_command"
        fi
    done

    if command -v fc-match >/dev/null 2>&1; then
        log "Noto monospace match: $(fc-match -f '%{family}\n' 'Noto Sans Mono' | head -n 1)"
    fi

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
    configure_pyenv_python
    verify_terminal_environment
    log "Terminal setup stage complete."
}

if [[ "${RICE_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi