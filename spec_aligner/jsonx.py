"""Pull a JSON object/array out of raw LLM output."""

from __future__ import annotations

import json
import re


def extract_json(raw: str):
    text = raw.strip()
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if m:
        text = m.group(1).strip()
    starts = sorted(
        c for c in ((text.find("{"), "}"), (text.find("["), "]")) if c[0] != -1
    )
    for start, close in starts:
        end = text.rfind(close)
        if end > start:
            try:
                return json.loads(text[start : end + 1])
            except ValueError:
                continue
    raise ValueError(f"no JSON found in LLM output: {text[:200]!r}")