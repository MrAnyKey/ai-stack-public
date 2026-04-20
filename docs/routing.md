# AI Routing Blueprint

Current routing contract for `ai-stack`.

## Design Rule

All clients talk to LiteLLM (`:4000`). Direct llama-swap (`:8081`) only for debugging.

```text
client
  -> LiteLLM :4000
    -> local: llama-swap :8081 -> llama-server -> GGUF
    -> cloud: OpenAI / Gemini / Anthropic
```

## Local Models

Served by llama-swap. Source of truth: `managed/llama-swap/config.yaml.tmpl`.

| llama-swap name | LiteLLM name | Purpose |
| --------------- | ------------ | ------- |
| `nomic-embed-text` | `nomic-embed-text` | embeddings |
| `glm-4.7-flash` | `glm-4.7-flash` | fast local chat |
| `gemma-4-26b-moe` | `gemma-4-26b-moe` | general purpose |
| `qwen3.6-35b-a3b` | `qwen3.6-35b-a3b` | reasoning, large ctx |
| `qwen3.6-35b-moe` | `qwen3.6-35b-moe` | reasoning, MoE |
| `gpt-oss-20b` | `gpt-oss-20b` | general purpose |
| `gemma-4-27b-unsloth` | `gemma-4-27b-unsloth` | fine-tuned general |
| `deepseek-r1-distill-32b` | `deepseek-r1-distill-32b` | deep reasoning |

> Note: llama-swap model name must exactly match what LiteLLM sends (the part after `openai/`). If names diverge, requests silently fail to route.

## Cloud Models

Source of truth: `managed/litellm/config.yaml.tmpl`.

| LiteLLM name | Provider |
| ------------ | -------- |
| `gemini-2.5-flash-lite` | Gemini |
| `gemini-2.5-flash` | Gemini |
| `gemini-2.5-pro` | Gemini |
| `gpt-5.4-mini` | OpenAI |
| `gpt-5.4` | OpenAI |
| `claude-sonnet-4-6` | Anthropic |

## Routing Policy

Use local for: private input, bulk transforms, embeddings, structural extraction, low-risk drafts.

Use cloud for: final code reasoning, architecture decisions, long-context synthesis, editorial review.

## Fallback Policy

Fallbacks defined in `router_settings.fallbacks` inside `managed/litellm/config.yaml.tmpl` (currently commented out — enable per-use-case).

Do not add fallbacks that silently send local-only sensitive work to cloud. If local-only required, client calls local model directly and handles failure explicitly.

## Health Checks

Disabled by default:

```yaml
background_health_checks: false
enable_health_check_routing: false
```

Active health checks trigger llama-swap requests and load GPU models without user intent.

`llama-swap` model TTL defaults to `LLAMA_SWAP_MODEL_TTL=300` (5 min idle unload). Use `-1` only if you want models permanently in VRAM.

## Supporting Services

Optional Podman quadlets:

- `qdrant.service` — `:6333/:6334`
- `n8n.service` — `:5678`
- `n8n-runners.service` — `:5679`
- `searxng.service` — `:8080`

```bash
just quadlet-start
```

## Observability

```bash
# Linux
journalctl --user -u litellm -f
journalctl --user -u llama-swap -f
journalctl --user -u qdrant.service -u n8n.service -u searxng.service -f

# macOS
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

## Secrets

- `litellm/.env` — LiteLLM master key, API keys, optional `DATABASE_URL`
- `podman/.env` — container env, rendered locally by chezmoi

Tracked examples contain placeholders only.
