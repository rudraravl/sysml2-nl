#!/usr/bin/env python3
"""Validate the Solidity dataset: files exist, checksums match, schema holds."""
import json
import hashlib
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator
except ImportError:
    Draft202012Validator = None


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    root = Path(__file__).parent.parent
    manifest = root / "index" / "manifest.jsonl"
    if not manifest.exists():
        print("manifest.jsonl missing - run build_manifest.py first")
        return 1

    schema = None
    schema_path = root / "schema" / "manifest.schema.json"
    if Draft202012Validator and schema_path.exists():
        schema = Draft202012Validator(json.loads(schema_path.read_text(encoding="utf-8")))

    errors = 0
    n = 0
    with open(manifest, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            rec = json.loads(line)
            n += 1
            if schema:
                for err in schema.iter_errors(rec):
                    print(f"[{rec['id']}] schema: {err.message}")
                    errors += 1
            for kind, rel in rec["paths"].items():
                p = root / rel
                if not p.exists():
                    print(f"[{rec['id']}] missing {kind}: {rel}")
                    errors += 1
                    continue
                try:
                    p.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    print(f"[{rec['id']}] {kind} is not valid UTF-8")
                    errors += 1
                if sha256_file(p) != rec["sha256"][kind]:
                    print(f"[{rec['id']}] checksum mismatch for {kind}")
                    errors += 1
    print(f"validated {n} records, {errors} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
