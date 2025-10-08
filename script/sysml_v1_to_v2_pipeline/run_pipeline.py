#!/usr/bin/env python
"""Direct Python script to run the DELS pipeline without Typer CLI issues"""

import os
import json
import glob
import hashlib
from rich import print

# Import pipeline modules
from src.ir_schema import IR
from src.extract_v1 import extract_to_ir
from src.map_v1_to_v2 import ir_to_v2_text
from src.render_v2 import write_v2_tree
from src.shard import write_shards_for_file
from src.generate_nl import summarize_v2_text, write_md
from src.validate import validate_v2_dir

def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1<<20), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def main():
    DELS_XML = "/Users/creatix/Documents/sysml2-nl/tmp/DiscreteEventLogisticsSystems-master/DiscreteEventLogisticsSystems.xml"
    
    print("\n" + "="*50)
    print("[bold cyan]SysML v1 → v2 Pipeline for DELS[/bold cyan]")
    print("="*50 + "\n")
    
    # Step 1: Extract
    print("[bold]Step 1: Extracting DELS XML to IR...[/bold]")
    ir = extract_to_ir(DELS_XML)
    with open("dels_ir.json", "w", encoding="utf-8") as f:
        f.write(ir.model_dump_json(indent=2))
    print(f"[green]✓ IR extracted to dels_ir.json[/green]")
    print(f"  Blocks: {len(ir.blocks)}, Requirements: {len(ir.requirements)}, Activities: {len(ir.activities)}\n")
    
    # Step 2: Map to v2
    print("[bold]Step 2: Mapping IR to SysML v2 text...[/bold]")
    os.makedirs("out/dels_v2_raw", exist_ok=True)
    files = ir_to_v2_text(ir)
    write_v2_tree(files, "out/dels_v2_raw")
    print(f"[green]✓ Draft v2 written to out/dels_v2_raw/[/green]")
    print(f"  Generated {len(files)} v2 files\n")
    
    # Step 3: Shard
    print("[bold]Step 3: Sharding into 200-500 line files (target: 400)...[/bold]")
    os.makedirs("out/dels_v2_sharded", exist_ok=True)
    count = 0
    for p in glob.glob(os.path.join("out/dels_v2_raw", "**/*.sysml"), recursive=True):
        count += write_shards_for_file(p, "out/dels_v2_sharded", target=400)
    print(f"[green]✓ Sharded {count} files into out/dels_v2_sharded/[/green]\n")
    
    # Step 4: Generate NL
    print("[bold]Step 4: Generating NL summaries...[/bold]")
    os.makedirs("out/dels_nl", exist_ok=True)
    total = 0
    for p in glob.glob(os.path.join("out/dels_v2_sharded", "*.sysml")):
        with open(p, "r", encoding="utf-8") as f:
            txt = f.read()
        s = summarize_v2_text(txt)
        md_path = os.path.join("out/dels_nl", os.path.basename(p).replace(".sysml", ".md"))
        write_md(s, md_path)
        total += 1
    print(f"[green]✓ NL summaries written: {total}[/green]\n")
    
    # Step 5: Validate
    print("[bold]Step 5: Validating sharded v2 files...[/bold]")
    msg = validate_v2_dir("out/dels_v2_sharded")
    if msg.strip():
        print(f"[yellow]Validation warnings:[/yellow]\n{msg}")
    else:
        print("[green]✓ Validation passed[/green]")
    print()
    
    # Step 6: Generate manifest
    print("[bold]Step 6: Generating dataset manifest...[/bold]")
    os.makedirs("dataset", exist_ok=True)
    with open("dataset/dels_manifest.jsonl", "w", encoding="utf-8") as fout:
        for p in sorted(glob.glob(os.path.join("out/dels_v2_sharded", "*.sysml"))):
            base = os.path.basename(p).rsplit(".", 1)[0]
            nl = os.path.join("out/dels_nl", base + ".md")
            entry = {
                "id": base,
                "sysml2_path": p,
                "nl_path": nl if os.path.exists(nl) else None,
                "stats": {"lines": sum(1 for _ in open(p, "r", encoding="utf-8"))},
                "hash_sysml2": sha256(p),
                "hash_nl": sha256(nl) if os.path.exists(nl) else None,
            }
            fout.write(json.dumps(entry) + "\n")
    print(f"[green]✓ Manifest written to dataset/dels_manifest.jsonl[/green]\n")
    
    print("="*50)
    print("[bold green]Pipeline complete![/bold green]")
    print("="*50 + "\n")
    
    print("[bold]Output summary:[/bold]")
    print("  - IR:              dels_ir.json")
    print("  - Raw v2:          out/dels_v2_raw/")
    print("  - Sharded v2:      out/dels_v2_sharded/")
    print("  - NL summaries:    out/dels_nl/")
    print("  - Manifest:        dataset/dels_manifest.jsonl\n")
    
    print("[bold]Next steps:[/bold]")
    print("  1. Review dels_ir.json to check extraction quality")
    print("  2. Inspect out/dels_v2_sharded/*.sysml files")
    print("  3. Send to SysML v2 expert for review\n")

if __name__ == "__main__":
    main()
