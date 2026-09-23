# Profile Selection Guide

Use the smallest set of instructions that fully covers the current repository. More files do not automatically produce better behaviour; conflicting project assumptions are dangerous.

## Selection matrix

| Repository/task | Baseline | Specialised profile | Project pack |
| --- | --- | --- | --- |
| General Python/Git repository | `templates/core` | None unless needed | None |
| ML/DL/data pipeline | `templates/core` | `templates/ml-systems` | Use project pack if present |
| Ubuntu/Arch/WSL/GNOME automation | `templates/core` | `templates/linux-desktop-automation` | `projects/ubuntuRicePack` when applicable |
| Native Windows/PowerShell/data app | `templates/core` | `templates/windows-data-automation` | `projects/sqlAutomation` when applicable |
| Continue/Ollama coding stack | `templates/core` | `templates/local-ai-continue` | None |
| DeepDocForgery | `templates/core` + `templates/ml-systems` | Linux profile for environment tasks | `projects/DeepDocForgery` |
| Fin-Glassbox | `templates/core` + `templates/ml-systems` | Windows/Linux profile only for platform work | `projects/fin-glassbox` |

## Do not combine these assumptions blindly

- Fin-Glassbox chronological financial splits are not DeepDocForgery's source-group-disjoint image splits.
- DeepDocForgery's `output/` contract does not automatically define another repository's artifact root.
- UbuntuRicePack's no-Snap policy is binding for that project, not a universal Linux rule unless Ibrahim says so.
- Fin-Glassbox's `.npy` plus CSV decision applies specifically to its FinBERT embedding path.
- SQL automation's no-timezone timestamp convention applies where that project contract requires it; do not retroactively rewrite unrelated timestamps.
- Continue model names and cloud availability are a configuration snapshot. Verify provider availability before changing or reinstalling the stack.

## Recommended repository layout

For a represented project:

```text
repository/
├── AGENTS.md                 # Project-specific behavioural contract
├── README.md                 # Stable project introduction and usage
├── docs/                     # Architecture, setup, data contracts, workflows
├── configs/                  # Versioned configuration, no secrets
├── src/ or code/             # Product/research code
├── tests/                    # Unit, integration, smoke, resume tests
├── scripts/                  # Narrow orchestration/setup helpers
└── output/ or outputs/       # Generated state, normally ignored
```

Adapt to the existing repository. Do not reorganise a working tree only to match this example.

## Starting a new task

Before making a change, the agent should be able to answer:

1. Whose project is this?
2. Which instruction files apply?
3. What exactly is authorised: review, diagnosis, implementation, packaging, or deployment?
4. What current user changes must be preserved?
5. What environment and shell are active?
6. What is the smallest reproducible failure or vertical feature slice?
7. What state, checkpoints, data, or outputs can be reused safely?
8. What checks will demonstrate completion rather than merely absence of an exception?

If those answers are unavailable, inspect first. Ask only when inspection cannot resolve a material choice.
