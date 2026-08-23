"""Expand 100 executable Modelica cases into 300 transparent RAG pairs."""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path


ROOT = Path(__file__).with_name("examples")


def _paraphrase(text: str, style: int) -> str:
    replacements = {
        "Model ": ("Construct a Modelica model of ", "Implement in Modelica "),
        "Create ": ("Construct ", "Build "),
        "Represent ": ("Model ", "Implement "),
        "Simulate ": ("Model and simulate ", "Implement the dynamics of "),
    }
    for prefix, variants in replacements.items():
        if text.startswith(prefix):
            body = text[len(prefix):]
            return variants[style] + body[:1].lower() + body[1:]
    wrappers = (
        "Construct an executable Modelica robotics model for this requirement: ",
        "Implement the following robotics dynamics as a self-contained Modelica model: ",
    )
    return wrappers[style] + text[:1].lower() + text[1:]


def build() -> list[dict]:
    existing = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    base = [
        deepcopy(row) for row in existing
        if 1 <= int(row["id"][1:]) <= 100
    ]
    if len(base) != 100:
        raise RuntimeError("Modelica semantic corpus must contain M001-M100")
    rows = []
    for row in base:
        row["semantic_case_id"] = row["id"]
        row["lineage_id"] = row.get("archetype", row["id"])
        row["variant_type"] = "executable_case"
        rows.append(row)
    for style in range(2):
        for offset, source in enumerate(base, 1):
            row = deepcopy(source)
            row["id"] = f"M{101 + style * 100 + offset - 1:03d}"
            row["requirement"] = _paraphrase(source["requirement"], style)
            row["tier"] = "paraphrase"
            row["semantic_case_id"] = source["id"]
            row["lineage_id"] = source.get("archetype", source["id"])
            row["variant_type"] = f"semantic_preserving_paraphrase_{style + 1}"
            row["source"] = "team-authored semantic-preserving paraphrase"
            rows.append(row)

    subsets = json.loads((ROOT / "corpus_subsets.json").read_text(encoding="utf-8"))
    subsets["full100"] = [f"M{number:03d}" for number in range(1, 101)]
    subsets["full300"] = [f"M{number:03d}" for number in range(1, 301)]
    (ROOT / "manifest.json").write_text(
        json.dumps(rows, indent=2) + "\n", encoding="utf-8"
    )
    (ROOT / "corpus_subsets.json").write_text(
        json.dumps(subsets, indent=2) + "\n", encoding="utf-8"
    )
    return rows


if __name__ == "__main__":
    print(f"wrote {len(build())} Modelica retrieval pairs")
