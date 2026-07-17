"""QA-based NL <-> SysML v2 alignment: twin-blind question answering.

Requires Python 3.10+ (system python3 here is 3.6 - use /usr/bin/python3.11).
"""

from .pipeline import compare_files, compare_pair

__all__ = ["compare_pair", "compare_files"]
__version__ = "0.2.0"
