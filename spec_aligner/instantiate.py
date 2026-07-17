"""Instantiate Tier-2 template questions for one sample (question-writer LLM)."""

from __future__ import annotations

import json

from .bank import template_index
from .jsonx import extract_json


def instantiate(bank: dict, nl: str, sysml: str, sample_id: str, ask) -> tuple[list[dict], list[dict]]:
    """One LLM call -> (validated questions, rejected items with reasons)."""
    raw = ask(writer_prompt(bank, nl, sysml, sample_id))
    data = extract_json(raw)
    items = data.get("questions", data) if isinstance(data, dict) else data
    if not isinstance(items, list):
        raise ValueError("question writer did not return a list")
    return validate_instances(items, bank, nl, sysml, sample_id)


def writer_prompt(bank: dict, nl: str, sysml: str, sample_id: str) -> str:
    rules = bank["instantiation_rules"]
    lines = [
        "You are a question writer for NL <-> SysML v2 alignment checking.",
        "Read BOTH documents below, then instantiate questions from the templates:",
        "fill each ⟨slot⟩ with this sample's actual entities, properties, values, states, actions.",
        "",
        "## Templates",
        json.dumps(bank["templates"], ensure_ascii=False, indent=1),
        "",
        "## Rules",
        f"- target count: {rules['target_instance_count']['min']}-{rules['target_instance_count']['max']} questions; priorities: "
        + " ".join(rules["priorities"]),
        f"- vocabulary: {rules['vocabulary_bridging']}",
        f"- origin: {rules['origin_tagging']}",
        f"- options: {rules['option_harvesting']}",
        f"- distractors: {rules['distractor_verification']}",
        f"- anchors: {rules['anchors']}",
        "- never include 'not_stated' in options (it is appended automatically); never leave a ⟨slot⟩ unfilled.",
        "",
        "## Output",
        'Strict JSON only: {"questions": [{"template_id": str, "text": str, "options": [str, ...],',
        ' "origin": "nl"|"sysml"|"both"|"fabricated", "slots": {"<slot>": "<value>", ...},',
        ' "anchors": {"nl_span": str|null, "sysml_lines": [int, int]|null}}]}',
        "",
        "## Document A - natural-language description",
        nl.strip(),
        "",
        "## Document B - SysML v2 model",
        "```sysml",
        sysml.strip(),
        "```",
    ]
    return "\n".join(lines)


def validate_instances(items: list, bank: dict, nl: str, sysml: str,
                       sample_id: str) -> tuple[list[dict], list[dict]]:
    tpl = template_index(bank)
    cap = bank["instantiation_rules"]["target_instance_count"]["max"]
    lo_nl, lo_sys = nl.lower(), sysml.lower()
    kept: list[dict] = []
    rejected: list[dict] = []
    per: dict[str, int] = {}

    for it in items:
        reason = _check(it, tpl, per, lo_nl, lo_sys)
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
    return kept, rejected


def _check(it, tpl: dict, per: dict, lo_nl: str, lo_sys: str) -> str | None:
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
    origin = it.get("origin")
    if fabricated != (origin == "fabricated"):
        return "origin 'fabricated' is for distractor templates only (and required there)"
    if not fabricated and origin not in ("nl", "sysml", "both"):
        return f"bad origin {origin!r}"
    slots = it.get("slots") or {}
    for name, stype in t["slots"].items():
        value = str(slots.get(name) or "").strip()
        if not value:
            return f"missing slot '{name}'"
        if stype.startswith("fabricated") and (value.lower() in lo_nl or value.lower() in lo_sys):
            return f"fabricated slot '{name}'={value!r} appears in a document"
    return None
