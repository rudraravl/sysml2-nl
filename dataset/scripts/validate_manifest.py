import json, argparse, hashlib
from pathlib import Path

import jsonschema

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def is_utf8(path: Path) -> bool:
    try:
        with open(path, "r", encoding="utf-8") as f:
            f.read()
        return True
    except Exception:
        return False

def main(root: Path):
    manifest = root / "index" / "manifest.jsonl"
    schema = json.load(open(root / "schema" / "manifest.schema.json", "r", encoding="utf-8"))
    n = 0
    sha_errors = 0
    file_errors = 0
    encoding_errors = 0
    
    for line in open(manifest, "r", encoding="utf-8"):
        if not line.strip():
            continue
        obj = json.loads(line)
        jsonschema.validate(obj, schema)
        
        # Check file existence, UTF-8 encoding, and SHA checksums
        for file_type in ["sysml", "text", "meta"]:
            file_path = root / obj["paths"][file_type]
            if not file_path.exists():
                print(f"ERROR: Missing file {file_path}")
                file_errors += 1
            else:
                # Check UTF-8 encoding
                if not is_utf8(file_path):
                    print(f"ERROR: Not UTF-8 encoded: {file_path}")
                    encoding_errors += 1
                
                # Verify SHA checksum
                actual_sha = sha256_file(file_path)
                recorded_sha = obj["sha256"][file_type]
                if actual_sha != recorded_sha:
                    print(f"ERROR: SHA mismatch for {file_path}")
                    print(f"  Expected: {recorded_sha}")
                    print(f"  Actual:   {actual_sha}")
                    sha_errors += 1
        
        n += 1
    
    print(f"Validated {n} manifest records.")
    if file_errors > 0:
        print(f"ERROR: {file_errors} missing files")
    if encoding_errors > 0:
        print(f"ERROR: {encoding_errors} encoding issues")
    if sha_errors > 0:
        print(f"ERROR: {sha_errors} SHA checksum mismatches")
    if file_errors == 0 and encoding_errors == 0 and sha_errors == 0:
        print("All files exist, are UTF-8 encoded, and checksums match ✓")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=str, default=".")
    args = parser.parse_args()
    main(Path(args.root))
