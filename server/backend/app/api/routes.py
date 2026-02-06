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

    return NL2SysMLResponse(
        pipeline=req.pipeline,
        sysml=sysml,
        diagnostics=Diagnostics(
            loaded_from_cache=diag_extra.get("loaded_from_cache", False),
            model_load_ms=diag_extra.get("model_load_ms", 0),
            gen_ms=diag_extra.get("gen_ms", 0),
            unloaded_models=diag_extra.get("unloaded_models", []),
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
