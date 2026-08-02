# UbuntuRicePack

Ibrahim Hussain's reproducible Ubuntu desktop configuration for Ubuntu 25.04
(GNOME 48) and Ubuntu 26.04 (GNOME 50), with cross-distribution Rice Dock and
Rice Top Bar extensions that also run on Arch GNOME 48/50.

Ubuntu 25.04 reached end of life. The installer can use Ubuntu's official
old-releases archive so Plucky remains installable, but that cannot restore
security updates. Ubuntu 26.04 is the recommended profile.

## Quick start

For a new Ubuntu Desktop installation with interactive network and storage:

```bash
bash installation/prepare-autoinstall.sh
bash tests/validate-autoinstall.sh installation/autoinstall-ready.yaml
```

Import the resulting private YAML through Ubuntu Desktop's Automated
Installation page. OpenSSH Server is installed and enabled automatically.

For an already installed system:

```bash
bash tests/validate-rice-product.sh
bash ./install-rice.sh -m desktop
```

Run as the normal logged-in GNOME user. Log out and back in when installation
finishes.

To install only the two custom extensions on Ubuntu or Arch:

```bash
bash scripts/install-rice-shell-extensions.sh
```

To diagnose the native password stack and set a short local password through
the privileged system prompt:

```bash
bash scripts/09-set-local-password.sh
```

If the current PAM stack produces duplicate current-password prompts or an
authentication-token error, use the explicit backed-up repair path:

```bash
bash scripts/09-set-local-password.sh --repair-pam
```

Ollama/Open WebUI remains optional:

```bash
bash scripts/10-setup-local-ai-ollama-openwebui.sh
```

See [APPLY-INSTRUCTIONS.md](installation/APPLY-INSTRUCTIONS.md) for operating instructions
and [ENGINEERING-AUDIT.md](tests/ENGINEERING-AUDIT.md) for the supplied-extension
analysis, root causes, provenance, conflict policy, and validation record.
