---
name: ibrahim-windows-data-automation
description: Diagnose and build Windows-native PowerShell, Python, SQL, Streamlit/Flask, scheduler, and desktop-integration workflows.
---

# Windows and Data Automation Workflow

## 1. Detect the execution context

1. Identify PowerShell/CMD/WSL and the current directory.
2. Resolve `python`, the active `.venv`, Git, PostgreSQL client/server, and required desktop applications.
3. Inspect environment variables by name only; never print secret values.
4. Read existing launchers, configuration, `pytest.ini`, database migrations/schema, and logs.

## 2. Reproduce the failing path

- Run the narrow entry point: UI, worker, scheduled script, SQL operation, or provider probe.
- Capture exit code, traceback, application logs, service status, port ownership, and file locks.
- Distinguish import/path problems from dependency, database, UI, and external-integration failures.

## 3. Preserve contracts

Record before editing:

- CLI/PowerShell invocation.
- Configuration keys and secret boundaries.
- Database tables and parameter types.
- Job states and UI polling contract.
- Timestamp format and no-timezone rule when applicable.
- Folder replacement, hashing, and scheduling semantics.

## 4. Implement by layer

1. Put pure parsing/transformation/business logic in testable functions.
2. Keep SQL parameterised and transactions explicit.
3. Run long work through a worker/background job with persistent state.
4. Make UI polling responsive and preserve/restore controls after failure.
5. Put external side effects behind approval gates and adapters.
6. Lock shared cache/output updates and recover stale locks safely.
7. Log actionable context without credentials or private content.

## 5. Verify

1. Run syntax/import checks.
2. Run focused unit tests.
3. Start the database-dependent application against the configured local test database when authorised.
4. Start the UI and worker separately, then together.
5. Exercise success, validation failure, worker failure, retry, and recovery paths.
6. Verify timestamp and schema output.
7. Mark live desktop/email/database/provider paths unverified if they were not actually invoked.

## 6. Package or automate

- For repository delivery, exclude `.venv`, secrets, caches, local databases, downloads, and logs.
- For scheduled replacement, download to a temporary directory, validate hash/version, stop only the required process, replace the exact destination, verify, and record the applied hash.
- Provide native one-line PowerShell commands for setup, test, launch, and diagnosis.

## 7. Report

State the root cause, files changed, exact commands run, actual test/coverage output, remaining live integration gaps, and the delivered artifact.

## Detailed sub-workflows

### Native setup workflow

1. Confirm supported Python and PowerShell versions.
2. Create/activate the established `.venv` only if absent.
3. Install dependencies through the repository's declared file/package metadata.
4. Resolve native PostgreSQL/service/database configuration if required.
5. Create local configuration from a safe template; never fill secrets automatically.
6. Run import/config/database connectivity checks separately.
7. Run migrations or schema creation only with explicit project support.
8. Start worker and UI with documented one-line commands.

### UI/background-job workflow

1. Submit validated input and create a job record.
2. Return control to the UI immediately.
3. Worker claims the job atomically.
4. Persist stage/progress and heartbeats where needed.
5. UI polls and renders progress without resubmission.
6. Worker validates outputs before success.
7. Failure stores actionable details and releases locks.
8. UI restores controls and offers safe retry/resume.
9. Navigation reuses the completed extraction/results.

### SQL workflow

1. Extract and normalise relevant records.
2. Validate required fields and types.
3. Generate parameterised SQL plus parameter values.
4. Run a parser/policy validation.
5. Display source mapping and SQL to the user.
6. Bind approval to the SQL/parameters hash.
7. Execute within explicit transaction/timeout bounds.
8. Commit only on validated success; otherwise roll back.
9. Record affected/result counts and generate reports.

### Outlook/external-send workflow

1. Build a preview from verified outputs.
2. Validate recipients separately when real people are involved.
3. Display subject/body/attachments and final data summary.
4. Obtain explicit final approval bound to the preview.
5. Select the supported adapter (manual, classic Outlook COM, or configured provider).
6. Send once with idempotency/duplicate protection where feasible.
7. Record adapter outcome and recoverable error.
8. Never call a mocked adapter a live send.

### Cache and lock recovery

1. Name cache entries by content and relevant config/version hash.
2. Write via temporary files and atomic promotion.
3. Put owner/process/time/job metadata in locks.
4. On collision, distinguish active from stale ownership.
5. Recover stale locks through a narrow, logged path.
6. Validate cache contents before reuse.
7. Invalidate only incompatible entries.

### Scheduled replacement workflow

1. Resolve/download release to a validated temporary directory.
2. Verify hash and compare with last-applied hash.
3. Skip with a logged success when unchanged.
4. Back up/stop only what the contract requires.
5. Replace the complete target tree when specified.
6. Verify file inventory/hash and application health.
7. Persist the applied hash.
8. Restore backup on a failed post-replacement check where the design supports rollback.

### Import and test-path repair

1. Reproduce with `python -m pytest -q` from repository root.
2. Inspect package layout and `pytest.ini`/`pyproject.toml`.
3. Fix packaging/import configuration, not each test's `sys.path` independently.
4. Verify application imports and tests from a clean shell.
5. Document the stable command.

### Acceptance matrix

| Area | Acceptance evidence |
| --- | --- |
| Setup | Clean PowerShell setup/import commands |
| UI | Navigation and state persist without re-extraction |
| Worker | Progress, success, failure, retry/recovery transitions |
| SQL | Parameterisation, validation, approval, transaction behaviour |
| Exports | CSV/Excel/report files exist and validate |
| Time | Exact required string and no unintended timezone changes |
| Integrations | Mocked versus live-tested status clearly separated |
| Packaging | No `.venv`, secrets, cache, local DB, or logs |
