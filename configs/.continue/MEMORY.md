# MEMORY.md — Continue/Ollama Snapshot

## Durable preferences

- Ibrahim wants a simple scripted setup, not many manual configuration steps.
- Main script location: `C:\Scripts`.
- Continue should support autocomplete, chat, edit, apply, agent/tool-aware work where supported, repository context, reusable prompts, and local plus optional Together models.
- Ollama's ordinary Windows startup entry should remain off when the deterministic hidden Continue launcher is installed.
- API keys belong in `.continue/.env`, not YAML or scripts.
- CPU-only was the selected default after the tested iGPU path did not improve the practical experience.

## Saved configuration snapshot — 2026-09-18

- Stack name: `Ibrahim Dev Stack`, version `1.0.0`, schema `v1`.
- Ollama API: `http://127.0.0.1:11434`.
- Model store: `D:\Games\AI`.
- Gemma3 1B autocomplete: context 32,768; max tokens 512; temperature 0.1; autocomplete prompt cap 8,192; cache/import/recent context enabled.
- Qwen2.5-Coder 3B: chat/edit/apply; context 32,768; max tokens 8,192; temperature 0.15.
- CodeQwen 7B: optional chat; configured context 65,536/max 16,384, but hardware practicality must be rechecked.
- DeepSeek-R1 1.5B: optional reasoning chat; configured large context/max output, but actual feasible context is hardware-dependent.
- CodeLlama 7B: optional chat.
- Together configuration used separate scout, code-agent, reasoner, and reviewer roles. Revalidate current provider identifiers.

## Historical benchmark observations

- System memory observed: 11.88 GB total and 5.49 GB free.
- Gemma warm response was approximately 0.591 seconds in both compared CPU and tested GPU paths; the tested GPU cold path was approximately 39.8 seconds.
- CodeQwen 7B used roughly 4.3 GB in the observed GPU test, took approximately 83.6 seconds, and produced poor output in that trial.
- One attempted benchmark was invalid because the PowerShell body variable was undefined; do not interpret that request failure as a model result.

These are dated observations, not permanent acceptance thresholds.

## Installed artifacts in the saved script

- `C:\Scripts\start_ollama_continue_hidden.vbs`
- a current-user Startup shortcut named `Ollama Continue.lnk`
- `%USERPROFILE%\.continue\config.yaml`
- optional `%USERPROFILE%\.continue\.env.example`
- `C:\Scripts\ollama-continue.log`

The installer backs up an existing config as `config.yaml.backup-<timestamp>` before replacement.
