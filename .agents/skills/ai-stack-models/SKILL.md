---
name: ai-stack-models
description: >
  Use for model management tasks in ai-stack: download models, update GGUF models, model
  registry, models.json, update_models.sh, HuggingFace download, model weights, models/
  directory, model prune, model check, nomic-embed-text, qwen, gemma, deepseek, glm,
  gpt-oss, llama model files, GGUF files, model not found, missing model file, wrong model path.
  Repo: /home/mranykey/Documents/AnyKey/Repos/ai-stack
---

# Model Management

**Models dir:** `models/`
**Registry:** `models.json`
**Script:** `scripts/update_models.sh`
**Docs:** `scripts/README.md`

GGUF model weights are never committed to git. Managed via `update_models.sh` using HuggingFace CLI.

## Check What's Missing

```bash
./scripts/update_models.sh --check-only
```

## Download Missing Models

```bash
./scripts/update_models.sh --all
```

## Remove Orphaned Files

```bash
./scripts/update_models.sh --prune
```

## Filter by Model Name

```bash
./scripts/update_models.sh --model qwen
./scripts/update_models.sh --model deepseek
./scripts/update_models.sh --model nomic
```

## Full Refresh

```bash
./scripts/update_models.sh --all --prune
```

The script auto-restarts llama-swap if model files changed.

## Registry Format

`models.json` defines each model:

```json
[
  {
    "dir": "models/qwen3.6-35b-a3b",
    "repo": "org/Qwen3.6-35B-A3B-GGUF",
    "include": "*.Q4_K_M.gguf"
  }
]
```

To add a new model: add entry to `models.json`, run `--all` to download, add model block to `managed/llama-swap/config.yaml.tmpl`, run `just render-configs`.

## Model Path in llama-swap Config

All model paths in `managed/llama-swap/config.yaml.tmpl` use chezmoi template variable:

```yaml
-m {{ .chezmoi.destDir }}/models/model-dir/model-file.gguf
```

`{{ .chezmoi.destDir }}` resolves to repo root at render time.

## Current Local Models

Defined in `managed/llama-swap/config.yaml.tmpl`. Names must exactly match what LiteLLM sends.

| Model name | Purpose |
| ---------- | ------- |
| `nomic-embed-text` | embeddings |
| `glm-4.7-flash` | fast local chat |
| `gemma-4-26b-moe` | general purpose |
| `qwen3.6-35b-a3b` | reasoning, large ctx |
| `qwen3.6-35b-moe` | reasoning, MoE |
| `gpt-oss-20b` | general purpose |
| `gemma-4-27b-unsloth` | fine-tuned general |
| `deepseek-r1-distill-32b` | deep reasoning |

Source of truth for cloud models and routing: `managed/litellm/config.yaml.tmpl`.
