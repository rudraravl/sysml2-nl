"""Central configuration."""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from repository root (3 levels up from this file)
# server/backend/app/core/config.py -> repo root
_repo_root = Path(__file__).resolve().parents[4]
_env_file = _repo_root / ".env"
if _env_file.exists():
    load_dotenv(_env_file)

# Idle timeout (10 minutes default)
IDLE_UNLOAD_SECONDS = int(os.getenv("IDLE_UNLOAD_SECONDS", "600"))

# Device selection
MODEL_DEVICE = os.getenv("MODEL_DEVICE", "cuda")

# Input limits
MAX_INPUT_CHARS = int(os.getenv("MAX_INPUT_CHARS", "50000"))
DEFAULT_MAX_NEW_TOKENS = int(os.getenv("DEFAULT_MAX_NEW_TOKENS", "4096"))
MAX_NEW_TOKENS_LIMIT = int(os.getenv("MAX_NEW_TOKENS_LIMIT", "65536"))

# Model IDs
# KaLM-Gemma Pipeline:
#   Generator: google/gemma-3-12b-it (for generation via model.generate())
#   Encoder: tencent/KaLM-Embedding-Gemma3-12B-2511 (for embedding via encode())
# For gated models, set HF_TOKEN env var or run: huggingface-cli login
GEMMA_MODEL_ID = os.getenv("GEMMA_MODEL_ID", "google/gemma-3-12b-it")
KALM_EMB_ID = os.getenv("KALM_EMB_ID", "tencent/KaLM-Embedding-Gemma3-12B-2511")

# Qwen Pipeline:
#   Generator: Qwen/Qwen3-8B-Instruct (for generation)
#   Encoder: Qwen/Qwen3-Embedding-8B (for embedding)
QWEN_MODEL_ID = os.getenv("QWEN_MODEL_ID", "Qwen/Qwen3-8B")
QWEN_EMB_ID = os.getenv("QWEN_EMB_ID", "Qwen/Qwen3-Embedding-8B")

# HuggingFace token (for gated models)
HF_TOKEN = os.getenv("HF_TOKEN", None)

# Check CUDA availability at import time
try:
    import torch
    if not torch.cuda.is_available():
        MODEL_DEVICE = "cpu"
except ImportError:
    MODEL_DEVICE = "cpu"
