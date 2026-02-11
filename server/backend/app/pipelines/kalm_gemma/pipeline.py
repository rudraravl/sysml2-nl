"""KaLM-Gemma pipeline implementation.

USAGE RULES:
- Generator (Gemma): Only for model.generate(), use apply_chat_template
- Encoder (KaLM): Only for embedding/retrieval, never generate()
- Decode only new tokens: gen_ids = out[0, prompt_len:]
- Never mix tokenizers from different checkpoints
- Embedding conditioning: KaLM embedding is prepended as conditioning tokens
"""

import time
import torch
from fastapi import HTTPException

from app.pipelines.base import BasePipeline
from app.pipelines.kalm_gemma.prompt import SYSTEM_PROMPT, EMBEDDING_CONDITIONED_PROMPT
from app.runtime.resources import model_manager
from app.core.config import MAX_INPUT_CHARS
from app.core.logging import get_logger

log = get_logger(__name__)


def mean_pooling(hidden_states: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
    """
    Mean pooling over token embeddings, weighted by attention mask.
    
    Args:
        hidden_states: (batch, seq_len, hidden_dim) tensor of token embeddings
        attention_mask: (batch, seq_len) tensor indicating valid tokens
        
    Returns:
        (batch, hidden_dim) tensor of pooled embeddings
    """
    # Expand attention mask to match hidden states shape
    mask_expanded = attention_mask.unsqueeze(-1).expand(hidden_states.size()).float()
    # Sum embeddings weighted by mask
    sum_embeddings = torch.sum(hidden_states * mask_expanded, dim=1)
    # Divide by number of valid tokens (avoid division by zero)
    sum_mask = torch.clamp(mask_expanded.sum(dim=1), min=1e-9)
    return sum_embeddings / sum_mask


class KaLMGemmaPipeline(BasePipeline):
    """Pipeline using KaLM for embedding and Gemma for SysML generation."""

    @property
    def name(self) -> str:
        return "kalm"

    async def _generate_embedding(self, text: str) -> tuple[torch.Tensor, bool, int, list[str]]:
        """
        Generate embedding for input text using KaLM encoder.
        
        Args:
            text: Input text to encode
            
        Returns:
            (embedding, loaded_from_cache, load_ms, evicted_models)
        """
        enc_tokenizer, enc_model, enc_cached, enc_load_ms, enc_evicted = await model_manager.get_encoder()
        
        # Tokenize input for encoder
        inputs = enc_tokenizer(
            text, 
            return_tensors="pt", 
            padding=True, 
            truncation=True,
            max_length=8192  # KaLM supports long context
        ).to(enc_model.device)
        
        # Generate embedding (no gradient needed for inference)
        with torch.no_grad():
            outputs = enc_model(**inputs)
            # Use mean pooling over last hidden states
            embedding = mean_pooling(outputs.last_hidden_state, inputs.attention_mask)
            # L2 normalize for cosine similarity compatibility
            embedding = torch.nn.functional.normalize(embedding, p=2, dim=1)
        
        return embedding, enc_cached, enc_load_ms, enc_evicted

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Generate SysML from natural language using embedding-conditioned generation.
        
        The KaLM embedding captures the semantic meaning of the input text and is
        prepended to the prompt embeddings as conditioning tokens for generation.
        """
        # Validate input
        if len(text) > MAX_INPUT_CHARS:
            raise HTTPException(
                status_code=400,
                detail=f"Input too long: {len(text)} chars, max {MAX_INPUT_CHARS}"
            )

        # Step 1: Generate semantic embedding using KaLM encoder
        log.info("Generating semantic embedding with KaLM encoder...")
        emb_start = time.time()
        embedding, enc_cached, enc_load_ms, enc_evicted = await self._generate_embedding(text)
        emb_ms = int((time.time() - emb_start) * 1000)
        log.info(f"Embedding generated: shape={embedding.shape}, dim={embedding.shape[-1]}, time={emb_ms}ms")

        # Step 2: Get generator (Gemma) for text generation
        gen_tokenizer, gen_model, gen_cached, gen_load_ms, gen_evicted = await model_manager.get_generator()

        # Build prompt using chat template - no raw text, only embedding conditioning
        messages = [
            {"role": "user", "content": EMBEDDING_CONDITIONED_PROMPT}
        ]
        
        # Use apply_chat_template - proper way for instruction-tuned models
        prompt = gen_tokenizer.apply_chat_template(
            messages, 
            tokenize=False, 
            add_generation_prompt=True
        )
        log.debug(f"Prompt length: {len(prompt)} chars")

        # Get prompt token embeddings
        inputs = gen_tokenizer(prompt, return_tensors="pt").to(gen_model.device)
        prompt_embeds = gen_model.get_input_embeddings()(inputs.input_ids)
        
        # Prepare conditioning embedding from KaLM
        # embedding shape: (1, hidden_dim) -> (1, num_cond_tokens, hidden_dim)
        # We can expand the embedding to multiple conditioning tokens for stronger signal
        num_cond_tokens = 4  # Use 4 conditioning tokens
        cond_embeds = embedding.unsqueeze(1).expand(-1, num_cond_tokens, -1)
        cond_embeds = cond_embeds.to(prompt_embeds.dtype)  # Match dtype
        
        # Concatenate: [conditioning_tokens] + [prompt_tokens]
        combined_embeds = torch.cat([cond_embeds, prompt_embeds], dim=1)
        total_prefix_len = combined_embeds.shape[1]
        
        log.debug(f"Conditioning: {num_cond_tokens} tokens, prompt: {prompt_embeds.shape[1]} tokens")

        # Generate SysML using embedding-conditioned input
        gen_start = time.time()
        
        # Create attention mask for combined embeddings
        attention_mask = torch.ones(combined_embeds.shape[:2], dtype=torch.long, device=combined_embeds.device)
        
        outputs = gen_model.generate(
            inputs_embeds=combined_embeds,
            attention_mask=attention_mask,
            max_new_tokens=max_new_tokens,
            do_sample=True,
            temperature=0.2,
            top_p=0.95,
            pad_token_id=gen_tokenizer.eos_token_id,
        )

        # Decode only new tokens (skip the prefix length)
        gen_ids = outputs[0, total_prefix_len:]
        sysml = gen_tokenizer.decode(gen_ids, skip_special_tokens=True).strip()

        gen_ms = int((time.time() - gen_start) * 1000)
        log.info(f"Generated {len(gen_ids)} tokens in {gen_ms}ms")

        # Combine evicted models from both encoder and generator
        all_evicted = enc_evicted + gen_evicted

        # Diagnostics include both encoder and generator info
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
