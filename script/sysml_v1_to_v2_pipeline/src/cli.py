from __future__ import annotations
import os, json, glob, hashlib, shutil
import typer
from typing import Optional
from rich import print
from .ir_schema import IR
from .extract_v1 import extract_to_ir
from .map_v1_to_v2 import ir_to_v2_text
from .render_v2 import write_v2_tree
from .shard import write_shards_for_file
from .generate_nl import summarize_v2_text, write_md
from .validate import validate_v2_dir

app = typer.Typer(help="SysML v1 → v2 sharded pipeline")

def _sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1<<20), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

@app.command()
def extract(input_file: str, out: Optional[str] = typer.Option("ir.json")):
    """Extract SysML v1 XML/MDZIP to IR JSON"""
    ir = extract_to_ir(input_file)
    with open(out, "w", encoding="utf-8") as f:
        f.write(ir.model_dump_json(indent=2))
    print(f"[green]IR written to {out}[/green]  (blocks={len(ir.blocks)}, reqs={len(ir.requirements)})")

@app.command()
def map(ir: str, out: Optional[str] = typer.Option("out/v2_raw")):
    """Map IR to SysML v2 text"""
    os.makedirs(out, exist_ok=True)
    with open(ir, "r", encoding="utf-8") as f:
        IR_obj = IR.model_validate_json(f.read())
    files = ir_to_v2_text(IR_obj)
    write_v2_tree(files, out)
    print(f"[green]Draft v2 written under {out}[/green]")

@app.command()
def shard(v2dir: str, out: Optional[str] = typer.Option("out/v2_sharded"), target: Optional[int] = typer.Option(400)):
    """Shard v2 files into 200-500 line chunks"""
    os.makedirs(out, exist_ok=True)
    count = 0
    for p in glob.glob(os.path.join(v2dir, "**/*.sysml"), recursive=True):
        count += write_shards_for_file(p, out, target=target)
    print(f"[green]Sharded {count} files into {out}[/green]")

@app.command()
def nl(v2dir: str, ir: str, out: Optional[str] = typer.Option("out/nl")):
    """Generate NL summaries for v2 shards"""
    os.makedirs(out, exist_ok=True)
    total = 0
    for p in glob.glob(os.path.join(v2dir, "*.sysml")):
        with open(p, "r", encoding="utf-8") as f:
            txt = f.read()
        s = summarize_v2_text(txt)
        md_path = os.path.join(out, os.path.basename(p).replace(".sysml", ".md"))
        write_md(s, md_path)
        total += 1
    print(f"[green]NL summaries written: {total}[/green]")

@app.command()
def validate(v2dir: str):
    """Validate v2 files"""
    msg = validate_v2_dir(v2dir)
    if msg.strip():
        print(msg)
    else:
        print("[green]Validation passed[/green]")

@app.command()
def manifest(v2dir: str, nldir: str, out: Optional[str] = typer.Option("dataset/manifest.jsonl")):
    """Generate dataset manifest"""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fout:
        for p in sorted(glob.glob(os.path.join(v2dir, "*.sysml"))):
            base = os.path.basename(p).rsplit(".", 1)[0]
            nl = os.path.join(nldir, base + ".md")
            entry = {
                "id": base,
                "sysml2_path": p,
                "nl_path": nl if os.path.exists(nl) else None,
                "stats": {"lines": sum(1 for _ in open(p, "r", encoding="utf-8"))},
                "hash_sysml2": _sha256(p),
                "hash_nl": _sha256(nl) if os.path.exists(nl) else None,
            }
            fout.write(json.dumps(entry) + "\n")
    print(f"[green]Manifest written to {out}[/green]")

if __name__ == "__main__":
    app()