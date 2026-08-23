"""Load and retrieve approved NL-to-OpenUSD examples."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path

from nl2robotics.retrieval import DiverseBM25, RetrievalDocument


@dataclass(frozen=True)
class OpenUSDExample:
    id: str
    split: str
    category: str
    difficulty: str
    requirement: str
    tags: tuple[str, ...]
    model_path: Path
    provenance: str
    semantic_case_id: str
    lineage_id: str
    variant_type: str

    @property
    def code(self) -> str:
        return self.model_path.read_text(encoding="utf-8")


class OpenUSDExampleCorpus:
    def __init__(self, root: Path | None = None, *, split: str = "rag",
                 subset: str = "full300"):
        self.root = root or Path(__file__).with_name("examples")
        rows = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        subsets = json.loads((self.root / "corpus_subsets.json").read_text(encoding="utf-8"))
        if subset not in subsets:
            raise ValueError(f"unknown corpus subset {subset!r}")
        allowed = set(subsets[subset])
        self.examples = [
            self._example(row) for row in rows
            if row["split"] == split and row["id"] in allowed
        ]
        if not self.examples:
            raise ValueError(f"no OpenUSD examples found for split {split!r}")
        self.subset = subset
        self._index = DiverseBM25([
            RetrievalDocument(
                " ".join((item.requirement, item.category, *item.tags)),
                item.semantic_case_id,
                item.lineage_id,
                item.category,
            ) for item in self.examples
        ])

    def _example(self, row: dict) -> OpenUSDExample:
        return OpenUSDExample(
            id=row["id"],
            split=row["split"],
            category=row["category"],
            difficulty=row["difficulty"],
            requirement=row["requirement"],
            tags=tuple(row["tags"]),
            model_path=self.root / row["model"],
            provenance=row["provenance"],
            semantic_case_id=row.get("semantic_case_id", row["id"]),
            lineage_id=row.get("lineage_id", row["id"]),
            variant_type=row.get("variant_type", "executable_case"),
        )

    def retrieve(self, requirement: str, *,
                 k: int = 5) -> list[tuple[OpenUSDExample, float]]:
        if k < 1:
            raise ValueError("k must be positive")
        ranked = self._index.rank(
            requirement, k=k, max_per_semantic_case=1, max_per_lineage=1
        )
        return [(self.examples[index], score) for index, score in ranked]

    def format_context(self, hits: list[tuple[OpenUSDExample, float]]) -> str:
        blocks = []
        for index, (example, _) in enumerate(hits, 1):
            blocks.append(
                f"Example {index} [{example.id}; {example.category}]\n"
                f"Requirement: {example.requirement}\nOpenUSD USDA:\n{example.code}"
            )
        return "\n\n---\n\n".join(blocks)
