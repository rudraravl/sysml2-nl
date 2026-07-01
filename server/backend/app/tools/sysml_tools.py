"""SysML v2 MBSE tools exposed through the tool-calling layer."""

import json
import os
import sys
from pathlib import Path
from typing import Any, Optional
from urllib import request as url_request
from urllib.error import URLError

from app.tools.schemas import SysMLDiagnostic, SysMLValidationResult

_REPO_ROOT = Path(__file__).resolve().parents[4]
if _REPO_ROOT.exists() and str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))


def _compiler_api():
    try:
        from nl2sysml.compiler_interface import check_code, is_compiler_available

        return check_code, is_compiler_available
    except Exception:
        return None, lambda: False


def is_validate_sysml_available() -> bool:
    """Return whether an authoritative SysML validation backend is available."""

    _, is_compiler_available = _compiler_api()
    if is_compiler_available():
        return True
    return bool(os.getenv("SYSML_VALIDATOR_URL"))


def validate_sysml(model_text: str, syntax_only: Optional[bool] = None) -> SysMLValidationResult:
    """Validate SysML v2 text with the configured MBSE backend."""

    check_code, is_compiler_available = _compiler_api()
    resolved_syntax_only = (
        os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"
        if syntax_only is None
        else syntax_only
    )

    if check_code is not None and is_compiler_available():
        return _validate_with_compiler(check_code, model_text, resolved_syntax_only)

    validator_url = os.getenv("SYSML_VALIDATOR_URL")
    if validator_url:
        return _validate_with_rest(validator_url, model_text, resolved_syntax_only)

    return SysMLValidationResult(
        ok=False,
        backend="unconfigured",
        available=False,
        syntax_only=resolved_syntax_only,
        error_count=1,
        diagnostics=[
            SysMLDiagnostic(
                message=(
                    "No authoritative SysML validation backend is configured. "
                    "Set up sysml2-compiler or configure SYSML_VALIDATOR_URL."
                ),
                severity="error",
            )
        ],
    )


def _validate_with_compiler(check_code, model_text: str, syntax_only: bool) -> SysMLValidationResult:
    """Validate with the local sysml2-compiler wrapper."""

    result = check_code(model_text, syntax_only=syntax_only)
    diagnostics = _compiler_diagnostics(getattr(result, "errors", []))
    return SysMLValidationResult(
        ok=bool(getattr(result, "is_valid", False)),
        backend="sysml_compiler",
        available=True,
        syntax_only=syntax_only,
        error_count=getattr(result, "error_count", len(diagnostics)),
        diagnostics=diagnostics,
    )


def _compiler_diagnostics(errors) -> list[SysMLDiagnostic]:
    """Normalize compiler errors to the shared tool result schema."""

    return [
        SysMLDiagnostic(
            line=getattr(error, "line", 0) or 0,
            column=getattr(error, "column", 0) or 0,
            message=getattr(error, "message", str(error)),
            severity=getattr(error, "severity", "error") or "error",
            code=getattr(error, "code", None),
            file=getattr(error, "file", None),
        )
        for error in errors
    ]


def _validate_with_rest(validator_url: str, model_text: str, syntax_only: bool) -> SysMLValidationResult:
    """Validate through a REST MBSE backend using the same tool contract."""

    payload = {
        "source": model_text,
        "model_text": model_text,
        "syntax_only": syntax_only,
    }
    data = json.dumps(payload).encode("utf-8")
    req = url_request.Request(
        validator_url,
        data=data,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    try:
        with url_request.urlopen(req, timeout=float(os.getenv("SYSML_VALIDATOR_TIMEOUT", "30"))) as resp:
            raw = json.loads(resp.read().decode("utf-8", errors="replace"))
    except (OSError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        return SysMLValidationResult(
            ok=False,
            backend="rest_validator",
            available=False,
            syntax_only=syntax_only,
            error_count=1,
            diagnostics=[
                SysMLDiagnostic(
                    message=f"REST validator request failed: {exc}",
                    severity="error",
                )
            ],
        )

    diagnostics = _rest_diagnostics(raw.get("diagnostics") or raw.get("errors") or [])
    ok = bool(raw.get("ok", raw.get("valid", raw.get("is_valid", not diagnostics))))
    return SysMLValidationResult(
        ok=ok,
        backend=str(raw.get("backend", "rest_validator")),
        available=True,
        syntax_only=syntax_only,
        error_count=int(raw.get("error_count", len([d for d in diagnostics if d.severity != "warning"]))),
        diagnostics=diagnostics,
    )


def _rest_diagnostics(items: Any) -> list[SysMLDiagnostic]:
    """Normalize diagnostics from a REST validator."""

    if not isinstance(items, list):
        return []
    diagnostics = []
    for item in items:
        if isinstance(item, str):
            diagnostics.append(SysMLDiagnostic(message=item))
        elif isinstance(item, dict):
            diagnostics.append(
                SysMLDiagnostic(
                    line=int(item.get("line") or 0),
                    column=int(item.get("column") or 0),
                    message=str(item.get("message") or item),
                    severity=str(item.get("severity") or "error"),
                    code=item.get("code"),
                    file=item.get("file"),
                )
            )
    return diagnostics


def validate_sysml_tool(arguments: dict[str, Any]) -> dict[str, Any]:
    """Execute validate_sysml from a generic tool-call argument payload."""

    model_text = arguments.get("model_text")
    if not isinstance(model_text, str) or not model_text.strip():
        raise ValueError("validate_sysml requires non-empty string argument 'model_text'")
    syntax_only = arguments.get("syntax_only")
    if syntax_only is not None and not isinstance(syntax_only, bool):
        raise ValueError("validate_sysml argument 'syntax_only' must be a boolean when provided")
    return validate_sysml(model_text=model_text, syntax_only=syntax_only).model_dump()
