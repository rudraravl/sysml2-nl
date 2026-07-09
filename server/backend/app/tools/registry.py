"""Registry for MBSE tool calls."""

from typing import Any, Callable

from app.tools.mbse_catalog import list_mbse_tools_tool, recommend_mbse_tools_tool
from app.tools.schemas import ToolDefinition, ToolFunction
from app.tools.syson_tools import import_sysml_to_syson_tool
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

LIST_MBSE_TOOLS_TOOL = ToolDefinition(
    function=ToolFunction(
        name="list_mbse_tools",
        description="List MBSE/SysML v2 tool candidates from the verified compatibility catalog.",
        parameters={
            "type": "object",
            "properties": {
                "min_compatibility": {
                    "type": "string",
                    "enum": ["High", "Medium", "Listed-not-scored", "Low", "Unverified"],
                    "description": "Minimum verified compatibility level to return.",
                },
                "availability": {
                    "type": "string",
                    "enum": ["Available", "Development"],
                    "description": "Optional availability filter.",
                },
                "include_unverified": {
                    "type": "boolean",
                    "description": "Whether to include tools without public SysML v2 verification.",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of tools to return.",
                },
            },
            "additionalProperties": False,
        },
    )
)

RECOMMEND_MBSE_TOOLS_TOOL = ToolDefinition(
    function=ToolFunction(
        name="recommend_mbse_tools",
        description="Recommend MBSE/SysML v2 tool candidates for a validation, authoring, visualization, or integration task.",
        parameters={
            "type": "object",
            "properties": {
                "task": {
                    "type": "string",
                    "description": "Short task description, such as validation, graphical authoring, visualization, integration, or versioning.",
                },
                "include_unverified": {
                    "type": "boolean",
                    "description": "Whether to include unverified/research candidates.",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of recommendations to return.",
                },
            },
            "required": ["task"],
            "additionalProperties": False,
        },
    )
)

IMPORT_SYSML_TO_SYSON_TOOL = ToolDefinition(
    function=ToolFunction(
        name="import_sysml_to_syson",
        description=(
            "Upload SysML v2 text to a configured, running SysON backend and verify "
            "that the import created model elements."
        ),
        parameters={
            "type": "object",
            "properties": {
                "model_text": {"type": "string", "description": "Complete SysML v2 text to import."},
                "project_id": {"type": "string", "description": "Existing target SysON project ID."},
                "filename": {
                    "type": "string",
                    "description": "Safe .sysml filename; defaults to generated-model.sysml.",
                },
            },
            "required": ["model_text", "project_id"],
            "additionalProperties": False,
        },
    )
)

_TOOL_EXECUTORS: dict[str, Callable[[dict[str, Any]], dict[str, Any]]] = {
    "validate_sysml": validate_sysml_tool,
    "list_mbse_tools": list_mbse_tools_tool,
    "recommend_mbse_tools": recommend_mbse_tools_tool,
    "import_sysml_to_syson": import_sysml_to_syson_tool,
}


def list_tool_definitions() -> list[ToolDefinition]:
    """Return OpenAI-compatible tool definitions."""

    return [
        VALIDATE_SYSML_TOOL,
        LIST_MBSE_TOOLS_TOOL,
        RECOMMEND_MBSE_TOOLS_TOOL,
        IMPORT_SYSML_TO_SYSON_TOOL,
    ]


def execute_tool_call(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    """Execute a registered tool by name."""

    executor = _TOOL_EXECUTORS.get(name)
    if executor is None:
        raise KeyError(f"Unknown tool: {name}")
    return executor(arguments)
