import json
import tempfile
import unittest
from pathlib import Path

from nl2robotics.hybrid.deltaai.gpu_profile import summarize_samples


class GPUProfileTest(unittest.TestCase):
    def test_summarizes_peak_vram_and_utilization(self):
        with tempfile.TemporaryDirectory() as temporary:
            samples = Path(temporary) / "samples.csv"
            samples.write_text(
                "2026/09/03 10:00:00.000, 0, GPU-abc, NVIDIA GH200 120GB, 97871, 410, 0\n"
                "2026/09/03 10:00:00.200, 0, GPU-abc, NVIDIA GH200 120GB, 97871, 1880, 76\n"
                "2026/09/03 10:00:00.400, 0, GPU-abc, NVIDIA GH200 120GB, 97871, 1220, 32\n",
                encoding="utf-8",
            )
            report = summarize_samples(samples)
        device = report["devices"][0]
        self.assertEqual(3, device["sample_count"])
        self.assertEqual(1880.0, device["peak_memory_used_mib"])
        self.assertEqual(1470.0, device["incremental_peak_memory_mib"])
        self.assertEqual(76.0, device["peak_utilization_gpu_percent"])
        json.dumps(report, allow_nan=False)

    def test_rejects_empty_sample_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            samples = Path(temporary) / "samples.csv"
            samples.write_text("", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no GPU samples"):
                summarize_samples(samples)


if __name__ == "__main__":
    unittest.main()
