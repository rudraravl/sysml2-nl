"""SysML-equivalent rated mixture of experts for OpenUSD generation."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Optional

from nl2robotics.modelica import moe as shared_moe
from spec_aligner.llm import CliUsageLimitError

from .pipeline import OpenUSDPipeline, SYSTEM_PROMPT, clean_usda


EXPERT_MODELS = tuple(shared_moe.EXPERT_MODELS)
COMBINER_MODEL = shared_moe.COMBINER_MODEL
EXPERT_MODELS_RATING = dict(shared_moe.EXPERT_MODELS_RATING)
Invoke = Callable[[str, str, str, Optional[str]], str]


def generate_openusd_moe(
    requirement: str,
    *,
    pipeline: OpenUSDPipeline | None = None,
    k: int = 5,
    max_repairs: int = 2,
    output_dir: Path | None = None,
    invoke: Invoke | None = None,
    openrouter_key: str | None = None,
) -> tuple[str, dict]:
    if not requirement.strip():
        raise ValueError("requirement must be non-empty")
    pipeline = pipeline or OpenUSDPipeline()
    backend = shared_moe.sysml_moe._llm_backend()
    if invoke is None:
        _, openrouter_key = shared_moe.sysml_moe._load_env()
        invoke = shared_moe._invoke

    system, human, hits = pipeline.build_messages(requirement, k=k)
    candidates = []
    soft_fails = []
    for model in EXPERT_MODELS:
        try:
            candidates.append((model, clean_usda(
                invoke(model, system, human, openrouter_key)
            )))
        except CliUsageLimitError:
            raise
        except Exception as exc:
            soft_fails.append({"model": model, "error": str(exc)})
    blocks = []
    for index, (model, code) in enumerate(candidates, 1):
        group = shared_moe.sysml_moe._model_group(model)
        rating = EXPERT_MODELS_RATING.get(group, 5)
        blocks.append(
            f"Candidate {index} ({model}, rating={rating}/10):\n{code}\n---"
        )
    combine_human = human
    if blocks:
        combine_human += "\n\nCandidate stages:\n" + "\n".join(blocks)
    combine_system = (
        SYSTEM_PROMPT
        + "\nSynthesize one best stage from the candidates. Preserve grounded "
          "requirements and valid schema relationships; do not concatenate stages."
    )
    combined = clean_usda(invoke(
        COMBINER_MODEL, combine_system, combine_human, openrouter_key
    ))

    def repair(prompt: str) -> str:
        return invoke(COMBINER_MODEL, SYSTEM_PROMPT, prompt, openrouter_key)

    report = pipeline.refine(
        requirement, combined, repair, hits=hits,
        max_repairs=max_repairs, output_dir=output_dir,
    )
    return report["final_openusd"], {
        **report,
        "generation_mode": "moe",
        "llm_backend": backend,
        "expert_models": list(EXPERT_MODELS),
        "expert_ratings": {
            model: EXPERT_MODELS_RATING.get(
                shared_moe.sysml_moe._model_group(model), 5
            ) for model in EXPERT_MODELS
        },
        "combiner_model": COMBINER_MODEL,
        "expert_candidates": [model for model, _ in candidates],
        "expert_candidate_outputs": {model: code for model, code in candidates},
        "expert_soft_fails": soft_fails,
        "expert_soft_fail_count": len(soft_fails),
        "expert_prompt": f"System:\n{system}\n\nHuman:\n{human}",
        "combine_prompt": f"System:\n{combine_system}\n\nHuman:\n{combine_human}",
    }
