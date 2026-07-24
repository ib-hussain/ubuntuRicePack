#!/usr/bin/env bash
# Independent optional installer for Ollama + Open WebUI.
# It is intentionally NOT called by install-rice.sh.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ubuntu-rice-pack"
mkdir -p "$STATE_DIR"
LOG_FILE="${LOG_FILE:-$STATE_DIR/local-ai-$(date +%Y%m%d-%H%M%S).log}"

log() {
    printf '[INFO] %s\n' "$*" | tee -a "$LOG_FILE"
}

warn() {
    printf '[WARN] %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

fail() {
    printf '[ERROR] %s\n' "$*" | tee -a "$LOG_FILE" >&2
    exit 1
}

is_wsl() {
    [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]] ||
        grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

require_supported_host() {
    [[ "$EUID" -ne 0 ]] ||
        fail "Run this as your normal user, without sudo."
    [[ -r /etc/os-release ]] ||
        fail "Cannot identify this distribution."

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* &&
            "${ID_LIKE:-}" != *debian* ]]; then
        fail "This installer supports Ubuntu and Ubuntu-based WSL only."
    fi

    command -v apt-get >/dev/null 2>&1 || fail "apt-get is required."
}

ensure_wsl_systemd_setting() {
    is_wsl || return 0

    sudo python3 - <<PY
from pathlib import Path
import configparser

path = Path("/etc/wsl.conf")
config = configparser.ConfigParser()
config.optionxform = str
if path.exists():
    config.read(path)
if not config.has_section("boot"):
    config.add_section("boot")
config.set("boot", "systemd", "true")
if not config.has_section("user"):
    config.add_section("user")
config.set("user", "default", "${USER}")
with path.open("w", encoding="utf-8") as handle:
    config.write(handle, space_around_delimiters=False)
PY
}

wait_for_url() {
    local url="$1"
    local attempts="${2:-90}"
    local attempt=""

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

require_supported_host
ensure_wsl_systemd_setting

if [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" != "systemd" ]]; then
    if is_wsl; then
        fail "WSL systemd has been configured. Run 'wsl --shutdown' in PowerShell, reopen Ubuntu, and rerun this script."
    fi
    fail "systemd must be running before Ollama and Docker can be configured."
fi

log "Installing Local AI prerequisites."
sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl docker.io openssl xdg-utils
sudo systemctl enable --now docker.service

if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER"
fi

if ! command -v ollama >/dev/null 2>&1; then
    log "Installing Ollama from its official Linux installer."
    ollama_installer="$(
        mktemp "${TMPDIR:-/tmp}/ollama-install.XXXXXX"
    )"
    curl -fsSL https://ollama.com/install.sh -o "$ollama_installer"
    sh "$ollama_installer"
    rm -f -- "$ollama_installer"
else
    log "Ollama is already installed."
fi

log "Writing the Ollama systemd configuration."
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf \
    >/dev/null <<'OLLAMA_SERVICE'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
OLLAMA_SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service
sudo systemctl restart ollama.service

log "Waiting for the Ollama API."
wait_for_url http://127.0.0.1:11434/api/tags 60 ||
    fail "Ollama did not become reachable. Check: journalctl -u ollama -e"

# Only these two models are installed. Override the tags without editing the
# script by setting OLLAMA_MODEL_1 and/or OLLAMA_MODEL_2.
OLLAMA_MODEL_1="${OLLAMA_MODEL_1:-gemma3:1b}"
OLLAMA_MODEL_2="${OLLAMA_MODEL_2:-deepseek-r1}"
for model_name in "$OLLAMA_MODEL_1" "$OLLAMA_MODEL_2"; do
    log "Pulling Ollama model: $model_name"
    ollama pull "$model_name"
done

OPENWEBUI_PORT="${OPENWEBUI_PORT:-3000}"
[[ "$OPENWEBUI_PORT" =~ ^[0-9]+$ ]] &&
    ((OPENWEBUI_PORT >= 1024 && OPENWEBUI_PORT <= 65535)) ||
    fail "OPENWEBUI_PORT must be between 1024 and 65535."

OPENWEBUI_IMAGE="${OPENWEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
OPENWEBUI_CONFIG_DIR="$HOME/.config/ubuntuRicePack"
OPENWEBUI_ENV="$OPENWEBUI_CONFIG_DIR/openwebui.env"
mkdir -p "$OPENWEBUI_CONFIG_DIR"

if [[ -f "$OPENWEBUI_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$OPENWEBUI_ENV"
fi
WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)}"

umask 077
tee "$OPENWEBUI_ENV" >/dev/null <<OPENWEBUI_CONFIG
OLLAMA_BASE_URL=http://127.0.0.1:11434
PORT=$OPENWEBUI_PORT
WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY
OPENWEBUI_CONFIG
chmod 0600 "$OPENWEBUI_ENV"
umask 022

log "Installing the Open WebUI container while preserving its data volume."
sudo docker pull "$OPENWEBUI_IMAGE"
if sudo docker container inspect open-webui >/dev/null 2>&1; then
    sudo docker rm -f open-webui
fi

# Host networking lets Open WebUI reach local-only Ollama without exposing the
# Ollama API on every network interface.
sudo docker run -d \
    --name open-webui \
    --restart unless-stopped \
    --network host \
    --env-file "$OPENWEBUI_ENV" \
    -v open-webui:/app/backend/data \
    "$OPENWEBUI_IMAGE"

wait_for_url "http://127.0.0.1:$OPENWEBUI_PORT/health" 120 ||
    fail "Open WebUI did not become healthy. Check: sudo docker logs open-webui"

create_openwebui_launcher() {
    local application_dir="$HOME/.local/share/applications"
    local icon_dir="$HOME/.local/share/icons/hicolor/scalable/apps"
    local desktop_dir=""
    local icon_name="applications-internet"
    local icon_source=""
    local desktop_file="$application_dir/openwebui.desktop"

    mkdir -p "$HOME/.local/bin" "$application_dir" "$icon_dir"

    for candidate in \
        "$REPO_ROOT/assets/arch-icons/open-webui.svg" \
        "$REPO_ROOT/assets/open-webui.svg" \
        "$REPO_ROOT/assets/openwebui.svg"
    do
        if [[ -f "$candidate" ]]; then
            icon_source="$candidate"
            break
        fi
    done

    if [[ -n "$icon_source" ]]; then
        install -Dm644 "$icon_source" "$icon_dir/openwebui.svg"
        icon_name="openwebui"
    fi

    tee "$HOME/.local/bin/openwebui-launcher" >/dev/null <<LAUNCHER
#!/usr/bin/env bash
set -Eeuo pipefail
url="http://127.0.0.1:$OPENWEBUI_PORT"
if command -v google-chrome-stable >/dev/null 2>&1; then
    exec google-chrome-stable --app="\$url" --class=OpenWebUI
fi
exec xdg-open "\$url"
LAUNCHER
    chmod 0755 "$HOME/.local/bin/openwebui-launcher"

    tee "$desktop_file" >/dev/null <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Open WebUI
Comment=Local AI chat interface powered by Ollama
Exec=$HOME/.local/bin/openwebui-launcher
Icon=$icon_name
Terminal=false
Categories=Development;Utility;Network;
StartupNotify=true
DESKTOP
    chmod 0755 "$desktop_file"

    if ! is_wsl; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        desktop_dir="${desktop_dir:-$HOME/Desktop}"
        mkdir -p "$desktop_dir"
        cp -a "$desktop_file" "$desktop_dir/openwebui.desktop"
        chmod 0755 "$desktop_dir/openwebui.desktop"
        gio set "$desktop_dir/openwebui.desktop" metadata::trusted true \
            >/dev/null 2>&1 || true
    fi

    update-desktop-database "$application_dir" >/dev/null 2>&1 || true
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" \
        >/dev/null 2>&1 || true
}

create_openwebui_launcher

log "Local AI setup is complete."
log "Models: $OLLAMA_MODEL_1, $OLLAMA_MODEL_2"
log "Open WebUI: http://127.0.0.1:$OPENWEBUI_PORT"
log "Docker group membership becomes available after your next login."

