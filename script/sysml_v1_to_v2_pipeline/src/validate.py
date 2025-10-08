from __future__ import annotations
import os, glob, re
from typing import Tuple

def check_line_budget(path: str, min_lines: int = 180, max_lines: int = 520) -> Tuple[bool, int]:
    n = sum(1 for _ in open(path, "r", encoding="utf-8"))
    return (min_lines <= n <= max_lines, n)

def validate_v2_dir(v2dir: str) -> str:
    """Very light validation. Extend with a real v2 parser when available."""
    msgs = []
    for p in glob.glob(os.path.join(v2dir, "**/*.sysml"), recursive=True):
        ok, n = check_line_budget(p)
        if not ok:
            msgs.append(f"[BUDGET] {p} has {n} lines (out of bounds)")
        # naive check: package declared?
        with open(p, "r", encoding="utf-8") as f:
            txt = f.read(2000)
            if "package " not in txt:
                msgs.append(f"[PACKAGE] {p} missing 'package' declaration (heuristic)")
    return "\n".join(msgs)
