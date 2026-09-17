from __future__ import annotations

from pathlib import Path
import unittest

from nl2robotics.hybrid.gpu_handoff import (
    _isaac_api_probe,
    build_isaac_command,
    classify_rt_capability,
    parse_nvidia_smi,
)


class GPUHandoffTests(unittest.TestCase):
    def test_nvidia_smi_parser_preserves_model_memory_and_driver(self):
        rows = parse_nvidia_smi(
            "NVIDIA RTX A6000, 49140, 580.65.06\n"
            "NVIDIA L40S, 46068, 580.65.06\n"
        )
        self.assertEqual("NVIDIA RTX A6000", rows[0]["name"])
        self.assertEqual(49140, rows[0]["memory_mib"])
        self.assertEqual(2, len(rows))

    def test_command_freezes_claim_relevant_configuration(self):
        command = build_isaac_command(
            isaac_python=Path("/opt/isaac/python.sh"),
            bundle_path=Path("/work/execution-input.json"),
            output_dir=Path("/work/results"),
            articulation_root="/World/WorldAnchor",
            repetitions=3,
            controller_backend="local",
            device="cpu",
            solver="TGS",
        )
        self.assertIn("--repetitions", command)
        self.assertIn("3", command)
        self.assertIn("--isaac-version-prefix", command)
        self.assertIn("6.0", command)
        self.assertIn("/World/WorldAnchor", command)

    def test_rt_capability_accepts_known_rt_families(self):
        passed, detail = classify_rt_capability([
            {"name": "NVIDIA RTX A6000"},
            {"name": "NVIDIA L40S"},
            {"name": "NVIDIA A40"},
        ])
        self.assertTrue(passed, detail)

    def test_rt_capability_rejects_deltaai_h100(self):
        passed, detail = classify_rt_capability([
            {"name": "NVIDIA H100 96GB HBM3"},
        ])
        self.assertFalse(passed)
        self.assertIn("non-RT", detail)

    def test_rt_capability_fails_closed_for_unknown_gpu(self):
        passed, detail = classify_rt_capability([
            {"name": "NVIDIA Future Accelerator"},
        ])
        self.assertFalse(passed)
        self.assertIn("review", detail)

    def test_preflight_probes_every_runtime_api_family(self):
        probe = _isaac_api_probe("local")
        self.assertIn("import fmpy", probe)
        self.assertIn("get_dof_efforts", probe)
        self.assertIn("set_dof_positions", probe)
        self.assertIn("SimulationManager", probe)
        self.assertIn("version.startswith('6.0')", probe)


if __name__ == "__main__":
    unittest.main()
