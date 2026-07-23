#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying GNOME, dock, theme, and keybinding settings."

# Load all dconf configuration 
if [[ -f "$REPO_ROOT/configs/dconf/dconf-complete.ini" ]]; then
    dconf load / < "$REPO_ROOT/configs/dconf/dconf-complete.ini" || true
fi

# gsettings set org.gnome.shell.debug enable-debugging true 2>/dev/null || echo "schema not available, trying alternate method"
# Apply core settings with gs_set for permanence
# log "Applying core gsettings with permanence..."


python - <<'PY'
from pathlib import Path
import ast
import subprocess

def run(cmd, check=False):
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)

def out(cmd, default=""):
    r = run(cmd)
    return r.stdout.strip() if r.returncode == 0 else default

def gv(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

media = "org.gnome.settings-daemon.plugins.media-keys"
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
prefix = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"

raw = out(["gsettings", "get", media, "custom-keybindings"], "[]").replace("@as ", "")
try:
    paths = ast.literal_eval(raw)
    if not isinstance(paths, list):
        paths = []
except Exception:
    paths = []

clean = []
for path in paths:
    schema = prefix + path
    binding = out(["gsettings", "get", schema, "binding"], "''").strip("'").strip('"')
    command = out(["gsettings", "get", schema, "command"], "''").strip("'").strip('"').lower()
    bad = binding in {"<Super>", "Super", "Super_L", "<Super_L>"} or ("gnome-control-center" in command and "super" in binding.lower())
    if not bad:
        clean.append(path)

entries = {
    base + "code/": ("Open VS Code", "code", "<Super>c"),
    base + "files/": ("Open Files", "nautilus", "<Super>e"),
    base + "settings/": ("Open Settings", "gnome-control-center", "<Super>i"),
    base + "terminal/": ("Open Terminal", "gnome-terminal", "<Control><Alt>t"),
    base + "task-manager/": ("Open System Monitor", "gnome-system-monitor", "<Control><Shift>Escape"),
}

for path in entries:
    if path not in clean:
        clean.append(path)

value = "[" + ", ".join("'" + p + "'" for p in clean) + "]"
run(["gsettings", "set", media, "custom-keybindings", value], check=True)

for path, (name, command, binding) in entries.items():
    schema = prefix + path
    run(["gsettings", "set", schema, "name", gv(name)], check=True)
    run(["gsettings", "set", schema, "command", gv(command)], check=True)
    run(["gsettings", "set", schema, "binding", gv(binding)], check=True)

dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]

def exists(name):
    return any((d / name).exists() for d in dirs)

def pick(*names):
    for name in names:
        if exists(name):
            return name
    return None

apps = [
    pick("org.gnome.Nautilus.desktop", "nautilus.desktop"),
    pick("code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop"),
    pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop"),
    pick("google-chrome.desktop", "google-chrome-stable.desktop", "firefox.desktop"),
]

apps = [x for x in apps if x]
fav = "[" + ", ".join("'" + x + "'" for x in apps) + "]"
run(["gsettings", "set", "org.gnome.shell", "favorite-apps", fav], check=True)

# Set app-picker-layout from dconf-complete
picker_layout = "[{'ib-arch-menu.desktop': <{'position': <0>}>, 'blueman-manager.desktop': <{'position': <1>}>, 'ca.desrt.dconf-editor.desktop': <{'position': <2>}>, 'com.mattjakeman.ExtensionManager.desktop': <{'position': <3>}>, 'org.flameshot.Flameshot.desktop': <{'position': <4>}>, 'htop.desktop': <{'position': <5>}>, 'ib-power-modes.desktop': <{'position': <6>}>, 'org.gnome.Screenshot.desktop': <{'position': <7>}>, 'btop.desktop': <{'position': <8>}>, 'org.pulseaudio.pavucontrol.desktop': <{'position': <9>}>, 'System': <{'position': <10>}>, 'conky.desktop': <{'position': <11>}>, 'org.gnome.Settings.desktop': <{'position': <12>}>, 'org.gnome.SystemMonitor.desktop': <{'position': <13>}>, 'firefox.desktop': <{'position': <14>}>, 'audacious.desktop': <{'position': <15>}>}]"
run(["gsettings", "set", "org.gnome.shell", "app-picker-layout", picker_layout], check=True)

print(fav)
PY
