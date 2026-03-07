"""Graphviz / dot availability check."""

import os
import subprocess

_EXTRA_PATHS = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"]
for p in _EXTRA_PATHS:
    if p not in os.environ.get("PATH", ""):
        os.environ["PATH"] = p + os.pathsep + os.environ.get("PATH", "")

DOT_AVAILABLE = False
try:
    subprocess.run(["dot", "-V"], capture_output=True, check=True)
    DOT_AVAILABLE = True
except Exception:
    DOT_AVAILABLE = False
