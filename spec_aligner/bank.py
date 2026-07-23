"""Load and validate the question bank (questions.json)."""

from __future__ import annotations

import json
from pathlib import Path

BANK_PATH = Path(__file__).parent / "questions.json"
ORIGINS = {"nl", "sysml", "both"}


def load(path: str | Path = BANK_PATH) -> dict:
    bank = json.loads(Path(path).read_text(encoding="utf-8"))
    validate(bank)
    return bank


def universal(bank: dict) -> list[dict]:
    """Universal questions with options resolved, ready for answering/scoring."""
    ordinal = set(bank["scoring"].get("ordinal_option_sets", []))
    out = []
    for q in bank["universal"]:
        q = dict(q)
        if "options_ref" in q:
            ref = q.pop("options_ref")
            q["options"] = list(bank["option_sets"][ref])
            if ref in ordinal:
                q["ordinal"] = True
        q["origin"] = "both"
        q["tier"] = "universal"
        out.append(q)
    return out


def template_index(bank: dict) -> dict[str, dict]:
    return {t["id"]: t for t in bank["templates"]}


def validate(bank: dict) -> None:
    for key in ("option_sets", "answering_protocol", "universal", "templates",
                "instantiation_rules", "scoring"):
        assert key in bank, f"questions.json missing '{key}'"

    ids: set[str] = set()
    for q in bank["universal"]:
        assert q["id"] not in ids, f"duplicate question id {q['id']}"
        ids.add(q["id"])
        assert ("options_ref" in q) ^ ("options" in q), \
            f"{q['id']}: need exactly one of options/options_ref"
        if "options_ref" in q:
            assert q["options_ref"] in bank["option_sets"], f"{q['id']}: unknown option set"
        assert q.get("category"), f"{q['id']}: missing category"
    for q in bank["universal"]:
        dep = q.get("depends_on")
        if dep:
            assert dep["question"] in ids, f"{q['id']}: depends_on unknown {dep['question']}"

    tids: set[str] = set()
    for t in bank["templates"]:
        assert t["id"] not in tids, f"duplicate template id {t['id']}"
        tids.add(t["id"])
        assert ("options" in t) ^ ("options_rule" in t), \
            f"{t['id']}: need exactly one of options/options_rule"
        assert t["max_instances"] > 0, f"{t['id']}: bad max_instances"
        for slot in t["slots"]:
            assert f"⟨{slot}⟩" in t["pattern"], f"{t['id']}: slot '{slot}' not in pattern"

    sc = bank["scoring"]
    for key in ("aligned", "conflict", "missing_in_model", "unverifiable",
                "extra_in_model_origin_sysml", "extra_in_model_origin_other"):
        assert key in sc["credit"], f"scoring.credit missing '{key}'"
    for key in ("negative_answers", "negative_prefix", "reliability_threshold"):
        assert key in sc, f"scoring missing '{key}'"