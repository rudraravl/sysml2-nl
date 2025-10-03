# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository contains a comprehensive dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

**Total: 685 samples** from official OMG sources and community repositories.

### Dataset Composition
- **250 samples** from OMG SysML v2 Official Release (examples, training, validation)
- **36 samples** from community SysML-v2-Models repository  
- **399 samples** from OMG SysML-v2-Pilot-Implementation repository
- **Quality tiers**: A+ (Official Release), A (Pilot Implementation), B (Community)

## Data Sources

- **000001 - 000250**: SysML v2 models from [OMG SysML v2 Official Release](https://github.com/Systems-Modeling/SysML-v2-Release) (Most Important - Official Examples & Training)
- **000251 - 000286**: SysML v2 models from [SysML-v2-Models repository](https://github.com/GfSE/SysML-v2-Models) (Community Examples)
- **000287 - 000685**: SysML v2 models from [SysML-v2-Pilot-Implementation repository](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation) (OMG Official Pilot Implementation)

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
