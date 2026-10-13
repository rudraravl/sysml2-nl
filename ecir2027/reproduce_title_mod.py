#!/usr/bin/env python3
"""Recompute Modelica control rates, paired tests, and usage without model calls.

Usage: python3 ecir2027/reproduce_title_mod.py
Only the Python standard library is required. Output is JSON on stdout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent
ARMS = {"a0c": "c1", "a0b": "b1", "rs": "r1"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def holm(values):
    result = [0.0] * len(values)
    running = 0.0
    for rank, index in enumerate(sorted(range(len(values)), key=values.__getitem__)):
        running = max(running, (len(values) - rank) * values[index])
        result[index] = min(1.0, running)
    return result


def reproduce(root):
    ids = (HERE / "ids/ladder500_mod.txt").read_text().split()
    cells = [load(root / req / "cell.json") for req in ids]
    if len(ids) != 500 or len(set(ids)) != 500:
        raise ValueError("expected 500 distinct frozen requirements")
    for req, cell in zip(ids, cells):
        if cell["req_id"] != req:
            raise ValueError(f"cell ID mismatch: {req}")
    n = len(cells)
    first = sum(c["a0"] for c in cells)
    baseline = [json.loads(line) for line in
                (HERE / "runs/scored/a0_v1.jsonl").read_text().splitlines() if line]
    if {c["req_id"] for c in baseline} != set(ids) or len(baseline) != n:
        raise ValueError("archived baseline must have exactly the same 500 IDs")
    old = sum(c["compile_valid"] for c in baseline)
    vectors = {}
    rates = {}
    for budget in (1, 2):
        vectors[budget] = {}
        for arm, stem in ARMS.items():
            values = []
            for c in cells:
                if budget == 2:
                    passed = c[arm]
                elif c["a0"]:
                    passed = True
                else:
                    p = root / c["req_id"] / (stem + ".json")
                    passed = load(p)["compile_valid"] if p.exists() else False
                values.append(bool(passed))
            vectors[budget][arm] = values
            rates[f"{arm}_{budget}_extra"] = {
                "passed": sum(values), "n": n, "percent": 100 * sum(values) / n}
    tests = []
    for budget in (1, 2):
        for a, b in (("a0c", "a0b"), ("a0c", "rs"), ("a0b", "rs")):
            pairs = list(zip(vectors[budget][a], vectors[budget][b]))
            wins = sum(x and not y for x, y in pairs)
            losses = sum(y and not x for x, y in pairs)
            discordant = wins + losses
            p = min(1.0, 2 * sum(math.comb(discordant, i)
                    for i in range(min(wins, losses) + 1)) / 2**discordant)
            tests.append({"extra_attempts": budget, "a": a, "b": b,
                          "a_only": wins, "b_only": losses, "p_raw": p})
    for row, adjusted in zip(tests, holm([t["p_raw"] for t in tests])):
        row["p_holm_six_modelica_comparisons"] = adjusted
    for start in (0, 3):
        for row, adjusted in zip(tests[start:start + 3],
                                 holm([t["p_raw"] for t in tests[start:start + 3]])):
            row["p_holm_three_within_budget"] = adjusted
    failed = [c for c in cells if not c["a0"]]
    draft_errors = [len(load(root / c["req_id"] / "s0.json")["diagnostics"])
                    for c in failed if (root / c["req_id"] / "s0.json").exists()]
    usage = {}
    for arm in ("a0", *ARMS):
        usage[arm] = {}
        for field, source in (("model_calls", "attempts"),
                              ("tokens_in", "tokens_in"), ("tokens_out", "tokens_out")):
            values = [c[source][arm] for c in cells]
            usage[arm][field] = {"total": sum(values),
                                 "mean_per_requirement": statistics.mean(values),
                                 "median_per_requirement": statistics.median(values)}
    paths = sorted(p for p in root.glob("*/*")
                   if p.is_file() and p.suffix in (".mo", ".json"))
    return {
        "n": n, "first_draw": {"passed": first, "percent": first * 100 / n},
        "archived_first_draw": {"passed": old, "percent": old * 100 / n},
        "route_difference_pp": (first - old) * 100 / n,
        "rates": rates, "paired_exact_mcnemar": tests,
        "holm_note": "Choose the correction family specified by the paper; cross-language table families require their other raw p-values.",
        "failures": {"unsuccessful_requirements": len(failed),
                     "normalization_skips": sum(c.get("skipped") == "normalization" for c in cells),
                     "actual_failing_drafts": len(draft_errors),
                     "median_compiler_errors_among_failing_drafts": statistics.median(draft_errors),
                     "cleared_by_diagnostic_repair": sum(c["a0c"] for c in failed)},
        "usage": usage,
        "sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in paths},
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=HERE / "runs/title_mod")
    args = parser.parse_args()
    print(json.dumps(reproduce(args.root), indent=2, sort_keys=True))
