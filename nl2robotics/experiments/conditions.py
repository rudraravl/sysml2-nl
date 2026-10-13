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

    # None preserves the historical B0-FULL and best-of-N constructor.
    compiler_repair: bool | None = None
    execution_repair: bool | None = None

    def __post_init__(self) -> None:
        for name in ("compiler_repair", "execution_repair"):
            if getattr(self, name) is None:
                object.__setattr__(self, name, self.tool_repair)
        if self.tool_repair != (self.compiler_repair or self.execution_repair):
            raise ValueError("tool_repair must agree with the two repair stages")

    def to_dict(self) -> dict:
        return asdict(self)


CONDITIONS = {
    item.id: item for item in (
        AblationCondition("B0", "direct_frontier", False, False, False, False, False),
        AblationCondition("B1", "rag", True, False, False, False, False),
        AblationCondition("B2", "rag_moe", True, True, False, False, False),
        AblationCondition("B3", "tool_grounded", True, True, True, False, True),
        AblationCondition("FULL", "complete_pipeline", True, True, True, True, True),
        AblationCondition("A0", "direct_frontier", False, False, False, False, False),
        AblationCondition("A1", "rag", True, False, False, False, False),
        AblationCondition("A2", "rag_moe", True, True, False, False, False),
        AblationCondition("A3", "rag_moe_compiler_repair", True, True, True,
                          False, False, compiler_repair=True, execution_repair=False),
        AblationCondition("A4", "rag_moe_compiler_execution_repair", True, True,
                          True, False, False, compiler_repair=True, execution_repair=True),
    )
}


GLM_ABLATION_CONDITIONS = ("A0", "A1", "A2", "A3", "A4")

def select_conditions(ids: list[str] | None = None) -> list[AblationCondition]:
    selected = ids or ["B0", "B1", "B2", "B3", "FULL"]
    unknown = [item for item in selected if item not in CONDITIONS]
    if unknown:
        raise ValueError(f"unknown ablation conditions: {unknown}")
    return [CONDITIONS[item] for item in selected]
