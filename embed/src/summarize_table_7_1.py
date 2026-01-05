from __future__ import annotations

import re
from pathlib import Path

import numpy as np

from retrieval_eval import SPLIT_ORDER, format_paper_row


LOG_FILES = [
    "log_run_baseline_minilm.txt",
    "log_run_baseline_bge.txt",
    "log_run_baseline_qwen3_embed.txt",
    "log_run_baseline_llama.txt",
    "log_run_baseline_kalm.txt",
]


def _parse_log(path: Path) -> tuple[str, str, dict[str, float]]:
    model = ""
    cls = ""
    r5_line = ""
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("Model:"):
            model = line.split(":", 1)[1].strip()
        elif line.startswith("Class:"):
            cls = line.split(":", 1)[1].strip()
        elif line.startswith("R@5 "):
            r5_line = line
    if not model or not cls or not r5_line:
        raise ValueError(f"Could not parse {path}")

    # Example: "R@5 Off/Com/Pilot/ESA/Agent/All (%): Off=..., Com=..., ..."
    pairs = dict(re.findall(r"([A-Za-z]+)=([0-9.]+)", r5_line))
    scores: dict[str, float] = {}
    for _, col in SPLIT_ORDER:
        scores[col] = float(pairs.get(col, "nan")) / 100.0
    scores["All"] = float(pairs.get("All", "nan")) / 100.0
    return model, cls, scores


def _avg(rows: list[dict[str, float]]) -> dict[str, float]:
    cols = [col for _, col in SPLIT_ORDER] + ["All"]
    out: dict[str, float] = {}
    for col in cols:
        vals = [r.get(col, float("nan")) for r in rows]
        vals = [v for v in vals if not np.isnan(v)]
        out[col] = float(np.mean(vals)) if vals else float("nan")
    return out


def main() -> None:
    here = Path(__file__).resolve().parent
    parsed = []
    for name in LOG_FILES:
        p = here / name
        if not p.exists():
            continue
        try:
            parsed.append(_parse_log(p))
        except Exception as e:
            print(f"Skipping {p.name}: {e}")

    if not parsed:
        raise SystemExit(
            "No parseable baseline logs found. Re-run the baseline scripts to regenerate logs, e.g.:\n"
            "  python embed/src/run_baseline_miniLM.py\n"
            "  python embed/src/run_baseline_bge.py\n"
            "  python embed/src/run_baseline_qwen3_embed.py\n"
            "  python embed/src/run_baseline_llama.py\n"
            "  python embed/src/run_baseline_KaLM.py"
        )

    by_cls: dict[str, list[dict[str, float]]] = {}
    all_rows: list[dict[str, float]] = []
    for _, cls, scores in parsed:
        by_cls.setdefault(cls, []).append(scores)
        all_rows.append(scores)

    print("=== Per-model rows (R@5) ===")
    for model, cls, scores in parsed:
        print(format_paper_row(model, cls, scores))

    print("\n=== Category averages (R@5) ===")
    for cls in ["E", "E+D", "D"]:
        if cls not in by_cls:
            continue
        print(format_paper_row("Category Avg", cls, _avg(by_cls[cls])))
    print(format_paper_row("All Models Avg", "All", _avg(all_rows)))


if __name__ == "__main__":
    main()
