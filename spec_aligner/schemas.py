from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal

SpecKind = Literal[
    "entity",
    "attribute",
    "relation",
    "port",
    "connection",
    "requirement",
    "constraint",
    "behavior",
]

MismatchClass = Literal[
    "missing_in_model",
    "extra_in_model",
    "semantic_conflict",
    "naming_or_type_mismatch",
    "granularity_mismatch",
    "ambiguous_requirement",
    "parse_or_extraction_uncertain",
]

Severity = Literal["high", "medium", "low"]


@dataclass
class SourceEvidence:
    modality: Literal["natural_language", "sysml"]
    span: str
    line_start: int | None = None
    line_end: int | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SourceEvidence":
        return cls(**data)


@dataclass
class SpecItem:
    id: str
    kind: SpecKind
    name: str
    subject: str | None = None
    predicate: str | None = None
    property: str | None = None
    operator: str | None = None
    value: float | str | None = None
    unit: str | None = None
    related_entities: list[str] = field(default_factory=list)
    source: SourceEvidence | None = None
    confidence: float = 1.0
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SpecItem":
        data = dict(data)
        if data.get("source"):
            data["source"] = SourceEvidence.from_dict(data["source"])
        return cls(**data)


@dataclass
class SpecDocument:
    modality: Literal["natural_language", "sysml"]
    specs: list[SpecItem] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SpecDocument":
        data = dict(data)
        data["specs"] = [SpecItem.from_dict(item) for item in data.get("specs", [])]
        return cls(**data)


@dataclass
class AlignmentPair:
    nl_spec_id: str
    sysml_spec_id: str
    score: float
    confidence: float
    needs_human_review: bool = False
    rationale: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class AlignmentResult:
    matched_pairs: list[AlignmentPair] = field(default_factory=list)
    nl_only: list[str] = field(default_factory=list)
    sysml_only: list[str] = field(default_factory=list)
    uncertain_pairs: list[AlignmentPair] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Mismatch:
    id: str
    class_: MismatchClass
    severity: Severity
    nl_spec_id: str | None
    sysml_spec_id: str | None
    summary: str
    details: str
    evidence: dict[str, str] = field(default_factory=dict)
    confidence: float = 1.0
    suggested_action: str = ""
    needs_human_review: bool = False

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["class"] = data.pop("class_")
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Mismatch":
        data = dict(data)
        if "class" in data:
            data["class_"] = data.pop("class")
        return cls(**data)
