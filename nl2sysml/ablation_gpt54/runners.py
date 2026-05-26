"""Run ablation conditions A (baseline), B (RAG), C (MOE+compiler)."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Ensure nl2sysml is on path when run as script or -m from repo root
_NL2 = Path(__file__).resolve().parent.parent
if str(_NL2) not in sys.path:
    sys.path.insert(0, str(_NL2))

from config import (  # noqa: E402
    COMPILER_SYNTAX_ONLY,
    Condition,
    GPT_MODEL,
    RAG_K,
    REPO_ROOT,
)

from compiler_interface import check_code, is_compiler_available  # noqa: E402
from metrics import PromptMetrics, compiler_result_to_metrics  # noqa: E402

import agent_rag_moe as moe  # noqa: E402
from agent_rag_moe import (  # noqa: E402
    PROMPT_HUMAN_TEMPLATE,
    _collect_examples,
    _default_system_prompt,
    _invoke_with_retry,
    _load_env,
    _rag_context,
    _similarity,
    generate_sysml_moe,
)


def _rag_retrieval_stats(nl_prompt: str, root: Path) -> Tuple[int, List[float]]:
    """Count few-shot examples that would score > 0 (same rule as _rag_context)."""
    examples = _collect_examples(root)
    if not examples:
        return 0, []
    scored = sorted(
        (_similarity(nl_prompt, ex[0]) for ex in examples),
        reverse=True,
    )
    top_scores = [s for s in scored[:5] if s > 0]
    return len(top_scores), top_scores


def _run_gpt_single(
    description: str,
    *,
    use_rag: bool,
) -> Tuple[str, Dict[str, Any]]:
    _, openrouter_key = _load_env()
    if not openrouter_key:
        raise RuntimeError("OPENROUTER_API_KEY missing in environment/.env")

    sys_msg = _default_system_prompt(None)
    if use_rag:
        context = _rag_context(description, REPO_ROOT, k=RAG_K)
        ex_count, top_scores = _rag_retrieval_stats(description, REPO_ROOT)
    else:
        context = ""
        ex_count, top_scores = 0, []

    human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=description)
    code = _invoke_with_retry(GPT_MODEL, sys_msg, human_msg, openrouter_key)

    return code, {
        "retrieval_used": use_rag,
        "rag_example_count": ex_count,
        "rag_top_scores": top_scores,
        "context_length": len(context),
    }


def _run_moe_with_pre_refine_capture(description: str) -> Tuple[str, Dict[str, Any]]:
    """Call generate_sysml_moe; capture compiler state before refinement loop."""
    pre_snapshot: Dict[str, Any] = {}

    original_refine = moe._refine_with_compiler

    def capturing_refine(code: str, *args, **kwargs):
        pre_result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
        pre_snapshot["valid_before_refinement"] = pre_result.is_valid
        pre_snapshot["errors_before_refinement"] = pre_result.error_count
        pre_snapshot["pre_refine_code_length"] = len(code or "")
        return original_refine(code, *args, **kwargs)

    moe._refine_with_compiler = capturing_refine
    try:
        code, record = generate_sysml_moe(description)
    finally:
        moe._refine_with_compiler = original_refine

    return code, {
        "retrieval_used": True,
        "prompt_record": record,
        "refinement_iterations": moe.MAX_REFINEMENT_ITERATIONS,
        "valid_before_refinement": pre_snapshot.get("valid_before_refinement"),
        "errors_before_refinement": pre_snapshot.get("errors_before_refinement"),
    }


def run_condition(
    condition: Condition,
    prompt_id: str,
    description: str,
) -> Tuple[str, PromptMetrics]:
    if condition == Condition.BASELINE:
        code, meta = _run_gpt_single(description, use_rag=False)
        result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
        pm = compiler_result_to_metrics(
            prompt_id,
            condition,
            description,
            code,
            result,
            model=GPT_MODEL,
            retrieval_used=False,
        )
        return code, pm

    if condition == Condition.RAG:
        code, meta = _run_gpt_single(description, use_rag=True)
        result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
        pm = compiler_result_to_metrics(
            prompt_id,
            condition,
            description,
            code,
            result,
            model=GPT_MODEL,
            retrieval_used=True,
            rag_example_count=meta.get("rag_example_count", 0),
            rag_top_scores=meta.get("rag_top_scores", []),
        )
        return code, pm

    if condition == Condition.MOE:
        code, meta = _run_moe_with_pre_refine_capture(description)
        result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
        pm = compiler_result_to_metrics(
            prompt_id,
            condition,
            description,
            code,
            result,
            model=f"MOE ({', '.join(moe.EXPERT_MODELS)}) + {moe.COMBINER_MODEL}",
            retrieval_used=True,
            refinement_iterations=meta.get("refinement_iterations", 0),
            errors_before_refinement=meta.get("errors_before_refinement"),
            valid_before_refinement=meta.get("valid_before_refinement"),
        )
        pm.extra["_prompt_record"] = meta.get("prompt_record")
        return code, pm

    raise ValueError(f"Unknown condition: {condition}")


def save_prompt_output(
    out_dir: Path,
    prompt_id: str,
    description: str,
    code: str,
    metrics: PromptMetrics,
    *,
    prompt_record: Optional[Dict[str, Any]] = None,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    pid = prompt_id.upper()
    sysml_path = out_dir / f"{pid}.sysml"
    sysml_path.write_text(f"// {description}\n{code}\n", encoding="utf-8")

    meta_path = out_dir / f"{pid}_meta.json"
    meta_path.write_text(
        json.dumps(metrics.to_dict(), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    if prompt_record is not None:
        record_path = out_dir / f"{pid}_prompt_record.json"
        record_path.write_text(
            json.dumps(prompt_record, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )


def require_compiler() -> None:
    if not is_compiler_available():
        raise RuntimeError(
            "SysML compiler is not available. Build sysml2-compiler and set "
            "SYSML_COMPILER_JAR_PATH / SYSML_COMPILER_LIBRARY_PATH. "
            "See nl2sysml/COMPILER_FEEDBACK.md and sysml2-compiler/README.md."
        )
