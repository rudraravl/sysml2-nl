from __future__ import annotations
import os, re, json, hashlib
from typing import Dict, List

def summarize_v2_text(text: str) -> Dict[str, List[str] | str]:
    """Heuristic, model-free NL summary (placeholder).
    You can replace with an LLM and the provided prompt template."""
    title = "Chunk"
    m = re.search(r"package\s+([^\n;]+)", text)
    if m:
        title = m.group(1).strip()
    defs = re.findall(r"(part def|requirement)\s+([^\s{;]+)", text)
    key = [f"{k} {n}" for k, n in defs]
    ports = re.findall(r"\bport\s+([A-Za-z0-9_]+)", text)
    conns = re.findall(r"\bconnection\s+([^\n;]+);", text)
    return {
        "title": title,
        "scope": "Auto‑summary of elements in this shard.",
        "key_elements": key[:20],
        "interfaces": ports[:20],
        "connections": conns[:10],
    }

def write_md(summary: Dict, out_path: str) -> None:
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(f"# {summary['title']}\n\n")
        f.write(f"**Scope:** {summary['scope']}\n\n")
        if summary.get("key_elements"):
            f.write("**Key elements:**\n")
            for x in summary["key_elements"]:
                f.write(f"- {x}\n")
            f.write("\n")
        if summary.get("interfaces"):
            f.write("**Interfaces (ports):**\n")
            for x in summary["interfaces"]:
                f.write(f"- {x}\n")
            f.write("\n")
        if summary.get("connections"):
            f.write("**Connections:**\n")
            for x in summary["connections"]:
                f.write(f"- {x}\n")
            f.write("\n")
