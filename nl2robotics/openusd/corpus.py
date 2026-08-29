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
                 subset: str = "full1500"):
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

    def retrieve(self, requirement: str, *, k: int = 5,
                 preferred_categories: tuple[str, ...] = (),
                 ) -> list[tuple[OpenUSDExample, float]]:
        if k < 1:
            raise ValueError("k must be positive")
        unknown = set(preferred_categories) - {
            item.category for item in self.examples
        }
        if unknown:
            raise ValueError(f"unknown OpenUSD retrieval categories: {sorted(unknown)}")
        ranked = _preferred_rank(
            self._index, self.examples, requirement, k, preferred_categories,
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


def _preferred_rank(index: DiverseBM25, examples: list[OpenUSDExample],
                    query: str, k: int,
                    categories: tuple[str, ...]) -> list[tuple[int, float]]:
    if not categories:
        return index.rank(
            query, k=k, max_per_semantic_case=1, max_per_lineage=1,
        )
    preferred_count = min(k, max(1, (4 * k + 4) // 5))
    routed = index.rank(
        query, k=preferred_count, max_per_semantic_case=1, max_per_lineage=1,
        allowed_categories=frozenset(categories),
    )
    global_ranked = index.rank(
        query, k=k + preferred_count,
        max_per_semantic_case=1, max_per_lineage=1,
    )
    selected = list(routed)
    semantic = {examples[i].semantic_case_id for i, _ in selected}
    lineage = {examples[i].lineage_id for i, _ in selected}
    for candidate in global_ranked:
        item = examples[candidate[0]]
        if item.semantic_case_id in semantic or item.lineage_id in lineage:
            continue
        selected.append(candidate)
        semantic.add(item.semantic_case_id)
        lineage.add(item.lineage_id)
        if len(selected) == k:
            break
    return selected
