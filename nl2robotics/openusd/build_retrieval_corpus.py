"""Build 500 executable OpenUSD cases and 1,500 transparent RAG pairs.

The stable O001-O100 stages seed four controlled physical-parameter variants
each. Two additional NL formulations are attached to every executable stage.
Structural lineage stays explicit so related stage variants cannot dominate a
single retrieval result set.
"""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import re


ROOT = Path(__file__).with_name("examples")
MODELS = ROOT / "models"
SEMANTIC_CASES = 500
FACTORS = (0.85, 0.95, 1.05, 1.15)

_SCALAR_ATTRIBUTE = re.compile(
    r"(?m)^(\s*(?:float|double)\s+)([A-Za-z_:][A-Za-z0-9_:]*)"
    r"(\s*=\s*)([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
)
_TIME_CODES = re.compile(
    r"(?m)^(\s*)(timeCodesPerSecond)(\s*=\s*)"
    r"([-+]?\d+(?:\.\d+)?)"
)

_ATTRIBUTE_PREFERENCES = {
    "joint_drives": ("drive:angular:physics:targetPosition",
                     "drive:linear:physics:targetPosition", "physics:upperLimit",
                     "physics:mass"),
    "geometry_transforms": ("radius", "height", "size", "physics:mass"),
    "rigid_body_collision": ("physics:mass", "physics:restitution"),
    "mass_inertia": ("physics:mass",),
    "joint_topology": ("physics:upperLimit", "physics:mass"),
    "articulations": ("physics:upperLimit", "physics:mass"),
    "materials_contact": ("physics:staticFriction", "physics:restitution"),
    "environments": ("physics:mass", "physics:gravityMagnitude"),
    "sensor_placement": ("physics:mass",),
    "stage_metadata": ("physics:gravityMagnitude", "timeCodesPerSecond"),
}


def _number(value: float) -> str:
    return f"{value:.10g}"


def _words(identifier: str) -> str:
    return identifier.replace(":", " ").replace("_", " ")


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


def _semantic_base(existing: list[dict]) -> list[dict]:
    """Return O001-O100, bootstrapping rate scenarios from a fresh core20."""
    available = [deepcopy(row) for row in existing
                 if 1 <= int(row["id"][1:]) <= 100]
    if len(available) == 100:
        return available
    if len(available) != 20:
        raise RuntimeError("OpenUSD corpus must contain O001-O020 or O001-O100")

    semantic = []
    for row in available:
        row.update({
            "tier": "core", "semantic_case_id": row["id"],
            "lineage_id": row["id"], "variant_type": "executable_case",
        })
        semantic.append(row)
    for variant, rate in enumerate((30, 50, 90, 240), 1):
        for offset, source in enumerate(available, 1):
            case_id = f"O{variant * 20 + offset:03d}"
            stage = (ROOT / source["model"]).read_text(encoding="utf-8")
            model = f"models/{case_id}.usda"
            (ROOT / model).write_text(_set_rate(stage, rate), encoding="utf-8")
            row = deepcopy(source)
            row.update({
                "id": case_id,
                "tier": "expanded",
                "difficulty": "intermediate" if variant < 3 else "advanced",
                "requirement": _rate_requirement(source["requirement"], rate),
                "model": model,
                "provenance": "team-authored controlled sampling-rate scenario",
                "semantic_case_id": case_id,
                "lineage_id": source["id"],
                "variant_type": "controlled_sampling_rate",
                "tags": [*source["tags"], f"rate-{rate}-hz"],
            })
            semantic.append(row)
    return semantic


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


def _vary_scalar(stage: str, category: str, factor: float) -> tuple[str, str, float]:
    candidates = [match for match in _SCALAR_ATTRIBUTE.finditer(stage)
                  if float(match.group(4)) != 0.0]
    time_match = _TIME_CODES.search(stage)
    if time_match and float(time_match.group(4)) != 0.0:
        candidates.append(time_match)
    preferences = _ATTRIBUTE_PREFERENCES[category]
    match = next(
        (candidate for name in preferences for candidate in candidates
         if candidate.group(2) == name),
        candidates[0] if candidates else None,
    )
    if match is None:
        raise RuntimeError("OpenUSD stage has no controllable scalar attribute")
    value = float(match.group(4)) * factor
    if match.group(2) == "timeCodesPerSecond":
        value = round(value)
    updated = stage[:match.start(4)] + _number(value) + stage[match.end(4):]
    return updated, match.group(2), value


def _operating_variant(source: dict, case_id: str, factor: float,
                       variant: int) -> dict:
    stage = (ROOT / source["model"]).read_text(encoding="utf-8")
    stage, attribute, value = _vary_scalar(stage, source["category"], factor)
    model = f"models/{case_id}.usda"
    (ROOT / model).write_text(stage, encoding="utf-8")
    row = deepcopy(source)
    row.update({
        "id": case_id,
        "tier": "augmented",
        "difficulty": "intermediate" if variant < 3 else "advanced",
        "requirement": (
            source["requirement"].rstrip(".") +
            f". For controlled operating variant {variant}, override the "
            f"baseline {_words(attribute)} value with {_number(value)}."
        ),
        "model": model,
        "provenance": "team-authored controlled OpenUSD operating variant",
        "semantic_case_id": case_id,
        "lineage_id": source.get("lineage_id", source["id"]),
        "variant_type": f"controlled_scalar_attribute_variant_{variant}",
        "tags": [
            *source["tags"], "controlled-parameter",
            attribute.replace(":", "-").lower(), f"operating-variant-{variant}",
        ],
    })
    return row


def build() -> list[dict]:
    existing = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    base = _semantic_base(existing)

    semantic = []
    for row in base:
        row["semantic_case_id"] = row["id"]
        row["lineage_id"] = row.get("lineage_id", row["id"])
        row["variant_type"] = "executable_case"
        semantic.append(row)
    for variant, factor in enumerate(FACTORS, 1):
        for offset, source in enumerate(base, 1):
            case_id = f"O{variant * 100 + offset:03d}"
            semantic.append(_operating_variant(source, case_id, factor, variant))

    rows = list(semantic)
    for style in range(2):
        for offset, source in enumerate(semantic, 1):
            row = deepcopy(source)
            row["id"] = f"O{501 + style * SEMANTIC_CASES + offset - 1:03d}"
            row["requirement"] = _paraphrase(source["requirement"], style)
            row["tier"] = "paraphrase"
            row["variant_type"] = f"semantic_preserving_paraphrase_{style + 1}"
            row["provenance"] = "team-authored semantic-preserving paraphrase"
            rows.append(row)

    semantic_ids = [row["id"] for row in semantic]
    style_one = [row["id"] for row in rows[500:1000]]
    style_two = [row["id"] for row in rows[1000:1500]]
    subsets = {
        "core20": semantic_ids[:20],
        "semantic100": semantic_ids[:100],
        "full300": [*semantic_ids[:100], *style_one[:100], *style_two[:100]],
        "semantic500": semantic_ids,
        "full1500": [row["id"] for row in rows],
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
