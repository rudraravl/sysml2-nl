import json, hashlib
from pathlib import Path

def sha256_file(path: Path) -> str:
    import hashlib
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
    # Process all data in a single directory
    data_dir = root / "data"
    if not data_dir.exists():
        raise FileNotFoundError(f"Data directory not found: {data_dir}")
    
    for did in sorted(p.name for p in data_dir.iterdir() if p.is_dir()):
        base = data_dir / did
        sysml = base / f"{did}.sysml"
        text  = base / f"{did}.txt"
        meta  = base / "meta.json"
        for p in [sysml, text, meta]:
            if not p.exists():
                raise FileNotFoundError(f"Missing file: {p}")
        
        # Read meta.json to get labels including split
        with open(meta, 'r', encoding='utf-8') as f:
            meta_data = json.load(f)
        
        rec = {
            "id": did,
            "split": meta_data.get("split", "unknown"),
            "quality_tier": meta_data.get("quality_tier", "B"),
            "paths": {
                "sysml": str(sysml.relative_to(root)).replace("\\","/"),
                "text":  str(text.relative_to(root)).replace("\\","/"),
                "meta":  str(meta.relative_to(root)).replace("\\","/")
            },
            "sha256": {
                "sysml": sha256_file(sysml),
                "text":  sha256_file(text),
                "meta":  sha256_file(meta)
            },
            "sizes": {
                "sysml": sysml.stat().st_size,
                "text":  text.stat().st_size,
                "meta":  meta.stat().st_size
            },
            "stats": {
                "sysml_lines": count_lines(sysml),
                "text_tokens": count_tokens(text),
                "language": "en"
            },
            "labels": meta_data.get("labels", {"domain":"unknown","diagram_kinds":[],"difficulty":"beginner","quality_tier":"B"}),
            "license":"CC-BY-4.0",
            "source":{"provenance":"unknown","timestamp":"", "version":""}
        }
        records.append(rec)
        for p in [sysml, text, meta]:
            rel = str(p.relative_to(root)).replace("\\","/")
            checks.append(f"{sha256_file(p)}\t{rel}\n")
    (root / "index").mkdir(parents=True, exist_ok=True)
    with open(root / "index" / "manifest.jsonl", "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(root / "index" / "checksums.tsv", "w", encoding="utf-8") as f:
        f.writelines(checks)
    
    # Generate stats.json
    total_sysml_lines = sum(r["stats"]["sysml_lines"] for r in records)
    total_text_tokens = sum(r["stats"]["text_tokens"] for r in records)
    total_sysml_size = sum(r["sizes"]["sysml"] for r in records)
    total_text_size = sum(r["sizes"]["text"] for r in records)
    total_meta_size = sum(r["sizes"]["meta"] for r in records)
    
    # Read version from VERSION file
    version_file = root / "VERSION"
    with open(version_file, "r") as f:
        version = f.read().strip()
    
    # Count records by split
    by_split = {}
    for r in records:
        split = r.get("split", "unknown")
        by_split[split] = by_split.get(split, 0) + 1
    
    stats = {
        "num_records": len(records),
        "by_split": by_split,
        "avg_text_tokens": round(total_text_tokens / len(records), 1) if records else 0,
        "avg_sysml_lines": round(total_sysml_lines / len(records), 1) if records else 0,
        "total_sysml_size": total_sysml_size,
        "total_text_size": total_text_size,
        "total_meta_size": total_meta_size,
        "quality_tiers": {tier: sum(1 for r in records if r.get("quality_tier") == tier) for tier in ["A+", "A", "B", "C"]},
        "domains": list(set(r["labels"]["domain"] for r in records if r["labels"]["domain"] != "unknown")),
        "difficulty_levels": {level: sum(1 for r in records if r["labels"]["difficulty"] == level) for level in ["beginner", "intermediate", "advanced"]},
        "diagram_kinds": list(set(kind for r in records for kind in r["labels"]["diagram_kinds"])),
        "version": version,
        "created_utc": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat().replace("+00:00", "Z")
    }
    with open(root / "index" / "stats.json", "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2, ensure_ascii=False)
    
    print(f"Built manifest for {len(records)} records.")

if __name__ == "__main__":
    main()
