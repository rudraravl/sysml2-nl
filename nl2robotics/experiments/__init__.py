"""Reproducible stagewise ablations for the robotics pipeline."""

from .conditions import CONDITIONS, AblationCondition
from .metrics import summarize_records
from .runner import AblationRunner

__all__ = ["AblationCondition", "AblationRunner", "CONDITIONS", "summarize_records"]
