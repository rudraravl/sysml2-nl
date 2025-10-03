# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository contains a comprehensive dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

**Total: 386 samples** from official OMG sources, community repositories, and ESA aerospace models.

### Dataset Composition
- **250 samples** from OMG SysML v2 Official Release (examples, training, validation)
- **36 samples** from community SysML-v2-Models repository  
- **90 samples** from OMG SysML-v2-Pilot-Implementation repository (unique content only)
- **10 samples** from ESA/ESA_Comet aerospace models
- **Quality tiers**: A+ (Official Release), A (Pilot Implementation, ESA), B (Community)

## Data Sources

- **000001 - 000250**: SysML v2 models from [OMG SysML v2 Official Release](https://github.com/Systems-Modeling/SysML-v2-Release) (Most Important - Official Examples, Training & Validation)
  - **000001 - 000090**: Examples (90 samples) - Complete system models demonstrating SysML v2 concepts
  - **000091 - 000188**: Training (98 samples) - Step-by-step tutorials for learning SysML v2 features  
  - **000189 - 000250**: Validation (62 samples) - Test cases for verifying SysML v2 compliance
- **000251 - 000286**: SysML v2 models from [SysML-v2-Models repository](https://github.com/GfSE/SysML-v2-Models) (Community Examples)
- **000287 - 000376**: SysML v2 models from [SysML-v2-Pilot-Implementation repository](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation) (OMG Official Pilot Implementation - Unique Content Only)
  - **000287 - 000300**: Interactive Examples (14 samples) - Vehicle models and interactive demonstrations
  - **000301 - 000360**: Domain Libraries (60 samples) - Quantities, units, and measurement libraries
  - **000361 - 000376**: Test Cases (16 samples) - Validation tests and tool-specific implementations
- **000377 - 000386**: SysML v2 models from ESA/ESA_Comet aerospace projects ([MontiCore/sysmlv2](https://github.com/MontiCore/sysmlv2)) (Aerospace Domain)

## Layout
- `data/<id>/` holds triplets: `<id>.sysml`, `<id>.txt`, `meta.json`
- `index/manifest.jsonl` is the canonical index (one JSON per line)
- `index/checksums.tsv` contains SHA256 checksums for integrity
- `index/stats.json` contains dataset statistics and summary information
- `schema/` has JSON Schemas for validation
- `scripts/` contains helper utilities

## Metadata Structure

Each sample includes a `meta.json` file with the following structure:

```json
{
  "id": "000001",
  "source_path": "/path/to/original/sysml/file.sysml",
  "split": "official|community|pilot|esa",
  "quality": "A+|A|B|C",
  "category": "not processed",
  "created": "2024-01-01T12:00:00.000000"
}
```

- **id**: Unique 6-digit identifier for the sample
- **source_path**: Original file path of the SysML model
- **split**: Dataset split (official, community, pilot, esa)
- **quality**: Quality tier (A+ for official release, A for pilot/ESA, B for community)
- **category**: Placeholder for future categorization (currently "not processed")
- **created**: ISO timestamp when the sample was created

## Quick start
- Edit / add samples under `data/<id>/`
- Run `python scripts/build_manifest.py` to rebuild the manifest and checksums
- (Optional) run `python scripts/validate_manifest.py` to validate the dataset
