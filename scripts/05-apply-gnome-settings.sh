#!/usr/bin/env bash
# Apply the curated GNOME configuration. Never imports a whole dconf database.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_gnome_session

log "Applying the curated Ubuntu GNOME configuration."

BEST_SETTINGS_SCRIPT="$SCRIPT_DIR/apply-ubuntu-gnome-best-settings.sh"
if [[ -f "$BEST_SETTINGS_SCRIPT" ]]; then
    bash "$BEST_SETTINGS_SCRIPT"
else
    warn "The comprehensive GNOME settings script is absent: $BEST_SETTINGS_SCRIPT"
fi

find_first_file() {
    local candidate=""
    for candidate in "$@"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

extension_settings="$(
    find_first_file \
        "$REPO_ROOT/configs/dconf/extensions-settings.dconf" \
        "$REPO_ROOT/gnome-settings-export/extensions-settings.dconf" ||
        true
)"
terminal_settings="$(
    find_first_file \
        "$REPO_ROOT/configs/dconf/terminal-settings.dconf" \
        "$REPO_ROOT/gnome-settings-export/terminal-settings.dconf" ||
        true
)"

if [[ -n "$extension_settings" ]]; then
    dconf load /org/gnome/shell/extensions/ <"$extension_settings"
    log "Loaded the curated extension settings subtree."
fi

if [[ -n "$terminal_settings" ]] &&
        command -v gnome-terminal >/dev/null 2>&1; then
    dconf load /org/gnome/terminal/ <"$terminal_settings"
    log "Loaded the GNOME Terminal profile."
fi

# Reassert portable Ubuntu values after importing the Arch extension settings.
gs_set org.gnome.desktop.interface gtk-theme "'MacTahoe-Dark-blue'"
gs_set org.gnome.desktop.interface icon-theme "'Papirus-Dark'"
gs_set org.gnome.desktop.interface color-scheme "'prefer-dark'"
gs_set org.gnome.desktop.wm.preferences button-layout "':minimize,maximize,close'"
gs_set org.gnome.shell.extensions.user-theme name "'MacTahoe-Dark-blue'"
gs_set org.gnome.shell.extensions.dash-to-dock preferred-monitor "-2"
gs_set org.gnome.shell.extensions.dash-to-dock \
    preferred-monitor-by-connector "'primary'"

python3 - <<'PY'
import ast
import pathlib
import subprocess


def run(*args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def get(schema: str, key: str, default: str = "") -> str:
    result = run("gsettings", "get", schema, key)
    return result.stdout.strip() if result.returncode == 0 else default


def variant_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


media_schema = "org.gnome.settings-daemon.plugins.media-keys"
base_path = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
relocatable = (
    "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"
)

keybindings = {
    f"{base_path}terminal/": (
        "Open Terminal",
        "gnome-terminal",
        "<Control><Alt>t",
    ),
    f"{base_path}files/": ("Open Files", "nautilus", "<Super>e"),
    f"{base_path}browser/": (
        "Open Browser",
        "google-chrome-stable",
        "<Super>b",
    ),
    f"{base_path}code/": ("Open VS Code", "code", "<Super>c"),
    f"{base_path}task-manager/": (
        "Open System Monitor",
        "gnome-system-monitor",
        "<Control><Shift>Escape",
    ),
    f"{base_path}settings/": (
        "Open Settings",
        "gnome-control-center",
        "<Super>i",
    ),
    f"{base_path}custom0/": (
        "Flameshot Clipboard Snip",
        "flameshot gui --clipboard",
        "<Shift><Super>s",
    ),
}

raw_paths = get(media_schema, "custom-keybindings", "[]").replace("@as ", "")
try:
    existing_paths = ast.literal_eval(raw_paths)
except (SyntaxError, ValueError):
    existing_paths = []

if not isinstance(existing_paths, list):
    existing_paths = []

paths = [path for path in existing_paths if isinstance(path, str)]
for path in keybindings:
    if path not in paths:
        paths.append(path)

paths_value = "[" + ", ".join(variant_string(path) for path in paths) + "]"
run(
    "gsettings",
    "set",
    media_schema,
    "custom-keybindings",
    paths_value,
    check=True,
)

for path, (name, command, binding) in keybindings.items():
    schema = relocatable + path
    for key, value in (
        ("name", name),
        ("command", command),
        ("binding", binding),
    ):
        run(
            "gsettings",
            "set",
            schema,
            key,
            variant_string(value),
            check=True,
        )

application_dirs = (
    pathlib.Path.home() / ".local/share/applications",
    pathlib.Path("/usr/local/share/applications"),
    pathlib.Path("/usr/share/applications"),
)


def pick(*desktop_ids: str) -> str | None:
    for desktop_id in desktop_ids:
        if any((directory / desktop_id).is_file() for directory in application_dirs):
            return desktop_id
    return None


favorites = [
    pick("google-chrome.desktop", "google-chrome-stable.desktop"),
    pick("org.gnome.Nautilus.desktop", "nautilus.desktop"),
    pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop"),
    pick("code.desktop", "visual-studio-code.desktop"),
    pick("audacious.desktop"),
]
favorites = [item for item in favorites if item]

favorites_value = (
    "[" + ", ".join(variant_string(item) for item in favorites) + "]"
)
run(
    "gsettings",
    "set",
    "org.gnome.shell",
    "favorite-apps",
    favorites_value,
    check=True,
)
print(f"Dock favorites: {favorites_value}")
PY

# A settings import may contain Arch's enabled-extension list. Translate and
# enforce the Ubuntu extension state one final time.
bash "$SCRIPT_DIR/04-setup-extensions.sh" --enable-only

log "GNOME settings are applied."

