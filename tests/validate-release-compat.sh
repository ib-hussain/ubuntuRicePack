#!/usr/bin/env bash
# Offline regression tests for Ubuntu 25.04/26.04 release selection and the
# narrowly-scoped Plucky APT archive migration.

set -Eeuo pipefail
IFS=$'\n\t'

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
COMPAT_SCRIPT="$REPO_ROOT/scripts/ubuntu-release-compat.sh"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ubuntu-rice-release-test.XXXXXX")"

cleanup() {
    case "$TEMP_DIR" in
        "${TMPDIR:-/tmp}"/ubuntu-rice-release-test.*|/tmp/ubuntu-rice-release-test.*)
            rm -rf -- "$TEMP_DIR"
            ;;
    esac
}
trap cleanup EXIT

pass() {
    printf 'PASS: %s\n' "$*"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$COMPAT_SCRIPT" ]] || fail "release compatibility helper is missing"

[[ "$(bash "$COMPAT_SCRIPT" --profile 25.04 plucky)" == \
    $'25.04\tplucky\t48\teol' ]] ||
    fail "Ubuntu 25.04 profile is incorrect"
[[ "$(bash "$COMPAT_SCRIPT" --profile 26.04 resolute)" == \
    $'26.04\tresolute\t50\tsupported' ]] ||
    fail "Ubuntu 26.04 profile is incorrect"
if bash "$COMPAT_SCRIPT" --profile 24.04 noble >/dev/null 2>&1; then
    fail "an undefined Ubuntu release profile was accepted"
fi
pass "Ubuntu 25.04/GNOME 48 and 26.04/GNOME 50 profiles resolve"

APT_ROOT="$TEMP_DIR/etc/apt"
mkdir -p -- "$APT_ROOT/sources.list.d"
cat >"$APT_ROOT/sources.list" <<'EOF_SOURCES_LIST'
deb http://archive.ubuntu.com/ubuntu plucky main restricted
deb http://security.ubuntu.com/ubuntu plucky-security main restricted
EOF_SOURCES_LIST
cat >"$APT_ROOT/sources.list.d/ubuntu.sources" <<'EOF_DEB822'
Types: deb
URIs: https://us.archive.ubuntu.com/ubuntu/
Suites: plucky plucky-updates
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF_DEB822
cat >"$APT_ROOT/sources.list.d/vendor.list" <<'EOF_VENDOR'
deb [arch=amd64] https://packages.microsoft.com/repos/code stable main
# plucky is deliberately present to ensure codename alone cannot rewrite it.
EOF_VENDOR

cp -a -- "$APT_ROOT/sources.list" "$TEMP_DIR/original-sources.list"
cp -a -- "$APT_ROOT/sources.list.d/ubuntu.sources" \
    "$TEMP_DIR/original-ubuntu.sources"
cp -a -- "$APT_ROOT/sources.list.d/vendor.list" "$TEMP_DIR/original-vendor.list"

first_output="$(
    bash "$COMPAT_SCRIPT" --rewrite-eol-sources "$APT_ROOT" plucky
)"
grep -Fq $'changed\t' <<<"$first_output" ||
    fail "Plucky migration did not report changed sources"

grep -Fq 'http://old-releases.ubuntu.com/ubuntu' "$APT_ROOT/sources.list" ||
    fail "one-line Ubuntu sources were not migrated"
grep -Fq 'http://old-releases.ubuntu.com/ubuntu' \
    "$APT_ROOT/sources.list.d/ubuntu.sources" ||
    fail "deb822 Ubuntu sources were not migrated"
if grep -Eq '(archive|security)\.ubuntu\.com' \
    "$APT_ROOT/sources.list" \
    "$APT_ROOT/sources.list.d/ubuntu.sources"
then
    fail "a live Ubuntu URI remains in migrated Plucky sources"
fi

cmp -s -- \
    "$TEMP_DIR/original-sources.list" \
    "$APT_ROOT/sources.list.ubuntuRicePack-pre-eol" ||
    fail "sources.list backup does not match the original"
cmp -s -- \
    "$TEMP_DIR/original-ubuntu.sources" \
    "$APT_ROOT/sources.list.d/ubuntu.sources.ubuntuRicePack-pre-eol" ||
    fail "deb822 source backup does not match the original"
cmp -s -- "$TEMP_DIR/original-vendor.list" \
    "$APT_ROOT/sources.list.d/vendor.list" ||
    fail "third-party APT source was modified"

find "$APT_ROOT" -type f -print0 | sort -z | xargs -0 sha256sum \
    >"$TEMP_DIR/after-first.sha256"
second_output="$(
    bash "$COMPAT_SCRIPT" --rewrite-eol-sources "$APT_ROOT" plucky
)"
find "$APT_ROOT" -type f -print0 | sort -z | xargs -0 sha256sum \
    >"$TEMP_DIR/after-second.sha256"
grep -Fq $'unchanged\t' <<<"$second_output" ||
    fail "second Plucky migration did not report an idempotent no-op"
cmp -s -- "$TEMP_DIR/after-first.sha256" "$TEMP_DIR/after-second.sha256" ||
    fail "second Plucky migration changed files"
pass "Plucky archive migration is scoped, backed up, and idempotent"

grep -Fq 'prepare_ubuntu_package_sources' "$REPO_ROOT/install-rice.sh" ||
    fail "top-level installer does not prepare archived sources"
[[ "$(grep -Fc 'prepare_ubuntu_package_sources' \
    "$REPO_ROOT/scripts/01-install-packages.sh")" -ge 2 ]] ||
    fail "standalone package stage does not protect both APT refreshes"
if grep -Eq 'EXPECTED_GNOME_MAJOR=.*50|RICE_GNOME_MAJOR:-50' \
    "$REPO_ROOT/scripts/04-setup-extensions.sh" \
    "$REPO_ROOT/scripts/install-rice-shell-extensions.sh"
then
    fail "an extension installer still defaults every release to GNOME 50"
fi
grep -Fq 'RICE_EXPECTED_GNOME_MAJOR' \
    "$REPO_ROOT/scripts/04-setup-extensions.sh" ||
    fail "Ubuntu extension stage does not use the release GNOME profile"
grep -Fq 'Ubuntu 25.04 profile: web-search-provider is not required.' \
    "$REPO_ROOT/scripts/04-setup-extensions.sh" ||
    fail "Ubuntu 26.04-only web-search provider is still mandatory on 25.04"
for verifier in \
    "$REPO_ROOT/scripts/05-apply-gnome-settings.sh" \
    "$REPO_ROOT/scripts/08-finalize-desktop.sh"
do
    grep -Fq 'ubuntu_web_search_provider_expected' "$verifier" ||
        fail "$(basename "$verifier") does not use release-specific extension verification"
done
grep -Fq 'not packaged on Ubuntu 25.04' \
    "$REPO_ROOT/scripts/08-finalize-desktop.sh" ||
    fail "final verifier still requires Resolute's VLC PipeWire split on Plucky"
pass "installer and extension stages consume the release compatibility profile"
