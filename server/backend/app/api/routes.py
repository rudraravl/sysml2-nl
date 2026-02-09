"""API routes."""

from fastapi import APIRouter, HTTPException

from app.api.schemas import (
    NL2SysMLRequest,
    NL2SysMLResponse,
    Diagnostics,
    VersionResponse,
    HealthResponse,
    StatusResponse,
)
from app.pipelines.registry import get_pipeline, list_pipelines
from app.runtime.resources import model_manager
from app.core.logging import get_logger

log = get_logger(__name__)
router = APIRouter()


@router.post("/api/nl2sysml", response_model=NL2SysMLResponse)
async def nl2sysml(req: NL2SysMLRequest):
    """Convert natural language to SysML."""
    log.info(f"Request: pipeline={req.pipeline}, text_len={len(req.text)}")

    pipeline = get_pipeline(req.pipeline)
    sysml, diag_extra = await pipeline.run(req.text, req.max_new_tokens)

    # Map pipeline-specific diagnostics to common fields
    # kalm pipeline uses generator_* prefix, others use direct names
    loaded_from_cache = diag_extra.get("generator_loaded_from_cache", diag_extra.get("loaded_from_cache", False))
    model_load_ms = diag_extra.get("generator_load_ms", diag_extra.get("model_load_ms", 0))
    
    return NL2SysMLResponse(
        pipeline=req.pipeline,
        sysml=sysml,
        diagnostics=Diagnostics(
            loaded_from_cache=loaded_from_cache,
            model_load_ms=model_load_ms,
            gen_ms=diag_extra.get("gen_ms", 0),
            unloaded_models=diag_extra.get("unloaded_models", []),
            # Encoder/embedding fields (kalm pipeline only)
            encoder_loaded_from_cache=diag_extra.get("encoder_loaded_from_cache"),
            encoder_load_ms=diag_extra.get("encoder_load_ms"),
            embedding_ms=diag_extra.get("embedding_ms"),
            embedding_dim=diag_extra.get("embedding_dim"),
        ),
    )



@router.get("/api/version", response_model=VersionResponse)
async def version():
    """Get API version and available pipelines."""
    return VersionResponse(
        version="0.2.0",
        pipelines=list_pipelines(),
    )


@router.get("/health", response_model=HealthResponse)
async def health():
    """Health check."""
    return HealthResponse(status="healthy")


@router.get("/api/status", response_model=StatusResponse)
async def status():
    """Debug endpoint: show loaded models."""
    st = await model_manager.status()
    return StatusResponse(
        loaded_models=st["loaded_models"],
        last_used=st["last_used"],
    )
