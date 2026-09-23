---
name: ibrahim-continue-ollama-stack
description: Install, configure, benchmark, diagnose, and safely maintain Ibrahim Hussain's Continue.dev and Ollama coding-assistant stack on Windows and WSL.
---

# Continue and Ollama Workflow

## 1. Inspect current state

1. Record Windows/WSL context, RAM/free RAM, CPU/GPU, VS Code, Continue, and Ollama versions.
2. Locate the actual Ollama executable and `OLLAMA_MODELS` store.
3. List installed models and resident processes.
4. Inspect `.continue/config.yaml`, `.continue/.env` presence (not value), startup entries, `C:\Scripts`, and Ollama logs.
5. Back up the current config before mutation.

## 2. Establish service ownership

1. Choose one service-start mechanism.
2. Disable the competing normal startup entry when using the custom hidden launcher.
3. Set process environment for model directory, keep-alive, and CPU/iGPU policy.
4. Start hidden server with persistent log.
5. Wait bounded time and probe health.
6. Preload only the selected lightweight autocomplete model.
7. Confirm a single listener/process.

## 3. Benchmark model suitability

For each candidate role:

1. Stop unrelated resident models.
2. Record free memory.
3. Run a small deterministic prompt with a correctly defined request body.
4. Measure cold load, warm latency, generation throughput/quality, and resident memory.
5. Inspect whether CPU/GPU is actually used.
6. Test the realistic role/context, not only an empty prompt.
7. Reject a model/setting that causes swapping, editor stalls, very poor output, or repeated timeouts.

## 4. Configure Continue

1. Assign one primary model per role.
2. Set conservative temperature for coding.
3. Choose context/max tokens based on actual capability and memory.
4. Enable cache/import/recent-file features for autocomplete.
5. Configure timeouts long enough for local CPU models without hiding permanent failures.
6. Add cloud models only with `${{ secrets.NAME }}` references.
7. Configure scoped context providers and repository map.
8. Add explicit global coding/ML rules.
9. Add reusable prompts with inspection and verification requirements.
10. Validate YAML before replacing the live config.

## 5. Verify by role

- Autocomplete: open a small repository, warm Gemma, type a realistic function, observe latency and relevance.
- Chat/explain: select code and ask Qwen2.5-Coder to explain using repository context.
- Edit/apply: request a small reversible edit and inspect the diff before applying.
- Agent: verify file/terminal tools only where configured/supported.
- Repository context: ask for real entry points and confirm citations/files are correct.
- Cloud: after secret setup, run a minimal request for each intended role.

## 6. Diagnose failures

| Symptom | First checks |
| --- | --- |
| No models in Continue | YAML parse/schema, extension logs, provider entries |
| Connection refused | Ollama process, port 11434, startup log |
| Wrong model store | `OLLAMA_MODELS` in the owning process |
| Very slow first response | cold load, model size, memory pressure |
| Repeated slow responses | model eviction, keep-alive, swap, context size |
| Empty/bad benchmark | request JSON/body variable and prompt |
| VS Code freeze | model memory, context providers, oversized repository context |
| Cloud auth failure | `.env` presence/name, VS Code restart, provider model availability |

## 7. Rollback

1. Stop the custom Ollama server.
2. Remove/disable the custom startup shortcut if requested.
3. Restore the timestamped Continue config backup.
4. Re-enable the former startup method only if that is the intended rollback.
5. Preserve model files unless deletion was explicitly requested.

## 8. Handoff evidence

- detected versions and memory;
- active service owner and model directory;
- model-role table;
- benchmark results with cold/warm distinction;
- config/installer paths;
- local and cloud role tests actually run;
- untested provider/tool capabilities;
- secret-safety confirmation.
