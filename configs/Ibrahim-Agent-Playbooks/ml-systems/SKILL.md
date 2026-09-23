---
name: ibrahim-ml-system-workflow
description: Build or repair leakage-safe, resumable ML and deep-learning pipelines with persistent HPO, evidence-based validation, and code-only delivery.
---

# ML System Workflow

## Phase 1 — Frame the system

1. Define the prediction or generation objective, unit of observation, labels, outputs, and operational use.
2. Define success metrics and unacceptable failure modes.
3. Map the repository's current dataflow and identify already-completed work that must be reused.
4. Record hard constraints: platforms, available hardware, formats, licences, data locations, and release exclusions.

## Phase 2 — Audit data and splits

1. Inspect representative real records without mutating raw data.
2. Validate schema, counts, missingness, duplicates, value ranges, orientation/shapes, and label alignment.
3. Define chronological or source-group-disjoint train/validation/test splits.
4. Check explicitly for leakage through time, entity, source document, near duplicates, preprocessing, or cached embeddings.
5. Create a manifest with stable IDs, source paths, labels, split, group, dimensions/dates, and a fingerprint.

## Phase 3 — Establish resumable preparation

1. Put generated artifacts beneath the configured output root.
2. Write state atomically and store the manifest/config/source fingerprint.
3. Skip only outputs that are complete, readable, and fingerprint-compatible.
4. On restart, resume from the last committed unit rather than restarting the stage.
5. Add a `--force` or equivalent explicit invalidation path; never silently reuse incompatible artifacts.

## Phase 4 — Implement and test components

1. Implement each encoder/model/risk/agent module behind a clear typed or documented contract.
2. Add boundary checks for tensor shape, dtype, device, finite values, feature ordering, and masks.
3. Preserve traceability from model inputs/outputs to stable sample IDs.
4. Unit-test each component with small temporary fixtures.
5. Verify import use and intended CLI execution.

## Phase 5 — Tune without losing state

1. Define a bounded search space and an objective aligned with validation metrics.
2. Use persistent Optuna/TPE or the repository's established study storage.
3. Give the study a stable name and fingerprint the data/configuration.
4. Record trial failures, pruning, seeds, resource use, and selected parameters.
5. Resume the existing compatible study; do not reset it merely because the process stopped.

## Phase 6 — Train robustly

1. Confirm environment, device, free memory, loaders, and a single-batch forward/backward pass.
2. Save latest and best checkpoints atomically with model, optimiser, scheduler, scaler, epoch/step, metrics, config, and fingerprint.
3. Add NaN/Inf, gradient, loss, and checkpoint guards.
4. Log progress, ETA, CPU/RAM, GPU utilisation, and VRAM where available.
5. Validate after each configured interval and preserve the best model according to the declared metric.
6. Interrupt and resume a smoke run to prove recovery.

## Phase 7 — Evaluate and analyse

1. Load the exact selected checkpoint and training-fitted preprocessing objects.
2. Freeze the test set until the design is fixed.
3. Produce aggregate and per-class/per-regime/per-source metrics as appropriate.
4. Inspect errors and distribution shift; do not reinterpret test data as a tuning set.
5. Validate output schema, sample counts, stable IDs, and finite values.
6. Record artifact hashes or versions that bind results to code and data.

## Phase 8 — Build inference parity

1. Reconstruct the complete training-time transformation path.
2. Validate checkpoint key variants only through deliberate compatibility code.
3. Support the required historical, cached/frozen, or manual mode without changing semantics.
4. Separate deterministic model output from narration or UI explanation.
5. Run a representative end-to-end inference smoke test.

## Phase 9 — Document and deliver

1. Update architecture, data contract, setup, workflow, model, and inference documentation.
2. Keep README stable and informational; put dated run status elsewhere.
3. Run syntax checks, focused tests, smoke tests, resume tests, and the affordable full suite.
4. Review diff/status and scan for secrets or generated artifacts.
5. Build a code-only archive from the verified tree and inspect its contents.

## Required hand-off evidence

- Environment and command used.
- Data/split fingerprint or description.
- Actual tests and smoke runs.
- Resume validation.
- Output contracts and measured metrics.
- Unverified hardware or external integrations.
- Exact archive/version delivered.

## Detailed sub-workflows

### Data-doctor workflow

Run this before expensive training and whenever a dataset adapter changes:

1. Resolve raw roots and manifest/output roots.
2. Inventory sources and licences.
3. Read a bounded sample from every source/subset/class.
4. Validate decodability and required metadata.
5. Validate sample IDs and group IDs.
6. Compute schema/dtype/shape/orientation/date summaries.
7. Check missing labels/masks and legal target ranges.
8. Detect exact duplicates and, where feasible, near duplicates.
9. Verify split/group/time constraints.
10. Exercise the full deterministic preprocessing chain.
11. Confirm output tensors are finite and aligned.
12. Persist a doctor report tied to the manifest fingerprint.

Doctor success means the checked contract passed. It does not prove model quality.

### One-batch training probe

Before a full run:

1. Load one real batch through the intended profile.
2. Log tensor names, shapes, dtypes, devices, ranges, masks, and labels.
3. Run forward pass and every configured loss.
4. Confirm finite loss and intended reduction.
5. Run backward pass.
6. Inspect gradient presence/norm by branch/head.
7. Run an optimiser step and confirm intended parameters change.
8. Save and reload a checkpoint.
9. Run evaluation/inference on the same batch using reloaded state.

This catches many configuration, frozen-parameter, output-shape, and checkpoint errors before hours of compute are spent.

### Resume validation workflow

1. Run a small fixture for at least one checkpoint interval.
2. Record state, metric, epoch/step, and artifact hashes.
3. Terminate in a controlled way.
4. Restart with the same config and confirm resume location/state.
5. Verify optimiser/scheduler/scaler continuity.
6. Confirm completed preparation items/trials are not repeated.
7. Change a fingerprinted setting and confirm incompatible resume is rejected.
8. Exercise the documented reset/force path and confirm its scope.

### Leakage audit workflow

Create a report with these sections:

- split algorithm and boundaries;
- duplicate/group overlap results;
- feature availability timestamps;
- target construction window;
- fitted-transform partitions;
- label/path/metadata leakage checks;
- caching/embedding provenance;
- test-set access policy;
- residual risks and assumptions.

For temporal data, include minimum/maximum timestamps by split and assert strict ordering. For images/documents, group all derivatives of one source identity before splitting.

### Paper-to-code workflow

1. Read the paper/source completely enough to identify method, equations, datasets, preprocessing, architecture, loss, optimisation, evaluation, and ablations.
2. Build a table with “source states,” “repository implementation,” “difference,” and “reason.”
3. Mark missing hyperparameters rather than inventing them silently.
4. Map each paper component to a repository module and test.
5. Implement the smallest faithful vertical path.
6. Reproduce a sanity result or invariant before full-scale training.
7. Document deviations, proxy targets, pretrained substitutions, resolution changes, and dataset differences.
8. Do not claim reproduction when only architecture shape was copied.

### Suspicious-result workflow

Use this when metrics are implausibly high/low, a class disappears, losses are zero, or one branch dominates:

1. Verify metric code against a tiny manually computed example.
2. Verify label mapping and class counts at source, manifest, batch, output, and metric stages.
3. Check duplicates/group/time leakage.
4. Check whether preprocessing saw validation/test data.
5. Inspect predictions before threshold/rules and after them.
6. Compare train/eval transforms and feature order.
7. Inspect a small set of false positives/negatives or localisation overlays.
8. Run a simple baseline.
9. Run branch/head ablations.
10. Repeat with another seed where stochastic instability is plausible.

### OOM/performance workflow

1. Record model, resolution/sequence length, batch, accumulation, precision, workers, and peak memory.
2. Confirm there are no competing processes or retained graphs/tensors.
3. Separate data-loading memory from model/activation/optimiser memory.
4. Reduce the parameter that addresses the real bottleneck: batch, resolution/length, workers/prefetch, precision, checkpointing, or model capacity.
5. Preserve effective batch semantics with gradient accumulation when appropriate.
6. Re-run the one-batch probe and throughput measurement.

### Inference parity audit

Compare training and inference for:

- source parsing;
- sample/feature order;
- tokenizer/transforms;
- scaling/PCA/imputation;
- masks/padding/window construction;
- model class/config;
- checkpoint key and strictness;
- label mapping/thresholds;
- rules/barriers;
- device/precision/eval mode;
- output schema and stable IDs.

Any mismatch must be intentional and documented.

### Model-release workflow

When model artifacts are intentionally delivered separately from a code-only source archive:

1. Identify checkpoint, preprocessing, tokenizer/config, feature schema, label mapping, and evaluation report.
2. Bind them through a manifest with hashes and training commit/config/data fingerprint.
3. Test loading from the packaged layout in a clean environment.
4. State hardware/software compatibility and expected input/output contract.
5. Keep secrets, raw training data, transient checkpoints, and unnecessary logs out of the package.

### Final acceptance matrix

| Area | Required evidence |
| --- | --- |
| Data | Manifest, counts, schema, provenance, split audit |
| Preprocessing | Training-only fit proof and persisted objects |
| Model | Connected/supervised modules and gradient probe |
| HPO | Persistent study identity and selected-trial record |
| Training | Resumable checkpoint and real logs |
| Evaluation | Appropriate metrics, slices, and error analysis |
| Inference | Parity audit and end-to-end smoke |
| Reproducibility | Command, config, commit, environment, fingerprints |
| Release | Inspected code-only archive and explicit artifact exclusions |
