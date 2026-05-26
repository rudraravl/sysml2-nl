"""Compiler-based metrics for ablation outputs."""

from __future__ import annotations

import json
import statistics
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from config import Condition, CONDITION_ORDER, RESULTS_ROOT


@dataclass
class PromptMetrics:
    prompt_id: str
    condition: str
    description: str
    is_valid: bool
    error_count: int
    syntax_error_count: int
    semantic_error_count: int
    empty_output: bool
    model: str
    retrieval_used: bool
    refinement_iterations: int = 0
    errors_before_refinement: Optional[int] = None
    valid_before_refinement: Optional[bool] = None
    rag_example_count: int = 0
    rag_top_scores: List[float] = field(default_factory=list)
    errors: List[Dict[str, Any]] = field(default_factory=list)
    extra: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


def compiler_result_to_metrics(
    prompt_id: str,
    condition: Condition,
    description: str,
    code: str,
    result: Any,
    *,
    model: str,
    retrieval_used: bool,
    refinement_iterations: int = 0,
    errors_before_refinement: Optional[int] = None,
    valid_before_refinement: Optional[bool] = None,
    rag_example_count: int = 0,
    rag_top_scores: Optional[List[float]] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> PromptMetrics:
    errors = getattr(result, "errors", []) or []
    syntax_count = sum(1 for e in errors if e.is_syntax_error())
    semantic_count = sum(1 for e in errors if e.is_semantic_error())
    return PromptMetrics(
        prompt_id=prompt_id,
        condition=condition.value,
        description=description,
        is_valid=getattr(result, "is_valid", False),
        error_count=len(errors),
        syntax_error_count=syntax_count,
        semantic_error_count=semantic_count,
        empty_output=not (code or "").strip(),
        model=model,
        retrieval_used=retrieval_used,
        refinement_iterations=refinement_iterations,
        errors_before_refinement=errors_before_refinement,
        valid_before_refinement=valid_before_refinement,
        rag_example_count=rag_example_count,
        rag_top_scores=rag_top_scores or [],
        errors=[
            {
                "line": e.line,
                "column": e.column,
                "message": e.message,
                "severity": e.severity,
                "code": e.code,
            }
            for e in errors
        ],
        extra=extra or {},
    )


@dataclass
class CorpusMetrics:
    condition: str
    label: str
    n_prompts: int
    valid_rate: float
    mean_errors: float
    median_errors: float
    syntax_failure_rate: float
    semantic_failure_rate: float
    empty_output_rate: float
    mean_errors_before_refinement: Optional[float] = None
    refinement_gain: Optional[float] = None
    fixed_by_refinement_rate: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


def _load_prompt_metrics(condition_dir: Path) -> List[PromptMetrics]:
    fields = PromptMetrics.__dataclass_fields__
    rows: List[PromptMetrics] = []
    for meta_path in sorted(condition_dir.glob("*_meta.json")):
        data = json.loads(meta_path.read_text(encoding="utf-8"))
        filtered = {k: data[k] for k in fields if k in data}
        rows.append(PromptMetrics(**filtered))
    return rows


def aggregate_corpus(rows: List[PromptMetrics], condition: Condition) -> CorpusMetrics:
    n = len(rows) or 1
    valid_count = sum(1 for r in rows if r.is_valid)
    syntax_fail = sum(1 for r in rows if r.syntax_error_count > 0)
    semantic_fail = sum(1 for r in rows if r.semantic_error_count > 0)
    empty_count = sum(1 for r in rows if r.empty_output)
    errors = [r.error_count for r in rows]

    mean_before = None
    refinement_gain = None
    fixed_rate = None
    if condition == Condition.MOE:
        before_vals = [
            r.errors_before_refinement
            for r in rows
            if r.errors_before_refinement is not None
        ]
        if before_vals:
            mean_before = statistics.mean(before_vals)
            refinement_gain = mean_before - statistics.mean(errors)
            fixed = sum(
                1
                for r in rows
                if r.valid_before_refinement is False and r.is_valid is True
            )
            invalid_before = sum(
                1 for r in rows if r.valid_before_refinement is False
            )
            fixed_rate = (fixed / invalid_before * 100) if invalid_before else 0.0

    return CorpusMetrics(
        condition=condition.value,
        label=condition.label,
        n_prompts=len(rows),
        valid_rate=valid_count / n * 100,
        mean_errors=statistics.mean(errors) if errors else 0.0,
        median_errors=statistics.median(errors) if errors else 0.0,
        syntax_failure_rate=syntax_fail / n * 100,
        semantic_failure_rate=semantic_fail / n * 100,
        empty_output_rate=empty_count / n * 100,
        mean_errors_before_refinement=mean_before,
        refinement_gain=refinement_gain,
        fixed_by_refinement_rate=fixed_rate,
    )


def pairwise_deltas(
    summaries: Dict[str, CorpusMetrics],
) -> Dict[str, Dict[str, float]]:
    keys = [c.value for c in CONDITION_ORDER]
    out: Dict[str, Dict[str, float]] = {}
    pairs = [("rag", "baseline"), ("moe", "rag"), ("moe", "baseline")]
    for a, b in pairs:
        if a not in summaries or b not in summaries:
            continue
        sa, sb = summaries[a], summaries[b]
        out[f"{a}_minus_{b}"] = {
            "delta_valid_rate_pp": sa.valid_rate - sb.valid_rate,
            "delta_mean_errors": sa.mean_errors - sb.mean_errors,
        }
    return out


def build_summary(
    results_root: Path = RESULTS_ROOT,
) -> Dict[str, Any]:
    per_condition: Dict[str, Any] = {}
    summaries: Dict[str, CorpusMetrics] = {}

    for cond in CONDITION_ORDER:
        cond_dir = results_root / cond.output_dir_name
        if not cond_dir.exists():
            continue
        rows = _load_prompt_metrics(cond_dir)
        corpus = aggregate_corpus(rows, cond)
        summaries[cond.value] = corpus
        per_condition[cond.value] = {
            "corpus": corpus.to_dict(),
            "prompts": [r.to_dict() for r in rows],
        }

    delta = pairwise_deltas(summaries)
    return {
        "conditions": {k: v.to_dict() for k, v in summaries.items()},
        "pairwise_deltas": delta,
        "per_condition": per_condition,
    }


def write_summary_files(
    summary: Dict[str, Any],
    results_root: Path = RESULTS_ROOT,
) -> None:
    results_root.mkdir(parents=True, exist_ok=True)
    json_path = results_root / "summary.json"
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# GPT-5.4 Ablation Summary",
        "",
        "| Condition | Valid % | Mean errors | Median errors | Syntax fail % | Semantic fail % | Empty % |",
        "|-----------|---------|---------------|---------------|---------------|-----------------|---------|",
    ]
    for cond in CONDITION_ORDER:
        c = summary.get("conditions", {}).get(cond.value)
        if not c:
            continue
        lines.append(
            f"| {cond.label} | {c['valid_rate']:.1f} | {c['mean_errors']:.2f} | "
            f"{c['median_errors']:.1f} | {c['syntax_failure_rate']:.1f} | "
            f"{c['semantic_failure_rate']:.1f} | {c['empty_output_rate']:.1f} |"
        )

    moe = summary.get("conditions", {}).get(Condition.MOE.value)
    if moe and moe.get("refinement_gain") is not None:
        lines.extend(
            [
                "",
                "## MOE compiler refinement (condition C)",
                "",
                f"- Mean errors before refinement: {moe.get('mean_errors_before_refinement', 'n/a')}",
                f"- Refinement gain (mean error reduction): {moe.get('refinement_gain', 'n/a')}",
                f"- Fixed-by-refinement rate: {moe.get('fixed_by_refinement_rate', 'n/a')}%",
            ]
        )

    deltas = summary.get("pairwise_deltas", {})
    if deltas:
        lines.extend(["", "## Pairwise deltas", ""])
        for name, d in deltas.items():
            lines.append(
                f"- **{name}**: Δ valid rate {d['delta_valid_rate_pp']:+.1f} pp, "
                f"Δ mean errors {d['delta_mean_errors']:+.2f}"
            )

    md_path = results_root / "summary.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
