"""Deterministic comparison of the two answer sets -> similarity + mismatches."""

from __future__ import annotations

from .bank import language

SEVERITY = {
    "conflict": "high",
    "missing_in_model": "medium",
    "unverifiable": "low",
    "extra_in_model": "low",
}


def kind(answer: str, neg: set[str], prefix: str = "no_") -> str:
    if answer == "not_stated":
        return "ns"
    if answer in neg or answer.startswith(prefix):
        return "neg"
    return "pos"


def outcome(nl_answer: str, model_answer: str, neg: set[str], prefix: str = "no_") -> str:
    knl, ksys = kind(nl_answer, neg, prefix), kind(model_answer, neg, prefix)
    if knl == "ns":
        return "vacuous" if ksys in ("ns", "neg") else "extra_in_model"
    if ksys == "ns":
        return "unverifiable"
    if nl_answer == model_answer:
        return "aligned"
    if knl == "pos" and ksys == "neg":
        return "missing_in_model"
    return "conflict"


def score(questions: list[dict], nl_ans: dict, sys_ans: dict, bank: dict) -> dict:
    # the model-side answer key follows the bank's language ("sysml", "solidity")
    mk = language(bank)["id"]
    sc = bank["scoring"]
    neg, prefix = set(sc["negative_answers"]), sc["negative_prefix"]
    credit_map = sc["credit"]

    rows = []
    for q in questions:
        a, b = nl_ans[q["id"]]["answer"], sys_ans[q["id"]]["answer"]
        rows.append({"q": q, "nl": nl_ans[q["id"]], mk: sys_ans[q["id"]],
                     "outcome": outcome(a, b, neg, prefix), "scored": False})
    by_id = {r["q"]["id"]: r for r in rows}

    distractors = [r for r in rows if r["q"].get("category") == "distractor"]
    reliability = {}
    for side in ("nl", mk):
        ok = sum(1 for r in distractors if kind(r[side]["answer"], neg, prefix) != "pos")
        reliability[side] = round(ok / len(distractors), 3) if distractors else 1.0

    wildcards = set(sc.get("canary_wildcards", []))
    canary = by_id.get("U-GLB-01")
    canary_conflict = bool(
        canary and canary["outcome"] == "conflict"
        and canary["nl"]["answer"] not in wildcards
        and canary[mk]["answer"] not in wildcards
    )

    scored = []
    for r in rows:
        q = r["q"]
        if q.get("category") == "distractor" or q["id"] == "U-GLB-01":
            continue
        dep = q.get("depends_on")
        if dep:
            parent = by_id.get(dep["question"])
            if not parent or parent["outcome"] != "aligned" or parent["nl"]["answer"] != dep["answer"]:
                r["outcome"] = "skipped_dependency"
                continue
        if r["outcome"] == "vacuous":
            continue
        r["scored"] = True
        r["credit"] = _credit(r, credit_map, mk)
        scored.append(r)

    similarity = round(sum(r["credit"] for r in scored) / len(scored), 4) if scored else None
    # a truly mispaired document also collapses globally; adjacent-domain fuzz
    # on an otherwise well-aligned pair is not a red flag
    domain_mismatch = canary_conflict and (similarity is None or similarity < 0.7)

    cats: dict[str, list[float]] = {}
    for r in scored:
        cats.setdefault(r["q"]["category"], []).append(r["credit"])
    per_category = {c: round(sum(v) / len(v), 4) for c, v in sorted(cats.items())}

    counts: dict[str, int] = {}
    for r in rows:
        counts[r["outcome"]] = counts.get(r["outcome"], 0) + 1

    mismatches = [_mismatch(r, mk) for r in scored if r["outcome"] != "aligned"]
    mismatches.sort(key=lambda m: ("high", "medium", "low").index(m["severity"]))

    return {
        "model_key": mk,
        "similarity": similarity,
        "per_category": per_category,
        "counts": counts,
        "scored": len(scored),
        "low_signal": len(scored) < 30,
        "reliability": reliability,
        "reliability_flag": min(reliability.values()) < sc["reliability_threshold"],
        "domain_mismatch": domain_mismatch,
        "mismatches": mismatches,
        "rows": [
            {"qid": r["q"]["id"], "category": r["q"].get("category"),
             "outcome": r["outcome"], "scored": r["scored"], "credit": r.get("credit"),
             "nl": r["nl"], mk: r[mk]}
            for r in rows
        ],
    }


def _credit(row: dict, credit_map: dict, mk: str = "sysml") -> float:
    q = row["q"]
    if row["outcome"] == "extra_in_model":
        key = ("extra_in_model_origin_sysml" if q.get("origin") == mk
               else "extra_in_model_origin_other")
        return credit_map[key]
    if row["outcome"] == "conflict" and q.get("ordinal"):
        opts = q["options"]
        a, b = row["nl"]["answer"], row[mk]["answer"]
        if a in opts and b in opts and abs(opts.index(a) - opts.index(b)) == 1:
            return credit_map.get("adjacent_conflict", 0.7)   # boundary fuzz, not a real clash
    return credit_map[row["outcome"]]


def _mismatch(row: dict, mk: str = "sysml") -> dict:
    q = row["q"]
    severity = SEVERITY[row["outcome"]]
    if row["outcome"] == "conflict" and row["credit"] >= 0.5:
        severity = "low"                                      # adjacent ordinal bucket
    return {
        "qid": q["id"],
        "category": q.get("category"),
        "origin": q.get("origin"),
        "tier": q.get("tier"),
        "text": q["text"],
        "outcome": row["outcome"],
        "severity": severity,
        "credit": row["credit"],
        "nl": row["nl"],
        mk: row[mk],
        "metamodel_refs": q.get("metamodel_refs", []),
        "anchors": q.get("anchors", {}),
    }