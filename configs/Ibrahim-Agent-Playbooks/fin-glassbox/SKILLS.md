# SKILLS.md — Fin-Glassbox Operating Workflows

This file contains the repeatable technical workflows used to build, debug, train, evaluate, recover, and release Fin-Glassbox. Apply the workflow matching the task, together with `AGENTS.md` and the current repository state.

## Skill 1 — Repository and environment intake

1. Confirm the repository root, branch, remote, and applicable instructions.
2. Inspect `git status`, relevant diffs, LFS status/pointers, README, SETUP, workflow/XAI docs, configs, entry points, and tests.
3. Verify repository-local Git identity before any commit.
4. Detect OS/shell, Python/venv, package versions, CPU/RAM, disk, CUDA/driver/PyTorch, GPU processes, utilisation, and free VRAM.
5. Identify the exact requested stage and preserve already-generated compatible work.
6. Use one-line Bash or PowerShell commands matching the active environment.

Exit criteria: the agent can state the current execution environment, affected module/data contract, working-tree risk, and verification plan without guessing.

## Skill 2 — Market-data acquisition and coverage audit

1. Inspect the current ticker universe, date bounds, source adapters, and existing raw/processed files.
2. Download incrementally and retry safely; do not destroy valid prior data on a partial source failure.
3. Normalise the canonical market schema, historically including `date,ticker,open,high,low,close,volume,dividends,stock_splits`.
4. Validate ordering, duplicate date/ticker rows, impossible prices/volumes, corporate-action handling, and missingness.
5. Compare requested ticker/date rectangles with locally available histories.
6. Classify missing history by evidence: source/listing availability versus downloader/pipeline failure.
7. Save a coverage report and fingerprint. Do not confuse this raw acquisition universe with the final cleaned 2,500-stock modelling panel.

Exit criteria: every missing segment has a defensible classification, and the processed panel is traceable to source and configuration.

## Skill 3 — Chronological data preparation

1. Resolve the current chunk configuration; default historical policy is C1 2000–04/2005/2006, C2 2007–14/2015/2016, C3 2017–22/2023/2024.
2. Attach stable date, ticker/entity, chunk, split, and source IDs.
3. Fit all learned preprocessing on the training partition only.
4. Transform validation/test with frozen training-fitted objects.
5. Validate no date/entity leakage, feature availability after the prediction timestamp, duplicate membership, or target leakage.
6. Write manifests and checksums/fingerprints; never rely only on filenames such as `final` or `cleaned`.

Exit criteria: splits and transformations can be reproduced and audited from manifests/configuration.

## Skill 4 — FinBERT preparation, HPO, fine-tuning, and embeddings

1. Inspect SEC text source, balancing/filtering rules, tokenizer/model version, maximum length, chunking, and metadata schema.
2. Build three chronological chunk datasets without crossing temporal boundaries.
3. Validate tokenisation counts, empty/truncated text, document IDs, split membership, and data-loader performance.
4. Use persistent Optuna/TPE storage with a stable study name. Resume a compatible study rather than restarting it.
5. Support masked-language-model fine-tuning and preserve the designed supervised extension point.
6. Before a long run, execute a CUDA availability check and one-batch forward/backward smoke.
7. Save latest/best epoch checkpoints atomically, including optimiser/scheduler/scaler, step/epoch, metrics, seed/config, and fingerprint.
8. Resume after interruption and verify the resumed epoch/trial and optimiser state.
9. Produce frozen and, where required, unfrozen model artifacts.
10. Generate 768-dimensional embeddings with matching CSV metadata, then fit PCA on training embeddings only and transform all splits to 256 dimensions.
11. Save embeddings as `.npy` plus CSV metadata; do not switch this path to Parquet.
12. Validate row counts, order/alignment, dimensions, explained variance, finite values, and split provenance.

Exit criteria: every embedding row maps to a source record, and no validation/test information influenced PCA or fine-tuning selection beyond declared validation use.

## Skill 5 — Temporal encoder and quantitative features

1. Reconstruct each approximately 30-day window using only data available by the prediction date.
2. Validate feature order, scaling, padding/masking, symbol continuity, and target alignment.
3. Fit scalers on training data and persist them with explicit feature names/version.
4. Unit-test boundary dates and insufficient-history behaviour.
5. Train/tune with resumable checkpoints and log actual batch/device throughput.
6. Verify inference recreates identical windows and feature order.

Exit criteria: a saved sample can be traced from raw dates to the exact tensor and model output.

## Skill 6 — Analysts, risk engine, and graph evidence

1. Inspect and retain Technical, Sentiment, and News analyst contracts; reject accidental Fundamental Analyst references.
2. Validate graph construction timing, node identity, edge features, and absence of future information.
3. Run volatility, drawdown, VaR, CVaR, liquidity, contagion, and regime modules with documented units and horizons.
4. Validate output names, ranges, missing-data policy, confidence semantics, and stable date/ticker alignment.
5. Adapt graph outputs to contagion/regime evidence rather than assuming an upstream forecasting objective remains correct.
6. Produce per-module explanations and risk drivers in structured form.

Exit criteria: every analyst/risk feature entering fusion is named, bounded or documented, temporally valid, and independently inspectable.

## Skill 7 — Fusion training and rule barrier

1. Build a manifest of all upstream feature files, model versions, scalers, column order, chunk, and split.
2. Check exact row alignment and reject silent inner joins or duplicate keys.
3. Train the learned MLP/FusionEngine on training data, select with validation data, and preserve the test set.
4. Save the FusionEngine scaler and feature-order contract with the checkpoint.
5. Emit both learned outputs and the deterministic rule-barrier result/flags.
6. Test rule boundaries, conflicting evidence, low-confidence behaviour, position sizing, and extreme-risk cases.
7. Validate final recommendation distribution for suspicious collapse without forcing an artificial balance.
8. Produce fused decision CSVs following the current schema; historical artifacts used a 104-column schema.

Exit criteria: final decisions are reproducible from named upstream features, learned checkpoint, scaler, and explicit rule configuration.

## Skill 8 — Explainability and narration

1. Generate structured XAI at module and final-decision levels before narration.
2. Include primary drivers, risk factors, analyst outputs, regime/liquidity context, confidence, and barrier flags.
3. Keep deterministic structured JSON as the auditable source of truth.
4. Pass only that structure to Qwen3-0.6B.
5. Constrain narration to summarisation: it must not change BUY/HOLD/SELL, risk, confidence, position, or flags.
6. Test missing fields, contradictory evidence, low confidence, extreme risks, and narrator failure.
7. Provide three transparency levels: concise user view, full-system view, and per-module detail/raw JSON.

Exit criteria: the same deterministic record produces an explanation faithful to its fields even if narration is disabled.

## Skill 9 — Inference modes

### Historical replay

1. Select an existing historical date/entity record.
2. Load the corresponding frozen artifacts without refitting.
3. Reproduce upstream outputs, fusion, barrier, XAI, and narration.
4. Compare with the stored result and explain any version difference.

### Frozen-cached Type B.2

1. Load cached upstream module outputs and required frozen scalers/checkpoints.
2. Validate schema/version/fingerprint compatibility.
3. Run PositionSizing and qualitative stages, frozen Quantitative Analyst, FusionEngine, barrier, XAI, and narrator in the configured order.
4. Reject mixed artifact versions.

### Manual frozen inference

1. Validate user inputs and make the as-of timestamp explicit.
2. Resolve all required features using only information available at that timestamp.
3. Apply the identical frozen preprocessing and feature order.
4. Run the deterministic pipeline and then optional narration.

Exit criteria: all modes share the same core decision contract and differ only in how valid upstream evidence is obtained.

## Skill 10 — Streamlit/UI and deployment diagnosis

1. Reproduce locally with the deployment entry point and environment, without exposing `.env`.
2. Separate repository clone/LFS failures from dependency installation and application startup failures.
3. Verify required LFS objects or provide an intentionally lightweight deployment artifact; never assume a pointer is the file.
4. Validate paths relative to repository root, checkpoint/scaler presence, and supported checkpoint key variants.
5. Smoke-test the default transparency UI, sidebar module outputs, raw JSON, error states, and narrator-disabled fallback.
6. Keep compute-heavy inference cached appropriately without caching user-specific mutable state incorrectly.
7. Report whether the actual deployed environment was tested.

Exit criteria: the app starts, loads compatible artifacts, renders a representative result, and degrades honestly when optional narration is unavailable.

## Skill 11 — Performance diagnosis

1. Capture baseline wall time, throughput, CPU/RAM, GPU utilisation/VRAM, disk throughput, worker settings, and competing processes.
2. Profile data loading/tokenisation/preprocessing, host-to-device transfer, model compute, and output writing separately.
3. Change one bottleneck-oriented variable at a time: cached preprocessing, worker count, batch size, precision, pinned memory, or competing jobs.
4. Verify correctness and measure improvement against the baseline.
5. If applying a system performance mode, save original CPU/GPU settings and verify restoration.

Exit criteria: an optimisation has measured benefit and unchanged output/test correctness.

## Skill 12 — Git recovery and code-only release

1. Back up known definitive local files and record their hashes.
2. If the checkout is locked or merge-corrupted, clone a clean `main` into a new directory.
3. Copy only inspected, intended files from the backup/current tree.
4. Restore `.env` locally but never stage it.
5. Run tests and smoke checks, inspect diff/status, verify Git identity, and verify LFS pointers.
6. Update stable docs without placing temporary progress in README.
7. Build a code-only archive excluding datasets, generated embeddings/results, checkpoints, logs, studies, caches, environments, and secrets.
8. Inspect archive contents and generate checksums when required.

Exit criteria: the clean tree contains only intentional changes, tests are accurately reported, and the deliverable contains no secret/data/generated leakage.

## Standard completion report

Every workflow should finish with:

- Result and affected mode/module.
- Evidence/root cause.
- Files changed.
- Exact one-line commands run.
- Actual tests, smokes, resume checks, and metrics.
- Current artifact/data/config fingerprint or version.
- Unverified external, deployment, or hardware paths.
- Delivered release/archive when requested.

## Skill 13 — SEC corpus ingestion and filing-text preparation

1. Inventory submissions JSON, company-facts data, raw filings, and processed text roots.
2. Record source versions/acquisition dates and stable company/filing/document identifiers.
3. Parse filing metadata and event timestamps, including form type and accession identity.
4. Apply the current subset/filtering policy without silently expanding the corpus.
5. Deduplicate filings/chunks and preserve parent-document linkage.
6. Normalise text while retaining enough raw/source evidence to audit extraction.
7. Define chunking/truncation and tokenizer-version metadata.
8. Attach chronological chunk/split strictly by the relevant event/as-of date.
9. Validate text availability, empty/truncated rates, source counts, date bounds, and cross-split document/company policy.
10. Write a manifest/fingerprint before FinBERT training or embedding.

Failure checks:

- wrong timezone/session mapping around filing timestamps;
- duplicated accession/chunk records;
- source path included as a label shortcut;
- current/future market text joined to earlier events;
- validation/test text entering MLM/supervised training contrary to the declared protocol.

## Skill 14 — Supervised FinBERT label construction

1. Define the event timestamp and first eligible market observation.
2. Define post-filing outcome horizon and target formula.
3. Exclude any market observations used as the target from the text/market input window.
4. Handle filings during/after market hours consistently.
5. Define thresholds/classes/neutral band from training data or fixed policy.
6. Persist label version, parameters, and source market data fingerprint.
7. Validate class distribution by chronological chunk/split.
8. Manually inspect boundary cases.
9. Ensure HPO uses validation, never test, labels.
10. Keep MLM-only and supervised artifacts distinct.

## Skill 15 — FRED macro feature engineering

1. Inventory selected series IDs, descriptions, units, frequency, transformation, and availability/revision assumptions.
2. Validate observation coverage against 2000–2024 chunks.
3. Apply frequency conversion and lag rules explicitly.
4. Use only values assumed available by each as-of date.
5. Fit imputers/scalers on training partitions.
6. Record missing/stale observation flags.
7. Join by date without forward information.
8. Validate values/ranges and first/last dates by split.
9. Persist series metadata and transformation versions with artifacts.

If point-in-time vintage data is not used, document the resulting revision/look-ahead limitation rather than claiming perfect historical availability.

## Skill 16 — Cross-asset graph construction and validation

1. Define node universe and how listing/delisting/missing history is represented.
2. Define edges: correlation, sector, learned adjacency, or other relationship.
3. Define the historical window and update cadence.
4. Ensure each graph uses only data available at its as-of date.
5. Validate node ordering and mapping to ticker rows.
6. Persist graph configuration/fingerprint.
7. Produce contagion/regime evidence with stable schema.
8. Evaluate by chunk/regime and run graph/no-graph ablations.
9. Check for isolated nodes and graph-density drift.
10. Do not reuse a full-period adjacency matrix in early chunks unless explicitly justified as non-predictive metadata.

## Skill 17 — Quantitative Analyst attention workflow

1. Resolve the exact risk-feature list/order and its scaler.
2. Reject stale inputs without required attention fields/schema version.
3. Fit scaler/model on training data only.
4. Validate rows by date/ticker/chunk/split and finite values.
5. Run persistent HPO or configured training with checkpoints.
6. Inspect attention weights by feature/source/regime.
7. Emit at least the pooled risk score, top attention risk driver, individual `risk_attention_*` values, recommendation/confidence fields, and XAI metadata required by the current schema.
8. Validate that attention weights and top driver correspond.
9. Check for constant/all-HOLD collapse and whether the loss/target scale makes it trivial.
10. Save model, scaler, feature order, schema version, and metrics as one artifact set.

Historical chunk-1 training numbers belong in `MEMORY.md`; never bake them into acceptance logic.

## Skill 18 — Fusion row-alignment audit

Before training or inference fusion:

1. Declare the canonical key, normally including date, ticker/entity, chunk, and split.
2. Count rows and duplicate keys in every upstream file.
3. Compare key sets and report missing/extra keys by module.
4. Resolve missing-module policy through availability flags/imputation; never through a silent inner join.
5. Verify feature names/order/types/ranges against the saved fusion schema.
6. Verify every upstream artifact fingerprint/version.
7. Join and assert row count/key uniqueness.
8. Sample rows end to end to confirm values were not shifted.
9. Store an alignment report with the fused artifact.

## Skill 19 — Rule-barrier and position audit

1. Capture learned recommendation/confidence/risk and learned position suggestion.
2. Capture PositionSizing recommendation.
3. Resolve the user rule cap/configuration.
4. Compute `min(position_sizing_recommendation, learned_position_suggestion, user_rule_cap)` for final position.
5. Apply recommendation/risk constraints in the documented order.
6. Record every triggered rule, pre-rule output, post-rule output, cap source, and explanation.
7. Unit-test exact thresholds, equality boundaries, missing data, extreme risk, negative/zero positions, and conflicting recommendations.
8. Produce a distribution of rule triggers and changed decisions by split.
9. Ensure the narrator uses post-barrier output while explaining the barrier truthfully.

## Skill 20 — Fused-schema and distribution audit

1. Load the current schema definition or derive it from verified code—not from the old 104-column count alone.
2. Validate columns, order where required, dtypes, categorical domains, ranges, and nullability.
3. Assert stable key uniqueness and expected row counts.
4. Validate module availability flags and conditional fields.
5. Validate learned/post-rule/final consistency.
6. Validate XAI/attention/risk-driver consistency.
7. Count BUY/HOLD/SELL and risk/confidence/position distributions.
8. Compare validation versus test/chunks for suspicious drift/collapse.
9. Investigate extreme rarity through thresholds, rules, joins, model outputs, and class balance.
10. Save a machine-readable audit report.

Do not “repair” distributions by modifying results after the fact.

## Skill 21 — Frozen deployment bundle construction

1. Select the intended inference mode/chunk and one compatible artifact manifest.
2. Include inference/deploy code and configuration.
3. Include required Quantitative/Fusion models, scalers, feature schemas, and cached upstream outputs.
4. Include the fixed Qwen3-0.6B narrator directory only when model licensing/size/deployment permits and the user requested the full package.
5. Verify all Git LFS files are materialised.
6. Load every checkpoint/scaler from the bundle in a clean environment.
7. Run one cached and one representative manual/historical smoke where applicable.
8. Verify the UI exposes no repo-root/chunk/device/split/transparency controls and always shows full transparency.
9. Test narrator failure/fallback.
10. Produce bundle manifest/hashes and state deployment resource requirements.

## Skill 22 — Git LFS capacity and deployment audit

1. Inventory tracked LFS patterns and pointer files.
2. Calculate object count and total/local/missing size.
3. Run LFS status/dry-run checks.
4. Confirm remote quota/bandwidth and deployment platform LFS support.
5. Identify artifacts that should move to a model/release/object store or be reproducibly rebuilt.
6. Verify clone plus `git lfs pull` in a clean target-like environment.
7. Separate LFS acquisition failure from app startup.
8. Never push an unexpectedly huge set without Ibrahim's informed intent.

## Skill 23 — Remote long-run operations

1. Start/attach a named `tmux` session.
2. Confirm repo/branch/commit, venv, config/fingerprint, disk, RAM, GPU, and competing jobs.
3. Use persistent log files and unbuffered output where needed.
4. Run preflight/one-batch smoke.
5. Start the resumable command.
6. Monitor stage progress, utilisation, VRAM, throughput, checkpoint updates, and log errors.
7. On disconnect/reboot/failure, inspect state before rerunning; resume without `--fresh` when compatible.
8. Verify completion artifacts and exit/status, not merely an absent process.
9. Restore any temporary CPU/GPU performance settings.

## Skill 24 — Performance-mode safety

1. Capture original CPU governor/boost/EPP and GPU persistence/power settings.
2. Query hardware-supported limits; never exceed reported GPU maximum.
3. Apply temporary performance mode through auditable scripts.
4. Benchmark the actual pipeline and identify data versus compute bottlenecks.
5. Restore original state on completion/failure.
6. Verify restored values.

Performance mode does not replace dataloader/tokenisation/I/O profiling.

## Skill 25 — Clean-clone incident recovery

Use when Windows locks/merge/LFS state makes the existing checkout unsafe:

1. Stop and record current branch/status/divergence/merge state.
2. Copy definitive files to an external backup and hash them.
3. Preserve `.env` separately and mark it never-commit.
4. Fresh-clone `origin/main` into a new directory.
5. Initialise/pull LFS as required.
6. Copy only the approved definitive source/doc files.
7. Inspect diff and scan for secrets.
8. Run tests/smokes.
9. Verify repository-local Ibrahim Git identity.
10. Commit/push only intended changes.
11. Restore `.env` locally after the clean tree is stable.
12. Retain the old tree until the new one is verified; do not keep retrying destructive resets against locked files.

## Skill 26 — Documentation reconciliation

1. Inventory current Markdown, diagrams, paper/presentation files, and references.
2. Detect duplicated/superseded architecture or component descriptions.
3. Remove Fundamental/debater/LangChain references from active documentation unless clearly historical.
4. Align module names, paths, schemas, chunk boundaries, inference modes, and UI behaviour with current code.
5. Keep README stable/informational and link to detailed docs.
6. Put setup in `SETUP.md`, process in `WORKFLOW.md`, explanations in XAI/module docs, and dated status in `MEMORY.md`/run reports.
7. Verify every documented command against the current CLI.
8. Do not resurrect deleted historical files simply to fill a link; update the link/map deliberately.

## Cross-workflow acceptance matrix

| Layer | Must be proven |
| --- | --- |
| Sources | Inventory, provenance, coverage, licences/availability assumptions |
| Splits | Exact chronological boundaries and no leakage |
| Preprocessing | Training-only fit and persisted identity |
| Encoders | Checkpoint/resume, aligned outputs, current schemas |
| Analysts/risk | Named ranges/units/availability and independent XAI |
| Quantitative | Attention fields, scaler/feature order, non-stale schema |
| Fusion | Unique aligned keys, compatible artifacts, learned output |
| Barrier | Explicit triggers and final-position min rule |
| XAI/narrator | Structured truth first, grounded narration, failure fallback |
| UI | Always-full transparency and removed user-facing operator controls |
| Release/deploy | LFS/artifact completeness, clean load, no secrets |
| Documentation | Current architecture and verified commands |
