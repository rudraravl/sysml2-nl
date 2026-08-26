from __future__ import annotations

import unittest

from .articulated import audit_articulated_suite


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


if __name__ == "__main__":
    unittest.main()
