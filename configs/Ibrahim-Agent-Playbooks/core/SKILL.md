---
name: ibrahim-repository-engineering
description: Inspect, diagnose, implement, verify, document, and package repository changes using Ibrahim Hussain's evidence-led, resumable, cross-platform workflow.
---

# Ibrahim Repository Engineering Workflow

Use this workflow for a new feature, repair, refactor, compatibility update, or release in one of Ibrahim Hussain's repositories.

## 1. Establish identity and scope

- Confirm the work belongs to Ibrahim Hussain's software/data-science context.
- Exclude history belonging to other account users.
- Restate the requested outcome and explicit non-goals.
- Identify whether the task authorises diagnosis only, implementation, packaging, or deployment.

## 2. Inspect the current state

Run read-only checks before editing:

- Locate the repository root and read all applicable `AGENTS.md` files.
- Inspect `git status`, the relevant diff, repository tree, README, configuration, entry points, tests, and recent logs.
- Identify the active OS, shell, Python executable, virtual environment, package versions, CPU/RAM, and CUDA/GPU state when relevant.
- Find existing implementations with fast text search before adding new modules.
- Record current commands, output locations, schemas, checkpoints, and public interfaces that must remain compatible.

## 3. Reproduce and form a root-cause hypothesis

- Use the smallest reliable reproducer.
- Trace inputs through transformations to the failing output.
- Check paths, environment assumptions, types, shapes, schemas, encoding, permissions, locks, resources, and version compatibility.
- Separate the observed failure from inferred causes.
- If more than one cause is plausible, choose a discriminating check before editing.

## 4. Design the smallest complete change

Define:

- Files and interfaces to change.
- Invariants that must stay true.
- Configuration/default migration.
- Validation and error behaviour.
- Checkpoint/resume implications.
- Tests and documentation required.
- Release exclusions and rollback path.

Prefer extending existing architecture over creating parallel mechanisms.

## 5. Implement defensively

- Make local, reviewable edits.
- Validate at module boundaries.
- Preserve user changes and backwards compatibility.
- Use atomic writes for state and checkpoints.
- Include actionable logs with context and stack traces where appropriate.
- Keep shell-specific commands and paths correct for the detected environment.
- Never embed credentials or machine-specific secrets.

## 6. Verify in increasing scope

Run, as applicable:

1. Parser, compiler, or syntax checks.
2. Focused tests for the changed behaviour.
3. Related subsystem tests.
4. A representative smoke run using real data when safe.
5. An interrupted-and-resumed run for stateful work.
6. The full affordable suite.
7. Output contract checks: counts, columns, shapes, dtypes, ranges, finite values, and expected files.

Do not mask failed checks. Do not report tests that were not run.

## 7. Review the repository delta

- Inspect `git diff --check`, the actual diff, and `git status`.
- Confirm no dataset, output, secret, environment, cache, or unrelated file entered the change.
- Confirm documentation matches the implemented CLI and paths.
- Confirm Git identity and LFS pointer state if a commit or release is involved.

## 8. Package or hand off

- Build archives from the verified state.
- For code-only releases, exclude all data and generated artifacts.
- For replacement-only packages, include only the files the user must replace while preserving directory structure.
- List archive contents and verify the checksum when used.
- Give exact one-line Bash or PowerShell commands appropriate to Ibrahim's environment.

## 9. Report outcome

Report in this order:

1. Outcome.
2. Root cause or design decision.
3. Files changed.
4. Verification commands and observed results.
5. Remaining unverified external dependencies or limitations.
6. Delivered artifact.

Never describe an external service, GPU path, database, email client, or deployment as verified unless it was actually exercised.

## Expanded execution playbook

### A. Task intake and authority check

Parse the request into a short internal contract:

| Field | Question |
| --- | --- |
| Outcome | What observable result must exist? |
| Scope | Which repository, component, platform, and artifacts are included? |
| Non-goals | What must remain untouched? |
| Authority | Is this review, diagnosis, implementation, packaging, deployment, or an external side effect? |
| Evidence | Which files, logs, errors, mock-ups, or prior decisions are authoritative? |
| Risk | Could the action delete data, rewrite history, expose secrets, or affect external users? |

If the user asks to diagnose, stop after evidence-backed diagnosis unless implementation is clearly included. If the user asks to build/fix, carry the work through verification and delivery.

### B. Repository map

Create a working map before editing:

- root instructions and documentation;
- source packages and entry points;
- configuration and environment loading;
- storage/data/checkpoint/output locations;
- test structure;
- build/package/deploy scripts;
- external integrations;
- current dirty changes;
- likely files for the requested path.

Do not read every file indiscriminately. Start broad enough to understand topology, then read the concrete dependency path completely.

### C. Reproduction record

Capture a reproducible record:

```text
Environment:
Command:
Inputs/config:
Expected:
Observed:
Exit code:
Relevant logs/traceback:
First known bad stage:
```

For a UI issue, include navigation/state transitions. For a data issue, include schema/count/sample identity. For a long pipeline, include the persisted stage status and fingerprint. For a platform issue, include OS/shell/session/service versions.

### D. Hypothesis matrix

For non-obvious bugs, make a compact matrix:

| Hypothesis | Supporting evidence | Contradicting evidence | Discriminating check |
| --- | --- | --- | --- |
| Path/config error | ... | ... | ... |
| Data/schema error | ... | ... | ... |
| State/cache mismatch | ... | ... | ... |
| Dependency/platform issue | ... | ... | ... |
| Implementation defect | ... | ... | ... |

Run the discriminating checks before changing multiple layers.

### E. Change design record

Before implementation, identify:

- affected files;
- public and serialized interfaces;
- configuration migration/defaults;
- state/cache invalidation;
- success and failure paths;
- test cases;
- backward compatibility;
- documentation and release effects.

For a multi-stage change, implement a vertical slice that reaches a meaningful output before broadening it.

### F. Implementation loop

1. Make one coherent edit group.
2. Run the cheapest relevant check.
3. Inspect the failure rather than applying speculative changes.
4. Continue until the narrow path is correct.
5. Add the regression test.
6. Widen verification.

Avoid a long untested patch that combines refactoring, dependency upgrades, behaviour changes, and packaging.

### G. Stateful-stage checklist

When touching resumable work, verify all of the following:

- fresh start creates valid state;
- normal resume skips completed valid units;
- partially written output is not accepted as complete;
- config/data/schema changes invalidate incompatible state;
- corrupt state fails clearly or recovers through an explicit route;
- latest and best artifacts are not confused;
- a completed stage remains inspectable through a status command/report;
- reset/force affects only the selected stage/profile/run.

### H. UI/application checklist

- input validation before expensive work;
- no long blocking operation on the UI request thread;
- visible progress and current stage;
- recoverable error with details/log path;
- controls restored after failure;
- no duplicate submission on refresh/poll;
- explicit approval before external execution/sending;
- downloadable output exists and is validated;
- navigation preserves already-computed state when intended.

### I. Installer/automation checklist

- detects target platform/release;
- distinguishes required and optional stages;
- backs up exact targets;
- uses narrow privilege elevation;
- validates downloads and configs before install;
- is idempotent on a second run;
- writes logs and verification reports;
- exposes strict mode where the project defines one;
- gives rollback and session-restart instructions;
- packages only intentional replacement files when requested.

### J. ML/data checklist

- source and label definition;
- stable sample IDs;
- train/validation/test rule;
- leakage audit;
- training-only fitted preprocessing;
- persistent HPO/checkpoints;
- finite-value/shape/dtype/device validation;
- representative CPU smoke;
- target-hardware run status;
- evaluation matched to task/class balance;
- inference parity and saved preprocessing;
- artifacts excluded from code-only release.

### K. Release checklist

1. Establish the exact verified source state.
2. Confirm no secret/data/generated leak.
3. Build the archive from that state.
4. List and inspect archive contents.
5. Extract/test the archive when practical.
6. Generate checksum if the project uses checksums.
7. Record version and intended replacement/install procedure.
8. Never call an old archive current merely because its filename is newer.

### L. Handoff template

```markdown
Outcome: <what now works or was diagnosed>

Root cause/design: <evidence-backed explanation>

Changed:
- <file/component and purpose>

Verified:
- `<command>` — <actual outcome>

Not verified:
- <live service, hardware, target session, or dependency boundary>

Artifact:
- <file/version/checksum>
```

Keep the user-facing summary concise when requested, while retaining all necessary technical evidence in the files or run report.
