"""Configuration for GPT-5.5 ablation studies."""

from __future__ import annotations

import os
from pathlib import Path

ABLATION_DIR = Path(__file__).resolve().parent
NL2SYSML_DIR = ABLATION_DIR.parent
REPO_ROOT = NL2SYSML_DIR.parent

GPT55_MODEL = os.getenv("GPT55_MODEL", "openai/gpt-5.5")
DEFAULT_DATASET = NL2SYSML_DIR / "dataset.json"
NL_SEED_FILE = NL2SYSML_DIR / "nl_seed.jsonl"

# Executable-rule study (dataset.json, 20 prompts)
RESULT_CSV = ABLATION_DIR / "result.csv"
HTML_REPORT = ABLATION_DIR / "index.html"
GENERATED_DIR = ABLATION_DIR / "generated"

# Stage A: GPT-5.5 only on nl_seed.jsonl (no RAG, no MOE)
BASELINE_OUTPUT_DIR = ABLATION_DIR / "results" / "baseline_nl_seed"
BASELINE_DEFAULT_NUM_ENTRIES = int(os.getenv("GPT55_BASELINE_NUM_ENTRIES", "50"))

COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"
RAG_K = int(os.getenv("GPT55_RAG_K", "3"))

EXECUTABLE_HINT = (
    "Generate SysML v2 code only. Include executable behavior when applicable. "
    "For signal accepts, expose typed payload/output parameters. "
    "For messages, assign signatures and realize signal messages with flows/connectors. "
    "For state machines, call only locally defined or structurally reachable actions. "
    "For submachine states, reference defined state machines in the owning structure."
)
