---
name: ai-stack-litellm
description: >
  Use for LiteLLM tasks in ai-stack: read litellm logs, fix litellm service, debug litellm
  gateway, litellm config, litellm routing, litellm model aliases, litellm .env, litellm
  secrets, litellm systemd, litellm launchd, litellm install, litellm venv, litellm DB,
  litellm postgres, litellm prisma, litellm health check, litellm master key, API keys.
  Repo: /home/mranykey/Documents/AnyKey/Repos/ai-stack
---

# LiteLLM Service

**Location:** `litellm/`
**Port:** `:4000`
**Docs:** `litellm/README.md`

LiteLLM is the OpenAI-compatible proxy gateway. All clients talk to it. It routes to llama-swap (local) or cloud providers.

## Edit Config

**Always edit the template, not the generated file:**

```bash
$EDITOR managed/litellm/config.yaml.tmpl   # route rules, model aliases, cloud providers
just render-configs                         # regenerate litellm/config.yaml
just -f litellm/Justfile service-restart
```

## Start / Stop / Logs

```bash
# Linux
just -f litellm/Justfile service-start
just -f litellm/Justfile service-restart
just -f litellm/Justfile service-stop
journalctl --user -u litellm --no-pager -n 160
journalctl --user -u litellm -f

# macOS
just -f litellm/Justfile launchd-install
just -f litellm/Justfile launchd-stop
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
```

## Health

```bash
curl http://127.0.0.1:4000/health/liveliness
curl http://127.0.0.1:4000/health/readiness
curl http://127.0.0.1:4000/v1/models
```

## Secrets

`litellm/.env` holds active secrets. Two ways to populate it:

**KeePassXC (rendered by chezmoi):**
```bash
just render-configs    # reads KeePassXC, writes litellm/.env
```

**Manual:**
```bash
cp litellm/.env.example litellm/.env
$EDITOR litellm/.env
```

Required keys: `LITELLM_MASTER_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`

⚠️ `just render-configs` overwrites `litellm/.env`. Warn user if they have manual edits.

Never print secret values. Redact when showing file contents.

## Database

LiteLLM uses Postgres when `DATABASE_URL` is present in `litellm/.env`. Without it, runs with no DB. **Do not use SQLite.**

```dotenv
DATABASE_URL=postgresql://litellm_user:PASSWORD@127.0.0.1:5432/litellm
```

## Reinstall venv

```bash
just -f litellm/Justfile install
```

Recreates `litellm/.venv` from scratch with `litellm[proxy]`, `prisma`, `uvloop`.

## Critical Rules

- Logs → journald (Linux) or Unified Log (macOS). Never log to files.
- Service restart must be capped: `StartLimitIntervalSec=60`, `StartLimitBurst=5`
- `LITELLM_MODE=PRODUCTION` must be set in systemd unit (prevents auto `.env` loading)
- `background_health_checks: false` in config — health checks load GPU models silently

## Known Failures

**`ModuleNotFoundError: No module named 'prisma'`**
`DATABASE_URL` is set, Postgres not configured. Remove `DATABASE_URL` or set up Postgres.
```bash
litellm/.venv/bin/python -m pip show litellm prisma
```

**Service starts then immediately stops**
Check journal: `journalctl --user -u litellm --no-pager -n 50`
Common causes: missing key in `litellm/.env`, bad YAML in `litellm/config.yaml`, DB connection failure.
