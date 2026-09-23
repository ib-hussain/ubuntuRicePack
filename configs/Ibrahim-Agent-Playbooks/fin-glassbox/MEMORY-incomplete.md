# MEMORY.md

## Purpose

This file contains persistent project context for `fin-glassbox`.

It exists so that a new AI agent can understand major decisions without reconstructing the entire development history.

This is **project memory**, not general user biography.

---

# 1. Ownership and Scope

**Owner / primary developer:** Ibrahim Hussain
**Field:** BS Data Science
**Repository/project:** `fin-glassbox`

The project has also been described as:

> Explainable Distributed System for Finance

and in earlier documentation as:

> An Explainable Multimodal Neural Framework for Financial Risk Management

Treat `fin-glassbox` as the stable repository identity.

Do not mix this project with unrelated account conversations involving Physics teaching, Ali Asad, German-language work, Vienna, IoT devices, or unrelated electronics projects.

---

# 2. Core Objective

The project is an explainable multimodal financial-risk and decision framework.

It combines heterogeneous signals rather than relying on one monolithic model.

Primary information families are:

1. market/time-series data;
2. SEC filing text;
3. macroeconomic/FRED data;
4. cross-asset graph relationships;
5. explicit quantitative risk measures.

The architecture emphasises transparency and intermediate outputs.

---

# 3. Final Architectural Direction

The settled high-level architecture is:

```text
Market stream
    ↓
Temporal / Technical processing
    ↓
Technical signal
                         ┐
SEC filing stream       │
    ↓                    │
FinBERT                  │
    ↓                    │
Sentiment / News         │
                         │
Macro/FRED ──────────────┤
                         ├──→ Learned Fusion
Cross-asset graphs       │         ↓
    ↓                    │     Rule Barrier
Contagion / Regime       │         ↓
                         │   Final Decision
Risk modules ────────────┘         ↓
                              Structured XAI
                                   ↓
                               Qwen narrator
```

---

# 4. Current Analyst Set

The later settled design focuses on:

```text
Technical Analyst
Sentiment Analyst
News Analyst
```

A standalone Fundamental Analyst is not part of the final design.

---

# 5. Fundamental Branch Decision

The Fundamental Encoder / Fundamental Analyst was deliberately removed.

Do not reintroduce it simply because old files or documentation mention fundamentals.

CIK-to-ticker mapping remains useful for SEC/company alignment and was retained independently from the removed Fundamental branch.

---

# 6. Historical Modules

Older repository states included modules or concepts named similarly to:

```text
QualitativeAnalyst
QuantitativeAnalyst
```

These existed during earlier architecture/inference iterations.

Their existence should not automatically redefine the current architecture.

Before removing historical files, however, inspect active imports and saved-model dependencies.

---

# 7. Risk Stack

The project evolved toward an explicit risk stack including:

```text
Volatility
Drawdown
VaR
CVaR
Liquidity
Contagion
Regime
```

The risk system is deliberately visible to the user.

Risk calculations should remain individually inspectable rather than disappearing into one opaque aggregate.

---

# 8. Graph Models

Graph-based work included architectures derived from systems such as:

```text
StemGNN
MTGNN
```

They were adapted to project-specific cross-asset tasks including:

```text
contagion
market relationships
regime behaviour
```

They should not be documented merely as generic price-forecasting modules.

---

# 9. Chronological Splits

Canonical temporal splits:

## Chunk 1

```text
Train:      2000–2004
Validation: 2005
Test:       2006
```

## Chunk 2

```text
Train:      2007–2014
Validation: 2015
Test:       2016
```

## Chunk 3

```text
Train:      2017–2022
Validation: 2023
Test:       2024
```

These boundaries are central to leakage prevention.

---

# 10. SEC / FinBERT Dataset Snapshot

One canonical SEC text dataset used during development was:

```text
final/filings_finbert_chunks_balanced_25y_cap40000.csv
```

Recorded characteristics:

```text
989,244 chunks
years: 2000–2024
maximum: 40,000 chunks/year
```

Recorded SHA-256:

```text
e4476ef3395b8f8f46bfbd19524d206d5012c60f2554c69c0c92fe4479c73f96
```

This hash identifies that specific dataset version and should not be treated as the hash of future regenerated datasets.

---

# 11. FinBERT Design

FinBERT processing used MLM fine-tuning before downstream representation use.

Raw transformer representation:

```text
768 dimensions
```

Final representation:

```text
256 dimensions
```

The dimensionality reduction stage is PCA.

PCA must be fitted on training data only.

Outputs use:

```text
.npy embeddings
CSV metadata
```

Parquet was explicitly rejected for this workflow.

---

# 12. Recorded FinBERT Split Shapes

A completed FinBERT run produced the following embedding row counts:

## Chunk 1

```text
train: 189,244
val:    40,000
test:   40,000
```

## Chunk 2

```text
train: 320,000
val:    40,000
test:   40,000
```

## Chunk 3

```text
train: 240,000
val:    40,000
test:   40,000
```

All final embeddings were 256-dimensional.

These numbers are useful historical validation references but are not universal constants if the source dataset changes.

---

# 13. Temporal Encoder

The settled temporal design uses an approximately:

```text
30-day window
```

The temporal encoder produces high-volume market representations and therefore requires efficient batching and resumability.

Recorded output examples from development included millions of rows per split.

Do not treat exact historical row counts as architecture constants.

---

# 14. Market Data History

Market-data engineering involved a much larger acquisition universe before final filtering.

Historical acquisition/audit work included:

```text
target universe: 4,534 tickers
date range: 2000-01-03 through 2024-12-31
```

A custom downloader/package existed under:

```text
code/yfinance_ib/
```

The project explicitly distinguished:

```text
Yahoo/listing-history limitations
```

from:

```text
local downloader or processing failures
```

Missing history must not automatically be labelled a downloader bug.

Another documented cleaned market panel used later in the project contained approximately:

```text
2,500 stocks
6,286 trading days
zero missing values
```

These represent different stages of the data-engineering pipeline, not contradictory universes.

---

# 15. Data Integrity Principle

Data integrity takes priority over artificially complete coverage.

Do not fabricate historical financial observations merely to fill gaps.

When possible:

```text
recover from legitimate sources
→ identify listing-history limitations
→ document unresolved gaps
```

instead of interpolation that creates nonexistent market history.

---

# 16. HPO

The project standardised on HPO-first training for trainable modules.

Preferred system:

```text
Optuna
TPE
SQLite persistence
```

Studies should resume by default.

A deliberate `--fresh` operation may create a new study.

Full training should not rely on unexplained hardcoded epoch counts when an HPO workflow exists.

---

# 17. Training and Checkpoints

Training is expected to be resumable.

Important behaviours:

```text
checkpoint each epoch
maintain latest checkpoint
save optimisation state
resume from latest
```

The project has repeatedly prioritised avoiding expensive recomputation.

---

# 18. CPU / GPU

The project has been developed using both local/CPU environments and a remote CUDA machine.

A significant training environment used:

```text
Ubuntu 22.04
Python 3.12.7
NVIDIA RTX 3090 Ti
~24 GB VRAM
```

CUDA was used for neural workloads.

CPU processing remained important for preprocessing, risk calculations and data work.

Code should therefore avoid unnecessary hard dependency on CUDA unless the operation fundamentally requires it.

---

# 19. Long-Running Work

The remote machine was terminal-only.

Long jobs were therefore commonly run inside:

```text
tmux
```

to survive SSH disconnections.

This applies to:

```text
training
embedding generation
large downloads
large Git LFS transfers
```

---

# 20. Fusion

The later architecture uses a learned fusion stage.

The learned fusion signal is subsequently constrained by an explicit rule barrier.

Conceptually:

```text
module outputs
→ learned MLP fusion
→ deterministic rule barrier
→ final recommendation
```

Both pre-rule and post-rule states should remain available for explainability.

---

# 21. Final Decisions

Primary recommendation classes are:

```text
BUY
HOLD
SELL
```

The final output also includes concepts such as:

```text
confidence
position sizing
regime information
liquidity
contagion
risk metrics
XAI summaries
```

---

# 22. Historical Final-Fusion Snapshot

One recorded Chunk 3 test fusion output contained approximately:

```text
427,500 rows
```

with class counts:

```text
HOLD: 403,315
BUY:   24,182
SELL:       3
```

This is a historical run snapshot.

Do not hardcode these values as expected class proportions.

The extreme SELL sparsity is something future evaluation should remain capable of surfacing rather than hiding.

---

# 23. Historical Module Metrics

Recorded project snapshots included values such as:

```text
Technical Analyst C3 accuracy: ~49.02%
News C3 F1:                    ~0.877
Sentiment C3 accuracy:         ~31.76%
VaR95 breach rate:             ~4.74%
```

These numbers are historical evaluation references.

They are **not acceptance thresholds** and must not be used to fabricate passing tests.

Future runs may differ because of:

```text
data changes
code changes
seed changes
hyperparameters
model versions
```

---

# 24. Inference Modes

The project explored three major modes.

## Type A

Historical/replay-oriented inference.

## Type B.2

Frozen-cached inference.

This became the important application mode.

It uses saved trained models together with reusable caches to avoid unnecessarily recomputing the entire historical pipeline.

It should still perform genuine model inference where required.

## Manual

Allows manually supplied inputs while using the same internal system components.

---

# 25. Frozen Model Principle

Frozen inference and replay are not the same.

A system that merely looks up:

```text
date + ticker → final historical recommendation
```

does not satisfy the intended frozen-model inference architecture.

Saved models must remain usable.

---

# 26. Application UI

The inference application was designed around transparency.

Desired behaviours include:

```text
default explanation
full-system output
per-model/module inspection
raw JSON
```

The interface should permit the user to inspect intermediate results rather than only the final recommendation.

---

# 27. Narrator

The selected lightweight narrator model is:

```text
Qwen3-0.6B
```

Its role is natural-language explanation.

It is not responsible for creating the financial recommendation.

---

# 28. Repository Documentation

Important repository-level documentation has included:

```text
README.md
SETUP.md
WORKFLOW.md
xAI.md
```

The root README should function as:

```text
project introduction
architecture overview
documentation hub
```

It should not become a list of which modules happen to be complete on a particular day.

---

#
