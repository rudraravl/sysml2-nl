"""API request/response schemas."""

from typing import Literal, Optional
from pydantic import BaseModel, Field, ConfigDict


class NL2SysMLRequest(BaseModel):
    """Request for NL to SysML conversion."""
    text: str = Field(..., min_length=1, description="Natural language input")
    pipeline: Literal["agentic", "kalm", "qwen", "llama"] = Field(default="agentic")
    max_new_tokens: int = Field(default=4096, ge=1, le=65536)


class Diagnostics(BaseModel):
    """Generation diagnostics."""
    model_config = ConfigDict(protected_namespaces=())
    
    # Generator diagnostics (common to all pipelines)
    loaded_from_cache: bool
    model_load_ms: int
    gen_ms: int
    unloaded_models: list[str] = Field(default_factory=list)
    
    # Encoder/embedding diagnostics (kalm pipeline only)
    encoder_loaded_from_cache: Optional[bool] = None
    encoder_load_ms: Optional[int] = None
    embedding_ms: Optional[int] = None
    embedding_dim: Optional[int] = None


class NL2SysMLResponse(BaseModel):
    """Response from NL to SysML conversion."""
    pipeline: str
    sysml: str
    diagnostics: Diagnostics


class RefineRequest(BaseModel):
    """Request to refine existing SysML output."""
    original_text: str = Field(..., min_length=1, description="Original NL requirement")
    current_sysml: str = Field(..., min_length=1, description="Current generated SysML code")
    instruction: str = Field(..., min_length=1, description="Refinement instruction from user")
    max_new_tokens: int = Field(default=4096, ge=1, le=65536)


class RefineResponse(BaseModel):
    """Response from refinement."""
    sysml: str
    gen_ms: int


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
