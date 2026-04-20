# AI Stack — Architecture Diagram

## Top-Level Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ai-stack Repository                          │
│                     /home/mranykey/.../ai-stack                      │
└─────────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────┐         ┌──────────────────────┐
│  Host Services   │         │  Podman Quadlet Svc  │
│  (systemd user)  │         │  (systemd user via     │
│                  │         │   quadlets)           │
│  • llama-swap    │         │                       │
│  • LiteLLM       │         │  • Qdrant (vector DB) │
└────────┬─────────┘         │  • n8n + runners      │
       │                     │  • SearXNG            │
       ▼                     └──────────┬────────────┘
┌────────────────────────────────────────────────┐
│              Port Mapping                      │
│                                                │
│  127.0.0.1:8081  → llama-swap                │
│  127.0.0.1:4000  → LiteLLM gateway            │
│  localhost:6333  → Qdrant HTTP                │
│  localhost:6334  → Qdrant gRPC                │
│  localhost:5678  → n8n UI                     │
│  localhost:5679  → n8n runners broker         │
│  localhost:8080  → SearXNG search             │
└────────────────────────────────────────────────┘
```

## Service Flow

```
┌──────────┐     OpenAI-compatible     ┌─────────────┐
│  Client  │ ─────────────────────────→│   LiteLLM   │
│ (API/CLI)│                            │   Gateway   │
└──────────┘                            └──────┬──────┘
                                                │
                    ┌───────────────────────────┼───────────────────────────┐
                    │                           │                           │
                    ▼                           ▼                           ▼
          ┌───────────────┐          ┌──────────────────┐        ┌──────────────────┐
          │  Local Models  │          │  Cloud Providers  │        │  Routing/Proxy   │
          │  (via llama-   │          │                   │        │  llama-swap      │
          │   swap)        │          │  • OpenAI         │        │  (model hot-swap)│
          │                │          │  • Gemini         │        └────────┬─────────┘
          │  GGUF files    │          │  • Anthropic      │                 │
          │  /models/      │          └──────────────────┘                 │
          └───────┬────────┘                                              │
                  │                                                       │
                  ▼                                                       ▼
          ┌───────────────┐                                      ┌───────────────┐
          │  llama.cpp    │                                      │  llama-swap   │
          │  (built from  │                                      │  (AUR/pkg)    │
          │   vendor/     │                                      │                 │
          │   llama.cpp)  │                                      │  Route by model │
          │                │                                      │  TTL/idle eject │
          │  CUDA 89,     │                                      └─────────────────┘
          │  Release build│
          └───────────────┘
```

## Directory Structure

```
ai-stack/
│
├── .agents/                          # Agent skills
│   └── skills/
│       └── ai-stack-litellm/
│           └── SKILL.md              # LiteLLM diagnostics & fix procedures
│
├── .chezmoiroot                      # Chezmoi root marker
├── .config/
│   └── chezmoi/
│       ├── chezmoi.example.toml      # Template: chezmoi config
│       └── chezmoi.toml              # Local (ignored): actual config + KeePassXC path
│
├── .env.example                      # Non-secret defaults (ports, hosts)
├── .env                              # Local (ignored): runtime env
│
├── .github/
│   └── workflows/
│       └── pre-commit.yml            # CI: runs pre-commit on PRs/pushes
│
├── .gitmodules                       # Submodule: vendor/llama.cpp
├── .gitignore
├── .pre-commit-config.yaml           # Pre-commit hooks (gitleaks + hygiene)
│
├── Justfile                          # Root orchestrator (bootstrap, destroy, render, services)
│
├── litellm/                          # LiteLLM service
│   ├── Justfile                      # install, render-configs, service-{start|stop|restart|status|logs}
│   ├── .env.example                  # Template: API keys, DB URL
│   ├── .env                          # Local (ignored): rendered secrets from KeePassXC
│   ├── config.yaml                   # Local (ignored): rendered from managed template
│   ├── .venv/                        # uv-managed Python venv (litellm[proxy], prisma, uvloop)
│   ├── systemd/
│   │   └── litellm.service.tmpl      # systemd user service template
│   └── launchd/
│       └── com.anykey.ai-stack.litellm.plist.tmpl  # macOS launchd agent template
│
├── llama-swap/                       # llama-swap service
│   ├── Justfile                      # install, render-configs, service-{start|stop|restart|status|logs}
│   ├── systemd/
│   │   └── llama-swap.service.tmpl   # systemd user service template
│   └── launchd/
│       └── com.anykey.ai-stack.llama-swap.plist.tmpl  # macOS launchd agent template
│
├── managed/                          # Source-of-truth templates (tracked by git)
│   ├── litellm/
│   │   ├── config.yaml.tmpl          # LiteLLM config template (chezmoi)
│   │   └── private_dot_env.tmpl      # .env template (chezmoi, KeePassXC-rendered)
│   ├── llama-swap/
│   │   └── config.yaml.tmpl          # llama-swap config template (chezmoi)
│   └── podman/
│       ├── private_dot_env.tmpl      # Podman .env template (chezmoi)
│       ├── config/
│       │   └── searxng/
│       │       ├── limiter.toml.tmpl
│       │       └── settings.yml.tmpl
│       └── quadlets/
│           ├── ai-stack.network.tmpl
│           ├── n8n.container.tmpl
│           ├── n8n-runners.container.tmpl
│           ├── qdrant.container.tmpl
│           └── searxng.container.tmpl
│
├── podman/                           # Podman quadlet services (generated + data)
│   ├── Justfile                      # quadlet-{start|stop|status|logs|install|destroy|bootstrap}
│   ├── .env.example                  # Template: images, ports
│   ├── .env                          # Local (ignored): rendered env
│   ├── quadlets/                     # Generated quadlet units (ignored by git)
│   │   ├── ai-stack.network
│   │   ├── n8n.container
│   │   ├── n8n-runners.container
│   │   ├── qdrant.container
│   │   └── searxng.container
│   ├── config/
│   │   └── searxng/                  # Generated SearXNG config
│   └── data/                         # Persistent data (preserved on destroy)
│       ├── n8n/
│       ├── qdrant/
│       └── searxng-cache/
│
├── models.json                           # GGUF model registry
├── scripts/
│   ├── install_packages.sh           # pacman → paru fallback installer
│   └── update_models.sh              # Linux model update script
│
├── vendor/
│   └── llama.cpp/                    # Git submodule (llama.cpp source)
│
├── llama-cpp/                        # Built binaries (ignored by git)
│   ├── llama-server                  # CUDA 89 Release build
│   └── *.so                          # Shared libraries
│
├── models/                           # GGUF model weights (ignored by git)
│
├── README.md                         # Project docs
├── docs/
│   ├── architecture.md
│   └── routing.md
└── AI.code-workspace
```

## Config Rendering Pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│                        chezmoi Rendering                              │
└──────────────────────────────────────────────────────────────────────┘

Source (tracked)                    Destination (generated, ignored)
─────────────────                   ────────────────────────────────

managed/litellm/config.yaml.tmpl  →  litellm/config.yaml
managed/litellm/private_dot_env.tmpl → litellm/.env
managed/llama-swap/config.yaml.tmpl → llama-swap/config.yaml
managed/podman/quadlets/*.tmpl    →  podman/quadlets/*.container
managed/podman/config/searxng/*  →  podman/config/searxng/*
managed/podman/private_dot_env.tmpl → podman/.env

Inputs:
  • .env (root non-secret defaults)
  • podman/.env (podman-specific defaults)
  • KeePassXC database (API keys, passwords via chezmoi keepassxc driver)
  • randAlphaNum() for generated secrets (SEARXNG_SECRET, N8N_RUNNERS_AUTH_TOKEN)

Command: just render-configs
  → render-litellm-configs (chezmoi apply litellm/.env + litellm/config.yaml)
  → render-llama-swap-configs (chezmoi apply llama-swap/config.yaml)
  → render-quadlets (delegates to podman/Justfile render-configs)
```

## Bootstrap Flow

```
just run (alias for just bootstrap)
  │
  ├─► install
  │    └─► scripts/install_packages.sh chezmoi keepassxc uv llama-swap
  │         └─► pacman check → paru -S fallback
  │
  ├─► ensure-chezmoi-config
  │    └─► .config/chezmoi/chezmoi.toml (copy from .example if missing)
  │    └─► validate KeePassXC database path
  │
  ├─► ensure-llama-cpp
  │    └─► llama-cpp/llama-server exists? → yes: skip
  │    └─► no: just build (cmake + nvcc, CUDA 89, ccache)
  │
  ├─► service-start
  │    ├─► llama-swap/Justfile service-restart
  │    │    └─► install (llama-swap pkg) → render-configs → service-install → systemctl start
  │    └─► litellm/Justfile service-restart
  │         └─► install (uv venv + litellm[proxy] + prisma + uvloop) → render-configs →
  │             secrets-check → service-install → systemctl start
  │
  └─► podman-bootstrap
       └─► podman/Justfile bootstrap
            └─► quadlet-start → quadlet-install → render-configs → systemctl restart quadlets
```

## Data Flow: Request Path

```
Client Request
     │
     ▼
┌─────────────────────────────────┐
│  LiteLLM Gateway (:4000)        │
│  - Auth (master key)            │
│  - Router (model → provider)    │
│  - Health check routing         │
│  - Proxy DB (optional Postgres) │
└────┬────────────────────────────┘
     │
     ├─────────────────────┬─────────────────────┬──────────────────┐
     ▼                     ▼                     ▼                  ▼
  Local Model          OpenAI              Gemini          Anthropic
  llama-swap           (cloud)             (cloud)         (cloud)
  :8081                │                    │               │
     │                 ▼                    ▼               ▼
  llama-server       OpenAI API         Gemini API      Anthropic API
  (llama.cpp)        endpoints          endpoints       endpoints
     │
  GGUF model from
  /models/
```

## Podman Network

```
┌─────────────────────────────────────────────────────────┐
│  ai-stack.network (Podman bridge)                       │
│                                                         │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Qdrant  │  │     n8n      │  │    SearXNG       │  │
│  │ :6333    │  │   :5678      │  │    :8080         │  │
│  │ :6334    │  │   :5679      │  │                  │  │
│  └──────────┘  │ (runners)    │  └──────────────────┘  │
│                └──────────────┘                         │
└─────────────────────────────────────────────────────────┘
     │
     ▼ (PublishPort on host)
Host ports → localhost:6333, localhost:5678, localhost:8080
```

## Service Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐
│  systemd    │     │  launchd    │     │  Pre-commit      │
│  (Linux)    │     │  (macOS)    │     │  (dev/CI)        │
├─────────────┤     ├─────────────┤     ├──────────────────┤
│ StandardOut │     │ RunAtLoad   │     │ gitleaks         │
│ = journal   │     │ KeepAlive   │     │ YAML/TOML/JSON   │
│ StandardErr │     │ ThrottleInt │     │   parse check    │
│ = journal   │     │erval        │     │ merge markers    │
│ Restart=    │     │ KeepAlive   │     │ large files      │
│ on-failure  │     │ Restart     │     │ private keys     │
│ RestartSec= │     │ loops       │     │ broken symlinks  │
│ 2           │     │             │     │ line endings     │
│ StartLimit  │     │ /usr/bin/   │     │ final newline    │
│ Interval=60 │     │ logger →    │     │ trailing ws      │
│ Burst=5     │     │ Unified Log │     │                  │
└─────────────┘     └─────────────┘     └──────────────────┘
```

## Key Files Reference

| Purpose | Template (tracked) | Generated (ignored) |
|---------|-------------------|---------------------|
| LiteLLM config | [`managed/litellm/config.yaml.tmpl`](../managed/litellm/config.yaml.tmpl) | `litellm/config.yaml` |
| LiteLLM secrets | [`managed/litellm/private_dot_env.tmpl`](../managed/litellm/private_dot_env.tmpl) | `litellm/.env` |
| llama-swap config | [`managed/llama-swap/config.yaml.tmpl`](../managed/llama-swap/config.yaml.tmpl) | `llama-swap/config.yaml` |
| Podman env | [`managed/podman/private_dot_env.tmpl`](../managed/podman/private_dot_env.tmpl) | `podman/.env` |
| Quadlet units | [`managed/podman/quadlets/*.tmpl`](../managed/podman/quadlets/) | `podman/quadlets/*.container` |
| SearXNG config | [`managed/podman/config/searxng/*.tmpl`](../managed/podman/config/searxng/) | `podman/config/searxng/*` |
| systemd units | [`litellm/systemd/*.tmpl`](../litellm/systemd/), [`llama-swap/systemd/*.tmpl`](../llama-swap/systemd/) | `~/.config/systemd/user/*.service` |
| launchd agents | [`litellm/launchd/*.plist.tmpl`](../litellm/launchd/), [`llama-swap/launchd/*.plist.tmpl`](../llama-swap/launchd/) | `~/Library/LaunchAgents/com.anykey.ai-stack.*.plist` |
