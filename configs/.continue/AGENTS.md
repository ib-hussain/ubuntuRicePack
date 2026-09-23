# AGENTS.md — Continue.dev, Ollama and Local Coding Agents

## Scope and identity

Use this profile for Ibrahim Hussain's Windows/WSL local coding-assistant stack: Continue.dev, Ollama, local model storage, optional Together-hosted models, repository context providers, reusable coding prompts, and startup automation.

This is Ibrahim's BS Data Science/software-engineering context. Do not import preferences from other account users.

## Primary goal

The stack should provide a low-friction coding workflow in VS Code:

- fast local inline completion;
- local code explanation, chat, editing, and apply operations;
- optional heavier local chat models;
- optional cloud repository scouting, implementation, deep reasoning, and independent review;
- repository/file/diff/terminal/problems/debugger/tree context;
- reusable data-science, ML, DL, paper-to-code, debugging, testing, review, optimisation, and verification prompts;
- deterministic hidden Ollama startup dedicated to Continue.

Simple daily use matters more than exposing every knob. Installation and startup should be scripted, not a tiring sequence of manual edits.

## Historical machine snapshot

Treat this as dated evidence, not a permanent hardware specification:

- Windows system RAM: 11.88 GB total, 5.49 GB free at measurement time.
- Native Windows Ollama 0.34.2.
- Model store: `D:\Games\AI`.
- Models observed: `gemma3:1b`, `qwen2.5-coder:3b`, `codeqwen:7b`, `deepseek-r1:1.5b`, and CodeLlama variants.
- CPU-only default was selected after the tested integrated-GPU/Vulkan path produced poor cold-load behaviour and no meaningful warm-speed gain for Gemma; CodeQwen 7B also produced slow/poor results in that trial.

Always benchmark the current machine and version before changing the default.

## Established model roles

The saved Continue configuration used:

| Role | Model | Intent |
| --- | --- | --- |
| Inline autocomplete | `gemma3:1b` | Small, warm, cached completion model. |
| Primary local chat/edit/apply | `qwen2.5-coder:3b` | Practical local code work and explanations. |
| Optional local chat | `codeqwen:7b` | Larger coding model when memory/latency is acceptable. |
| Optional reasoning chat | `deepseek-r1:1.5b` | Small reasoning-oriented chat. |
| Optional local chat | `codellama:7b` | Alternative code conversation. |

Cloud roles in the saved configuration included a fast repository scout, a primary code agent, a deeper reasoner, and an independent reviewer through Together. Provider model identifiers and availability may change; verify them before rewriting the configuration.

## Resource realism

- A model listed by Ollama is not necessarily usable with a requested context size on the current RAM.
- Context length in configuration is an upper bound/intent, not proof that the machine can allocate it.
- Benchmark cold load, warm response, generation quality, resident memory, and eviction behaviour.
- Keep only the model needed for the active role warm on a constrained machine.
- Do not set multiple 7B models to remain resident simultaneously on approximately 12 GB system RAM.
- Prefer a smaller reliable autocomplete model over a larger model that stalls editing.

## Ollama service ownership

The established Windows design disables the normal Ollama startup entry and uses one deterministic hidden startup path for Continue:

- script directory: `C:\Scripts`;
- hidden VBS launcher starts `ollama.exe serve`;
- `OLLAMA_MODELS=D:\Games\AI`;
- integrated-GPU use disabled by default;
- keep-alive set to one hour;
- service log written under `C:\Scripts`;
- Gemma autocomplete model preloaded after service startup;
- a user Startup shortcut invokes the hidden launcher.

Do not enable both the normal Ollama startup and the custom launcher. Duplicate servers/process races make diagnosis harder.

## Configuration and secret policy

- Continue config lives under the user's `.continue` directory.
- Back up existing `config.yaml` with a timestamp before replacement.
- Keep provider keys in `.continue/.env`, never directly in YAML or the installer.
- Generate `.env.example` only when the real `.env` does not exist.
- Never print the actual API key.
- Restart VS Code after adding/changing secrets or configuration when required.
- Preserve user settings outside the intended config replacement.

## Continue agent behaviour

All configured agents should follow these core rules:

- inspect relevant files before non-trivial changes;
- preserve repository architecture, APIs, naming, formatting, and dependencies unless change is required;
- never invent files, output, tests, metrics, or dataset properties;
- plan large work from dependencies and validation requirements;
- implement coherent vertical slices;
- run relevant tests/checks and fix failures introduced by the change;
- distinguish paper/source facts from assumptions;
- guard against leakage and irreproducibility in ML work;
- retain checkpoints, provenance, and resumability for experiments;
- prefer reusable source modules/tests over notebook-only production logic.

## Context-provider discipline

The saved configuration enabled file, code, diff, current file, terminal, open files, clipboard, tree, problems, debugger, repository map, and OS context. These are useful only when scoped correctly:

- do not dump the whole repository into a small local model;
- start with repository map/tree/signatures, then fetch relevant files;
- include the current diff for reviews and repairs;
- use terminal/log evidence for runtime bugs;
- avoid clipboard context containing secrets;
- ignore large generated/data/output directories through repository configuration.

## Prompt design

Reusable prompts should state:

- required inspection before edits;
- exact objective;
- source-of-truth evidence;
- constraints/non-goals;
- implementation expectations;
- validation and acceptance criteria;
- prohibition on invented success.

Keep distinct prompts for explaining, refactoring, debugging, tests, review, repository audit/plan, full features, data science, EDA, ML build/debug, DL build/debug, paper-to-code, reproduction, reporting, optimisation, and independent verification.

## Troubleshooting order

When Continue fails:

1. Confirm VS Code and Continue load.
2. Validate YAML syntax/schema.
3. Confirm exactly one Ollama server process.
4. Probe `http://127.0.0.1:11434` and a minimal generation request.
5. Confirm the model exists in the configured model store.
6. Check memory and resident models with `ollama ps`.
7. Test the selected role with a small context.
8. Inspect Continue logs/Developer Tools.
9. Test cloud provider authentication without printing the key.
10. Increase context/tokens only after the basic path works.

Do not diagnose an undefined PowerShell request-body variable as a model failure. Validate the benchmark script itself.

## Verification requirements

- PowerShell script parses/runs from a normal non-admin shell unless an operation truly needs elevation.
- Existing config backup is created when applicable.
- Startup shortcut targets the correct hidden launcher.
- Normal Ollama startup remains disabled as instructed.
- One server starts, listens locally, writes logs, and uses the intended model directory.
- Gemma preload completes or fails harmlessly without blocking login.
- Continue config parses and models appear under intended roles.
- Local autocomplete and local chat are each tested.
- Cloud models are tested only when a key is configured and network use is authorised.
- Secrets are absent from delivered files.

## Release rule

Deliver the installer/config/templates without local model blobs, logs, real `.env`, VS Code caches, or personal secret material. Provide exact PowerShell installation and rollback instructions.
