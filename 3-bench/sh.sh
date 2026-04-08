#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default model to use
export BENCH_MODEL="${BENCH_MODEL:-catboost-base}"

log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

log "Using model: $BENCH_MODEL"

log "Starting FastAPI with model: $BENCH_MODEL"
cd "$SCRIPT_DIR/1-FastAPI"
uvicorn app:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 &
UVICORN_PID=$!

sleep 5

log "Download Pharo + Executing Benchmark"
cd "$SCRIPT_DIR/2-BootStrap"
bash 2.sh

log "Showing Results"
# Results script path (if it exists)
python3 "$SCRIPT_DIR/3-Results/results.py" 2>/dev/null || log "Results script not found or failed"

log "Cleaning up"
kill $UVICORN_PID || true

log "All tasks completed."