"""QA-based NL <-> model alignment: twin-blind question answering.

The model side is a language chosen by the question bank: SysML v2
(questions.json, the default) or Solidity (questions_solidity.json). Pass
``bank_path=`` to compare_pair/compare_files to select one.

Requires Python 3.10+ (system python3 here is 3.6 - use /usr/bin/python3.11).
"""

from .pipeline import compare_files, compare_pair

__all__ = ["compare_pair", "compare_files"]
__version__ = "0.2.0"