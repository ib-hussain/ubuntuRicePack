#!/bin/bash
# ==========================================================
# 00-common.sh — sourced by every other scripts/*.sh, never
# run directly. Provides logging + copy helpers and the
# per-package pacman installer (uses sudo — this whole
# scripts/ family is meant to run as the target user, not
# root, unlike wsl-install.sh itself).
# ==========================================================
# REPO_ROOT may already be exported by wsl-install.sh when
# it hands off via `su`. If run standalone, derive it.
: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_FILE="$REPO_ROOT/install.log"

log()  { echo "[INFO] $*"  | tee -a "$LOG_FILE"; }
warn() { echo "[WARN] $*"  | tee -a "$LOG_FILE"; }
fail() { echo "[ERROR] $*" | tee -a "$LOG_FILE"; exit 1; }
copy_dir_contents() {
    local src="$1"
    local dest="$2"
    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "$src"/. "$dest"/
        log "Copied $src -> $dest"
    else
        warn "Directory missing, skipped: $src"
    fi
}
copy_file() {
    local src="$1"
    local dest="$2"
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp -a "$src" "$dest"
        log "Copied $src -> $dest"
    else
        warn "File missing, skipped: $src"
    fi
}
install_pacman_package() {
    local pkg="$1"
    [[ -n "$pkg" ]] || return 0
    sudo pacman -S --needed --noconfirm "$pkg" || warn "pacman failed for package: $pkg"
}
# ==========================================================
# 01-install-packages.sh
# Installs packages/wsl-pacman.txt one at a time (so one bad
# package name warns and continues, instead of aborting).
# ==========================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${REPO_ROOT:=$(cd "$SCRIPT_DIR/.." && pwd)}"

log "Installing pacman packages from packages/wsl-pacman.txt"
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    install_pacman_package "$pkg"
done < "$REPO_ROOT/packages/wsl-pacman.txt"
# ==========================================================
# 02-restore-themes-and-configs.sh
# Restores dotfiles and ~/.local/bin, including the ff-blue
# fastfetch wrapper. (The old script wrote ff-blue here AND
# again in 03-setup-terminal.sh — consolidated to just here
# so there's one source of truth for it.)
# ==========================================================
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/icons"
copy_dir_contents "$REPO_ROOT/configs/local-bin" "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
if [[ -f "$REPO_ROOT/configs/.bashrc" ]]; then
    copy_file "$REPO_ROOT/configs/.bashrc" "$HOME/.bashrc"
    copy_file "$REPO_ROOT/configs/.bash_profile" "$HOME/.bash_profile"
fi
# ff-blue: force fastfetch to render the Arch logo in blue.
# Only written if configs/local-bin didn't already provide
# one via the copy above.
if [[ ! -f "$HOME/.local/bin/ff-blue" ]]; then
    cat > "$HOME/.local/bin/ff-blue" <<'EOFF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOFF
    chmod +x "$HOME/.local/bin/ff-blue"
    log "Created default ff-blue wrapper (none found in configs/local-bin)"
else
    log "ff-blue already restored from configs/local-bin"
fi
# ==========================================================
# 03-setup-terminal.sh
# Restores fastfetch's own config, then sanity-checks .bashrc.
# ff-blue itself now lives entirely in 02 — not duplicated here.
# ==========================================================
log "Restoring fastfetch config"
mkdir -p "$HOME/.config/fastfetch"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"

bash -n "$HOME/.bashrc" || warn "configs/.bashrc has a syntax error — check it before relying on it"

if ! grep -q 'pyenv init' "$HOME/.bashrc" 2>/dev/null; then
    warn "configs/.bashrc doesn't call 'pyenv init' — add these three lines so pyenv works in normal interactive shells:"
    warn '  export PYENV_ROOT="$HOME/.pyenv"'
    warn '  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
    warn '  eval "$(pyenv init -)"'
fi
# ==========================================================
# 10-setup-local-ai-ollama-openwebui.sh
# NOT run automatically by wsl-install.sh — this needs a
# live systemd PID 1 to enable/start services against, which
# only exists after `wsl --shutdown` + relaunch with
# systemd=true active. Run it manually, as ibrahim, once
# that's confirmed (`systemctl status` should show systemd,
# not `bash` or `init`, as PID 1):
# ==========================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${REPO_ROOT:=$(cd "$SCRIPT_DIR/.." && pwd)}"

# Wrapped in if/else rather than a hard `fail` — this section
# now lives inline in the middle of the single first-pass
# script, not as its own standalone file run later. A hard
# `exit` here would abort 06-wsl.sh entirely and skip
# everything below it (git identity), since set -euo pipefail
# is active. Skipping gracefully instead means: no systemd yet
# -> warn and move on to git config; re-run this whole script
# after the restart to pick Ollama back up.
if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
    warn "systemd is not PID 1 yet (got '$(ps -p 1 -o comm=)') — skipping Ollama/Open WebUI setup for now."
    warn "Run 'wsl --shutdown' + relaunch, then re-run this script to pick it up."
else
    log "Ensuring ollama is installed"
    install_pacman_package ollama
    log "Configuring Ollama to listen on 0.0.0.0 so Open WebUI (or a Windows-side client) can reach it"
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf <<'EOF' >/dev/null
[Service]
Environment=OLLAMA_HOST=0.0.0.0:11434
EOF
    sudo systemctl daemon-reload
    if sudo systemctl enable --now ollama.service; then
        sudo systemctl try-restart ollama.service 2>/dev/null || true
        log "Waiting for Ollama API to come up"
        for i in {1..30}; do
            if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
                log "Ollama API is reachable."
                break
            fi
            sleep 1
        done
        if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
            log "Pulling gemma3:1b"
            ollama pull gemma3:1b || warn "Could not pull gemma3:1b. Retry later with: ollama pull gemma3:1b"
            log "Pulling qwen2.5-coder:3b"
            ollama pull qwen2.5-coder:3b || warn "Could not pull qwen2.5-coder:3b. Retry later with: ollama pull qwen2.5-coder:3b"
        else
            warn "Ollama API never became reachable — skipping model pulls. Check: sudo systemctl status ollama"
        fi

        # ------------------------------------------------------
        # Open WebUI — installed as a user-level pip package.
        # An ow-serve wrapper (created below) pins the port so
        # it's defined in exactly one place, and is what the
        # Windows-side launchers call (C:\Scripts\
        # start_ollama_webui_hidden.vbs, C:\Scripts\
        # OpenLocalModel.bat — both updated to run
        # `~/.local/bin/ow-serve` instead of the raw command).
        #
        # Heads up: this pulls a genuinely large dependency set
        # (it's a full web app, not a thin client) — expect
        # several hundred MB on first install.
        # ------------------------------------------------------
        log "Installing Open WebUI"
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

        # /tmp is tmpfs (RAM-backed, ~half of WSL's memory — often
        # only a few GB) not disk-backed. pip stages wheel downloads
        # there by default via Python's tempfile module, and a large
        # dependency chain can exhaust it even though the real disk
        # has hundreds of GB free. Redirect to the actual filesystem.
        mkdir -p "$HOME/.cache/pip-tmp"
        export TMPDIR="$HOME/.cache/pip-tmp"

        # Open WebUI pulls in sentence-transformers -> torch as a
        # dependency for its built-in RAG/embeddings support. Left
        # to its own resolver, pip grabs the CUDA build by default
        # on Linux — several GB of nvidia-* packages that do
        # nothing on a machine with no GPU. Installing CPU-only
        # torch first means the resolver sees it already satisfied
        # and skips the CUDA stack entirely.
        log "Pre-installing CPU-only torch so Open WebUI doesn't pull the CUDA stack"
        pip install --user torch --index-url https://download.pytorch.org/whl/cpu || warn "CPU-only torch pre-install failed — continuing, but open-webui may pull CUDA torch instead"

        if pip install --user --upgrade open-webui; then
            # Single source of truth for the port — the Windows
            # launchers call THIS instead of `open-webui serve`
            # directly, so the port only needs to change here.
            # Port 1025 instead of the 8080 default: XAMPP's
            # Apache already owns 8080 on this machine, and
            # whichever service binds first wins the port while
            # the other's requests silently go to the wrong app.
            cat > "$HOME/.local/bin/ow-serve" <<'EOFW'
#!/usr/bin/env bash
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$HOME/.local/bin:$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
exec open-webui serve --port 1025 "$@"
EOFW
            chmod +x "$HOME/.local/bin/ow-serve"

            log "Ollama + Open WebUI setup complete."
            log "Start with your existing launcher, or manually:"
            log "  ollama serve &"
            log "  ~/.local/bin/ow-serve"
            log "Then from Windows: http://localhost:1025"
        else
            warn "open-webui install failed — Ollama itself is still set up and running."
        fi
    else
        warn "Could not enable/start ollama.service — skipping model pulls and Open WebUI."
    fi
fi

# ==========================================================
# 14-system-stability.sh
# Git identity — unchanged from your original.
# ==========================================================
log "Setting git identity"
git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor "nano"
git config --global push.default simple
