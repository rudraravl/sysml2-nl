#!/usr/bin/env python3
"""Compare naive_glm vs with_kernel_spec using ablation-style metrics.

Reads existing samples from both directories, runs compiler if needed for
syntax/semantic breakdown, and outputs a summary table.

Usage:
    python nl2sysml/compare_naive_vs_pipeline.py
    python nl2sysml/compare_naive_vs_pipeline.py --recompile  # re-run compiler on all
"""

import json
import statistics
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

_ROOT = Path(__file__).resolve().parent.parent
_NL2 = Path(__file__).resolve().parent
sys.path.insert(0, str(_NL2))

from dotenv import load_dotenv
load_dotenv(_ROOT / ".env")

from compiler_interface import check_code, is_compiler_available

WKS_DIR = _ROOT / "dataset" / "with_kernel_spec"
NAIVE_DIR = _ROOT / "dataset" / "naive_glm"
OUT_DIR = _ROOT / "dataset" / "comparison_results"


@dataclass
class SampleMetrics:
    sid: str
    is_valid: bool
    error_count: int
    syntax_error_count: int
    semantic_error_count: int
    empty_output: bool


@dataclass
class CorpusMetrics:
    label: str
    n: int
    valid_rate: float
    mean_errors: float
    median_errors: float
    syntax_fail_rate: float
    semantic_fail_rate: float
    empty_rate: float


def _score_file(sysml_path: Path) -> SampleMetrics:
    """Run compiler on a .sysml file, return metrics."""
    import signal

    sid = sysml_path.parent.name
    code = sysml_path.read_text(encoding="utf-8").strip()
    if not code:
        return SampleMetrics(sid, False, 0, 0, 0, True)

    class _Timeout(Exception):
        pass

    def _alarm(signum, frame):
        raise _Timeout()

    old = signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(60)
    try:
        result = check_code(code)
        syntax = sum(1 for e in result.errors if e.is_syntax_error())
        semantic = sum(1 for e in result.errors if e.is_semantic_error())
        return SampleMetrics(sid, result.is_valid, result.error_count, syntax, semantic, False)
    except _Timeout:
        print(f"  ⚠ compiler timeout on {sid}", file=sys.stderr)
        return SampleMetrics(sid, False, -1, 0, 0, False)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)


def _load_naive_metrics(sid: str, recompile: bool) -> Optional[SampleMetrics]:
    """Load or compute metrics for a naive_glm sample."""
    d = NAIVE_DIR / sid
    sysml = d / f"{sid}.sysml"
    meta = d / "meta.json"
    if not sysml.exists():
        return None

    if recompile and is_compiler_available():
        return _score_file(sysml)

    # Use cached meta if available
    if meta.exists():
        m = json.loads(meta.read_text(encoding="utf-8"))
        v = m.get("validation", {})
        return SampleMetrics(
            sid=sid,
            is_valid=v.get("is_valid", False),
            error_count=v.get("error_count", 0),
            syntax_error_count=v.get("syntax_error_count", 0),
            semantic_error_count=v.get("semantic_error_count", 0),
            empty_output=not sysml.read_text(encoding="utf-8").strip(),
        )
    # Fallback: compile
    if is_compiler_available():
        return _score_file(sysml)
    return None


def _load_wks_metrics(sid: str, recompile: bool) -> Optional[SampleMetrics]:
    """Load or compute metrics for a with_kernel_spec sample."""
    d = WKS_DIR / sid
    sysml = d / f"{sid}.sysml"
    meta = d / "meta.json"
    if not sysml.exists():
        return None

    if recompile and is_compiler_available():
        return _score_file(sysml)

    # Use cached meta — with_kernel_spec only has error_count, not breakdown
    if meta.exists():
        m = json.loads(meta.read_text(encoding="utf-8"))
        v = m.get("validation", {})
        return SampleMetrics(
            sid=sid,
            is_valid=v.get("is_valid", False),
            error_count=v.get("error_count", 0),
            syntax_error_count=v.get("syntax_error_count", 0),
            semantic_error_count=v.get("semantic_error_count", 0),
            empty_output=not sysml.read_text(encoding="utf-8").strip(),
        )

    # No meta at all — need compiler
    if is_compiler_available():
        return _score_file(sysml)
    return None


def aggregate(rows: list[SampleMetrics], label: str) -> CorpusMetrics:
    n = len(rows) or 1
    errors = [r.error_count for r in rows]
    return CorpusMetrics(
        label=label,
        n=len(rows),
        valid_rate=sum(1 for r in rows if r.is_valid) / n * 100,
        mean_errors=statistics.mean(errors) if errors else 0,
        median_errors=statistics.median(errors) if errors else 0,
        syntax_fail_rate=sum(1 for r in rows if r.syntax_error_count > 0) / n * 100,
        semantic_fail_rate=sum(1 for r in rows if r.semantic_error_count > 0) / n * 100,
        empty_rate=sum(1 for r in rows if r.empty_output) / n * 100,
    )


def main():
    recompile = "--recompile" in sys.argv

    # Find overlapping sample IDs
    wks_ids = {p.parent.name for p in WKS_DIR.glob("*/meta.json")}
    naive_ids = {p.parent.name for p in NAIVE_DIR.glob("*/meta.json")} if NAIVE_DIR.exists() else set()

    if not naive_ids:
        print(f"No naive_glm samples found at {NAIVE_DIR}")
        print("Run: .venv/bin/python nl2sysml/naive_glm_generate.py")
        sys.exit(1)

    common = sorted(wks_ids & naive_ids)
    print(f"with_kernel_spec samples: {len(wks_ids)}")
    print(f"naive_glm samples:        {len(naive_ids)}")
    print(f"Overlapping (compared):   {len(common)}")
    print(f"Compiler: {'available' if is_compiler_available() else 'UNAVAILABLE (using cached metrics only)'}")
    print("=" * 70)

    naive_rows = []
    wks_rows = []
    for sid in common:
        nm = _load_naive_metrics(sid, recompile)
        wm = _load_wks_metrics(sid, recompile)
        if nm and wm:
            naive_rows.append(nm)
            wks_rows.append(wm)

    if not naive_rows:
        print("No scoreable samples. Check compiler availability.")
        sys.exit(1)

    naive_corpus = aggregate(naive_rows, f"Naive GLM ({len(naive_rows)} samples)")
    wks_corpus = aggregate(wks_rows, f"Full pipeline ({len(wks_rows)} samples)")

    # Print table
    print()
    hdr = f"{'Condition':<30} {'Valid%':>7} {'Mean err':>9} {'Med err':>8} {'Syn%':>6} {'Sem%':>6} {'Empty%':>7}"
    print(hdr)
    print("-" * len(hdr))
    for c in [naive_corpus, wks_corpus]:
        print(f"{c.label:<30} {c.valid_rate:>6.1f}% {c.mean_errors:>9.1f} {c.median_errors:>8.1f} "
              f"{c.syntax_fail_rate:>5.1f}% {c.semantic_fail_rate:>5.1f}% {c.empty_rate:>6.1f}%")

    # Deltas
    print()
    dv = wks_corpus.valid_rate - naive_corpus.valid_rate
    de = wks_corpus.mean_errors - naive_corpus.mean_errors
    ds = wks_corpus.syntax_fail_rate - naive_corpus.syntax_fail_rate
    dsem = wks_corpus.semantic_fail_rate - naive_corpus.semantic_fail_rate
    print(f"Pipeline vs Naive:  Δ valid {dv:+.1f} pp,  Δ mean errors {de:+.1f},  "
          f"Δ syntax fail {ds:+.1f} pp,  Δ semantic fail {dsem:+.1f} pp")

    # Per-sample detail
    print()
    print("Per-sample breakdown:")
    print(f"  {'ID':<8} {'Naive err':>9} {'Pipeline err':>12} {'Δ':>6} {'Naive':>7} {'Pipeline':>10}")
    print(f"  {'':<8} {'':>9} {'':>12} {'':>6} {'valid?':>7} {'valid?':>10}")
    print("  " + "-" * 55)
    for nm, wm in sorted(zip(naive_rows, wks_rows), key=lambda x: x[0].sid):
        delta = wm.error_count - nm.error_count
        nv = "✓" if nm.is_valid else "✗"
        wv = "✓" if wm.is_valid else "✗"
        print(f"  {nm.sid:<8} {nm.error_count:>9} {wm.error_count:>12} {delta:>+6} "
              f"{nv:>7} {wv:>10}")

    # Save results
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    result = {
        "generated": datetime.now().isoformat() if "datetime" in dir() else "unknown",
        "n_compared": len(common),
        "naive_glm": asdict(naive_corpus),
        "with_kernel_spec": asdict(wks_corpus),
        "delta": {
            "valid_rate_pp": dv,
            "mean_errors": de,
            "syntax_fail_rate_pp": ds,
            "semantic_fail_rate_pp": dsem,
        },
        "per_sample": [
            {
                "sid": nm.sid,
                "naive": asdict(nm),
                "pipeline": asdict(wm),
                "delta_errors": wm.error_count - nm.error_count,
            }
            for nm, wm in zip(naive_rows, wks_rows)
        ],
    }

    from datetime import datetime as _dt
    result["generated"] = _dt.now().isoformat()

    json_path = OUT_DIR / "comparison.json"
    json_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nResults saved to: {json_path}")

    # Markdown summary
    md = [
        "# Naive GLM vs Full Pipeline Comparison",
        "",
        f"Samples compared: {len(common)}",
        "",
        "| Condition | Valid % | Mean errors | Median errors | Syntax fail % | Semantic fail % |",
        "|-----------|---------|-------------|---------------|---------------|-----------------|",
        f"| Naive GLM (single model) | {naive_corpus.valid_rate:.1f} | {naive_corpus.mean_errors:.1f} | "
        f"{naive_corpus.median_errors:.1f} | {naive_corpus.syntax_fail_rate:.1f} | {naive_corpus.semantic_fail_rate:.1f} |",
        f"| Full pipeline (MoE+refine+kernel+spec) | {wks_corpus.valid_rate:.1f} | {wks_corpus.mean_errors:.1f} | "
        f"{wks_corpus.median_errors:.1f} | {wks_corpus.syntax_fail_rate:.1f} | {wks_corpus.semantic_fail_rate:.1f} |",
        "",
        "## Delta (pipeline - naive)",
        "",
        f"- Valid rate: {dv:+.1f} pp",
        f"- Mean errors: {de:+.1f}",
        f"- Syntax fail rate: {ds:+.1f} pp",
        f"- Semantic fail rate: {dsem:+.1f} pp",
        "",
    ]
    md_path = OUT_DIR / "comparison.md"
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Summary saved to: {md_path}")


if __name__ == "__main__":
    main()
