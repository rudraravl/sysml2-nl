#!/usr/bin/env python3
"""Build the per-snapshot SysMLAgent corpora from one generation run (no extra generation).

    dataset/sysml_agent_iter0/<ID>/   iter-0: the initial generation = the paper's LLM_Raw+RAG
    dataset/sysml_agent_iter1/<ID>/   the model after fix round 1, or iter-0 if it was already
                                      ANTLR-valid: budget-matched to FORGE's one repair round
    dataset/sysml_agent/<ID>/         the final candidate (written by run_sysml_agent.py itself)

Each gets <ID>.sysml, <ID>.txt and a naive-compatible meta.json whose `validation` / `errors`
come from our compiler on that snapshot (already computed during generation and stored in
transcript.json, so nothing is recompiled). `snapshot` records the cost up to that snapshot.

    python nl2sysml/sysml_agent/materialize.py [--src dataset/sysml_agent]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent
sys.path.insert(0, str(_HERE))

import run_sysml_agent as run  # noqa: E402

SNAPSHOTS = {"iter0": 0, "iter1": 1}


def snapshot_meta(final_meta: dict, tr: dict, j: int, pipeline: str) -> dict:
    it = tr["iterations"][j]
    c = it.get("compile") or {"is_valid": False, "error_count": 0, "syntax_error_count": 0,
                              "semantic_error_count": 0, "errors": []}
    meta = {k: final_meta[k] for k in ("id", "model", "created", "elapsed_sec")}
    meta.update({
        "pipeline": pipeline,
        "empty_output": bool(c.get("empty")),
        "validation": {k: c[k] for k in ("is_valid", "error_count", "syntax_error_count",
                                         "semantic_error_count")},
        "errors": c["errors"],
    })
    if c.get("timeout"):
        meta["compiler_timeout"] = True
    used = tr["iterations"][:j + 1]
    meta["snapshot"] = {
        "iter": j,
        "antlr_valid": it["antlr"]["valid"],
        "n_calls": j + 1,
        "tokens": run._tokens(used),
        "llm_latency_sec": round(sum(u["latency_sec"] for u in used), 1),
    }
    meta["sysml_agent"] = final_meta["sysml_agent"]  # the whole run, for reference
    return meta


def materialize(src: Path, root: Path) -> dict:
    counts = {}
    for name, want in SNAPSHOTS.items():
        dst = root / f"{src.name}_{name}"
        n = 0
        for mp in sorted(src.glob("*/meta.json")):
            final = json.loads(mp.read_text(encoding="utf-8"))
            if "sysml_agent" not in final:
                continue
            sid, d = final["id"], mp.parent
            tr = json.loads((d / "transcript.json").read_text(encoding="utf-8"))
            j = min(want, len(tr["iterations"]) - 1)
            code = (d / "candidates" / f"iter-{j}.sysml").read_text(encoding="utf-8")
            out = dst / sid
            out.mkdir(parents=True, exist_ok=True)
            (out / f"{sid}.sysml").write_text(code, encoding="utf-8")
            (out / f"{sid}.txt").write_text((d / f"{sid}.txt").read_text(encoding="utf-8"),
                                            encoding="utf-8")
            meta = snapshot_meta(final, tr, j, f"{run.PIPELINE}_{name}")
            (out / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n",
                                           encoding="utf-8")
            n += 1
        counts[str(dst)] = n
    return counts


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", type=Path, default=_ROOT / "dataset" / "sysml_agent")
    a = ap.parse_args()
    for d, n in materialize(a.src, a.src.parent).items():
        print(f"{n:5d} seeds -> {d}")
