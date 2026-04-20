#!/usr/bin/env bash
set -euo pipefail

MASTER_BRANCH="${MASTER_BRANCH:-master}"
REMOTE="${REMOTE:-origin}"

repo_root="$(git rev-parse --show-toplevel)"
branch="$(git -C "$repo_root" branch --show-current)"

if [[ -z "$branch" ]]; then
  echo "[miss] detached HEAD; checkout a branch first"
  exit 1
fi

if [[ -f "$repo_root/.git/MERGE_HEAD" || -d "$repo_root/.git/rebase-merge" || -d "$repo_root/.git/rebase-apply" ]]; then
  echo "[miss] merge or rebase already in progress; finish it first"
  exit 1
fi

stash_ref=""
if ! git -C "$repo_root" diff --quiet || ! git -C "$repo_root" diff --cached --quiet || [[ -n "$(git -C "$repo_root" ls-files --others --exclude-standard)" ]]; then
  before_stash="$(git -C "$repo_root" rev-parse -q --verify refs/stash || true)"
  git -C "$repo_root" stash push --include-untracked -m "ai-stack sync before commit"
  after_stash="$(git -C "$repo_root" rev-parse -q --verify refs/stash || true)"

  if [[ "$before_stash" != "$after_stash" ]]; then
    stash_ref="stash@{0}"
  fi
fi

if [[ "$branch" == "$MASTER_BRANCH" ]]; then
  git -C "$repo_root" pull --no-rebase "$REMOTE" "$MASTER_BRANCH"
else
  git -C "$repo_root" fetch "$REMOTE" "$MASTER_BRANCH"
  git -C "$repo_root" merge --no-edit "$REMOTE/$MASTER_BRANCH"
fi

if [[ -n "$stash_ref" ]]; then
  git -C "$repo_root" stash pop "$stash_ref"
fi

echo "[ok] synced $branch with $REMOTE/$MASTER_BRANCH"
