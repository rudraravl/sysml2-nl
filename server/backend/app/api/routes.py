"""API routes."""

import json
import asyncio
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from app.api.schemas import (
    NL2SysMLRequest,
    NL2SysMLResponse,
    Diagnostics,
    RefineRequest,
    RefineResponse,
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


@router.post("/api/nl2sysml/stream")
async def nl2sysml_stream(req: NL2SysMLRequest):
    """Convert natural language to SysML with streaming progress updates (SSE)."""
    log.info(f"Stream request: pipeline={req.pipeline}, text_len={len(req.text)}")

    async def event_generator():
        progress_queue = asyncio.Queue()
        loop = asyncio.get_event_loop()
        
        def progress_callback(stage: str, detail: str):
            # Thread-safe: callbacks may come from run_in_executor threads
            try:
                loop.call_soon_threadsafe(
                    progress_queue.put_nowait,
                    {"type": "progress", "stage": stage, "detail": detail}
                )
            except Exception:
                pass
        
        pipeline = get_pipeline(req.pipeline)
        
        # Set progress callback if agentic pipeline
        if hasattr(pipeline, 'set_progress_callback'):
            pipeline.set_progress_callback(progress_callback)
        
        # Start the pipeline in a task
        async def run_pipeline():
            try:
                sysml, diag_extra = await pipeline.run(req.text, req.max_new_tokens)
                await progress_queue.put({"type": "result", "sysml": sysml, "diagnostics": diag_extra})
            except Exception as e:
                await progress_queue.put({"type": "error", "message": str(e)})
        
        task = asyncio.create_task(run_pipeline())
        
        # Stream progress updates
        while True:
            try:
                # Wait for next update with timeout
                msg = await asyncio.wait_for(progress_queue.get(), timeout=0.5)
                yield f"data: {json.dumps(msg)}\n\n"
                
                if msg["type"] in ("result", "error"):
                    break
            except asyncio.TimeoutError:
                # Send heartbeat to keep connection alive
                yield f"data: {json.dumps({'type': 'heartbeat'})}\n\n"
                
                # Check if task is done
                if task.done():
                    break
        
        # Ensure task is complete
        await task
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )



@router.post("/api/nl2sysml/refine", response_model=RefineResponse)
async def nl2sysml_refine(req: RefineRequest):
    """Refine existing SysML output using only the combiner model."""
    import time
    from pathlib import Path
    from app.pipelines.agentic.pipeline import (
        _rag_context, _default_system_prompt, _invoke_with_retry,
        COMBINER_MODEL, GEMINI_API_KEY,
    )
    import google.generativeai as genai

    log.info(f"Refine request: instruction_len={len(req.instruction)}, sysml_len={len(req.current_sysml)}")

    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not configured")

    genai.configure(api_key=GEMINI_API_KEY)
    root = Path(__file__).resolve().parents[4]
    loop = asyncio.get_event_loop()

    start = time.time()

    # Rebuild RAG context for the original requirement
    context = await loop.run_in_executor(None, _rag_context, req.original_text, root, 3)

    sys_msg = _default_system_prompt(
        "You are refining an existing SysML v2 model based on user feedback. "
        "Apply the requested changes precisely. Keep all correct parts unchanged."
    )
    human_msg = (
        f"{context}\n\n"
        f"Original requirement:\n{req.original_text}\n\n"
        f"Current SysML v2 model:\n{req.current_sysml}\n\n"
        f"Refinement instruction:\n{req.instruction}\n\n"
        "Apply the refinement instruction to the SysML model above. "
        "Output only the complete refined SysML v2 code."
    )

    refined = await loop.run_in_executor(None, _invoke_with_retry, COMBINER_MODEL, sys_msg, human_msg)
    gen_ms = int((time.time() - start) * 1000)

    log.info(f"Refine complete in {gen_ms}ms, output {len(refined)} chars")
    return RefineResponse(sysml=refined or req.current_sysml, gen_ms=gen_ms)


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
