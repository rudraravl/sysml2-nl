"""Headless static-analysis pass over a candidate contract.

Pipeline stage 3: run before the (expensive) semantic spec-alignment evaluator,
so a contract with a high-severity vulnerability gets repaired first.

Primary tool is Slither; Aderyn is supported as an alternative backend. Both are
optional - when neither is installed the stage reports ``available=False`` and
the generation loop skips it, the same way it skips compiler and execution when
those are missing.

Filtering matters more than detection here. Slither ships ~90 detectors, most of
them informational (naming conventions, solc version, unindexed events, dead
code). Feeding all of them into a repair loop would spend model calls on style
and drown the findings that matter, so only High/Medium *impact* findings whose
confidence is also High/Medium are treated as actionable by default; the rest
are recorded for analysis but never trigger a repair.

Usage::

    from nl2solidity.security_analysis import analyze_solidity
    result = analyze_solidity(code)
    for finding in result.blocking():
        print(finding.detector, finding.impact, finding.line)
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2solidity.solidity_execution.models import SecurityFinding, SecurityResult

ACTIONABLE_IMPACTS = ("High", "Medium")
ACTIONABLE_CONFIDENCE = ("High", "Medium")

# Detectors whose findings are noise for freshly generated, self-contained
# contracts: they describe project hygiene rather than a defect the model can
# meaningfully repair.
DEFAULT_EXCLUDED_DETECTORS = {
    "solc-version",
    "pragma",
    "naming-convention",
    "similar-names",
    "too-many-digits",
    "low-level-calls",
    "assembly",
    "dead-code",
    "unused-state",
    "costly-loop",
    "external-function",
    "immutable-states",
    "constable-states",
}

_analysis_slots: Optional[threading.BoundedSemaphore] = None
_analysis_slots_lock = threading.Lock()


def _analysis_gate() -> threading.BoundedSemaphore:
    global _analysis_slots
    with _analysis_slots_lock:
        if _analysis_slots is None:
            cap = max(1, int(os.getenv("SECURITY_MAX_CONCURRENCY", "3")))
            _analysis_slots = threading.BoundedSemaphore(cap)
        return _analysis_slots


def _tool_binary(name: str, env_var: str) -> Optional[str]:
    explicit = os.getenv(env_var)
    if explicit:
        return explicit if Path(explicit).exists() or shutil.which(explicit) else None
    # Prefer the interpreter's own environment before PATH, so a venv install is
    # found even when the shell PATH points elsewhere.
    local = Path(sys.executable).parent / name
    if local.exists():
        return str(local)
    return shutil.which(name)


def active_tool() -> Optional[str]:
    """Which analyzer will be used, or None when the stage is unavailable."""
    if os.getenv("SECURITY_ANALYSIS_ENABLED", "true").lower() == "false":
        return None
    preferred = os.getenv("SECURITY_ANALYSIS_TOOL", "slither").lower()
    order = [preferred] + [t for t in ("slither", "aderyn") if t != preferred]
    for tool in order:
        if tool == "slither" and _tool_binary("slither", "SLITHER_BIN"):
            return "slither"
        if tool == "aderyn" and _tool_binary("aderyn", "ADERYN_BIN"):
            return "aderyn"
    return None


def is_analysis_available() -> bool:
    return active_tool() is not None


def analyzer_version() -> Optional[str]:
    tool = active_tool()
    if tool is None:
        return None
    binary = _tool_binary(tool, "SLITHER_BIN" if tool == "slither" else "ADERYN_BIN")
    try:
        proc = subprocess.run([binary, "--version"], capture_output=True,
                              text=True, timeout=60)
    except Exception:
        return None
    text = (proc.stdout or proc.stderr or "").strip().splitlines()
    return f"{tool} {text[0]}" if text else tool


def _solc_binary_for(source: str) -> Optional[str]:
    """The solc the checker would pick, so Slither compiles like we do."""
    try:
        from nl2solidity.check_solidity import SolidityChecker
        checker = SolidityChecker(
            solc_binary=os.getenv("SOLC_BIN"),
            default_version=os.getenv("SOLC_DEFAULT_VERSION", "0.8.26"),
            auto_install=os.getenv("SOLC_AUTO_INSTALL", "true").lower() != "false",
        )
        return checker._resolve_binary(checker._pragma_of(source))
    except Exception:
        return None


def _excluded_detectors() -> set:
    override = os.getenv("SECURITY_EXCLUDED_DETECTORS")
    if override is None:
        return set(DEFAULT_EXCLUDED_DETECTORS)
    return {name.strip() for name in override.split(",") if name.strip()}


_PATH_NOISE_RE = re.compile(r"(?:\.\./)*(?:/?[\w.\-]+/)*Candidate\.sol")


def _clean_description(text: str) -> str:
    """Strip the temp-directory path Slither embeds in every location.

    Slither prints absolute (or deeply relative) paths for each source location;
    left in place they dominate the repair prompt and leak scratch directories.
    """
    return " ".join(_PATH_NOISE_RE.sub("Candidate.sol", text).split())


def _finding_from_slither(entry: Dict[str, Any]) -> Optional[SecurityFinding]:
    elements = entry.get("elements") or []
    contract = function = file_name = None
    line = None

    for element in elements:
        etype = element.get("type")
        source = element.get("source_mapping") or {}
        lines = source.get("lines") or []
        if line is None and lines:
            line = lines[0]
            file_name = source.get("filename_relative") or source.get("filename_short")
        if etype == "function" and function is None:
            function = element.get("name")
            parent = (element.get("type_specific_fields") or {}).get("parent") or {}
            contract = contract or parent.get("name")
        elif etype == "contract" and contract is None:
            contract = element.get("name")

    description = _clean_description(entry.get("description") or "")
    if not description:
        return None

    return SecurityFinding(
        detector=entry.get("check", "unknown"),
        impact=entry.get("impact", "Informational"),
        confidence=entry.get("confidence", "Medium"),
        description=description,
        contract=contract,
        function=function,
        file=file_name,
        line=line,
        tool="slither",
    )


def _run_slither(path: Path, source: str, timeout: float) -> SecurityResult:
    binary = _tool_binary("slither", "SLITHER_BIN")
    if binary is None:
        return SecurityResult(available=False, tool="slither",
                              tool_error="slither not installed")

    args = [binary, str(path), "--json", "-"]
    solc = _solc_binary_for(source)
    if solc:
        args += ["--solc", solc]
    excluded = _excluded_detectors()
    if excluded:
        args += ["--exclude", ",".join(sorted(excluded))]

    try:
        with _analysis_gate():
            proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                                  cwd=str(path.parent))
    except subprocess.TimeoutExpired:
        return SecurityResult(available=True, tool="slither",
                              tool_error=f"slither timed out after {timeout:g}s")
    except Exception as exc:
        return SecurityResult(available=True, tool="slither", tool_error=str(exc))

    # Slither exits non-zero when it finds issues, so the exit code is not an
    # error signal; only unparseable output is.
    stdout = proc.stdout or ""
    brace = stdout.find("{")
    if brace == -1:
        detail = (proc.stderr or stdout).strip()[:500]
        return SecurityResult(available=True, tool="slither",
                              tool_error=f"slither produced no JSON: {detail}")
    try:
        payload = json.loads(stdout[brace:])
    except json.JSONDecodeError as exc:
        return SecurityResult(available=True, tool="slither",
                              tool_error=f"could not parse slither JSON: {exc}")

    if not payload.get("success", True) and not (payload.get("results") or {}):
        error = payload.get("error") or "slither could not analyze the contract"
        return SecurityResult(available=True, tool="slither",
                              tool_error=str(error)[:500])

    findings: List[SecurityFinding] = []
    for entry in ((payload.get("results") or {}).get("detectors") or []):
        finding = _finding_from_slither(entry)
        if finding is not None:
            findings.append(finding)

    return SecurityResult(available=True, tool="slither", findings=findings,
                          analyzed=True)


def _run_aderyn(path: Path, timeout: float) -> SecurityResult:
    binary = _tool_binary("aderyn", "ADERYN_BIN")
    if binary is None:
        return SecurityResult(available=False, tool="aderyn",
                              tool_error="aderyn not installed")

    out_file = path.parent / "aderyn-report.json"
    try:
        with _analysis_gate():
            subprocess.run([binary, str(path.parent), "--output", str(out_file)],
                           capture_output=True, text=True, timeout=timeout)
        payload = json.loads(out_file.read_text(encoding="utf-8"))
    except subprocess.TimeoutExpired:
        return SecurityResult(available=True, tool="aderyn",
                              tool_error=f"aderyn timed out after {timeout:g}s")
    except Exception as exc:
        return SecurityResult(available=True, tool="aderyn", tool_error=str(exc))

    findings: List[SecurityFinding] = []
    for severity, key in (("High", "high_issues"), ("Medium", "medium_issues"),
                          ("Low", "low_issues")):
        for issue in ((payload.get(key) or {}).get("issues") or []):
            for instance in issue.get("instances") or [{}]:
                findings.append(SecurityFinding(
                    detector=issue.get("detector_name", issue.get("title", "unknown")),
                    impact=severity,
                    confidence="Medium",
                    description=issue.get("title", ""),
                    file=instance.get("contract_path"),
                    line=instance.get("line_no"),
                    tool="aderyn",
                ))
    return SecurityResult(available=True, tool="aderyn", findings=findings,
                          analyzed=True)


def analyze_solidity(code: str, *, timeout: Optional[float] = None) -> SecurityResult:
    """Run the static analyzer over one candidate contract. Never raises."""
    tool = active_tool()
    if tool is None:
        return SecurityResult(available=False,
                              tool_error="no static analyzer available "
                                         "(pip install slither-analyzer)")

    timeout = timeout if timeout is not None else float(
        os.getenv("SECURITY_TIMEOUT_SEC", "180"))

    workdir = Path(tempfile.mkdtemp(prefix="nl2solidity-sec-"))
    path = workdir / "Candidate.sol"
    try:
        path.write_text(code, encoding="utf-8")
        if tool == "slither":
            return _run_slither(path, code, timeout)
        return _run_aderyn(path, timeout)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def actionable_findings(result: SecurityResult) -> List[SecurityFinding]:
    """High/medium findings worth a repair round."""
    return [
        f for f in result.findings
        if f.impact in ACTIONABLE_IMPACTS and f.confidence in ACTIONABLE_CONFIDENCE
    ]


def format_findings(findings: List[SecurityFinding], limit: int = 12) -> str:
    """Render findings as repair-loop feedback, with the rule and line number."""
    if not findings:
        return "No high or medium severity findings."
    lines = []
    for finding in findings[:limit]:
        location = f" (line {finding.line})" if finding.line else ""
        scope = ""
        if finding.contract or finding.function:
            scope = f" in {finding.contract or ''}" + (
                f".{finding.function}" if finding.function else "")
        description = " ".join(finding.description.split())
        lines.append(
            f"- [{finding.impact}/{finding.confidence}] {finding.detector}"
            f"{scope}{location}: {description}")
    return "\n".join(lines)


def summarize(result: SecurityResult) -> Dict[str, Any]:
    """Compact record for meta.json / diagnostics."""
    from collections import Counter
    actionable = actionable_findings(result)
    return {
        "available": result.available,
        "tool": result.tool,
        "analyzed": result.analyzed,
        "tool_error": result.tool_error,
        "n_findings": len(result.findings),
        "n_actionable": len(actionable),
        "by_impact": dict(Counter(f.impact for f in result.findings)),
        "detectors": dict(Counter(f.detector for f in result.findings)),
        "actionable": [
            {
                "detector": f.detector,
                "impact": f.impact,
                "confidence": f.confidence,
                "line": f.line,
                "contract": f.contract,
                "function": f.function,
                "description": " ".join(f.description.split())[:400],
            }
            for f in actionable
        ],
    }


def _cli() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Static-analysis pass (Slither/Aderyn)")
    parser.add_argument("sol_file", help="Path to a .sol file")
    parser.add_argument("--all", action="store_true",
                        help="Show every finding, not just actionable ones")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    args = parser.parse_args()

    result = analyze_solidity(Path(args.sol_file).read_text(encoding="utf-8"))
    if args.json:
        print(json.dumps(summarize(result), indent=2))
        return

    if not result.available:
        print(f"unavailable: {result.tool_error}")
        raise SystemExit(2)
    if result.tool_error:
        print(f"{result.tool}: {result.tool_error}")
        raise SystemExit(2)

    findings = result.findings if args.all else actionable_findings(result)
    print(f"{result.tool}: {len(result.findings)} finding(s), "
          f"{len(actionable_findings(result))} actionable")
    print(format_findings(findings, limit=100))
    raise SystemExit(1 if actionable_findings(result) else 0)


if __name__ == "__main__":
    _cli()
