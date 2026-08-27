"""Tests for fail-closed DeltaAI hardware identification."""

import unittest

from nl2robotics.hybrid.deltaai.preflight import _is_deltaai_hopper_gpu


class DeltaAIHardwareTest(unittest.TestCase):
    def test_accepts_deltaai_hopper_products(self):
        self.assertTrue(_is_deltaai_hopper_gpu([
            "NVIDIA H100 80GB HBM3, 580.95.05",
        ]))
        self.assertTrue(_is_deltaai_hopper_gpu([
            "NVIDIA GH200 120GB, 580.95.05",
        ]))

    def test_rejects_other_gpu_families_and_empty_probe(self):
        self.assertFalse(_is_deltaai_hopper_gpu([
            "NVIDIA A100-SXM4-80GB, 580.95.05",
        ]))
        self.assertFalse(_is_deltaai_hopper_gpu([]))


if __name__ == "__main__":
    unittest.main()
