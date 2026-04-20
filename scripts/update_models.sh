#!/usr/bin/env bash
set -euo pipefail

# Check, download, update, and prune GGUF models using models.json as source of truth.

CHECK_ONLY=0
ALL=0
PRUNE=0
NO_RESTART=0
MODEL_FILTER=""

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
REGISTRY_FILE="${REPO_ROOT}/models.json"
MODELS_ROOT="${MODELS_ROOT:-${REPO_ROOT}/models}"

usage() {
  cat <<'EOF'
Usage: ./scripts/update_models.sh [options]

Options:
  --check-only        Dry run (no download, no delete)
  --all               Download models that are missing locally
  --prune             Find/remove local .gguf files not in models.json
  --no-restart        Skip llama-swap restart even if files changed
  --model <substr>    Filter entries by dir substring (example: gemma)
  --models-root <p>   Override models root dir (default: $MODELS_ROOT or <git-root>/models)
  -h, --help          Show this help

Examples:
  ./scripts/update_models.sh --check-only
  ./scripts/update_models.sh
  ./scripts/update_models.sh --all --prune
  ./scripts/update_models.sh --model gemma --all
  MODELS_ROOT=/data/models ./scripts/update_models.sh --check-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    --all) ALL=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --no-restart) NO_RESTART=1; shift ;;
    --model)
      [[ $# -lt 2 ]] && { echo "Missing value for --model" >&2; exit 2; }
      MODEL_FILTER="$2"
      shift 2
      ;;
    --models-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --models-root" >&2; exit 2; }
      MODELS_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 1; }
command -v hf >/dev/null 2>&1 || { echo "hf CLI not found. Install: curl -LsSf https://hf.co/cli/install.sh | bash" >&2; exit 1; }
[[ -f "$REGISTRY_FILE" ]] || { echo "Registry not found: $REGISTRY_FILE" >&2; exit 1; }

mapfile -t ENTRIES < <(
  python3 - "$REGISTRY_FILE" "$MODEL_FILTER" <<'PY'
import json
import sys

registry_file = sys.argv[1]
flt = sys.argv[2].lower()

with open(registry_file, "r", encoding="utf-8") as f:
    data = json.load(f)

for e in data:
    d = str(e.get("dir", ""))
    r = str(e.get("repo", ""))
    i = str(e.get("include", ""))
    if not (d and r and i):
        continue
    if flt and flt not in d.lower():
        continue
    print(f"{d}\t{r}\t{i}")
PY
)

if [[ -n "$MODEL_FILTER" && ${#ENTRIES[@]} -eq 0 ]]; then
  echo "No entries match '$MODEL_FILTER' in $REGISTRY_FILE" >&2
  exit 1
fi

declare -A REGISTERED_FILES=()
declare -A REPO_CACHE=()

for line in "${ENTRIES[@]}"; do
  IFS=$'\t' read -r dir repo include <<<"$line"
  key="${dir}/${include}"
  key="${key,,}"
  REGISTERED_FILES["$key"]=1
done

short_sha() {
  local s="${1:-}"
  if [[ -z "$s" ]]; then
    echo "(none)"
  else
    echo "${s:0:12}"
  fi
}

get_local_commit() {
  local local_dir="$1"
  local filename="$2"
  local meta="${local_dir}/.cache/huggingface/download/${filename}.metadata"
  if [[ ! -f "$meta" ]]; then
    return 1
  fi
  head -n 1 "$meta" | tr -d '[:space:]'
}

get_remote_commit() {
  local repo="$1"
  if [[ -n "${REPO_CACHE[$repo]:-}" ]]; then
    echo "${REPO_CACHE[$repo]}"
    return 0
  fi

  local sha
  if ! sha="$(
    curl -fsSL "https://huggingface.co/api/models/${repo}/revision/main" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sha", ""))'
  )"; then
    echo "  [WARN] HF API unreachable for ${repo}" >&2
    REPO_CACHE["$repo"]=""
    return 1
  fi

  REPO_CACHE["$repo"]="$sha"
  echo "$sha"
}

remove_old_ggufs() {
  local local_dir="$1"
  local keep_file="$2"
  local dir_name
  dir_name="$(basename "$local_dir")"

  [[ -d "$local_dir" ]] || return 0

  shopt -s nullglob
  for file in "$local_dir"/*.gguf; do
    local name
    name="$(basename "$file")"
    [[ "$name" == "$keep_file" ]] && continue

    local key="${dir_name}/${name}"
    key="${key,,}"
    if [[ -z "${REGISTERED_FILES[$key]:-}" ]]; then
      echo "  removing old file: ${name}"
      if [[ "$CHECK_ONLY" -eq 0 ]]; then
        rm -f -- "$file"
        local meta="${local_dir}/.cache/huggingface/download/${name}.metadata"
        [[ -f "$meta" ]] && rm -f -- "$meta"
      fi
    fi
  done
  shopt -u nullglob
}

restart_llama_swap() {
  echo
  echo "Restarting llama-swap..."

  if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet llama-swap; then
    systemctl --user restart llama-swap
    echo "llama-swap restarted OK (systemctl --user)"
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet llama-swap; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      sudo systemctl restart llama-swap
      echo "llama-swap restarted OK (sudo systemctl)"
      return 0
    fi
    echo "Restart skipped: need privileges. Run manually: sudo systemctl restart llama-swap"
    return 1
  fi

  echo "Restart skipped: no active systemd service 'llama-swap' detected"
  echo "Run manually with your process manager if needed"
  return 1
}

updated=0
current=0
new_items=0
skipped=0
failed=0

mode_str="UPDATE EXISTING"
if [[ "$CHECK_ONLY" -eq 1 ]]; then
  mode_str="CHECK ONLY"
elif [[ "$ALL" -eq 1 && "$PRUNE" -eq 1 ]]; then
  mode_str="UPDATE + NEW + PRUNE"
elif [[ "$ALL" -eq 1 ]]; then
  mode_str="UPDATE + NEW"
elif [[ "$PRUNE" -eq 1 ]]; then
  mode_str="UPDATE + PRUNE"
fi

echo
echo "=== GGUF Model Manager (Linux) ==="
echo "Registry : ${REGISTRY_FILE} (${#ENTRIES[@]} entries)"
echo "Models   : ${MODELS_ROOT}"
echo "Mode     : ${mode_str}"
echo

for line in "${ENTRIES[@]}"; do
  IFS=$'\t' read -r dir repo include <<<"$line"

  local_dir="${MODELS_ROOT}/${dir}"
  local_file="${local_dir}/${include}"

  echo "[ ${dir} / ${include} ]"

  if [[ ! -f "$local_file" ]]; then
    if [[ "$ALL" -eq 1 && "$CHECK_ONLY" -eq 0 ]]; then
      echo "  new - downloading..."
      mkdir -p "$local_dir"
      if hf download "$repo" --include "$include" --local-dir "$local_dir"; then
        echo "  done"
        ((new_items+=1))
        remove_old_ggufs "$local_dir" "$include"
      else
        echo "  FAILED"
        ((failed+=1))
      fi
    else
      if [[ "$ALL" -eq 1 ]]; then
        echo "  not downloaded"
      else
        echo "  not downloaded (use --all to fetch)"
      fi
      ((skipped+=1))
    fi
    echo
    continue
  fi

  local_sha=""
  if local_sha_tmp="$(get_local_commit "$local_dir" "$include" 2>/dev/null)"; then
    local_sha="$local_sha_tmp"
  fi

  remote_sha=""
  if ! remote_sha="$(get_remote_commit "$repo" 2>/dev/null)" || [[ -z "$remote_sha" ]]; then
    echo "  cannot reach HF, skipping"
    ((skipped+=1))
    echo
    continue
  fi

  if [[ "$local_sha" == "$remote_sha" ]]; then
    echo "  up to date  [$(short_sha "$remote_sha")]"
    ((current+=1))
  else
    echo "  UPDATE AVAILABLE"
    echo "    local : $(short_sha "$local_sha")"
    echo "    remote: $(short_sha "$remote_sha")"

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
      ((skipped+=1))
    else
      echo "  downloading..."
      if hf download "$repo" --include "$include" --local-dir "$local_dir"; then
        echo "  done"
        ((updated+=1))
        remove_old_ggufs "$local_dir" "$include"
      else
        echo "  FAILED"
        ((failed+=1))
      fi
    fi
  fi
  echo
done

if [[ "$PRUNE" -eq 1 ]]; then
  echo "=== Prune - scanning for orphaned files ==="
  echo

  ORPHANS=()
  ORPHAN_SIZES=()

  if [[ -d "$MODELS_ROOT" ]]; then
    while IFS= read -r -d '' file; do
      dir_name="$(basename "$(dirname "$file")")"
      file_name="$(basename "$file")"
      key="${dir_name}/${file_name}"
      key="${key,,}"

      if [[ -z "${REGISTERED_FILES[$key]:-}" ]]; then
        ORPHANS+=("$file")
        size_bytes="$(stat -c %s "$file" 2>/dev/null || echo 0)"
        ORPHAN_SIZES+=("$size_bytes")
      fi
    done < <(find "$MODELS_ROOT" -mindepth 2 -maxdepth 2 -type f -name '*.gguf' -print0)
  fi

  if [[ ${#ORPHANS[@]} -eq 0 ]]; then
    echo "  nothing to prune - all files on disk are in models.json"
  else
    echo "  Found ${#ORPHANS[@]} orphaned file(s) not in models.json:"
    echo

    total_bytes=0
    for idx in "${!ORPHANS[@]}"; do
      file="${ORPHANS[$idx]}"
      size_bytes="${ORPHAN_SIZES[$idx]}"
      total_bytes=$((total_bytes + size_bytes))
      size_gb="$(python3 - <<PY
s=${size_bytes}
print(round(s / (1024**3), 2))
PY
)"
      rel="${file#"${MODELS_ROOT}"/}"
      echo "  ${rel} [${size_gb} GB]"
    done

    total_gb="$(python3 - <<PY
s=${total_bytes}
print(round(s / (1024**3), 2))
PY
)"
    echo
    echo "  Total: ${total_gb} GB"
    echo

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
      echo "  (dry run - nothing deleted)"
    else
      read -r -p "  Delete all listed files? [y/N] " answer
      if [[ "$answer" =~ ^[yY]$ ]]; then
        for file in "${ORPHANS[@]}"; do
          rm -f -- "$file"
          parent="$(dirname "$file")"
          base="$(basename "$file")"
          meta="${parent}/.cache/huggingface/download/${base}.metadata"
          [[ -f "$meta" ]] && rm -f -- "$meta"
          rel="${file#"${MODELS_ROOT}"/}"
          echo "  deleted: ${rel}"
        done
        echo
        echo "  Pruned ${#ORPHANS[@]} file(s), freed ~${total_gb} GB"
      else
        echo "  Skipped - nothing deleted"
      fi
    fi
  fi
  echo
fi

echo "=== Summary ==="
[[ "$current"  -gt 0 ]] && echo "  Up-to-date    : ${current}"
[[ "$updated"  -gt 0 ]] && echo "  Updated       : ${updated}"
[[ "$new_items" -gt 0 ]] && echo "  Downloaded new: ${new_items}"
[[ "$skipped"  -gt 0 ]] && echo "  Skipped       : ${skipped}"
[[ "$failed"   -gt 0 ]] && echo "  Failed        : ${failed}"

if [[ $((updated + new_items)) -gt 0 && "$CHECK_ONLY" -eq 0 && "$NO_RESTART" -eq 0 ]]; then
  restart_llama_swap || true
fi
