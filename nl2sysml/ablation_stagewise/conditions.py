"""Scientific condition definitions for the cumulative SysML ablation."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class Condition:
    id: str
    label: str
    rag: bool
    moe: bool
    compiler_feedback: bool
    execution_feedback: bool

    def to_dict(self) -> dict:
        return asdict(self)


# A0 (one-shot GLM-5.2) is existing evidence and is intentionally not launched
# by this package. Every new condition is cumulative and changes one component.
CONDITIONS = {
    item.id: item for item in (
        Condition("A1", "GLM-5.2 + RAG", True, False, False, False),
        Condition("A2", "RAG + MoE", True, True, False, False),
        Condition("A3", "A2 + compiler-guided repair", True, True, True, False),
        Condition("A4", "A3 + execution-guided repair", True, True, True, True),
    )
}


def get_condition(condition_id: str) -> Condition:
    try:
        return CONDITIONS[condition_id.upper()]
    except KeyError as exc:
        raise ValueError(
            f"unknown condition {condition_id!r}; choose one of {list(CONDITIONS)}"
        ) from exc
