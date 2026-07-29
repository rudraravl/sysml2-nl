"""Parse SysML compiler/kernel ERROR/WARNING lines into analysis-friendly JSON."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

_DIAG_RE = re.compile(
    r"^(?P<severity>ERROR|WARNING)\s*:\s*(?P<message>.*?)(?:\s+\((?P<location>[^)]+)\))?\s*$",
    re.IGNORECASE,
)
_LOCATION_RE = re.compile(
    r"(?P<file>.+?)\s+line\s*:\s*(?P<line>\d+)\s+column\s*:\s*(?P<column>\d+)",
    re.IGNORECASE,
)

_PARSE_MARKERS = (
    "no viable alternative",
    "mismatched input",
    "missing eof",
    "missing '}'",
    "extraneous input",
    "token recognition error",
)


def _flatten_lines(chunks: Iterable[str]) -> List[str]:
    lines: List[str] = []
    for chunk in chunks:
        for part in str(chunk).splitlines():
            part = part.strip()
            if part:
                lines.append(part)
    return lines


def categorize_message(message: str) -> str:
    """Coarse category for distribution analysis across the dataset."""
    lowered = message.lower()
    if any(marker in lowered for marker in _PARSE_MARKERS):
        return "parse"
    if "duplicate of inherited" in lowered:
        return "duplicate_member"
    if "must be an accessible feature" in lowered:
        return "feature_access"
    if "could not be resolved" in lowered or "couldn't be resolved" in lowered:
        return "unresolved"
    if "already exists" in lowered or "duplicate" in lowered:
        return "duplicate"
    if "is not a" in lowered or "must be a" in lowered:
        return "type_constraint"
    return "other"


def parse_diagnostic_line(line: str) -> Optional[Dict[str, Any]]:
    """Parse one compiler diagnostic line into a structured record."""
    match = _DIAG_RE.match(line.strip())
    if not match:
        return None

    severity = match.group("severity").upper()
    message = match.group("message").strip()
    location = (match.group("location") or "").strip()

    record: Dict[str, Any] = {
        "severity": severity,
        "message": message,
        "raw": line.strip(),
        "category": categorize_message(message),
        "file": None,
        "line": None,
        "column": None,
    }

    if location:
        loc = _LOCATION_RE.search(location)
        if loc:
            record["file"] = loc.group("file").strip()
            record["line"] = int(loc.group("line"))
            record["column"] = int(loc.group("column"))
        else:
            record["location_raw"] = location

    return record


def _unique_preserve(messages: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for msg in messages:
        if msg in seen:
            continue
        seen.add(msg)
        out.append(msg)
    return out


def build_compiler_diagnostics(
    trace: List[str],
    *,
    errors: Optional[List[str]] = None,
    bridge_error: Optional[str] = None,
    compiled: Optional[bool] = None,
    success: Optional[bool] = None,
    model_kind: Optional[str] = None,
    kernel_available: Optional[bool] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Build a dataset-analysis JSON blob from compiler/kernel output."""
    raw_lines = _flatten_lines(trace)
    # Prefer the main compiler stream; fall back to bridge error_lines if needed.
    diagnostic_source = list(raw_lines)
    if errors:
        for line in _flatten_lines(errors):
            if line not in diagnostic_source:
                diagnostic_source.append(line)

    parsed: List[Dict[str, Any]] = []
    non_diagnostic: List[str] = []
    for line in diagnostic_source:
        record = parse_diagnostic_line(line)
        if record is None:
            if line != "# errors":
                non_diagnostic.append(line)
            continue
        parsed.append(record)

    error_recs = [r for r in parsed if r["severity"] == "ERROR"]
    warning_recs = [r for r in parsed if r["severity"] == "WARNING"]

    error_messages = [r["message"] for r in error_recs]
    warning_messages = [r["message"] for r in warning_recs]
    error_counts = Counter(error_messages)
    warning_counts = Counter(warning_messages)
    category_counts = Counter(r["category"] for r in error_recs)
    warning_category_counts = Counter(r["category"] for r in warning_recs)
    line_counts = Counter(
        r["line"] for r in error_recs if isinstance(r.get("line"), int)
    )

    lines_with_errors = sorted(line_counts)
    payload: Dict[str, Any] = {
        "raw_trace": "\n".join(raw_lines),
        "raw_trace_lines": raw_lines,
        "errors": error_recs,
        "warnings": warning_recs,
        "n_errors": len(error_recs),
        "n_warnings": len(warning_recs),
        "n_unique_errors": len(error_counts),
        "n_unique_warnings": len(warning_counts),
        "unique_error_messages": _unique_preserve(error_messages),
        "unique_warning_messages": _unique_preserve(warning_messages),
        "error_counts_by_message": dict(error_counts.most_common()),
        "warning_counts_by_message": dict(warning_counts.most_common()),
        "error_counts_by_category": dict(category_counts.most_common()),
        "warning_counts_by_category": dict(warning_category_counts.most_common()),
        "error_counts_by_line": {
            str(line): count for line, count in sorted(line_counts.items())
        },
        "first_error_line": lines_with_errors[0] if lines_with_errors else None,
        "last_error_line": lines_with_errors[-1] if lines_with_errors else None,
        "has_errors": bool(error_recs),
        "has_warnings": bool(warning_recs),
        "non_diagnostic_lines": non_diagnostic,
        "bridge_error": bridge_error,
    }

    if compiled is not None:
        payload["compiled"] = compiled
    if success is not None:
        payload["success"] = success
    if model_kind is not None:
        payload["model_kind"] = model_kind
    if kernel_available is not None:
        payload["kernel_available"] = kernel_available
    if extra:
        payload.update(extra)

    return payload


def format_compiler_diagnostics_json(diagnostics: Dict[str, Any]) -> str:
    return json.dumps(diagnostics, indent=2, ensure_ascii=False) + "\n"


def write_compiler_diagnostics_file(
    path: str | Path,
    diagnostics: Dict[str, Any],
) -> str:
    """Write structured compiler diagnostics JSON to disk."""
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(format_compiler_diagnostics_json(diagnostics), encoding="utf-8")
    return str(target)
