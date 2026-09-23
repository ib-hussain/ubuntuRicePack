# AGENTS.md — Fin-Glassbox

## Project identity

This repository belongs to **Ibrahim Hussain** and collaborators. Ibrahim is a BS Data Science student. The project is known as **Fin-Glassbox**, **Explainable Distributed System for Finance**, and in formal documentation as **An Explainable Multimodal Neural Framework for Financial Risk Management**.

Apply only Fin-Glassbox context here. Do not import details from DeepDocForgery, UbuntuRicePack, physics/teaching work, Ali Asad, German/Vienna conversations, IoT/electronics, Montessori/school work, or other users.

## Mission

Build a leakage-safe, reproducible, explainable multimodal financial-risk system that combines market history, SEC filing text, macroeconomic context, and cross-asset graph evidence. The deterministic analytical pipeline must produce structured recommendations, risk/confidence/position information, and traceable explanations. A small language model may narrate those outputs but must not make or alter the financial decision.

This is a research and decision-support system, not personalised financial advice.

## Authoritative precedence

When information conflicts, use this order:

1. Current user correction.
2. Current repository code, configuration, data schemas, tests, and produced manifests.
3. Project `AGENTS.md`, `SKILLS.md`, and the durable decisions in `MEMORY.md`.
4. Dated status snapshots in `MEMORY.md`.
5. Old chat descriptions, archived reports, and superseded diagrams.

Never silently choose between conflicting historical artifacts. Inspect and state the evidence.

## Canonical system boundaries

### Active input streams

- Market data.
- SEC text/filing subset.
- Macroeconomic FRED features.
- Cross-asset graph information.

### Removed component

The **Fundamental Analyst/branch is removed**. Do not reintroduce it in code, diagrams, feature counts, fusion inputs, UI panels, documentation, or tests unless Ibrahim explicitly changes this decision.

### Encoders and evidence modules

- A temporal attention encoder using approximately 30-day market windows.
- A FinBERT text path, historically fine-tuned with masked language modelling and designed to allow a future supervised mode.
- FinBERT hidden representations are reduced from 768 to 256 dimensions with PCA fitted on the training partition only.
- Cross-asset graph modelling for contagion/regime evidence; historical work adapted StemGNN/MTGNN-style ideas away from plain forecasting.
- Risk modules covering volatility, drawdown, VaR, CVaR, liquidity, contagion, and regime risk.

### Analysts and decision path

The retained qualitative/analytical roles are Technical, Sentiment, and News. Position sizing and quantitative/risk evidence feed a learned fusion path. The canonical decision order is:

1. Prepare/load frozen upstream representations and model outputs.
2. Run position sizing and qualitative analysts as required by the selected mode.
3. Run the frozen Quantitative Analyst where applicable.
4. Run the learned FusionEngine/MLP.
5. Apply the deterministic rule barrier/constraints.
6. Emit final recommendation, signal, risk, confidence, position, flags, and structured XAI fields.
7. Optionally use Qwen3-0.6B to narrate the already-determined result.

The rule barrier is not a training label postprocessor to be hidden inside the model. Preserve learned output and rule-adjusted output separately enough to audit the difference.

## Temporal split policy

Use leakage-safe chronological chunks:

- C1: 2000–2006, historically train 2000–2004, validation 2005, test 2006.
- C2: 2007–2016, historically train 2007–2014, validation 2015, test 2016.
- C3: 2017–2024, historically train 2017–2022, validation 2023, test 2024.

These boundaries are durable unless current configuration explicitly changes them. All fitted transformations—including scalers, PCA, feature selection, calibration, and threshold selection—must respect the training boundary. Never use validation/test records to fit preprocessing.

## Data and artifact contracts

- Preserve stable identifiers such as date, ticker/entity, chunk, split, and source row/document linkage through every stage.
- Prefer `.npy` arrays plus CSV metadata for FinBERT embeddings. Parquet was explicitly rejected for that path.
- Validate row alignment between embeddings and metadata, chronological membership, dimensionality, dtype, finite values, and expected counts.
- Treat raw acquisition coverage and the final cleaned modelling panel as different datasets. Do not combine their ticker counts or completeness claims.
- Do not hard-code historical counts into logic. Read manifests and current files.
- Keep datasets, cached embeddings, experiment outputs, checkpoints, HPO databases, and logs out of ordinary Git. Respect existing Git LFS tracking for intentionally versioned large artifacts.
- `.env` remains local and uncommitted.

## Resumability and long-running work

Preparation, encoding, HPO, training, evaluation, fusion generation, and inference must be resumable where they are expensive.

- Fingerprint data sources/manifests, split definitions, relevant configuration, preprocessing, and model architecture.
- Use atomic state/checkpoint writes.
- Keep latest and best checkpoints when both are useful.
- Checkpoint payload compatibility must accept deliberate historical key variants such as `state_dict`, `model_state_dict`, or `model_state`, while normalising to one internal representation.
- Persist Optuna/TPE studies in stable storage, typically SQLite, with stable study names and configuration fingerprints.
- Resume only compatible work. Refuse stale/incompatible state with a clear recovery command.
- Store preprocessing objects needed for inference, including Quantitative Analyst and FusionEngine scalers/PCA/feature order.

## Environment and command rules

- Primary historical training environment: Ubuntu 22.04, Python 3.12.7, 6 cores/12 threads, 64 GB RAM, RTX 3090 Ti with approximately 24 GB VRAM.
- Development and repository recovery may occur in Windows/PowerShell or WSL.
- Detect actual current driver, CUDA, PyTorch, storage, processes, and available memory before choosing settings.
- Use `tmux` for long remote runs and persist logs outside the terminal session.
- Ibrahim requires copyable **single-line commands**. Never format one command as a backslash-continued multi-line block.
- Use the established virtual environment and explicit `python` interpreter.
- Do not print or persist credentials, host secrets, tokens, or `.env` content.

## Performance rules

- Measure before changing performance settings.
- Low GPU utilisation may come from dataloading, tokenisation/preprocessing, disk I/O, undersized batches, CPU limits, or competing GPU processes. Diagnose these before altering the model.
- Use safe worker counts and pinned/persistent loading only when measured and supported.
- Record CPU/RAM and GPU utilisation/VRAM during long runs.
- Any temporary performance-mode scripts must save the original CPU/GPU state and provide a verified restore path.

## Inference and UI modes

Preserve three conceptual modes:

- Historical replay.
- Frozen-cached Type B.2 inference.
- Manual frozen inference.

The UI must always expose transparency and support:

- a concise user-friendly result;
- a full-system explanation;
- per-module outputs in a sidebar or equivalent detail view;
- raw structured JSON for audit/debugging.

Do not let the narrator invent missing evidence. Narration must be grounded only in the structured deterministic output and must preserve uncertainty and flags.

## Validation ladder

For every material change:

1. Check imports/syntax and configuration parsing.
2. Run focused unit tests.
3. Validate a representative data batch and its temporal membership.
4. Run a small stage smoke test.
5. Test checkpoint/HPO resume where touched.
6. Run a small end-to-end path through fusion, rule barrier, XAI, and final schema.
7. Run the affordable full test suite.
8. Inspect output counts, 104-column or current schema, missing/finite values, class distribution, and stable identifiers.
9. Inspect `git diff`, `git status`, LFS pointers, and archive contents.

Never report a deployment, GPU run, LFS download, external data source, or integration as verified unless actually exercised.

## Git, recovery, and release safety

- Repository: `ib-hussain/fin-glassbox`, normally branch `main`.
- Verify repository-local commit identity for Ibrahim Hussain before committing; do not inherit an incorrect global identity.
- Preserve definitive files before merge/recovery operations. Historical recovery identified `code/deploy.py`, `code/inference.py`, `Paper.docx`, and local `.env` as especially important, but current repository state must be inspected.
- If Windows locks or a failed merge make the checkout unsafe, prefer a fresh clone of `main`, deliberate copying of known-good files, tests, and a clean diff. Restore `.env` locally only; never commit it.
- Diagnose Git LFS clone/deploy failures before treating them as application startup failures.
- Releases and source bundles are code-only unless explicitly requested otherwise.

## Documentation rules

- Use British English.
- Root `README.md` is an informational introduction: purpose, architecture, module families, links, team, and stable usage. It must not contain progress, done/not-done checklists, or temporary status.
- `SETUP.md` holds environment and installation instructions.
- Distributed module docs hold model/data details; workflow and XAI deserve dedicated documents.
- Dated training results and operational state belong in `MEMORY.md`, run reports, or experiment logs.
- Include the full project team and accurate contacts only from current repository/user-provided information.
- Do not invent citations, metrics, hyperparameters, or completion claims.

## Definition of done

A change is done only when the intended path works, temporal/data leakage constraints hold, resume behaviour remains valid, actual tests/smokes are reported, documentation matches implementation, secrets/data/generated artifacts are excluded, and the requested artifact is produced from the verified tree.

## Non-negotiable architectural invariants

1. **The Fundamental branch is removed.** A stale file, diagram, CSV column, prompt, or checkpoint does not authorise its return.
2. **No Bull/Bear debate framework.** The active design uses specialised analysts, risk modules, learned fusion, a rule barrier, and structured XAI. Do not insert LangChain orchestration or debating agents into the decision path.
3. **Learned weighting comes before rules.** Preserve the learned FusionEngine output and then apply the deterministic user-configurable barrier.
4. **Narration comes last.** Qwen3-0.6B describes structured output; it does not generate the recommendation, risk, confidence, or position.
5. **Time is part of every contract.** Feature availability, split membership, training-only fitting, label horizon, and replay/as-of inference must all be leakage-safe.
6. **Frozen inference means frozen.** Do not refit a scaler/PCA/model/threshold on a selected demo row or test period.
7. **Transparency is not optional.** The later UI correction removed the transparency control and requires full transparency to remain accessible.
8. **Artifact identity matters.** Never mix an encoder/checkpoint/scaler/PCA/schema/cache from incompatible runs merely because filenames match.

## System topology in more detail

### Market/temporal path

The market pipeline begins with normalised OHLCV/corporate-action records, creates leakage-safe engineered features/windows, applies training-fitted preprocessing, and encodes approximately 30 trading days through the Temporal Attention Encoder. Preserve date/ticker/as-of identity through the tensor and output.

### SEC/FinBERT path

SEC filings/submissions are filtered and chunked into traceable text records. The historical FinBERT design supports:

- MLM fine-tuning;
- an approved `mlm_then_supervised` path;
- labels derived from post-filing market outcomes with explicit anti-leakage rules;
- persistent Optuna/TPE HPO;
- CUDA/parallel processing;
- epoch checkpoints and resume;
- frozen and unfrozen exports;
- three chronological chunks;
- 768-dimensional hidden representations reduced to 256 by training-only PCA;
- `.npy` arrays with CSV metadata.

The intended command surface historically included concepts such as `build-labels`, `train-mlm`, `train-supervised`, `hpo`, `embed-all`, and `freeze`. Inspect the current CLI before using these names verbatim.

### Macro path

FRED features must be joined according to what would have been observable at the as-of date. Record series IDs, frequency, transformations, release/revision assumptions, missingness policy, and alignment method. Do not treat a modern revised historical series as automatically point-in-time correct.

### Graph path

Graph construction must state node universe, edge meaning, lookback, update cadence, normalisation, and as-of boundary. StemGNN/MTGNN-derived code was adapted for contagion and market-regime evidence; do not evaluate it only as a price forecaster or silently use future correlations.

### Analyst path

- **Technical Analyst:** consumes market/temporal evidence and emits named recommendation/confidence/explanation fields.
- **Sentiment Analyst:** consumes applicable textual/sentiment evidence with explicit text-availability behaviour.
- **News Analyst:** emits its distinct evidence/score/flags and historical evaluation used F1 in at least one snapshot.
- **Qualitative stage:** combines or structures relevant qualitative outputs without becoming an untraceable second fusion engine.
- **Quantitative Analyst:** attention-based aggregation of risk evidence, with persisted scaler/feature order and explicit attention-derived output fields.
- **Position Sizing:** provides an independent risk-aware cap/recommendation used by the final position rule.

### Risk path

Every risk module must document units, horizon, input availability, expected range, missing-data behaviour, and whether its output is a score, probability, amount, classification, or flag. Do not combine differently scaled risks without the declared preprocessing/attention/fusion contract.

### Fusion and barrier path

The learned fusion output is computed first. The barrier then applies user-configurable constraints. The final position decision follows the established conservative cap:

```text
final_position = min(
    position_sizing_recommendation,
    learned_position_suggestion,
    user_rule_cap
)
```

Preserve each operand, the selected minimum/capping reason, and relevant barrier flags in output. Do not overwrite the learned suggestion so completely that auditing becomes impossible.

## Quantitative schema guard

Reject a stale Quantitative Analyst output schema that omits the attention evidence required by the later design, including fields in the families:

- `top_attention_risk_driver`;
- `attention_pooled_risk_score`;
- `risk_attention_*`.

Validate exact current column names from code/schema. A CSV that has the right row count but an older feature set must not enter fusion.

## Data-source scale and provenance

Historical source scale included:

- more than 900,000 SEC submissions JSON records/files in the broader processing corpus description;
- more than 17 GB of SEC company-facts data;
- more than 300,000 raw filing documents;
- a raw market acquisition audit spanning 4,534 requested tickers;
- a final cleaned modelling panel described as 2,500 stocks × 6,286 trading days with zero missing values after the project's filling/feature-engineering process.

These numbers describe different stages/universes. Do not merge them. Current manifests and documentation must name the stage, filters, date bounds, and artifact identity behind every count.

## Market acquisition failure history as a design rule

An early audit failed for 6,859 tickers because a local `data/yfinance.py` shadowed the installed `yfinance` module. This is a reminder to:

- inspect `module.__file__` when an import behaves implausibly;
- avoid naming local modules after third-party packages;
- test one ticker through the exact acquisition environment before a large audit;
- distinguish source unavailability/listing history from downloader failure;
- retain the custom `yfinance_ib` path only if it is the current intentional adapter.

Never interpret “zero successful downloads” across an entire universe as evidence that every ticker is unavailable before checking the import/runtime path.

## Label construction and as-of semantics

For supervised text or decision labels:

- define the filing/event timestamp used;
- define market-session alignment;
- define post-event horizon and return/risk computation;
- prevent overlapping/future windows from entering input features;
- handle filings outside market hours explicitly;
- preserve label version and thresholds;
- generate labels before training through a reproducible command/stage;
- keep test labels unavailable to fitted preprocessing/HPO.

## Artifact manifest standard

Every trained or derived component should be identifiable through a manifest containing:

- component/module and version;
- commit/diff identity;
- resolved config and hash;
- data/manifest/split fingerprint;
- training period/chunk;
- preprocessing identities and feature order;
- checkpoint/model/scaler/PCA paths and hashes;
- metric-selection policy and selected metric;
- output schema version;
- compatible upstream/downstream artifact versions;
- environment/device summary;
- creation/completion status.

Inference should resolve one compatible artifact set rather than search the filesystem for the first `final_model.pt`.

## Checkpoint and model-loading policy

- Normalise historical payload keys (`state_dict`, `model_state_dict`, `model_state`) through a deliberate loader.
- Validate expected model class/config and parameter key compatibility.
- Do not default to `strict=False` and ignore missing/unexpected keys without a reviewed compatibility rule.
- Persist/reload scalers, PCA, feature lists, label mappings, thresholds, and rule configuration.
- Distinguish `latest_checkpoint.pt`, `best_checkpoint.pt`, `final_model.pt`, and epoch checkpoints by purpose.
- Do not delete intermediate recovery checkpoints from a running environment merely because the source release excludes them.

## UI requirements after later corrections

The later accepted UI direction supersedes earlier configurable-control designs:

- Qwen narrator is fixed to the packaged Qwen3-0.6B path/model.
- Package the full required model/artifact set for the intended deployment.
- Do not expose repository-root, chunk, device, split, or transparency controls in the user-facing UI.
- Deployment operators may still configure launch/runtime details outside the ordinary user controls.
- Always expose full transparency: final result, all model/module outputs, XAI/risk drivers, flags, and raw JSON/detail views.
- Use longer explanation context where supported, while grounding it strictly in deterministic structured output.
- If narration fails, the deterministic model outputs and explanations remain usable.

Historical Streamlit launch commands exposed `--repo-root`, `--device`, `--default-chunk`, and `--default-split`; those are operator/launch concerns, not user-facing controls.

## Cached Type B.2 packaging

The historical frozen deployment package expected a consistent set such as:

- `code/inference.py`;
- `code/deploy.py`;
- Qwen directory under `outputs/models/Narrator/Qwen3-0.6B`;
- Quantitative Analyst chunk-3 `final_model.pt` and `scaler.npz`;
- FusionEngine chunk-3 `final_model.pt` and `scaler.npz`;
- compatible cached chunk-3 validation/test CSVs;
- cached outputs for upstream analysts/risk modules;
- current schemas/feature-order metadata.

Exact current paths must come from code/config. Verify every LFS object is materialised rather than a pointer.

## Output schema quality gates

For each fused output:

- schema version and exact column set;
- unique date/ticker key where expected;
- row count versus input/join manifests;
- chunk/split membership;
- finite-value checks;
- categorical domain checks;
- learned output and post-barrier output;
- all three position operands/cap reason;
- module availability flags such as `text_available`;
- confidence/risk range semantics;
- attention/risk-driver fields;
- XAI fields and raw structured record;
- recommendation distribution and extreme imbalance alert;
- no duplicate/Cartesian join expansion.

Do not use a silent inner join that drops missing-module rows. Make the missing-data policy explicit.

## Metric interpretation

- Tie metrics to artifact, chunk, split, and code/config.
- Separate module metrics from final decision distribution.
- A 49% technical accuracy or 31.76% sentiment accuracy is not automatically good/bad without class/task baselines.
- A near-perfect News F1 snapshot must still be checked for split/label leakage and class definitions.
- A VaR95 breach near 5% may be a calibration diagnostic, not an ordinary classification score.
- An all/mostly-HOLD final distribution may reflect thresholds/rules/data, but must be investigated rather than “balanced” by arbitrary relabelling.
- Three SELL rows out of hundreds of thousands is an alert for schema/threshold/rule audit, not permission to force more SELL outputs.

## Deployment failure taxonomy

Diagnose in order:

1. repository clone/access;
2. Git LFS pointer/object retrieval/quota;
3. archive/artifact completeness;
4. Python environment/dependencies;
5. path/config/secrets;
6. checkpoint/scaler/schema compatibility;
7. app startup;
8. inference execution;
9. UI rendering/narration.

If clone/LFS fails, the application never started. Do not change Streamlit logic to fix it.

## Large-artifact discipline

A historical LFS upload showed 18–19 GB at roughly 9%, implying an extremely large total push. Before pushing large artifacts:

- inventory file counts/sizes and total bytes;
- inspect `.gitattributes` and pointer status;
- run LFS dry-run/status checks;
- confirm hosting quota and deployment feasibility;
- decide whether the artifact belongs in version control, a release/model store, or reproducible external storage;
- use `tmux` for authorised long remote uploads and verify completion.

Do not commit hundreds of gigabytes merely because LFS accepts the file extension.

## Git recovery evidence

The historical Windows worktree reached `MERGING`, failed to unlink files, and contained LFS pointer errors. Commands such as merge abort/reset could not repair it safely. The chosen clean-clone recovery is now a durable incident pattern: stop destructive retries, preserve definitive files externally, clone `origin/main`, deliberately copy only intended files, test/diff, restore local `.env`, and commit/push with verified identity.

## Documentation architecture

Maintain a coherent map rather than multiple contradictory generations:

- `README.md`: stable overview, architecture families, team, links, high-level run path—no progress checklist.
- `SETUP.md`: environments, data/artifact prerequisites, installation, launch.
- `WORKFLOW.md`: stage order, data/artifact movement, resumability.
- encoder/analyst/risk/fusion docs: exact interfaces and methods.
- XAI documentation: structured fields, drivers, barrier reasoning, narrator constraints.
- `MEMORY.md` or run reports: dated counts, metrics, incidents, current verification status.

Do not recreate deleted superseded diagrams/papers/config documents without evidence that they are current.

## Security and financial-use boundaries

- Never store API keys, deployment secrets, private SSH keys, or `.env` in source/release.
- Avoid logging sensitive source documents or tokens.
- Keep deterministic outputs and provenance available for audit.
- State that the system is research/decision support, not personalised financial advice.
- Do not let narrator fluency obscure uncertainty, missing text, stale artifacts, or rule overrides.
