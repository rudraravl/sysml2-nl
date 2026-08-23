"""Deterministic, lineage-aware retrieval shared by robotics profiles."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import math
import re


_WORD = re.compile(r"[A-Za-z]+(?:[A-Z][a-z]+)*|\d+(?:\.\d+)?")


def tokens(text: str) -> list[str]:
    """Tokenize prose, snake case, hyphenation, and common unit spellings."""
    expanded = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text)
    expanded = expanded.replace("_", " ").replace("-", " ")
    result = [match.group(0).lower() for match in _WORD.finditer(expanded)]
    aliases = {
        "degrees": "deg", "degree": "deg", "radians": "rad",
        "radian": "rad", "kilograms": "kg", "kilogram": "kg",
        "meters": "m", "meter": "m", "metres": "m", "metre": "m",
        "revolute": "rotational", "prismatic": "translational",
    }
    return result + [aliases[item] for item in result if item in aliases]


@dataclass(frozen=True)
class RetrievalDocument:
    text: str
    semantic_case_id: str
    lineage_id: str
    category: str


class DiverseBM25:
    """BM25 ranker that limits repeated phrasings of one semantic artifact."""

    def __init__(self, documents: list[RetrievalDocument]):
        if not documents:
            raise ValueError("retrieval index requires at least one document")
        self.documents = documents
        self._tokens = [tokens(item.text) for item in documents]
        self._df: Counter[str] = Counter()
        for document in self._tokens:
            self._df.update(set(document))
        self._average_length = sum(map(len, self._tokens)) / len(self._tokens)

    def rank(self, query: str, *, k: int,
             max_per_semantic_case: int = 1,
             max_per_lineage: int = 1) -> list[tuple[int, float]]:
        if k < 1:
            raise ValueError("k must be positive")
        if max_per_semantic_case < 1:
            raise ValueError("max_per_semantic_case must be positive")
        if max_per_lineage < 1:
            raise ValueError("max_per_lineage must be positive")
        query_tokens = tokens(query)
        query_counts = Counter(query_tokens)
        scored = [
            (index, self._score(query_counts, document))
            for index, document in enumerate(self._tokens)
        ]
        scored.sort(key=lambda item: (-item[1], item[0]))
        selected: list[tuple[int, float]] = []
        seen_semantic: Counter[str] = Counter()
        seen_lineage: Counter[str] = Counter()
        for index, score in scored:
            document = self.documents[index]
            if seen_semantic[document.semantic_case_id] >= max_per_semantic_case:
                continue
            if seen_lineage[document.lineage_id] >= max_per_lineage:
                continue
            selected.append((index, score))
            seen_semantic[document.semantic_case_id] += 1
            seen_lineage[document.lineage_id] += 1
            if len(selected) == min(k, len({d.lineage_id for d in self.documents})):
                break
        return selected

    def _score(self, query: Counter[str], document: list[str]) -> float:
        frequencies = Counter(document)
        score = 0.0
        size = len(self.documents)
        for term, query_frequency in query.items():
            frequency = frequencies.get(term, 0)
            if not frequency:
                continue
            df = self._df[term]
            inverse = math.log(1 + (size - df + 0.5) / (df + 0.5))
            normalizer = frequency + 1.5 * (
                0.25 + 0.75 * len(document) / self._average_length
            )
            term_score = inverse * frequency * 2.5 / normalizer
            score += term_score * (1.0 + min(query_frequency - 1, 2) * 0.05)
        return score
