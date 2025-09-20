# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository is a **starter skeleton** for building a dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

## Layout
- `data/<split>/<id>/` holds triplets: `<id>.sysml`, `<id>.txt`, `meta.json`
- `index/manifest.jsonl` is the canonical index (one JSON per line)
- `index/checksums.tsv` contains SHA256 checksums for integrity
- `schema/` has JSON Schemas for validation
- `scripts/` contains helper utilities

## Quick start
- Edit / add samples under `data/train|val|test/<id>/`
- Run `python scripts/build_manifest.py` to rebuild the manifest and checksums
- (Optional) run `python scripts/validate_manifest.py` and `python scripts/validate_samples.py`

## License
Set the license you want in `LICENSE` (default: CC-BY-4.0 suggested).
