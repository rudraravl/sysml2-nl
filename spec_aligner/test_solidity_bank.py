"""The Solidity bank: schema, language plumbing, and repair-prompt wording.

Deterministic - no LLM calls. `ask` is a stub that answers from a fixed table.
"""

import json
import re
import unittest
from pathlib import Path

from spec_aligner.bank import BANK_PATH, SOLIDITY_BANK_PATH, language, load, universal
from spec_aligner.feedback import build_repair_prompt
from spec_aligner.pipeline import compare_pair

NL = ("This escrow contract holds ETH for a buyer until a purchase settles. An arbiter may "
      "release the balance to the seller or refund the buyer. Each state change emits an event.")
SOL = """
pragma solidity ^0.8.20;
contract Escrow {
    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    bool public released;
    event Deposited(address indexed from, uint256 amount);
    event Released(address indexed to, uint256 amount);
    constructor(address _seller, address _arbiter) payable {
        buyer = msg.sender; seller = _seller; arbiter = _arbiter;
        emit Deposited(msg.sender, msg.value);
    }
    function release() external {
        require(msg.sender == arbiter, "not arbiter");
        require(!released, "done");
        released = true;
        emit Released(seller, address(this).balance);
        payable(seller).transfer(address(this).balance);
    }
}
"""


def stub_ask(answer_for):
    """Answer every qid the prompt lists, using a callable for the option choice."""
    def ask(prompt: str) -> str:
        qids = re.findall(r"^- (\S+) \(", prompt, re.M)
        opts = dict(re.findall(r"^- (\S+) \([^)]*\).*?\[options: ([^\]]+)\]", prompt, re.M))
        rows = []
        for qid in qids:
            choices = [o.strip() for o in opts.get(qid, "not_stated").split("|")]
            rows.append({"qid": qid, "answer": answer_for(qid, choices),
                         "evidence": "stub", "confidence": 0.9})
        return json.dumps({"answers": rows})
    return ask


class SolidityBank(unittest.TestCase):
    def setUp(self):
        self.bank = load(SOLIDITY_BANK_PATH)

    def test_bank_validates_and_declares_solidity(self):
        self.assertEqual(language(self.bank)["id"], "solidity")
        self.assertEqual(len(self.bank["universal"]), 45)
        self.assertEqual(len(universal(self.bank)), 45)

    def test_canary_id_matches_scorer(self):
        # score.py treats U-GLB-01 as the domain canary and excludes it from S
        self.assertIn("U-GLB-01", {q["id"] for q in self.bank["universal"]})

    def test_runtime_profile_ids_exist(self):
        ids = {q["id"] for q in self.bank["universal"]}
        for qid in self.bank["profiles"]["runtime"]["universal_ids"]:
            self.assertIn(qid, ids, f"runtime profile names unknown question {qid}")

    def test_template_slots_appear_in_patterns(self):
        for t in self.bank["templates"]:
            for slot in t["slots"]:
                self.assertIn(f"⟨{slot}⟩", t["pattern"], t["id"])

    def test_answer_prompt_is_solidity_flavoured(self):
        from spec_aligner.answer import answer_prompt
        qs = universal(self.bank)[:3]
        prompt = answer_prompt(qs, SOL, "solidity", self.bank)
        self.assertIn("```solidity", prompt)
        self.assertIn("Solidity smart contract source", prompt)
        self.assertNotIn("SysML", prompt)

    def test_report_is_keyed_solidity(self):
        ask = stub_ask(lambda qid, choices: choices[0])
        data = compare_pair(NL, SOL, ask, sample_id="escrow", shards=1,
                            universal_only=True, bank_path=SOLIDITY_BANK_PATH)
        self.assertEqual(data["model_key"], "solidity")
        self.assertIn("solidity", data["answers"][0])
        self.assertNotIn("sysml", data["answers"][0])
        self.assertEqual(data["question_selection"]["language"], "solidity")

    def test_perfect_agreement_scores_one(self):
        ask = stub_ask(lambda qid, choices: choices[0])
        data = compare_pair(NL, SOL, ask, sample_id="escrow", shards=1,
                            universal_only=True, bank_path=SOLIDITY_BANK_PATH)
        self.assertEqual(data["summary"]["similarity"], 1.0)

    def test_disagreement_is_localized(self):
        def answer_for(qid, choices):
            # the contract side claims the opposite on one question
            return choices[-2] if qid == "U-EVT-01" else choices[0]
        first = stub_ask(lambda qid, choices: choices[0])
        calls = {"n": 0}

        def ask(prompt):
            calls["n"] += 1
            return (first(prompt) if calls["n"] == 1 else stub_ask(answer_for)(prompt))
        data = compare_pair(NL, SOL, ask, sample_id="escrow", shards=1,
                            universal_only=True, bank_path=SOLIDITY_BANK_PATH)
        self.assertLess(data["summary"]["similarity"], 1.0)
        self.assertTrue(any(m["qid"] == "U-EVT-01" for m in data["mismatches"]))

    def test_repair_prompt_asks_for_solidity_not_sysml(self):
        report = {"model_key": "solidity", "mismatches": [
            {"severity": "high", "text": "Is a fee taken on withdrawal?", "outcome": "conflict",
             "nl": {"answer": "yes", "evidence": "charges a 2% fee"},
             "solidity": {"answer": "no", "evidence": ""}}]}
        prompt = build_repair_prompt(NL, SOL, report)
        self.assertIn("Solidity contract", prompt)
        self.assertIn("Solidity source", prompt)
        self.assertNotIn("SysML", prompt)
        self.assertIn("re-entrancy", prompt)          # language-specific preservation rule
        self.assertIn("charges a 2% fee", prompt)     # evidence carried through

    def test_sysml_bank_is_unchanged(self):
        sysml_bank = load(BANK_PATH)
        self.assertEqual(language(sysml_bank)["id"], "sysml")
        report = {"mismatches": []}                    # no model_key -> legacy default
        self.assertIn("SysML v2 model", build_repair_prompt("nl", "model", report))


if __name__ == "__main__":
    unittest.main()
