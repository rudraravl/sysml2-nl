"""Model API definitions and environment for Pass 1 pipeline."""

from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv(*_args, **_kwargs):  # type: ignore[misc]
        return False

# nl2sysml/vlm-gen/sysml_pipeline/config.py
NL2SYSML_DIR = Path(__file__).resolve().parents[2]
VLM_GEN_ROOT = NL2SYSML_DIR / "vlm-gen"
REPO_ROOT = NL2SYSML_DIR.parent

if str(NL2SYSML_DIR) not in sys.path:
    sys.path.insert(0, str(NL2SYSML_DIR))

_ENV_PATH = REPO_ROOT / ".env"

# Path A: Python codegen LLM (OpenRouter model id)
PATH_A_MODEL = os.getenv("VLM_PATH_A_MODEL", "openai/gpt-5.4")

# Path B: direct SysML generation
PATH_B_MODEL = os.getenv("VLM_PATH_B_MODEL", "openai/gpt-5.4")

# MoE combiner
MOE_MODEL = os.getenv("VLM_MOE_MODEL", "anthropic/claude-sonnet-4.5")

SANDBOX_TIMEOUT_SEC = int(os.getenv("VLM_SANDBOX_TIMEOUT_SEC", "45"))
PATH_A_MAX_RETRIES = int(os.getenv("VLM_PATH_A_MAX_RETRIES", "1"))
OUTPUT_SYSML_FILENAME = "output.sysml"


def load_api_keys() -> tuple[str | None, str | None]:
    """Load GEMINI and OPENROUTER keys; configure Gemini if present."""
    load_dotenv(_ENV_PATH)
    gkey = os.getenv("GEMINI_API_KEY")
    or_key = os.getenv("OPENROUTER_API_KEY")
    if gkey:
        import google.generativeai as genai

        genai.configure(api_key=gkey)
    return gkey, or_key


def require_openrouter() -> str:
    _, or_key = load_api_keys()
    if not or_key:
        raise RuntimeError(
            "OPENROUTER_API_KEY missing. Set it in the repo root .env file."
        )
    return or_key
