#!/usr/bin/env bash
set -euo pipefail

SOURCE_REF="${SOURCE_REF:-master}"
PUBLIC_REPOSITORY="${PUBLIC_REPOSITORY:-git@github.com:MrAnyKey/ai-stack-public.git}"
PUBLIC_BRANCH="${PUBLIC_BRANCH:-master}"
PUBLIC_TAGS="${PUBLIC_TAGS:-true}"
SYNC_BEFORE_PUBLISH="${SYNC_BEFORE_PUBLISH:-true}"

repo_root="$(git rev-parse --show-toplevel)"

if [[ "$SYNC_BEFORE_PUBLISH" == "true" && -z "${GITHUB_ACTIONS:-}" ]]; then
  "$repo_root/scripts/sync_with_master.sh"
fi

if git -C "$repo_root" remote get-url public >/dev/null 2>&1; then
  git -C "$repo_root" remote set-url public "$PUBLIC_REPOSITORY"
else
  git -C "$repo_root" remote add public "$PUBLIC_REPOSITORY"
fi

git -C "$repo_root" push --force public "$SOURCE_REF:$PUBLIC_BRANCH"

if [[ "$PUBLIC_TAGS" == "true" ]]; then
  git -C "$repo_root" push --force public 'refs/tags/*:refs/tags/*'
fi
