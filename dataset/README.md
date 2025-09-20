# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository is a **starter skeleton** for building a dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

## Data Sources

- **000001 - 000036**: SysML v2 models from [SysML-v2-Models repository](https://github.com/GfSE/SysML-v2-Models)
- **000101 - 000102**: LLM-generated natural language descriptions using Gemini API

## Layout
- `data/<id>/` holds triplets: `<id>.sysml`, `<id>.txt`, `meta.json`
- `index/manifest.jsonl` is the canonical index (one JSON per line)
- `index/checksums.tsv` contains SHA256 checksums for integrity
- `index/stats.json` contains dataset statistics and summary information
- `schema/` has JSON Schemas for validation
- `scripts/` contains helper utilities

## Quick start
- Edit / add samples under `data/<id>/`
- Run `python scripts/build_manifest.py` to rebuild the manifest and checksums
- (Optional) run `python scripts/validate_manifest.py` to validate the dataset

## License
Set the license you want in `LICENSE` (default: CC-BY-4.0 suggested).
