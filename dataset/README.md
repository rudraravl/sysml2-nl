# SysML2 ↔ Natural Language Alignment Dataset (Starter)

This repository contains a comprehensive dataset that pairs SysML v2 textual models (`.sysml`)
with natural language descriptions (`.txt`), along with metadata and a canonical manifest index.

**Total: 1,935 samples** from official OMG sources, community repositories, ESA aerospace models, and agent-generated SysML.

### Dataset Composition
- **250 samples** from OMG SysML v2 Official Release (examples, training, validation)
- **36 samples** from community SysML-v2-Models repository  
- **90 samples** from OMG SysML-v2-Pilot-Implementation repository (unique content only)
- **10 samples** from ESA/ESA_Comet aerospace models
- **1,549 samples** from agent-generated SysML (with generated NL)
- **Quality tiers**: A+ (Official Release), A (Pilot Implementation, ESA), B (Community)

## Dataset Curation

This dataset is curated to cover both *real* SysML v2 models (official and community-authored) and *synthetic* models that expand domain breadth while staying close to SysML v2 concrete syntax. All entries are normalized into a single paired format (`.sysml` + `.txt` + `meta.json`), indexed by `index/manifest.jsonl`, and integrity-checked via SHA256 and schema validation (`dataset/scripts/build_manifest.py`, `dataset/scripts/validate_manifest.py`).

### Community Data

Community models are sourced from public SysML v2 repositories (e.g., `SysML-v2-Models`) and curated for uniqueness and usability:
- **De-duplication and filtering**: remove near-duplicates and non-model artifacts; keep representative examples across domains and modeling styles.
- **Normalization**: ensure UTF-8 encoding and consistent file layout; preserve original provenance via `meta.json.source_path`.
- **Pairing**: each model is paired with a natural-language description (`.txt`) suitable for embedding/alignment tasks (either provided upstream or generated during dataset preparation, depending on the source).

### Agent-Generated Data (Wikipedia-Seeded)

Agent-generated entries start from lightweight “wiki seeds” and are expanded into full SysML v2 models through a pipeline that combines **retrieval**, **Mixture-of-Experts (MoE)**, and **compiler feedback**.

1) **Wiki seed → prompt pool**  
`nl2sysml/nl_generator.py` harvests candidate device/system titles from the Wikipedia API (categories and curated pages), filters out noisy/meta pages, deduplicates titles, and converts them into short, high-level natural-language requirements (the `.txt` side for each generated pair).

2) **Retrieval (RAG) grounding**  
For each prompt, the generator builds a compact context block by retrieving:
- **Few-shot dataset examples**: similar NL↔SysML pairs sampled from `dataset/data/` (to mirror dataset style and common idioms).
- **SysML v2 spec snippets**: pre-chunked excerpts from `nl2sysml/spec_index/chunks.jsonl` (produced by `script/ingest_sysml_spec.py` from SysML v2 specification PDFs).  
This grounding step is implemented in `nl2sysml/agent_rag.py` / `nl2sysml/agent_rag_moe.py`.

3) **MoE candidate generation + synthesis**  
`nl2sysml/agent_rag_moe.py` queries multiple “expert” LLMs to propose candidate SysML v2 models for the same prompt, then uses a separate “combiner” model to synthesize a single best model by selecting/merging candidates. This improves robustness across domains and mitigates single-model failure modes.

4) **Compiler feedback (optional refinement loop)**  
As an additional QA step, generated candidates can be validated with a SysML v2 compiler and iteratively repaired by feeding diagnostics back to the model (see `nl2sysml/COMPILER_FEEDBACK.md`; a minimal API-based demo lives in `nl2sysml/compiler-demo/demo.py`). When this loop is used, syntactically valid candidates are prioritized during final selection/synthesis.

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
- **000387 - 001935**: SysML v2 models from agent generation (syntax-checked corpus)

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
  "split": "official|community|pilot|esa|agent",
  "quality": "A+|A|B|C",
  "category": "not processed",
  "created": "2024-01-01T12:00:00.000000"
}
```

- **id**: Unique 6-digit identifier for the sample
- **source_path**: Original file path of the SysML model
- **split**: Dataset split (official, community, pilot, esa)
- **quality**: Quality tier (A+ for official release, A for pilot/ESA, B for community)
- **category**: Placeholder for future categorization (empty for agent-generated entries)
- **created**: ISO timestamp when the sample was created

## Quick start
- Edit / add samples under `data/<id>/`
- Run `python scripts/build_manifest.py` to rebuild the manifest and checksums
- (Optional) run `python scripts/validate_manifest.py` to validate the dataset
