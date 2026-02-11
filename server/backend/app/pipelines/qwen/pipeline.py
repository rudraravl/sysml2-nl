"""Qwen3 pipeline implementation.

Uses Qwen3-Embedding-8B for semantic encoding and Qwen3-8B for generation.
The embedding is used as conditioning input prepended to the prompt embeddings.
"""

import time
import torch
from fastapi import HTTPException

from app.pipelines.base import BasePipeline
from app.runtime.resources import model_manager
from app.core.config import MAX_INPUT_CHARS
from app.core.logging import get_logger

log = get_logger(__name__)

# Prompt for embedding-conditioned generation
EMBEDDING_CONDITIONED_PROMPT = """You are a SysML v2 expert. A semantic embedding representing a system description has been provided as context.
Based on the semantic understanding from the embedding, generate the corresponding SysML v2 code.

Rules:
- Output ONLY valid SysML v2 code
- No markdown code fences (no ```)
- No explanations or comments outside the code
- Use proper SysML v2 syntax with packages, parts, ports, connections
- Keep the code minimal and focused on the described system

SysML v2 Code:"""


def last_token_pooling(hidden_states: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
    """
    Last token pooling for Qwen embeddings.
    Gets the hidden state of the last non-padding token.
    """
    # Get the position of the last token for each sequence
    sequence_lengths = attention_mask.sum(dim=1) - 1
    batch_size = hidden_states.shape[0]
    
    # Gather the last token hidden states
    last_hidden = hidden_states[torch.arange(batch_size, device=hidden_states.device), sequence_lengths]
    return last_hidden


class QwenPipeline(BasePipeline):
    """Pipeline using Qwen3-Embedding-8B + Qwen3-8B with embedding conditioning."""

    @property
    def name(self) -> str:
        return "qwen"

    async def _generate_embedding(self, text: str) -> tuple[torch.Tensor, bool, int, list[str]]:
        """
        Generate embedding for input text using Qwen3-Embedding-8B.
        
        Returns:
            (embedding, loaded_from_cache, load_ms, evicted_models)
        """
        enc_tokenizer, enc_model, enc_cached, enc_load_ms, enc_evicted = await model_manager.get_qwen_encoder()
        
        # Tokenize input for encoder
        inputs = enc_tokenizer(
            text, 
            return_tensors="pt", 
            padding=True, 
            truncation=True,
            max_length=8192
        ).to(enc_model.device)
        
        # Generate embedding
        with torch.no_grad():
            outputs = enc_model(**inputs)
            # Use last token pooling (standard for Qwen embeddings)
            embedding = last_token_pooling(outputs.last_hidden_state, inputs.attention_mask)
            # L2 normalize
            embedding = torch.nn.functional.normalize(embedding, p=2, dim=1)
        
        return embedding, enc_cached, enc_load_ms, enc_evicted

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Generate SysML from natural language using embedding-conditioned generation."""
        # Validate input
        if len(text) > MAX_INPUT_CHARS:
            raise HTTPException(
                status_code=400,
                detail=f"Input too long: {len(text)} chars, max {MAX_INPUT_CHARS}"
            )

        # Step 1: Generate semantic embedding using Qwen encoder
        log.info("Generating semantic embedding with Qwen3-Embedding-8B...")
        emb_start = time.time()
        embedding, enc_cached, enc_load_ms, enc_evicted = await self._generate_embedding(text)
        emb_ms = int((time.time() - emb_start) * 1000)
        log.info(f"Embedding generated: shape={embedding.shape}, dim={embedding.shape[-1]}, time={emb_ms}ms")

        # Step 2: Get Qwen generator
        gen_tokenizer, gen_model, gen_cached, gen_load_ms, gen_evicted = await model_manager.get_qwen_generator()

        # Build prompt using chat template
        messages = [
            {"role": "system", "content": EMBEDDING_CONDITIONED_PROMPT},
        ]
        
        prompt = gen_tokenizer.apply_chat_template(
            messages, 
            tokenize=False, 
            add_generation_prompt=True
        )
        log.debug(f"Prompt length: {len(prompt)} chars")

        # Get prompt token embeddings
        inputs = gen_tokenizer(prompt, return_tensors="pt").to(gen_model.device)
        prompt_embeds = gen_model.get_input_embeddings()(inputs.input_ids)
        
        # Prepare conditioning embedding
        # embedding shape: (1, hidden_dim) -> (1, num_cond_tokens, hidden_dim)
        num_cond_tokens = 4  # Use 4 conditioning tokens
        cond_embeds = embedding.unsqueeze(1).expand(-1, num_cond_tokens, -1)
        cond_embeds = cond_embeds.to(prompt_embeds.dtype)
        
        # Concatenate: [conditioning_tokens] + [prompt_tokens]
        combined_embeds = torch.cat([cond_embeds, prompt_embeds], dim=1)
        total_prefix_len = combined_embeds.shape[1]
        
        log.debug(f"Conditioning: {num_cond_tokens} tokens, prompt: {prompt_embeds.shape[1]} tokens")

        # Generate SysML using embedding-conditioned input
        gen_start = time.time()
        
        attention_mask = torch.ones(combined_embeds.shape[:2], dtype=torch.long, device=combined_embeds.device)
        
        with torch.no_grad():
            outputs = gen_model.generate(
                inputs_embeds=combined_embeds,
                attention_mask=attention_mask,
                max_new_tokens=max_new_tokens,
                do_sample=True,
                temperature=0.7,
                top_p=0.8,
                top_k=20,
                pad_token_id=gen_tokenizer.eos_token_id,
            )

        # Decode only new tokens (skip the prefix length)
        gen_ids = outputs[0, total_prefix_len:]
        sysml = gen_tokenizer.decode(gen_ids, skip_special_tokens=True).strip()

        gen_ms = int((time.time() - gen_start) * 1000)
        log.info(f"Generated {len(gen_ids)} tokens in {gen_ms}ms")

        # Combine evicted models
        all_evicted = enc_evicted + gen_evicted

        # Diagnostics
        diagnostics = {
            "encoder_loaded_from_cache": enc_cached,
            "encoder_load_ms": enc_load_ms,
            "embedding_ms": emb_ms,
            "embedding_dim": embedding.shape[-1],
            "num_cond_tokens": num_cond_tokens,
            "generator_loaded_from_cache": gen_cached,
            "generator_load_ms": gen_load_ms,
            "gen_ms": gen_ms,
            "evicted_models": all_evicted,
        }

        return sysml, diagnostics
