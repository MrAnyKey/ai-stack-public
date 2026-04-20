# llama-swap

Go binary that routes between local GGUF models. Receives requests on port 8081 (OpenAI/Anthropic API compatible), hot-swaps models on demand, unloads idle models after TTL expires.

LiteLLM sends local model requests here. Clients should not talk to llama-swap directly unless debugging.

## Ports

- `:8081` — OpenAI-compatible API

## Key Files

| File | Purpose |
| ---- | ------- |
| `managed/llama-swap/config.yaml.tmpl` | Model definitions, GPU flags, TTL — **edit this** |
| `llama-swap/config.yaml` | Generated config (ignored, do not edit) |
| `llama-swap/systemd/llama-swap.service.tmpl` | Linux systemd unit template |
| `llama-swap/launchd/com.anykey.ai-stack.llama-swap.plist.tmpl` | macOS launchd agent template |

## Commands

```bash
# Linux
just -f llama-swap/Justfile service-start
just -f llama-swap/Justfile service-stop
just -f llama-swap/Justfile service-restart
just -f llama-swap/Justfile service-status
just -f llama-swap/Justfile service-logs

# macOS
just -f llama-swap/Justfile launchd-install
just -f llama-swap/Justfile launchd-stop
just -f llama-swap/Justfile launchd-status
just -f llama-swap/Justfile launchd-logs

# Both
just -f llama-swap/Justfile render-configs   # re-render llama-swap/config.yaml
just -f llama-swap/Justfile install          # install llama-swap package
```

## Logs

```bash
# Linux
journalctl --user -u llama-swap -f
journalctl --user -u llama-swap --no-pager -n 160

# macOS
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

## Status

```bash
curl http://127.0.0.1:8081/v1/models    # all configured models
curl http://127.0.0.1:8081/running      # currently loaded models (VRAM)
```

## Model Config

Models defined in `managed/llama-swap/config.yaml.tmpl`. Each model block requires:

```yaml
models:
  "model-name":
    cmd: >-
      {{ .chezmoi.destDir }}/llama-cpp/llama-server
      --port ${PORT}
      -m {{ .chezmoi.destDir }}/models/model-dir/model.gguf
      -ngl 99
    env:
      - "LD_LIBRARY_PATH={{ .chezmoi.destDir }}/llama-cpp"
    ttl: 300
```

`LD_LIBRARY_PATH` is required — llama-server needs repo-local shared libraries from `llama-cpp/`.

## VRAM Policy

Models unload after `ttl` seconds idle. Default `LLAMA_SWAP_MODEL_TTL=300` (5 minutes). Set to `-1` only if you want models resident in VRAM permanently.

## Known Issues

**`ExitError >> exit status 127`** — llama-server can't find shared libraries. Verify `LD_LIBRARY_PATH` is set in model `env` block. Test directly:

```bash
LD_LIBRARY_PATH=./llama-cpp ./llama-cpp/llama-server --version
```
