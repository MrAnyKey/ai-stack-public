# litellm

OpenAI-compatible proxy gateway. Routes requests to local models (via llama-swap) or cloud providers (OpenAI, Gemini, Anthropic). Runs as a user service on port 4000.

## Ports

- `:4000` — proxy API (OpenAI-compatible)

## Key Files

| File | Purpose |
| ---- | ------- |
| `managed/litellm/config.yaml.tmpl` | Route definitions, model aliases, router settings — **edit this** |
| `managed/litellm/private_dot_env.tmpl` | Secrets template rendered from KeePassXC |
| `litellm/config.yaml` | Generated config (ignored, do not edit) |
| `litellm/.env` | Generated secrets (ignored, do not edit) |
| `litellm/.env.example` | Keys template for manual setup |
| `litellm/systemd/litellm.service.tmpl` | Linux systemd unit template |
| `litellm/launchd/com.anykey.ai-stack.litellm.plist.tmpl` | macOS launchd agent template |

## Commands

```bash
# Linux
just -f litellm/Justfile service-start
just -f litellm/Justfile service-stop
just -f litellm/Justfile service-restart
just -f litellm/Justfile service-status
just -f litellm/Justfile service-logs

# macOS
just -f litellm/Justfile launchd-install
just -f litellm/Justfile launchd-stop
just -f litellm/Justfile launchd-status
just -f litellm/Justfile launchd-logs

# Both
just -f litellm/Justfile render-configs   # re-render litellm/config.yaml + litellm/.env
just -f litellm/Justfile install          # recreate .venv (litellm[proxy], prisma, uvloop)
just -f litellm/Justfile secrets-check    # verify required keys present in litellm/.env
```

## Logs

```bash
# Linux
journalctl --user -u litellm -f
journalctl --user -u litellm --no-pager -n 160

# macOS
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
```

## Health

```bash
curl http://127.0.0.1:4000/health/liveliness
curl http://127.0.0.1:4000/health/readiness
curl http://127.0.0.1:4000/v1/models
```

## Secrets

Required keys in `litellm/.env`:

```dotenv
LITELLM_MASTER_KEY=...
OPENAI_API_KEY=...
GEMINI_API_KEY=...
ANTHROPIC_API_KEY=...
```

Optional Postgres DB:

```dotenv
DATABASE_URL=postgresql://litellm_user:PASSWORD@127.0.0.1:5432/litellm
```

Without `DATABASE_URL`, LiteLLM runs with `db: "Not connected"`. Do not use SQLite.

## Virtual Environment

Python packages isolated in `litellm/.venv` via `uv`. Recreated from scratch on each `just install`. Never committed.

## Known Issues

**`ModuleNotFoundError: No module named 'prisma'`** — `DATABASE_URL` is set but Postgres isn't configured. Remove `DATABASE_URL` from `litellm/.env` or set up Postgres.

**Background health checks loading GPU models** — keep `litellm/config.yaml` with:

```yaml
general_settings:
  background_health_checks: false
  enable_health_check_routing: false
```
