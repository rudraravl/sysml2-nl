#!/bin/bash

# SysML v1 to v2 Pipeline - DELS Translation
# This script runs the complete pipeline for DiscreteEventLogisticsSystems.xml

set -e  # Exit on any error

DELS_XML="/Users/creatix/Documents/sysml2-nl/tmp/DiscreteEventLogisticsSystems-master/DiscreteEventLogisticsSystems.xml"
PIPELINE_DIR="/Users/creatix/Documents/sysml2-nl/script/sysml_v1_to_v2_pipeline"

cd "$PIPELINE_DIR"

echo "=========================================="
echo "SysML v1 → v2 Pipeline for DELS"
echo "=========================================="
echo ""

# Step 1: Extract DELS XML to IR
echo "Step 1: Extracting DELS XML to IR..."
python -m src.cli extract "$DELS_XML" --out dels_ir.json
echo "✓ IR extracted to dels_ir.json"
echo ""

# Step 2: Map IR to v2 text (deterministic)
echo "Step 2: Mapping IR to SysML v2 text..."
python -m src.cli map --ir dels_ir.json --out out/dels_v2_raw
echo "✓ Draft v2 text written to out/dels_v2_raw/"
echo ""

# Step 3: Shard into 200-500 line files
echo "Step 3: Sharding into 200-500 line files (target: 400)..."
python -m src.cli shard --v2dir out/dels_v2_raw --out out/dels_v2_sharded --target 400
echo "✓ Sharded files written to out/dels_v2_sharded/"
echo ""

# Step 4: Generate NL summaries
echo "Step 4: Generating NL summaries..."
python -m src.cli nl --v2dir out/dels_v2_sharded --ir dels_ir.json --out out/dels_nl
echo "✓ NL summaries written to out/dels_nl/"
echo ""

# Step 5: Validate
echo "Step 5: Validating sharded v2 files..."
python -m src.cli validate --v2dir out/dels_v2_sharded
echo "✓ Validation complete"
echo ""

# Step 6: Generate manifest
echo "Step 6: Generating dataset manifest..."
python -m src.cli manifest --v2dir out/dels_v2_sharded --nldir out/dels_nl --out dataset/dels_manifest.jsonl
echo "✓ Manifest written to dataset/dels_manifest.jsonl"
echo ""

echo "=========================================="
echo "Pipeline complete!"
echo "=========================================="
echo ""
echo "Output summary:"
echo "  - IR:              dels_ir.json"
echo "  - Raw v2:          out/dels_v2_raw/"
echo "  - Sharded v2:      out/dels_v2_sharded/"
echo "  - NL summaries:    out/dels_nl/"
echo "  - Manifest:        dataset/dels_manifest.jsonl"
echo ""
echo "Next steps:"
echo "  1. Review dels_ir.json to check extraction quality"
echo "  2. Inspect out/dels_v2_sharded/*.sysml files"
echo "  3. Send to SysML v2 expert for review"
echo ""
