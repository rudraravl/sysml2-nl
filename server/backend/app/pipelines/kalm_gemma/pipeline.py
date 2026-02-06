"""KaLM-Gemma pipeline implementation."""

import time
from fastapi import HTTPException

from app.pipelines.base import BasePipeline
from app.pipelines.kalm_gemma.prompt import build_prompt
from app.runtime.resources import model_manager
from app.core.config import MAX_INPUT_CHARS
from app.core.logging import get_logger

log = get_logger(__name__)


class KaLMGemmaPipeline(BasePipeline):
    """Pipeline using Gemma for SysML generation."""

    @property
    def name(self) -> str:
        return "kalm"

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Generate SysML from natural language."""
        # Validate input
        if len(text) > MAX_INPUT_CHARS:
            raise HTTPException(
                status_code=400,
                detail=f"Input too long: {len(text)} chars, max {MAX_INPUT_CHARS}"
            )

        # Build prompt
        prompt = build_prompt(text)
        log.debug(f"Prompt length: {len(prompt)} chars")

        # Get model
        tokenizer, model, cached, load_ms = await model_manager.get_generator("gemma")

        # Generate
        gen_start = time.time()
        
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        input_len = inputs.input_ids.shape[1]

        outputs = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=True,
            temperature=0.2,
            top_p=0.95,
            pad_token_id=tokenizer.eos_token_id,
        )

        # Decode only new tokens
        new_tokens = outputs[0][input_len:]
        sysml = tokenizer.decode(new_tokens, skip_special_tokens=True).strip()

        gen_ms = int((time.time() - gen_start) * 1000)
        log.info(f"Generated {len(new_tokens)} tokens in {gen_ms}ms")

        # TODO: retrieval with KaLM embedding

        diagnostics = {
            "loaded_from_cache": cached,
            "model_load_ms": load_ms,
            "gen_ms": gen_ms,
        }

        return sysml, diagnostics
