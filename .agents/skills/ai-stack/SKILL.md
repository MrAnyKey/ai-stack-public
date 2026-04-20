---
name: ai-stack
description: >
  ALWAYS use this skill for ANY task in the ai-stack repo. Covers: reading logs,
  fixing services (litellm, llama-swap, qdrant, n8n, searxng), setup, install,
  render configs, manage models, macOS launchd, Linux systemd, Podman quadlets,
  pre-commit, VRAM issues, service restarts, .env files, KeePassXC secrets,
  Justfile recipes, chezmoi templates. Repo: /home/mranykey/Documents/AnyKey/Repos/ai-stack
---

# AI Stack Skill

**Repo root:** `/home/mranykey/Documents/AnyKey/Repos/ai-stack`

## What This Stack Is

```text
client → LiteLLM :4000 → llama-swap :8081 → llama-server → GGUF models (models/)
                        ↘ OpenAI / Gemini / Anthropic (cloud)

optional quadlets: Qdrant :6333 | n8n :5678 | SearXNG :8080
```

- **LiteLLM** (`litellm/`) — Python proxy gateway, port 4000, systemd/launchd user service
- **llama-swap** (`llama-swap/`) — Go binary, routes GGUF models, port 8081, systemd/launchd user service
- **llama-server** — built from `vendor/llama.cpp`, binary at `llama-cpp/llama-server`
- **Quadlets** (`podman/`) — optional Podman containers managed by systemd

**Config source of truth:** `managed/` directory (chezmoi templates, tracked by git)
**Generated configs:** `litellm/config.yaml`, `litellm/.env`, `llama-swap/config.yaml`, `podman/quadlets/`, `podman/.env` — all gitignored, never edit directly

## Linux vs macOS — Quick Reference

| Action | Linux | macOS |
| ------ | ----- | ----- |
| Start services | `just service-start` | `just launchd-install` |
| Stop services | `just service-stop` | `just launchd-stop` |
| Service status | `just service-status` | `just launchd-status` |
| Read logs | `journalctl --user -u <svc> -f` | `log stream --predicate 'eventMessage CONTAINS "ai-stack-<svc>"'` |
| Install packages | `scripts/install_packages.sh` (pacman/paru) | `brew install just chezmoi uv llama-swap` |
| Service files | `~/.config/systemd/user/*.service` | `~/Library/LaunchAgents/com.anykey.ai-stack.*.plist` |
| Build llama.cpp | CUDA 89 (`-DGGML_CUDA=ON`) | Metal (`-DGGML_METAL=ON`) |

## Critical Rules — Never Break

1. **Logs go to service manager only.** Linux → journald (`StandardOutput=journal`). macOS → Unified Log (`/usr/bin/logger`). Never write logs to repo files.
2. **Never commit secrets.** API keys in KeePassXC or local `.env` (gitignored). Examples contain placeholders only.
3. **`just run` and `just render-configs` overwrite `litellm/.env`.** Always warn user before running if they have manual edits.
4. **Health checks stay disabled by default.** Active LiteLLM health checks load GPU models silently via llama-swap.
5. **Use Podman quadlets, not Docker Compose.** Quadlet templates in `managed/podman/quadlets/`.
6. **Never use SQLite for LiteLLM DB.** Only Postgres or no DB at all.
7. **Edit templates in `managed/`, not generated files.** Generated files get overwritten on next `just render-configs`.

## Common Workflows

### Start everything (Linux)

```bash
just run
# or individually:
just service-start      # llama-swap + litellm
just quadlet-start      # optional: qdrant, n8n, searxng
```

### Start everything (macOS)

```bash
just launchd-install
# optional containers (needs podman machine running):
just quadlet-start
```

### Restart a service after config change

```bash
# Linux
just render-configs
just -f litellm/Justfile service-restart
just -f llama-swap/Justfile service-restart

# macOS
just render-configs
launchctl unload ~/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist
launchctl load   ~/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist
```

### Re-render all configs

```bash
just render-configs
```

### Check service health

```bash
curl http://127.0.0.1:4000/health/liveliness   # LiteLLM alive
curl http://127.0.0.1:4000/health/readiness    # LiteLLM ready
curl http://127.0.0.1:8081/v1/models           # llama-swap model list
curl http://127.0.0.1:8081/running             # currently loaded GGUF models
```

## Reading Logs

### Linux

```bash
# Follow live
journalctl --user -u litellm -f
journalctl --user -u llama-swap -f

# Last N lines (no pager)
journalctl --user -u litellm --no-pager -n 160
journalctl --user -u llama-swap --no-pager -n 160

# Quadlet services
journalctl --user -u qdrant.service -u n8n.service -u searxng.service -f
```

### macOS

```bash
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

## Key Files — Where to Look

### Justfiles (run recipes here)

- `Justfile` — root: `just run`, `just destroy`, `just build`, `just render-configs`
- `litellm/Justfile` — `service-start`, `service-restart`, `install`, `render-configs`
- `llama-swap/Justfile` — `service-start`, `service-restart`, `install`, `render-configs`
- `podman/Justfile` — `quadlet-start`, `quadlet-stop`, `quadlet-status`, `quadlet-logs`

### Templates (edit these)

- `managed/litellm/config.yaml.tmpl` — LiteLLM routing, models, cloud providers
- `managed/litellm/private_dot_env.tmpl` — LiteLLM secrets template
- `managed/llama-swap/config.yaml.tmpl` — local GGUF model definitions, VRAM flags
- `managed/podman/private_dot_env.tmpl` — Podman env template
- `managed/podman/quadlets/*.tmpl` — container unit templates

### Service unit templates

- Linux: `litellm/systemd/litellm.service.tmpl`, `llama-swap/systemd/llama-swap.service.tmpl`
- macOS: `litellm/launchd/com.anykey.ai-stack.litellm.plist.tmpl`, `llama-swap/launchd/com.anykey.ai-stack.llama-swap.plist.tmpl`

### Runtime files (never commit, check these when debugging)

- `litellm/.env` — active secrets (KeePassXC-rendered or manual)
- `litellm/config.yaml` — active LiteLLM config
- `llama-swap/config.yaml` — active llama-swap config
- `podman/.env` — active quadlet env

## Diagnosing Problems — Step by Step

1. Check git status for dirty tree: `git status --short`
2. Read service logs (see above)
3. Check health endpoints (see above)
4. Inspect rendered config: `cat litellm/config.yaml` or `cat llama-swap/config.yaml`
5. If config wrong → edit template in `managed/`, re-run `just render-configs`, restart service

## Known Failures

### `ModuleNotFoundError: No module named 'prisma'`

LiteLLM started with `DATABASE_URL` in `litellm/.env` but Postgres isn't set up.

Fix: remove `DATABASE_URL` from `litellm/.env`, or set up Postgres properly.

```bash
litellm/.venv/bin/python -m pip show litellm prisma
```

### `ExitError >> exit status 127` in llama-swap logs

llama-server can't find shared libraries.

Test directly:

```bash
LD_LIBRARY_PATH=/home/mranykey/Documents/AnyKey/Repos/ai-stack/llama-cpp \
  /home/mranykey/Documents/AnyKey/Repos/ai-stack/llama-cpp/llama-server --version
```

Each model block in `managed/llama-swap/config.yaml.tmpl` must have:

```yaml
env:
  LD_LIBRARY_PATH: "{{ .chezmoi.destDir }}/llama-cpp"
```

### Service restart loop (systemd)

Unit must cap restarts:

```ini
StartLimitIntervalSec=60
StartLimitBurst=5
Restart=on-failure
RestartSec=2
```

macOS plist must have `ThrottleInterval` key.

### VRAM fills without user request

LiteLLM health checks are triggering llama-swap. Verify `.env` has:

```dotenv
LITELLM_BACKGROUND_HEALTH_CHECKS=false
LITELLM_ENABLE_HEALTH_CHECK_ROUTING=false
LLAMA_SWAP_MODEL_TTL=300
```

Check what's loaded:

```bash
nvidia-smi
curl http://127.0.0.1:8081/running
journalctl --user -u llama-swap --no-pager -n 120
```

## Secrets Management

**KeePassXC (preferred)** — chezmoi renders `litellm/.env` from these entries:

| Entry | Field | Used as |
| ----- | ----- | ------- |
| `AI Stack/LiteLLM` | Password | `LITELLM_MASTER_KEY` |
| `AI Stack/OpenAI` | Password | `OPENAI_API_KEY` |
| `AI Stack/Gemini` | Password | `GEMINI_API_KEY` |
| `AI Stack/Anthropic` | Password | `ANTHROPIC_API_KEY` |

Optional Postgres attrs on `AI Stack/LiteLLM`: `DB_NAME`, `DB_HOST`, `DB_USER`, `DB_PASSWORD`

**Manual (no KeePassXC/chezmoi)** — bypass `just run` entirely:

```bash
# litellm secrets
cp litellm/.env.example litellm/.env
$EDITOR litellm/.env

# litellm config — no chezmoi vars, plain copy ok
cp managed/litellm/config.yaml.tmpl litellm/config.yaml

# llama-swap config — contains {{ .chezmoi.destDir }}, must substitute
sed "s|{{ .chezmoi.destDir }}|$(pwd)|g" \
    managed/llama-swap/config.yaml.tmpl > llama-swap/config.yaml
```

⚠️ `just run` and `just render-configs` require KeePassXC and will fail or overwrite manual configs. Never mix the two paths.

## Config Rendering Pipeline

```text
managed/litellm/config.yaml.tmpl     → litellm/config.yaml
managed/litellm/private_dot_env.tmpl → litellm/.env
managed/llama-swap/config.yaml.tmpl  → llama-swap/config.yaml
managed/podman/private_dot_env.tmpl  → podman/.env
managed/podman/quadlets/*.tmpl       → podman/quadlets/*.container
managed/podman/config/searxng/*.tmpl → podman/config/searxng/*

Command: just render-configs
Inputs: .env (root), KeePassXC database, randAlphaNum() for generated secrets
```

## Documentation Rules (when editing docs)

- Fish shell examples preferred unless user asks otherwise
- Include both KeePassXC path and manual `.env` path in examples
- Never print real secrets from `litellm/.env` — redact values
- Log examples: journald on Linux, Unified Log on macOS
- Quadlet templates live in `managed/podman/quadlets/`; render to `podman/quadlets/`; install with `just quadlet-install`
- Keep `.pre-commit-config.yaml` and `.github/workflows/pre-commit.yml` in sync

## Docs Location

- Architecture / diagrams: `docs/architecture.md`
- Routing policy / aliases: `docs/routing.md`
- LiteLLM reference: `litellm/README.md`
- llama-swap reference: `llama-swap/README.md`
- Podman quadlets reference: `podman/README.md`
- Model management: `scripts/README.md`
