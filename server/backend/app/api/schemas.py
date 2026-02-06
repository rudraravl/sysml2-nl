"""API request/response schemas."""

from typing import Literal, Optional
from pydantic import BaseModel, Field, ConfigDict


class NL2SysMLRequest(BaseModel):
    """Request for NL to SysML conversion."""
    text: str = Field(..., min_length=1, description="Natural language input")
    pipeline: Literal["kalm", "qwen", "llama"] = Field(default="kalm")
    max_new_tokens: int = Field(default=768, ge=1, le=4096)


class Diagnostics(BaseModel):
    """Generation diagnostics."""
    model_config = ConfigDict(protected_namespaces=())
    
    loaded_from_cache: bool
    model_load_ms: int
    gen_ms: int
    unloaded_models: list[str] = Field(default_factory=list)


class NL2SysMLResponse(BaseModel):
    """Response from NL to SysML conversion."""
    pipeline: str
    sysml: str
    diagnostics: Diagnostics


class VersionResponse(BaseModel):
    """API version info."""
    version: str
    pipelines: list[str]


class HealthResponse(BaseModel):
    """Health check response."""
    status: str


class StatusResponse(BaseModel):
    """Debug status response."""
    loaded_models: list[str]
    last_used: dict[str, float]
