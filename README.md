# AI Stack

[![validate](https://img.shields.io/badge/validate-GitHub%20Actions-2088ff?logo=githubactions)](https://github.com/MrAnyKey/ai-stack-public/actions/workflows/validate.yml)
[![pre-commit](https://img.shields.io/badge/pre--commit-GitHub%20Actions-2088ff?logo=githubactions)](https://github.com/MrAnyKey/ai-stack-public/actions/workflows/pre-commit.yml)
[![release](https://img.shields.io/badge/release-public-2088ff?logo=githubactions)](https://github.com/MrAnyKey/ai-stack-public/actions/workflows/public-release.yml)
[![semantic-release: python](https://img.shields.io/badge/semantic--release-python-e10079?logo=semantic-release)](https://python-semantic-release.readthedocs.io/)

Personal local AI setup I use for daily work. It is published as a reference, not as a general-purpose product or reusable distribution.

Local AI inference stack. LiteLLM on `:4000` routes to local GGUF models (via llama-swap on `:8081`) and cloud providers.

```text
client → LiteLLM :4000 → llama-swap :8081 → llama-server → GGUF models
                        ↘ OpenAI / Gemini / Anthropic

optional: Qdrant :6333 | n8n :5678 | SearXNG :8080  (Podman quadlets)
```

## Tooling

| Tool | Role | Why |
| ---- | ---- | --- |
| [just](https://just.systems) | Task runner | Simpler than Make, cross-platform, great for project commands |
| [chezmoi](https://chezmoi.io) | Config templating | Renders templates with secrets at deploy time; nothing hardcoded |
| [llama-swap](https://github.com/mostlygeek/llama-swap) | Model router | Hot-swaps GGUF models on demand, zero VRAM when idle |
| [LiteLLM](https://litellm.ai) | API gateway | One OpenAI-compatible endpoint for local + cloud models |
| [uv](https://docs.astral.sh/uv/) | Python env | Fast, reproducible Python installs for LiteLLM |
| [Podman](https://podman.io) | Containers | Rootless containers for optional services (Qdrant, n8n, SearXNG) |
| [KeePassXC](https://keepassxc.org) | Secret store | API keys read at render time, never written to disk in plaintext |

## Features

**Auto-build llama.cpp — always latest.**
`just build` pulls the newest commit from `vendor/llama.cpp`, builds with CUDA 89 (Linux) or Metal (macOS), copies binaries to `llama-cpp/`. Skips rebuild if already on latest commit. `just bump-llama` fetches and forces a rebuild. Version tracked in `README.md` via HTML comments.

**Templated configs — one command to render everything.**
All service configs live as chezmoi templates in `managed/`. `just render-configs` renders them locally: secrets from KeePassXC, ports/hosts from `.env`, random tokens auto-generated. Generated files are gitignored and never committed.

**Secrets from KeePassXC — nothing hardcoded.**
`managed/litellm/private_dot_env.tmpl` reads API keys directly from your KeePassXC database at render time. Optional Postgres DB credentials also pulled from KeePassXC attributes. Manual `.env` path supported for setups without KeePassXC.

**Hot-swapping local models.**
llama-swap loads a GGUF model on first request and unloads it after idle TTL (default 5 min). Multiple models configured; only one in VRAM at a time. Zero VRAM used when idle.

**Single gateway for local + cloud.**
LiteLLM exposes one OpenAI-compatible endpoint. Clients use model names (e.g. `gemma-4-26b-moe`, `gemini-2.5-flash`) without knowing whether it's local or cloud. Fallbacks and context-window fallbacks configured per model.

**Linux + macOS.**
systemd user services on Linux, launchd user agents on macOS. Same `just` commands, different subcommands (`service-*` vs `launchd-*`).

## Requirements

### Linux (Arch/CachyOS)

- `paru` (AUR helper)
- `just`
- CUDA toolkit at `/opt/cuda` (for building llama.cpp)
- `podman` (optional, for Qdrant/n8n/SearXNG)

### macOS

- [Homebrew](https://brew.sh)
- `brew install just chezmoi uv llama-swap`
- Apple Silicon (Metal GPU) — no CUDA needed
- `podman` (optional, requires `podman machine`)

## Setup — Linux

**First run with KeePassXC:**

```bash
KEEPASSXC_DATABASE=/path/to/Passwords.kdbx just run
```

After first run the KeePassXC path is saved in `.config/chezmoi/chezmoi.toml`, so later just:

```bash
just run
```

**First run without KeePassXC (manual .env):**

`just run` requires KeePassXC. For manual setup, bypass it entirely:

```bash
# 1. LiteLLM secrets — fill manually
cp litellm/.env.example litellm/.env
$EDITOR litellm/.env    # add LITELLM_MASTER_KEY, API keys

# 2. LiteLLM config — no template vars, plain copy works
cp managed/litellm/config.yaml.tmpl litellm/config.yaml

# 3. llama-swap config — has {{ .chezmoi.destDir }} vars, must substitute
repo="$(pwd)"
sed "s|{{ .chezmoi.destDir }}|${repo}|g" \
    managed/llama-swap/config.yaml.tmpl > llama-swap/config.yaml

# 4. Install + start
just -f litellm/Justfile install
just -f litellm/Justfile service-install
just -f llama-swap/Justfile service-install
systemctl --user start llama-swap litellm
```

> **Warning:** `just render-configs` re-renders from KeePassXC and overwrites manual configs. Don't run it if you used the manual path.

**Destroy (stops services, removes generated configs, keeps `podman/data` and `models/`):**

```bash
just destroy
```

## Setup — macOS

> **⚠ NOT TESTED ON macOS — WRITTEN BY LOCAL AI, REVIEWED BY CLAUDE CODE, NOT RUN ON REAL HARDWARE.** Flow is designed and should work in theory. Report issues.

Install tools (replaces Linux `just install`):

```bash
brew install just chezmoi uv llama-swap
```

Build llama.cpp with Metal (skip if already built):

```bash
just build   # detects macOS, uses -DGGML_METAL=ON instead of CUDA
```

Start services:

```bash
KEEPASSXC_DATABASE=/path/to/Passwords.kdbx just launchd-install
```

After first run:

```bash
just launchd-install   # re-render configs + load agents
```

Service commands:

```bash
just launchd-status
just launchd-stop
```

Logs:

```bash
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

Optional Podman quadlets on macOS (requires podman machine first):

```bash
podman machine init && podman machine start
just quadlet-start
```

## Secrets

Secrets are never committed. Two options:

### Option A: KeePassXC (recommended)

Copy the example config:

```bash
cp .config/chezmoi/chezmoi.example.toml .config/chezmoi/chezmoi.toml
$EDITOR .config/chezmoi/chezmoi.toml   # set database path
```

KeePassXC entries needed (entry titles, as set in `.config/chezmoi/chezmoi.toml`):

| Entry title | Used as |
| ----------- | ------- |
| `LiteLLM` | `LITELLM_MASTER_KEY` |
| `OpenAI` | `OPENAI_API_KEY` |
| `Gemini` | `GEMINI_API_KEY` |
| `Anthropic` | `ANTHROPIC_API_KEY` |

Entry names map to the `[data.ai_stack.keepassxc.entries]` section in `.config/chezmoi/chezmoi.toml`. Change them there if your database uses different titles.

### Option B: Manual `.env`

```bash
cp litellm/.env.example litellm/.env
$EDITOR litellm/.env
```

```dotenv
LITELLM_MASTER_KEY=REPLACE_ME
OPENAI_API_KEY=REPLACE_ME
GEMINI_API_KEY=REPLACE_ME
ANTHROPIC_API_KEY=REPLACE_ME
```

## Services — Linux

```bash
just service-start
just service-stop
just service-status
just service-restart
```

Logs:

```bash
journalctl --user -u litellm -f
journalctl --user -u llama-swap -f
```

Health:

```bash
curl http://127.0.0.1:4000/health/liveliness
curl http://127.0.0.1:8081/v1/models
curl http://127.0.0.1:8081/running
```

## Services — macOS

```bash
just launchd-install    # render configs + install plists + start
just launchd-stop
just launchd-status
```

Logs:

```bash
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-litellm"'
log stream --style compact --predicate 'eventMessage CONTAINS "ai-stack-llama-swap"'
```

Restart a single service:

```bash
launchctl unload ~/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist
launchctl load   ~/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist
```

## Podman Quadlets (optional)

Optional containers: Qdrant :6333/:6334, n8n :5678, SearXNG :8080.

```bash
just quadlet-start    # render configs + install units + start
just quadlet-stop
just quadlet-status
just quadlet-logs
```

Config lives in `podman/.env` (rendered from `managed/podman/private_dot_env.tmpl`). Edit after rendering:

```bash
just -f podman/Justfile render-configs
$EDITOR podman/.env
```

## Config Rendering

All configs come from templates in `managed/` — edit templates, not generated files.

| Template (tracked) | Generated (ignored) |
| ------------------ | ------------------- |
| `managed/litellm/config.yaml.tmpl` | `litellm/config.yaml` |
| `managed/litellm/private_dot_env.tmpl` | `litellm/.env` |
| `managed/llama-swap/config.yaml.tmpl` | `llama-swap/config.yaml` |
| `managed/podman/private_dot_env.tmpl` | `podman/.env` |
| `managed/podman/quadlets/*.tmpl` | `podman/quadlets/*.container` |

Re-render everything:

```bash
just render-configs
```

## VRAM Policy

Health checks disabled by default — they silently load GPU models:

```dotenv
LITELLM_BACKGROUND_HEALTH_CHECKS=false
LITELLM_ENABLE_HEALTH_CHECK_ROUTING=false
LLAMA_SWAP_MODEL_TTL=300
```

Override in `.env`. Use `LLAMA_SWAP_MODEL_TTL=-1` only if you want models to stay in VRAM forever.

If VRAM fills unexpectedly:

```bash
nvidia-smi
curl http://127.0.0.1:8081/running
journalctl --user -u llama-swap --no-pager -n 120
```

## LiteLLM Postgres DB (optional)

Add KeePassXC attributes to `AI Stack/LiteLLM` entry:

```dotenv
DB_NAME=litellm
DB_HOST=127.0.0.1
DB_USER=litellm_user
DB_PASSWORD=<generated>
```

Create the database:

```fish
set DB_PASSWORD (openssl rand -base64 32)
sudo -iu postgres createuser --login litellm_user
sudo -iu postgres createdb --owner litellm_user litellm
sudo -iu postgres psql -d postgres -c "ALTER ROLE litellm_user WITH PASSWORD '$DB_PASSWORD';"
sudo -iu postgres psql -d litellm -c "GRANT ALL ON SCHEMA public TO litellm_user;"
```

Or add directly to `litellm/.env`:

```dotenv
DATABASE_URL=postgresql://litellm_user:REPLACE_ME@127.0.0.1:5432/litellm
```

Do not use SQLite for this project.

## Models

GGUF files go in `models/`. Registry is `models.json`.

```bash
just models-check       # dry run
just models-download    # download missing
just models-prune       # remove orphaned files
just models-sync        # download missing + prune

# or call script directly with --model filter:
./scripts/update_models.sh --model qwen
```

## Pre-commit

```bash
just precommit-install    # install hooks once
just precommit-run        # run manually
```

Checks: `gitleaks` secret scanning + YAML/TOML/JSON parsing + file hygiene. Same checks run in CI via `.github/workflows/pre-commit.yml`.

## Releases

Releases are automated with Python Semantic Release on `master` only. Conventional commits determine the next version, update `pyproject.toml` and `CHANGELOG.md`, create a release commit, tag `vX.Y.Z`, and publish a GitHub release.

```text
fix: patch release
feat: patch release
minor: minor release
BREAKING CHANGE: major release
```

No package is published; `pyproject.toml` exists only for repository metadata and release configuration.

Commit format:

- `fix: ...` creates a patch release
- `feat: ...` creates a patch release
- `perf: ...` or `refactor: ...` creates a patch release
- `minor: ...` creates a minor release for broad repository-level changes
- `BREAKING CHANGE:` in the commit body creates a major release for critical incompatible changes

## llama.cpp Version

<!-- LLAMA_CPP_VERSION_START -->
- version: `b8855-5-gfd6ae4ca1`
- commit: `fd6ae4ca1`
- date: `2026-04-20 19:25:39`
<!-- LLAMA_CPP_VERSION_END -->

## Versioning Policy

Commit: templates, service units, scripts, docs, sanitized examples.

Never commit: API keys, KeePassXC databases, `.env` files, model weights, logs, `.venv/`, generated configs, built binaries.

## Further Docs

- [Architecture](docs/architecture.md) — component diagrams, data flow, bootstrap sequence
- [Routing blueprint](docs/routing.md) — model aliases, local vs cloud policy, fallback rules
- [litellm/README.md](litellm/README.md) — LiteLLM service reference
- [llama-swap/README.md](llama-swap/README.md) — llama-swap service reference
- [podman/README.md](podman/README.md) — Podman quadlets reference
- [scripts/README.md](scripts/README.md) — model management scripts

## Public Mirror

This repository is developed privately. The public repository mirrors `master` only:

- Source: `MrAnyKey/ai-stack`
- Public mirror: `MrAnyKey/ai-stack-public`
- Auto workflow: `.github/workflows/public-mirror.yml`
- Publish script: `scripts/publish_public_mirror.sh`

The mirror is published automatically after a successful private `release` workflow on `master`. It uses one deploy key secret:

- Secret name in private source repo: `PUBLIC_REPO_DEPLOY_KEY`
- Public repo deploy key target: `MrAnyKey/ai-stack-public`
- Deploy key permission: allow write access

The mirror force-pushes the `master` branch history only. The public repo then runs `.github/workflows/public-release.yml` with Python Semantic Release, creates its own tags, and publishes its own GitHub Releases from public history without committing release metadata back to `master`.

Manual fallback from a local checkout uses your existing SSH access:

```bash
scripts/publish_public_mirror.sh
```

Both paths publish only `master`. They do not publish private branches or private tags.
