from __future__ import annotations

import json
import random
import unittest
from pathlib import Path

from spec_aligner import compare_pair
from spec_aligner.nl_extractor import extract as extract_nl
from spec_aligner.pipeline import compare_files
from spec_aligner.report import report_data
from spec_aligner.sysml_extractor import extract as extract_sysml


DATASET_SAMPLE_SIZE = 10
DATASET_SAMPLE_SEED = 20260708
TEST_RESULT_DIR = Path(__file__).resolve().parent / "test_result"


def classes(data):
    return [m["class"] for m in data["mismatches"]]


def dataset_pairs() -> list[tuple[Path, Path]]:
    repo_root = Path(__file__).resolve().parents[1]
    data_dir = repo_root / "dataset" / "data"
    pairs: list[tuple[Path, Path]] = []
    for txt_path in sorted(data_dir.glob("*/*.txt")):
        sysml_path = txt_path.with_suffix(".sysml")
        if sysml_path.exists():
            pairs.append((txt_path, sysml_path))
    return pairs


class SpecAlignerTest(unittest.TestCase):
    def test_numeric_conflict(self):
        data = compare_pair(
            "The battery voltage shall be at least 12 volts.",
            "part def Battery { constraint { voltage >= 10[V]; } }",
        )
        self.assertIn("semantic_conflict", classes(data))
        mm = next(m for m in data["mismatches"] if m["class"] == "semantic_conflict")
        self.assertEqual(mm["severity"], "high")
        self.assertIn("12", mm["details"])
        self.assertIn("10", mm["details"])

    def test_unit_and_name_normalization_perfect_match(self):
        data = compare_pair(
            "The Battery Pack voltage shall be at least 12 volts.",
            "part def batteryPack { constraint { voltage >= 12[V]; } }",
        )
        self.assertNotIn("semantic_conflict", classes(data))
        self.assertGreaterEqual(data["summary"]["matched_count"], 1)

    def test_missing_in_model(self):
        data = compare_pair(
            "The battery voltage shall be at least 12 volts.",
            "part def Battery;",
        )
        self.assertIn("missing_in_model", classes(data))

    def test_extra_in_model(self):
        data = compare_pair(
            "Create a Battery.",
            "part def Battery; part def Charger;",
        )
        self.assertIn("extra_in_model", classes(data))

    def test_ambiguous_requirement(self):
        data = compare_pair(
            "The controller should be fast enough.",
            "part def Controller;",
        )
        self.assertIn("ambiguous_requirement", classes(data))

    def test_extractors_keep_evidence(self):
        nl_doc = extract_nl("The battery voltage shall be at least 12 V.")
        sys_doc = extract_sysml("part def Battery {\n  constraint { voltage >= 12[V]; }\n}")
        self.assertTrue(nl_doc.specs[0].source.span)
        self.assertEqual(sys_doc.specs[0].source.line_start, 1)
        self.assertTrue(any(s.kind == "constraint" and s.source.line_start for s in sys_doc.specs))

    def test_random_dataset_sample_pairs_compare(self):
        pairs = dataset_pairs()
        self.assertGreaterEqual(
            len(pairs),
            DATASET_SAMPLE_SIZE,
            "dataset/data should contain at least 10 .txt/.sysml pairs",
        )

        sample = random.Random(DATASET_SAMPLE_SEED).sample(pairs, DATASET_SAMPLE_SIZE)
        TEST_RESULT_DIR.mkdir(exist_ok=True)
        for txt_path, sysml_path in sample:
            with self.subTest(sample=txt_path.parent.name):
                nl_doc, sysml_doc, alignment, mismatches = compare_files(str(txt_path), str(sysml_path))
                data = report_data(nl_doc, sysml_doc, alignment, mismatches)
                result_path = TEST_RESULT_DIR / f"{txt_path.parent.name}.json"
                result_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

                self.assertGreater(len(nl_doc.specs), 0)
                self.assertGreater(len(sysml_doc.specs), 0)
                self.assertEqual(
                    len(alignment.matched_pairs)
                    + len(alignment.uncertain_pairs)
                    + len(alignment.nl_only),
                    len(nl_doc.specs),
                )
                self.assertIsInstance(mismatches, list)


if __name__ == "__main__":
    unittest.main()
