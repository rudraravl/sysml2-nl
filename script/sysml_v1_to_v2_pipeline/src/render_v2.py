from __future__ import annotations
import os
from typing import Dict

def write_v2_tree(files: Dict[str, str], out_dir: str) -> None:
    for stem, text in files.items():
        path = os.path.join(out_dir, *stem.split("/")) + ".sysml"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
