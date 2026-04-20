---
name: ai-stack-llama-swap
description: >
  Use for llama-swap and llama.cpp tasks in ai-stack: llama-swap logs, llama-swap config,
  llama-swap service, llama-swap models, llama-swap TTL, llama-swap VRAM, llama-swap hot-swap,
  llama-swap port 8081, llama.cpp build, llama.cpp CUDA, llama.cpp Metal, llama-server,
  llama-server binary, build llama.cpp, rebuild llama, GGUF model loading, exit status 127,
  LD_LIBRARY_PATH, model not loading, model unload, VRAM full, GPU models.
  Repo: /home/mranykey/Documents/AnyKey/Repos/ai-stack
---

# llama-swap + llama.cpp

**Location:** `llama-swap/`
**Binary:** `llama-cpp/llama-server` (built from `vendor/llama.cpp`)
**Port:** `:8081`
**Docs:** `llama-swap/README.md`

llama-swap routes OpenAI-compatible requests to local GGUF models. Hot-swaps models on demand. Unloads idle models after TTL.

## Edit Config

```bash
$EDITOR managed/llama-swap/config.yaml.tmpl
just render-configs
just -f llama-swap/Justfile service-restart
```

Each model block needs `LD_LIBRARY_PATH` or llama-server crashes with exit 127:

```yaml
models:
  "model-name":
    cmd: >-
      {{ .chezmoi.destDir }}/llama-cpp/llama-server
      --port ${PORT}
      -m {{ .chezmoi.destDir }}/models/dir/model.gguf
      -ngl 99
    env:
      LD_LIBRARY_PATH: "{{ .chezmoi.destDir }}/llama-cpp"
    ttl: 300
```

## Start / Stop / Logs

```bash
# Linux
just -f llama-swap/Justfile service-start
just -f llama-swap/Justfile service-restart
just -f llama-swap/Justfile service-stop
journalctl --user -u llama-swap --no-pager -n 160
journalctl --user -u llama-swap -f

# macOS
just -f llama-swap/Justfile launchd-install
just -f llama-swap/Justfile launchd-stop
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

## Status

```bash
curl http://127.0.0.1:8081/v1/models    # all configured models
curl http://127.0.0.1:8081/running      # currently loaded (in VRAM)
```

## Build llama.cpp

Build detects OS automatically:

```bash
just build      # Linux: CUDA arch 89 | macOS: Metal
just rebuild    # force rebuild from scratch
```

**Linux requirements:** CUDA toolkit at `/opt/cuda`, `cmake`, optional `ccache`
**macOS requirements:** Xcode command line tools, `cmake`, optional `ccache`

Built binary: `llama-cpp/llama-server`
Built libs: `llama-cpp/*.so` (Linux) or `llama-cpp/*.dylib` (macOS)

Check current version:
```bash
cat llama-cpp/.sha
just status
```

Update to latest:
```bash
just bump-llama   # updates submodule + triggers rebuild
```

## VRAM Management

Models unload after `ttl` seconds of inactivity. Default: `LLAMA_SWAP_MODEL_TTL=300`.

If VRAM fills unexpectedly (health checks loading models):
```bash
nvidia-smi
curl http://127.0.0.1:8081/running
journalctl --user -u llama-swap --no-pager -n 120
# Look for background POST /v1/chat/completions or /v1/embeddings
```

Verify in `litellm/config.yaml`:
```yaml
general_settings:
  background_health_checks: false
  enable_health_check_routing: false
```

## Known Failures

**`ExitError >> exit status 127`**
llama-server can't find shared libs. Test:
```bash
LD_LIBRARY_PATH=/home/mranykey/Documents/AnyKey/Repos/ai-stack/llama-cpp \
  /home/mranykey/Documents/AnyKey/Repos/ai-stack/llama-cpp/llama-server --version
```
Fix: add `LD_LIBRARY_PATH` to model `env` block in `managed/llama-swap/config.yaml.tmpl`.

**Model never unloads**
`ttl` set to `-1` or `LLAMA_SWAP_MODEL_TTL=-1` in `.env`. Change to `300`.

**Build fails on macOS: "CUDA toolkit not found"**
Old build recipe without OS detection. Run `just build` — it now auto-detects macOS and uses Metal.
