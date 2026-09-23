---
name: ibrahim-linux-desktop-automation
description: Build, repair, and verify Ibrahim Hussain's idempotent Ubuntu, Arch, WSL, GNOME, dock, shell, and local-AI automation.
---

# Linux Desktop Automation Workflow

## 1. Classify the target

Identify:

- Ubuntu, Arch, or WSL.
- Distribution release and GNOME Shell version.
- Interactive user, home directory, display session, and current shell.
- Whether the requested change is system packages, user configuration, GNOME state, an extension, dock CSS/JS, VS Code, or local AI.
- Explicit exclusions such as Snap, Firefox, partitioning, GDM branding, or unrelated top-panel work.

## 2. Inspect before editing

1. Read the orchestrator, common helpers, target stage scripts, current configs, and verification logic.
2. Inspect Git status/diff and the last user-provided logs.
3. Capture current package, GNOME extension, Dconf, and file state relevant to the failure.
4. Reproduce with the smallest stage-specific command instead of rerunning the entire installer immediately.

## 3. Diagnose the execution layer

Check:

- Incorrect OS/release branching.
- Root-versus-user context and ownership.
- Missing commands, packages, schemas, or extension versions.
- Strict-mode and pipeline failures.
- Bad quoting, paths, symlinks, or Windows line endings.
- Stale cached assets or partially installed state.
- Session-restart requirements.
- WSL limitations such as systemd user-session or networking mode.

## 4. Implement the repair

1. Put reusable logic in the existing common helper.
2. Keep stage scripts independently rerunnable.
3. Back up the exact target before replacement.
4. Validate downloads/assets before installing.
5. Apply user-owned files as the target user and root-owned files through the narrow root helper.
6. Record changed, already-correct, unsupported, and failed items separately.
7. Print the next required action, such as logout/login or `wsl --shutdown`.

## 5. Verify safely

1. Run Bash syntax checks and ShellCheck if available.
2. Exercise dry-run/state-only mode where supported.
3. Run the smallest affected stage.
4. Rerun it to verify idempotency.
5. Inspect logs, reports, ownership, installed paths, and Dconf/extension state.
6. For GNOME extensions, inspect the user journal and verify after session reload.
7. Test each supported release branch through detection fixtures or containers where practical; do not claim visual validation from a headless environment.

## 6. Package and hand off

- Include only changed replacement files when requested.
- Preserve repository-relative paths.
- Exclude caches, logs, backups, secrets, downloaded packages, and unrelated assets.
- Inspect ZIP contents.
- Give one-line Bash commands for backup, extraction, replacement, validation, and rerun.
- State which checks must still occur on Ibrahim's actual GNOME session.

## Detailed installer workflow

### A. Preflight

Collect and log:

- distribution ID/version/codename;
- GNOME Shell version and session type;
- WSL/native detection;
- target user, UID/GID, home, shell;
- repository root and commit;
- sudo availability;
- network state;
- free disk;
- relevant commands/packages/schemas;
- selected normal/strict/dry-run/state-only mode.

Fail before mutation when a required invariant is absent.

### B. Package resolution

1. Build the desired package set for the detected release/profile.
2. Check availability before installation.
3. Map approved alternatives per release.
4. Enforce forbidden packages/sources.
5. Update package metadata only when needed.
6. Install in bounded groups with useful logs.
7. Record resolved package/version/source.
8. Verify required executables after installation.

### C. User configuration restore

1. Inventory repository config sources and target paths.
2. Back up existing targets.
3. Validate source syntax/format.
4. Create parent directories with correct ownership.
5. Install or merge according to the file's declared semantics; do not merge files intended for replacement.
6. Validate installed content and ownership.
7. Record rollback commands.

### D. GNOME stage

1. Ensure it is a desktop-capable profile.
2. Inventory installed extensions and provenance.
3. Install/update the repository-owned extension.
4. Resolve distribution aliases such as Ubuntu Dock versus Dash-to-Dock.
5. Apply desired enable/disable state.
6. Validate and apply extension settings.
7. Back up and apply curated Dconf/GSettings values.
8. Generate detailed supported/unsupported/failure reports.
9. State the logout/login requirement.
10. After reload, verify actual state and inspect journal failures.

### E. Dock/extension development workflow

1. Read the production extension code and new browser mock-up.
2. Separate visual intent from browser-only CSS features.
3. Map changes to `_stylesheet.scss`, compiled `stylesheet.css`, and JavaScript/theming logic.
4. Preserve running indicators, dynamic radius, orientation, dock mode, and upstream Ubuntu Dock behaviour.
5. Implement hover scale and spacing together.
6. Validate JavaScript and metadata/schemas.
7. Validate Sass/CSS generation and ensure source/compiled files agree.
8. Install into a controlled test profile/session.
9. Inspect GNOME Shell journal and exercise hover, launch, running, multi-window, orientation, autohide, and restart behaviour.
10. Package only changed files if requested.

### F. Compatibility workflow

For each supported Ubuntu/GNOME branch:

1. Test release detection.
2. Resolve package/source alternatives.
3. Verify GNOME schemas/keys.
4. Verify extension `shell-version` and API use.
5. Verify JavaScript imports/runtime assumptions.
6. Run installer static tests.
7. Use a VM or target session for desktop runtime checks.
8. Record genuinely unsupported optional features.

### G. Repair workflow

For a reported failure:

1. Preserve the user's latest log and verification report.
2. Re-run only the failing stage with tracing/diagnostics if safe.
3. Identify first failure, not cascading warnings.
4. Patch the shared mechanism when multiple stages rely on it.
5. Add a regression check.
6. Run the stage, its verification, then the full affordable installer test.
7. Rerun to prove idempotency.
8. Deliver a replacement-only overlay when that is the established release format.

### H. Acceptance checklist

- No forbidden Snap/Firefox installation.
- No partition/format/chroot path in post-install rice.
- Correct release and WSL/native branch.
- Required scripts present and executable.
- Root/user ownership correct.
- Backups and rollback available.
- Downloads validated and cached.
- Bash syntax and ShellCheck status recorded.
- GNOME metadata/schema/JS/CSS validation passed.
- Desired extension/service/launcher state verified.
- Strict mode behaves as specified.
- Logs/reports name actionable paths.
- Second run converges.
- Package contains only intended files.
