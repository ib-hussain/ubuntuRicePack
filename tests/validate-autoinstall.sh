#!/usr/bin/env bash
# Offline structural and product-policy validation for the UbuntuRicePack
# Ubuntu Desktop autoinstall template or a locally prepared ready file.

set -Eeuo pipefail
IFS=$'\n\t'

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
AUTOINSTALL_FILE="$REPO_ROOT/installation/autoinstall.yaml"
ALLOW_TEMPLATE=0
TEMP_DIR=""

usage() {
    cat <<'USAGE'
Usage:
  bash tests/validate-autoinstall.sh [FILE]
  bash tests/validate-autoinstall.sh --template [FILE]

Without --template, validation fails while the password placeholder remains.
Use --template only for validating the tracked, intentionally incomplete file.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            ALLOW_TEMPLATE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            printf 'ERROR: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
        *)
            AUTOINSTALL_FILE="$1"
            shift
            ;;
    esac
done

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] || return 0
    case "$TEMP_DIR" in
        "${TMPDIR:-/tmp}"/ubuntu-rice-autoinstall.*|/tmp/ubuntu-rice-autoinstall.*)
            rm -rf -- "$TEMP_DIR"
            ;;
        *)
            printf 'WARN: refusing to remove unexpected path: %s\n' \
                "$TEMP_DIR" >&2
            ;;
    esac
}
trap cleanup EXIT

command -v python3 >/dev/null 2>&1 ||
    fail "python3 is required."
python3 -c 'import yaml' >/dev/null 2>&1 ||
    fail "PyYAML is required (Ubuntu package: python3-yaml)."
[[ -f "$AUTOINSTALL_FILE" ]] ||
    fail "autoinstall file is missing: $AUTOINSTALL_FILE"
[[ "$(sed -n '1p' "$AUTOINSTALL_FILE")" == "#cloud-config" ]] ||
    fail "the first line must be #cloud-config"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ubuntu-rice-autoinstall.XXXXXX")"
LATE_COMMAND_FILE="$TEMP_DIR/late-command.sh"

python3 - "$AUTOINSTALL_FILE" "$ALLOW_TEMPLATE" "$LATE_COMMAND_FILE" <<'PY'
from pathlib import Path
import re
import sys

import yaml

path = Path(sys.argv[1])
allow_template = sys.argv[2] == "1"
late_command_file = Path(sys.argv[3])
placeholder = "$6$REPLACE_WITH_A_LOCAL_SHA512_CRYPT_HASH"
expected_url = "https://github.com/ib-hussain/ubuntuRicePack.git"
expected_commit = "7e7269acecbda4545b1ff89864e6178475b28e12"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


try:
    document = yaml.safe_load(path.read_text(encoding="utf-8"))
except yaml.YAMLError as error:
    raise SystemExit(f"FAIL: YAML parse error: {error}") from error

require(isinstance(document, dict), "top-level YAML must be a mapping")
require(
    set(document) == {"autoinstall"},
    "autoinstall must be the only top-level key",
)
config = document["autoinstall"]
require(isinstance(config, dict), "autoinstall must be a mapping")
require(config.get("version") == 1, "autoinstall version must be 1")

interactive = config.get("interactive-sections")
require(
    interactive == ["network", "storage"],
    "network and storage must be the two interactive sections",
)
require(
    "storage" not in config,
    "a storage recipe is forbidden; disk selection must remain interactive",
)
require(
    "network" not in config,
    "a network recipe is forbidden; network selection must remain interactive",
)

require(config.get("locale") == "en_US.UTF-8", "locale mismatch")
require(config.get("timezone") == "Asia/Karachi", "timezone mismatch")
keyboard = config.get("keyboard")
require(
    isinstance(keyboard, dict) and keyboard.get("layout") == "us",
    "keyboard layout must be us",
)

identity = config.get("identity")
require(isinstance(identity, dict), "identity section is required")
require(identity.get("realname") == "Ibrahim Hussain", "real name mismatch")
require(identity.get("username") == "ibrahim", "username mismatch")
require(identity.get("hostname") == "ibLaptop", "hostname mismatch")
password = identity.get("password")
require(isinstance(password, str), "identity password must be a string")
if password == placeholder:
    require(
        allow_template,
        "password placeholder remains; run installation/prepare-autoinstall.sh",
    )
else:
    sha512_crypt = re.compile(
        r"^\$6\$(?:rounds=[0-9]+\$)?"
        r"[./0-9A-Za-z]{1,16}\$[./0-9A-Za-z]{86}$"
    )
    require(
        bool(sha512_crypt.fullmatch(password)),
        "identity password is not a valid SHA-512 crypt hash",
    )

ssh = config.get("ssh")
require(isinstance(ssh, dict), "ssh section is required")
require(ssh.get("install-server") is True, "SSH server must be installed")
require(ssh.get("allow-pw") is True, "SSH password login must be enabled")
require(
    ssh.get("authorized-keys") == [],
    "authorized-keys must remain an explicit empty list until a real key is supplied",
)

for section in ("drivers", "codecs"):
    value = config.get(section)
    require(
        isinstance(value, dict) and value.get("install") is True,
        f"{section}.install must be true",
    )
require(config.get("oem") == {"install": "auto"}, "OEM install must be auto")
require(config.get("updates") == "all", "all updates must be installed")
require(config.get("shutdown") == "reboot", "installer must reboot")
require(config.get("snaps") == [], "snaps must be an empty list")

packages = config.get("packages")
require(isinstance(packages, list), "packages must be a list")
required_packages = {
    "ca-certificates",
    "git",
    "gnome-terminal",
    "openssh-server",
    "python3",
    "python3-yaml",
}
require(
    required_packages.issubset(set(packages)),
    "bootstrap package set is incomplete",
)
require(
    not {"firefox", "snapd"}.intersection(packages),
    "Firefox and snapd are prohibited",
)

late_commands = config.get("late-commands")
require(
    isinstance(late_commands, list) and late_commands,
    "late-commands must be a non-empty list",
)
require(
    all(isinstance(command, str) for command in late_commands),
    "each late command must be a shell string",
)
late_blob = "\n".join(late_commands)

required_fragments = (
    expected_url,
    expected_commit,
    'RICE_COMMIT=7e7269acecbda4545b1ff89864e6178475b28e12',
    'git -C "$RICE_DIR" checkout --detach FETCH_HEAD',
    'git -C "$RICE_DIR" rev-parse HEAD',
    "apt-get purge -y",
    "apt-mark hold snapd firefox",
    "Pin-Priority: -10",
    "sshd -t",
    "systemctl enable ssh.service",
    "PermitRootLogin no",
    "PasswordAuthentication yes",
    "ssh-keygen -A",
    "visudo -cf",
    "ubuntu-rice-first-login.desktop",
    "gnome-terminal --wait --",
    "RICE_PASSWORDLESS_SUDO=0",
    "bash ./install-rice.sh --mode desktop --strict",
    "first-login.complete",
    "systemd-cat -t ubuntu-rice-first-login",
)
for fragment in required_fragments:
    require(fragment in late_blob, f"late command is missing: {fragment}")

require(
    "git checkout main" not in late_blob
    and "git checkout origin/main" not in late_blob,
    "bootstrap must not check out a moving branch",
)

late_command_file.write_text(
    "#!/usr/bin/env bash\n" + late_blob + "\n",
    encoding="utf-8",
)

print(
    "PASS: YAML structure, fully interactive storage/network, identity, "
    "SSH, no-Snap policy, pinned bootstrap, and first-login workflow validate"
)
PY

bash -n "$LATE_COMMAND_FILE"
printf 'PASS: embedded late-command and first-login shell parse\n'

if [[ "$ALLOW_TEMPLATE" == "1" ]]; then
    printf 'PASS: autoinstall template is structurally valid (password intentionally unset)\n'
else
    printf 'PASS: autoinstall is ready to import: %s\n' "$AUTOINSTALL_FILE"
fi
