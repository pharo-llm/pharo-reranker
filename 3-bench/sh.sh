#!/bin/bash

# =========================================================
# Benchmark Runner (Legacy - redirects to run-all.sh)
# =========================================================
# This script now delegates to the complete pipeline script
# For direct usage, run: bash run-all.sh
# =========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

log "Redirecting to complete pipeline (run-all.sh)..."
log "For standalone FastAPI server, use: cd 1-FastAPI && uvicorn app:app --host 0.0.0.0 --port 8000"

# Execute the complete pipeline
exec bash "${SCRIPT_DIR}/run-all.sh" "$@"
