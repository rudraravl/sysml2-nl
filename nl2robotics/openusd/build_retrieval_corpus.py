"""Build 100 executable OpenUSD cases and 300 transparent RAG pairs."""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import re


ROOT = Path(__file__).with_name("examples")
MODELS = ROOT / "models"


def _set_rate(stage: str, rate: int) -> str:
    updated, count = re.subn(
        r"(?m)^(\s*timeCodesPerSecond\s*=\s*)[-+]?\d+(?:\.\d+)?",
        rf"\g<1>{rate}", stage, count=1,
    )
    if count != 1:
        raise RuntimeError("stage has no authored timeCodesPerSecond")
    return updated


def _rate_requirement(text: str, rate: int) -> str:
    text = re.sub(
        r"sampled at \d+(?:\.\d+)? time codes per second",
        f"sampled at {rate} time codes per second", text,
    )
    if "time codes per second" not in text:
        text = text.rstrip(".") + f", authored at {rate} time codes per second."
    return text


def _paraphrase(text: str, style: int) -> str:
    replacements = {
        "Create ": ("Author ", "Build "),
        "Represent ": ("Model ", "Author "),
        "Connect ": ("Join ", "Construct an assembly that connects "),
        "Attach ": ("Mount ", "Add and attach "),
    }
    for prefix, variants in replacements.items():
        if text.startswith(prefix):
            body = text[len(prefix):]
            return variants[style] + body[:1].lower() + body[1:]
    wrappers = (
        "Author a textual USDA robotics scene that meets this requirement: ",
        "Build the equivalent portable UsdPhysics stage for this specification: ",
    )
    return wrappers[style] + text[:1].lower() + text[1:]


def build() -> list[dict]:
    existing = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    core = [
        deepcopy(row) for row in existing
        if 1 <= int(row["id"][1:]) <= 20
    ]
    if len(core) != 20:
        raise RuntimeError("OpenUSD core corpus must contain O001-O020")

    semantic = []
    for row in core:
        row["tier"] = "core"
        row["semantic_case_id"] = row["id"]
        row["lineage_id"] = row["id"]
        row["variant_type"] = "executable_case"
        semantic.append(row)
    rates = (30, 50, 90, 240)
    for variant, rate in enumerate(rates, 1):
        for base_index, source in enumerate(core, 1):
            number = variant * 20 + base_index
            case_id = f"O{number:03d}"
            source_stage = (ROOT / source["model"]).read_text(encoding="utf-8")
            model_path = MODELS / f"{case_id}.usda"
            model_path.write_text(_set_rate(source_stage, rate), encoding="utf-8")
            row = deepcopy(source)
            row.update({
                "id": case_id,
                "tier": "expanded",
                "difficulty": "intermediate" if variant < 3 else "advanced",
                "requirement": _rate_requirement(source["requirement"], rate),
                "model": f"models/{case_id}.usda",
                "provenance": "team-authored controlled sampling-rate scenario",
                "semantic_case_id": case_id,
                "lineage_id": source["id"],
                "variant_type": "controlled_sampling_rate",
                "tags": [*source["tags"], f"rate-{rate}-hz"],
            })
            semantic.append(row)

    rows = list(semantic)
    for style in range(2):
        for offset, source in enumerate(semantic, 1):
            row = deepcopy(source)
            row["id"] = f"O{101 + style * 100 + offset - 1:03d}"
            row["requirement"] = _paraphrase(source["requirement"], style)
            row["tier"] = "paraphrase"
            row["semantic_case_id"] = source["semantic_case_id"]
            row["variant_type"] = f"semantic_preserving_paraphrase_{style + 1}"
            row["provenance"] = "team-authored semantic-preserving paraphrase"
            rows.append(row)

    subsets = {
        "core20": [f"O{number:03d}" for number in range(1, 21)],
        "semantic100": [f"O{number:03d}" for number in range(1, 101)],
        "full300": [f"O{number:03d}" for number in range(1, 301)],
    }
    (ROOT / "manifest.json").write_text(
        json.dumps(rows, indent=2) + "\n", encoding="utf-8"
    )
    (ROOT / "corpus_subsets.json").write_text(
        json.dumps(subsets, indent=2) + "\n", encoding="utf-8"
    )
    return rows


if __name__ == "__main__":
    print(f"wrote {len(build())} OpenUSD retrieval pairs")
