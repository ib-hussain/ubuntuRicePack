# AGENTS.md — ubuntuRicePack / archRicePack

## Project identity

This is Ibrahim Hussain's Linux desktop customisation and installation-automation work. The history spans `archRicePack`, its Ubuntu migration `ubuntuRicePack`, WSL support, GNOME settings, Bash/Fastfetch, VS Code, themes, extensions, dock/top-bar components, optional local AI, and Ubuntu autoinstall/bootstrap work.

Apply only Ibrahim's project history. Do not mix in another user's Linux preferences.

## Project objective

Maintain a reproducible, attractive, functional GNOME environment across the supported Ubuntu and Arch contexts while preserving Ibrahim's curated behaviour and making installation/repair safe to rerun. The repository is not merely a theme dump; it is a staged, logged, verified desktop automation system.

## Durable product decisions

### Ubuntu post-install boundary

- The rice installer is post-install only.
- It must never partition or format disks.
- It must never run an Arch installation/chroot flow.
- It must not modify GDM logo/branding unless a future explicit request changes this.
- The separate Ubuntu autoinstall work may prepare the OS, but storage and network remain interactive according to the approved design.

### Package policy

- No Snap usage.
- No Snap-installed Firefox; the project historically asked for no Firefox in the Ubuntu package plan.
- Prefer official Ubuntu package sources for required software.
- Release-specific approved upstream sources must be guarded and validated.

### Desktop/dock policy

- Ubuntu uses Ubuntu Dock (`ubuntu-dock@ubuntu.com`) as the native base.
- Arch may use Dash to Dock.
- Do not install/bundle a competing Dash-to-Dock on Ubuntu merely to simplify styling.
- Repository-owned extension identity historically used `arch-dock-icon@ib-hussain`; later design also discussed unified `rice-dock@ib-hussain` and `rice-top-bar@ib-hussain`. Inspect the current tree and use its actual canonical UUIDs.
- One `logo.png` should be shared consistently where the current design expects it.
- Avoid icon/theme collisions and CSS-glyph substitution hacks.

### Optional local AI

Local AI remains an independent optional stage/script. Do not make Ollama/Open WebUI a prerequisite for the base rice or desktop repair.

### WSL

WSL uses a guarded subset. It may configure systemd, target user, optional hostname, hosts entry, shell/dev tooling, and VS Code integration. It must not run native GNOME desktop stages.

## Supported platform intent

Historical compatibility work targeted:

- Ubuntu 25.04 with GNOME 48;
- Ubuntu 26.04 with GNOME 50;
- Ubuntu GNOME 50.1 in the main tested/customised environment;
- Arch GNOME 50.2 in the source/migration context;
- WSL on Windows.

These are historical targets. Runtime-detect the actual release and GNOME version. Do not claim compatibility because a version string was added; package, schema, extension API, and runtime behaviour must all be considered.

## Repository structure intent

The repository has historically preserved configuration areas such as:

- autostart;
- Dconf/GSettings snapshots and apply scripts;
- extensions;
- Fastfetch;
- GNOME Shell;
- GTK 3/4;
- local bin scripts;
- Nautilus Python integration;
- power menu/profile tooling;
- themes/icons/fonts/wallpapers;
- VS Code settings/data;
- Bash/profile configuration;
- installer/autoinstall scripts;
- WSL setup;
- optional cluster/local-AI work.

Do not aggressively shorten or flatten the repository if doing so removes behaviour, verification, portability, or repair granularity.

## Installer architecture

Use the existing staged orchestrator pattern:

- one main `install-rice.sh` or current equivalent;
- shared helpers such as `scripts/00-common.sh`;
- numbered stages for packages, configuration, terminal, development tooling, extensions, GNOME, VS Code, finalisation, WSL, and optional components;
- `run_step` for ordinary user-stage execution;
- narrow `run_root` for privileged operations;
- named logs, backups, state, and verification reports under a user-owned state directory;
- missing required scripts are fatal;
- optional unavailable functionality is reported accurately.

The user has asked for unified desktop/WSL entry points, but this means shared orchestration with explicit branches—not executing desktop work in WSL.

## `run_root()` contract

The shared root helper is critical. It must:

- accept an argument vector without unsafe re-parsing;
- preserve spaces and special characters;
- invoke only the intended command with sudo/root privileges;
- retain target-user context information separately;
- propagate the actual exit code;
- log the high-level action without leaking secrets;
- avoid turning the entire installer into root-owned execution;
- behave correctly under strict Bash modes.

A failure here is a repository-wide problem and deserves focused tests, not a local workaround in every stage.

## Strict Bash and pipeline rules

- Use `set -euo pipefail` only with deliberate handling.
- Avoid `producer | grep -q` patterns that can produce a SIGPIPE/false failure under `pipefail`; capture output or use safe matching.
- Quote paths and expansions.
- Validate arrays/optional variables before use under `nounset`.
- Do not use broad globs for destructive/privileged targets.
- Normalise line endings for shell files delivered from Windows.

## Idempotency

On a second run:

- repositories/sources are not duplicated;
- config blocks/hosts entries/launchers are not appended twice;
- extensions are updated or left correct, not duplicated;
- Dconf values converge;
- downloads use valid cache;
- backups do not overwrite the only original baseline;
- already-correct items are reported separately;
- required failures still produce non-zero status.

Idempotency must be tested, not assumed from `mkdir -p` and `--force` flags.

## Logging and reports

Each run should expose:

- detected repository and target user;
- detected distribution/release/GNOME/WSL branch;
- log path;
- stage start/end/status;
- changed, already-correct, unsupported, warning, and failed counts;
- extension inventory and desired/current states;
- GNOME settings report;
- final audit report;
- exact logout/login or `wsl --shutdown` action.

Warnings must point to the log/report. A completion banner is valid only when required final verification passed.

## GNOME configuration rules

- Back up current Dconf before applying the curated snapshot.
- Verify schema and key existence.
- Preserve appearance, desktop, input, privacy, power, window behaviour, shortcuts, media keys, app folders, notification settings, dock favourites, application grid, terminal profile, and installed application settings where represented.
- Treat unsupported keys on a different GNOME version as compatibility results, not silent deletion.
- Keep themes, Noto appearance, Nerd Fonts, icons, wallpapers, and shell extensions internally consistent.
- State when logout/login is required for Shell extensions/theme reload.

Historical verification output separated changed/planned, already matched, unsupported/unavailable, and rejected/failed. Preserve that style of evidence.

## Extension policy

- Validate a complete declared inventory.
- `arch-dock-icon@ib-hussain` was historically the only repository-owned extension in one approved design; other unmodified extensions should come from Ubuntu packages or GNOME Extensions.
- Map a generic Dash-to-Dock inventory requirement to Ubuntu Dock on Ubuntu.
- Journal-log runtime extension failures.
- Support state-only mode where downloads/code replacement are skipped but desired state/settings are reapplied.
- Do not report an enabled extension as working until the live session/journal confirms it.

## Arch-style Ubuntu Dock specification

The later dock redesign uses `dev+production-mockup.html` as the visual reference and replaces the prior glitchy dock styling coherently.

### Scope

- Dock only.
- Browser mock-up top panel/`.menu-bar` is out of scope.
- Preserve native Ubuntu Dock/Dash-to-Dock behaviour beyond the requested styling/interaction.

### Visual/interaction decisions

- Running-app indicator remains the existing **DOTS** style; a decorative mock-up dot is not a second indicator.
- Roundness remains dynamic. Historical production logic used a radius derived from `dashMaxIconSize × dockRoundness`; do not hard-code `16px` merely because the mock-up uses it.
- GNOME St does not support browser `backdrop-filter`. Use a tinted translucent fallback with a subtle border rather than pretending the blur works.
- Continuous PointerWatcher/Gaussian magnification was abandoned when it silently did not work.
- Use per-icon hover signals (`enter-event`/`leave-event` or `notify::hover`) for discrete focus.
- Accepted five-icon scale pattern: `1.1, 1.2, 1.5, 1.2, 1.1` for index ±2.
- Accepted vertical translations: `0, -6, -10, -6, 0` across that neighbourhood.
- Hover spacing must be applied together with scale so icons do not collide. The browser reference used 13 px side margins; production may animate margins or horizontal translation within GNOME constraints.
- Enter/leave magnification is acceptable; do not reintroduce a dead continuous tracker.

### Implementation surfaces

Keep source and compiled styling consistent:

- `_stylesheet.scss` variables/source;
- `stylesheet.css` production output;
- `theming.js::_adjustTheme()` for dynamic theme-derived behaviour;
- any dock icon/hover handler JavaScript required by the current implementation.

Do not create a third styling mode or leave the older mock-up path active.

## VS Code repair decision tree

For `code .` returning immediately:

1. Inspect command resolution/shim and package source.
2. Run verbose/status diagnostics.
3. Inspect VS Code and user journal logs.
4. Try extensions-disabled and a temporary user-data directory.
5. If the clean profile works, back up and rebuild only corrupted profile/cache state.
6. Preserve user settings/keybindings/snippets/extensions where possible.
7. Verify opening from terminal and through desktop launcher.

Do not suppress the symptom with a background launch that leaves a broken profile.

## Ubuntu autoinstall rules

The approved design uses the installer YAML for OS/base setup and a visible first-GNOME-login bootstrap for the rice.

- `interactive-sections` retains storage interaction.
- Do not include a disk recipe.
- Network is interactive where required.
- SSH server is enabled.
- Root SSH is disabled.
- Password login follows the approved installation need.
- Repository checkout is pinned to an exact verified commit when generating a reproducible installer.
- Generated YAML and sensitive values are restrictive and ignored.
- Schema/XML/JS or other applicable generated-file checks must pass.

## Release format

Ibrahim often wants replacement-only/changed-files-only ZIPs:

- test the full repository;
- package only changed files with repository-relative paths;
- include apply instructions when the overlay is not self-explanatory;
- inspect and test extraction;
- generate SHA-256;
- do not include logs, backups, caches, downloaded assets, generated secrets, or unchanged files.

## Documentation and completion

- Preserve detailed behaviour; do not reduce scripts solely to make them shorter.
- Document desktop versus WSL paths and strict versus normal mode.
- State static validation separately from live GNOME testing.
- A change is complete only after full relevant validation, idempotent rerun evidence, and a precise target-session boundary.
