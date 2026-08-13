"""Load and retrieve leakage-safe NL-to-Modelica examples."""

from __future__ import annotations

from dataclasses import dataclass
import json
import math
from pathlib import Path
import re


_TOKEN = re.compile(r"[A-Za-z][A-Za-z0-9_]*")


def _tokens(text: str) -> list[str]:
    return [token.lower() for token in _TOKEN.findall(text)]


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

    @property
    def code(self) -> str:
        return self.model_path.read_text(encoding="utf-8")


class ExampleCorpus:
    """Deterministic BM25-style retriever over the approved RAG split."""

    def __init__(self, root: Path | None = None, *, split: str = "rag",
                 subset: str = "full100"):
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
        self._docs = [
            _tokens(" ".join((item.requirement, item.category, *item.tags)))
            for item in self.examples
        ]
        self._df: dict[str, int] = {}
        for doc in self._docs:
            for token in set(doc):
                self._df[token] = self._df.get(token, 0) + 1
        self._avg_len = sum(map(len, self._docs)) / len(self._docs)

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
        )

    def retrieve(self, requirement: str, *, k: int = 4,
                 tags: tuple[str, ...] = ()) -> list[tuple[Example, float]]:
        if k < 1:
            raise ValueError("k must be positive")
        query = _tokens(requirement + " " + " ".join(tags))
        scores = [self._score(query, doc) for doc in self._docs]
        ranked = sorted(zip(self.examples, scores), key=lambda item: (-item[1], item[0].id))
        return ranked[:min(k, len(ranked))]

    def _score(self, query: list[str], doc: list[str]) -> float:
        counts = {token: doc.count(token) for token in set(query)}
        score = 0.0
        for token in query:
            tf = counts.get(token, 0)
            if not tf:
                continue
            df = self._df.get(token, 0)
            idf = math.log(1 + (len(self._docs) - df + 0.5) / (df + 0.5))
            norm = tf + 1.5 * (1 - 0.75 + 0.75 * len(doc) / self._avg_len)
            score += idf * tf * 2.5 / norm
        return score

    def context(self, requirement: str, *, k: int = 5,
                max_code_lines: int = 100) -> str:
        return self.format_context(
            self.retrieve(requirement, k=k), max_code_lines=max_code_lines
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
