# podman

Optional supporting services managed as Podman quadlets (systemd-controlled containers). Not required for the core AI stack (LiteLLM + llama-swap run as host services).

## Services

| Service | Port | Purpose |
| ------- | ---- | ------- |
| Qdrant | `:6333` (HTTP), `:6334` (gRPC) | Vector database |
| n8n | `:5678` | Workflow automation |
| n8n-runners | `:5679` (broker) | External task runners sidecar |
| SearXNG | `:8080` | Meta-search engine |

All containers share the `ai-stack` Podman bridge network.

## Key Files

| File | Purpose |
| ---- | ------- |
| `managed/podman/quadlets/*.tmpl` | Quadlet unit templates — **edit these** |
| `managed/podman/private_dot_env.tmpl` | Env template for container config |
| `managed/podman/config/searxng/*.tmpl` | SearXNG config templates |
| `podman/.env.example` | Env var reference |
| `podman/.env` | Generated env (ignored) |
| `podman/quadlets/` | Generated unit files (ignored) |
| `podman/data/` | Persistent volumes (preserved on `just destroy`) |

## Commands

```bash
just quadlet-start    # render configs + install units + start all
just quadlet-stop     # stop all quadlet services
just quadlet-status   # systemctl status for all
just quadlet-logs     # follow logs for all

# or from podman/Justfile directly:
just -f podman/Justfile render-configs
just -f podman/Justfile quadlet-install
just -f podman/Justfile quadlet-start
just -f podman/Justfile destroy          # remove units + configs, keeps podman/data
```

## Logs

```bash
# Linux
journalctl --user -u qdrant.service -f
journalctl --user -u n8n.service -f
journalctl --user -u searxng.service -f

# Follow all at once
journalctl --user -u qdrant.service -u n8n.service -u n8n-runners.service -u searxng.service -f
```

## Config

Quadlet rendering uses `podman/.env` — no KeePassXC unlock needed. After rendering, edit secrets/config:

```bash
just -f podman/Justfile render-configs
$EDITOR podman/.env
```

Auto-generated secrets (`SEARXNG_SECRET`, `N8N_RUNNERS_AUTH_TOKEN`) are written into local `podman/.env` on each render. Keep `N8N_IMAGE` and `N8N_RUNNERS_IMAGE` on matching n8n versions.

## Persistent Data

`podman/data/` contains persistent volumes and is never deleted by `just destroy`:

```
podman/data/n8n/          # n8n workflows, credentials
podman/data/qdrant/       # vector collections
podman/data/searxng-cache/
```

## macOS

macOS requires a running podman machine before starting quadlets:

```bash
podman machine init
podman machine start
just quadlet-start
```

Note: quadlet support on macOS depends on podman machine version. If quadlets don't work, use `podman run` commands manually.
