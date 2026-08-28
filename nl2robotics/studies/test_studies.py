from __future__ import annotations

import unittest

from .articulated import audit_articulated_suite
from .capability_matrix import audit_manifest as audit_capabilities


class ArticulatedStudyTests(unittest.TestCase):
    def test_study_covers_supported_articulated_breadth(self):
        report = audit_articulated_suite()
        self.assertTrue(report["success"], report)
        self.assertEqual([1, 3], report["coverage"]["joint_count_range"])
        self.assertEqual(["prismatic", "revolute"],
                         report["coverage"]["joint_types"])
        self.assertEqual(["X", "Y", "Z"], report["coverage"]["axes"])
        self.assertEqual(["box", "capsule", "cylinder", "sphere"],
                         report["coverage"]["link_shapes"])
        self.assertEqual(["branching", "serial", "single"],
                         report["coverage"]["topologies"])
        self.assertEqual(3,
                         report["coverage"]["max_simultaneously_controlled_joints"])


class CapabilityBreadthStudyTests(unittest.TestCase):
    def test_study_covers_broad_profile_matrix_without_overclaiming(self):
        report = audit_capabilities()
        self.assertTrue(report["success"], report)
        self.assertEqual(13, report["case_count"])
        self.assertEqual(13, report["family_count"])
        self.assertEqual(1, report["target_tier_counts"]["5"])
        self.assertEqual(12, report["target_tier_counts"]["2"])
        self.assertEqual(13, report["rag"]["routed_family_count"])
        self.assertEqual(1500, report["rag"]["modelica_example_count"])
        self.assertEqual(1500, report["rag"]["openusd_example_count"])
        self.assertTrue(report["launch"]["success"], report["launch"])
        self.assertEqual(2, report["launch"]["phase_count"])


if __name__ == "__main__":
    unittest.main()
