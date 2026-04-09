#!/bin/bash
# =========================================================
# Complete Benchmark Pipeline: A to Z
# =========================================================
# This script orchestrates the entire benchmark process:
# 1. Downloads base model (if needed)
# 2. Sets up FastAPI server with the model
# 3. Runs Pharo benchmark
# 4. Collects and saves results
# =========================================================

set -euo pipefail

# =========================================================
# Configuration
# =========================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default model - can be overridden via env var
# Options: catboost-base, catboost-bm25, catboost-emb, catboost-tfidf, catboost-full
#          qwen3-base-0.6b, qwen3-base-4b, qwen3-base-8b
export BENCH_MODEL="${BENCH_MODEL:-catboost-base}"

# HuggingFace model to download (for Qwen3 models)
declare -A HF_MODELS
HF_MODELS[qwen3-base-0.6b]="Qwen/Qwen3-Reranker-0.6B"
HF_MODELS[qwen3-base-4b]="Qwen/Qwen3-Reranker-4B"
HF_MODELS[qwen3-base-8b]="Qwen/Qwen3-Reranker-8B"

LOG_FILE="${SCRIPT_DIR}/pipeline.log"
RESULTS_DIR="${SCRIPT_DIR}/results"
MODELS_CACHE_DIR="${SCRIPT_DIR}/1-FastAPI/models"

# =========================================================
# Logging
# =========================================================
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIPELINE] $1"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
    exit 1
}

# =========================================================
# Helper Functions
# =========================================================
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "Required command not found: $1"
    fi
}

wait_for_server() {
    local url="$1"
    local max_wait="${2:-30}"
    local waited=0
    
    log "Waiting for server at $url (max ${max_wait}s)..."
    while [ $waited -lt $max_wait ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
            log "Server is ready after ${waited}s"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    error_exit "Server did not become ready after ${max_wait}s"
}

# =========================================================
# Step 1: Prerequisites Check
# =========================================================
step_prerequisites() {
    log "=========================================="
    log "Step 1: Checking prerequisites"
    log "=========================================="
    
    check_command "python3"
    check_command "curl"
    check_command "wget"
    
    # Check if virtual environment exists
    if [ ! -d "${SCRIPT_DIR}/venv" ]; then
        log "Creating Python virtual environment..."
        python3 -m venv "${SCRIPT_DIR}/venv"
    fi
    
    # Activate venv and install dependencies
    source "${SCRIPT_DIR}/venv/bin/activate"
    log "Installing Python dependencies..."
    pip install -q -r "${SCRIPT_DIR}/requirements.txt"
    
    log "Prerequisites check completed"
}

# =========================================================
# Step 2: Download Base Model (for Qwen3 models)
# =========================================================
step_download_model() {
    log "=========================================="
    log "Step 2: Downloading base model"
    log "=========================================="
    
    local model="$BENCH_MODEL"
    
    # Check if it's a Qwen3 model
    if [[ -n "${HF_MODELS[$model]+_}" ]]; then
        local hf_id="${HF_MODELS[$model]}"
        local model_cache_path="${MODELS_CACHE_DIR}/${model}"
        
        if [ -d "$model_cache_path" ]; then
            log "Model already cached: $model"
            log "Skipping download (delete $model_cache_path to force re-download)"
        else
            log "Downloading model from HuggingFace: $hf_id"
            mkdir -p "$MODELS_CACHE_DIR"
            
            python3 -c "
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import os

model_id = '$hf_id'
cache_path = '$model_cache_path'

print(f'Downloading {model_id}...')
tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
model = AutoModelForSequenceClassification.from_pretrained(
    model_id,
    trust_remote_code=True,
)

tokenizer.save_pretrained(cache_path)
model.save_pretrained(cache_path)
print(f'Model saved to: {cache_path}')
"
            log "Model download completed: $model"
        fi
    else
        log "Model '$model' is a CatBoost model - no download needed"
    fi
}

# =========================================================
# Step 3: Setup Results Directory
# =========================================================
step_setup_results() {
    log "=========================================="
    log "Step 3: Setting up results directory"
    log "=========================================="
    
    mkdir -p "${RESULTS_DIR}/runs"
    mkdir -p "${RESULTS_DIR}/models"
    
    log "Results directory ready: ${RESULTS_DIR}"
}

# =========================================================
# Step 4: Start FastAPI Server
# =========================================================
step_start_fastapi() {
    log "=========================================="
    log "Step 4: Starting FastAPI server"
    log "=========================================="
    
    cd "${SCRIPT_DIR}/1-FastAPI"
    
    # Kill any existing uvicorn on port 8000
    if lsof -ti :8000 > /dev/null 2>&1; then
        log "Killing existing process on port 8000..."
        kill -9 $(lsof -ti :8000) || true
        sleep 2
    fi
    
    # Start uvicorn in background
    log "Starting uvicorn with model: $BENCH_MODEL"
    BENCH_MODEL="$BENCH_MODEL" uvicorn app:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 &
    UVICORN_PID=$!
    
    log "Uvicorn started with PID: $UVICORN_PID"
    echo "$UVICORN_PID" > "${SCRIPT_DIR}/.uvicorn.pid"
    
    # Wait for server to be ready
    wait_for_server "http://localhost:8000/models" 60
    
    # Verify server is responding
    local response
    response=$(curl -s http://localhost:8000/models)
    log "Server response: $response"
    
    cd "$SCRIPT_DIR"
}

# =========================================================
# Step 5: Run Pharo Benchmark
# =========================================================
step_run_benchmark() {
    log "=========================================="
    log "Step 5: Running Pharo benchmark"
    log "=========================================="
    
    cd "${SCRIPT_DIR}/2-BootStrap"
    
    log "Executing Pharo benchmark..."
    BENCH_MODEL="$BENCH_MODEL" bash 2.sh
    
    log "Pharo benchmark completed"
    cd "$SCRIPT_DIR"
}

# =========================================================
# Step 6: Collect Results
# =========================================================
step_collect_results() {
    log "=========================================="
    log "Step 6: Collecting results"
    log "=========================================="
    
    BENCH_MODEL="$BENCH_MODEL" python3 "${SCRIPT_DIR}/3-Results/results.py"
    
    log "Results collection completed"
}

# =========================================================
# Step 7: Cleanup
# =========================================================
step_cleanup() {
    log "=========================================="
    log "Step 7: Cleanup"
    log "=========================================="
    
    # Kill uvicorn if running
    if [ -f "${SCRIPT_DIR}/.uvicorn.pid" ]; then
        UVICORN_PID=$(cat "${SCRIPT_DIR}/.uvicorn.pid")
        if kill -0 "$UVICORN_PID" 2>/dev/null; then
            log "Stopping uvicorn (PID: $UVICORN_PID)..."
            kill "$UVICORN_PID" || true
            sleep 2
        fi
        rm -f "${SCRIPT_DIR}/.uvicorn.pid"
    fi
    
    # Also kill by port as backup
    if lsof -ti :8000 > /dev/null 2>&1; then
        log "Force killing process on port 8000..."
        kill -9 $(lsof -ti :8000) || true
    fi
    
    log "Cleanup completed"
}

# =========================================================
# Main Pipeline
# =========================================================
main() {
    log "=========================================="
    log "Starting Benchmark Pipeline"
    log "Model: $BENCH_MODEL"
    log "Results: ${RESULTS_DIR}"
    log "=========================================="
    
    # Trap to ensure cleanup on exit
    trap step_cleanup EXIT
    
    # Execute pipeline steps
    step_prerequisites
    step_download_model
    step_setup_results
    step_start_fastapi
    step_run_benchmark
    step_collect_results
    
    log "=========================================="
    log "Pipeline completed successfully!"
    log "Results saved to: ${RESULTS_DIR}"
    log "Latest results: ${RESULTS_DIR}/latest.json"
    log "=========================================="
    
    # Print summary
    if [ -f "${RESULTS_DIR}/latest.json" ]; then
        log "Latest run summary:"
        python3 -c "
import json
with open('${RESULTS_DIR}/latest.json') as f:
    data = json.load(f)
print(f\"  Model: {data.get('model_name', 'N/A')}\")
print(f\"  Run ID: {data.get('run_id', 'N/A')}\")
print(f\"  Status: {data.get('status', 'N/A')}\")
print(f\"  Timestamp: {data.get('timestamp', 'N/A')}\")
"
    fi
}

# Run main
main "$@"
