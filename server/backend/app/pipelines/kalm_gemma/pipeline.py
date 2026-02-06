"""KaLM-Gemma pipeline implementation.

USAGE RULES:
- Generator (Gemma): Only for model.generate(), use apply_chat_template
- Encoder (KaLM): Only for embedding/retrieval (TODO), never generate()
- Decode only new tokens: gen_ids = out[0, prompt_len:]
- Never mix tokenizers from different checkpoints
"""

import time
from fastapi import HTTPException

from app.pipelines.base import BasePipeline
from app.pipelines.kalm_gemma.prompt import SYSTEM_PROMPT
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

        # Get generator (Gemma) - only for generation
        tokenizer, model, cached, load_ms = await model_manager.get_generator()

        # Build prompt using chat template (proper way for chat models)
        messages = [
            {"role": "user", "content": f"{SYSTEM_PROMPT}\n\nNatural Language Description:\n{text}\n\nSysML v2 Code:"}
        ]
        
        # Use apply_chat_template - proper way for instruction-tuned models
        prompt = tokenizer.apply_chat_template(
            messages, 
            tokenize=False, 
            add_generation_prompt=True
        )
        log.debug(f"Prompt length: {len(prompt)} chars")

        # Tokenize
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        prompt_len = inputs.input_ids.shape[1]

        # Generate
        gen_start = time.time()
        
        outputs = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=True,
            temperature=0.2,
            top_p=0.95,
            pad_token_id=tokenizer.eos_token_id,
        )

        # Decode only new tokens (critical: truncate prompt)
        gen_ids = outputs[0, prompt_len:]
        sysml = tokenizer.decode(gen_ids, skip_special_tokens=True).strip()

        gen_ms = int((time.time() - gen_start) * 1000)
        log.info(f"Generated {len(gen_ids)} tokens in {gen_ms}ms")

        # TODO: retrieval with KaLM embedding
        # encoder_tokenizer, encoder_model, _, _ = await model_manager.get_encoder()
        # embedding = encode(text, encoder_tokenizer, encoder_model)
        # similar_examples = faiss_search(embedding)

        diagnostics = {
            "loaded_from_cache": cached,
            "model_load_ms": load_ms,
            "gen_ms": gen_ms,
        }

        return sysml, diagnostics
