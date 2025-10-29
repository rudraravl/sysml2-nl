#!/usr/bin/env python3
import os
import json
import subprocess
from pathlib import Path


def pdfto_text_bytes(pdf: Path) -> bytes:
    try:
        out = subprocess.check_output(["pdftotext", str(pdf), "-"], stderr=subprocess.DEVNULL)
        return out
    except Exception as e:
        raise SystemExit(f"pdftotext failed on {pdf}: {e}")


def normalize(s: str) -> str:
    # Collapse excessive whitespace while keeping paragraphs
    lines = [ln.rstrip() for ln in s.splitlines()]
    # Drop empty leading/trailing blocks
    text = "\n".join(lines).strip()
    return text


def chunks(s: str, size: int = 2000, overlap: int = 200):
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
    spec_dir = repo / "tmp" / "SysML-v2-Release" / "doc"
    out_dir = repo / "nl2sysml" / "spec_index"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_jsonl = out_dir / "chunks.jsonl"

    pdfs = sorted(spec_dir.glob("*.pdf"))
    if not pdfs:
        raise SystemExit(f"No PDFs found in {spec_dir}")

    with out_jsonl.open("w", encoding="utf-8") as f:
        for pdf in pdfs:
            raw = pdfto_text_bytes(pdf)
            txt = normalize(raw.decode("utf-8", errors="ignore"))
            title = pdf.stem
            rel = pdf.relative_to(repo)
            idx = 0
            for c in chunks(txt, size=2200, overlap=250):
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

