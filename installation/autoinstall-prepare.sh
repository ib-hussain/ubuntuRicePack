#!/usr/bin/env bash
# Create a ready-to-import autoinstall file without storing a plaintext
# password or modifying the tracked template.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/autoinstall.yaml"
OUTPUT_FILE="${1:-$SCRIPT_DIR/autoinstall-ready.yaml}"
PLACEHOLDER='$6$REPLACE_WITH_A_LOCAL_SHA512_CRYPT_HASH'
COMMIT_PLACEHOLDER='REPLACE_WITH_REPOSITORY_COMMIT'
EXPECTED_REMOTE='https://github.com/ib-hussain/ubuntuRicePack.git'

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

command -v openssl >/dev/null 2>&1 ||
    fail "openssl is required (Ubuntu package: openssl)."
command -v python3 >/dev/null 2>&1 ||
    fail "python3 is required."
command -v git >/dev/null 2>&1 ||
    fail "git is required."
[[ -f "$TEMPLATE_FILE" ]] ||
    fail "Template is missing: $TEMPLATE_FILE"
[[ "$OUTPUT_FILE" != "$TEMPLATE_FILE" ]] ||
    fail "Refusing to overwrite the tracked template."

[[ -d "$REPO_ROOT/.git" ]] ||
    fail "Run this helper from the committed ubuntuRicePack Git checkout."
[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] ||
    fail "Commit or remove every working-tree change before preparing autoinstall."

REPOSITORY_COMMIT="$(git -C "$REPO_ROOT" rev-parse --verify HEAD)"
[[ "$REPOSITORY_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    fail "Could not resolve a full repository commit."

REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin)"
[[ "$REMOTE_URL" == "$EXPECTED_REMOTE" ]] ||
    fail "origin must be $EXPECTED_REMOTE (found: $REMOTE_URL)."

REMOTE_COMMIT="$(
    git ls-remote --exit-code origin refs/heads/main |
        awk 'NR == 1 {print $1}'
)" || fail "Could not verify origin/main."
[[ "$REMOTE_COMMIT" == "$REPOSITORY_COMMIT" ]] ||
    fail "Push commit $REPOSITORY_COMMIT to origin/main before preparing autoinstall."

printf '%s\n' \
    "This password will be used for local login and SSH password login." \
    "A short password is accepted, but it is unsafe on an Internet-exposed SSH server."

read -r -s -p "Password for ibrahim: " PASSWORD_ONE
printf '\n'
read -r -s -p "Confirm password: " PASSWORD_TWO
printf '\n'

[[ -n "$PASSWORD_ONE" ]] || fail "The password cannot be empty."
[[ "$PASSWORD_ONE" == "$PASSWORD_TWO" ]] ||
    fail "The passwords did not match."

PASSWORD_HASH="$(
    printf '%s' "$PASSWORD_ONE" |
        openssl passwd -6 -stdin
)"
unset PASSWORD_ONE PASSWORD_TWO
[[ "$PASSWORD_HASH" == '$6$'* ]] ||
    fail "openssl did not produce a SHA-512 crypt hash."

PASSWORD_HASH="$PASSWORD_HASH" \
REPOSITORY_COMMIT="$REPOSITORY_COMMIT" \
python3 - \
    "$TEMPLATE_FILE" \
    "$OUTPUT_FILE" \
    "$PLACEHOLDER" \
    "$COMMIT_PLACEHOLDER" <<'PY'
from pathlib import Path
import os
import sys

template = Path(sys.argv[1])
output = Path(sys.argv[2])
placeholder = sys.argv[3]
commit_placeholder = sys.argv[4]
password_hash = os.environ.pop("PASSWORD_HASH")
repository_commit = os.environ.pop("REPOSITORY_COMMIT")

text = template.read_text(encoding="utf-8")
if text.count(placeholder) != 1:
    raise SystemExit(
        f"expected one password placeholder in {template}, "
        f"found {text.count(placeholder)}"
    )
if text.count(commit_placeholder) != 2:
    raise SystemExit(
        f"expected two commit placeholders in {template}, "
        f"found {text.count(commit_placeholder)}"
    )

output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_name(f".{output.name}.tmp")
temporary.write_text(
    text.replace(placeholder, password_hash).replace(
        commit_placeholder,
        repository_commit,
    ),
    encoding="utf-8",
)
temporary.chmod(0o600)
temporary.replace(output)
PY
unset PASSWORD_HASH REPOSITORY_COMMIT

bash "$REPO_ROOT/tests/validate-autoinstall.sh" "$OUTPUT_FILE"
printf 'Ready autoinstall file: %s\n' "$OUTPUT_FILE"
printf '%s\n' \
    "Keep it private: it contains a reusable password hash." \
    "Pinned repository commit: $REMOTE_COMMIT" \
    "At the installer, networking and storage will still be interactive."
