#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${SCRIPT_DIR}/1-FastAPI/models"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOWNLOAD] $1"
}

mkdir -p "$MODELS_DIR"

MODELS=(
    "qwen3-reranker-0.6b|Qwen/Qwen3-Reranker-0.6B"
    "qwen3-reranker-4b|Qwen/Qwen3-Reranker-4B"
    "qwen3-reranker-8b|Qwen/Qwen3-Reranker-8B"
)

for entry in "${MODELS[@]}"; do
    IFS='|' read -r MODEL_NAME HF_ID <<< "$entry"
    MODEL_PATH="${MODELS_DIR}/${MODEL_NAME}"

    if [ -d "$MODEL_PATH" ]; then
        log "Model already exists, skipping: $MODEL_NAME -> $MODEL_PATH"
        continue
    fi

    log "Downloading snapshot: $MODEL_NAME"
    log "From Hugging Face: $HF_ID"

    python3 <<PYTHON_SCRIPT
from huggingface_hub import snapshot_download

repo_id = "$HF_ID"
local_dir = "$MODEL_PATH"

snapshot_download(
    repo_id=repo_id,
    local_dir=local_dir,
    local_dir_use_symlinks=False,
)

print(f"SUCCESS: Downloaded {repo_id} to {local_dir}")
PYTHON_SCRIPT

    log "Saved to: $MODEL_PATH"
    du -sh "$MODEL_PATH"
done

log "All requested models processed."