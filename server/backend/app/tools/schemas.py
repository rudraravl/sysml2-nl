"""Schemas for backend tool-calling."""

from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


class ToolFunction(BaseModel):
    """OpenAI-compatible function metadata for a callable tool."""

    name: str
    description: str
    parameters: dict[str, Any]


class ToolDefinition(BaseModel):
    """OpenAI-compatible tool definition."""

    type: Literal["function"] = "function"
    function: ToolFunction


class ToolCallRequest(BaseModel):
    """Generic request to execute a named backend tool."""

    name: str = Field(..., min_length=1)
    arguments: dict[str, Any] = Field(default_factory=dict)


class ToolCallResponse(BaseModel):
    """Generic response from a backend tool invocation."""

    name: str
    ok: bool
    result: dict[str, Any] = Field(default_factory=dict)
    error: Optional[str] = None


class SysMLValidationRequest(BaseModel):
    """Request for the validate_sysml tool."""

    model_text: str = Field(..., min_length=1)
    syntax_only: Optional[bool] = None


class SysMLDiagnostic(BaseModel):
    """Structured diagnostic returned by SysML validation backends."""

    line: int = 0
    column: int = 0
    message: str
    severity: str = "error"
    code: Optional[str] = None
    file: Optional[str] = None


class SysMLValidationResult(BaseModel):
    """Result payload for the validate_sysml tool."""

    ok: bool
    backend: str
    available: bool
    syntax_only: bool
    error_count: int
    diagnostics: list[SysMLDiagnostic] = Field(default_factory=list)

