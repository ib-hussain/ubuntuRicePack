# AGENTS.md — Windows, PowerShell and Data Automation

## Scope

Use this profile for Ibrahim Hussain's Windows-native Python projects, PowerShell automation, PostgreSQL/SQL workflows, Streamlit or Flask applications, scheduled configuration updates, Continue/Ollama setup, and desktop integrations.

## Environment conventions

- Detect whether the terminal is Windows PowerShell, PowerShell 7, CMD, Git Bash, or WSL before giving commands.
- Prefer native Windows instructions when the project is already Windows-native. Do not introduce Docker, Gunicorn, or a Linux deployment layer unless the task requires it.
- Use the repository's `.venv` and run tools through the selected interpreter, for example `python -m pytest -q`.
- Use native PostgreSQL when that is the established setup.
- Quote Windows paths and avoid Bash continuations or environment-variable syntax in PowerShell instructions.
- Keep commands short, copyable, and one line where practical.

## Application architecture

- Separate UI, service/business logic, database access, workers/background tasks, configuration, and integrations.
- Keep long work outside the request/UI thread. Provide job status, progress polling, meaningful failure details, and safe retry.
- Require explicit user approval before sending email, changing external state, or executing high-impact operations.
- Use parameterised SQL and explicit transaction boundaries. Never build SQL from unsanitised UI strings.
- Add locking and recovery around shared caches or generated files.
- Preserve UI state across failures and restore controls in `finally`-style cleanup.
- Guard optional integration properties and log stack traces without exposing secrets.

## Time and data rules

- When the project requires Ibrahim's timestamp convention, format timestamps only as `YYYY-MM-DD HH:MM:SS`.
- Preserve the provided date and time components. Do not attach, convert, add, or subtract timezones unless the current specification explicitly changes that rule.
- Validate imported Excel/CSV/database schemas before transformation.
- Preserve source rows and record standardisation/merge decisions rather than silently changing identifiers.

## PowerShell automation

- Resolve paths explicitly and use temporary directories for downloads/extraction.
- Verify downloaded content with SHA-256 or the project's established version marker before replacement.
- When the requirement is complete replacement, replace the destination folder contents rather than layering stale and new files.
- Make scheduled tasks idempotent and use non-interactive exit codes/logs.
- Do not write plaintext passwords or tokens into scripts, task definitions, or committed configuration.
- For file-lock failures, identify the locking process and prefer a clean clone/copy workflow over destructive retries.

## Local AI tooling

- Treat Continue configuration, model providers, embeddings/RAG, custom commands, and Ollama service setup as separate testable parts.
- Match model size to available RAM. Prefer the established lightweight model for autocomplete when larger models are too slow or exceed memory.
- Keep API keys in environment or secure local settings, never in distributable YAML or scripts.
- Verify the provider endpoint and a minimal completion before debugging editor features.

## Verification

- Add unit tests for business logic, SQL generation, parsing, caching, and approval gates.
- Add integration seams/mocks, but state clearly when live PostgreSQL, Outlook, Teradata, scheduler, or external providers were not exercised.
- Use a permanent `pytest.ini`/package configuration when import-path behaviour must be stable; do not rely on an ad hoc shell variable.
- Verify frontend startup, worker startup, background-job state transitions, and a representative end-to-end flow.
- Report exact pass counts and coverage only from actual output.

## Native Windows design preference

When a repository is already designed for Windows PowerShell, native Python, native PostgreSQL, Streamlit/Flask, or desktop applications, preserve that design. Do not introduce Docker, WSL-only paths, Gunicorn, Bash launchers, or Linux service managers simply because they are familiar. Cross-platform support may be added when requested, but the primary path must remain simple for Ibrahim to run.

## PowerShell command quality

Commands must be:

- valid in the stated PowerShell version;
- copyable as one line where practical;
- explicit about the working directory;
- safe with spaces and special characters in paths;
- non-destructive by default;
- clear about process/user/machine scope for environment variables;
- honest about administrator requirements.

Do not mix PowerShell line continuations/backticks into a command unless they materially improve a script file. For chat hand-offs, one-line commands are preferred.

## Python environment and imports

- Resolve `python`/`py` and the selected `.venv` before installation or tests.
- Prefer `python -m pip` and `python -m pytest` so packages/tests use the same interpreter.
- Use a project configuration such as `pytest.ini`, packaging metadata, or proper package installation to solve import paths. Do not rely on a transient `PYTHONPATH` workaround as the permanent fix.
- Keep development and launch commands documented for PowerShell.
- Pin or bound dependencies where reproducibility matters, while avoiding unnecessary mass upgrades during a bug fix.

## Web/data application structure

Use explicit layers:

1. UI/routes/pages.
2. Request/input validation.
3. Application/service logic.
4. Background job/worker execution.
5. SQL/data access.
6. External adapters such as Outlook or Teradata.
7. Persistent state/cache/export generation.
8. Logging and error presentation.

The UI must not directly own long-running extraction, model, SQL, or export logic. A refresh or navigation event must not accidentally restart expensive work.

## Background work and polling

- Give each job a stable identifier.
- Persist status transitions such as queued, running, awaiting approval, succeeded, failed, and cancelled where relevant.
- Include current stage, progress, timestamps, output references, and error details.
- Poll without duplicating submission or blocking the UI.
- Recover or clearly mark stale “running” jobs after process interruption.
- Use locks around shared cache/state writes and detect stale locks safely.
- Validate generated artifacts before setting a job to succeeded.

## Approval-gate pattern

For document-to-SQL/email workflows, keep separate user approvals:

- approval of extracted/interpreted records or generated SQL before database execution;
- approval of final output/message before email or other external sending.

Show the user the relevant evidence at each gate. An approval must bind to the exact content/hash being approved so later regeneration cannot silently change what is executed or sent.

## SQL safety

- Generate structured SQL plus parameters rather than raw interpolated strings.
- Validate statement type and forbid/require operations according to task scope.
- Display SQL and relevant record mapping for review.
- Use explicit transactions, rollback on failure, timeouts, and bounded result sizes.
- Separate SQL generation validity from live database execution.
- Log query identity/timing/result counts without exposing sensitive row data.
- Never state that Teradata/PostgreSQL execution is verified when tests used only mocks or parsing.

## Document extraction and UI state

The polished multi-page UI should allow the user to inspect:

- full extracted text;
- selected/relevant records;
- transformations or mappings;
- generated SQL and validation state;
- approvals and execution state;
- downloadable reports/CSV/Excel outputs;
- navigation between pages without rerunning extraction.

Cache based on content/config identity, not just filename. Preserve the original upload and trace derived records back to source locations.

## File replacement automation

For scheduled configuration synchronisation:

1. Resolve the latest approved release/source.
2. Download into a unique temporary directory.
3. Verify status, archive shape, and SHA-256 or version marker.
4. Compare with the last applied hash.
5. Stop or coordinate only the process that locks the target.
6. Back up current target if rollback is required.
7. Replace the complete destination when complete replacement is the contract; do not leave stale files.
8. Verify the installed tree and launch/health signal.
9. Record the applied hash and result.
10. Clean only the narrow temporary directory.

Scheduled Task configuration must be idempotent, non-interactive, use explicit working directory/interpreter, and write a useful log/exit code.

## Windows file-lock handling

- Identify the locking process before retrying.
- Do not loop destructive Git/reset/copy operations against files Windows refuses to unlink.
- Preserve definitive files outside the troubled tree.
- Prefer a clean clone/new directory and deliberate file transfer when a worktree is stuck in a merge/LFS/lock state.
- Validate copied files and restore local secrets only after the clean tree is stable.

## Timestamp contract

Where the application specifies Ibrahim's timestamp rule:

- output exactly `YYYY-MM-DD HH:MM:SS`;
- preserve provided date/time components;
- do not assign an assumed timezone;
- do not convert, add, or subtract offsets;
- define behaviour for missing seconds/date components explicitly;
- test string, database, Excel/CSV, and UI round trips.

Do not generalise this rule to a project whose specification requires timezone-aware instants.

## Desktop/email integration boundary

Outlook may involve manual export, classic Outlook COM automation, or another adapter. Keep these paths separate and capability-detected. A unit test with a fake COM object is not a live-send test. External sending always requires the authorised approval path and should record success/failure without leaking message content.

## Windows app definition of done

Completion requires native setup commands, working import/start paths, validated background state transitions, guarded SQL/external actions, real output artifacts, automated tests, an honest live-integration boundary, and an inspected release archive.
