# Benchmark - Pharo Reranker

This directory contains the benchmarking infrastructure for both CatBoost and base Qwen3-Reranker models.

## Available Models

### Base Qwen3-Reranker Models (loaded from Hugging Face)
- `qwen3-base-0.6b` - Qwen3-Reranker-0.6B (lightweight)
- `qwen3-base-4b` - Qwen3-Reranker-4B (medium)
- `qwen3-base-8b` - Qwen3-Reranker-8B (largest)

## Usage

### Run with default model (catboost-base)
```bash
bash sh.sh
```

### Run with a base Qwen3 model
```bash
BENCH_MODEL=qwen3-base-0.6b bash sh.sh
BENCH_MODEL=qwen3-base-4b bash sh.sh
BENCH_MODEL=qwen3-base-8b bash sh.sh
```

### Run with a specific CatBoost model
```bash
BENCH_MODEL=catboost-full bash sh.sh
```

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. For CatBoost models, ensure model files exist in `1-FastAPI/models/` directory with proper structure.

3. For base Qwen3 models, ensure you have sufficient GPU/memory:
   - `qwen3-base-0.6b`: ~1.2GB VRAM
   - `qwen3-base-4b`: ~8GB VRAM
   - `qwen3-base-8b`: ~16GB VRAM