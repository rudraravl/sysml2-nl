"""Tests for the QA-based spec aligner. Run with Python 3.10+:

    /usr/bin/python3.11 -m unittest spec_aligner.test_spec_aligner -v

Deterministic throughout - LLM calls are stubbed. The dataset test reuses the
legacy seed (20260708) so the same 10 samples are exercised.
"""

from __future__ import annotations

import hashlib
import json
import random
import re
import unittest
from pathlib import Path

from spec_aligner import bank as bank_mod
from spec_aligner.answer import answer_all, answer_prompt, parse_answers, shard
from spec_aligner.instantiate import validate_instances, writer_prompt
from spec_aligner.pipeline import compare_pair
from spec_aligner.report import render_markdown, report_data, write_json
from spec_aligner.score import outcome, score

DATASET_SAMPLE_SIZE = 10
DATASET_SAMPLE_SEED = 20260708
TEST_RESULT_DIR = Path(__file__).resolve().parent / "test_result"

BANK = bank_mod.load()
NEG = set(BANK["scoring"]["negative_answers"])


def dataset_pairs() -> list[tuple[Path, Path]]:
    repo_root = Path(__file__).resolve().parents[1]
    pairs = []
    for txt_path in sorted((repo_root / "dataset" / "data").glob("*/*.txt")):
        sysml_path = txt_path.with_suffix(".sysml")
        if sysml_path.exists():
            pairs.append((txt_path, sysml_path))
    return pairs


def uq(qid, options, category="structure", **kw):
    return {"id": qid, "category": category, "text": qid, "options": list(options),
            "origin": kw.pop("origin", "both"), "tier": "universal", **kw}


def ans(answer, evidence="ev"):
    return {"answer": answer, "evidence": evidence if answer != "not_stated" else "",
            "confidence": 1.0}


def stub_answers(questions):
    """Deterministic pseudo-answers derived from the question id (md5, stable)."""
    out = {}
    for q in questions:
        h = int(hashlib.md5(q["id"].encode()).hexdigest(), 16)
        opts = q["options"]
        i = h % (len(opts) + 1)
        out[q["id"]] = ans(opts[i] if i < len(opts) else "not_stated", evidence="stub")
    return out


class BankTest(unittest.TestCase):
    def test_bank_shape(self):
        self.assertEqual(len(BANK["universal"]), 45)
        self.assertEqual(len(BANK["templates"]), 30)
        distractors = [t for t in BANK["templates"] if t["category"] == "distractor"]
        self.assertEqual(len(distractors), 3)

    def test_universal_resolved(self):
        qs = bank_mod.universal(BANK)
        self.assertEqual(len(qs), 45)
        for q in qs:
            self.assertIsInstance(q["options"], list)
            self.assertGreaterEqual(len(q["options"]), 2)
            self.assertNotIn("not_stated", q["options"])
            self.assertEqual(q["tier"], "universal")


class OutcomeTest(unittest.TestCase):
    CASES = [
        ("yes", "yes", "aligned"),
        ("no", "no", "aligned"),
        ("yes", "no", "missing_in_model"),
        ("yes", "none", "missing_in_model"),
        ("yes", "nothing_flows", "missing_in_model"),
        (">= 12 V", "no_bound", "missing_in_model"),
        ("no", "yes", "conflict"),
        ("no_bound", ">= 12 V", "conflict"),
        ("two", "three_to_five", "conflict"),
        (">= 12 V", ">= 10 V", "conflict"),
        ("yes", "not_stated", "unverifiable"),
        ("not_stated", "yes", "extra_in_model"),
        ("not_stated", "no", "vacuous"),
        ("not_stated", "not_stated", "vacuous"),
    ]

    def test_outcome_matrix(self):
        for nl, sysml, expected in self.CASES:
            with self.subTest(nl=nl, sysml=sysml):
                self.assertEqual(outcome(nl, sysml, NEG), expected)


class ScoreTest(unittest.TestCase):
    def build(self):
        questions = [
            uq("U-GLB-01", BANK["option_sets"]["domain"], category="global"),
            uq("A", ["yes", "no"]),
            uq("B", ["yes", "no"], depends_on={"question": "A", "answer": "yes"}),
            uq("C", ["yes", "no"], category="connectivity", origin="sysml"),
            uq("D", ["yes", "no"]),
            uq("E", ["yes", "no"], category="distractor"),
            uq("F", ["yes", "no"]),
            uq("G", ["yes", "no"], depends_on={"question": "F", "answer": "yes"}),
        ]
        nl = {"U-GLB-01": ans("vehicle_or_transport"), "A": ans("yes"), "B": ans("yes"),
              "C": ans("not_stated"), "D": ans("not_stated"), "E": ans("no"),
              "F": ans("yes"), "G": ans("yes")}
        sysml = {"U-GLB-01": ans("aerospace_or_space"), "A": ans("yes"), "B": ans("no"),
                 "C": ans("yes"), "D": ans("no"), "E": ans("yes"), "F": ans("no"),
                 "G": ans("yes")}
        return questions, nl, sysml

    def test_score_synthetic(self):
        questions, nl, sysml = self.build()
        res = score(questions, nl, sysml, BANK)
        # scored: A aligned 1.0, B missing 0.3, C extra(origin sysml) 1.0, F missing 0.3
        self.assertEqual(res["scored"], 4)
        self.assertAlmostEqual(res["similarity"], 0.65)
        self.assertEqual(res["counts"], {
            "aligned": 1, "missing_in_model": 2, "extra_in_model": 1,
            "vacuous": 1, "conflict": 2, "skipped_dependency": 1,
        })
        self.assertTrue(res["domain_mismatch"])                # canary conflict
        self.assertEqual(res["reliability"], {"nl": 1.0, "sysml": 0.0})
        self.assertTrue(res["reliability_flag"])               # sysml fell for distractor
        self.assertEqual(res["per_category"],
                         {"connectivity": 1.0, "structure": round((1.0 + 0.3 + 0.3) / 3, 4)})
        self.assertEqual(len(res["mismatches"]), 3)            # B, C, F
        self.assertEqual(res["mismatches"][0]["severity"], "medium")
        skipped = [r for r in res["rows"] if r["outcome"] == "skipped_dependency"]
        self.assertEqual([r["qid"] for r in skipped], ["G"])

    def test_ordinal_adjacent_bucket(self):
        buckets = BANK["option_sets"]["count_bucket"]
        questions = [
            dict(uq("N1", buckets), ordinal=True),
            dict(uq("N2", buckets), ordinal=True),
        ]
        nl = {"N1": ans("three_to_five"), "N2": ans("one")}
        sysml = {"N1": ans("more_than_five"), "N2": ans("more_than_five")}
        res = score(questions, nl, sysml, BANK)
        by_qid = {m["qid"]: m for m in res["mismatches"]}
        self.assertEqual(by_qid["N1"]["credit"], 0.7)          # adjacent -> partial
        self.assertEqual(by_qid["N1"]["severity"], "low")
        self.assertEqual(by_qid["N2"]["credit"], 0.0)          # far apart -> real clash
        self.assertEqual(by_qid["N2"]["severity"], "high")

    def test_canary_wildcard_tolerance(self):
        questions = [uq("U-GLB-01", BANK["option_sets"]["domain"], category="global")]
        nl = {"U-GLB-01": ans("electrical_or_energy")}
        sysml = {"U-GLB-01": ans("other")}   # fuzzy teaching-sample domain
        res = score(questions, nl, sysml, BANK)
        self.assertFalse(res["domain_mismatch"])
        nl2 = {"U-GLB-01": ans("electrical_or_energy")}
        sy2 = {"U-GLB-01": ans("biological_or_medical")}   # hard disagreement
        res2 = score(questions, nl2, sy2, BANK)
        self.assertTrue(res2["domain_mismatch"])

    def test_dependency_skip_on_vacuous_parent(self):
        questions = [
            uq("P", ["yes", "no"]),
            uq("K", ["yes", "no"], depends_on={"question": "P", "answer": "yes"}),
        ]
        nl = {"P": ans("not_stated"), "K": ans("yes")}
        sysml = {"P": ans("no"), "K": ans("no")}
        res = score(questions, nl, sysml, BANK)
        self.assertEqual(res["scored"], 0)
        self.assertIsNone(res["similarity"])
        self.assertEqual(res["counts"]["skipped_dependency"], 1)


class AnswerTest(unittest.TestCase):
    def test_shard_partition(self):
        qs = bank_mod.universal(BANK)
        parts = shard(qs, 5)
        self.assertEqual(len(parts), 5)
        self.assertEqual(sum(len(p) for p in parts), len(qs))
        flat = [q["id"] for p in parts for q in p]
        self.assertEqual(flat, [q["id"] for q in qs])
        self.assertEqual(len(shard(qs[:3], 5)), 3)   # never more shards than questions

    def test_answer_prompts_worldviews(self):
        qs = bank_mod.universal(BANK)[:4]
        nl_prompt = answer_prompt(qs, "The battery is big.", "natural_language", BANK)
        sys_prompt = answer_prompt(qs, "part def Battery;", "sysml", BANK)
        self.assertIn("OPEN WORLD", nl_prompt)
        self.assertNotIn("CLOSED WORLD", nl_prompt)
        self.assertIn("CLOSED WORLD", sys_prompt)
        self.assertIn(":>>", sys_prompt)              # notation cheat-sheet present
        for q in qs:
            self.assertIn(q["id"], nl_prompt)
        self.assertIn("not_stated", nl_prompt)

    def test_parse_answers(self):
        qs = [uq("U1", ["yes", "no"]), uq("U2", BANK["option_sets"]["count_bucket"]),
              uq("U3", ["yes", "no"])]
        raw = ('```json\n{"answers": ['
               '{"qid": "U1", "answer": "Yes", "evidence": "the battery", "confidence": 0.9},'
               '{"qid": "U2", "answer": "many", "evidence": "x", "confidence": "high"}]}\n```')
        out = parse_answers(raw, qs)
        self.assertEqual(out["U1"]["answer"], "yes")            # case-normalized
        self.assertNotIn("invalid", out["U1"])
        self.assertEqual(out["U2"]["answer"], "not_stated")     # out-of-space coerced
        self.assertEqual(out["U2"]["invalid"], "many")
        self.assertEqual(out["U2"]["confidence"], 0.0)
        self.assertTrue(out["U3"]["missing"])                   # unanswered filled

    def test_nl_answer_remap(self):
        qs = [uq("V1", ["12 V", "declared_without_value"])]
        raw = ('{"answers": [{"qid": "V1", "answer": "declared_without_value",'
               ' "evidence": "a stable small voltage", "confidence": 0.8}]}')
        out = parse_answers(raw, qs, remap=BANK["scoring"]["nl_answer_remap"])
        self.assertEqual(out["V1"]["answer"], "not_stated")     # NL side coerced
        self.assertEqual(out["V1"]["remapped_from"], "declared_without_value")
        out_sy = parse_answers(raw, qs)                          # SysML side untouched
        self.assertEqual(out_sy["V1"]["answer"], "declared_without_value")

    def test_answer_all_merges_shards(self):
        calls = []

        def fake_ask(prompt):
            calls.append(prompt)
            qids = re.findall(r"^- (\S+) \(", prompt, re.M)
            firsts = re.findall(r"\[options: ([^|\]]+)", prompt)
            rows = [{"qid": qid, "answer": first.strip(), "evidence": "e", "confidence": 1}
                    for qid, first in zip(qids, firsts)]
            return json.dumps({"answers": rows})

        qs = bank_mod.universal(BANK)
        out = answer_all(qs, "doc", "natural_language", fake_ask, BANK, shards=5)
        self.assertEqual(len(calls), 5)
        self.assertEqual(set(out), {q["id"] for q in qs})
        self.assertEqual(out["U-STR-01"]["answer"], "none")     # first count_bucket option


class InstantiateTest(unittest.TestCase):
    NL = "The battery connects to the charger."
    SYSML = "part def Battery; part def Charger;\nconnect b to c;"

    def test_writer_prompt_contains_everything(self):
        p = writer_prompt(BANK, self.NL, self.SYSML, "000050")
        self.assertIn("T-CST-01", p)
        self.assertIn(self.NL, p)
        self.assertIn("connect b to c;", p)
        self.assertIn("not_stated", p)

    def test_validate_instances(self):
        items = [
            {"template_id": "T-CON-01", "text": "Is the battery directly connected to the charger?",
             "options": ["yes", "no"], "origin": "both",
             "slots": {"A": "battery", "B": "charger"}},
            {"template_id": "T-XXX-99", "text": "x", "options": ["yes", "no"],
             "origin": "both", "slots": {}},
            {"template_id": "T-CON-01", "text": "Is ⟨A⟩ connected?", "options": ["yes", "no"],
             "origin": "both", "slots": {"A": "battery", "B": "charger"}},
            {"template_id": "T-DIS-01", "text": "Does the system include a battery?",
             "options": ["yes", "no"], "origin": "fabricated",
             "slots": {"absent_component": "battery"}},
            {"template_id": "T-DIS-01", "text": "Does the system include a hydraulic pump?",
             "options": ["yes", "no"], "origin": "fabricated",
             "slots": {"absent_component": "hydraulic pump"}},
            {"template_id": "T-STA-04", "text": "What is the initial state of the charger?",
             "options": ["idle", "active"], "origin": "sysml", "slots": {"component": "charger"}},
            {"template_id": "T-STA-04", "text": "What is the initial state of the battery?",
             "options": ["full", "empty"], "origin": "sysml", "slots": {"component": "battery"}},
            {"template_id": "T-STA-04", "text": "What is the initial state of the cable?",
             "options": ["a", "b"], "origin": "sysml", "slots": {"component": "cable"}},
            {"template_id": "T-CON-01", "text": "Is the charger connected to the cable?",
             "options": ["yes", "no"], "origin": "fabricated",
             "slots": {"A": "charger", "B": "cable"}},
            {"template_id": "T-CON-01", "text": "Is the cable connected to the plug?",
             "options": ["yes", "no", "not_stated"], "origin": "both",
             "slots": {"A": "cable", "B": "plug"}},
        ]
        kept, rejected = validate_instances(items, BANK, self.NL, self.SYSML, "tst")
        self.assertEqual(len(kept), 4)      # good CON + good DIS + two STA-04
        self.assertEqual(len(rejected), 6)
        self.assertEqual(kept[0]["id"], "Q-tst-T-CON-01-1")
        self.assertEqual(kept[1]["expected_answer"], "no_or_not_stated")
        reasons = " | ".join(r["reason"] for r in rejected)
        self.assertIn("unknown template", reasons)
        self.assertIn("unfilled slot", reasons)
        self.assertIn("appears in a document", reasons)
        self.assertIn("over max_instances", reasons)
        self.assertIn("fabricated", reasons)
        self.assertIn("not_stated must not be listed", reasons)

    def test_requirement_family_autolink(self):
        items = [
            {"template_id": "T-REQ-01", "text": "Is there a requirement concerning safety?",
             "options": ["yes", "no"], "origin": "both", "slots": {"topic": "Safety"}},
            {"template_id": "T-REQ-03",
             "text": "What threshold does the safety requirement specify for stop time?",
             "options": ["<= 2 s", "other"], "origin": "both",
             "slots": {"topic": "safety", "property": "stop time"}},
            {"template_id": "T-REQ-03",
             "text": "What threshold does the power requirement specify for wattage?",
             "options": ["<= 750 W", "other"], "origin": "both",
             "slots": {"topic": "power", "property": "wattage"}},
        ]
        kept, rejected = validate_instances(items, BANK, self.NL, self.SYSML, "tst")
        self.assertEqual(len(kept), 3)
        self.assertEqual(kept[1]["depends_on"],
                         {"question": kept[0]["id"], "answer": "yes"})   # topic matches
        self.assertNotIn("depends_on", kept[2])                          # no parent


class PipelineTest(unittest.TestCase):
    def test_compare_pair_plumbing(self):
        data = compare_pair("The battery.", "part def Battery;",
                            lambda prompt: '{"answers": []}',
                            sample_id="t", shards=3, universal_only=True)
        self.assertEqual(data["mode"], "universal_only")
        self.assertEqual(data["summary"]["questions"]["universal"], 45)
        self.assertEqual(data["summary"]["scored"], 0)          # everything not_stated
        self.assertIsNone(data["summary"]["similarity"])
        self.assertIn("Alignment report", render_markdown(data))


class SeededDatasetTest(unittest.TestCase):
    """Same seed as the legacy regex test: identical stub answers on both sides
    must score 1.0 (self-consistency); one flipped SysML answer must be caught
    (perturbation sensitivity). Reports land in test_result/."""

    def test_random_dataset_sample_dry_run(self):
        pairs = dataset_pairs()
        self.assertGreaterEqual(len(pairs), DATASET_SAMPLE_SIZE)
        sample = random.Random(DATASET_SAMPLE_SEED).sample(pairs, DATASET_SAMPLE_SIZE)
        picked = [t.parent.name for t, _ in sample]
        print(f"\nseeded picks: {sorted(picked)}")
        self.assertEqual(len(set(picked)), DATASET_SAMPLE_SIZE)

        TEST_RESULT_DIR.mkdir(exist_ok=True)
        qs = bank_mod.universal(BANK)
        for txt_path, sysml_path in sample:
            with self.subTest(sample=txt_path.parent.name):
                nl_ans = stub_answers(qs)
                sys_ans = stub_answers(qs)              # identical -> self-consistent
                res = score(qs, nl_ans, sys_ans, BANK)
                self.assertGreaterEqual(res["scored"], 5)
                self.assertEqual(res["similarity"], 1.0)
                self.assertFalse(res["domain_mismatch"])
                for bad in ("conflict", "missing_in_model", "extra_in_model", "unverifiable"):
                    self.assertNotIn(bad, res["counts"])

                # perturbation: flip one scored aligned answer on the SysML side
                row = next(r for r in res["rows"] if r["scored"] and r["outcome"] == "aligned")
                q = next(q for q in qs if q["id"] == row["qid"])
                other = next(o for o in q["options"] if o != row["sysml"]["answer"])
                flipped = dict(sys_ans)
                flipped[q["id"]] = ans(other, evidence="flipped")
                res2 = score(qs, nl_ans, flipped, BANK)
                self.assertLess(res2["similarity"], 1.0)
                caught = res2["counts"].get("conflict", 0) + res2["counts"].get("missing_in_model", 0)
                self.assertGreaterEqual(caught, 1)
                self.assertTrue(any(m["qid"] == q["id"] for m in res2["mismatches"]))

                data = report_data(txt_path.parent.name, BANK, qs, res2, mode="stub_dry_run")
                write_json(TEST_RESULT_DIR / f"{txt_path.parent.name}.json", data)


if __name__ == "__main__":
    unittest.main()
