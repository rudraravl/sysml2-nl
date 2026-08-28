#!/usr/bin/env python3
"""
Ingest Solidity documentation into a RAG chunk index.

Retargeted from script/ingest_sysml_spec.py. Produces
nl2solidity/spec_index/chunks.jsonl, which agent_rag_moe._rag_context reads.

============================== DANGLING (RAG samples) ==============================
Point `spec_dir` at a folder of Solidity reference material (the Solidity docs
PDF/HTML export, EIP text, security guides, etc.) and run this to populate the
index. Until then chunks.jsonl is absent/empty and RAG spec retrieval is a no-op.
===================================================================================
"""

import json
import subprocess
from pathlib import Path


def pdf_to_text_bytes(pdf: Path) -> bytes:
    try:
        return subprocess.check_output(["pdftotext", str(pdf), "-"], stderr=subprocess.DEVNULL)
    except Exception as e:
        raise SystemExit(f"pdftotext failed on {pdf}: {e}")


def normalize(s: str) -> str:
    lines = [ln.rstrip() for ln in s.splitlines()]
    return "\n".join(lines).strip()


def chunks(s: str, size: int = 2200, overlap: int = 250):
    if size <= 0:
        yield s
        return
    start = 0
    n = len(s)
    while start < n:
        end = min(n, start + size)
        yield s[start:end].strip()
        if end == n:
            break
        start = max(end - overlap, start + 1)


def main():
    repo = Path(__file__).resolve().parents[1]
    # DANGLING: drop Solidity reference PDFs here (or adapt to read .md/.html).
    spec_dir = repo / "nl2solidity" / "spec_source"
    out_dir = repo / "nl2solidity" / "spec_index"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_jsonl = out_dir / "chunks.jsonl"

    pdfs = sorted(spec_dir.glob("*.pdf")) if spec_dir.is_dir() else []
    if not pdfs:
        raise SystemExit(
            f"No PDFs found in {spec_dir}. Add Solidity reference material "
            "(docs/EIPs/security guides) and re-run. RAG spec retrieval stays "
            "a no-op until chunks.jsonl exists."
        )

    with out_jsonl.open("w", encoding="utf-8") as f:
        for pdf in pdfs:
            raw = pdf_to_text_bytes(pdf)
            txt = normalize(raw.decode("utf-8", errors="ignore"))
            title = pdf.stem
            rel = pdf.relative_to(repo)
            idx = 0
            for c in chunks(txt):
                if not c:
                    continue
                rec = {
                    "id": f"{title}#c{idx}",
                    "title": title,
                    "source": str(rel),
                    "chunk_index": idx,
                    "text": c,
                }
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                idx += 1

    print(f"Wrote {out_jsonl}")


if __name__ == "__main__":
    main()
