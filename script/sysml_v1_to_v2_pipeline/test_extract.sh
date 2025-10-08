#!/bin/bash

# Quick test: Extract DELS XML to IR
cd /Users/creatix/Documents/sysml2-nl/script/sysml_v1_to_v2_pipeline

echo "Testing extraction..."
python -m src.cli extract \
  --input '/Users/creatix/Documents/sysml2-nl/tmp/DiscreteEventLogisticsSystems-master/DiscreteEventLogisticsSystems.xml' \
  --out dels_ir.json

echo ""
echo "Extraction complete! Check dels_ir.json"
echo ""
echo "Quick stats:"
python -c "import json; d=json.load(open('dels_ir.json')); print(f'Blocks: {len(d[\"blocks\"])}, Requirements: {len(d[\"requirements\"])}, Activities: {len(d[\"activities\"])}')"
