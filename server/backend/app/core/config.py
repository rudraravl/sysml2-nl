"""Central configuration."""

import os

# Idle timeout (10 minutes default)
IDLE_UNLOAD_SECONDS = int(os.getenv("IDLE_UNLOAD_SECONDS", "600"))

# Device selection
MODEL_DEVICE = os.getenv("MODEL_DEVICE", "cuda")

# Input limits
MAX_INPUT_CHARS = int(os.getenv("MAX_INPUT_CHARS", "20000"))
DEFAULT_MAX_NEW_TOKENS = int(os.getenv("DEFAULT_MAX_NEW_TOKENS", "768"))

# Model IDs
# For gated models (gemma), set HF_TOKEN env var or run: huggingface-cli login
# Fallback: TinyLlama/TinyLlama-1.1B-Chat-v1.0 (public, for testing)
GEMMA_MODEL_ID = os.getenv("GEMMA_MODEL_ID", "TinyLlama/TinyLlama-1.1B-Chat-v1.0")
KALM_EMB_ID = os.getenv("KALM_EMB_ID", "tencent/KaLM-Embedding-Gemma3-12B-2511")

# HuggingFace token (for gated models)
HF_TOKEN = os.getenv("HF_TOKEN", None)

# Check CUDA availability at import time
try:
    import torch
    if not torch.cuda.is_available():
        MODEL_DEVICE = "cpu"
except ImportError:
    MODEL_DEVICE = "cpu"
