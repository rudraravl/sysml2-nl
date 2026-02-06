"""Pipeline registry."""

from fastapi import HTTPException

from app.pipelines.base import BasePipeline, PipelineName

# Lazy imports to avoid circular dependencies
_pipelines: dict[str, BasePipeline] = {}


def _init_pipelines():
    """Initialize pipelines on first access."""
    if _pipelines:
        return

    from app.pipelines.kalm_gemma.pipeline import KaLMGemmaPipeline
    from app.pipelines.qwen.pipeline import QwenPipeline
    from app.pipelines.llama.pipeline import LlamaPipeline

    _pipelines["kalm"] = KaLMGemmaPipeline()
    _pipelines["qwen"] = QwenPipeline()
    _pipelines["llama"] = LlamaPipeline()


def get_pipeline(name: PipelineName) -> BasePipeline:
    """Get a pipeline by name."""
    _init_pipelines()
    if name not in _pipelines:
        raise HTTPException(status_code=400, detail=f"Unknown pipeline: {name}")
    return _pipelines[name]


def list_pipelines() -> list[str]:
    """List available pipeline names."""
    _init_pipelines()
    return list(_pipelines.keys())
