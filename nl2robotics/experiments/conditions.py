"""Frozen, interpretable ablation conditions from the research design."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class AblationCondition:
    id: str
    label: str
    rag: bool
    moe: bool
    tool_repair: bool
    alignment: bool
    validated_contract: bool

    def to_dict(self) -> dict:
        return asdict(self)


CONDITIONS = {
    item.id: item for item in (
        AblationCondition("B0", "direct_frontier", False, False, False, False, False),
        AblationCondition("B1", "rag", True, False, False, False, False),
        AblationCondition("B2", "rag_moe", True, True, False, False, False),
        AblationCondition("B3", "tool_grounded", True, True, True, False, True),
        AblationCondition("FULL", "complete_pipeline", True, True, True, True, True),
    )
}


def select_conditions(ids: list[str] | None = None) -> list[AblationCondition]:
    selected = ids or list(CONDITIONS)
    unknown = [item for item in selected if item not in CONDITIONS]
    if unknown:
        raise ValueError(f"unknown ablation conditions: {unknown}")
    return [CONDITIONS[item] for item in selected]
