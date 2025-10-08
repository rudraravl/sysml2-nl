# Quick Start Guide

## TL;DR - Run the Pipeline

```bash
cd /Users/creatix/Documents/sysml2-nl/script/sysml_v1_to_v2_pipeline
python run_pipeline.py
```

That's it! The pipeline will automatically process the DELS model and generate all outputs.

---

## What You Get

After running, you'll have:

1. **`dels_ir.json`** - Intermediate representation (64 blocks, 127 parts)
2. **`out/dels_v2_sharded/Core.part01.sysml`** - SysML v2 text (384 lines)
3. **`out/dels_nl/Core.part01.md`** - Natural language summary
4. **`dataset/dels_manifest.jsonl`** - Dataset manifest with checksums

---

## View the Results

```bash
# View the IR
cat dels_ir.json | head -50

# View the generated v2 code
cat out/dels_v2_sharded/Core.part01.sysml | head -50

# View the NL summary
cat out/dels_nl/Core.part01.md

# View the manifest
cat dataset/dels_manifest.jsonl
```

---

## For Other Models

To process a different SysML v1 model:

1. Edit `run_pipeline.py` line 27:
   ```python
   DELS_XML = "/path/to/your/model.xml"  # or .mdzip
   ```

2. Run:
   ```bash
   python run_pipeline.py
   ```

---

## Manual Control

If you want to run steps individually:

```bash
# Step 1: Extract
python -m src.cli extract /path/to/model.xml --out ir.json

# Step 2: Map
python -m src.cli map ir.json --out out/v2_raw

# Step 3: Shard
python -m src.cli shard out/v2_raw --out out/v2_sharded --target 400

# Step 4: NL
python -m src.cli nl out/v2_sharded ir.json --out out/nl

# Step 5: Validate
python -m src.cli validate out/v2_sharded

# Step 6: Manifest
python -m src.cli manifest out/v2_sharded out/nl --out dataset/manifest.jsonl
```

---

## Current Status

✅ **WORKING** - Successfully extracted and translated DELS model  
✅ **64 blocks** converted to SysML v2  
✅ **127 part relationships** preserved  
✅ **384 lines** of clean v2 text generated  

⚠️ **TODO** - Enhance extraction for:
- Requirements (0 extracted, needs XPath)
- Activities (0 extracted, needs XPath)
- Ports and connectors
- Value properties and constraints

---

## Need Help?

- See `README.md` for detailed documentation
- See `RESULTS.md` for complete analysis
- See `PIPELINE_SUCCESS.md` for full report

---

## Files to Review

1. **`dels_ir.json`** - Check if all expected blocks are present
2. **`out/dels_v2_sharded/Core.part01.sysml`** - Review v2 syntax and structure
3. **`out/dels_nl/Core.part01.md`** - Check NL summary quality

---

## Next Steps

1. 📧 Send `Core.part01.sysml` to SysML v2 expert
2. 💬 Get feedback on mapping conventions
3. 🔧 Enhance extractor based on feedback
4. 🚀 Scale to larger models

---

**Questions?** Check the full documentation in `README.md`
