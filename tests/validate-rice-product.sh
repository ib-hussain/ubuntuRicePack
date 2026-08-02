#!/usr/bin/env bash
# Static product validation for UbuntuRicePack and its GNOME extensions.

set -Eeuo pipefail
IFS=$'\n\t'

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
DOCK_DIR="$REPO_ROOT/configs/extensions/rice-dock@ib-hussain"
TOP_BAR_DIR="$REPO_ROOT/configs/extensions/rice-top-bar@ib-hussain"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rice-product-test.XXXXXX")"
SCHEMA_COMPILER="$(command -v glib-compile-schemas 2>/dev/null || true)"
if [[ -z "$SCHEMA_COMPILER" &&
    -x /usr/lib/x86_64-linux-gnu/glib-2.0/glib-compile-schemas ]]
then
    SCHEMA_COMPILER=/usr/lib/x86_64-linux-gnu/glib-2.0/glib-compile-schemas
fi

cleanup() {
    [[ "$TEMP_DIR" == "${TMPDIR:-/tmp}"/rice-product-test.* ]] || return 0
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
    printf 'PASS: %s\n' "$*"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "required test command is unavailable: $1"
}

require_command bash
require_command find
require_command awk
require_command python3
[[ -n "$SCHEMA_COMPILER" ]] ||
    fail "required test command is unavailable: glib-compile-schemas"

while IFS= read -r -d '' script; do
    if LC_ALL=C grep -q $'\r' "$script"; then
        fail "shell script contains CRLF line endings: $script"
    fi
    bash -n "$script"
done < <(
    find "$REPO_ROOT" -type f \
        \( -name '*.sh' -o -path '*/configs/power-menu/ib-power-menu' \) \
        -print0
)
pass "all shell scripts parse"

grep -Fq 'command sudo -- "$@"' "$REPO_ROOT/scripts/00-common.sh" ||
    fail "run_root does not execute a protected argv array through sudo"
if grep -A25 '^run_root()' "$REPO_ROOT/scripts/00-common.sh" |
    grep -Eq '^[[:space:]]*(eval|bash[[:space:]]+-c)([[:space:]]|$)'
then
    fail "run_root must not evaluate a command string"
fi
pass "run_root validates its argv and bypasses shell aliases/functions"

help_output="$(bash "$REPO_ROOT/install-rice.sh" --help)"
grep -Fq -- '-m, --mode MODE' <<<"$help_output" ||
    fail "installer help does not expose the shortened mode option"
grep -Fq -- '-r, --repair-pass' <<<"$help_output" ||
    fail "installer help does not expose the shortened PAM repair option"
pass "installer help is side-effect-free and exposes the shortened options"

awk \
    '/<<'\''ROTATOR'\''/{capture=1; next} /^ROTATOR$/{capture=0} capture' \
    "$REPO_ROOT/scripts/06-setup-assets-grub-wallpapers.sh" \
    >"$TEMP_DIR/rice-wallpaper-rotator"
bash -n "$TEMP_DIR/rice-wallpaper-rotator"
for script_tag in \
    "scripts/03-setup-terminal.sh:EOF_FF_BLUE" \
    "scripts/10-setup-local-ai-ollama-openwebui.sh:LAUNCHER"
do
    source_file="${script_tag%%:*}"
    heredoc_tag="${script_tag##*:}"
    generated_file="$TEMP_DIR/$heredoc_tag"
    awk -v tag="$heredoc_tag" \
        '$0 ~ "<<.*" tag {capture=1; next}
         $0 == tag {capture=0}
         capture' \
        "$REPO_ROOT/$source_file" \
        >"$generated_file"
    bash -n "$generated_file"
done
pass "generated helper shell scripts parse"

python3 - "$REPO_ROOT" <<'PY'
import json
from pathlib import Path
import ast
import re
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
extensions = {
    "rice-dock@ib-hussain": root / "configs/extensions/rice-dock@ib-hussain",
    "rice-top-bar@ib-hussain": root / "configs/extensions/rice-top-bar@ib-hussain",
}

for uuid, directory in extensions.items():
    metadata = json.loads(
        (directory / "metadata.json").read_text(encoding="utf-8")
    )
    if metadata.get("uuid") != uuid:
        raise SystemExit(f"{directory}: metadata UUID mismatch")
    versions = {str(value) for value in metadata.get("shell-version", [])}
    missing = {"48", "50"} - versions
    if missing:
        raise SystemExit(
            f"{uuid}: GNOME Shell versions are not declared: "
            f"{', '.join(sorted(missing))}"
        )

for path in list(root.rglob("*.xml")) + list(root.rglob("*.ui")):
    ET.parse(path)

for path in root.glob("configs/nautilus-python/*.py"):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

for path in root.glob("configs/**/*.css"):
    depth = 0
    for character in path.read_text(encoding="utf-8"):
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth < 0:
                raise SystemExit(f"{path}: unmatched closing CSS brace")
    if depth:
        raise SystemExit(f"{path}: {depth} unclosed CSS block(s)")

relative_import = re.compile(
    r"""(?:from\s+|import\s*)['"](\.[^'"]+)['"]"""
)
for directory in extensions.values():
    for source in directory.rglob("*.js"):
        text = source.read_text(encoding="utf-8")
        for target in relative_import.findall(text):
            resolved = (source.parent / target).resolve()
            if not resolved.is_file():
                raise SystemExit(
                    f"{source.relative_to(root)}: missing import {target}"
                )

heredoc_start = re.compile(r"""<<['"]?(PY[A-Z0-9_]*)['"]?""")
for script in [root / "install-rice.sh", *root.glob("scripts/*.sh")]:
    lines = script.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        match = heredoc_start.search(lines[index])
        if not match:
            index += 1
            continue
        tag = match.group(1)
        start = index + 1
        index = start
        while index < len(lines) and lines[index] != tag:
            index += 1
        if index == len(lines):
            raise SystemExit(f"{script}: unterminated {tag} heredoc")
        ast.parse("\n".join(lines[start:index]) + "\n")
        index += 1

print(
    "PASS: metadata, XML/UI, embedded Python, and relative JS imports validate"
)
PY

for extension_dir in "$DOCK_DIR" "$TOP_BAR_DIR"; do
    schema_temp="$TEMP_DIR/$(basename "$extension_dir")"
    mkdir -p -- "$schema_temp"
    find "$extension_dir/schemas" \
        -maxdepth 1 \
        -type f \
        ! -name gschemas.compiled \
        -exec cp -a -- {} "$schema_temp/" \;
    "$SCHEMA_COMPILER" --strict "$schema_temp"
    [[ -s "$schema_temp/gschemas.compiled" ]] ||
        fail "compiled schema is empty for $(basename "$extension_dir")"
done
pass "both extension schemas compile strictly"

mapfile -t logo_files < <(
    find "$DOCK_DIR/media" \
        -maxdepth 1 \
        -type f \
        -name 'logo.*' \
        -printf '%f\n' |
        sort
)
[[ "${#logo_files[@]}" -eq 1 && "${logo_files[0]}" == "logo.png" ]] ||
    fail "Rice Dock must contain exactly one logo source named logo.png"
[[ -s "$DOCK_DIR/stylesheet.css" ]] ||
    fail "Rice Dock compiled stylesheet.css is missing"
[[ -s "$DOCK_DIR/_stylesheet.scss" ]] ||
    fail "Rice Dock stylesheet source is missing"
grep -Fq "media/logo.png" "$DOCK_DIR/appIcons.js" ||
    fail "Show Applications does not use media/logo.png"
grep -Fq "style_class: 'rice-show-apps-icon'" "$DOCK_DIR/appIcons.js" ||
    fail "Show Applications does not use its isolated Rice style class"
if grep -Fq \
    "style_class: 'show-apps-icon rice-show-apps-icon'" \
    "$DOCK_DIR/appIcons.js"
then
    fail "Show Applications still inherits shell-theme replacement artwork"
fi
for selector in \
    rice-show-apps-button \
    rice-show-apps-base-icon \
    rice-show-apps-icon
do
    grep -Fq "$selector" "$DOCK_DIR/stylesheet.css" ||
        fail "compiled dock stylesheet lacks $selector compatibility rule"
done
grep -Fq "background-image: none" "$DOCK_DIR/stylesheet.css" ||
    fail "Rice Dock does not suppress shell-theme Show Apps artwork"
if grep -Eq \
    'background-image:[^;]*(logo\.png|arch-logo)' \
    "$DOCK_DIR/stylesheet.css" \
    "$DOCK_DIR/_stylesheet.scss" \
    "$DOCK_DIR/appIconIndicators.js"
then
    fail "logo is incorrectly layered as a CSS background"
fi
if find "$DOCK_DIR" -type f -name 'arch-logo.*' -print -quit |
    grep -q .
then
    fail "retired arch-logo asset remains in Rice Dock"
fi
pass "Rice Dock uses one theme-isolated, unlayered logo.png content source"

grep -Fq "TransparentPanelController" "$TOP_BAR_DIR/extension.js" ||
    fail "Rice Top Bar does not start the transparency controller"
grep -Fq "background-color: rgba(0, 0, 0, 0)" \
    "$TOP_BAR_DIR/transparentPanel.js" ||
    fail "Rice Top Bar lacks its inline transparency fallback"
grep -Fq "background-color: transparent" "$TOP_BAR_DIR/stylesheet.css" ||
    fail "Rice Top Bar lacks its theme-level transparency rule"
pass "Rice Top Bar has CSS and inline transparency controls"

for retired in \
    arch-dock-icon@ib-hussain \
    dash-to-dock@micxgx.gmail.com \
    hidetopbar@mathieu.bidon.ca
do
    [[ ! -d "$REPO_ROOT/configs/extensions/$retired" ]] ||
        fail "retired extension source remains: $retired"
done
pass "retired conflicting extension source is absent"

NAUTILUS_SOURCE="$REPO_ROOT/configs/nautilus-python/ib_context_tools.py"
for installer in \
    "$REPO_ROOT/scripts/02-restore-themes-and-configs.sh" \
    "$REPO_ROOT/scripts/07-setup-vscode.sh"
do
    grep -Fq '.local/share/nautilus-python/extensions' "$installer" ||
        fail "$(basename "$installer") does not use Nautilus 4's extensions directory"
done
grep -Fq 'gi.require_version("Nautilus", "4.0")' "$NAUTILUS_SOURCE" ||
    fail "Nautilus integration does not request the Nautilus 4 API"
if grep -Eq '/usr/bin/code|GDK_BACKEND' "$NAUTILUS_SOURCE"; then
    fail "Nautilus integration contains a host-specific VS Code launcher"
fi
pass "Nautilus 4 integration uses its supported extension directory and portable launcher"

VSCODE_SETUP="$REPO_ROOT/scripts/07-setup-vscode.sh"
if grep -Eq \
    'copy_(file|dir_contents).*globalStorage|rsync[^#]*configs/vscode/extensions' \
    "$VSCODE_SETUP"
then
    fail "VS Code setup still copies non-portable runtime state"
fi
grep -Fq 'code --install-extension' "$VSCODE_SETUP" ||
    fail "VS Code extensions are not installed through the supported CLI"
grep -Fq 'apt_package_installed code' "$VSCODE_SETUP" ||
    fail "VS Code setup does not verify the Microsoft APT package"
grep -Fq 'dpkg-query -S "$CODE_REAL_PATH"' "$VSCODE_SETUP" ||
    fail "VS Code setup does not verify ownership of the active code launcher"
grep -Fq 'settings.json keybindings.json' "$VSCODE_SETUP" ||
    fail "VS Code setup does not restore the portable user settings"
grep -Fq 'vscode-profile-v2.complete' "$VSCODE_SETUP" ||
    fail "VS Code setup lacks its one-time profile migration marker"
grep -Fq 'backup_path "$VSCODE_CONFIG_ROOT"' "$VSCODE_SETUP" ||
    fail "VS Code profile repair is not backed up"
grep -Fq 'rm -rf -- "$VSCODE_CONFIG_ROOT"' "$VSCODE_SETUP" ||
    fail "VS Code profile repair does not remove captured session state"
grep -Fq -- '--stop-running' "$VSCODE_SETUP" ||
    fail "VS Code repair cannot explicitly stop a stale editor process"
grep -Fq 'code --new-window .' "$VSCODE_SETUP" ||
    fail "VS Code setup does not report the supported fresh-window launch"
if LC_ALL=C grep -q $'\r' "$REPO_ROOT/configs/vscode/extensions.txt"; then
    fail "VS Code extension list contains CRLF line endings"
fi
pass "VS Code restore performs a backed-up one-time Linux profile migration"

for package in \
    papirus-icon-theme \
    python3-nautilus \
    ptyxis \
    xdg-terminal-exec \
    procps \
    audacious \
    audacious-plugins
do
    grep -Fxq "$package" "$REPO_ROOT/packages/ubuntu-packages.txt" ||
        fail "required Ubuntu package is absent from package inventory: $package"
done
grep -Fq 'remove_snap_stack' "$REPO_ROOT/scripts/01-install-packages.sh" ||
    fail "package installer does not enforce the no-Snap policy"
pass "Ubuntu package inventory covers Papirus, Nautilus, Ptyxis, and Audacious"

grep -Fq \
    'releases/latest/download/SHA-256.txt' \
    "$REPO_ROOT/scripts/03-setup-terminal.sh" ||
    fail "Nerd Fonts installer does not use the upstream checksum manifest"
if grep -Fq \
    'api.github.com/repos/ryanoasis/nerd-fonts' \
    "$REPO_ROOT/scripts/03-setup-terminal.sh"
then
    fail "Nerd Fonts installer still depends on GitHub's anonymous REST quota"
fi
grep -Fq '.cache/ubuntuRicePack/nerd-fonts' \
    "$REPO_ROOT/scripts/03-setup-terminal.sh" ||
    fail "Nerd Fonts installer does not cache verified archives"
pass "Nerd Fonts downloads are checksummed, cached, and independent of the REST API"

for terminal_asset in \
    "$REPO_ROOT/configs/ptyxis/IB-Glass.palette" \
    "$REPO_ROOT/configs/ptyxis/ubuntu-xdg-terminals.list"
do
    [[ -s "$terminal_asset" ]] ||
        fail "Ptyxis configuration asset is missing: $terminal_asset"
done
grep -Fq 'org.gnome.Ptyxis.Profile' \
    "$REPO_ROOT/scripts/apply-ubuntu-gnome-best-settings.sh" ||
    fail "GNOME settings stage does not configure the active Ptyxis profile"
grep -Fq "org.gnome.Ptyxis|interface-style|'dark'" \
    "$REPO_ROOT/scripts/apply-ubuntu-gnome-best-settings.sh" ||
    fail "Ptyxis is not configured through its supported interface-style key"
if grep -A35 -F 'ptyxis_profile_path=' \
    "$REPO_ROOT/scripts/apply-ubuntu-gnome-best-settings.sh" |
    grep -Fq 'dark-theme'
then
    fail "Ptyxis profile uses the unsupported dark-theme key"
fi
pass "Ubuntu's Ptyxis terminal has a palette, default-terminal entry, and profile settings"

grep -Fq 'find "$WALLPAPER_DIR" -type f' \
    "$REPO_ROOT/scripts/06-setup-assets-grub-wallpapers.sh" ||
    fail "wallpaper cache check is missing"
if grep -A8 -F 'wallpaper_images_exist()' \
    "$REPO_ROOT/scripts/06-setup-assets-grub-wallpapers.sh" |
    grep -Fq -- '-print0'
then
    fail "wallpaper existence check can still fail with SIGPIPE under pipefail"
fi
pass "wallpaper reruns use a pipefail-safe local cache check"

bash "$REPO_ROOT/tests/validate-release-compat.sh"
pass "Ubuntu 25.04/26.04 release compatibility validates"

bash "$REPO_ROOT/tests/validate-autoinstall.sh" \
    --template \
    "$REPO_ROOT/installation/autoinstall.yaml"
pass "hybrid Ubuntu Desktop autoinstall template validates"

if command -v node >/dev/null 2>&1; then
    while IFS= read -r -d '' source; do
        node --input-type=module --check <"$source"
    done < <(
        find "$DOCK_DIR" "$TOP_BAR_DIR" -type f -name '*.js' -print0
    )
    pass "all extension JavaScript parses as ECMAScript modules"

    node - "$TOP_BAR_DIR/transparentPanel.js" <<'NODE'
const fs = require('fs');
const sourcePath = process.argv[2];
let source = fs.readFileSync(sourcePath, 'utf8')
    .replace(
        "import * as Main from 'resource:///org/gnome/shell/ui/main.js';",
        '')
    .replace(
        'export class TransparentPanelController',
        'class TransparentPanelController');

const factory = new Function(
    'Main',
    `${source}\nreturn TransparentPanelController;`);

class Actor {
    constructor(style = null) {
        this.style = style;
        this.classes = new Set();
    }

    get_style() {
        return this.style;
    }

    set_style(value) {
        this.style = value;
    }

    add_style_class_name(value) {
        this.classes.add(value);
    }

    remove_style_class_name(value) {
        this.classes.delete(value);
    }
}

const panel = new Actor('color: white');
const panelBox = new Actor();
const Controller = factory({panel, layoutManager: {panelBox}});
const controller = new Controller('[test]');

if (!panel.style.includes('rgba(0, 0, 0, 0)') ||
    !panelBox.style.includes('rgba(0, 0, 0, 0)') ||
    !panel.classes.has('rice-transparent-panel'))
    throw new Error('transparency was not fully applied');

controller.destroy();
if (panel.style !== 'color: white' ||
    panelBox.style !== null ||
    panel.classes.has('rice-transparent-panel'))
    throw new Error('prior actor state was not restored');
NODE
    pass "transparent-panel controller applies and restores actor state"
else
    printf 'SKIP: node is unavailable; JavaScript parser check not run\n'
fi

pass "UbuntuRicePack static product validation complete"
