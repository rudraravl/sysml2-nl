from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np


SPLIT_ORDER: list[tuple[str, str]] = [
    ("official", "Off"),
    ("community", "Com"),
    ("pilot", "Pilot"),
    ("esa", "ESA"),
    ("agent", "Agent"),
]


@dataclass(frozen=True)
class PairRecord:
    nl: str
    sysml: str
    split: str


def load_records(dataset_dir: Path) -> list[PairRecord]:
    manifest_path = dataset_dir / "index" / "manifest.jsonl"
    out: list[PairRecord] = []
    with manifest_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            split = str(rec.get("split", "unknown"))
            nl_path = dataset_dir / rec["paths"]["text"]
            sysml_path = dataset_dir / rec["paths"]["sysml"]
            out.append(
                PairRecord(
                    nl=nl_path.read_text(encoding="utf-8").strip(),
                    sysml=sysml_path.read_text(encoding="utf-8").strip(),
                    split=split,
                )
            )
    return out


def split_indices(splits: list[str]) -> dict[str, np.ndarray]:
    idx: dict[str, list[int]] = {}
    for i, s in enumerate(splits):
        idx.setdefault(s, []).append(i)
    return {k: np.asarray(v, dtype=np.int32) for k, v in idx.items()}


def _topk_global(row: np.ndarray, cand: np.ndarray, k: int) -> np.ndarray:
    if k <= 0:
        return cand[:0]
    if cand.size == 0:
        return cand
    k = min(k, cand.size)
    scores = row[cand]
    if k == cand.size:
        local = np.argsort(-scores)
        return cand[local]
    local = np.argpartition(-scores, kth=k - 1)[:k]
    local = local[np.argsort(-scores[local])]
    return cand[local]


def recall_at_k(sims: np.ndarray, q: np.ndarray, cand: np.ndarray, k: int) -> float:
    if q.size == 0 or cand.size == 0:
        return float("nan")
    hits = 0
    for i in q:
        topk = _topk_global(sims[i], cand, k)
        if i in topk:
            hits += 1
    return hits / float(q.size)


def eval_bidirectional_recalls_by_source(
    sims: np.ndarray,
    splits: list[str],
    ks: Iterable[int] = (5,),
) -> dict[int, dict[str, float]]:
    """
    Returns {k: {Off/Com/Pilot/ESA/Agent/All: avg_recall}}, where avg is the
    mean of NL→SysML and SysML→NL recalls computed within each source subset.
    """
    idx = split_indices(splits)
    all_idx = np.arange(len(splits), dtype=np.int32)
    out: dict[int, dict[str, float]] = {}

    sims_t = sims.T
    for k in ks:
        row: dict[str, float] = {}
        for split_name, col in SPLIT_ORDER:
            cand = idx.get(split_name, np.asarray([], dtype=np.int32))
            r1 = recall_at_k(sims, cand, cand, k)
            r2 = recall_at_k(sims_t, cand, cand, k)
            row[col] = (r1 + r2) / 2.0
        r1 = recall_at_k(sims, all_idx, all_idx, k)
        r2 = recall_at_k(sims_t, all_idx, all_idx, k)
        row["All"] = (r1 + r2) / 2.0
        out[int(k)] = row
    return out


def format_paper_row(name: str, cls: str, scores: dict[str, float]) -> str:
    cols = [col for _, col in SPLIT_ORDER] + ["All"]
    vals = []
    for col in cols:
        v = scores.get(col, float("nan"))
        vals.append("N/A" if np.isnan(v) else f"{100.0 * v:.1f}")
    return f"{name} ({cls}) & " + " & ".join(vals) + r" \\"

