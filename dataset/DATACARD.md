# SysML2-NL Dataset Data Card

**Purpose:** Joint embedding space development for SysML v2 and Natural Language semantic alignment, enabling cross-modal understanding and comparison without requiring explicit bidirectional translation.

**Collection:** Dataset contains paired SysML v2 models and natural language descriptions, designed to support research in Model-Based Systems Engineering (MBSE) and AI-assisted semantic alignment techniques.

**Structure:** Single unified dataset without train/val/test splits. Each sample contains:
- `{id}.sysml` - SysML v2 model file
- `{id}.txt` - Natural language description
- `meta.json` - Sample metadata and annotations

**Quality Assurance:** Comprehensive validation includes:
- File existence verification
- UTF-8 encoding validation
- SHA256 checksum integrity verification
- JSON schema compliance
- Manifest structure validation

**Quality Tiers:** A (high), B (partial), C (noisy). See `labels.quality_tier` in manifest entries.

**Validation:** Use `python dataset/scripts/validate_manifest.py` for complete dataset integrity verification.

**Known Limitations:** This dataset focuses on semantic alignment rather than full SysML v2 parsing compliance. Examples are designed for joint embedding research.

**Licensing:** CC-BY-4.0. See individual manifest records for per-sample licensing overrides if needed.
