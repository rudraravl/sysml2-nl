"""Configuration for the GPT-5.4 ablation study."""

from __future__ import annotations

import os
from enum import Enum
from pathlib import Path

NL2SYSML_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = NL2SYSML_DIR.parent

GPT_MODEL = "openai/gpt-5.4"
DEFAULT_DATASET = NL2SYSML_DIR / "dataset.json"
RESULTS_ROOT = Path(__file__).resolve().parent / "results"

MAX_REFINEMENT_ITERATIONS = int(os.getenv("MAX_REFINEMENT_ITERATIONS", "2"))
COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"
RAG_K = 3


class Condition(str, Enum):
    BASELINE = "baseline"
    RAG = "rag"
    MOE = "moe"

    @property
    def output_dir_name(self) -> str:
        return {
            Condition.BASELINE: "baseline_no_rag",
            Condition.RAG: "rag_gpt54",
            Condition.MOE: "moe_full",
        }[self]

    @property
    def label(self) -> str:
        return {
            Condition.BASELINE: "A: GPT-5.4, no retrieval",
            Condition.RAG: "B: GPT-5.4 + lexical RAG",
            Condition.MOE: "C: MOE + compiler refinement",
        }[self]


CONDITION_ORDER = [Condition.BASELINE, Condition.RAG, Condition.MOE]
