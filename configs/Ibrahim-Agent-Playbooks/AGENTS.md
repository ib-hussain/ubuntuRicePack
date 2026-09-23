# AGENTS.md Templates — Ibrahim Hussain

> These templates encode the working conventions developed through Ibrahim Hussain's Linux/Ubuntu, AI/ML, agentic-system, local-LLM, automation, repository-recovery, DeepDocForgery, and Fin-Glassbox work.
>
> They are deliberately stricter than a generic coding-agent instruction file.

---

# VERSION A — GENERAL `AGENTS.md`

```markdown
# AGENTS.md

## Owner

This repository belongs to **Ibrahim Hussain**, BS Data Science.

Relevant engineering context includes:

- AI/ML and deep-learning systems
- agentic and multi-agent architectures
- explainable AI
- computer vision
- financial ML
- Linux and Ubuntu engineering
- GNOME Shell customisation
- Windows/PowerShell automation
- local LLMs and Ollama
- repository automation
- reproducible ML pipelines
- resumable long-running workloads


---

## 1. Core Engineering Philosophy

Work **repository-first**.

Never begin by inventing an architecture, file structure, command, interface, or implementation that has not been verified against the repository.

Before modifying anything:

1. inspect the repository;
2. understand the existing conventions;
3. inspect relevant configuration;
4. inspect tests;
5. inspect recent or related implementations;
6. reproduce the problem where possible;
7. determine the smallest coherent fix;
8. implement it without unnecessarily restructuring unrelated code;
9. do not make assumptions but rather ask about anything not specified or anything you are unsure about.

The existing repository is the primary source of truth.

Conversation history is secondary.

Assumptions are last.

---

## 2. Do Not Rebuild What Already Exists

Do not casually replace working subsystems with new implementations.

Prefer:

- adapting existing code;
- extending established abstractions;
- reusing current checkpoint/state formats;
- preserving existing configuration;
- preserving existing interfaces;
- preserving relative paths;
- preserving generated state when compatible.

If something is already partially implemented, finish or repair it rather than creating a parallel implementation.

Deleted repository files are not automatically mistakes. Treat deliberate deletions as intentional unless evidence shows otherwise or specified by user.

---

## 3. Changes Must Be Integrated

Do not implement isolated fragments while leaving the actual workflow broken.

A change is incomplete if:

- the function exists but is never wired into execution;
- configuration exists but is not consumed;
- checkpointing exists but resume does not work;
- a UI control exists but backend behaviour is unchanged;
- training works but inference cannot load the model;
- a script works independently but the main pipeline fails;
- tests cover helper functions but the integrated execution path fails.

Implement end-to-end behaviour.

---

## 4. Preserve User Work

Treat existing user data, local changes, models, outputs, datasets, checkpoints, configuration, `.env` files, and Git history as valuable.

Avoid destructive commands unless absolutely necessary and explicitly justified.

Especially avoid blindly recommending and never even try:

    git clean -fd
    git clean -fdx
    git reset --hard
    rm -rf
    forced repository replacement

Before destructive recovery:

1. inspect;
2. identify what would be lost;
3. back up ALL files;
4. distinguish tracked, ignored, untracked, generated, and external data;
5. only then modify state BUT EXPLICITLY WARN USER AND TRY YOUR BEST TO NOT DELETE ANYTHING EVER.

`.env` files stay local unless the repository explicitly says otherwise.

Never commit secrets.

---

## 5. Git Workflow

Prefer safe Git workflows.

Before changes, inspect:

    git status
    git branch --show-current
    git log --oneline --decorate -n 15
    git diff
    git diff --cached
    git remote -v

When large files are involved, also inspect:

    git lfs ls-files

Do not assume Git LFS is configured correctly merely because large files exist.

Before pushing large repositories, inspect:

- file count;
- largest files;
- total change size;
- LFS pointer status;
- whether generated outputs are accidentally staged.

Avoid force-push unless the specific operation genuinely requires history rewriting and the consequences are understood.

When recovery becomes more dangerous than reconstruction of the worktree, prefer:

1. secure irreplaceable local files;
2. obtain a known-good clean checkout;
3. restore only definitive files;
4. verify;
5. commit intentionally.

---

## 6. Shell and Command Style

Commands must be executable as provided.

### PowerShell

Prefer native PowerShell where available.

Prefer:

    ssh
    scp
    git
    python
    pip

over unnecessary third-party wrappers such as `plink` or `pscp`.

Give commands with explicit paths where ambiguity is possible.

Do not provide Bash syntax disguised as PowerShell.

### Linux

Prefer robust Bash scripts over PowerShell if working on Windows as WSL is always available in Arch and fallback is Ubuntu.

Scripts should:

- fail clearly;
- log useful context;
- validate required files;
- be safe to rerun;
- avoid destructive implicit behaviour;
- handle partial completion;
- be idempotent, even with a rerun nothing bad happens so they can rerun in order to redo anything or if a run fails then the next fixed run doesnot and completes the task that the previous run didnot complete;
- produce actionable error messages.

### CLI formatting

When a command is intended to be copied directly, prefer a **single-line command** unless multiline syntax is VERY necessary.

Do not use backslash-separated multiline CLI commands.

---

## 7. Debugging Method

Debug from evidence, not intuition.

When terminal output is supplied:

- read it exactly;
- identify the first meaningful failure;
- separate root cause from downstream errors;
- use actual paths, package versions, stack traces, and state;
- do not answer with generic troubleshooting if the logs already identify the problem.

Do not reassure the user that something is fixed until verification supports that conclusion.

If a previous fix failed, reconsider the diagnosis rather than repeating the same fix in different wording.

---

## 8. Testing Rules

Testing is part of implementation.

At minimum:

1. run targeted tests for modified behaviour;
2. run related module tests;
3. run the repository test suite where practical;
4. run syntax/static validation relevant to the stack;
5. test the actual integration path;
6. report exactly what was executed and what passed or failed.

Examples include:

    python -m pytest -q
    python -m py_compile
    bash -n script.sh
    smoke tests for ML/DL works

For GNOME/repository tooling, also validate schemas, JavaScript, configuration parsing, and dry-run modes where applicable.

Do not claim dynamic CUDA behaviour was verified if only CPU/static tests were run.

Clearly distinguish:

- statically verified;
- unit tested;
- integration tested;
- GPU tested;
- manually inspected;
- not yet verified.

---

## 9. ML / AI Engineering Rules

For machine-learning repositories, correctness includes the entire lifecycle:

    raw data
      ↓
    preparation
      ↓
    split construction
      ↓
    preprocessing fitted on training data
      ↓
    training
      ↓
    checkpointing
      ↓
    evaluation
      ↓
    inference
      ↓
    explainability
      ↓
    deployment

Avoid leakage.

Fit learned preprocessing only on the permitted training split.

Preserve chronological ordering for temporal datasets unless the project explicitly specifies otherwise.

Do not generate dummy data, fake embeddings, synthetic labels, or placeholder model outputs in production paths.

If synthetic fixtures are needed for tests, keep them clearly test-only.

---

## 10. Resumability Is a First-Class Feature

Long-running work must not assume a clean restart.

Preparation, training, HPO, evaluation, and other expensive stages should support recovery where feasible.

Prefer:

- atomic state writes;
- latest checkpoints;
- epoch checkpoints;
- stage journals;
- fingerprints;
- manifests;
- locks where concurrency matters;
- partial-progress metadata;
- explicit resume commands;
- validation before reusing cached state.

A resume mechanism is not complete merely because a checkpoint file exists. Write the commands for resuming/running/using the file and it's arguments at the bottom or start of file in docstrings. If you right at the top, then make it such that it comes at the end of the file's docstring.

It must restore enough state to continue correctly.

---

## 11. Generated Artifacts

Keep source data and generated artifacts conceptually separate.

Generated outputs should normally include:

- checkpoints;
- logs;
- manifests;
- caches;
- predictions;
- evaluation results;
- HPO databases/results;
- inference outputs;
- telemetry;
- temporary state.

Do not package large datasets into code-only archives.

When the repository defines `data/` for source input and `output/` for generated work, obey that separation consistently.

---

## 12. Compatibility

Do not fix one environment by unnecessarily breaking another supported environment.

When relevant, explicitly account for:

- Windows;
- PowerShell;
- Linux;
- WSL;
- Arch Desktop;
- Ubuntu Desktop;
- headless Ubuntu;
- CPU-only environments;
- CUDA environments.

Detect capabilities rather than assuming them when practical.

CPU support may be intentionally limited for very expensive ML workloads, but imports, configuration checks, small smoke tests, and diagnostics should remain usable where reasonable.

---

## 13. Dependencies

Prefer minimal dependencies.

Use native platform capabilities where practical.

Do not introduce a dependency merely to avoid writing a small amount of straightforward code.

When changing dependencies:

- check compatibility;
- check Python version(Global python version=3.12.7);
- inspect transitive conflicts;
- update requirements/lock files consistently;
- verify imports.

---

## 14. Configuration

Centralise configuration rather than spreading magic constants throughout the code.

Configuration should be:

- explicit;
- discoverable;
- validated;
- versionable where appropriate;
- overrideable where appropriate.

Do not silently ignore invalid configuration.

---

## 15. Logging

Logs must help diagnose failures.

Useful logs identify:

- stage;
- input;
- output;
- state/checkpoint used;
- device;
- important dimensions/counts;
- resumed vs fresh execution;
- failure reason.

Avoid meaningless verbosity.

Preserve detailed logs for long-running jobs.

---

## 16. Documentation

Documentation describes the system, not the conversation used to create it.

Root documentation should normally explain:

- purpose;
- architecture;
- repository structure;
- setup;
- execution workflow;
- important design decisions;
- outputs;
- limitations;
- links to deeper documentation.

Do not fill a permanent README with temporary statements such as:

- "currently working on";
- "done";
- "not done";
- "next we will";
- progress-chat summaries.

Use dedicated development notes if progress tracking is required.

Use **British English** in project documentation unless an existing project standard requires otherwise.

---

## 17. Reports

When producing an engineering report:

- explain the real architecture;
- avoid unnecessary theoretical padding;
- distinguish authored code from external models/tools;
- explain AI usage clearly;
- include setup/execution instructions when requested;
- preserve the user's own design decisions.

Architecture diagrams should be as simple as the task permits.

---

## 18. UI / UX Implementation

When a supplied HTML mock-up or reference implementation exists, treat it as a behavioural and visual specification.

Do not approximate major interaction behaviour simply because the production toolkit differs.

First identify:

- which behaviours translate directly;
- which CSS/browser capabilities are unavailable;
- which effects require a GNOME/native implementation;
- what fallback best preserves the intended behaviour.

Explicitly document unavoidable platform differences.

---

## 19. Agent Behaviour

An AI coding agent working for Ibrahim should:

- inspect before editing;
- reason from repository evidence;
- continue existing work instead of restarting;
- preserve user choices from earlier stages;
- avoid asking questions already answered;
- make best-effort progress when context is sufficient;
- make coherent changes rather than toy patches;
- verify its work;
- state residual uncertainty precisely.

Never invent repository contents.

Never claim a test passed unless it actually ran successfully.

Never claim a problem is solved based only on code inspection when runtime verification is required.

---

## 20. Deliverables

When asked for modified files or an archive:

- preserve repository-relative paths;
- include exactly what was requested;
- if requested, provide only changed files rather than the full repository;
- exclude datasets and generated artifacts from code-only packages;
- verify archive contents before delivery.

---

## Definition of Done

A task is done only when:

1. the root cause or requirement is understood;
2. the implementation is integrated;
3. existing functionality is preserved unless intentionally changed;
4. relevant tests pass;
5. the real execution path has been checked where practical;
6. generated/state behaviour is correct;
7. documentation/configuration is updated where needed;
8. the final response explains what changed and what remains unverified.

"Code was written" is not equivalent to "task completed."
```

---

# VERSION B — AI / ML / DEEP-LEARNING `AGENTS.md`

```markdown
# AGENTS.md — AI/ML Systems

## Owner

Ibrahim Hussain — BS Data Science.

This repository should be treated as an engineering/research system, not a notebook experiment.

## Prime Directive

Preserve reproducibility, leakage safety, resumability, traceability, and deployability.

Before implementing any ML change, inspect:

- dataset structure;
- manifests;
- split construction;
- preprocessing;
- models;
- checkpoints;
- training entrypoints;
- evaluation;
- inference;
- tests;
- configuration;
- output/state directories.

Do not modify a model architecture without understanding what downstream code consumes its outputs.

## Data Discipline

Never silently alter:

- label semantics;
- temporal boundaries;
- sample identities;
- tensor shapes;
- metadata alignment;
- masking semantics.

Maintain explicit provenance.

Do not invent missing observations.

Distinguish genuinely absent historical data from processing failures.

Where chronological data is used, prevent future information from leaking into:

- imputers;
- scalers;
- PCA;
- threshold generation;
- graph construction;
- feature normalisation;
- label construction.

## Model Lifecycle

Every major model should have a lifecycle equivalent to:

    prepare
    → train
    → validate
    → checkpoint
    → resume
    → evaluate
    → freeze/export
    → inference

Training and inference must agree on:

- architecture;
- feature ordering;
- dimensionality;
- preprocessing;
- state-dict naming;
- label mapping.

Checkpoint loaders should tolerate documented historical formats where practical, but new checkpoints should use one canonical format.

## HPO

Hyperparameter optimisation must be connected to the real training path.

Do not build an HPO script that optimises a toy model different from production training.

Persist:

- study state;
- trial configuration;
- result metric;
- best parameters.

Make HPO resumable.

## GPU Engineering

Use CUDA where intended.

Optimise only after measuring.

Potential bottlenecks include:

- storage;
- preprocessing;
- dataloader workers;
- host RAM;
- CPU transforms;
- batch size;
- multiple competing jobs;
- model compute;
- VRAM.

Do not attribute slow training to "GPU settings" without evidence.

## Checkpoints

Save checkpoints atomically.

For long training runs, preserve at least:

- latest recoverable state;
- periodic/epoch checkpoints where appropriate;
- best validation checkpoint where appropriate.

Resume should recover relevant:

- model state;
- optimiser;
- scheduler;
- epoch/step;
- scaler for AMP;
- RNG state where reproducibility requires it;
- sampler/progress state when feasible.

## Outputs

Keep generated data structured and predictable.

Prefer:

    output/
      checkpoints/
      logs/
      manifests/
      predictions/
      evaluation/
      hpo/
      state/
      xai/

Do not scatter generated files throughout source directories.

## Testing

Tests should cover:

- tensor shapes;
- forward pass;
- checkpoint save/load;
- resume;
- preprocessing consistency;
- CPU smoke path where applicable;
- CUDA path where hardware is available;
- inference compatibility;
- malformed input handling.

Do not confuse a smoke test with scientific validation.

## Explainability

If the system claims explainability, preserve raw model evidence before narration.

Explanations should be based on actual model signals such as:

- attention;
- gradients;
- risk contributions;
- feature importance;
- graph importance;
- rule traces;
- intermediate predictions.

An LLM narrator may explain model output, but should not silently replace the decision engine unless the architecture explicitly says so.

## Documentation

Record:

- data assumptions;
- split boundaries;
- model interfaces;
- feature dimensions;
- training commands;
- evaluation metrics;
- checkpoint format;
- inference contract.

Prefer concise technical precision over marketing language.
```

---

# VERSION C — LINUX / UBUNTU / GNOME `AGENTS.md`

```markdown
# AGENTS.md — Ubuntu / GNOME Engineering

## Owner

Ibrahim Hussain.

The target is a reproducible, repository-controlled Ubuntu desktop configuration.

## General Rules

The repository is not a collection of ad-hoc dotfiles.

Treat it as a deployment system.

Installation must be:

- modular;
- idempotent;
- recoverable;
- logged;
- testable;
- compatible with the supported Ubuntu versions;
- safe on partially configured machines.

## Package Policy

Prefer packages obtainable from official Ubuntu sources when possible.

Do not introduce Snap-based dependencies into a configuration that intentionally avoids Snap.

Do not assume Firefox/Snap availability.

## Modes

Where supported, preserve distinct operating modes such as:

    --mode desktop
    --mode wsl

Do not execute GNOME-specific actions blindly inside WSL/headless environments.

Detect environment capabilities.

## Script Architecture

Prefer numbered stages such as:

    scripts/
      01-install-packages.sh
      02-restore-themes-and-configs.sh
      03-setup-terminal.sh
      04-setup-extensions.sh
      05-apply-gnome-settings.sh
      ...

Each step should:

- be individually understandable;
- validate prerequisites;
- fail clearly;
- support rerunning;
- avoid corrupting later stages;
- write meaningful logs.

Use a common runner/helper rather than duplicating control flow.

## GNOME Settings

Before applying settings:

- confirm schema exists;
- confirm key exists;
- validate expected value type;
- preserve settings that are intentionally outside repository control.

Provide dry-run/strict validation where practical.

Back up user configuration before wholesale replacement.

## Extensions

Do not run conflicting dock implementations simultaneously.

For example, Ubuntu Dock and an independent Dash-to-Dock instance must not both control the same UI.

Custom extensions should:

- target the intended GNOME Shell version;
- handle enable/disable cleanly;
- restore runtime modifications on disable;
- log lifecycle errors;
- avoid leaking patched state.

Prefer compatibility fallbacks when GNOME internals expose different getter/setter forms between versions.

## Mock-Up Translation

HTML/CSS mock-ups express design intent, not necessarily literal GNOME CSS capability.

Identify unsupported browser properties, such as effects GNOME St does not implement, and recreate the closest native behaviour without pretending unsupported CSS will work.

Preserve:

- spacing;
- magnification behaviour;
- icon geometry;
- running indicators;
- hover behaviour;
- roundness;
- visual hierarchy.

## Validation

Before considering a patch complete:

    bash -n <modified scripts>

Then run relevant:

- script `--help`;
- dry-run;
- strict configuration validation;
- JavaScript syntax checks;
- schema compilation/validation;
- repository tests;
- extension lifecycle checks.

For replacement packages, verify exact archive contents and preserve relative paths.

## Release Style

When Ibrahim requests a replacement ZIP containing only modified files:

- include only modified files;
- preserve original repository-relative paths;
- do not include unrelated files;
- validate the ZIP after creation.
```

---

# VERSION D — WINDOWS / POWERSHELL / AUTOMATION / LOCAL-LLM `AGENTS.md`

```markdown
# AGENTS.md — Windows Automation and Agentic Tooling

## Owner

Ibrahim Hussain.

## PowerShell

Commands must be genuine PowerShell.

Use explicit paths where useful.

Prefer native tools available on supported Windows installations:

    ssh
    scp
    git
    python

Avoid unnecessary external utilities.

When a command alters existing configuration, first determine replacement semantics:

- merge;
- overwrite;
- delete-and-recreate;
- append.

Never assume.

## Automation

Automation should be end-to-end.

A workflow should handle:

    discover state
    → validate prerequisites
    → perform operation
    → verify result
    → log outcome
    → recover/retry where appropriate

Scheduled or startup automation should be simple to operate and easy to diagnose.

## Local LLMs

When working with Ollama/Continue/local models:

- inspect actual installed models;
- inspect RAM/VRAM constraints;
- distinguish context length from output-token limit;
- avoid assigning a model a role it cannot perform;
- keep frequently used models warm/cached where practical.

Model routing should be based on task type.

Useful conceptual roles include:

- scout/repository reader;
- planner;
- coder;
- reasoner;
- reviewer.

Do not imply that an editor extension automatically performs arbitrary model-to-model handoffs unless an actual orchestration layer implements them.

## Agent Modes

Respect capability boundaries.

A read-only planning mode must not be described as though it can edit files or execute arbitrary terminal operations.

An implementation agent should always inspect repository evidence before making changes.

## Reliability

Agentic systems should support:

- explicit routing;
- retries;
- fallbacks;
- state persistence;
- error propagation;
- structured outputs;
- execution logs.

Do not hide failed sub-agent work behind a successful-looking final response.

## Verification

For application repositories:

    python -m pytest -q

Where requested:

    python -m pytest --cov=<package> --cov-report=term-missing

Run the application path or relevant smoke test after unit tests.

A green test suite is evidence, not permission to skip checking whether the requested workflow actually works.
```
