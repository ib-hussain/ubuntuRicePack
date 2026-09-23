# AGENTS.md — Linux, WSL, Ubuntu and GNOME Automation

## Scope

Use this profile for Ibrahim Hussain's `archRicePack`, `ubuntuRicePack`, GNOME extensions, dock styling, WSL setup, Bash configuration, VS Code, local AI tooling, themes, and post-install automation.

## Platform decisions

- Ubuntu automation is post-install only. Do not partition, format disks, run `arch-chroot`, or alter installer-owned storage.
- Do not add Snap or Snap-installed Firefox. Prefer packages available from official Ubuntu sources or the explicitly approved upstream source.
- Do not apply Arch-only assumptions to Ubuntu. Ubuntu uses Ubuntu Dock; Arch may use Dash to Dock.
- Keep local-AI setup independent from desktop theming so either can be installed or repaired alone.
- Support the repository's stated Ubuntu versions, including guarded compatibility for 25.04 and 26.04 where requested. Detect the release instead of assuming it.
- Separate native Linux, Ubuntu, and WSL paths. WSL-specific changes must not leak into native desktop stages.

## Installer architecture

- Use a small orchestrator plus numbered stage scripts and shared helpers.
- Missing required scripts are fatal and clearly reported.
- Separate user-session changes from root-required operations. Do not run the whole installer as root.
- Make stages idempotent: rerunning should converge, not duplicate entries or corrupt state.
- Cache downloads and reusable assets across reruns, with integrity/version validation.
- Back up user configuration before replacement and print a usable rollback command.
- Store logs, reports, backups, and state beneath an explicit per-user state directory.
- Detect unsupported keys/packages/extensions and report them; do not turn optional absence into an unexplained hard failure.

## Shell reliability

- Use strict Bash deliberately and understand `set -euo pipefail` failure modes.
- Avoid early-closing pipelines such as `producer | grep -q` under `pipefail`; capture output or use a construct that does not turn SIGPIPE into a false failure.
- Quote every path and variable expansion unless word splitting is explicitly intended.
- Do not reuse reserved/common environment variables for task-specific state.
- Make root helpers preserve the target user's home and ownership.
- Validate files before installing them, and use temporary files plus atomic moves for replacements.

## GNOME and visual configuration

- Preserve the curated GNOME behaviour, shortcuts, app folders, Dconf settings, Bash/Fastfetch styling, Noto/Nerd Fonts, VS Code data, wallpapers, GTK configuration, Nautilus integration, power menu, and extension state.
- Verify schemas and keys exist before applying `gsettings`/Dconf values.
- Treat GNOME version and extension compatibility as runtime facts. Record unavailable/unsupported settings separately from real failures.
- Keep extension installation, extension state, extension configuration, and final verification distinct.
- Log out/in requirements explicitly; do not claim live Shell state changed when a session restart is required.
- Do not modify GDM branding or logos unless explicitly requested for the current project.

## Dock rules

- For the arch-style Ubuntu Dock work, replace the prior dock styling as a coherent whole.
- Top-panel changes are out of scope unless explicitly requested.
- Preserve running-app indicators as dots.
- Keep roundness dynamic.
- Couple hover spacing with magnification so icons do not collide.
- Discrete enter/leave magnification is acceptable where continuous tracking is not supported.
- Do not depend on unsupported `backdrop-filter` behaviour.
- Maintain both development mock-up fidelity and production GNOME Shell compatibility.

## Verification

- Run `bash -n` for every changed shell script and `shellcheck` when available.
- Test user and root paths separately.
- Verify OS detection, package availability, idempotent reruns, backups, ownership, installed files, Dconf keys, extension state, and generated reports.
- Inspect journal logs for GNOME extension failures.
- Where full desktop behaviour cannot be exercised in the current environment, say so and provide precise on-machine verification commands.
- Produce replacement-only ZIPs when requested and inspect their directory layout before delivery.

## Distribution and session matrix

Never treat “Linux” as one environment. Resolve at least:

| Dimension | Examples/impact |
| --- | --- |
| Distribution | Ubuntu package names/sources differ from Arch/pacman/AUR. |
| Release | Ubuntu 25.04/GNOME 48 and 26.04/GNOME 50 may expose different packages, schemas, and extension APIs. |
| Session | GNOME Wayland/Xorg, headless shell, first-login bootstrap, or no graphical session. |
| Host | Native desktop versus WSL. |
| User context | Interactive user, target user under sudo, or root-only system operation. |
| Installation phase | Post-install rice, autoinstall/cloud-init, repair, or state-only reapplication. |

Record the detected branch in logs and verification reports. Do not run desktop/session operations as root or inside WSL merely because package installation succeeded.

## Canonical staged-installer design

The established design uses a small `install-rice.sh` orchestrator, numbered scripts, and shared helpers. A representative order is:

1. common checks, sudo readiness, locale/hostname, and WSL detection;
2. package sources and packages;
3. repository-owned/user configs and themes;
4. terminal/Bash/Fastfetch;
5. optional pyenv/development tooling;
6. desktop assets and launchers;
7. GNOME extensions;
8. GNOME/Dconf settings;
9. VS Code/user application restoration;
10. finalisation and audit;
11. optional local-AI stage kept independent.

Use the repository's actual stage numbers. Do not renumber or consolidate blindly when user instructions, repair commands, and reports depend on them.

Every required stage should have:

- `--help` or discoverable usage where appropriate;
- precondition checks;
- idempotent actions;
- explicit required/optional classification;
- structured logging;
- a verification phase;
- useful exit status;
- rerun/recovery instructions.

## Privilege boundary

- The orchestrator runs as the target user.
- Root operations are narrow functions/commands, not an entire root-owned run.
- Resolve target user/home before elevation and never substitute root's home.
- Restore ownership for user files created through privileged operations.
- Do not pass untrusted strings into a root shell.
- `run_root()` must preserve arguments exactly, report the executed stage safely, propagate the real exit status, and avoid quoting that collapses an argument vector into an unintended command string.

When `run_root()` is broken, write a focused regression/smoke test around spaces, empty values where supported, and failure propagation.

## Backups and rollback

Before replacing a user configuration:

1. Resolve the exact target.
2. Create a timestamped backup under the project's state/backups directory.
3. Preserve permissions/ownership where relevant.
4. Validate the new content before promotion.
5. Print a concrete rollback command.
6. Do not overwrite a known-good original backup on subsequent runs.

For Dconf, export the affected subtree or full selected snapshot before import. For PAM or other security-sensitive system configuration, validate syntax and keep a recovery route before activation.

## Package-source discipline

- Honour the no-Snap/no-Firefox requirement in UbuntuRicePack.
- Prefer official Ubuntu repositories for ordinary packages.
- For approved upstream repositories, verify release support, signing key handling, and idempotent source configuration.
- Detect renamed, removed, transitional, or release-specific packages.
- Do not enable an unsupported repository merely to make `apt` find a package.
- Record which packages were installed, already present, unavailable, optional, or failed.
- In normal mode, allow documented non-critical gaps to continue; in `--strict`, elevate the project's declared mismatches to failure.

## Asset and download policy

- Avoid duplicating large unchanged wallpaper/theme assets across repositories when the agreed design fetches them from an authoritative pinned URL.
- Cache downloads across reruns.
- Validate checksum/version/content before use.
- Do not trust an HTML error page saved with an archive extension.
- Extract into a temporary location and validate expected structure.
- Install through atomic replacement or a staged copy.
- Keep third-party attribution and licences.

## GNOME settings methodology

### Applying settings

- Detect whether schemas/keys exist before `gsettings` operations.
- Distinguish a missing schema, missing key, rejected value, locked-down setting, and command failure.
- Apply only settings relevant to the detected GNOME/distribution branch.
- Preserve unavailable settings as reported skips rather than deleting them from the desired-state definition.
- Keep a count/report of changed/planned, already matching, unsupported/unavailable, and rejected/failed settings.

### Extension lifecycle

Treat these as separate phases:

1. inventory and provenance;
2. download/install/version validation;
3. enable/disable desired state;
4. extension-specific settings;
5. Shell-session reload;
6. runtime verification/journal inspection.

Repository-owned extensions are updated from repository source. Unmodified third-party extensions should come from Ubuntu packages or GNOME Extensions, not be bundled gratuitously.

### Verification boundary

A headless script can validate metadata, JavaScript syntax, schemas, CSS/Sass, files, and configured state. It cannot prove visual/runtime behaviour in Ibrahim's live GNOME session. Mark that boundary and provide on-target checks.

## Desktop launchers and icons

- Validate `.desktop` syntax and executable paths.
- Preserve the curated desktop icon set where the project defines one, historically including Chrome, VS Code, Nautilus, terminal, Audacious, Open WebUI, and Trash.
- Refresh the desktop/application database after installation.
- Ensure launchers are user-owned and trusted/visible as required by the desktop implementation.
- Avoid hard-coded paths to applications not installed by the selected profile.

## VS Code repair standard

When `code .` returns immediately without a window:

1. Resolve which `code` executable/shim is invoked.
2. Capture `code --verbose`/diagnostic output and process state.
3. Inspect relevant user journal/logs and extension-host errors.
4. Test a clean temporary user-data directory and extensions-disabled launch.
5. Distinguish a corrupt profile/cache from a broken package/launcher/display session.
6. Back up the existing profile before rebuilding only the corrupt state.
7. Preserve settings, keybindings, snippets, and explicitly required extensions where possible.
8. Verify both launching from terminal and opening a folder.

Do not repeatedly reinstall VS Code without first distinguishing package failure from profile/session failure.

## WSL rules

- Keep WSL configuration in its own guarded branch.
- Configure `/etc/wsl.conf` deliberately for systemd, default user, and optional hostname.
- Update `/etc/hosts` only through a bounded idempotent rule.
- Do not attempt GNOME desktop extension operations in a WSL-only profile.
- After WSL configuration changes, instruct Ibrahim to run `wsl --shutdown` from Windows PowerShell.
- Resource tuning in `.wslconfig` is a Windows-host concern; validate RAM/swap impact before large model prewarming.

## Autoinstall boundary

For the Ubuntu custom installation YAML work:

- storage remains interactive; never embed a destructive/preselected disk recipe;
- network remains interactive where agreed;
- SSH server is enabled according to the approved policy;
- root SSH remains disabled;
- password login follows the agreed installation requirements;
- the rice repository is fetched at a pinned verified commit;
- the visible first-login bootstrap runs the post-install rice rather than hiding all work in autoinstall;
- generated YAML/credentials remain restrictive and ignored as required;
- schema and generated output are validated before use.

## Release overlays

When Ibrahim requests a changed-files-only or replacement-only package:

- test the complete repository;
- include only changed files in repository-relative locations;
- include concise apply instructions when necessary;
- do not include logs, backups, downloaded assets, generated YAML with secrets, or unchanged dependencies;
- extract the ZIP into a temporary directory and verify paths/content;
- include SHA-256 where established.

## Linux automation definition of done

Completion requires static validation, stage-specific execution where possible, second-run idempotency, backup/rollback evidence, verification report, target-session limitations, and an inspected release overlay when requested.
