---
name: ubunturicepack-engineering
description: Inspect, repair, extend, verify, and package Ibrahim Hussain's Ubuntu/Arch/WSL GNOME rice and installation automation.
---

# ubuntuRicePack Technical Workflow

## 1. Identify repository and target profile

1. Confirm `ubuntuRicePack` versus `archRicePack` and inspect remote/branch/commit.
2. Read current README/instructions and `scripts/00-common.sh`.
3. Inspect `install-rice.sh`, stage order, configs/assets, tests, Git status, and last logs/reports.
4. Detect distribution/release/GNOME/session/WSL/user/home.
5. Select desktop, WSL, autoinstall generation, repair, state-only, or optional local-AI scope.
6. Reconfirm no-Snap/no-Firefox and non-destructive boundaries.

## 2. Build a stage dependency map

For the requested change, identify:

- shared helpers used;
- root operations;
- packages/sources;
- repository config inputs;
- target files/Dconf keys/extensions;
- backup/rollback mechanism;
- verification report;
- supported release branches;
- session restart requirement;
- package/release overlay impact.

Patch the shared mechanism when it is the common cause.

## 3. Reproduce narrowly

- Run `bash -n` first.
- Run the stage `--help`/dry-run/state-only mode where available.
- Capture the exact log/report.
- Reproduce only the failing stage before a full rerun.
- Under strict-mode failures, distinguish required mismatch from optional absence.
- For GNOME runtime issues, reproduce in the live session and inspect the journal.

## 4. Implement safely

1. Add release/profile branching to existing helpers rather than scattering detection.
2. Validate package/source/asset/config before mutation.
3. Back up exact targets.
4. Use narrow root elevation and preserve ownership.
5. Make the action convergent/idempotent.
6. Record changed/already-correct/unsupported/failed results.
7. Provide rollback and reload/shutdown instructions.

## 5. Validate shell and generated artifacts

Run as applicable:

- `bash -n` across all changed shell scripts;
- ShellCheck;
- YAML/schema validation;
- XML validation;
- JavaScript syntax/lint checks;
- extension metadata/schema validation;
- Sass compilation and CSS consistency;
- `.desktop` validation;
- generated autoinstall validation;
- repository tests.

Do not allow a generated file to be treated as valid merely because the generator exited zero.

## 6. Verify installer behaviour

1. Run the narrow stage.
2. Inspect log/report/ownership/state.
3. Run verification/audit.
4. Rerun the stage and confirm no duplication or damage.
5. Run the full affordable installer/test path.
6. For WSL changes, run `wsl --shutdown` from PowerShell and verify after restart.
7. For GNOME changes, log out/in and verify extension/visual behaviour in-session.

## 7. Dock-specific workflow

1. Compare `dev+production-mockup.html` with production CSS/Sass/JS.
2. List browser-only effects that require GNOME-compatible fallbacks.
3. Preserve Ubuntu Dock/Dash-to-Dock mode and running DOTS.
4. Keep dynamic roundness in `_adjustTheme()`.
5. Implement per-icon hover scales/translations for the five-icon neighbourhood.
6. Implement corresponding hover spacing in the same handler.
7. Clear hover state on leave, actor destruction, overview/mode changes, and extension disable.
8. Validate orientation/autohide/running/multi-window/favourites.
9. Inspect journal for exceptions and confirm original icons restore on disable where applicable.
10. Package source and compiled styling together.

## 8. VS Code repair workflow

1. Resolve `Get-Command code`/Linux equivalent and package origin.
2. Capture verbose launch and process result.
3. Test `--disable-extensions` and temporary `--user-data-dir`.
4. Inspect logs/journal.
5. Back up current profile.
6. Repair the smallest corrupt cache/profile area or reinstall only if package failure is proven.
7. Restore required settings/extensions.
8. Verify `code .` and GUI launcher.

## 9. Autoinstall workflow

1. Validate templates and parameter inputs.
2. Ensure storage/network remain interactive as specified.
3. Ensure no destructive disk recipe exists.
4. Configure SSH policy.
5. Pin and verify the rice repository commit.
6. Generate YAML with restrictive permissions and ignored secret outputs.
7. Validate the generated file.
8. Verify first-login bootstrap visibility, logging, retry, and final audit.

## 10. Compatibility workflow

For Ubuntu 25.04/GNOME 48 and Ubuntu 26.04/GNOME 50 branches:

1. Test release detection fixtures.
2. Resolve package availability/source policy.
3. Check Dconf schemas/keys.
4. Check extension metadata and JS APIs.
5. Exercise normal and strict validation.
6. Record optional unsupported behaviour rather than hiding it.
7. Run live VM/session tests when possible.

## 11. Replacement-only release

1. Compute the intended changed-file list from the verified tree.
2. Ensure repository-relative paths are preserved.
3. Exclude unchanged files and all generated/local state.
4. Include apply instructions if needed.
5. Create ZIP, list contents, extract into a temporary tree, and run applicable checks.
6. Generate SHA-256.
7. Report full-repository tests separately from files included in the overlay.

## Acceptance evidence

- platform/release/profile detected;
- exact stage/root cause;
- backup/rollback;
- static/generated-file checks;
- narrow stage and second-run results;
- full test/audit result;
- live GNOME/WSL boundary;
- changed-files-only archive inventory and checksum.
