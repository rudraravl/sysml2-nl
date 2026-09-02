"""Twin-blind answering: one modality per call, sharded into parallel LLM calls."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from .bank import language
from .jsonx import extract_json

EMPTY = {"answer": "not_stated", "evidence": "", "confidence": 0.0, "missing": True}


def answer_all(questions: list[dict], doc: str, modality: str, ask, bank: dict,
               shards: int = 5) -> dict[str, dict]:
    """Answer every question from one document. Returns qid -> answer record."""
    parts = shard(questions, shards)
    remap = bank["scoring"].get("nl_answer_remap", {}) if modality == "natural_language" else {}
    merged: dict[str, dict] = {}
    if len(parts) == 1:
        merged.update(_answer_shard(parts[0], doc, modality, ask, bank, remap))
    else:
        with ThreadPoolExecutor(max_workers=len(parts)) as ex:
            futs = [ex.submit(_answer_shard, qs, doc, modality, ask, bank, remap)
                    for qs in parts]
            for f in futs:
                merged.update(f.result())
    for q in questions:
        merged.setdefault(q["id"], dict(EMPTY))
    return merged


def shard(questions: list[dict], n: int) -> list[list[dict]]:
    if not questions:
        return [[]]
    n = max(1, min(int(n), len(questions)))
    size = -(-len(questions) // n)
    return [questions[i:i + size] for i in range(0, len(questions), size)]


def _answer_shard(questions, doc, modality, ask, bank, remap=None):
    return parse_answers(ask(answer_prompt(questions, doc, modality, bank)), questions,
                         remap=remap)


def answer_prompt(questions: list[dict], doc: str, modality: str, bank: dict) -> str:
    p = bank["answering_protocol"]
    lang = language(bank)
    nl = modality == "natural_language"
    world = p["nl_answerer_worldview"] if nl else (
        p.get("model_answerer_worldview")
        or p.get(f"{lang['id']}_answerer_worldview")
        or p["sysml_answerer_worldview"]
    )
    lines = [
        "You answer alignment questions from ONE document. The document is "
        + ("a natural-language system description." if nl else f"a {lang['label']}."),
        "",
        world,
        "",
        "Rules:",
    ]
    lines += [f"- {r}" for r in p["shared_rules"]]
    lines += [
        "- 'answer' must be EXACTLY one of the listed options, or 'not_stated'.",
        '- Output strict JSON only: {"answers": [{"qid": str, "answer": str, "evidence": str,'
        ' "confidence": float}]} with one record for EVERY question id listed below.',
        "",
        "## Questions",
    ]
    for q in questions:
        opts = " | ".join(list(q["options"]) + ["not_stated"])
        lines.append(f"- {q['id']} ({q['category']}) {q['text']}  [options: {opts}]")
    lines += ["", "## Document"]
    lines += [doc.strip()] if nl else [f"```{lang['fence']}", doc.strip(), "```"]
    return "\n".join(lines)


def parse_answers(raw: str, questions: list[dict],
                  remap: dict | None = None) -> dict[str, dict]:
    """remap: answers to coerce (e.g. NL side may not use the closed-world option
    'declared_without_value' - deterministic guard where prompt rules slip)."""
    data = extract_json(raw)
    rows = data.get("answers", data) if isinstance(data, dict) else data
    if not isinstance(rows, list):
        raise ValueError("answers is not a list")
    allowed = {q["id"]: list(q["options"]) + ["not_stated"] for q in questions}
    out: dict[str, dict] = {}
    for r in rows:
        if not isinstance(r, dict):
            continue
        qid = r.get("qid")
        if qid not in allowed:
            continue
        raw_answer = str(r.get("answer", "")).strip()
        answer = _match(raw_answer, allowed[qid])
        rec = {
            "answer": answer or "not_stated",
            "evidence": " ".join(str(r.get("evidence") or "").split()),
            "confidence": _clamp(r.get("confidence")),
        }
        if answer is None:
            rec["invalid"] = raw_answer
        if remap and rec["answer"] in remap:
            rec["remapped_from"] = rec["answer"]
            rec["answer"] = remap[rec["answer"]]
        out[qid] = rec
    for q in questions:
        out.setdefault(q["id"], dict(EMPTY))
    return out


def _match(raw_answer: str, options: list[str]) -> str | None:
    if raw_answer in options:
        return raw_answer
    lowered = raw_answer.lower()
    squashed = lowered.replace(" ", "_")
    for o in options:
        if o.lower() in (lowered, squashed):
            return o
    return None


def _clamp(value) -> float:
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return 0.0