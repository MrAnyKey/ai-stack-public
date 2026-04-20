#!/usr/bin/env bash
set -euo pipefail

MASTER_BRANCH="${MASTER_BRANCH:-master}"
REMOTE="${REMOTE:-origin}"

repo_root="$(git rev-parse --show-toplevel)"
branch="$(git -C "$repo_root" branch --show-current)"

if [[ -z "$branch" ]]; then
  echo "[miss] detached HEAD; checkout a branch before push"
  exit 1
fi

git -C "$repo_root" fetch "$REMOTE" "$MASTER_BRANCH" --quiet

master_ref="$REMOTE/$MASTER_BRANCH"
if ! git -C "$repo_root" rev-parse --verify --quiet "$master_ref" >/dev/null; then
  echo "[miss] cannot find $master_ref"
  exit 1
fi

if git -C "$repo_root" merge-base --is-ancestor "$master_ref" HEAD; then
  echo "[ok] $branch contains $master_ref"
  exit 0
fi

echo "[miss] $branch does not contain latest $master_ref"
echo "[fix] run: just git-sync"
exit 1
