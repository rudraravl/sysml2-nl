"""Compatibility wrapper for SysML validation."""

from app.tools.sysml_tools import validate_sysml as _validate_sysml


def validate_sysml(sysml_text: str) -> dict:
    """Validate SysML v2 code using the registered MBSE validation tool."""

    return _validate_sysml(sysml_text).model_dump()
