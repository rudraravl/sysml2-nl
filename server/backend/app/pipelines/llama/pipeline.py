"""Llama pipeline stub."""

from fastapi import HTTPException

from app.pipelines.base import BasePipeline


class LlamaPipeline(BasePipeline):
    """Stub pipeline for Llama."""

    @property
    def name(self) -> str:
        return "llama"

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Not implemented."""
        raise HTTPException(
            status_code=501,
            detail="Llama pipeline not implemented yet"
        )
