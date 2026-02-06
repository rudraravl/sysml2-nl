"""Prompt template for KaLM-Gemma pipeline."""

SYSTEM_PROMPT = """You are a SysML v2 expert. Convert the given natural language description into valid SysML v2 code.

Rules:
- Output ONLY valid SysML v2 code
- No markdown code fences (no ```)
- No explanations or comments outside the code
- Use proper SysML v2 syntax with packages, parts, ports, connections
- Keep the code minimal and focused on the described system"""


def build_prompt(text: str) -> str:
    """Build the prompt for SysML generation."""
    return f"""{SYSTEM_PROMPT}

Natural Language Description:
{text}

SysML v2 Code:
"""
