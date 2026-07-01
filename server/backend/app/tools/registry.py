"""Registry for MBSE tool calls."""

from typing import Any, Callable

from app.tools.schemas import ToolDefinition, ToolFunction
from app.tools.sysml_tools import validate_sysml_tool


VALIDATE_SYSML_TOOL = ToolDefinition(
    function=ToolFunction(
        name="validate_sysml",
        description="Parse and validate SysML v2 text, returning structured diagnostics.",
        parameters={
            "type": "object",
            "properties": {
                "model_text": {
                    "type": "string",
                    "description": "Complete SysML v2 textual model to validate.",
                },
                "syntax_only": {
                    "type": "boolean",
                    "description": "When true, skip semantic/library checks if the backend supports it.",
                },
            },
            "required": ["model_text"],
            "additionalProperties": False,
        },
    )
)

_TOOL_EXECUTORS: dict[str, Callable[[dict[str, Any]], dict[str, Any]]] = {
    "validate_sysml": validate_sysml_tool,
}


def list_tool_definitions() -> list[ToolDefinition]:
    """Return OpenAI-compatible tool definitions."""

    return [VALIDATE_SYSML_TOOL]


def execute_tool_call(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    """Execute a registered tool by name."""

    executor = _TOOL_EXECUTORS.get(name)
    if executor is None:
        raise KeyError(f"Unknown tool: {name}")
    return executor(arguments)

