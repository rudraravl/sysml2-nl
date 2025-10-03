# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository contains a comprehensive dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

**Total: 695 samples** from official OMG sources, community repositories, and ESA aerospace models.

### Dataset Composition
- **250 samples** from OMG SysML v2 Official Release (examples, training, validation)
- **36 samples** from community SysML-v2-Models repository  
- **399 samples** from OMG SysML-v2-Pilot-Implementation repository
- **10 samples** from ESA/ESA_Comet aerospace models
- **Quality tiers**: A+ (Official Release), A (Pilot Implementation, ESA), B (Community)

## Data Sources

- **000001 - 000250**: SysML v2 models from [OMG SysML v2 Official Release](https://github.com/Systems-Modeling/SysML-v2-Release) (Most Important - Official Examples, Training & Validation)
  - **000001 - 000090**: Examples (90 samples) - Complete system models demonstrating SysML v2 concepts
  - **000091 - 000188**: Training (98 samples) - Step-by-step tutorials for learning SysML v2 features  
  - **000189 - 000250**: Validation (62 samples) - Test cases for verifying SysML v2 compliance
- **000251 - 000286**: SysML v2 models from [SysML-v2-Models repository](https://github.com/GfSE/SysML-v2-Models) (Community Examples)
- **000287 - 000685**: SysML v2 models from [SysML-v2-Pilot-Implementation repository](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation) (OMG Official Pilot Implementation)
  - **000287 - 000600**: Core Libraries (314 samples) - Domain libraries, systems library, and tool-generated libraries
  - **000601 - 000650**: Examples & Tests (50 samples) - Vehicle examples, camera models, and validation test cases
  - **000651 - 000685**: Generated Libraries (35 samples) - Auto-generated quantity libraries and tool support files
- **000686 - 000695**: SysML v2 models from ESA/ESA_Comet aerospace projects (Aerospace Domain)

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
