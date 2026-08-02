#!/usr/bin/env bash
# Pure Ubuntu release-profile helpers plus the narrowly-scoped APT source
# migration needed by end-of-life releases. This file is safe to source.

set -Eeuo pipefail
IFS=$'\n\t'

ubuntu_release_profile() {
    local version_id="${1:-}"
    local codename="${2:-}"

    case "$version_id:$codename" in
        25.04:plucky)
            printf '%s\t%s\t%s\t%s\n' \
                '25.04' 'plucky' '48' 'eol'
            ;;
        26.04:resolute)
            printf '%s\t%s\t%s\t%s\n' \
                '26.04' 'resolute' '50' 'supported'
            ;;
        *)
            return 1
            ;;
    esac
}

ubuntu_expected_gnome_major() {
    local profile=""
    local version_id="${1:-}"
    local codename="${2:-}"

    profile="$(ubuntu_release_profile "$version_id" "$codename")" || return 1
    cut -f3 <<<"$profile"
}

ubuntu_release_support_status() {
    local profile=""
    local version_id="${1:-}"
    local codename="${2:-}"

    profile="$(ubuntu_release_profile "$version_id" "$codename")" || return 1
    cut -f4 <<<"$profile"
}

rewrite_eol_ubuntu_sources() {
    local apt_root="${1:?Missing APT configuration root}"
    local codename="${2:?Missing Ubuntu codename}"

    [[ "$codename" == "plucky" ]] || {
        printf 'Refusing EOL source migration for unsupported codename: %s\n' \
            "$codename" >&2
        return 2
    }
    [[ -d "$apt_root" && ! -L "$apt_root" ]] || {
        printf 'APT configuration root is not a real directory: %s\n' \
            "$apt_root" >&2
        return 2
    }

    python3 - "$apt_root" "$codename" <<'PY_EOL_SOURCES'
from pathlib import Path
import os
import re
import shutil
import stat
import sys
import tempfile

apt_root = Path(sys.argv[1]).resolve()
codename = sys.argv[2]
old_uri = "http://old-releases.ubuntu.com/ubuntu"

if codename != "plucky":
    raise SystemExit(f"unsupported EOL codename: {codename}")

official_uri = re.compile(
    r"https?://(?:"
    r"(?:[a-z0-9-]+\.)?archive\.ubuntu\.com/ubuntu"
    r"|security\.ubuntu\.com/ubuntu"
    r"|ports\.ubuntu\.com/ubuntu-ports"
    r")/?",
    re.IGNORECASE,
)

candidates = [apt_root / "sources.list"]
source_directory = apt_root / "sources.list.d"
if source_directory.is_dir() and not source_directory.is_symlink():
    candidates.extend(sorted(source_directory.glob("*.list")))
    candidates.extend(sorted(source_directory.glob("*.sources")))

changed = []
for path in candidates:
    if not path.exists() or path.is_symlink() or not path.is_file():
        continue

    text = path.read_text(encoding="utf-8")
    if codename not in text or not official_uri.search(text):
        continue

    updated = official_uri.sub(old_uri, text)
    if updated == text:
        continue

    backup = path.with_name(path.name + ".ubuntuRicePack-pre-eol")
    if not backup.exists():
        shutil.copy2(path, backup, follow_symlinks=False)

    source_stat = path.stat()
    mode = stat.S_IMODE(source_stat.st_mode)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        dir=path.parent,
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(updated)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, mode)
        os.chown(temporary_name, source_stat.st_uid, source_stat.st_gid)
        os.replace(temporary_name, path)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass

    changed.append(path)

for path in changed:
    print(f"changed\t{path}")
if not changed:
    print("unchanged\tUbuntu archive sources already require no migration")
PY_EOL_SOURCES
}

usage() {
    cat <<'USAGE'
Usage:
  ubuntu-release-compat.sh --profile VERSION CODENAME
  ubuntu-release-compat.sh --rewrite-eol-sources APT_ROOT CODENAME

Supported profiles:
  Ubuntu 25.04 (Plucky)   GNOME 48   archived/EOL compatibility
  Ubuntu 26.04 (Resolute) GNOME 50   supported LTS
USAGE
}

main() {
    case "${1:-}" in
        --profile)
            [[ "$#" -eq 3 ]] || {
                usage >&2
                return 2
            }
            ubuntu_release_profile "$2" "$3"
            ;;
        --rewrite-eol-sources)
            [[ "$#" -eq 3 ]] || {
                usage >&2
                return 2
            }
            rewrite_eol_ubuntu_sources "$2" "$3"
            ;;
        --help | -h)
            usage
            ;;
        *)
            usage >&2
            return 2
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
