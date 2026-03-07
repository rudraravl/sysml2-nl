"""
SysML Architecture Composer – Deterministic DSL generator, parser, and Graphviz renderer.
No LLM usage; all transformations are purely rule-based.
"""

from app.sysml_composer.model import (
    SysMLModel,
    SysMLModelBuilder,
    parse_sysml_to_model,
    build_model_from_form,
    render_diagram,
)
from app.sysml_composer.dot_check import DOT_AVAILABLE

__all__ = [
    "SysMLModel",
    "SysMLModelBuilder",
    "parse_sysml_to_model",
    "build_model_from_form",
    "render_diagram",
    "DOT_AVAILABLE",
]
