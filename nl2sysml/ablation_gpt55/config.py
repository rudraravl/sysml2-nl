"""Configuration for the GPT-5.5 executable-rule ablation study."""

from __future__ import annotations

import os
from pathlib import Path

ABLATION_DIR = Path(__file__).resolve().parent
NL2SYSML_DIR = ABLATION_DIR.parent
REPO_ROOT = NL2SYSML_DIR.parent

GPT55_MODEL = os.getenv("GPT55_MODEL", "openai/gpt-5.5")
DEFAULT_DATASET = NL2SYSML_DIR / "dataset.json"
RESULT_CSV = ABLATION_DIR / "result.csv"
HTML_REPORT = ABLATION_DIR / "index.html"
GENERATED_DIR = ABLATION_DIR / "generated"

COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"
RAG_K = int(os.getenv("GPT55_RAG_K", "3"))
