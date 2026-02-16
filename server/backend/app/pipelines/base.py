"""Base pipeline interface."""

from abc import ABC, abstractmethod
from typing import Literal

PipelineName = Literal["agentic", "kalm", "qwen", "llama"]


class BasePipeline(ABC):
    """Abstract base class for all pipelines."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Pipeline name."""
        pass

    @abstractmethod
    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """
        Run the pipeline.
        
        Args:
            text: Input natural language text
            max_new_tokens: Maximum tokens to generate
            
        Returns:
            (sysml_output, diagnostics_dict)
        """
        pass
