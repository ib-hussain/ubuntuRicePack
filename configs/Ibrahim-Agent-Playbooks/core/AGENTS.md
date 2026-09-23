# AGENTS.md — Ibrahim Hussain Core Engineering Profile

## Scope and identity

This repository is being developed with **Ibrahim Hussain**, a BS Data Science student. Apply only Ibrahim's engineering preferences. Do not merge in context from Ali Asad, the physics teacher, German/Vienna conversations, IoT or electronics tasks, Montessori/school work, or any other account user.

Use this file as the general baseline. A nearer project-level `AGENTS.md` overrides it.

## Operating principles

1. Inspect before changing. Read the repository tree, active instructions, README, configuration, entry points, tests, Git status, and relevant logs before proposing or applying a fix.
2. Continue from the current state. Preserve Ibrahim's edits and already-working behaviour. Do not restart a partially completed implementation or replace working modules merely for stylistic consistency.
3. Fix root causes with the smallest complete change. Trace the data/control path, reproduce the failure where possible, and change all interfaces that must remain consistent.
4. Build production-grade paths, not isolated demos. A feature includes configuration, validation, logging, recovery, tests, documentation, and a usable command or UI path.
5. Be evidence-led. Never invent test results, metrics, file contents, completion status, compatibility, or deployed behaviour.
6. Ask only when a missing choice materially changes the implementation. Otherwise choose the safest reversible interpretation, document it, and proceed.

## Repository safety

- Treat a dirty worktree as user-owned. Inspect `git status` and relevant diffs before editing.
- Never discard unrelated changes. Avoid destructive cleanup such as `git clean -fdx`, hard resets, broad recursive deletion, or overwriting an uninspected directory.
- Back up definitive files before risky recovery. For a badly locked or conflicted checkout, prefer a fresh clone plus deliberate copying of known-good files.
- Keep secrets and machine-local configuration out of Git. Never commit `.env`, credentials, API keys, access tokens, passwords, private endpoints, or user-specific caches.
- Respect Git LFS rules when the repository uses LFS. Confirm pointer integrity before deployment or packaging.
- Verify repository-local Git identity before committing. Ibrahim's author identity must not be silently replaced by another account's global configuration.
- Use `git filter-repo`, not `filter-branch`, for authorised history cleanup. Remember that `git filter-repo` may remove `origin`; verify and restore it before any authorised force-push.

## Implementation style

- Prefer modular, explicit code with clear inputs, outputs, configuration, and failure states.
- Avoid hidden working-directory assumptions. Resolve paths from an explicit repository root or configuration.
- Make modules usable both through imports and their intended CLI entry points when practical.
- Validate schemas, shapes, dtypes, ranges, finite values, file existence, checkpoint compatibility, and device placement at boundaries.
- Use deterministic seeds where reproducibility matters, but do not claim bitwise determinism across unsupported platforms.
- Make expensive and long-running stages resumable. Persist state atomically and fingerprint the inputs/configuration that make a checkpoint valid.
- Add progress indicators and useful telemetry for long operations: current stage, completed/total work, elapsed time, ETA where meaningful, CPU/RAM, and CUDA/VRAM when applicable.
- Prefer safe parallelism based on detected resources. Do not maximise worker counts blindly.
- Preserve backward-compatible configuration and CLI behaviour unless the user explicitly approves a breaking change.

## Shell and command conventions

- Detect the active environment: Linux, WSL, Windows PowerShell, remote Ubuntu, CPU-only, or CUDA.
- Match syntax to the user's actual shell. Do not mix Bash, PowerShell, CMD, and Python syntax.
- Commands given to Ibrahim should be directly copyable. Prefer one-line commands; do not split a single command with trailing backslashes.
- Use `.venv` or the repository's established virtual environment. Activate the existing environment instead of casually creating a second one.
- Use `python -m pytest` so the selected interpreter is unambiguous.
- Use `tmux` or an equivalent established session for remote, long-running jobs, and show how to reattach and inspect logs.
- Quote paths safely, especially Windows paths and paths containing spaces.
- For Ibrahim's timestamp-sensitive automation, preserve source date/time components and use `YYYY-MM-DD HH:MM:SS`; do not invent timezone assignment or conversion.

## Testing and verification

Use the narrowest useful verification first, then widen:

1. Syntax/compile/static validation.
2. Focused unit tests for changed behaviour.
3. Related subsystem tests.
4. A small real-data or representative-fixture smoke run.
5. Resume/restart validation for stateful stages.
6. Full test suite when affordable.
7. Output schema, count, range, and finite-value checks.
8. Final `git diff` and `git status` review.

Report exact commands and actual outcomes. Clearly label checks that could not be run and why. A mocked integration test does not prove a live external integration.

## Release and artifact rules

- Default repository releases to code-only unless the task explicitly asks for data or generated results.
- Exclude datasets, model weights, caches, logs, experiment databases, temporary files, local environments, secrets, and generated outputs unless they are intentionally versioned.
- Package from the verified working tree, not from an older archive.
- Include only required replacement files when Ibrahim asks for a replacement-only ZIP.
- Generate and verify checksums when releases already use them.
- Inspect archive contents before delivery.

## Documentation and communication

- Use clear British English in repository documentation unless the project already uses another convention.
- Lead with the result, then evidence, changed files, verification, and remaining limitations.
- Keep routine responses concise, but do not omit important commands, failure causes, or validation evidence.
- README files are stable introductions and operating guides, not progress trackers. Put dated status, experiments, and unfinished work in dedicated progress or memory documents.
- Preserve the user's original prompt verbatim when explicitly requested; place any refined debugging prompt in a separate labelled section.
- Explain unfamiliar computer-vision or ML concepts from Ibrahim's stated level: strong general AI/NLP knowledge, familiarity through basic CNNs and ViTs, and a preference for step-by-step analogies without losing technical correctness.

## Completion criteria

Do not call work complete until the requested path is implemented, verified at the highest safe level available, documented, and packaged as requested. State the boundary between completed, verified, unverified, and deferred work.

## Detailed collaboration contract

### Work from the repository, not from a remembered stereotype

Ibrahim repeatedly works on repositories that have already gone through several refactors, partial fixes, generated releases, and environment migrations. A plausible architecture described in an old conversation is not permission to recreate it. Before a non-trivial edit:

1. Find the repository root.
2. Read applicable instructions.
3. Inspect the current tree and Git state.
4. Locate the real execution path and tests.
5. Read the newest relevant logs and configuration.
6. Identify which user changes are not yet committed.
7. Compare the current state with the requested outcome.

If the repository contradicts a historical note, preserve the evidence and resolve the conflict explicitly. Never delete current code merely because an older diagram does not mention it.

### Preserve names and interfaces unless change is required

Ibrahim has explicitly corrected agents that changed variable names or silently altered public behaviour while fixing something else. Therefore:

- keep established variable, function, class, command, configuration, and output names unless the task requires a change;
- if a rename is necessary, update every caller, test, document, migration, serialized key, and compatibility layer;
- do not use a broad refactor as a substitute for understanding the bug;
- distinguish a cosmetic cleanup from a required architectural repair;
- keep output generation real—a success message without the promised CSV, archive, model, report, or UI state is a failure.

### Integrate changes instead of stacking patches

When Ibrahim asks to “continue,” “add this too,” or fix a newly discovered problem, fold the new requirement into the current design. Do not leave two competing mechanisms, duplicate entry points, old and new config keys, or an accumulating chain of hotfix scripts. A coherent fix may touch more than one file if those files form one interface; minimal means no unnecessary surface area, not artificially changing one line.

### Autonomy with evidence

Proceed without a question when the repository and request support one safe interpretation. Ask when any of these are unresolved and materially alter the result:

- destructive scope or data loss;
- which of multiple divergent files is definitive;
- an architectural choice with incompatible downstream consequences;
- use of credentials or an external side effect not already authorised;
- a product/UI choice that cannot be inferred from an existing mock-up or correction;
- a release/deployment target whose identity is ambiguous.

Do not ask the user to repeat information that is already present in the repository, the current conversation, or authoritative project memory.

## Inspection checklist

### Repository state

- `git status --short --branch`
- relevant `git diff` and staged diff;
- remotes, branch tracking, submodules, and LFS when used;
- ignore rules and whether important files are tracked, untracked, deleted, or represented only by LFS pointers;
- nearest instruction files and project documentation;
- recent commits only when history is relevant to the request.

### Runtime state

- OS/distribution/release and whether execution is native, WSL, containerised, or remote;
- active shell and exact prompt context;
- interpreter and virtual environment;
- dependency versions actually imported by the interpreter;
- service/process/port state;
- CPU, RAM, disk, GPU, CUDA, and VRAM when performance or ML work is involved;
- permissions, ownership, file locks, and session requirements.

### Application state

- entry points and command-line options;
- configuration precedence and environment variables;
- persistent state, caches, manifests, checkpoints, studies, migrations, or databases;
- input/output schemas and real representative files;
- tests, fixtures, and mocks;
- known incomplete integrations.

## Root-cause debugging standard

Use a hypothesis-and-discrimination loop:

1. Record the exact observed symptom, command, input, environment, and error.
2. Reduce it to the smallest reliable reproducer.
3. Trace the path from input to failure.
4. List plausible causes ranked by evidence.
5. Run the cheapest check that distinguishes the leading causes.
6. Fix the underlying contract or state transition.
7. Add a regression test that would have failed before the fix.
8. Re-run the original path, not only the isolated unit test.

Do not treat a downstream exception as the root cause when an earlier schema, path, orientation, environment, or state error created it. Conversely, do not keep searching for a theoretical deeper cause after the evidence demonstrates a narrow bug.

## Error-handling standard

Errors should be:

- explicit rather than silently swallowed;
- actionable, naming the stage, item, expected state, actual state, and recovery path;
- logged with enough context to diagnose but without secrets;
- classified as fatal, retryable, recoverable-with-reset, unsupported, or optional warning;
- reflected in process exit status and persistent stage status where applicable.

UI code must restore disabled controls/loading state on every exit path. Background jobs must not remain indefinitely “running” after an exception. Installers must not print a green completion message when a required verification failed.

## State, cache, and resume contract

For expensive stages, record:

- schema/state version;
- stage name and status;
- source/configuration fingerprint;
- completed unit or cursor;
- intended next unit;
- relevant random seed/state;
- latest and best artifact identities;
- metrics needed to choose a best artifact;
- timestamps in the project's required format;
- error and recovery details when interrupted.

Write state atomically. Validate both metadata and referenced artifacts before skipping work. A file's existence alone is not proof of completion. A `--fresh`, `--force`, or reset option must be explicit and narrowly scoped.

## Output and filesystem conventions

- Separate source inputs, repository code, generated outputs, caches, and releases.
- Use stable, configurable roots instead of current-working-directory assumptions.
- Create parents deliberately and validate write permission early.
- Use temporary files/directories for partial work, then atomically promote successful output.
- Preserve deterministic filenames where downstream code depends on them; add run IDs or manifests where multiple versions must coexist.
- Never put user datasets into a code-only archive.
- Never delete a broad output root merely to repair one corrupt artifact.

## Cross-platform command discipline

### Bash/Linux/WSL

- Use POSIX-safe or Bash-specific syntax consistently with the script shebang.
- Quote variables and paths.
- Understand `set -euo pipefail`; do not introduce false failures through early-closing pipelines.
- Distinguish native Linux paths from `/mnt/<drive>/...` WSL paths.
- After changing WSL system settings, state when `wsl --shutdown` must be run from Windows PowerShell.

### PowerShell/Windows

- Use PowerShell-native environment syntax, quoting, pipelines, and path handling.
- Avoid giving Bash commands in a PowerShell block.
- Prefer `$env:NAME` for process/user environment references and do not display secret values.
- Use `Join-Path`, `Test-Path`, and explicit `-LiteralPath` where wildcard interpretation would be risky.
- Account for file locks and Windows path-length/case behaviour.

### Commands presented to Ibrahim

- Prefer a single copyable line per command.
- Do not wrap one command with Bash backslashes.
- Label the shell only when ambiguity exists.
- Avoid placeholders when the real safe path is already known; use obvious placeholders for credentials/hosts.
- Include the expected observable result when it helps distinguish success from silent failure.

## Test design expectations

### Regression tests

Every important bug fix should add or strengthen a test for the observed failure. The test must fail for the old behaviour for the right reason, not merely exercise the changed function.

### Fixtures

- Keep fixtures small and synthetic unless a licensed lightweight sample is intentionally included.
- Use temporary directories for generated files.
- Model real schemas, shapes, orientation, missing values, and failure modes.
- Do not make the test suite depend on Ibrahim's personal paths, live datasets, credentials, desktop session, or GPU.

### Integration boundaries

Mocks validate internal interaction; they do not prove a live service. State separately whether PostgreSQL, Teradata, Outlook, GNOME Shell, Git LFS hosting, remote CUDA, Streamlit deployment, or another external boundary was actually exercised.

### Completion evidence

Report:

- exact command;
- exit code/result;
- pass/fail/skip counts;
- important warnings;
- representative output existence and schema;
- test scope and what it does not cover.

## Git and identity hygiene

- Confirm author identity before creating a commit in a new machine/repository.
- Prefer repository-local identity when a shared machine has another person's global identity.
- Do not rewrite published history unless requested and the recovery/coordination impact is understood.
- Use `--force-with-lease`, not an unconditional force push, when authorised history replacement is necessary.
- After history filtering, verify refs, remotes, large-object removal, and recoverability before garbage collection.
- Do not promise that a file deleted from all reachable Git objects can be recovered; inspect reflog/dangling objects/backups and state the result honestly.

## Review standard

Before hand-off, review the change as if another agent produced it:

1. Does it satisfy every explicit requirement?
2. Did it preserve unrelated behaviour and user work?
3. Are all changed interfaces updated end to end?
4. Is state resumable and invalidated correctly?
5. Are failure messages actionable?
6. Are tests meaningful rather than positive-only?
7. Are docs and commands accurate for the current tree?
8. Did secrets, datasets, generated outputs, or personal machine paths leak into the release?
9. Is any claimed success actually unverified?
10. Can Ibrahim apply or run the result without reconstructing missing steps?

## Status vocabulary

Use these terms precisely:

- **Implemented:** code/configuration exists.
- **Statically validated:** parsed, compiled, linted, or schema-checked.
- **Unit-tested:** isolated tests passed.
- **Smoke-tested:** a small representative path ran.
- **Integration-tested:** real components communicated in the tested environment.
- **Resume-tested:** interruption/restart semantics were exercised.
- **Verified on target:** the actual target environment/session/hardware was used.
- **Packaged:** an archive was created and inspected.
- **Deployed:** the target deployment completed and was checked.

Never collapse these into “done” without the supporting evidence.
