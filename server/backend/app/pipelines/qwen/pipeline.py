"""Qwen pipeline stub."""

from fastapi import HTTPException

from app.pipelines.base import BasePipeline


class QwenPipeline(BasePipeline):
    """Stub pipeline for Qwen."""

    @property
    def name(self) -> str:
        return "qwen"

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Not implemented."""
        raise HTTPException(
            status_code=501,
            detail="Qwen pipeline not implemented yet"
        )
