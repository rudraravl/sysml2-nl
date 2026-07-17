"""Assemble and render the per-sample alignment report."""

from __future__ import annotations

import json
from pathlib import Path


def report_data(sample_id: str, bank: dict, questions: list[dict], result: dict,
                mode: str = "full") -> dict:
    uni = sum(1 for q in questions if q.get("tier") == "universal")
    return {
        "sample": sample_id,
        "bank_version": bank["version"],
        "mode": mode,
        "summary": {
            "similarity": result["similarity"],
            "scored": result["scored"],
            "questions": {"total": len(questions), "universal": uni,
                          "instantiated": len(questions) - uni},
            "counts": result["counts"],
            "reliability": result["reliability"],
            "reliability_flag": result["reliability_flag"],
            "domain_mismatch": result["domain_mismatch"],
        },
        "per_category": result["per_category"],
        "mismatches": result["mismatches"],
        "answers": result["rows"],
    }


def write_json(path: str | Path, data: dict) -> None:
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                          encoding="utf-8")


def render_markdown(data: dict) -> str:
    s = data["summary"]
    sim = "insufficient signal (nothing scored)" if s["similarity"] is None \
        else f"**{s['similarity']:.4f}** over {s['scored']} scored questions"
    lines = [
        f"# Alignment report – {data['sample']}",
        "",
        f"- Similarity: {sim}",
        f"- Questions: {s['questions']['total']} "
        f"(universal {s['questions']['universal']}, instantiated {s['questions']['instantiated']})",
        f"- Outcomes: " + ", ".join(f"{k} {v}" for k, v in sorted(s["counts"].items())),
        f"- Answerer reliability (distractors): nl {s['reliability']['nl']}, "
        f"sysml {s['reliability']['sysml']}"
        + (" **UNRELIABLE - review answers**" if s["reliability_flag"] else ""),
    ]
    if s["domain_mismatch"]:
        lines.append("- **DOMAIN MISMATCH (canary): the two documents may not describe the same system.**")
    if data["per_category"]:
        lines += ["", "## Per-category alignment", "", "| Category | Score |", "| --- | --- |"]
        lines += [f"| {c} | {v:.4f} |" for c, v in data["per_category"].items()]
    lines += ["", "## Mismatches", ""]
    if not data["mismatches"]:
        lines.append("None.")
    for m in data["mismatches"]:
        lines += [
            f"### [{m['severity']}] {m['qid']} ({m['category']}, {m['outcome']})",
            "",
            m["text"],
            "",
            f"- NL answered `{m['nl']['answer']}`"
            + (f" – \"{m['nl']['evidence']}\"" if m["nl"]["evidence"] else ""),
            f"- SysML answered `{m['sysml']['answer']}`"
            + (f" – `{m['sysml']['evidence']}`" if m["sysml"]["evidence"] else ""),
        ]
        if m.get("metamodel_refs"):
            lines.append(f"- Metamodel refs: {', '.join(m['metamodel_refs'])}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"
