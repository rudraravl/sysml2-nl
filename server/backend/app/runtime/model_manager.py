"""Model manager with load-on-demand and idle unload.

IMPORTANT USAGE RULES:
- Generator (gemma): Only use model.generate(), never for embedding
- Encoder (kalm): Only use for embedding (encode/forward), never generate()
- Never mix tokenizers from different checkpoints
- Use apply_chat_template for chat models
"""

import gc
import time
import asyncio
from typing import Any, Optional

from app.core.config import (
    IDLE_UNLOAD_SECONDS, MODEL_DEVICE, 
    GEMMA_MODEL_ID, KALM_EMB_ID, HF_TOKEN
)
from app.core.logging import get_logger

log = get_logger(__name__)

# Minimum free GPU memory required before loading a new model (in GB)
MIN_FREE_GPU_MEMORY_GB = 25


class ModelManager:
    """Manages model lifecycle: load on demand, unload after idle."""

    def __init__(self):
        self._models: dict[str, Any] = {}
        self._tokenizers: dict[str, Any] = {}
        self._last_used: dict[str, float] = {}
        self._lock = asyncio.Lock()
        self._device = MODEL_DEVICE

    def _get_free_gpu_memory_gb(self) -> float:
        """Get free GPU memory in GB. Returns inf if not using CUDA."""
        if self._device != "cuda":
            return float('inf')
        
        try:
            import torch
            if not torch.cuda.is_available():
                return float('inf')
            
            # Get free memory on the current CUDA device
            free_bytes = torch.cuda.mem_get_info()[0]
            free_gb = free_bytes / (1024 ** 3)
            return free_gb
        except Exception as e:
            log.warning(f"Failed to get GPU memory info: {e}")
            return float('inf')

    def _get_lru_model_key(self) -> Optional[str]:
        """Get the least recently used model key, or None if no models loaded."""
        if not self._last_used:
            return None
        # Return the key with the oldest (smallest) timestamp
        return min(self._last_used, key=self._last_used.get)

    def _ensure_gpu_memory(self, required_gb: float = MIN_FREE_GPU_MEMORY_GB) -> list[str]:
        """
        Ensure at least required_gb of free GPU memory.
        Uses LRU eviction to free memory if needed.
        Returns list of unloaded model keys.
        """
        unloaded = []
        
        while self._get_free_gpu_memory_gb() < required_gb:
            lru_key = self._get_lru_model_key()
            if lru_key is None:
                # No more models to unload
                free_mem = self._get_free_gpu_memory_gb()
                log.warning(
                    f"Cannot free enough GPU memory. "
                    f"Need {required_gb:.1f}GB, have {free_mem:.1f}GB free, "
                    f"no models to unload."
                )
                break
            
            log.info(
                f"GPU memory low ({self._get_free_gpu_memory_gb():.1f}GB free, "
                f"need {required_gb:.1f}GB). Unloading LRU model: {lru_key}"
            )
            self._unload_key(lru_key)
            unloaded.append(lru_key)
        
        if unloaded:
            log.info(
                f"Freed GPU memory by unloading {len(unloaded)} model(s). "
                f"Now have {self._get_free_gpu_memory_gb():.1f}GB free."
            )
        
        return unloaded

    async def get_generator(self) -> tuple[Any, Any, bool, int, list[str]]:
        """
        Get generator tokenizer and model (Gemma).
        Only for model.generate() - never use for embedding.
        Returns: (tokenizer, model, loaded_from_cache, load_ms, evicted_models)
        """
        key = "generator"
        evicted = []
        async with self._lock:
            cached = key in self._models

            if not cached:
                # Ensure enough GPU memory before loading
                evicted = self._ensure_gpu_memory(MIN_FREE_GPU_MEMORY_GB)
                
                log.info(f"Loading generator: {GEMMA_MODEL_ID}")
                load_start = time.time()
                tokenizer, model = self._load_generator()
                self._tokenizers[key] = tokenizer
                self._models[key] = model
                load_ms = int((time.time() - load_start) * 1000)
                log.info(f"Generator loaded in {load_ms}ms on {self._device}")
            else:
                load_ms = 0
                log.debug("Generator already loaded")

            self._last_used[key] = time.time()
            return self._tokenizers[key], self._models[key], cached, load_ms, evicted

    async def get_encoder(self) -> tuple[Any, Any, bool, int, list[str]]:
        """
        Get encoder tokenizer and model (KaLM).
        Only for embedding (encode/forward) - never use generate().
        Returns: (tokenizer, model, loaded_from_cache, load_ms, evicted_models)
        """
        key = "encoder"
        evicted = []
        async with self._lock:
            cached = key in self._models

            if not cached:
                # Ensure enough GPU memory before loading
                evicted = self._ensure_gpu_memory(MIN_FREE_GPU_MEMORY_GB)
                
                log.info(f"Loading encoder: {KALM_EMB_ID}")
                load_start = time.time()
                tokenizer, model = self._load_encoder()
                self._tokenizers[key] = tokenizer
                self._models[key] = model
                load_ms = int((time.time() - load_start) * 1000)
                log.info(f"Encoder loaded in {load_ms}ms on {self._device}")
            else:
                load_ms = 0
                log.debug("Encoder already loaded")

            self._last_used[key] = time.time()
            return self._tokenizers[key], self._models[key], cached, load_ms, evicted

    def _load_generator(self) -> tuple[Any, Any]:
        """Load generator (Gemma) - for text generation only."""
        from transformers import AutoTokenizer, AutoModelForCausalLM
        import torch

        kwargs = {"token": HF_TOKEN} if HF_TOKEN else {}

        tokenizer = AutoTokenizer.from_pretrained(GEMMA_MODEL_ID, **kwargs)
        model = AutoModelForCausalLM.from_pretrained(
            GEMMA_MODEL_ID,
            torch_dtype=torch.bfloat16,
            device_map=self._device if self._device == "cuda" else None,
            **kwargs,
        )

        if self._device == "cuda" and model.device.type != "cuda":
            model = model.to(self._device)

        model.eval()
        return tokenizer, model

    def _load_encoder(self) -> tuple[Any, Any]:
        """Load encoder (KaLM) - for embedding only, never generate()."""
        from transformers import AutoTokenizer, AutoModel
        import torch

        kwargs = {"token": HF_TOKEN} if HF_TOKEN else {}

        tokenizer = AutoTokenizer.from_pretrained(KALM_EMB_ID, **kwargs)
        model = AutoModel.from_pretrained(
            KALM_EMB_ID,
            torch_dtype=torch.bfloat16,
            device_map=self._device if self._device == "cuda" else None,
            **kwargs,
        )

        if self._device == "cuda" and model.device.type != "cuda":
            model = model.to(self._device)

        model.eval()
        return tokenizer, model

    async def unload_if_idle(self, now: Optional[float] = None) -> list[str]:
        """Unload models that have been idle beyond threshold."""
        now = now or time.time()
        unloaded = []

        async with self._lock:
            keys_to_unload = [
                k for k, t in self._last_used.items()
                if now - t > IDLE_UNLOAD_SECONDS
            ]

            for key in keys_to_unload:
                log.info(f"Unloading idle model: {key}")
                self._unload_key(key)
                unloaded.append(key)

        return unloaded

    async def unload_all(self):
        """Unload all models (for shutdown)."""
        async with self._lock:
            keys = list(self._models.keys())
            for key in keys:
                log.info(f"Unloading model: {key}")
                self._unload_key(key)

    def _unload_key(self, key: str):
        """Unload a single model and free memory."""
        import torch

        if key in self._models:
            del self._models[key]
        if key in self._tokenizers:
            del self._tokenizers[key]
        if key in self._last_used:
            del self._last_used[key]

        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

    async def status(self) -> dict:
        """Return loaded models and last_used times."""
        async with self._lock:
            return {
                "loaded_models": list(self._models.keys()),
                "last_used": dict(self._last_used),
            }
