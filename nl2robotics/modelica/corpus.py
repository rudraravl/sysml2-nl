"""Load and retrieve leakage-safe NL-to-Modelica examples."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path

from nl2robotics.retrieval import DiverseBM25, RetrievalDocument


@dataclass(frozen=True)
class Example:
    id: str
    split: str
    tier: str
    category: str
    archetype: str
    difficulty: str
    requirement: str
    tags: tuple[str, ...]
    model_path: Path
    source: str
    license: str
    semantic_case_id: str
    lineage_id: str
    variant_type: str

    @property
    def code(self) -> str:
        return self.model_path.read_text(encoding="utf-8")


class ExampleCorpus:
    """Deterministic BM25-style retriever over the approved RAG split."""

    def __init__(self, root: Path | None = None, *, split: str = "rag",
                 subset: str = "full1500"):
        self.root = root or Path(__file__).with_name("examples")
        self.subset = subset
        rows = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        subsets = json.loads(
            (self.root / "corpus_subsets.json").read_text(encoding="utf-8")
        )
        if subset not in subsets:
            raise ValueError(f"unknown corpus subset {subset!r}")
        allowed = set(subsets[subset])
        self.examples = [
            self._example(row) for row in rows
            if row["split"] == split and row["id"] in allowed
        ]
        if not self.examples:
            raise ValueError(f"no Modelica examples found for split {split!r}")
        self._index = DiverseBM25([
            RetrievalDocument(
                " ".join((item.requirement, item.category, *item.tags)),
                item.semantic_case_id,
                item.lineage_id,
                item.category,
            ) for item in self.examples
        ])

    def _example(self, row: dict) -> Example:
        return Example(
            id=row["id"],
            split=row["split"],
            tier=row["tier"],
            category=row["category"],
            archetype=row["archetype"],
            difficulty=row["difficulty"],
            requirement=row["requirement"],
            tags=tuple(row["tags"]),
            model_path=self.root / row["model_file"],
            source=row["source"],
            license=row["license"],
            semantic_case_id=row.get("semantic_case_id", row["id"]),
            lineage_id=row.get("lineage_id", row.get("archetype", row["id"])),
            variant_type=row.get("variant_type", "executable_case"),
        )

    def retrieve(self, requirement: str, *, k: int = 4,
                 tags: tuple[str, ...] = (),
                 preferred_categories: tuple[str, ...] = (),
                 ) -> list[tuple[Example, float]]:
        if k < 1:
            raise ValueError("k must be positive")
        unknown = set(preferred_categories) - {
            item.category for item in self.examples
        }
        if unknown:
            raise ValueError(f"unknown Modelica retrieval categories: {sorted(unknown)}")
        query = requirement + " " + " ".join(tags)
        ranked = _preferred_rank(
            self._index, self.examples, query, k, preferred_categories,
        )
        return [(self.examples[index], score) for index, score in ranked]

    def context(self, requirement: str, *, k: int = 5,
                max_code_lines: int = 100,
                preferred_categories: tuple[str, ...] = ()) -> str:
        return self.format_context(
            self.retrieve(
                requirement, k=k, preferred_categories=preferred_categories
            ),
            max_code_lines=max_code_lines,
        )

    def format_context(self, hits: list[tuple[Example, float]], *,
                       max_code_lines: int = 100) -> str:
        blocks = []
        for index, (item, _) in enumerate(hits, 1):
            code = "\n".join(item.code.splitlines()[:max_code_lines])
            blocks.append(
                f"Example {index} [{item.id}; {item.category}; {item.difficulty}]\n"
                f"Requirement: {item.requirement}\nModelica:\n{code}"
            )
        return "\n\n---\n\n".join(blocks)


def _preferred_rank(index: DiverseBM25, examples: list[Example], query: str,
                    k: int, categories: tuple[str, ...]) -> list[tuple[int, float]]:
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
