# AGENTS.md

## Project Identity

**Project:** `fin-glassbox`
**Canonical project description:** Explainable Distributed System for Finance
**Owner / primary developer:** Ibrahim Hussain
**Domain:** Data Science, multimodal machine learning, financial risk modelling, explainable AI, distributed/modular inference.

This file defines how AI coding agents must work inside this repository.

The goal is not merely to produce code that runs. The repository must remain:

* reproducible;
* leakage-safe;
* resumable;
* inspectable;
* modular;
* explainable;
* compatible with both CPU and CUDA where practical;
* safe to operate on expensive datasets and model artifacts;
* recoverable after interruptions;
* understandable by another engineer without relying on chat history.

---

# 1. Core Engineering Philosophy

## 1.1 Evidence before edits

Never begin by rewriting a module from assumptions.

Before modifying code:

1. inspect the repository tree;
2. inspect the relevant implementation;
3. inspect its configuration;
4. inspect the data schema or saved artifact it consumes;
5. inspect downstream consumers;
6. inspect existing tests;
7. inspect logs/checkpoints/manifests from previous runs;
8. determine whether the requested behaviour already partially exists.

Prefer understanding and extending the current system over replacing it.

---

## 1.2 Preserve working state

The repository contains expensive-to-reproduce artifacts.

Never casually delete:

* datasets;
* processed datasets;
* checkpoints;
* embeddings;
* Optuna studies;
* model exports;
* cached predictions;
* manifests;
* `.env`;
* local credentials;
* logs needed for recovery.

Avoid destructive commands such as:

```text
git clean -fdx
```

unless the exact deletion set has first been inspected and the user explicitly wants the deletion.

Ignored files may be the most expensive files in the project.

---

## 1.3 Root-cause debugging

Do not patch symptoms until the complete failing path is understood.

Trace:

```text
input
  ↓
loader
  ↓
preprocessing
  ↓
model/module
  ↓
serialization/cache
  ↓
downstream consumer
  ↓
final output
```

For shape, dtype, path, NaN, checkpoint, alignment, or schema errors, identify the first point where reality diverges from the expected invariant.

Do not insert arbitrary conversions merely to silence exceptions.

---

## 1.4 Minimal changes first

Prefer the smallest correct modification that preserves:

* public interfaces;
* checkpoint compatibility;
* output schemas;
* downstream consumers;
* existing configuration;
* prior results.

Large refactors require evidence that the current structure itself is causing the problem.

---

# 2. Project Architecture

Treat the project as a modular multimodal decision system.

The settled conceptual flow is:

```text
                     ┌──────────────────┐
                     │   Market Data    │
                     └────────┬─────────┘
                              │
                     Temporal / Technical
                              │
                              ▼

┌──────────────────┐   ┌──────────────────┐
│ SEC Filing Text  │──▶│ FinBERT Pipeline │
└──────────────────┘   └────────┬─────────┘
                                │
                     Sentiment / News Signals
                                │
                                ▼

┌──────────────────┐
│ FRED Macro Data  │──────────────┐
└──────────────────┘              │
                                  ▼

┌──────────────────┐      ┌─────────────────────┐
│ Cross-Asset Data │─────▶│ Graph / Risk Models │
└──────────────────┘      └──────────┬──────────┘
                                    │
                           Contagion / Regime
                                    │
                                    ▼

              ┌───────────────────────────────┐
              │          Risk Engine          │
              │                               │
              │ Volatility                    │
              │ Drawdown                      │
              │ VaR / CVaR                    │
              │ Liquidity                     │
              │ Contagion                     │
              │ Regime                        │
              └───────────────┬───────────────┘
                              │
                              ▼

               ┌────────────────────────────┐
               │ Analyst / Feature Outputs  │
               │                            │
               │ Technical                  │
               │ Sentiment                  │
               │ News                       │
               └─────────────┬──────────────┘
                             │
                             ▼

                    ┌─────────────────┐
                    │ Learned Fusion  │
                    │      MLP        │
                    └────────┬────────┘
                             │
                             ▼

                    ┌─────────────────┐
                    │  Rule Barrier   │
                    └────────┬────────┘
                             │
                             ▼

               Recommendation / Confidence
                    / Position Sizing
                             │
                             ▼

                  Structured XAI Output
                             │
                             ▼

                     Qwen3-0.6B
                  explanation narrator
```

The narrator explains results. It must **not become the decision engine**.

---

# 3. Removed / Superseded Architecture

Do not silently resurrect removed components.

## Fundamental branch

The standalone Fundamental Encoder / Fundamental Analyst was removed from the final design.

CIK-to-ticker mapping may remain where required for SEC alignment.

The existence of older files or historical documentation is not evidence that the Fundamental branch should be restored.

## Historical analyst modules

Older repository snapshots may contain concepts such as:

* `QualitativeAnalyst`;
* `QuantitativeAnalyst`;
* older fusion arrangements.

Treat these as historical unless the active code path explicitly depends on them.

When architecture and repository residue disagree, inspect the actual current inference path before changing anything.

---

# 4. Chronological Data Discipline

Financial ML in this repository must be leakage-safe.

The canonical chronological split scheme is:

| Chunk | Train     | Validation | Test |
| ----- | --------- | ---------- | ---- |
| C1    | 2000–2004 | 2005       | 2006 |
| C2    | 2007–2014 | 2015       | 2016 |
| C3    | 2017–2022 | 2023       | 2024 |

Never randomly shuffle temporal observations across these boundaries.

Anything learned from data must be fitted on **training data only**, including:

* PCA;
* scalers;
* thresholds;
* normalisation statistics;
* feature-selection parameters;
* decision thresholds;
* calibration parameters.

Validation and test sets may only be transformed with parameters learned from the corresponding training split.

---

# 5. FinBERT Rules

The text pipeline uses FinBERT-based SEC representations.

Important invariants:

* initial representation dimension: `768`;
* final representation dimension: `256`;
* dimensionality reduction is fitted on training data only;
* outputs use NumPy arrays;
* corresponding metadata uses CSV;
* alignment between embedding rows and metadata rows must be verified.

Do **not** switch the project to Parquet.

Preferred artifact forms:

```text
*.npy
*.csv
*.json
*.jsonl
*.npz
```

unless an existing module explicitly requires something else.

Fine-tuning historically uses MLM before downstream supervised use.

---

# 6. Temporal Modelling

The temporal branch uses an approximately 30-trading-day context/window in the settled design.

Do not modify temporal alignment, window indexing, or label alignment without validating:

* first valid timestamp;
* last valid timestamp;
* number of generated windows;
* target offset;
* ticker boundaries;
* split boundaries.

Never allow a window to cross a train/validation/test boundary improperly.

---

# 7. HPO-First Training

Expensive model training should follow:

```text
inspect
→ smoke
→ HPO
→ select parameters
→ full training
→ validation
→ export
```

Do not jump directly to arbitrary full-training hyperparameters when the component supports HPO.

Preferred HPO stack:

* Optuna;
* TPE sampler;
* persistent SQLite studies.

Studies must be resumable.

Provide a deliberate `--fresh` mechanism where appropriate rather than overwriting an existing study by accident.

Only one major GPU HPO workload should normally run at once.

---

# 8. Failed-Trial Discipline

A bad trial should fail early.

Reject or prune trials when encountering:

* NaN;
* Inf;
* non-finite loss;
* invalid tensor dimensions;
* empty datasets;
* unusable predictions;
* impossible class distributions;
* missing required artifacts.

Do not feed non-finite metrics into Optuna.

---

# 9. Resumability

Every expensive stage should be restartable.

Training should normally provide:

* checkpoint after each epoch;
* a stable latest-checkpoint location;
* optimizer state;
* scheduler state where applicable;
* epoch number;
* model state;
* enough metadata to continue correctly.

A resumed run must continue rather than silently restart.

For multi-stage pipelines, persist stage-level state where practical.

---

# 10. Model Exports

Where the component design requires it, preserve both:

```text
model_unfreezed
model_freezed
```

or the repository's established equivalent.

Do not confuse:

* a training checkpoint;
* a frozen inference model;
* cached predictions;
* replay data.

They serve different purposes.

---

# 11. Inference Modes

The project historically developed several inference modes.

Important conceptual modes include:

### Type A — historical/replay

Uses previously produced historical outputs where appropriate.

### Type B.2 — frozen cached inference

This is an important deployment mode.

It uses the real trained/frozen project models together with reusable cached upstream artifacts where applicable.

It is **not merely replaying a final CSV**.

### Manual inference

Allows controlled user-supplied inputs while reusing the same internal model logic.

Avoid implementing separate duplicate reasoning pipelines for each mode.

Prefer shared internal functions with different data-entry paths.

---

# 12. Explainability

Explainability is part of the architecture, not post-processing decoration.

Every major inference path should preserve useful intermediate outputs.

Where applicable expose:

* branch predictions;
* branch confidence;
* raw module scores;
* volatility;
* drawdown;
* VaR;
* CVaR;
* liquidity;
* contagion;
* regime;
* fusion logits/scores;
* rule modifications;
* final recommendation;
* confidence;
* position sizing;
* structured explanations.

The user should be able to determine:

> Why did the system produce this result?

without depending solely on an LLM-generated paragraph.

---

# 13. Narrator Model

`Qwen3-0.6B` is used as an explanation narrator.

Its responsibility is to transform already-computed structured system outputs into a readable explanation.

It must not:

* invent missing risk values;
* override the rule barrier;
* generate BUY/SELL/HOLD independently;
* replace numerical inference;
* silently alter confidence;
* become a hidden second decision model.

Structured model output remains authoritative.

---

# 14. UI Principles

Transparency is the default.

The interface should support:

* final recommendation;
* confidence;
* position sizing;
* system-level explanation;
* per-module outputs;
* selectable module details;
* raw structured/JSON output.

Do not hide intermediate reasoning behind a single polished narrative.

---

# 15. CLI Design

Important modules should be usable both:

```text
as imports
```

and

```text
as executable CLIs
```

Where appropriate, support operations conceptually equivalent to:

```text
inspect
smoke
hpo
train
predict
validate
```

Use the repository's existing CLI style rather than inventing incompatible conventions.

Useful recurring options include:

```text
--repo-root
--fresh
```

when appropriate.

Do not hardcode one developer's absolute path.

---

# 16. CPU + CUDA Behaviour

Code should work on CUDA where acceleration is useful but should not become unnecessarily unusable on CPU.

Device handling must be explicit.

Typical pattern:

```python
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
```

but follow existing abstractions where present.

CPU work should be parallelised sensibly for:

* preprocessing;
* data preparation;
* statistical risk computation;
* manifest generation;
* validation.

Do not move trivial work to GPU merely because CUDA is available.

---

# 17. Real Data Only

Tests may use tiny subsets of real project data.

Do not create fake financial observations to make a production pipeline appear functional unless a unit test explicitly requires synthetic fixtures.

For integration/smoke testing, prefer:

```text
small real subset
```

over:

```text
invented representative data
```

---

# 18. Validation Before Expensive Execution

Recommended sequence after code changes:

```text
syntax / import validation
→ focused unit test
→ small real-data smoke test
→ resume-path test
→ HPO smoke
→ full operation
```

At minimum, compile changed Python files:

```bash
python -m py_compile <file>
```

Then execute the smallest meaningful path that exercises the modification.

---

# 19. Artifact Validation

Never trust file existence alone.

For generated embeddings, predictions, models, or risk outputs validate:

* path;
* row count;
* shape;
* dtype;
* finite values;
* timestamp range;
* split identity;
* ticker identity where relevant;
* metadata alignment.

For large outputs, generate or preserve manifests.

Use hashes such as SHA-256 when artifacts need strong reproducibility guarantees.

---

# 20. Shell Interaction Style

Ibrahim works in both Linux shells and Windows PowerShell.

Commands must match the active shell.

Do not provide Bash syntax to PowerShell or PowerShell syntax to Bash.

Commands should generally be:

* directly copyable;
* concise;
* explicit;
* single-line when practical.

Avoid Bash commands split using trailing `\` unless there is a compelling reason.

For long-running remote Linux operations, use persistent terminal sessions such as `tmux`.

---

# 21. Git Safety

Before branch surgery, rebases, resets, cleanup, or large LFS operations inspect:

```text
git status
git branch
git log
git diff
git stash list
```

Preserve local-only artifacts.

`.env` must stay local and uncommitted.

Before large LFS pushes, inspect what is actually going to be transferred.

Never assume an ignored file is disposable.

---

# 22. Repository Hygiene

The repository historically separates concerns using structures such as:

```text
code/
data/
outputs/
researchPapers/
setup/
```

with specialised subdirectories for:

```text
analysts/
encoders/
fusion/
gnn/
riskEngine/
```

Documentation should live near the system it describes or be linked from the main documentation hub.

The root README should describe the project and architecture rather than become a running development-status diary.

---

# 23. Documentation Style

Use clear technical English.

Prefer:

* explicit architecture;
* data shapes;
* paths;
* assumptions;
* commands;
* inputs;
* outputs;
* failure modes;
* reproducibility instructions.

Avoid vague statements such as:

> The data is then processed.

Instead state what transformation occurs, where its fitted state comes from, and what output is produced.

British English is preferred for project documentation.

---

# 24. Debugging Response Style

When reporting a problem:

1. state what actually failed;
2. distinguish root cause from symptoms;
3. cite the evidence;
4. explain what must change;
5. make the smallest safe modification;
6. show how to verify it;
7. do not declare success until verification succeeds.

Do not call a pipeline "fixed" because compilation passes.

---

# 25. Definition of Done

A change is complete only when the relevant subset of the following has been demonstrated:

* syntax/import passes;
* targeted test passes;
* real-data smoke path passes;
* checkpoint/resume path works if relevant;
* CPU path remains valid where required;
* CUDA path remains valid where required;
* output schema is preserved or deliberately versioned;
* outputs contain no unexpected NaN/Inf;
* manifests/alignment checks pass;
* documentation is updated;
* no unrelated files were modified;
* Git diff is understood;
* expensive user data was not destroyed.

---

# 26. Agent Behaviour Summary

When working in this repository:

**Inspect first.
Preserve state.
Trace the entire path.
Use real evidence.
Fit only on training data.
Smoke-test before full runs.
HPO before arbitrary training.
Checkpoint expensive work.
Expose intermediate outputs.
Keep the narrator separate from the decision system.
Protect ignored data.
Do not claim success without verification.**
