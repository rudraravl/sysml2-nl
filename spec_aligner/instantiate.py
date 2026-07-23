"""Instantiate Tier-2 template questions for one sample (question-writer LLM)."""

from __future__ import annotations

import json

from .bank import template_index
from .jsonx import extract_json


SOURCE_MODES = {"nl", "sysml", "both"}
SOURCE_DEPENDENT_RULES = {
    "anchors",
    "distractor_verification",
    "generator_input",
    "option_harvesting",
    "origin_tagging",
}


def instantiate(bank: dict, nl: str, sysml: str, sample_id: str, ask, *,
                source_mode: str = "both", min_questions: int | None = None,
                max_questions: int | None = None) -> tuple[list[dict], list[dict]]:
    """One LLM call -> (validated questions, rejected items with reasons)."""
    if source_mode not in SOURCE_MODES:
        raise ValueError(f"unknown question source mode: {source_mode}")
    raw = ask(writer_prompt(bank, nl, sysml, sample_id, source_mode=source_mode,
                            min_questions=min_questions, max_questions=max_questions))
    data = extract_json(raw)
    items = data.get("questions", data) if isinstance(data, dict) else data
    if not isinstance(items, list):
        raise ValueError("question writer did not return a list")
    allowed = {source_mode} if source_mode != "both" else {"nl", "sysml", "both"}
    return validate_instances(items, bank, nl, sysml, sample_id,
                              cap=max_questions, allowed_origins=allowed,
                              allow_distractors=source_mode == "both")


def writer_prompt(bank: dict, nl: str, sysml: str, sample_id: str, *,
                  source_mode: str = "both", min_questions: int | None = None,
                  max_questions: int | None = None) -> str:
    rules = bank["instantiation_rules"]
    if source_mode not in SOURCE_MODES:
        raise ValueError(f"unknown question source mode: {source_mode}")
    target = rules["target_instance_count"]
    low = min_questions if min_questions is not None else target["min"]
    high = max_questions if max_questions is not None else target["max"]
    if low < 1 or high < low:
        raise ValueError("invalid instantiated-question range")

    if source_mode == "both":
        source_instruction = "Read BOTH documents below, then instantiate questions from the templates:"
        origin_instruction = "Use origin 'nl', 'sysml', or 'both' according to the supplied rules."
    elif source_mode == "nl":
        source_instruction = "Read ONLY the natural-language description below and instantiate questions from the templates:"
        origin_instruction = "Set origin to 'nl' for every non-distractor question. Do not anticipate or infer anything from candidate SysML."
    else:
        source_instruction = "Read ONLY the SysML v2 model below and instantiate questions from the templates:"
        origin_instruction = "Set origin to 'sysml' for every non-distractor question."

    lines = [
        "You are a question writer for NL <-> SysML v2 alignment checking.",
        source_instruction,
        "fill each ⟨slot⟩ with this sample's actual entities, properties, values, states, actions.",
        "",
        "## Templates",
        json.dumps(_templates_for_source(bank, source_mode), ensure_ascii=False, indent=1),
        "",
        "## Rules",
        f"- target count: {low}-{high} questions; priorities: "
        + " ".join(rules["priorities"]),
        f"- {origin_instruction}",
        *[f"- {key}: {val}" for key, val in rules.items()
          if isinstance(val, str)
          and key != "output_id_format"
          and (source_mode == "both" or key not in SOURCE_DEPENDENT_RULES)],
        *_source_specific_rules(source_mode),
        "- never include 'not_stated' in options (it is appended automatically); never leave a ⟨slot⟩ unfilled.",
        "",
        "## Output",
        'Strict JSON only: {"questions": [{"template_id": str, "text": str, "options": [str, ...],',
        ' "origin": "nl"|"sysml"|"both"|"fabricated", "slots": {"<slot>": "<value>", ...},',
        ' "anchors": {"nl_span": str|null, "sysml_lines": [int, int]|null}}]}',
        "",
    ]
    if source_mode in ("nl", "both"):
        lines += ["## Document A - natural-language description", nl.strip(), ""]
    if source_mode in ("sysml", "both"):
        lines += ["## Document B - SysML v2 model", "```sysml", sysml.strip(), "```"]
    return "\n".join(lines)


def _templates_for_source(bank: dict, source_mode: str) -> list[dict]:
    """Return prompt-only template copies whose instructions match visible input."""
    templates = []
    for original in bank["templates"]:
        if source_mode != "both" and original["category"] == "distractor":
            continue
        template = dict(original)
        if source_mode != "both":
            source = "the natural-language description" if source_mode == "nl" else "the SysML model"
            for key in ("instantiate_when", "options_rule"):
                value = template.get(key)
                if isinstance(value, str):
                    value = value.replace("BOTH modalities", source)
                    value = value.replace("both modalities", source)
                    value = value.replace("either modality", "the visible source document")
                    template[key] = value
        templates.append(template)
    return templates


def _source_specific_rules(source_mode: str) -> list[str]:
    if source_mode == "both":
        return []
    source = "natural-language description" if source_mode == "nl" else "SysML model"
    return [
        f"- Harvest named options and anchors only from the {source}.",
        "- Do not instantiate distractor templates in single-source mode.",
    ]


def validate_instances(items: list, bank: dict, nl: str, sysml: str,
                       sample_id: str, *, cap: int | None = None,
                       allowed_origins: set[str] | None = None,
                       allow_distractors: bool = True) -> tuple[list[dict], list[dict]]:
    tpl = template_index(bank)
    cap = cap or bank["instantiation_rules"]["target_instance_count"]["max"]
    allowed_origins = allowed_origins or {"nl", "sysml", "both"}
    lo_nl, lo_sys = nl.lower(), sysml.lower()
    kept: list[dict] = []
    rejected: list[dict] = []
    per: dict[str, int] = {}

    for it in items:
        reason = _check(it, tpl, per, lo_nl, lo_sys, allowed_origins,
                        allow_distractors)
        if reason:
            rejected.append({"item": it, "reason": reason})
            continue
        t = tpl[it["template_id"]]
        per[t["id"]] = per.get(t["id"], 0) + 1
        q = {
            "id": f"Q-{sample_id}-{t['id']}-{per[t['id']]}",
            "template_id": t["id"],
            "category": t["category"],
            "tier": "instantiated",
            "text": str(it["text"]).strip(),
            "options": [str(o) for o in it["options"]],
            "origin": it["origin"],
            "slots": it.get("slots") or {},
            "anchors": it.get("anchors") or {},
        }
        if "expected_answer" in t:
            q["expected_answer"] = t["expected_answer"]
        kept.append(q)
        if len(kept) >= cap:
            break
    _link_requirement_family(kept)
    return kept, rejected


def _link_requirement_family(kept: list[dict]) -> None:
    """T-REQ-02/03 depend on the T-REQ-01 with the same topic slot - a missing
    requirement then costs one penalty, not a cascade."""
    parents = {}
    for q in kept:
        if q["template_id"] == "T-REQ-01":
            parents[str(q["slots"].get("topic", "")).strip().lower()] = q["id"]
    for q in kept:
        if q["template_id"] in ("T-REQ-02", "T-REQ-03"):
            parent = parents.get(str(q["slots"].get("topic", "")).strip().lower())
            if parent:
                q["depends_on"] = {"question": parent, "answer": "yes"}


def _check(it, tpl: dict, per: dict, lo_nl: str, lo_sys: str,
           allowed_origins: set[str], allow_distractors: bool) -> str | None:
    if not isinstance(it, dict):
        return "not an object"
    t = tpl.get(it.get("template_id"))
    if not t:
        return f"unknown template {it.get('template_id')!r}"
    if per.get(t["id"], 0) >= t["max_instances"]:
        return f"{t['id']} over max_instances"
    text = str(it.get("text") or "")
    if not text.strip():
        return "empty text"
    if "⟨" in text or "⟩" in text:
        return "unfilled slot in text"
    opts = it.get("options")
    if not isinstance(opts, list) or not 2 <= len(opts) <= 8:
        return "options must be a list of 2-8"
    opts = [str(o) for o in opts]
    if len(set(opts)) != len(opts):
        return "duplicate options"
    if "not_stated" in opts:
        return "not_stated must not be listed as an option"
    fabricated = t["category"] == "distractor"
    if fabricated and not allow_distractors:
        return "distractor templates are disabled in single-source mode"
    origin = it.get("origin")
    if fabricated != (origin == "fabricated"):
        return "origin 'fabricated' is for distractor templates only (and required there)"
    if not fabricated and origin not in allowed_origins:
        return f"bad origin {origin!r}"
    slots = it.get("slots") or {}
    for name, stype in t["slots"].items():
        value = str(slots.get(name) or "").strip()
        if not value:
            return f"missing slot '{name}'"
        if stype.startswith("fabricated") and (value.lower() in lo_nl or value.lower() in lo_sys):
            return f"fabricated slot '{name}'={value!r} appears in a document"
    return None
