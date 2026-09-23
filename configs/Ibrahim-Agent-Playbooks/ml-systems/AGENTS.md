# AGENTS.md — ML and AI Systems

## Scope

Use this profile for Ibrahim Hussain's machine-learning, deep-learning, multi-agent, RAG, and research-engineering repositories. Apply the core engineering rules as well as the requirements below.

## Research integrity

- Start from the stated objective, target, decision boundary, and evaluation question. Do not select a model before defining the data and protocol.
- Distinguish source-stated facts, repository evidence, user decisions, and agent inferences.
- Never invent results, completed training, paper fidelity, or statistical significance.
- Record assumptions and deviations from referenced papers or specifications.
- Prefer an interpretable baseline before a complex model, unless the task is explicitly an architecture reproduction.

## Data contracts and leakage prevention

- Define sample identity, labels, feature availability time, grouping, split rules, and exclusion criteria explicitly.
- Use chronological splits for temporal financial data. Fit scalers, vocabularies, PCA, feature selection, calibration, and imputers on training data only.
- Use source/group-disjoint splits where related images or documents could otherwise leak across train, validation, and test.
- Fingerprint source files, relevant configuration, code/schema version, and split membership. A resume state is valid only when its fingerprint matches.
- Validate duplicates, missing values, infinities, label alignment, shape/orientation, date coverage, class distribution, and cross-split contamination.
- Keep raw data immutable. Store generated manifests, processed data, models, logs, HPO studies, evaluations, and inference outputs under a dedicated output root.

## Pipeline architecture

- Each stage must have an explicit input/output contract and be runnable independently where practical.
- Separate preparation, diagnostics, HPO, training, evaluation, inference, and deployment concerns.
- Configuration is the source of truth. Avoid duplicated hard-coded paths or hyperparameters.
- Support CPU and CUDA profiles without pretending that a CUDA-only test ran on CPU.
- Use stable sample IDs and metadata sidecars so arrays/tensors can be traced back to source rows.
- Save preprocessing objects required at inference, not only model weights.

## Resumability

Long stages must survive interruption:

- Persist state atomically after a meaningful unit of work.
- Record the current stage, completed sample/epoch/trial, random seed/state where needed, best metric, checkpoint path, and fingerprint.
- Keep both latest and best checkpoints when their purposes differ.
- Resume Optuna/TPE studies from persistent storage rather than creating a new study.
- Validate checkpoint architecture, configuration, preprocessing, and dataset compatibility before restoring.
- Test resume behaviour, including a deliberate interruption or a small fixture that simulates one.

## Performance and observability

- Profile before optimising. Investigate preprocessing, I/O, worker saturation, host-to-device transfer, batch size, competing jobs, and memory before attributing low GPU utilisation to the model.
- Use mixed precision only where numerically safe and supported.
- Guard against NaN/Inf losses, exploding gradients, silent broadcasting, OOM loops, and train/eval mode mismatch.
- Emit tqdm-style progress plus CPU/RAM and CUDA/VRAM telemetry for long work.
- Choose workers from available resources and workload behaviour; provide a safe override.

## Evaluation

- Select metrics that match the task and class balance. Include confusion matrices or per-class results where aggregate accuracy hides behaviour.
- For financial risk models, preserve chronological evaluation and report threshold/rule effects separately from learned-model output.
- For localisation, distinguish image-level classification metrics from pixel/region localisation metrics.
- Verify inference/training parity: transforms, feature order, scalers, PCA, tokenizer, device, checkpoint keys, and label mapping.
- Treat historical metric snapshots as evidence tied to a specific artifact, not timeless repository truth.

## Testing

- Unit-test transforms, losses, metric calculations, split logic, state/fingerprint handling, and checkpoint loading.
- Use temporary synthetic fixtures in tests; do not require real datasets in the repository.
- Add a CPU smoke test even when primary training uses CUDA.
- Mark genuine hardware-specific tests clearly and report skips accurately.
- Run a small end-to-end flow from manifest/data input to final output before release.

## Packaging

- Releases are code-only by default: exclude datasets, prepared tensors, model weights, logs, HPO databases, caches, predictions, and other generated artifacts.
- Include configs, tests, documentation, lightweight schemas/examples, and scripts necessary to reproduce the pipeline.
- Never include secrets or environment-specific `.env` files.

## Evidence hierarchy for ML claims

Use the strongest available evidence and name its level:

1. A verified artifact tied to a commit/config/data fingerprint.
2. A run log with command, environment, inputs, and output identities.
3. A test or independently recomputed metric.
4. Current repository code/configuration.
5. A dated project note or chat statement.

Do not promote a design intention into an implemented feature. In particular, distinguish:

- **declared**: described in config/docs;
- **connected**: receives and returns tensors in the executed graph;
- **supervised**: has a meaningful target/loss;
- **optimised**: its parameters receive non-zero valid gradients and updates;
- **effective**: ablation or evaluation shows it contributes;
- **production/inference parity**: the deployed path recreates training semantics.

A branch producing a tensor is not proof that it learns useful evidence. A zero or tiny loss is not automatically success. A positive-only dataset cannot establish authentic-versus-forged classification. A random split is not acceptable when time/entity/source relationships leak.

## Problem-definition contract

Every project must state:

- task type and operational decision;
- sample unit and grouping unit;
- input information available at prediction time;
- target/label construction and horizon;
- prediction granularity;
- allowed abstention or uncertainty behaviour;
- cost of false positives and false negatives;
- primary, secondary, and diagnostic metrics;
- deployment/inference mode;
- human review or rule-barrier role.

If these are unclear, do not hide the ambiguity behind model selection.

## Dataset inventory and provenance

Maintain a machine-readable inventory containing, as applicable:

- source dataset/provider and licence/terms;
- source file identity, size, checksum, modification time, and acquisition date;
- sample and group IDs;
- time/date coverage;
- labels, masks, targets, or label-generation version;
- source dimensions/orientation/format;
- split membership and reason;
- exclusion reason;
- preprocessing version;
- output artifact linkage.

Raw data is immutable. Correct source errors through a versioned adapter or manifest decision, not by silently editing the raw files.

## Leakage threat model

Audit more than obvious train/test overlap:

### Temporal leakage

- features published after the as-of timestamp;
- revised macro/financial values treated as historically known;
- target-window data entering preprocessing;
- centred windows or future padding;
- thresholds/calibration/PCA/scalers fitted on future partitions.

### Entity/group leakage

- the same company, document, identity, source image, video, patient, or derived sample across splits;
- near duplicates, rotations, crops, augmentations, or recompressions split independently;
- cached representation generated from a globally fitted model/transformation.

### Target leakage

- post-outcome features;
- labels encoded in filenames/paths/metadata;
- masks or target-derived statistics included as inputs;
- evaluation-time rules that use ground truth.

### Evaluation leakage

- repeated test-set inspection guiding design;
- selecting a checkpoint/hyperparameter from test performance;
- computing normalisation or class weights from all splits;
- tuning narrator/rule thresholds against held-out test decisions.

Record the audit and the controls, not merely “no leakage.”

## Split specifications

A split is a versioned data product. Specify:

- exact boundaries or group algorithm;
- stable seed where randomness is used;
- exclusion and minimum-history rules;
- stratification constraints and where they are safe;
- derivation grouping;
- class/source/date counts;
- duplicate/near-duplicate checks;
- hash/fingerprint;
- code/config version.

Never regenerate a split implicitly during training. Training reads a resolved manifest.

## Preprocessing fit boundaries

For every transform, record whether it is:

- stateless and deterministic;
- fitted only on training data;
- fitted per chunk/fold/entity;
- stochastic training augmentation;
- deterministic evaluation/inference transformation.

Persist fitted state for scalers, PCA, encoders, vocabularies/tokenizers when modified, feature selectors, imputers, calibrators, thresholds, and graph/statistical priors. Preserve feature names and order, not only arrays of parameters.

## Configuration standard

Configuration should capture:

- profile name and inheritance;
- dataset/manifests and output roots;
- split/fingerprint expectations;
- model architecture and initialisation/pretrained identity;
- optimiser, scheduler, loss weights, batch/accumulation, precision, workers;
- HPO study/storage/search space;
- checkpoint/resume policy;
- evaluation metrics/thresholds;
- seeds and determinism controls;
- telemetry/logging intervals;
- device/resource limits.

Log the resolved configuration. Do not depend on undocumented defaults spread across Python modules.

## HPO requirements

- Use validation data only for the HPO objective.
- Persist the study in SQLite or the repository's chosen durable backend.
- Give the study a stable descriptive name and record direction(s).
- Fingerprint data, split, objective, search space, and relevant code/config.
- Resume compatible incomplete trials/studies.
- Record failed and pruned trials with reasons.
- Bound unsafe parameters to prevent OOM or meaningless architectures.
- Retrain/evaluate the selected configuration through the declared protocol; do not treat the best trial's incidental in-memory model as the final artifact unless the workflow explicitly validates it.

## Checkpoint schema

A full resumable training checkpoint should normally include:

- schema version;
- model state;
- optimiser state;
- scheduler state;
- AMP gradient-scaler state;
- epoch, global step, batch cursor if supported;
- best metric and best checkpoint identity;
- early-stopping state;
- resolved config or hash;
- dataset/split/preprocessing fingerprint;
- feature/label mapping;
- RNG states where reproducible continuation matters;
- training-history pointer or embedded summary.

Write to a temporary file, flush/synchronise where appropriate, and atomically rename. Validate readability before updating a `latest` pointer. Do not overwrite the last known-good checkpoint with a partial write.

## Numerical and gradient safety

Check:

- input, activation, loss, and output finite values;
- scale and distribution of each loss term;
- gradient norms and whether each trainable branch receives gradients;
- loss-weight dominance;
- mask/ignore-index correctness;
- silent broadcasting or unintended reduction;
- mixed-precision overflow/underflow;
- train/eval mode and batch-normalisation/dropout behaviour;
- optimiser actually references intended parameters;
- frozen/unfrozen state matches configuration.

When a branch is intended to learn, add a test or diagnostic that proves its parameters change under a controlled step.

## Evaluation design

### Classification

Report class counts, confusion matrix, per-class precision/recall/F1, macro and weighted metrics, calibration where relevant, and decision-threshold policy. Accuracy alone is not enough for severe imbalance.

### Localisation/segmentation

Report pixel/region metrics, thresholding, small-region performance, authentic/empty-mask behaviour, and qualitative alignment. Separate image-level detection from localisation.

### Temporal finance/risk

Preserve chronological order and state horizons/units. Separate learned prediction, deterministic rules, position caps, and downstream risk results. Include breach/coverage analysis for VaR-like measures and evaluate by regime/time slice.

### Generative/narrative output

Evaluate grounding against structured evidence. The language model must not overwrite deterministic decisions or invent drivers.

## Ablation expectations

For multi-branch architectures, design ablations that can answer:

- Does each branch improve the appropriate metric?
- Does a gate/fusion layer use the branch or ignore it?
- Do proxy targets contribute or merely correlate with dataset source?
- Is exact-domain evidence better than a fallback approximation?
- Are improvements stable across sources, time chunks, orientations, and small/rare cases?

Do not claim an architectural contribution solely from the full-model metric.

## Reproducibility record

Each important run should record:

- command and working directory;
- commit/diff identity;
- resolved configuration;
- environment/package/device versions;
- data/split fingerprint;
- seeds;
- start/end time and interruption/resume events;
- HPO study/trial or checkpoint identity;
- output paths/hashes;
- measured metrics and evaluation script version;
- known warnings and unverified assumptions.

## CPU and CUDA profile discipline

- CPU profiles are for development, unit tests, preparation samples, and a complete small smoke path.
- CUDA profiles are for the intended full-data/full-capacity path.
- Keep semantic behaviour aligned while allowing smaller CPU backbones, sample manifests, worker/batch limits, or disabled expensive augmentation.
- Never let a CPU sample result masquerade as full-data performance.
- Never silently fall back from requested CUDA training to CPU for a long job; fail clearly or require explicit fallback.

## Performance workflow

1. Measure baseline end-to-end and per-stage throughput.
2. Observe CPU utilisation, RAM/swap, disk I/O, data wait, GPU utilisation, VRAM, and transfer time.
3. Determine whether the bottleneck is source decoding, tokenisation/augmentation, Python overhead, workers, storage, transfer, model compute, synchronisation, or output writing.
4. Change one relevant factor.
5. Re-measure correctness and performance.

Avoid “optimisations” that change data order, augmentation semantics, precision stability, or reproducibility without recording the trade-off.

## ML definition of done

An ML feature is not done because training starts. Completion requires:

- valid data/split contract;
- leakage audit;
- tested preprocessing fit boundaries;
- connected and supervised architecture;
- resumable HPO/training where expensive;
- validated checkpoint and inference parity;
- task-appropriate metrics and error analysis;
- representative smoke and actual target-hardware status;
- documentation and reproducible command;
- code-only package hygiene.
