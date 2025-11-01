"""
LangChain setup and retrieval flow

The model is implemented as a LangChain pipeline: a ChatPromptTemplate builds a two‑message chat (system + human), a ChatGoogleGenerativeAI client (Gemini 2.5 Pro) produces the response, and a StrOutputParser returns plain text. The human message takes two variables, `{context}` and `{input}`. `{context}` is assembled per call by a lightweight retriever that ranks local dataset examples and pre‑chunked spec passages and concatenates the top hits into a compact guidance block. The system message encodes strict output formatting constraints. A small post‑processor strips markdown fences and similar markers, and a single retry runs with a stricter system hint if constraints are violated or output is empty.

Invocation modes reuse the same chain. One‑shot mode passes a single `{input}` and prints the result. Batch mode iterates over prompts from `nl2sysml/dataset.json`, constructs `{context}` per prompt, records the exact resolved System/Human messages to `nl2sysml/result_rag/U{i}_prompt.txt`, and writes the chain output to `nl2sysml/result_rag/U{i}.sysml`. Credentials load from `.env` and the spec index is produced by `script/ingest_sysml_spec.py`.
"""

import os
from pathlib import Path
import sys, json
from pathlib import Path

# Keep it simple: minimal imports and setup
from dotenv import load_dotenv
import google.generativeai as genai
import re
import json
from typing import List, Tuple

# Centralized prompt templates
def _default_system_prompt(user_hint: str | None = None) -> str:
    base = (
        "You generate valid SysML v2 concrete syntax only. "
        "No markdown, no fences, no prose. "
        "Prefer correct grammar and consistency. "
        "Produce complete, non-trivial models that satisfy the requirement with appropriate parts, ports, connections, items/value types (with units), behaviors (state machines/actions), and requirements when applicable. "
        "Avoid placeholders and undefined references."
    )
    if user_hint and user_hint.strip():
        return (user_hint.strip() + " ") + base
    return base


PROMPT_HUMAN_TEMPLATE = (
    "{context}\n\n"
    "Generate SysML v2 code for the following requirement. "
    "Produce a complete, detailed, non-trivial model with appropriate parts, ports, connections, item/value types (with units), behaviors (state machines/actions), and requirements as applicable. "
    "Avoid placeholders. Requirement: {input}"
)


def _load_env():
    # Load repo-level .env (two dirs up from this file)
    load_dotenv(Path(__file__).parent.parent / ".env")
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY missing in environment/.env")
    genai.configure(api_key=key)
    return key


def build_agent(system_hint: str | None = None):
    """
    Return a simple LangChain pipeline backed by Gemini 2.5 Pro.
    - Uses a concise system prompt tuned for SysML v2 concrete syntax.
    - Minimal plumbing; fail fast if deps or key are missing.
    """
    _load_env()

    # Prefer LangChain wrapper, but keep a direct model for simple calls/tests
    try:
        from langchain_core.prompts import ChatPromptTemplate
        from langchain_core.output_parsers import StrOutputParser
        from langchain_google_genai import ChatGoogleGenerativeAI
    except Exception as e:
        raise RuntimeError(
            "LangChain or langchain-google-genai not installed: "
            "pip install langchain-core langchain-google-genai"
        ) from e

    # Default system guidance distilled from related papers + completeness bias
    sys_msg = _default_system_prompt(system_hint)

    # LLM
    llm = ChatGoogleGenerativeAI(
        model="gemini-2.5-pro",
        api_key=os.getenv("GEMINI_API_KEY"),
        temperature=0.2,
    )

    # Prompt → LLM → text
    prompt = ChatPromptTemplate.from_messages([
        ("system", sys_msg),
        ("human", PROMPT_HUMAN_TEMPLATE),
    ])
    chain = prompt | llm | StrOutputParser()
    return chain


def _tokenize(s: str) -> List[str]:
    return [t for t in re.split(r"[^A-Za-z0-9_]+", s.lower()) if t]


def _similarity(a: str, b: str) -> float:
    ta, tb = set(_tokenize(a)), set(_tokenize(b))
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    return inter / (len(ta) ** 0.5 * len(tb) ** 0.5)


def _collect_examples(root: Path, limit: int = 300) -> List[Tuple[str, str]]:
    pairs = []
    data_dir = root / "dataset" / "data"
    if not data_dir.exists():
        return pairs
    for p in sorted(data_dir.glob("*/*")):
        if p.suffix == ".txt":
            sysml = p.with_suffix(".sysml")
            if sysml.exists():
                try:
                    txt = p.read_text(encoding="utf-8")
                    code = sysml.read_text(encoding="utf-8")
                except Exception:
                    continue
                pairs.append((txt, code))
                if len(pairs) >= limit:
                    break
    return pairs


def _rag_context(nl_prompt: str, root: Path, k: int = 3) -> str:
    # Dataset examples (few-shot)
    examples = _collect_examples(root)
    blocks = []
    if examples:
        scored = sorted(
            ((ex, _similarity(nl_prompt, ex[0])) for ex in examples),
            key=lambda x: x[1], reverse=True,
        )
        top_data = [e for (e, s) in scored[:5] if s > 0]
        for i, (txt, code) in enumerate(top_data, 1):
            # Keep code-only and trim comments for clarity
            lines = []
            for ln in code.splitlines():
                t = ln.strip()
                if not t or t.startswith("//"):
                    continue
                lines.append(ln)
                if len(lines) >= 80:
                    break
            code_snip = "\n".join(lines)
            blocks.append(
                f"Example {i} NL:\n{txt.strip()}\n\nExample {i} SysML:\n{code_snip}\n---"
            )

    # Spec chunks (keyword-biased)
    spec_jsonl = root / "nl2sysml" / "spec_index" / "chunks.jsonl"
    if spec_jsonl.exists():
        try:
            hits = []
            prompt_tokens = _tokenize(nl_prompt)
            keywords = {t for t in prompt_tokens if len(t) >= 4}
            with spec_jsonl.open("r", encoding="utf-8") as fh:
                for line in fh:
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    txt = rec.get("text", "")
                    title = rec.get("title", "")
                    base = _similarity(nl_prompt, txt)
                    if base <= 0:
                        continue
                    # Keyword bonus
                    low = txt.lower()
                    kcount = sum(1 for kw in keywords if kw in low)
                    bonus = min(kcount * 0.01, 0.08)
                    # Prefer textual notation and kernel docs
                    title_bonus = 0.0
                    if "Textual Notation" in title or "Kernel_Modeling_Language" in title:
                        title_bonus = 0.05
                    score = base + bonus + title_bonus
                    hits.append((rec, score))
            hits.sort(key=lambda x: x[1], reverse=True)
            for j, (rec, s) in enumerate(hits[:3], 1):
                txt = rec.get("text", "")
                title = rec.get("title", "Spec")
                blocks.append(f"Spec {j} [{title}]:\n{txt}\n---")
        except Exception:
            pass

    if not blocks:
        return ""
    return (
        "Use the following examples and specification excerpts as guidance. "
        "Follow grammar; prefer simple, correct constructs.\n" + "\n".join(blocks)
    )


def _postprocess(code: str) -> str:
    # Strip markdown fences and any leading markers
    lines = []
    for ln in code.splitlines():
        if ln.strip().startswith("```"):
            continue
        if ln.strip().lower().startswith("sysml") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    out = "\n".join(lines).strip()
    return out


def generate_sysml(prompt_text: str, system_hint: str | None = None) -> str:
    """
    One-shot helper to get SysML v2 code for a natural-language prompt.
    Uses simple RAG and light post-processing.
    """
    root = Path(__file__).parent.parent
    context = _rag_context(prompt_text, root, k=3)
    chain = build_agent(system_hint)
    resp = chain.invoke({"input": prompt_text, "context": context})
    code = _postprocess(resp)
    # Retry once if markdown fences remain or empty
    if ("```" in resp) or (not code):
        strong_hint = (
            (system_hint or "")
            + " No markdown, no fences, no prose. Output SysML code only."
        ).strip()
        chain = build_agent(strong_hint)
        resp = chain.invoke({"input": prompt_text, "context": context})
        code = _postprocess(resp)
    return code


if __name__ == "__main__":
    args = " ".join(sys.argv[1:]).strip()
    if args:
        print(generate_sysml(args))
        raise SystemExit(0)

    base = Path(__file__).parent
    ds_path = base / "dataset.json"
    result_dir = base / "result_rag"
    result_dir.mkdir(parents=True, exist_ok=True)

    data = json.load(open(ds_path))
    prompts = data.get("prompts", [])
    if not prompts:
        raise SystemExit("No prompts found in dataset.json")

    for item in prompts:
        pid = str(item.get("id", "")).strip()
        desc = str(item.get("description", "")).strip()
        if not desc:
            continue
        fname = f"{pid.upper()}.sysml"
        out_path = result_dir / fname

        # Build prompt text to record
        repo_root = base.parent
        context = _rag_context(desc, repo_root, k=3)
        sys_msg = _default_system_prompt(None)
        human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=desc)

        # Generate code
        sysml = generate_sysml(desc)
        content = f"// {desc}\n{sysml}\n"
        out_path.write_text(content)
        print(f"wrote {out_path}")

        # Write prompt record
        prompt_path = result_dir / f"{pid.upper()}_prompt.txt"
        prompt_body = (
            "System:\n" + sys_msg + "\n\n" +
            "Human:\n" + human_msg + "\n"
        )
        prompt_path.write_text(prompt_body)
        print(f"wrote {prompt_path}")