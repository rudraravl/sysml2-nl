from __future__ import annotations
import os, re, hashlib
from typing import List, Tuple

def estimate_lines(text: str) -> int:
    return len([ln for ln in text.splitlines()])

def split_into_shards(text: str, target: int = 400, min_lines: int = 200, max_lines: int = 500) -> List[str]:
    """Very simple line-budget splitter: split by blank-line separated blocks
    and pack greedily until budget reached. Upgrade to graph-based sharder for production."""
    blocks = [blk.strip() for blk in re.split(r"\n\s*\n", text) if blk.strip()]
    shards, cur, cur_lines = [], [], 0
    for blk in blocks:
        bl = estimate_lines(blk) + 1
        if cur_lines + bl > max_lines and cur_lines >= min_lines:
            shards.append("\n\n".join(cur))
            cur, cur_lines = [], 0
        cur.append(blk)
        cur_lines += bl
        if cur_lines >= target and cur_lines <= max_lines:
            shards.append("\n\n".join(cur))
            cur, cur_lines = [], 0
    if cur:
        shards.append("\n\n".join(cur))
    return shards

def write_shards_for_file(path_in: str, out_dir: str, target: int = 400) -> int:
    with open(path_in, "r", encoding="utf-8") as f:
        text = f.read()
    shards = split_into_shards(text, target=target)
    base = os.path.splitext(os.path.basename(path_in))[0]
    for i, shard in enumerate(shards, 1):
        out = os.path.join(out_dir, f"{base}.part{i:02d}.sysml")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            f.write(shard)
    return len(shards)
