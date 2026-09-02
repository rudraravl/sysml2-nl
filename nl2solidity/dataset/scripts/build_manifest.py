#!/usr/bin/env python3
"""Build index/manifest.jsonl, index/checksums.tsv and index/stats.json.

Solidity counterpart of dataset/scripts/build_manifest.py: the per-sample
artifact is <id>.sol instead of <id>.sysml.
"""
import json
import hashlib
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def count_lines(path: Path) -> int:
    with open(path, "r", encoding="utf-8") as f:
        return sum(1 for _ in f)


def count_tokens(path: Path) -> int:
    with open(path, "r", encoding="utf-8") as f:
        return sum(len(line.split()) for line in f)


def main():
    root = Path(__file__).parent.parent
    records = []
    checks = []
    data_dir = root / "data"
    if not data_dir.exists():
        raise FileNotFoundError(f"Data directory not found: {data_dir}")

    for did in sorted(p.name for p in data_dir.iterdir() if p.is_dir()):
        base = data_dir / did
        sol = base / f"{did}.sol"
        text = base / f"{did}.txt"
        meta = base / "meta.json"
        for p in [sol, text, meta]:
            if not p.exists():
                raise FileNotFoundError(f"Missing file: {p}")

        with open(meta, "r", encoding="utf-8") as f:
            meta_data = json.load(f)

        rec = {
            "id": did,
            "split": meta_data.get("split", "unknown"),
            "quality": meta_data.get("quality", "B"),
            "source_path": meta_data.get("source_path", ""),
            "category": meta_data.get("category", "not processed"),
            "paths": {
                "solidity": str(sol.relative_to(root)).replace("\\", "/"),
                "text": str(text.relative_to(root)).replace("\\", "/"),
                "meta": str(meta.relative_to(root)).replace("\\", "/"),
            },
            "sha256": {
                "solidity": sha256_file(sol),
                "text": sha256_file(text),
                "meta": sha256_file(meta),
            },
            "sizes": {
                "solidity": sol.stat().st_size,
                "text": text.stat().st_size,
                "meta": meta.stat().st_size,
            },
            "stats": {
                "solidity_lines": count_lines(sol),
                "text_tokens": count_tokens(text),
                "language": "en",
            },
            "labels": meta_data.get(
                "labels", {"domain": "unknown", "difficulty": "beginner", "quality_tier": "B"}
            ),
            "license": meta_data.get("license", "unknown"),
            "source": meta_data.get("source", {"provenance": "unknown", "timestamp": "", "version": ""}),
        }
        records.append(rec)
        for p in [sol, text, meta]:
            rel = str(p.relative_to(root)).replace("\\", "/")
            checks.append(f"{sha256_file(p)}\t{rel}\n")

    (root / "index").mkdir(parents=True, exist_ok=True)
    with open(root / "index" / "manifest.jsonl", "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(root / "index" / "checksums.tsv", "w", encoding="utf-8") as f:
        f.writelines(checks)

    total_sol_lines = sum(r["stats"]["solidity_lines"] for r in records)
    total_text_tokens = sum(r["stats"]["text_tokens"] for r in records)

    with open(root / "VERSION", "r") as f:
        version = f.read().strip()

    by_split = {}
    for r in records:
        by_split[r["split"]] = by_split.get(r["split"], 0) + 1

    stats = {
        "num_records": len(records),
        "by_split": by_split,
        "avg_text_tokens": round(total_text_tokens / len(records), 1) if records else 0,
        "avg_solidity_lines": round(total_sol_lines / len(records), 1) if records else 0,
        "total_solidity_size": sum(r["sizes"]["solidity"] for r in records),
        "total_text_size": sum(r["sizes"]["text"] for r in records),
        "total_meta_size": sum(r["sizes"]["meta"] for r in records),
        "quality_tiers": {t: sum(1 for r in records if r.get("quality") == t) for t in ["A+", "A", "B", "C"]},
        "categories": sorted(set(r.get("category", "not processed") for r in records)),
        "version": version,
        "created_utc": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat().replace("+00:00", "Z"),
    }
    with open(root / "index" / "stats.json", "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2, ensure_ascii=False)

    print(f"Built manifest for {len(records)} records.")


if __name__ == "__main__":
    main()
