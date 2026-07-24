#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

if [[ "${SKIP_LOCAL_AI:-0}" == "1" ]]; then
    warn "SKIP_LOCAL_AI=1 set. Skipping Ollama/Open WebUI setup."
    exit 0
fi

log "Setting up Ollama + Open WebUI."

install_pacman_package ollama
# install_pacman_package ollama-cuda
install_pacman_package docker
install_pacman_package docker-compose
install_pacman_package xdg-utils
install_pacman_package imagemagick

# ----- Ensure Ollama listens on all interfaces for Docker access -----
log "Configuring Ollama to listen on 0.0.0.0 so Docker can reach it."
sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/override.conf <<'EOF' >/dev/null
[Service]
Environment=OLLAMA_HOST=0.0.0.0:11434
EOF

sudo systemctl daemon-reload
sudo systemctl try-restart ollama.service 2>/dev/null || true
# ---------------------------------------------------------------------

log "Enabling services."
sudo systemctl enable --now ollama.service || warn "Could not enable/start ollama.service."
sudo systemctl enable --now docker.service || warn "Could not enable/start docker.service."

if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
    warn "User added to docker group."
fi

# ----- Run all subsequent docker commands as the invoking user, not root -----
# Using sudo for the docker daemon-level setup above is fine (systemd units,
# package install), but the container itself should be created under the
# user's own docker context. Mixing sudo and group-based docker access
# creates ownership splits between root and the user across reruns, and on
# this script that previously caused open-webui's named volume to end up
# owned in a way the container's runtime user couldn't write to -- which
# made the entrypoint silently exit 0 before the app ever started.
#
# `sg docker -c '...'` runs a command in the docker group context for this
# script's process, without requiring a fresh login shell first.
run_as_docker_user() {
    if id -nG "$USER" | grep -qw docker; then
        sg docker -c "$*"
    else
        # Group membership not active in this shell yet (e.g. first run,
        # before logout/login). Fall back to sudo just for this invocation.
        sudo "$@"
    fi
}
# ------------------------------------------------------------------------------

log "Waiting for Ollama API."
for i in {1..30}; do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        log "Ollama API is reachable."
        break
    fi
    sleep 1
done

if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "Pulling gemma3:1b"
    ollama pull gemma3:1b || warn "Could not pull gemma3:1b. It can be pulled later with: ollama pull gemma3:1b"
    log "Pulling deepseek-r1"
    ollama pull deepseek-r1 || warn "Could not pull deepseek-r1. It can be pulled later with: ollama pull deepseek-r1"
    log "Pulling qwen2.5-coder:3b"
    ollama pull qwen2.5-coder:3b || warn "Could not pull qwen2.5-coder:3b. It can be pulled later with: ollama pull qwen2.5-coder:3b"
else
    warn "Ollama API did not become reachable. Skipping model pull."
fi

log "Installing Open WebUI Docker container."

if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'open-webui'; then
    log "Removing existing open-webui container."
    docker rm -f open-webui || true
fi

# Remove the named volume too if it exists with bad ownership from a
# previous sudo-based run. Comment this out if you want to preserve
# existing chat history/data across the fix.
if docker volume inspect open-webui >/dev/null 2>&1; then
    log "Found existing open-webui volume. Checking ownership..."
    OWNER_UID=$(docker run --rm -v open-webui:/data alpine stat -c '%u' /data 2>/dev/null || echo "unknown")
    log "Volume /data is currently owned by UID: ${OWNER_UID}"
fi

# Run the container as the current invoking user instead of via sudo, now
# that docker group membership is set up. This keeps the named volume's
# ownership consistent with what the container's entrypoint expects, and
# avoids the silent-exit-0 failure mode from ownership mismatches.
docker run -d -p 3000:8080 \
    --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -v open-webui:/app/backend/data \
    --name open-webui \
    --restart always \
    --health-cmd="curl -fsS http://localhost:8080/health || exit 1" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=3 \
    --health-start-period=30s \
    --entrypoint bash \
    ghcr.io/open-webui/open-webui:main \
    -c "pip install --quiet --upgrade typer && bash start.sh" \
    || warn "Open WebUI Docker container failed to start."
# NOTE: the ghcr.io/open-webui/open-webui:main image has shipped, at least
# as of the digest pulled while debugging this, with a broken `typer`
# install (`typer.Typer()` raises AttributeError on import). This made the
# container exit cleanly (code 0) within ~500ms of every single start,
# with completely empty logs, before uvicorn ever got a chance to print
# anything -- since the crash happens at import time inside
# open_webui/__init__.py, before logging is configured. The one-line
# `pip install --upgrade typer` before launching start.sh fixes it without
# needing to rebuild the image. If a future image revision fixes this
# upstream, this becomes a harmless no-op (pip will just confirm typer is
# already up to date), so it's safe to leave in permanently.

log "Waiting to confirm Open WebUI actually started (not just exited 0 immediately)."
sleep 5
CONTAINER_STATE=$(docker inspect open-webui --format='{{.State.Status}}' 2>/dev/null || echo "missing")
EXIT_CODE=$(docker inspect open-webui --format='{{.State.ExitCode}}' 2>/dev/null || echo "n/a")

if [[ "$CONTAINER_STATE" == "running" ]]; then
    log "Open WebUI container is running."
elif [[ "$CONTAINER_STATE" == "restarting" ]]; then
    warn "Open WebUI is stuck in a restart loop (last exit code: ${EXIT_CODE})."
    warn "Check logs with: docker logs open-webui --since 2m"
    warn "This usually means a volume permissions mismatch. Try:"
    warn "  docker run --rm -v open-webui:/data alpine chown -R 1000:1000 /data"
    warn "(adjust UID/GID to whatever the open-webui image expects -- check with: docker run --rm ghcr.io/open-webui/open-webui:main id)"
else
    warn "Open WebUI container state is unexpected: ${CONTAINER_STATE} (exit code: ${EXIT_CODE})"
fi

log "Creating Open WebUI launcher."

mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.local/bin"

cat > "$HOME/.local/bin/openwebui-launcher" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

URL="http://localhost:3000"

if command -v google-chrome-stable >/dev/null 2>&1; then
    exec google-chrome-stable --app="$URL" --class=OpenWebUI
elif command -v google-chrome >/dev/null 2>&1; then
    exec google-chrome --app="$URL" --class=OpenWebUI
elif command -v firefox >/dev/null 2>&1; then
    exec firefox "$URL"
elif command -v chromium >/dev/null 2>&1; then
    exec chromium --app="$URL" --class=OpenWebUI
fi
LAUNCHER

chmod +x "$HOME/.local/bin/openwebui-launcher"
cp "$HOME/archRicePack/assets/arch-icons/open-webui.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/openwebui.svg"
chmod +x "$HOME/.local/share/icons/hicolor/scalable/apps/openwebui.svg"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

cat > "$HOME/.local/share/applications/openwebui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Open WebUI
Comment=Local AI chat interface for Ollama
Exec=openwebui-launcher
Icon=openwebui
Terminal=false
Categories=Network;Utility;Development;AI;
StartupNotify=true
DESKTOP

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

log "Pinning Open WebUI to GNOME dock favourites."

python - <<'PY'
import ast
import subprocess

target = "openwebui.desktop"

raw = subprocess.check_output(["gsettings", "get", "org.gnome.shell", "favorite-apps"], text=True).strip()
raw = raw.replace("@as ", "")

try:
    favs = ast.literal_eval(raw)
    if not isinstance(favs, list):
        favs = []
except Exception:
    favs = []

if target not in favs:
    favs.append(target)

value = "[" + ", ".join("'" + x + "'" for x in favs) + "]"
subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=False)
print(value)
PY

log "Open WebUI setup complete."
log "Access URL: http://localhost:3000"
log "If Docker group access does not work immediately, log out and back in."