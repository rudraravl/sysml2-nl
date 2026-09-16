from __future__ import annotations

import unittest
from unittest.mock import patch
from pathlib import Path

from nl2sysml import compiler_interface as compiler


class _ProbeCompiler:
    def __init__(self, *, negative_control_detected: bool = True):
        self.negative_control_detected = negative_control_detected

    def check_file(self, path, syntax_only=False):
        text = Path(path).read_text(encoding="utf-8")
        if text.endswith("{") and self.negative_control_detected:
            return [object()]
        return []


class CompilerAvailabilityTests(unittest.TestCase):
    def test_missing_java_fails_closed(self):
        with patch.object(compiler, "_get_compiler", return_value=_ProbeCompiler()), \
             patch.object(compiler, "_java_runtime_available", return_value=False):
            result = compiler.check_code("package Test {}")
        self.assertFalse(result.is_valid)
        self.assertIn("not available", result.errors[0].message.lower())

    def test_availability_requires_invalid_negative_control(self):
        with patch.object(
            compiler, "_get_compiler",
            return_value=_ProbeCompiler(negative_control_detected=False),
        ):
            self.assertFalse(compiler.is_compiler_available())

    def test_availability_accepts_working_controls(self):
        with patch.object(compiler, "_get_compiler", return_value=_ProbeCompiler()):
            self.assertTrue(compiler.is_compiler_available())


if __name__ == "__main__":
    unittest.main()
