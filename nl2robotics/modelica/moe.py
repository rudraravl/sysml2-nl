"""Modelica adaptation of the SysML mixture-of-experts generation stage."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Optional

from nl2sysml import agent_rag_moe as sysml_moe
from spec_aligner.llm import CliUsageLimitError

from .pipeline import ModelicaPipeline, SYSTEM_PROMPT, clean_code


# Keep these aliases tied to the SysML experiment configuration for parity.
EXPERT_MODELS = tuple(sysml_moe.EXPERT_MODELS)
COMBINER_MODEL = sysml_moe.COMBINER_MODEL
EXPERT_MODELS_RATING = dict(sysml_moe.EXPERT_MODELS_RATING)

Invoke = Callable[[str, str, str, Optional[str]], str]


def generate_modelica_moe(
    requirement: str,
    *,
    pipeline: ModelicaPipeline | None = None,
    k: int = 5,
    max_repairs: int = 2,
    output_dir: Path | None = None,
    preferred_categories: tuple[str, ...] = (),
    invoke: Invoke | None = None,
    openrouter_key: str | None = None,
) -> tuple[str, dict]:
    """Run the SysML-equivalent MoE and compile-only Layer 1 feedback."""
    if not requirement.strip():
        raise ValueError("requirement must be non-empty")
    pipeline = pipeline or ModelicaPipeline()
    backend = sysml_moe._llm_backend()
    if invoke is None:
        _, openrouter_key = sysml_moe._load_env()
        invoke = _invoke

    system, human, hits = pipeline.build_messages(
        requirement, k=k, preferred_categories=preferred_categories
    )
    candidates: list[tuple[str, str]] = []
    soft_fails = []
    for model in EXPERT_MODELS:
        try:
            response = clean_code(invoke(model, system, human, openrouter_key))
            candidates.append((model, response))
        except CliUsageLimitError:
            raise
        except Exception as exc:
            soft_fails.append({"model": model, "error": str(exc)})

    combine_system = (
        SYSTEM_PROMPT
        + "\nSynthesize a single best model by merging or selecting from the "
          "candidate models. Preserve correct equations and satisfy every "
          "grounded requirement; do not concatenate top-level models."
    )
    candidate_block = _candidate_block(candidates)
    if candidate_block:
        combine_human = (
            f"{human}\n\nCandidate models from the experts:\n{candidate_block}"
        )
    else:
        combine_human = human
    combined = clean_code(
        invoke(COMBINER_MODEL, combine_system, combine_human, openrouter_key)
    )

    def repair(prompt: str) -> str:
        return invoke(COMBINER_MODEL, SYSTEM_PROMPT, prompt, openrouter_key)

    report = pipeline.refine_layer1(
        requirement,
        combined,
        repair,
        hits=hits,
        max_repairs=max_repairs,
        output_dir=output_dir,
    )
    record = {
        **report,
        "generation_mode": "moe",
        "retrieval_route": list(preferred_categories),
        "llm_backend": backend,
        "expert_models": list(EXPERT_MODELS),
        "expert_ratings": {
            model: EXPERT_MODELS_RATING.get(sysml_moe._model_group(model), 5)
            for model in EXPERT_MODELS
        },
        "combiner_model": COMBINER_MODEL,
        "expert_candidates": [model for model, _ in candidates],
        "expert_candidate_outputs": {
            model: code for model, code in candidates
        },
        "expert_soft_fails": soft_fails,
        "expert_soft_fail_count": len(soft_fails),
        "expert_prompt": f"System:\n{system}\n\nHuman:\n{human}",
        "combine_prompt": (
            f"System:\n{combine_system}\n\nHuman:\n{combine_human}"
        ),
    }
    return report["final_modelica"], record


def _candidate_block(candidates: list[tuple[str, str]]) -> str:
    blocks = []
    for index, (model, code) in enumerate(candidates, 1):
        group = sysml_moe._model_group(model)
        rating = EXPERT_MODELS_RATING.get(group, 5)
        blocks.append(
            f"Candidate {index} ({model}, rating={rating}/10):\n{code}\n---"
        )
    return "\n".join(blocks)


def _invoke(model: str, system: str, human: str,
            openrouter_key: str | None) -> str:
    """Use the exact provider routing and transport selected by the SysML MoE."""
    if sysml_moe._model_uses_cli(model):
        return sysml_moe._cli_invoke(model, system, human, mode="text")
    if model == "gemini-2.5-pro" or model.lower().startswith("gemini"):
        return sysml_moe._gemini_invoke(system, human)
    if not openrouter_key:
        raise RuntimeError(f"OPENROUTER_API_KEY missing for model {model}")
    return sysml_moe._openrouter_invoke(model, system, human, openrouter_key)


def routing() -> dict:
    """Return the active routes without making model calls."""
    routes = {}
    for model in (*EXPERT_MODELS, COMBINER_MODEL):
        if sysml_moe._model_uses_cli(model):
            from spec_aligner.llm import provider_for_model

            routes[model] = provider_for_model(model)
        else:
            routes[model] = "openrouter" if "gemini" not in model.lower() else "gemini"
    return {"backend": sysml_moe._llm_backend(), "routes": routes}
