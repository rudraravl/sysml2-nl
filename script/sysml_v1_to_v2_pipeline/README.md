# SysML v1 → SysML v2 Sharded Pipeline

**End-to-end turnkey pipeline**: SysML v1 (DELS .xml/.mdzip) → JSON IR → deterministic v1→v2 text → shard to 200–500 lines → NL summaries → validation + manifest.

This starter implementation provides a complete scaffold for converting large SysML v1 models into many small, semantically coherent SysML v2 artifacts suitable for dataset creation.

---

## What This Does (In One Line)

**SysML v1 (DELS .xml/.mdzip) → JSON IR → deterministic v1→v2 text → shard to 200–500 lines → NL summaries → validation + manifest.**

Usage-focused post-org and mapping choices follow the DoD guidance: v2 "definitions vs usages", parts/action trees, etc.

---

## Step 0: Prerequisites

- Python 3.8+
- SysML v1 model exported as `.xml` or `.mdzip` file
- (Optional) OpenAI API key for LLM-based NL summary generation

---

## Step 1: Set Up the Environment

```bash
# Navigate to the pipeline directory
cd /path/to/sysml_v1_to_v2_pipeline

# Install dependencies directly in your conda base environment
pip install -r requirements.txt
```

**Dependencies:**
- `lxml>=5.2.1` — XML parsing
- `pydantic>=2.7.0` — IR schema validation
- `typer>=0.12.3` — CLI framework
- `rich>=13.7.1` — Terminal output formatting
- `networkx>=3.3` — Graph operations for sharding

---

## Step 2: Quick Sanity Check (Verify Toolchain)

Run the pipeline on the minimal example to ensure everything works:

```bash
# Map minimal IR to v2
python -m src.cli map --ir examples/minimal_ir.json --out out/v2_raw

# Shard into 300-line chunks
python -m src.cli shard --v2dir out/v2_raw --out out/v2_sharded --target 300

# Generate NL summaries
python -m src.cli nl --v2dir out/v2_sharded --ir examples/minimal_ir.json --out out/nl

# Validate
python -m src.cli validate --v2dir out/v2_sharded

# Create manifest
python -m src.cli manifest --v2dir out/v2_sharded --nldir out/nl --out dataset/manifest.jsonl
```

**Expected output:**
- `out/v2_raw/*.sysml` — Draft v2 text files
- `out/v2_sharded/*.sysml` — 200–500-line shards
- `out/nl/*.md` — Natural language summaries
- `dataset/manifest.jsonl` — Dataset index with metadata

---

## Step 3: Extract Your DELS Model (XML or MDZIP) → IR

Extract your SysML v1 model into an intermediate representation (JSON):

```bash
# For XML files
python -m src.cli extract --input /path/to/DiscreteEventLogisticsSystems.xml --out ir.json

# For MDZIP files (they will be unzipped automatically)
python -m src.cli extract --input /path/to/model.mdzip --out ir.json
```

**What this does:**
- Parses the SysML v1 XML/MDZIP file
- Extracts blocks, requirements, activities, ports, connectors, etc.
- Produces a **conservative IR** (JSON) that decouples tool-specific XML from generation

**Important:** If counts come back empty or low, you may need to edit the XPaths in `src/extract_v1.py` to match your specific export format. MagicDraw/Cameo XMI varies by exporter version.

**Why an IR?**
- Decouples tool-specific XML from generation/sharding
- Provides strong guardrails for LLM prompts later
- Makes the pipeline auditable and debuggable

---

## Step 4: Deterministic v1→v2 Mapping (Draft v2 Text)

Generate draft SysML v2 text using rule-based mappings:

```bash
python -m src.cli map --ir ir.json --out out/v2_raw
```

**Core mappings implemented:**
- SysML v1 **block → v2 part definition**
- SysML v1 **requirement → v2 requirement definition**
- SysML v1 **activity → v2 action definition**
- Attributes, ports, and connectors (basic mappings)

**Mapping philosophy:**
- Follows DoD guidance on **usage-focused** organization
- Implements **definitions vs usages** separation
- Maps v1 `satisfy` → v2 **satisfy requirement usage** (richer semantics)
- For v1-like semantics, can use **requirement allocation** instead

You can incrementally enhance mappings in `src/map_v1_to_v2.py` for:
- More complex port/connector patterns
- Value properties with constraints
- Requirement cross-links (verify/derive/refine)

---

## Step 5: Shard into 200–500-Line Files

Split the large v2 files into semantically coherent chunks:

```bash
python -m src.cli shard --v2dir out/v2_raw --out out/v2_sharded --target 400
```

**Sharding strategy:**
- Target size: 200–500 lines (default: 400)
- Current implementation: packs by blank-line "blocks"
- **For production:** Replace with anchor-BFS sharder (by top block/scenario root/req subtree) to maximize cohesion
- Splits by concern: Structure / Behavior / Requirements / Interfaces
- Records exports/imports for each shard

**DoD guidance notes:**
- Expect **post-processing** and **re-organization**
- Move toward usage-focused structure (Definitions/* vs Usage/*)
- Build PartsTree and ActionTree hierarchies

---

## Step 6: Generate NL Summaries (Dataset Pairs)

Create natural language summaries for each shard:

```bash
python -m src.cli nl --v2dir out/v2_sharded --ir ir.json --out out/nl
```

**Current implementation:**
- Creates **model-free** summaries (runs offline, no API calls)
- Extracts basic metadata from shard content

**For production:**
- Swap in LLM call using `prompts/nl_prompt.txt`
- Guardrail prompt: "Do not invent new elements. Only summarize existing definitions."
- LLM should refine style, not semantics

---

## Step 7: Validate & Package

Validate the generated v2 files and create the dataset manifest:

```bash
# Validate sharded files
python -m src.cli validate --v2dir out/v2_sharded

# Generate manifest
python -m src.cli manifest --v2dir out/v2_sharded --nldir out/nl --out dataset/manifest.jsonl
```

**Validation checks:**
- Line count budgets (200–500 lines per file)
- Basic package structure presence
- File naming conventions
- (Future) Syntax validation, import/export consistency

**Manifest includes:**
- File paths (sysml2_path, nl_path)
- Line counts
- SHA-256 checksums
- Exports/imports lists
- Metadata

---

## Step 8: Expert Review Questions

Send the generated v2 artifacts to your SysML v2 expert and ask:

1. **Mapping choices**: Do our mappings (e.g., satisfy→allocation vs satisfy usage) match their preference?
   - *DoD notes*: v1 `satisfy` → v2 **satisfy requirement usage** has richer semantics
   - For v1-like semantics they used **requirement allocation**

2. **Post-processing structure**: Is our organization moving toward **usage-focused** structure (Definitions vs Usage, parts/action trees)?

3. **Validation checks**: Any additional checks needed before treating shards as reference v2?

4. **Package layout**: Are package names and hierarchy following v2 best practices?

---

## Step 9: Enhance for Higher Fidelity

When you need more complete mappings:

### Extend the Extractor (`src/extract_v1.py`):
- Add XPaths for **ports** (flow ports, proxy ports)
- Add XPaths for **connectors** (item flows, bindings)
- Add XPaths for **value properties** and **constraints**
- Add XPaths for **stereotypes** (map to v2 metadata/#keywords)

### Extend the Mapper (`src/map_v1_to_v2.py`):
- Port definitions with directions (in/out/inout)
- `connection` lines with `item` types
- Requirement cross-links (verify/derive/refine map cleanly)
- Behavioral flows and control structures
- Use cases and scenarios

### Post-Processing:
- Re-organize files into `Definitions/*` vs `Usage/*`
- Build **PartsTree** hierarchy for structural decomposition
- Build **ActionTree** hierarchy for behavioral flows
- Align with v2 idioms and best practices

---

## One-Liner: Complete Pipeline

After you've tuned the extractor, run the entire pipeline:

```bash
python -m src.cli extract --input /path/to/DELS.xml --out ir.json \
&& python -m src.cli map --ir ir.json --out out/v2_raw \
&& python -m src.cli shard --v2dir out/v2_raw --out out/v2_sharded --target 400 \
&& python -m src.cli nl --v2dir out/v2_sharded --ir ir.json --out out/nl \
&& python -m src.cli validate --v2dir out/v2_sharded \
&& python -m src.cli manifest --v2dir out/v2_sharded --nldir out/nl --out dataset/manifest.jsonl
```

---

## Example: DELS DiscreteEventLogisticsSystems.xml

### Quick Run (Using the Convenience Script)

```bash
# Run the complete pipeline with one command
./run_dels_pipeline.sh
```

This script automatically runs all 6 steps for the DELS model.

### Manual Step-by-Step (For the DELS model)

```bash
# Step 1: Extract
python -m src.cli extract \
  --input /Users/creatix/Documents/sysml2-nl/tmp/DiscreteEventLogisticsSystems-master/DiscreteEventLogisticsSystems.xml \
  --out dels_ir.json

# Step 2: Map to v2
python -m src.cli map --ir dels_ir.json --out out/dels_v2_raw

# Step 3: Shard
python -m src.cli shard --v2dir out/dels_v2_raw --out out/dels_v2_sharded --target 400

# Step 4: Generate NL
python -m src.cli nl --v2dir out/dels_v2_sharded --ir dels_ir.json --out out/dels_nl

# Step 5: Validate
python -m src.cli validate --v2dir out/dels_v2_sharded

# Step 6: Manifest
python -m src.cli manifest --v2dir out/dels_v2_sharded --nldir out/dels_nl --out dataset/dels_manifest.jsonl
```

---

## Project Layout

```
sysml_v1_to_v2_pipeline/
├── README.md                 # This file
├── requirements.txt          # Python dependencies
├── src/
│   ├── cli.py               # Typer CLI entry point
│   ├── ir_schema.py         # IR dataclasses (Block, Requirement, Activity, etc.)
│   ├── extract_v1.py        # XML/MDZIP → IR (edit XPaths for your export)
│   ├── map_v1_to_v2.py      # Deterministic v1→v2 text generator
│   ├── render_v2.py         # Write v2 text files
│   ├── shard.py             # Budgeted sharder (200–500 lines)
│   ├── generate_nl.py       # NL summary generation (stub for LLM)
│   └── validate.py          # Lightweight validation checks
├── examples/
│   └── minimal_ir.json      # Example IR for testing
├── prompts/
│   └── nl_prompt.txt        # Template prompt for LLM NL generation
└── out/                     # Generated outputs (created on first run)
```

---

## Notes & Gotchas

### Layout Will Not Carry Over
- Focus on **semantic equivalence** first
- Regenerate views in a v2 tool later (DoD team used Jupyter + PlantUML pilot for v2 text)

### Expect Refactoring
- Package re-organization (Definitions vs Usage)
- Parts/action hierarchies
- Requirement allocations
- Import/export cleanup

### XPath Tuning
- MagicDraw/Cameo XMI varies by exporter version
- The scaffold won't crash but may return empty lists
- Check `ir.json` after extraction and tune XPaths in `src/extract_v1.py` if needed

### Sharding Strategy
- Current: simple blank-line block packing
- Production: anchor-BFS by block/req subtree for better cohesion
- Keep large units/enums in shared `Libraries/` packages

### LLM Role (Polish Only)
- Input: deterministic v2 + IR snippet
- Output: stylistically refined v2 text or short NL summary
- Guardrail: "Do not invent new elements. Only reorganize or reformat existing definitions for v2 idiom."

---

## Advanced: Anchor-BFS Sharder

For better semantic cohesion, implement an anchor-BFS sharder:

1. Split by concern: Structure / Behavior / Requirements / Interfaces
2. Within each concern, anchor on top block or scenario root
3. Greedy BFS add elements until ~400 lines
4. Record `exports`/`imports` for cross-references
5. Keep large units/enums in shared `Libraries/` packages

---

## Troubleshooting

### Empty IR after extraction
- Check the XML structure of your export
- Update XPaths in `src/extract_v1.py` to match your XML schema
- Look for namespace prefixes (e.g., `uml:`, `xmi:`)

### Validation errors
- Check line counts are within 200–500 range
- Verify package declarations are present
- Check for syntax errors in generated v2 text

### Missing imports/exports
- Enhance the sharder to track cross-references
- Add import resolution logic in `src/shard.py`

---

## Contributing

This is a starter scaffold. Expected enhancements:

- [ ] More complete XPath coverage for all v1 elements
- [ ] Advanced anchor-BFS sharder
- [ ] Syntax validation using SysML v2 parser
- [ ] Semantic consistency checks
- [ ] Import/export resolution and optimization
- [ ] LLM integration for NL summaries
- [ ] Post-processing for usage-focused organization

---

## References

- **DoD SysML v1 to v2 Transition Approach**: Guidance on mapping conventions and usage-focused organization
- **DELS Repository**: https://github.com/usnistgov/DiscreteEventLogisticsSystems
- **SysML v2 Release**: https://github.com/Systems-Modeling/SysML-v2-Release

---

## License

See LICENSE file for details.