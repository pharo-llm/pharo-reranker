#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
from pathlib import Path

import yaml


def set_reranker_env(cfg: dict) -> None:
    reranker_env = cfg.get("reranker_env", {})
    env_map = {
        "max_positive_samples": "MAX_POSITIVE_SAMPLES",
        "max_negative_samples": "MAX_NEGATIVE_SAMPLES",
        "listwise_temperature": "LISTWISE_RERANKER_TEMPERATURE",
        "listwise_min_group_size": "LISTWISE_RERANKER_MIN_GROUP_SIZE",
        "positive_token": "GENERATIVE_RERANKER_POSITIVE_TOKEN",
        "negative_token": "GENERATIVE_RERANKER_NEGATIVE_TOKEN",
    }
    for key, env_name in env_map.items():
        if key in reranker_env:
            os.environ[env_name] = str(reranker_env[key])


def require_file(path: str, label: str) -> None:
    if not Path(path).exists():
        raise FileNotFoundError(f"{label} not found: {path}")


def build_swift_command(cfg: dict, model_cfg: dict) -> list[str]:
    data_cfg = cfg["data"]
    out_cfg = cfg["output"]
    train_cfg = cfg["training"]
    lora_cfg = cfg["lora"]

    out_dir = str(Path(out_cfg["root_dir"]) / model_cfg["run_name"])

    cmd = [
        "swift", "sft",
        "--model", model_cfg["name"],
        "--task_type", str(train_cfg["task_type"]),
        "--loss_type", str(train_cfg["loss_type"]),
        "--train_type", str(train_cfg["train_type"]),
        "--tuner_backend", str(train_cfg["tuner_backend"]),
        "--lora_rank", str(lora_cfg["rank"]),
        "--lora_alpha", str(lora_cfg["alpha"]),
        "--target_modules", str(train_cfg["target_modules"]),
        "--dataset", str(data_cfg["train_file"]),
        "--val_dataset", str(data_cfg["valid_file"]),
        "--dataset_num_proc", str(train_cfg["dataset_num_proc"]),
        "--max_length", str(train_cfg["max_length"]),
        "--learning_rate", str(train_cfg["learning_rate"]),
        "--num_train_epochs", str(train_cfg["num_train_epochs"]),
        "--per_device_train_batch_size", str(model_cfg["per_device_train_batch_size"]),
        "--per_device_eval_batch_size", str(model_cfg["per_device_eval_batch_size"]),
        "--gradient_accumulation_steps", str(train_cfg["gradient_accumulation_steps"]),
        "--warmup_ratio", str(train_cfg["warmup_ratio"]),
        "--weight_decay", str(train_cfg["weight_decay"]),
        "--eval_strategy", "steps",
        "--eval_steps", str(train_cfg["eval_steps"]),
        "--save_strategy", "steps",
        "--save_steps", str(train_cfg["save_steps"]),
        "--save_total_limit", str(train_cfg["save_total_limit"]),
        "--logging_steps", str(train_cfg["logging_steps"]),
        "--seed", str(train_cfg["seed"]),
        "--torch_dtype", str(train_cfg["torch_dtype"]),
        "--attn_impl", str(train_cfg["attn_impl"]),
        "--gradient_checkpointing", str(train_cfg["gradient_checkpointing"]).lower(),
        "--output_dir", out_dir,
    ]
    return cmd


def run_one(cfg: dict, model_cfg: dict, dry_run: bool = False) -> int:
    out_dir = Path(cfg["output"]["root_dir"]) / model_cfg["run_name"]
    out_dir.mkdir(parents=True, exist_ok=True)

    cmd = build_swift_command(cfg, model_cfg)

    print("=" * 80)
    print(f"Model:      {model_cfg['name']}")
    print(f"Run name:   {model_cfg['run_name']}")
    print(f"Output dir: {out_dir}")
    print("Command:")
    print(" ".join(cmd))
    print("=" * 80)

    if dry_run:
        return 0

    proc = subprocess.run(cmd)
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, help="Path to YAML config")
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Optional run_name(s) to train, e.g. qwen3-reranker-0.6b",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    require_file(cfg["data"]["train_file"], "Train file")
    require_file(cfg["data"]["valid_file"], "Validation file")

    Path(cfg["output"]["root_dir"]).mkdir(parents=True, exist_ok=True)

    set_reranker_env(cfg)

    models = cfg.get("models", [])
    if not models:
        raise ValueError("No models found in config.yaml")

    selected_models = models
    if args.only:
        only_set = set(args.only)
        selected_models = [m for m in models if m["run_name"] in only_set]
        if not selected_models:
            raise ValueError(f"No matching models found for --only {args.only}")

    for model_cfg in selected_models:
        code = run_one(cfg, model_cfg, dry_run=args.dry_run)
        if code != 0:
            print(f"Training failed for {model_cfg['run_name']} with exit code {code}", file=sys.stderr)
            return code

    print("All requested trainings finished successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())