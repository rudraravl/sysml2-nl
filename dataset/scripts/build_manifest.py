import os, json, hashlib, argparse
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

def main(root: Path):
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
        rec = {
            "id": did,
            "split": "all",  # Single split instead of train/val/test
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
            "labels": {"domain":"unknown","diagram_kinds":[],"difficulty":"easy","quality_tier":"B"},
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
    print(f"Built manifest for {len(records)} records.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=str, default=".")
    args = parser.parse_args()
    main(Path(args.root))
