"""Build 500 executable Modelica cases and 1,500 transparent RAG pairs.

The first 100 cases remain stable. Each receives four controlled operating
variants that change a real model parameter (or, when a compact equation-only
model has no declared parameter, an explicitly authored dynamic-rate scale).
Two semantic-preserving NL formulations are then added for every executable
case. Lineage metadata keeps variants of one structural archetype from
crowding retrieval results.
"""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import re


ROOT = Path(__file__).with_name("examples")
SEMANTIC_CASES = 500
FACTORS = (0.90, 0.97, 1.03, 1.10)

_MODEL = re.compile(r"(?m)^(\s*model\s+)([A-Za-z_]\w*)")
_PARAMETER = re.compile(
    r"(?m)^(\s*parameter\s+Real\s+)([A-Za-z_]\w*)"
    r"((?:\([^)]*\))?\s*=\s*)"
    r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)(\s*;)"
)
_COMPONENT_ARGUMENT = re.compile(
    r"\b([A-Za-z_]\w*)\s*=\s*"
    r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
)
_DERIVATIVE = re.compile(r"(?m)^(\s*der\([^)]+\)\s*=\s*)([^;]+)(;)")

_PREFERRED_ARGUMENTS = (
    "J", "mass", "m", "d", "c", "R", "L", "k", "V", "height",
    "tau_constant", "uMax", "duration", "ratio", "efficiency",
)
_IGNORED_ARGUMENTS = {"start", "fixed"}
_PREFERRED_PARAMETERS = (
    "inertia", "heatCapacity", "cooling", "pressureDrop", "forwardSpeed",
    "damping", "stiffness", "resistance", "inductance", "capacitance",
    "mass", "length", "radius", "area", "gain", "timeConstant",
)
_SENSITIVE_PARAMETERS = (
    "target", "reference", "maximum", "minimum", "restart", "ambient",
    "limit", "threshold", "setpoint",
)


def _number(value: float) -> str:
    return f"{value:.10g}"


def _words(identifier: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", " ", identifier).replace("_", " ").lower()


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


def _rename_model(code: str, case_id: str) -> str:
    match = _MODEL.search(code)
    if not match:
        raise RuntimeError("Modelica source has no top-level model")
    old_name = match.group(2)
    new_name = f"Rag{case_id}"
    code = _MODEL.sub(rf"\g<1>{new_name}", code, count=1)
    updated, count = re.subn(
        rf"(?m)^(\s*end\s+){re.escape(old_name)}(\s*;)",
        rf"\g<1>{new_name}\g<2>", code, count=1,
    )
    if count != 1:
        raise RuntimeError(f"could not rename end statement for {old_name}")
    return updated


def _vary_declared_parameter(code: str, factor: float) -> tuple[str, str, float] | None:
    candidates = [match for match in _PARAMETER.finditer(code)
                  if float(match.group(4)) != 0.0
                  and not any(token in match.group(2).lower()
                              for token in _SENSITIVE_PARAMETERS)]
    if not candidates:
        return None
    match = next(
        (item for name in _PREFERRED_PARAMETERS for item in candidates
         if item.group(2) == name),
        candidates[0],
    )
    value = float(match.group(4)) * factor
    updated = code[:match.start(4)] + _number(value) + code[match.end(4):]
    return updated, match.group(2), value


def _vary_mobile_geometry(code: str, factor: float) -> tuple[str, str, float]:
    """Scale wheel radius and axle track together, preserving turn rate."""
    model = _MODEL.search(code)
    assert model is not None
    line_end = code.find("\n", model.end())
    declaration = f"\n  parameter Real mobileGeometryScale = {_number(factor)};"
    code = code[:line_end] + declaration + code[line_end:]
    for name in ("wheelRadius", "axleTrack"):
        pattern = re.compile(
            rf"(?m)^(\s*parameter\s+Real\s+{name}(?:\([^)]*\))?\s*=\s*)"
            r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)(\s*;)"
        )
        code, count = pattern.subn(
            rf"\g<1>\g<2> * mobileGeometryScale\g<3>", code, count=1
        )
        if count != 1:
            raise RuntimeError(f"missing {name} for coupled mobile geometry variant")
    return code, "mobileGeometryScale", factor


def _vary_component_argument(code: str, factor: float) -> tuple[str, str, float] | None:
    candidates = [match for match in _COMPONENT_ARGUMENT.finditer(code)
                  if match.group(1) not in _IGNORED_ARGUMENTS
                  and float(match.group(2)) != 0.0]
    if not candidates:
        return None
    match = next(
        (item for name in _PREFERRED_ARGUMENTS for item in candidates
         if item.group(1) == name),
        candidates[0],
    )
    value = float(match.group(2)) * factor
    updated = code[:match.start(2)] + _number(value) + code[match.end(2):]
    return updated, match.group(1), value


def _vary_dynamic_rate(code: str, factor: float) -> tuple[str, str, float]:
    derivative = _DERIVATIVE.search(code)
    if not derivative:
        raise RuntimeError("Modelica source has no controllable numeric parameter")
    model = _MODEL.search(code)
    assert model is not None
    line_end = code.find("\n", model.end())
    declaration = f"\n  parameter Real dynamicRateScale = {_number(factor)};"
    code = code[:line_end] + declaration + code[line_end:]
    derivative = _DERIVATIVE.search(code)
    assert derivative is not None
    replacement = (
        derivative.group(1) + "dynamicRateScale * (" +
        derivative.group(2).strip() + ")" + derivative.group(3)
    )
    return code[:derivative.start()] + replacement + code[derivative.end():], \
        "dynamicRateScale", factor


def _operating_variant(source: dict, case_id: str, factor: float,
                       variant: int) -> dict:
    source_path = ROOT / source["model_file"]
    code = _rename_model(source_path.read_text(encoding="utf-8"), case_id)
    if source["id"] in {"M016", "M024"}:
        changed = _vary_mobile_geometry(code, factor)
        mechanism = "coupled_kinematic_parameter"
    else:
        changed = _vary_declared_parameter(code, factor)
        mechanism = "declared_parameter"
    if changed is None:
        changed = _vary_component_argument(code, factor)
        mechanism = "component_parameter"
    if changed is None:
        changed = _vary_dynamic_rate(code, factor)
        mechanism = "dynamic_rate_scale"
    code, parameter, value = changed
    model_file = f"models/{case_id}.mo"
    (ROOT / model_file).write_text(code, encoding="utf-8")

    row = deepcopy(source)
    row.update({
        "id": case_id,
        "tier": "augmented",
        "difficulty": "intermediate" if variant < 3 else "advanced",
        "requirement": (
            source["requirement"].rstrip(".") +
            f". For controlled operating variant {variant}, override the "
            f"baseline {_words(parameter)} value with {_number(value)}."
        ),
        "model_file": model_file,
        "source": "team-authored controlled Modelica operating variant",
        "semantic_case_id": case_id,
        "lineage_id": source.get("lineage_id", source.get("archetype", source["id"])),
        "variant_type": f"controlled_{mechanism}_variant_{variant}",
        "tags": [
            *source["tags"], "controlled-parameter", parameter.lower(),
            f"operating-variant-{variant}",
        ],
    })
    for prop in row.get("properties", []):
        prop["id"] = re.sub(r"^M\d+", case_id, prop["id"])
    return row


def build() -> list[dict]:
    existing = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    base = [deepcopy(row) for row in existing if 1 <= int(row["id"][1:]) <= 100]
    if len(base) != 100:
        raise RuntimeError("Modelica semantic corpus must contain M001-M100")

    semantic = []
    for row in base:
        row["semantic_case_id"] = row["id"]
        row["lineage_id"] = row.get("lineage_id", row.get("archetype", row["id"]))
        row["variant_type"] = "executable_case"
        semantic.append(row)
    for variant, factor in enumerate(FACTORS, 1):
        for offset, source in enumerate(base, 1):
            case_id = f"M{variant * 100 + offset:03d}"
            semantic.append(_operating_variant(source, case_id, factor, variant))

    rows = list(semantic)
    for style in range(2):
        for offset, source in enumerate(semantic, 1):
            row = deepcopy(source)
            row["id"] = f"M{501 + style * SEMANTIC_CASES + offset - 1:03d}"
            row["requirement"] = _paraphrase(source["requirement"], style)
            row["tier"] = "paraphrase"
            row["variant_type"] = f"semantic_preserving_paraphrase_{style + 1}"
            row["source"] = "team-authored semantic-preserving paraphrase"
            rows.append(row)

    semantic_ids = [row["id"] for row in semantic]
    style_one = [row["id"] for row in rows[500:1000]]
    style_two = [row["id"] for row in rows[1000:1500]]
    subsets = json.loads((ROOT / "corpus_subsets.json").read_text(encoding="utf-8"))
    subsets.update({
        "full100": semantic_ids[:100],
        "full300": [*semantic_ids[:100], *style_one[:100], *style_two[:100]],
        "semantic500": semantic_ids,
        "full1500": [row["id"] for row in rows],
    })
    (ROOT / "manifest.json").write_text(
        json.dumps(rows, indent=2) + "\n", encoding="utf-8"
    )
    (ROOT / "corpus_subsets.json").write_text(
        json.dumps(subsets, indent=2) + "\n", encoding="utf-8"
    )
    return rows


if __name__ == "__main__":
    print(f"wrote {len(build())} Modelica retrieval pairs")
