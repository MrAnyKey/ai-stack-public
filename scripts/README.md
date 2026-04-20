# scripts

Utility scripts for package installation and GGUF model management.

## sync_with_master.sh

Synchronizes the current branch before commit or publish.

```bash
./scripts/sync_with_master.sh
# or
just git-sync
```

- On `master`: `git pull --no-rebase origin master`
- On any other branch: `git fetch origin master` then `git merge origin/master`
- Dirty tracked, staged, and untracked changes are stashed first and popped back after sync.
- If stash pop conflicts, resolve conflicts before committing.

VS Code exposes this as the `git-sync` task via `.vscode/tasks.json`. Run it manually when the pre-push guard says the branch is stale.

## check_synced_with_master.sh

Pre-push guard. Fetches `origin/master` and blocks push if the current branch does not contain it.

```bash
./scripts/check_synced_with_master.sh
```

Installed by:

```bash
just precommit-install
```

If it fails, run `just git-sync`, resolve conflicts if needed, then push again.

## publish_public_mirror.sh

Publishes private `master` history to the public mirror repository.

```bash
./scripts/publish_public_mirror.sh
```

- Source ref defaults to `master`.
- Public target defaults to `git@github.com:MrAnyKey/ai-stack-public.git`.
- Only the branch is pushed. Private tags are not pushed.
- Local runs call `sync_with_master.sh` first. GitHub Actions skip that step because checkout already pins `master`.

## install_packages.sh

Installs system packages. Detects OS and uses the appropriate package manager.

- **Linux (Arch/CachyOS):** checks `pacman`, installs missing via `paru`
- **macOS:** checks `brew formula/cask`, installs missing via `brew`

```bash
bash scripts/install_packages.sh chezmoi uv llama-swap
```

Called automatically by `just install` and `just -f litellm/Justfile install`. On macOS, runs `brew install` instead of `paru`.

## update_models.sh

GGUF model manager. Registry of models defined in `models.json`. Uses HuggingFace CLI (`hf`) to download/update.

```bash
# Dry run — show what would change
./scripts/update_models.sh --check-only

# Download all missing models
./scripts/update_models.sh --all

# Remove files not in registry
./scripts/update_models.sh --prune

# Filter by model name substring
./scripts/update_models.sh --model qwen
./scripts/update_models.sh --model deepseek

# Check + download + prune in one pass
./scripts/update_models.sh --all --prune
```

Auto-restarts llama-swap after download if model files changed.

## models.json

Root-level registry of GGUF models (`models.json` at repo root). Each entry:

```json
{
  "dir": "model-name",
  "repo": "org/model-repo-on-hf",
  "include": "*.Q8_0.gguf"
}
```

Source of truth for `update_models.sh`. Add new model here, then run `--all` to download.

Windows support is not implemented yet. Use the Bash script on Linux or from a compatible shell.
