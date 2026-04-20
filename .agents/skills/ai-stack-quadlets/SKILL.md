---
name: ai-stack-quadlets
description: >
  Use for Podman quadlet tasks in ai-stack: qdrant, n8n, n8n-runners, searxng, podman quadlets,
  podman containers, quadlet units, quadlet install, quadlet start, quadlet stop, quadlet logs,
  quadlet status, podman network, podman .env, container images, n8n workflows, qdrant vectors,
  searxng search, podman machine, container data, podman/data, persistent volumes.
  Repo: /home/mranykey/Documents/AnyKey/Repos/ai-stack
---

# Podman Quadlets

**Location:** `podman/`
**Docs:** `podman/README.md`

Optional supporting services. Not required for core AI stack. All containers on `ai-stack` bridge network.

## Services

| Service | Port | Data |
| ------- | ---- | ---- |
| Qdrant | `:6333` HTTP, `:6334` gRPC | `podman/data/qdrant/` |
| n8n | `:5678` | `podman/data/n8n/` |
| n8n-runners | `:5679` broker | — |
| SearXNG | `:8080` | `podman/data/searxng-cache/` |

## Start / Stop / Status

```bash
just quadlet-start    # render + install + start all
just quadlet-stop
just quadlet-status
just quadlet-logs     # follow all logs

# or per-service via podman/Justfile
just -f podman/Justfile quadlet-start
just -f podman/Justfile destroy    # remove units + configs, keeps podman/data
```

## Logs

```bash
journalctl --user -u qdrant.service -f
journalctl --user -u n8n.service -f
journalctl --user -u n8n-runners.service -f
journalctl --user -u searxng.service -f

# All at once
journalctl --user -u qdrant.service -u n8n.service -u n8n-runners.service -u searxng.service -f
```

## Config

Templates: `managed/podman/quadlets/*.tmpl` (tracked, edit these)
Generated: `podman/quadlets/*.container` (ignored, do not edit)
Env: `podman/.env` (ignored, rendered from `managed/podman/private_dot_env.tmpl`)

Render + edit env:
```bash
just -f podman/Justfile render-configs
$EDITOR podman/.env
```

Quadlet rendering does NOT require KeePassXC unlock — only uses `podman/.env` values.

## Auto-generated Secrets

`SEARXNG_SECRET` and `N8N_RUNNERS_AUTH_TOKEN` are generated with `randAlphaNum()` on each render and written into local `podman/.env`. They change on every `render-configs` — restart containers after re-rendering.

## macOS

Needs podman machine running first:

```bash
podman machine init
podman machine start
just quadlet-start
```

## Data Persistence

`podman/data/` is never deleted by `just destroy`. Delete manually if you want to reset:

```bash
# WARNING: deletes all n8n workflows, qdrant collections, searxng cache
rm -rf podman/data/n8n podman/data/qdrant podman/data/searxng-cache
```

## Critical Rules

- Quadlet templates in `managed/podman/quadlets/` — always edit templates, not generated units
- Logs go to journald — never add container log file mounts
- Do not commit `podman/.env` — it may contain generated secrets
- Keep `N8N_IMAGE` and `N8N_RUNNERS_IMAGE` on matching n8n versions
