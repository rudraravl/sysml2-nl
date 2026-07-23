"""End-to-end pipeline: instantiate -> twin answer -> score -> report."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from .answer import answer_all
from .bank import load, universal
from .instantiate import instantiate
from .report import report_data
from .score import score


RUNTIME_UNIVERSAL_IDS = {
    "U-GLB-01",
    "U-STR-02",
    "U-INT-01",
    "U-CON-01",
    "U-CON-04",
    "U-ATT-01",
    "U-CST-01",
    "U-REQ-01",
    "U-STA-01",
    "U-ACT-01",
    "U-CLS-01",
}

PROFILES = {
    "research": {"source_mode": "both", "min_questions": 30, "max_questions": 60},
    "runtime": {"source_mode": "nl", "min_questions": 8, "max_questions": 16},
}


def compare_pair(nl: str, sysml: str, ask, sample_id: str = "pair", shards: int = 5,
                 universal_only: bool = False, cache_dir: str | Path | None = None, *,
                 profile: str = "research", question_source: str | None = None,
                 max_instantiated: int | None = None) -> dict:
    if profile not in PROFILES:
        raise ValueError(f"unknown alignment profile: {profile}")
    settings = dict(PROFILES[profile])
    if question_source is not None:
        settings["source_mode"] = question_source
    if max_instantiated is not None:
        settings["max_questions"] = max_instantiated
        settings["min_questions"] = min(settings["min_questions"], max_instantiated)

    bank = load()
    questions = universal(bank)
    if profile == "runtime":
        questions = [q for q in questions if q["id"] in RUNTIME_UNIVERSAL_IDS]
    rejected: list[dict] = []
    if not universal_only:
        inst, rejected = _instances(bank, nl, sysml, sample_id, ask, cache_dir,
                                    profile, settings)
        questions = questions + inst
    nl_ans = _nl_answers(bank, questions, nl, sample_id, ask, shards, cache_dir,
                         profile, settings["source_mode"])
    sys_ans = answer_all(questions, sysml, "sysml", ask, bank, shards)
    result = score(questions, nl_ans, sys_ans, bank)
    data = report_data(sample_id, bank, questions, result,
                       mode="universal_only" if universal_only else profile)
    data["question_selection"] = {
        "profile": profile,
        "source_mode": settings["source_mode"],
        "max_instantiated": settings["max_questions"],
    }
    if rejected:
        data["rejected_questions"] = rejected
    return data


def compare_files(nl_path: str | Path, sysml_path: str | Path, ask,
                  sample_id: str | None = None, **kw) -> dict:
    nl_path, sysml_path = Path(nl_path), Path(sysml_path)
    sample_id = sample_id or nl_path.stem
    return compare_pair(nl_path.read_text(encoding="utf-8"),
                        sysml_path.read_text(encoding="utf-8"),
                        ask, sample_id=sample_id, **kw)


def _instances(bank, nl, sysml, sample_id, ask, cache_dir, profile, settings):
    """Instantiated questions, cached per (sample, bank version)."""
    path = Path(cache_dir) / f"{sample_id}.questions.json" if cache_dir else None
    if path and path.exists():
        c = json.loads(path.read_text(encoding="utf-8"))
        if (c.get("bank_version") == bank["version"]
                and c.get("profile") == profile
                and c.get("source_mode") == settings["source_mode"]
                and c.get("max_questions") == settings["max_questions"]):
            return c["questions"], c.get("rejected", [])
    kept, rejected = instantiate(
        bank, nl, sysml, sample_id, ask,
        source_mode=settings["source_mode"],
        min_questions=settings["min_questions"],
        max_questions=settings["max_questions"],
    )
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"bank_version": bank["version"], "profile": profile,
                                    "source_mode": settings["source_mode"],
                                    "max_questions": settings["max_questions"],
                                    "questions": kept, "rejected": rejected},
                                   indent=1, ensure_ascii=False),
                        encoding="utf-8")
    return kept, rejected


def _nl_answers(bank, questions, nl, sample_id, ask, shards, cache_dir,
                profile, source_mode):
    """NL-side answers, cached: reused across every candidate SysML of the sample."""
    question_payload = [
        {"id": q["id"], "text": q["text"], "options": q["options"]}
        for q in questions
    ]
    key_data = json.dumps({"profile": profile, "source_mode": source_mode,
                           "questions": question_payload}, sort_keys=True)
    key = hashlib.sha1(key_data.encode()).hexdigest()[:12]
    path = Path(cache_dir) / f"{sample_id}.nl_answers.json" if cache_dir else None
    if path and path.exists():
        c = json.loads(path.read_text(encoding="utf-8"))
        if c.get("bank_version") == bank["version"] and c.get("key") == key:
            return c["answers"]
    answers = answer_all(questions, nl, "natural_language", ask, bank, shards)
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"bank_version": bank["version"], "key": key,
                                    "answers": answers}, indent=1, ensure_ascii=False),
                        encoding="utf-8")
    return answers
