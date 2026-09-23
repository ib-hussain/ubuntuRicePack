# MEMORY.md — Fin-Glassbox Durable Context

## Purpose

This is the durable context file for Fin-Glassbox. It separates stable project decisions from historical snapshots that must be revalidated. Update it when Ibrahim Hussain changes an architectural decision or when a newer verified run supersedes an older result.

## Identity and names

- Owner/lead context: **Ibrahim Hussain**, BS Data Science.
- Repository: `ib-hussain/fin-glassbox`, normally `main`.
- Local Windows path historically used: `D:\Downloads\Repositories\fin-glassbox`.
- WSL path historically used: `/mnt/c/Users/ibrahim/Downloads/fin-glassbox`.
- Remote Linux path historically used: `~/fin-glassbox`.
- Formal title: **An Explainable Multimodal Neural Framework for Financial Risk Management**.
- Conversational aliases: **Fin-Glassbox** and **Explainable Distributed System for Finance**.
- Historical team included Ibrahim Hussain, Lubabah Moten, and Sabeel Nadeem. Verify current contacts from the repository before publishing them.
- Correct Git author context for Ibrahim: `Ibrahim Hussain` and `ibrahimbeaconarion@gmail.com`; use repository-local configuration when a machine's global identity belongs to somebody else.

## Durable architecture decisions

### Inputs

1. Market data.
2. SEC filing text subset.
3. FRED macroeconomic data.
4. Cross-asset graph data.

The final cleaned modelling panel was historically described as 2,500 stocks across 6,286 trading days with zero missing values. This describes the cleaned modelling dataset, not every ticker ever queried during raw acquisition.

### Removed branch

- The Fundamental Analyst/branch was explicitly removed on 2026-05-02.
- It must remain absent from architecture, training, fusion, inference, UI, tests, and documentation unless Ibrahim reverses this decision.

### Encoders and learned modules

- Temporal Attention Encoder with approximately 30-day windows.
- FinBERT text encoder, historically fine-tuned using MLM and designed with a future supervised mode.
- FinBERT representation size 768, followed by PCA to 256 fitted on training data only.
- Technical, Sentiment, and News analysts.
- Quantitative Analyst and PositionSizing components in the inference/fusion path.
- Cross-asset graph models used for contagion/regime evidence; StemGNN/MTGNN ideas were adapted from forecasting use.
- Risk stack: volatility, drawdown, VaR, CVaR, liquidity, contagion, and regime.
- Learned MLP/FusionEngine followed by deterministic rule constraints/barrier.
- Structured XAI precedes narration.
- Qwen3-0.6B is narrator-only and must not determine or alter the decision.

### Chronological chunks

| Chunk | Total period | Historical train | Historical validation | Historical test |
| --- | --- | --- | --- | --- |
| C1 | 2000–2006 | 2000–2004 | 2005 | 2006 |
| C2 | 2007–2016 | 2007–2014 | 2015 | 2016 |
| C3 | 2017–2024 | 2017–2022 | 2023 | 2024 |

All learned preprocessing is fit on each relevant training partition only.

### Inference modes

1. Historical replay.
2. Frozen-cached Type B.2 inference.
3. Manual frozen inference.

### Transparency requirements

- Transparency is the default UI posture.
- Provide a user-friendly summary.
- Provide a full-system explanation.
- Provide per-module outputs in a sidebar/detail view.
- Provide raw structured JSON.

## Data and format decisions

- FinBERT output format: `.npy` embeddings with CSV metadata.
- Parquet was explicitly rejected for this embedding path.
- Stable date/ticker/document/chunk/split alignment is mandatory.
- Git LFS is used for intentionally versioned large CSV/model artifacts.
- Raw/processed datasets, caches, experiment logs, outputs, and intermediate models are normally ignored or kept outside ordinary Git.
- `.env` is local-only and uncommitted.
- Checkpoint compatibility encountered three payload keys: `state_dict`, `model_state_dict`, and `model_state`.
- Quantitative Analyst and FusionEngine inference require their retained scalers/feature-order contracts.

## Historical environment snapshot — April/May 2026

This is not a guarantee of the current machine:

- Ubuntu 22.04.
- Python 3.12.7.
- CPU: 6 cores / 12 threads.
- RAM: 64 GB.
- GPU: NVIDIA RTX 3090 Ti, approximately 24 GB VRAM.
- A recorded driver/CUDA snapshot was driver 535.288.01 and CUDA 12.2.
- Remote work used `tmux` and persistent logs.
- Performance helper scripts historically saved/restored CPU governor/boost/EPP and GPU power/persistence settings.

Always inspect the live environment before training. A prior observation of 50–60% GPU utilisation pointed to possible data-loader, preprocessing, batch-size, disk-I/O, or competing-process bottlenecks rather than proof of a model problem.

## Historical FinBERT output snapshot — 2026-04-25

The completed run recorded these embedding counts:

| Chunk | Train | Validation | Test |
| --- | ---: | ---: | ---: |
| C1 | 189,244 | 40,000 | 40,000 |
| C2 | 320,000 | 40,000 | 40,000 |
| C3 | 240,000 | 40,000 | 40,000 |

- C3 training-fitted PCA explained variance recorded: `0.980576`.
- These counts/metric belong to that artifact set. Re-read current manifests before using them as acceptance criteria.

## Historical raw market coverage audit — 2026-04-24

- Requested/audited universe: 4,534 tickers.
- Tickers with local target rows: 4,228.
- Zero-local tickers: 306.
- Local panel size at that audit: approximately 16.2 million rows and 56.88% of the full requested ticker/date rectangle.
- All 2,574 partially covered tickers were classified as `YAHOO_OR_LISTING_LIMITED_HISTORY` in that audit.
- Historical processed OHLCV schema: `date,ticker,open,high,low,close,volume,dividends,stock_splits`.

This acquisition audit is separate from the final cleaned 2,500-stock panel and must not be used to contradict or merge its figures.

## Historical fused-output snapshot

- Final files followed patterns such as `fused_decisions_chunk3_test.csv` and `chunk{1,2,3}_{val,test}` fusion outputs.
- A C3 test snapshot had 427,500 rows: HOLD 403,315; BUY 24,182; SELL 3.
- The historical demo schema contained 104 columns, including final recommendation/signal/risk/confidence/position, analyst outputs, XAI summaries, risk drivers, regime/liquidity, flags, chunk, and split.
- Example historical module metrics included Technical accuracy C3 49.02%, News F1 C3 0.877, Sentiment accuracy C3 31.76%, and VaR95 breach 4.74%.

These numbers are dated evidence, not targets and not proof of the current model. Validate the current files and investigate extreme class imbalance rather than silently changing it.

## Durable workflow preferences

- Commands for this project must be one line; Ibrahim explicitly rejected backslash-separated command formatting.
- Preserve and resume expensive work instead of restarting preparation, HPO, or training.
- Use persistent Optuna/TPE studies, epoch checkpoints, latest/best state, manifests, and fingerprints.
- Provide progress, `tqdm`-style status, CPU/RAM, and CUDA/VRAM telemetry.
- Maximise safe resource use only after measuring bottlenecks.
- Prefer minimal root-cause fixes integrated into the existing repository.
- Run compile/import checks, focused tests, real-data smokes, resume checks, output validation, full affordable tests, and final diff/status review.
- Use British English in documentation.
- README is stable/informational and contains no progress or done/not-done tracking.
- Release archives are code-only by default.

## Historical repository recovery decision — 2026-05-06

A Windows checkout became stuck in a file-lock/failed-merge state. The safe recovery plan was:

1. Preserve definitive copies of `code/deploy.py`, `code/inference.py`, `Paper.docx`, and local `.env` in a backup location.
2. Clone clean `origin/main` into a new directory.
3. Copy only inspected definitive source/document files.
4. Test and inspect the diff.
5. Commit/push intended files only.
6. Restore `.env` locally without committing it.

This remains the preferred pattern for a similarly corrupted checkout, but first inspect which files are definitive now.

## Known failure distinction

A deployment can fail before application startup because Git LFS objects cannot be cloned or downloaded. Diagnose repository/LFS acquisition separately from Python dependencies and app runtime. Do not edit application logic to fix a clone-stage failure.

## Documentation map observed historically

Important repository areas/files have included:

- `code/analysts/`
- `code/encoders/`
- `code/fusion/`
- `code/gnn/`
- `code/riskEngine/`
- `code/inference.py`
- `code/inference_training.py`
- `README.md`
- `SETUP.md`
- `WORKFLOW.md`
- `xAI.md`

Older or removed artifacts included multiple final-paper versions and superseded hyperparameter/XAI/workflow documents. Inspect the current tree; do not recreate removed files merely because they existed historically.

## Open verification checklist for future sessions

At the start of a new task, revalidate:

- Current repository branch, commit, dirty state, and LFS health.
- Current data manifests, chunk boundaries, schemas, and artifact fingerprints.
- Whether any architecture/config still contains a Fundamental branch.
- Current environment, GPU availability, and competing processes.
- Latest checkpoints, HPO study, scalers, PCA, and feature order.
- Current fusion schema and decision distribution.
- Which inference modes are operational versus only documented.
- UI and deployment health.
- Actual tests and coverage for the current commit.

## Memory update rule

When a current verified result supersedes a historical snapshot:

1. Keep the durable decision if unchanged.
2. Add a new dated snapshot with artifact/config/commit identity.
3. Mark the older snapshot superseded rather than deleting useful provenance.
4. Never promote a chat claim to durable fact without repository, manifest, log, or direct user confirmation.

## Later durable corrections that supersede earlier descriptions

### Architecture/orchestration

- No Fundamental Analyst.
- No Bull/Bear debaters.
- No LangChain orchestration in the decision path.
- Use specialised analysts + risk engines + learned fusion + deterministic rule barrier + structured XAI.

### Fusion/position

- Learned weighting runs before the user-configurable rule barrier.
- Final position uses the conservative cap:

```text
min(position_sizing_recommendation, learned_position_suggestion, user_rule_cap)
```

- Retain all operands and the rule/cap reason for audit.
- Reject stale Quantitative Analyst output lacking attention fields such as `top_attention_risk_driver`, `attention_pooled_risk_score`, and the `risk_attention_*` family.

### UI/deployment

A later May 2026 correction superseded an earlier design that exposed many controls:

- Qwen is fixed as the narrator.
- Package the full required model/artifact set for the deployment.
- Remove repository-root, chunk, device, split, and transparency controls from the ordinary user UI.
- Always expose full transparency and outputs from all models/modules.
- Provide longer explanation context where practical.
- Operator launch configuration may remain outside the user-facing interface.

## FinBERT workflow decisions in more detail

- CUDA/parallel implementation was required.
- The design supports MLM plus a future/approved supervised path.
- Approved sequence name: `mlm_then_supervised`.
- Supervised labels are generated from post-filing market outcomes with anti-leakage timing rules.
- Optuna TPE HPO is connected to real training and stored persistently in SQLite/resumable form.
- Epoch checkpoints resume from the latest compatible checkpoint.
- Three chronological chunks are preserved.
- Save frozen and unfrozen model forms.
- Save embeddings for every split/chunk as `.npy` with CSV metadata.
- Fit PCA on the training embeddings only and reduce 768 → 256.
- Parquet is not allowed for this embedding path.
- Historical command concepts: `build-labels`, `train-mlm`, `train-supervised`, `hpo`, `embed-all`, `freeze`. Verify the current CLI.

## FinBERT smoke snapshot — 2026-04-25

A recorded chunk-3 CUDA smoke run reported:

- overall referenced dataset size: 989,244 rows;
- train period: 2017–2022;
- validation period: 2023;
- 250 training batches and 125 validation batches in that smoke configuration;
- recorded losses: 5.679640 training / 4.690189 validation;
- exports under `outputs/models/FinBERT/chunk3/model_unfreezed` and `model_freezed`.

The snapshot also had remaining path-case and AMP/scheduler concerns in the surrounding work. It is not current completion proof.

## Quantitative Analyst historical snapshot — 2026-05-02

A chunk-1 attention-model run was reported with:

- train rows: 2,942,618;
- validation rows: 433,059;
- test rows: 430,559;
- parameter count: 12,740;
- best validation loss: `0.000005`;
- validation/test recommendations all HOLD in that snapshot;
- top attention driver overwhelmingly contagion.

Interpretation guard: the very small loss, all-HOLD output, and attention concentration require target/scale/class/attention audit. They are historical observations, not evidence that the module was ideal.

## Type B.2 cached-module memory

Historical cached/frozen deployment described module outputs for:

- Technical;
- Volatility;
- Drawdown;
- VaR/CVaR;
- Liquidity;
- StemGNN;
- MTGNN;
- Position Sizing;
- Qualitative;
- Quantitative;
- Fusion;
- Sentiment/News.

One described flow reused cached upstream outputs and recomputed Quantitative + Fusion. Current code/config determines the exact mode. Do not assume every historical module name still has an independent runtime checkpoint.

## Historical packaged artifact expectations

- Narrator path: `outputs/models/Narrator/Qwen3-0.6B`.
- Quantitative Analyst chunk-3: `final_model.pt` plus `scaler.npz`.
- FusionEngine chunk-3: `final_model.pt` plus `scaler.npz`.
- Compatible cached chunk-3 validation/test CSVs.
- `code/inference.py` and `code/deploy.py` were definitive user-edited files during the later repository recovery.

Verify every current path and LFS object. Do not treat an LFS pointer as a model.

## UI sample memory

The historical `fused_decisions_chunk3_test.csv` example contained 104 columns and sample A records around 2024-03-26 to 2024-04-02. Those examples produced HOLD, had `text_available=0`, and showed liquidity as a top risk driver. This illustrates the need for conditional text evidence and full module transparency; it is not a fixed demo-row requirement.

## Market downloader incident detail — 2026-04-24

- An initial audit attempted 6,859 tickers and failed all of them.
- Root cause was a local `data/yfinance.py` shadowing the installed third-party `yfinance` import.
- The repository also contained/used a custom `code/yfinance_ib/` package and a corresponding installed package that worked better in the tested environment.
- Subsequent coverage analysis examined Yahoo/listing history versus local coverage, rather than treating all gaps as downloader loss.

Durable lesson: log the imported module path and one-ticker source probe before universe-scale acquisition.

## SEC source scale snapshot

Project résumé/documentation evidence described:

- 900,000+ submissions JSON inputs;
- 17 GB+ company-facts data;
- 300,000+ raw filing documents.

These are broad source-scale claims. Current processed subset counts and exact file semantics must come from current manifests.

## Git/LFS operational timeline

### 2026-04-23 identity repair

- Remote/repository context: `ib-hussain/fin-glassbox`.
- Repo-local author corrected to Ibrahim Hussain `<ibrahimbeaconarion@gmail.com>`.
- A commit was amended/reset-author and force-pushed with the intended history correction.
- Follow-up history searches reported no remaining wrong-author commits in `origin/main` or all local refs at that time.

### 2026-04-25 large LFS push

- A long push displayed approximately 18–19 GB transferred at about 9%, suggesting roughly 200–210 GB total.
- `tmux` was used so the SSH disconnect would not kill the job.
- File counts/sizes/total sizes/LFS objects/dry-run checks were part of the investigation.

Durable lesson: inventory and justify large artifact sets before LFS push; check quota and deployment support.

### 2026-05-06 Windows merge/lock incident

- Local `main` and `origin/main` were reported as diverged 68 versus 12 commits.
- Worktree was stuck in `MERGING`.
- Merge abort/reset attempts failed on Windows unlink/invalid-argument locks involving files such as `README.md` and `code/deploy.py`.
- Four JSON files had LFS pointer-related errors.
- Definitive external backups existed for `deploy.py`, `inference.py`, `.env`, and `Paper.docx`.
- Clean-clone recovery was chosen over further destructive repair.

## Repository documentation/cleanup provenance

Historical cleanup records included removal of superseded artifacts such as:

- `researchPapers/FinalPaper_v1.2.pdf` through `FinalPaper_v2.0.pdf`;
- `FinalPresentation_fin-risk.pptx`;
- `Hyperparameter_Config.md`;
- `MASTER_PROMPT.md`;
- `WORKFLOW_v1.md` and `WORKFLOW_v2.md`;
- `XAI_Specifications.md`;
- old workflow images/Draw.io exports;
- some older module Markdown/code files.

This does not mean their topics are unimportant; it means future agents should not recreate superseded files from memory. Inspect the current documentation map.

## `.gitignore`/artifact memory

Historical ignore rules covered many generated items, including experiment logs, caches, outputs, secrets, virtual environments, data products, SEC/FRED/yFinance processed files, analyst XAI arrays, and intermediate model checkpoints. One snapshot excluded `latest_checkpoint.pt` and `final_model.pt` patterns but did not necessarily exclude every `best_checkpoint.pt`/`epoch_*.pt` variation. Audit current ignore rules before training or packaging.

## Performance operational memory

- Historical remote GPU snapshot: RTX 3090 Ti, 24,564 MiB, persistence enabled, 450 W reported cap, approximately 59% utilisation at one observation, two Python processes using small portions of memory.
- CPU/GPU performance scripts saved and restored governor/boost/EPP/persistence/power settings.
- A reported GPU maximum of 516 W in another query must not be blindly applied; always use the live card's reported allowed range.
- Sustained 50–60% utilisation motivated investigation of loader/preprocessing/batch/disk/competing processes.

## Known uncertainty register

Revalidate rather than assume:

- exact current project title wording in all documents;
- current team/contact list;
- current module filenames after cleanup;
- whether MTGNN remains an independent active module;
- current fusion schema column count;
- exact active inference recomputation/caching path;
- current deployment packaging and LFS strategy;
- current tests/coverage;
- whether supervised FinBERT training was completed beyond the documented MLM/future capability;
- point-in-time/vintage handling for FRED;
- current model/provider/licence constraints for packaging Qwen.

## Expanded new-session checklist

### Repository

- branch/commit/dirty state;
- remote and repo-local author;
- LFS status and materialised files;
- definitive local files/backups;
- active docs and stale references.

### Data

- source inventories and sizes;
- market panel versus raw acquisition universe;
- SEC/FRED/graph manifests;
- chronological boundaries and leakage audit;
- current row counts/schema/fingerprints.

### Models

- FinBERT/Temporal/analyst/risk/graph artifacts;
- HPO studies and resumable state;
- latest/best/final checkpoints;
- scalers/PCA/feature order;
- current attention/fusion schemas.

### Outputs/UI

- fused row alignment and distribution;
- barrier trigger distribution and final-position operands;
- XAI/raw JSON completeness;
- fixed Qwen narrator/fallback;
- removal of user-facing operator controls;
- all-module transparency.

### Verification

- current syntax/tests/smokes/resume tests;
- target GPU/deployment status;
- package/archive manifest and secrets/data exclusions.
