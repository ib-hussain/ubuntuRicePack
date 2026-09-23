# Ibrahim Hussain — Corrections and Recurring Engineering Patterns

This document explains why the playbooks contain their strongest rules. It is not a transcript. It consolidates repeated corrections and successful collaboration patterns from Ibrahim Hussain's software work.

## Identity correction

The most important meta-correction is that multiple people/topics have appeared in account history. Ibrahim explicitly identified himself as the BS Data Science person responsible for:

- Fin-Glassbox / Explainable Distributed System for Finance;
- DeepDocForgery;
- Ubuntu/Arch/WSL rice projects;
- PowerShell and Linux automation;
- sqlAutomation;
- Continue/Ollama/local coding assistants;
- related repositories and data-science assignments.

He explicitly is not Ali Asad, the physics teacher, or the person associated with German/Vienna, IoT/electronics, Montessori, school/lab, and unrelated work. The playbooks therefore treat identity scoping as an engineering correctness requirement.

## “Inspect the entire repository” means dependency-aware inspection

Ibrahim frequently provides a repository/archive plus errors and expects the agent to continue from the existing work. Problems occurred when an agent reasoned from a prompt or old archive without verifying the live tree.

Encoded rule:

- map the tree, instructions, entry points, config, tests, Git state, and relevant dependency path before editing;
- do not recreate already-implemented work;
- do not discard user changes;
- do not treat historical diagrams/status as more current than code/manifests.

## “Continue from where you left off” means integrate

Ibrahim has repeatedly added a requirement after an implementation was underway—orientation tolerance, resumability, new failure fixes, version compatibility, dock behaviour, or packaging constraints. He expects the new requirement integrated into the coherent current version.

Encoded rule:

- no parallel second mechanism;
- no pile of hotfix scripts;
- update all connected interfaces/tests/docs;
- reuse valid previous artifacts/state;
- produce the next clean version from the combined result.

## Do not claim success from partial evidence

Examples behind this rule include:

- a CSV/output had to exist, not just a “success” log;
- DeepDocForgery branches needed real supervision/gradients/evaluation, not only tensors;
- positive-only FCD could not establish binary classification;
- static GNOME checks could not prove live visual behaviour;
- mocked Teradata/Outlook paths could not be called live-tested;
- a deployment clone/LFS failure occurred before Streamlit startup;
- historical test totals could not prove a newer archive.

Encoded status vocabulary separates implementation, static validation, unit tests, smoke, integration, resume, target verification, packaging, and deployment.

## Resumability is a first-class feature

Long preparation, HPO, training, evaluation, and upload work was repeatedly interrupted or expensive. Ibrahim explicitly rejected restarting from scratch.

Encoded rule:

- state/checkpoint per expensive stage;
- fingerprints to prevent stale reuse;
- latest versus best semantics;
- persistent Optuna studies;
- atomic writes;
- status and recovery commands;
- intentional resume tests;
- `--fresh`/reset only as explicit scoped operations.

## Commands must match the active shell

Ibrahim works in:

- Windows PowerShell;
- WSL Bash/Arch;
- native/remote Ubuntu Bash;
- VS Code terminals;
- `tmux` for remote long jobs.

He explicitly asked for one-line commands and rejected backslash-separated Fin-Glassbox commands.

Encoded rule:

- label/choose the correct shell;
- never blend Bash/PowerShell syntax;
- use one copyable line per command where practical;
- use `python -m ...` through the intended environment;
- state when host-side `wsl --shutdown` is required.

## Root-cause before broad changes

Representative root causes included:

- local `data/yfinance.py` shadowing the real yfinance package;
- image/mask geometry differing by a valid 90-degree orientation;
- `next()` used on a non-iterator tqdm object;
- unrelated ROS pytest plugin auto-loading;
- Windows file locks/LFS pointer errors preventing merge recovery;
- unsupported browser CSS being carried into GNOME St;
- a silently dead pointer-watcher magnification implementation;
- an undefined PowerShell request-body variable invalidating a model benchmark.

Encoded rule:

- reproduce;
- trace to the first incorrect contract/state;
- use discriminating checks;
- patch the smallest complete interface;
- add a regression;
- re-run the original path.

## Preserve working behaviour and names

Ibrahim explicitly objected to unnecessary variable-name changes and values exact technical functionality over over-aggressive shortening.

Encoded rule:

- preserve public names/interfaces unless required;
- keep detailed installer behaviour and validation;
- do not replace a working architecture simply for stylistic uniformity;
- make migrations explicit when a rename is unavoidable.

## Full-stack completion, not isolated source edits

Successful work included more than code:

- configs and setup;
- tests and smoke paths;
- UI progress/errors;
- background worker state;
- approval gates;
- logs and reports;
- docs and exact commands;
- packaging and checksums;
- real output validation.

Encoded rule: implement a complete vertical slice and define done through observable behaviour.

## Resource-aware, profile-aware ML

Ibrahim uses small CPU development environments and larger CUDA machines. He wants maximum safe use of hardware, not blindly maximum workers/batches.

Encoded rule:

- separate CPU sample and CUDA full profiles;
- inspect live CPU/RAM/GPU/VRAM/processes;
- run one-batch probes;
- report telemetry;
- profile data/I/O/compute separately;
- distinguish CPU smoke success from full CUDA completion.

## Data leakage and evidence boundaries

Across finance and computer vision, Ibrahim repeatedly emphasised leakage-safe splits and credible claims.

Encoded rule:

- financial splits are chronological;
- transformations fit training only;
- document/image derivatives are grouped before splitting;
- label horizons and as-of availability are explicit;
- test data is not a tuning set;
- ablations and per-source/per-class metrics support architectural claims.

## Repository cleanliness and code-only releases

Ibrahim wants production-grade repositories without datasets/generated outputs in releases, especially for DeepDocForgery. He also requests changed-files-only overlays for Ubuntu work.

Encoded rule:

- code-only by default;
- no datasets, output, models, logs, HPO DBs, environments, caches, or secrets;
- include configs/tests/docs/licence/intentional fixtures;
- inspect archives;
- use replacement-only ZIPs when requested;
- test the whole repository even when packaging only changed files.

## Documentation style

Ibrahim prefers:

- practical, precise, technical writing;
- British English for repository documentation;
- README as stable introduction rather than progress tracker;
- setup/workflow/module/XAI details in dedicated docs;
- original prompts preserved verbatim when explicitly requested;
- simple but structured debugging prompts;
- explanations from his actual knowledge level, especially step-by-step CV foundations without oversimplifying the engineering.

## Project-specific corrections

### Fin-Glassbox

- Remove Fundamental Analyst.
- No Bull/Bear debaters or LangChain decision orchestration.
- Learned fusion before rule barrier.
- Final position is the minimum of PositionSizing recommendation, learned suggestion, and user cap.
- Attention-derived Quantitative schema is mandatory.
- Qwen is narrator-only.
- Later UI removes operator controls and always exposes full transparency.
- FinBERT PCA is train-only; embeddings are `.npy` + CSV, not Parquet.

### DeepDocForgery

- Support portrait/landscape 4032×2268/2268×4032 equivalently when valid.
- Put all generated state under `output/`.
- Resume every expensive stage.
- Preserve exact JPEG evidence/fallback distinction.
- Do not accept positive-only/leaky/inert/zero-loss claims.
- Isolate unrelated pytest plugins.

### UbuntuRicePack

- Post-install only; no disk/chroot/GDM branding.
- No Snap/no Firefox.
- Ubuntu Dock on Ubuntu.
- Preserve detailed behaviour, reports, idempotency, caching, rollback.
- Full repo tested; replacement-only archive delivered.
- Dock uses discrete hover scale plus spacing, dynamic radius, DOTS, and no fake backdrop blur.

### sqlAutomation

- Multi-page state must not re-run extraction.
- Show complete text, relevant records, SQL, and validation.
- Background job/polling with recoverable errors.
- Two approvals before SQL execution and sending.
- Parameterised SQL and real exports.
- Exact timestamp format with no timezone conversion.

### Continue/Ollama

- Script setup into `C:\Scripts`.
- One deterministic Ollama startup owner.
- Gemma for autocomplete, Qwen2.5-Coder for practical local coding.
- Resource-realistic model choices on approximately 12 GB RAM.
- Secrets in `.continue/.env`.
- Strong reusable ML/paper/debug/review prompts grounded in repository evidence.
