# SKILLS.md

## Purpose

This file records the technical workflow that repeatedly proved effective while building and debugging `fin-glassbox`.

It is intended to guide future AI agents through the same engineering process rather than merely describing the architecture.

---

# Skill 1 — Establish Repository Ground Truth

## Objective

Understand the real state of the repository before changing it.

## Procedure

### Step 1 — Resolve the repository root

Do not assume a path.

Historically the project has been used from environments including:

```text
~/fin-glassbox
```

and Windows/WSL locations.

Resolve the active repository root first.

### Step 2 — Inspect Git state

Check:

```bash
git status
```

Then inspect relevant branches, recent commits, stashes, and changed files.

Before destructive Git operations determine whether valuable local-only files exist.

### Step 3 — Inspect repository structure

Identify:

```text
code/
data/
outputs/
researchPapers/
setup/
```

and relevant component directories such as:

```text
encoders/
analysts/
riskEngine/
gnn/
fusion/
```

### Step 4 — Read the implementation and its consumers

For the target module inspect:

```text
implementation
configuration
CLI
input loader
artifact loader
downstream caller
tests
documentation
```

Do not modify a model file in isolation when another module relies on its exact schema.

---

# Skill 2 — Verify the Runtime

Before diagnosing model logic, verify the environment.

Check:

```text
Python version
virtual environment
PyTorch version
CUDA availability
GPU identity
available VRAM
CPU
RAM
disk space
working directory
```

The project has historically used Python `3.12.7`.

The major remote GPU environment used an NVIDIA RTX 3090 Ti with approximately 24 GB VRAM.

Do not assume that environment is always active.

Code must detect the current runtime.

---

# Skill 3 — Compile Before Running

For each changed Python module:

```bash
python -m py_compile path/to/file.py
```

Compilation is only the first gate.

Passing compilation means:

```text
syntax is valid
```

not:

```text
the algorithm is correct
```

Continue with runtime verification.

---

# Skill 4 — Inspect Data Before Training

Before launching a model:

1. verify input paths;
2. inspect column names;
3. inspect dtypes;
4. inspect timestamps;
5. inspect ticker/security identifiers;
6. inspect missing values;
7. inspect duplicate rows;
8. inspect finite values;
9. inspect expected split membership;
10. inspect row counts.

For multimodal modules, verify that identifiers and timestamps align across modalities.

Never infer alignment simply because two files have similar row counts.

---

# Skill 5 — Enforce Chronological Splits

Use the canonical split scheme:

```text
C1:
train = 2000–2004
val   = 2005
test  = 2006

C2:
train = 2007–2014
val   = 2015
test  = 2016

C3:
train = 2017–2022
val   = 2023
test  = 2024
```

Then explicitly verify the minimum and maximum timestamps in every generated dataset.

Any learned transformation must be trained on the training partition only.

This includes PCA, scaling, thresholds, calibration and similar transformations.

---

# Skill 6 — Build a Small Real-Data Smoke Path

Before HPO or full training, run a small representative subset.

The smoke test should exercise the real path:

```text
loader
→ preprocessing
→ model forward
→ loss / prediction
→ output generation
→ serialization
```

A useful smoke test verifies more than model construction.

It should catch:

* missing files;
* shape mismatches;
* alignment failures;
* device errors;
* dtype errors;
* output-writing errors.

Prefer a small real dataset over fabricated financial data.

---

# Skill 7 — HPO Before Full Training

For trainable models, use the sequence:

```text
smoke
→ small HPO validation
→ persistent HPO
→ inspect trials
→ select best parameters
→ full training
```

Use Optuna TPE where the module follows the established project pattern.

Persist studies in SQLite.

A rerun should resume the study unless explicitly started fresh.

Provide a deliberate fresh-study option rather than deleting databases manually.

---

# Skill 8 — Guard Every HPO Objective

Inside the objective function validate all major numerical outputs.

Reject:

```text
NaN
+Inf
-Inf
empty predictions
invalid losses
invalid metric values
```

before reporting results to Optuna.

Do not let one corrupt training state poison a study.

When possible, report intermediate metrics and support pruning.

---

# Skill 9 — Train Resumably

Full training should preserve enough state to continue.

At the end of each epoch save:

```text
epoch
model state
optimizer state
scheduler state
best metric
training configuration
```

Maintain a discoverable latest checkpoint.

Resume logic should:

1. detect an existing checkpoint;
2. load state;
3. restore epoch;
4. restore optimisation state;
5. continue with the next epoch.

Never label a restart as a resume.

---

# Skill 10 — Export Inference Artifacts Explicitly

Distinguish:

```text
training checkpoint
trained model export
frozen model
embedding cache
prediction cache
scaler/PCA state
manifest
```

Where required preserve both frozen and unfrozen exports.

A deployment path must consume the intended artifact type rather than whichever file happens to load successfully.

---

# Skill 11 — Build FinBERT Representations

The established SEC text workflow is conceptually:

```text
SEC filing text
→ clean/chunk text
→ chronological split
→ FinBERT MLM fine-tuning
→ 768-dimensional representations
→ train-only PCA fitting
→ 256-dimensional representations
→ .npy embedding output
→ CSV metadata output
```

For each output verify:

```text
embedding rows == metadata rows
embedding dimension == 256
all values finite
split == expected split
```

PCA fitted for one chunk must not be silently fitted using validation/test rows.

---

# Skill 12 — Validate Embedding Artifacts

For each generated embedding array inspect:

```python
shape
dtype
np.isfinite(...).all()
```

Verify metadata:

```text
row count
timestamps
identifiers
split
```

For very large artifacts, generate a manifest rather than repeatedly loading everything manually.

---

# Skill 13 — Build Temporal Representations

For temporal market features:

1. sort by security and date;
2. enforce split boundaries;
3. construct the configured lookback window;
4. verify target offset;
5. ensure windows do not leak future observations;
6. batch efficiently;
7. write embeddings;
8. write manifests;
9. validate finite outputs.

The settled architecture uses an approximately 30-day context.

Do not change the window because another value trains faster.

---

# Skill 14 — Compute Statistical Risk Modules

Risk computation is generally better handled independently from neural training when the metric itself is statistical.

The risk stack includes:

```text
volatility
drawdown
VaR
CVaR
liquidity
contagion
regime
```

For each module:

1. define its data dependency;
2. compute by chronological split;
3. preserve timestamps and identifiers;
4. validate finite outputs;
5. document exceptional values;
6. save outputs using the established schema;
7. align them before fusion.

Do not collapse all risk logic into a single opaque neural network.

---

# Skill 15 — Graph-Based Market Modelling

Cross-asset modelling has historically included graph architectures such as StemGNN/MTGNN-derived components.

Their role is not simply generic price forecasting.

Within this project they have been adapted for concepts such as:

```text
contagion
cross-asset dependency
market regime
```

When adapting an external architecture:

1. identify its original task;
2. identify which assumptions no longer apply;
3. redefine targets;
4. preserve temporal leakage safety;
5. verify graph construction;
6. document the adaptation.

Do not present an imported architecture as project-specific research without documenting the modifications.

---

# Skill 16 — Align Multimodal Outputs

Before fusion, create a deterministic alignment key.

Typical alignment dimensions include:

```text
security
timestamp
split
```

Check every module for:

```text
duplicate keys
missing keys
different trading calendars
different starting dates
different row counts
```

Join intentionally.

Do not use positional concatenation unless positional equivalence has been proven.

---

# Skill 17 — Train Learned Fusion

Fusion should consume validated branch/risk outputs.

Workflow:

```text
load aligned branch outputs
→ fit preprocessing on training split only
→ smoke forward pass
→ HPO
→ full training
→ evaluate validation
→ evaluate test
→ export
```

The learned fusion component produces the machine-learned integrated decision signal.

It is not the final unrestricted authority.

---

# Skill 18 — Apply the Rule Barrier

After learned fusion, apply deterministic constraints representing risk/business logic.

Preserve both:

```text
pre-rule output
post-rule output
```

The user must be able to identify when a rule changed the learned fusion recommendation.

Never overwrite the learned output without preserving the reason for the modification.

---

# Skill 19 — Produce Structured XAI

Build explanation data before natural-language narration.

Structured output should contain enough information to reconstruct the decision.

Conceptually:

```json
{
  "technical": {},
  "sentiment": {},
  "news": {},
  "risk": {},
  "fusion": {},
  "rules": {},
  "final": {}
}
```

The exact schema should follow the active implementation.

Structured XAI is the source of truth.

---

# Skill 20 — Narrate Without Re-Deciding

Pass structured XAI to `Qwen3-0.6B`.

Prompt the model to explain:

```text
what the system decided
which signals contributed
which risks mattered
whether a rule changed the result
```

Do not ask it to independently decide whether the security should be bought or sold.

Validate narration against the structured numerical output.

---

# Skill 21 — Implement Frozen-Cached Inference Correctly

For Type B.2 inference:

1. resolve the requested security/date/input;
2. identify reusable upstream cached artifacts;
3. load the real frozen models needed downstream;
4. execute the actual downstream model path;
5. run the rule barrier;
6. produce structured XAI;
7. produce narration;
8. expose module outputs.

Do not replace the entire pipeline with:

```text
lookup final result from CSV
```

That is replay, not frozen-model inference.

---

# Skill 22 — Keep Inference Modes DRY

Historical, frozen-cached, and manual inference should share internal functions.

Prefer:

```text
different input adapters
        ↓
shared feature preparation
        ↓
shared model execution
        ↓
shared rule engine
        ↓
shared XAI
```

over three duplicated pipelines.

---

# Skill 23 — Debug Numerically

When model results are suspicious, print or log the first meaningful numerical evidence.

Examples:

```text
input shape
min/max
mean/std
finite ratio
label distribution
prediction distribution
loss
class probabilities
join counts
unmatched IDs
```

Do not infer numerical correctness from absence of exceptions.

---

# Skill 24 — Debug Alignment Failures

When row counts diverge:

1. compare unique IDs;
2. compare timestamp ranges;
3. compare split filters;
4. inspect duplicates;
5. inspect dropped NaNs;
6. inspect lookback/window effects;
7. inspect market-calendar differences;
8. perform anti-joins to identify missing keys.

Do not "fix" alignment by truncating both arrays to the same length.

---

# Skill 25 — Validate Final Outputs

For each final split verify:

```text
row count
class distribution
confidence range
position sizing range
finite risk metrics
unique alignment keys
required columns
```

Compare with upstream counts where the architecture implies equality.

Large unexplained row loss is a bug until proven otherwise.

---

# Skill 26 — Verify the UI Against Raw Output

For representative cases compare:

```text
raw inference JSON
vs
displayed UI values
```

Check:

* recommendation;
* confidence;
* position size;
* analyst outputs;
* risk values;
* rules;
* explanation.

The UI must not silently round, transform, or reinterpret a value into a different conclusion.

---

# Skill 27 — Safe Git Workflow

Before committing:

```text
git status
git diff --stat
git diff
```

Confirm that only intended files changed.

For generated data/model files determine whether they should be:

```text
ignored
tracked normally
tracked through Git LFS
```

Do not commit `.env`.

Before destructive cleanup inspect ignored files separately.

---

# Skill 28 — Recover from Git Mistakes

When working-tree state becomes unsafe:

1. stop issuing destructive commands;
2. inspect branches;
3. inspect stashes;
4. inspect reflog;
5. identify Git-tracked recoverable content;
6. identify LFS content;
7. identify untracked/ignored content;
8. recover to a separate safe location first;
9. verify recovered artifacts;
10. only then rebuild the working tree.

Do not perform cleanup while recovery is still underway.

---

# Skill 29 — Long Remote Jobs

For remote training, embedding generation, or large Git/LFS transfers use persistent terminal sessions.

Typical pattern:

```text
SSH
→ tmux
→ activate environment
→ start job
→ detach
```

A network disconnect should not terminate a multi-hour computation.

---

# Skill 30 — Documentation After Implementation

Once a component is stable, document:

```text
purpose
inputs
outputs
data source
split scheme
algorithm/model
HPO
training
checkpoint paths
artifact formats
inference interface
validation
known limitations
```

Documentation should represent the current architecture.

Move obsolete design decisions into a clearly marked historical section rather than mixing them with active instructions.

---

# Final Workflow

The preferred end-to-end problem-solving loop is:

```text
1. Inspect repository
2. Inspect runtime
3. Inspect data
4. Trace full dependency path
5. Identify root cause / required change
6. Make minimal modification
7. Compile
8. Run targeted tests
9. Run real-data smoke test
10. Verify restart/resume behaviour
11. Run HPO where applicable
12. Run full computation
13. Validate artifacts numerically
14. Validate multimodal alignment
15. Validate inference
16. Validate XAI
17. Inspect Git diff
18. Update documentation
19. Commit only understood changes
```

The governing principle is:

> **Never spend hours recomputing something that could have been validated in minutes, and never destroy state that could have saved hours of recomputation.**
