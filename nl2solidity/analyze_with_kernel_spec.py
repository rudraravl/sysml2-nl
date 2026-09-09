#!/usr/bin/env python3
"""Standalone fidelity analysis of the full-pipeline Solidity corpus.

No naive baseline exists yet, so this does not compare naive-vs-pipeline; it
just characterizes overall quality of everything under
nl2solidity/dataset/with_kernel_spec/*/meta.json (compiler validity, Foundry
execution, Slither security, spec-alignment similarity, and the quality-gate
funnel that turns those four into a per-sample A/B grade), broken out overall
and by domain (category).

Reads only cached meta.json produced by the full pipeline (no LLM/solc/forge/
slither calls), so this runs in well under a second for ~800 samples.

Usage:
    python nl2solidity/analyze_with_kernel_spec.py
    python nl2solidity/analyze_with_kernel_spec.py --dir nl2solidity/dataset/with_kernel_spec
"""

import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

_ROOT = Path(__file__).resolve().parent.parent
_NL2 = Path(__file__).resolve().parent

DEFAULT_DIR = _NL2 / "dataset" / "with_kernel_spec"
OUT_DIR = _NL2 / "dataset" / "analysis_results"


@dataclass
class SampleRecord:
    sid: str
    category: str
    quality: str
    is_valid: bool
    error_count: int
    fuzz_status: Optional[str]
    properties_status: Optional[str]
    n_tests: int
    n_passed: int
    n_failed: int
    contract_defects: int
    harness_defects: int
    property_tests: int
    n_findings: int
    n_actionable: int
    by_impact: Dict[str, int]
    similarity: Optional[float]
    accepted: bool
    repairs: int
    # Quality-gate components (mirrors batch_generate.create_meta_json)
    validation_ok: bool
    alignment_ok: bool
    execution_ok: bool
    security_ok: bool


def load_records(directory: Path) -> List[SampleRecord]:
    records = []
    for meta_path in sorted(directory.glob("*/meta.json")):
        try:
            d = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        sid = d.get("id", meta_path.parent.name)
        v = d.get("validation", {}) or {}
        ex = d.get("execution", {}) or {}
        sec = d.get("security", {}) or {}
        sa = d.get("spec_alignment", {}) or {}
        tier = ex.get("tier_status", {}) or {}

        validation_ok = bool(v.get("is_valid", False))
        alignment_ok = bool(sa.get("accepted", False)) if sa else True
        execution_ok = not ex.get("contract_defects")
        security_ok = not sec.get("n_actionable")

        records.append(SampleRecord(
            sid=sid,
            category=d.get("category", "unknown"),
            quality=d.get("quality", "?"),
            is_valid=validation_ok,
            error_count=v.get("error_count", 0),
            fuzz_status=tier.get("fuzz"),
            properties_status=tier.get("properties"),
            n_tests=ex.get("n_tests", 0),
            n_passed=ex.get("n_passed", 0),
            n_failed=ex.get("n_failed", 0),
            contract_defects=ex.get("contract_defects", 0),
            harness_defects=ex.get("harness_defects", 0),
            property_tests=ex.get("property_tests", 0),
            n_findings=sec.get("n_findings", 0),
            n_actionable=sec.get("n_actionable", 0),
            by_impact=sec.get("by_impact", {}) or {},
            similarity=sa.get("similarity"),
            accepted=bool(sa.get("accepted", False)),
            repairs=sa.get("repairs", 0) or 0,
            validation_ok=validation_ok,
            alignment_ok=alignment_ok,
            execution_ok=execution_ok,
            security_ok=security_ok,
        ))
    return records


def rate(flags) -> float:
    flags = list(flags)
    return (sum(1 for f in flags if f) / len(flags) * 100) if flags else 0.0


def overview(records: List[SampleRecord]) -> Dict[str, Any]:
    n = len(records)
    sims = [r.similarity for r in records if r.similarity is not None]
    quality_counts = Counter(r.quality for r in records)
    return {
        "n": n,
        "quality_A_rate": rate(r.quality == "A" for r in records),
        "quality_counts": dict(quality_counts),
        "valid_rate": rate(r.validation_ok for r in records),
        "mean_errors": statistics.mean([r.error_count for r in records]) if n else 0,
        "fuzz_pass_rate": rate(r.fuzz_status == "passed" for r in records),
        "fuzz_status_counts": dict(Counter(r.fuzz_status for r in records)),
        "properties_status_counts": dict(Counter(r.properties_status for r in records)),
        "execution_clean_rate": rate(r.execution_ok for r in records),
        "mean_contract_defects": statistics.mean([r.contract_defects for r in records]) if n else 0,
        "security_clean_rate": rate(r.security_ok for r in records),
        "mean_findings": statistics.mean([r.n_findings for r in records]) if n else 0,
        "mean_actionable": statistics.mean([r.n_actionable for r in records]) if n else 0,
        "alignment_accepted_rate": rate(r.alignment_ok for r in records),
        "mean_similarity": statistics.mean(sims) if sims else None,
        "median_similarity": statistics.median(sims) if sims else None,
        "all_four_gates_clean_rate": rate(
            (r.validation_ok and r.alignment_ok and r.execution_ok and r.security_ok)
            for r in records
        ),
    }


def gate_funnel(records: List[SampleRecord]) -> Dict[str, Any]:
    """How many samples survive each additional quality gate, in the order
    batch_generate.create_meta_json ANDs them together."""
    n = len(records)
    step1 = [r for r in records if r.validation_ok]
    step2 = [r for r in step1 if r.alignment_ok]
    step3 = [r for r in step2 if r.execution_ok]
    step4 = [r for r in step3 if r.security_ok]
    return {
        "generated": n,
        "compiles": len(step1),
        "+ spec_aligned": len(step2),
        "+ execution_clean": len(step3),
        "+ security_clean (= quality A)": len(step4),
    }


def by_category(records: List[SampleRecord]) -> Dict[str, Dict[str, Any]]:
    cats: Dict[str, List[SampleRecord]] = defaultdict(list)
    for r in records:
        cats[r.category].append(r)
    out = {}
    for cat, rows in sorted(cats.items(), key=lambda kv: -len(kv[1])):
        sims = [r.similarity for r in rows if r.similarity is not None]
        out[cat] = {
            "n": len(rows),
            "quality_A_rate": rate(r.quality == "A" for r in rows),
            "valid_rate": rate(r.validation_ok for r in rows),
            "fuzz_pass_rate": rate(r.fuzz_status == "passed" for r in rows),
            "security_clean_rate": rate(r.security_ok for r in rows),
            "alignment_accepted_rate": rate(r.alignment_ok for r in rows),
            "mean_similarity": statistics.mean(sims) if sims else None,
        }
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", default=None,
                         help="Directory of {ID}/meta.json samples (default: dataset/with_kernel_spec)")
    args = parser.parse_args()
    directory = Path(args.dir) if args.dir else DEFAULT_DIR
    if not directory.is_absolute():
        directory = _NL2 / directory

    records = load_records(directory)
    if not records:
        print(f"No samples found under {directory}")
        sys.exit(1)

    ov = overview(records)
    funnel = gate_funnel(records)
    cats = by_category(records)

    print(f"Corpus: {directory}")
    print(f"Samples: {ov['n']}")
    print("=" * 70)
    print(f"Quality tier:           A={ov['quality_counts'].get('A', 0)}  "
          f"B={ov['quality_counts'].get('B', 0)}  ({ov['quality_A_rate']:.1f}% A)")
    print(f"Compiler valid rate:    {ov['valid_rate']:.1f}%  (mean errors {ov['mean_errors']:.2f})")
    print(f"Foundry fuzz pass rate: {ov['fuzz_pass_rate']:.1f}%  {ov['fuzz_status_counts']}")
    print(f"Execution-clean rate:   {ov['execution_clean_rate']:.1f}%  "
          f"(mean contract defects {ov['mean_contract_defects']:.2f})")
    print(f"Security-clean rate:    {ov['security_clean_rate']:.1f}%  "
          f"(mean findings {ov['mean_findings']:.2f}, mean actionable {ov['mean_actionable']:.2f})")
    print(f"Spec-alignment accepted:{ov['alignment_accepted_rate']:.1f}%  "
          f"(mean similarity {ov['mean_similarity']:.4f}, median {ov['median_similarity']:.4f})")
    print(f"All 4 gates clean:      {ov['all_four_gates_clean_rate']:.1f}%")
    print()
    print("Quality-gate funnel:")
    for k, v in funnel.items():
        print(f"  {k:<32} {v:>4}")
    print()
    print(f"{'Category':<14}{'n':>5}{'A rate':>9}{'Valid%':>9}{'Fuzz%':>8}{'Sec-clean%':>12}{'Align%':>9}{'MeanSim':>9}")
    print("-" * 76)
    for cat, s in cats.items():
        ms = f"{s['mean_similarity']:.3f}" if s["mean_similarity"] is not None else "n/a"
        print(f"{cat:<14}{s['n']:>5}{s['quality_A_rate']:>8.1f}%{s['valid_rate']:>8.1f}%"
              f"{s['fuzz_pass_rate']:>7.1f}%{s['security_clean_rate']:>11.1f}%"
              f"{s['alignment_accepted_rate']:>8.1f}%{ms:>9}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    result = {
        "generated": datetime.now().isoformat(),
        "corpus_dir": str(directory),
        "overview": ov,
        "gate_funnel": funnel,
        "by_category": cats,
    }
    json_path = OUT_DIR / "with_kernel_spec_fidelity.json"
    json_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nResults saved to: {json_path}")


if __name__ == "__main__":
    main()
