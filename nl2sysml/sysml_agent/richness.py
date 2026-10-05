#!/usr/bin/env python3
"""Model richness, requirement-component coverage and size-stratified validity per arm.

Descriptive (no tests): what the validity metrics do not show. For each arm on the paired seeds:
  - median counts of element keywords (part, attribute, port, state, action, requirement,
    connections = connect|connection|flow|interface|bind, constraint|assert);
  - component coverage: the requirement texts name their components in **bold**; the share of
    those names (lower-cased, non-alphanumerics removed) found in the model text, and the share
    of models containing all of them;
  - valid compile rate by model size (non-blank lines), unpaired within each size band.

    python nl2sysml/sysml_agent/richness.py -> dataset/analysis_results/sysml_agent/richness.{md,json}
"""

from __future__ import annotations

import json
import re
import statistics as st
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent))

from recompute_sysml_stats import CHECKPOINT, STALE  # noqa: E402

D = _HERE.parent.parent / "dataset"
OUT = D / "analysis_results" / "sysml_agent"
ARMS = {"naive": "naive_glm", "sysml_agent_iter0": "sysml_agent_iter0",
        "sysml_agent_iter1": "sysml_agent_iter1", "sysml_agent_final": "sysml_agent",
        "forge": "with_kernel_spec"}
KW = {"parts": r"\bpart\b", "attributes": r"\battribute\b", "ports": r"\bport\b",
      "states": r"\bstate\b", "actions": r"\baction\b", "requirements": r"\brequirement\b",
      "connections": r"\b(?:connect|connection|flow|interface|bind)\b",
      "constraints": r"\b(?:constraint|assert)\b"}
BINS = [(0, 60), (60, 100), (100, 150), (150, 250), (250, None)]


def norm(t: str) -> str:
    return re.sub(r"[^a-z0-9]", "", t.lower())


def main():
    diag = json.loads(CHECKPOINT.read_text())
    ids = sorted((p.parent.name for p in (D / "sysml_agent").glob("*/meta.json")
                  if p.parent.name not in set(STALE)), key=lambda s: int(s[1:]))
    terms = {}
    for s in ids:
        txt = (D / "with_kernel_spec" / s / f"{s}.txt").read_text(encoding="utf-8")
        terms[s] = {norm(re.sub(r"[:.\s]+$", "", t)) for t in re.findall(r"\*\*([^*]{3,60})\*\*", txt)} - {""}
    named = [s for s in ids if terms[s]]
    res = {}
    for a, d in ARMS.items():
        code = {s: (D / d / s / f"{s}.sysml").read_text(encoding="utf-8") for s in ids}
        cov = [sum(t in norm(code[s]) for t in terms[s]) / len(terms[s]) for s in named]
        lines = {s: sum(1 for ln in code[s].splitlines() if ln.strip()) for s in ids}
        valid = {s: (diag[s]["valid"] if a == "forge" else
                     json.loads((D / d / s / "meta.json").read_text())["validation"]["is_valid"]) for s in ids}
        bands = {}
        for lo, hi in BINS:
            ss = [s for s in ids if lines[s] >= lo and (hi is None or lines[s] < hi)]
            bands[f"{lo}-{hi or 'inf'}"] = {"n": len(ss), "valid_pct": 100 * sum(valid[s] for s in ss) / len(ss) if ss else None}
        res[a] = {"median_lines": st.median(lines.values()),
                  "median_elements": {k: st.median(len(re.findall(p, code[s])) for s in ids) for k, p in KW.items()},
                  "component_coverage_pct": 100 * st.mean(cov),
                  "all_components_pct": 100 * sum(c == 1 for c in cov) / len(cov),
                  "valid_by_size": bands}
    out = {"n": len(ids), "n_with_named_components": len(named),
           "median_named_components": st.median(len(terms[s]) for s in named), "arms": res}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "richness.json").write_text(json.dumps(out, indent=1) + "\n")
    L = [f"# Model richness, component coverage, size-stratified validity (n = {len(ids)})", "",
         f"Component coverage over the {len(named)} requirements that name components in bold "
         f"(median {out['median_named_components']:g} per requirement).", "",
         "| Arm | median lines | " + " | ".join(KW) + " | components covered | all covered |",
         "|---|---|" + "---|" * len(KW) + "---|---|"]
    for a, r in res.items():
        L.append(f"| {a} | {r['median_lines']:g} | " + " | ".join(f"{r['median_elements'][k]:g}" for k in KW)
                 + f" | {r['component_coverage_pct']:.1f}% | {r['all_components_pct']:.1f}% |")
    L += ["", "Valid compile rate by model size (non-blank lines; unpaired within a band):", "",
          "| lines | " + " | ".join(res) + " |", "|---|" + "---|" * len(res)]
    for b in res["naive"]["valid_by_size"]:
        L.append(f"| {b} | " + " | ".join(
            (f"{res[a]['valid_by_size'][b]['valid_pct']:.1f}% (n={res[a]['valid_by_size'][b]['n']})"
             if res[a]["valid_by_size"][b]["n"] else "–") for a in res) + " |")
    (OUT / "richness.md").write_text("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
