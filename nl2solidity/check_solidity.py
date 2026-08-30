#!/usr/bin/env python3
"""
Solidity compilation checker - Python wrapper around the `solc` compiler.

Counterpart of sysml2-compiler/check_sysml.py: it takes a source file, runs the
compiler over it, and returns a list of structured diagnostics. Compilation only
(no deployment, no test execution) - the Foundry runtime lives in
nl2solidity/solidity_execution.

The compiler is driven through `solc --standard-json`, so diagnostics arrive as
JSON instead of being scraped from stderr.

Binary resolution order (first hit wins):
  1. $SOLC_BIN                      - an explicit binary, pinned for every check
  2. py-solc-x                      - version chosen per file from its
                                      `pragma solidity` (installed on demand
                                      unless SOLC_AUTO_INSTALL=false)
  3. `solc` on $PATH

Usage:
    from nl2solidity.check_solidity import SolidityChecker
    checker = SolidityChecker()
    errors = checker.check_file("Token.sol")          # full analysis
    errors = checker.check_file("Token.sol", syntax_only=True)   # parse only

CLI:
    python3 -m nl2solidity.check_solidity Token.sol [--syntax-only] [--json]
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import threading
from pathlib import Path
from typing import Dict, List, Optional

# Default when a file carries no usable `pragma solidity` line.
DEFAULT_SOLC_VERSION = "0.8.26"

_PRAGMA_RE = re.compile(r"pragma\s+solidity\s+([^;]+);")


class SolidityError:
    """Represents a single diagnostic from solc.

    Field names match sysml2-compiler's SysMLError so both checkers can feed the
    same CompilerError conversion in compiler_interface.check_code.
    """

    def __init__(self, data: Dict):
        self.severity: str = data.get("severity", "error")
        self.line: int = data.get("line", 0)
        self.column: int = data.get("column", 0)
        self.message: str = data.get("message", "")
        # solc's diagnostic type, e.g. ParserError / TypeError / DeclarationError.
        self.code: Optional[str] = data.get("code")
        self.file: Optional[str] = data.get("file")
        self.formatted: Optional[str] = data.get("formatted")
        # The offending source line. solc messages are often location-only
        # ("Undeclared identifier."), so the snippet is what makes a diagnostic
        # actionable when it is replayed to a model.
        self.snippet: Optional[str] = data.get("snippet")

    def is_syntax_error(self) -> bool:
        return bool(self.code and ("Parser" in self.code or "Syntax" in self.code))

    def is_semantic_error(self) -> bool:
        return bool(self.code and ("TypeError" in self.code or "Declaration" in self.code))

    def __str__(self) -> str:
        location = f"{self.file or 'unknown'}:{self.line}:{self.column}"
        prefix = f"[{self.severity.upper()}]"
        kind = f" {self.code}:" if self.code else ""
        near = f" (near: {self.snippet})" if self.snippet else ""
        return f"{prefix}{kind} {location}: {self.message}{near}"

    def __repr__(self) -> str:
        return f"SolidityError({self.severity!r}, {self.code!r}, line={self.line})"


class SolcNotFoundError(RuntimeError):
    """No usable solc binary could be located or installed."""


class SolidityChecker:
    """Compile-checks Solidity sources via `solc --standard-json`."""

    def __init__(
        self,
        solc_binary: Optional[str] = None,
        *,
        evm_version: Optional[str] = None,
        default_version: str = DEFAULT_SOLC_VERSION,
        auto_install: bool = True,
        include_warnings: bool = False,
        codegen: bool = False,
        timeout: float = 60.0,
    ):
        """
        Args:
            solc_binary: explicit binary; when set, pragma-based selection is off.
            evm_version: forwarded as settings.evmVersion (None = solc default).
            default_version: version used when a source has no usable pragma.
            auto_install: allow py-solc-x to download a missing version (network).
            include_warnings: return warning/info diagnostics alongside errors.
            codegen: also run bytecode generation, which surfaces codegen-only
                errors such as "stack too deep" at the cost of speed.
            timeout: seconds per solc invocation.
        """
        self.solc_binary = str(solc_binary) if solc_binary else None
        self.evm_version = evm_version
        self.default_version = default_version
        self.auto_install = auto_install
        self.include_warnings = include_warnings
        self.codegen = codegen
        self.timeout = timeout

        # Resolved binaries, keyed by pragma string; solc downloads/lookups are
        # done once per distinct pragma rather than once per candidate.
        self._binary_cache: Dict[str, str] = {}
        self._cache_lock = threading.Lock()

        # Fail fast at construction so is_compiler_available() reports honestly.
        self._probe_binary()

    # ---------------------------------------------------------------- binary

    def _probe_binary(self) -> str:
        """Resolve a binary with no pragma constraint; raises if none exists."""
        return self._resolve_binary(None)

    def _resolve_binary(self, pragma: Optional[str]) -> str:
        if self.solc_binary:
            return self.solc_binary

        key = pragma or ""
        with self._cache_lock:
            cached = self._binary_cache.get(key)
        if cached:
            return cached

        binary = self._locate_binary(pragma)

        with self._cache_lock:
            self._binary_cache[key] = binary
        return binary

    def _locate_binary(self, pragma: Optional[str]) -> str:
        solcx_error: Optional[str] = None
        try:
            import solcx  # type: ignore
            from solcx.install import select_pragma_version  # type: ignore

            installed = solcx.get_installed_solc_versions()
            version = None

            if pragma:
                # Honor the source's own version constraint.
                try:
                    version = select_pragma_version(pragma, installed)
                except Exception:
                    version = None
                if version is None and self.auto_install:
                    try:
                        version = solcx.install_solc_pragma(pragma, show_progress=False)
                    except Exception as exc:
                        solcx_error = f"cannot satisfy pragma '{pragma}': {exc}"
            else:
                # No pragma: prefer the configured default version.
                wanted = str(self.default_version)
                version = next((v for v in installed if str(v) == wanted), None)
                if version is None and self.auto_install:
                    try:
                        version = solcx.install_solc(wanted, show_progress=False)
                    except Exception as exc:
                        solcx_error = f"install of {wanted} failed: {exc}"

            # Last resort within solcx: whatever is already on disk.
            if version is None and installed:
                version = max(installed)

            if version is not None:
                return str(solcx.install.get_executable(version))
        except ImportError:
            solcx_error = "py-solc-x not installed"
        except Exception as exc:  # pragma: no cover - defensive
            solcx_error = str(exc)

        path_solc = shutil.which("solc")
        if path_solc:
            return path_solc

        # py-solc-x is missing from *this* interpreter, but its downloaded
        # binaries are shared across interpreters - use the newest one. Version
        # selection is skipped here; a mismatched pragma surfaces as a normal
        # solc error ("Source file requires different compiler version").
        scanned = _newest_solcx_binary()
        if scanned:
            return scanned

        raise SolcNotFoundError(
            "No solc binary available "
            f"(py-solc-x: {solcx_error or 'unavailable'}; no 'solc' on PATH). "
            "Install with: pip install py-solc-x && "
            "python3 -c \"import solcx; solcx.install_solc('%s')\"" % self.default_version
        )

    def version(self) -> Optional[str]:
        """Version of the default-resolved binary, e.g. "0.8.26" (None if absent)."""
        try:
            binary = self._resolve_binary(None)
            proc = subprocess.run([binary, "--version"], capture_output=True,
                                  text=True, timeout=self.timeout)
        except Exception:
            return None
        match = re.search(r"Version:\s*(\S+)", proc.stdout or "")
        return match.group(1) if match else None

    @staticmethod
    def _pragma_of(source: str) -> Optional[str]:
        match = _PRAGMA_RE.search(source)
        if not match:
            return None
        pragma = " ".join(match.group(1).split())
        return pragma or None

    # ---------------------------------------------------------------- checks

    def check_file(self, file_path: str, syntax_only: bool = False) -> List[SolidityError]:
        """Check one .sol file. Returns [] when it compiles cleanly."""
        path = Path(file_path)
        source = path.read_text(encoding="utf-8")
        return self.check_source(source, syntax_only=syntax_only, filename=path.name)

    def check_source(self, source: str, syntax_only: bool = False,
                     filename: str = "Candidate.sol") -> List[SolidityError]:
        """Check Solidity source text. Returns [] when it compiles cleanly."""
        binary = self._resolve_binary(self._pragma_of(source))
        payload = self._standard_json_input(source, filename, syntax_only)

        try:
            proc = subprocess.run(
                [binary, "--standard-json"],
                input=json.dumps(payload),
                capture_output=True,
                text=True,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return [SolidityError({
                "severity": "error",
                "message": f"solc timed out after {self.timeout:g}s",
                "code": "CompilerTimeout",
                "file": filename,
            })]

        if not proc.stdout.strip():
            detail = (proc.stderr or "").strip() or f"solc exited with {proc.returncode}"
            return [SolidityError({
                "severity": "error",
                "message": f"solc produced no output: {detail}",
                "code": "CompilerFailure",
                "file": filename,
            })]

        try:
            output = json.loads(proc.stdout)
        except json.JSONDecodeError as exc:
            return [SolidityError({
                "severity": "error",
                "message": f"could not parse solc output: {exc}",
                "code": "CompilerFailure",
                "file": filename,
            })]

        return self._parse_diagnostics(output, source, filename)

    def _standard_json_input(self, source: str, filename: str, syntax_only: bool) -> Dict:
        settings: Dict = {}
        if syntax_only:
            # Parse only: no name resolution, no type checking.
            settings["stopAfter"] = "parsing"
            settings["outputSelection"] = {}
        elif self.codegen:
            # Requesting bytecode forces codegen, surfacing stack-too-deep etc.
            settings["outputSelection"] = {"*": {"*": ["evm.bytecode.object"]}}
        else:
            # Analysis only (parse + resolve + typecheck): all the errors that
            # matter for "does this compile", without paying for codegen.
            settings["outputSelection"] = {}

        if self.evm_version:
            settings["evmVersion"] = self.evm_version

        return {
            "language": "Solidity",
            "sources": {filename: {"content": source}},
            "settings": settings,
        }

    def _parse_diagnostics(self, output: Dict, source: str,
                           filename: str) -> List[SolidityError]:
        errors: List[SolidityError] = []
        offsets = _LineIndex(source)

        for item in output.get("errors", []):
            severity = item.get("severity", "error")
            if severity != "error" and not self.include_warnings:
                continue

            location = item.get("sourceLocation") or {}
            start = location.get("start", -1)
            if isinstance(start, int) and start >= 0:
                line, column = offsets.locate(start)
            else:
                line, column = _location_from_formatted(item.get("formattedMessage", ""))

            errors.append(SolidityError({
                "severity": severity,
                "line": line,
                "column": column,
                "message": item.get("message", ""),
                "code": item.get("type"),
                "file": location.get("file") or filename,
                "formatted": item.get("formattedMessage"),
                "snippet": offsets.line_text(line, column),
            }))

        return errors

    def check_files(self, file_paths: List[str],
                    syntax_only: bool = False) -> Dict[str, List[SolidityError]]:
        """Check several files independently; returns {path: errors}."""
        return {p: self.check_file(p, syntax_only=syntax_only) for p in file_paths}

    def check_directory(self, directory: str, recursive: bool = True,
                        syntax_only: bool = False) -> Dict[str, List[SolidityError]]:
        """Check every .sol file under a directory."""
        root = Path(directory)
        pattern = "**/*.sol" if recursive else "*.sol"
        return self.check_files([str(p) for p in sorted(root.glob(pattern))],
                                syntax_only=syntax_only)


def _version_key(name: str) -> tuple:
    """Sort key for a 'solc-v0.8.26' style filename."""
    digits = re.findall(r"\d+", name)
    return tuple(int(d) for d in digits[:3]) if digits else (0,)


def _newest_solcx_binary() -> Optional[str]:
    """Newest binary in the py-solc-x install folder, without importing solcx."""
    folder = os.getenv("SOLCX_BINARY_PATH")
    root = Path(folder) if folder else Path.home() / ".solcx"
    if not root.is_dir():
        return None
    candidates = [p for p in root.glob("solc-v*")
                  if p.is_file() and os.access(p, os.X_OK)]
    if not candidates:
        return None
    return str(max(candidates, key=lambda p: _version_key(p.name)))


class _LineIndex:
    """Maps solc byte offsets to 1-based (line, column) positions."""

    def __init__(self, source: str):
        self._raw = source.encode("utf-8")
        self._line_starts = [0]
        for i, byte in enumerate(self._raw):
            if byte == 0x0A:  # '\n'
                self._line_starts.append(i + 1)

    def line_text(self, line: int, column: int = 1,
                  max_len: int = 160) -> Optional[str]:
        """The source text of a 1-based line, trimmed for use in feedback.

        An over-long line (minified or single-line contracts) is windowed
        around ``column`` so the excerpt still shows the offending code.
        """
        if line < 1 or line > len(self._line_starts):
            return None
        start = self._line_starts[line - 1]
        end = self._line_starts[line] if line < len(self._line_starts) else len(self._raw)
        text = self._raw[start:end].decode("utf-8", errors="replace").rstrip()
        stripped = text.lstrip()
        if not stripped:
            return None
        if len(stripped) <= max_len:
            return stripped

        # Window around the column, keeping it centered where possible.
        lead = len(text) - len(stripped)
        centre = max(0, (column - 1) - lead)
        begin = max(0, centre - max_len // 2)
        window = stripped[begin:begin + max_len]
        return ("..." if begin else "") + window + ("..." if begin + max_len < len(stripped) else "")

    def locate(self, offset: int) -> tuple[int, int]:
        offset = max(0, min(offset, len(self._raw)))
        # Rightmost line start at or before the offset.
        lo, hi = 0, len(self._line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self._line_starts[mid] <= offset:
                lo = mid
            else:
                hi = mid - 1
        start = self._line_starts[lo]
        column = len(self._raw[start:offset].decode("utf-8", errors="replace")) + 1
        return lo + 1, column


_FORMATTED_LOC_RE = re.compile(r"-->\s+[^\s:]+:(\d+):(\d+)")


def _location_from_formatted(formatted: str) -> tuple[int, int]:
    match = _FORMATTED_LOC_RE.search(formatted or "")
    if not match:
        return 0, 0
    return int(match.group(1)), int(match.group(2))


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Check Solidity files with solc.")
    parser.add_argument("files", nargs="+", help="Solidity files or directories")
    parser.add_argument("--syntax-only", action="store_true",
                        help="Parse only (skip type checking)")
    parser.add_argument("--warnings", action="store_true", help="Include warnings")
    parser.add_argument("--codegen", action="store_true",
                        help="Also run codegen (catches stack-too-deep)")
    parser.add_argument("--solc", help="Path to a specific solc binary")
    parser.add_argument("--json", action="store_true", help="Emit JSON diagnostics")
    args = parser.parse_args()

    try:
        checker = SolidityChecker(solc_binary=args.solc,
                                  include_warnings=args.warnings,
                                  codegen=args.codegen)
    except SolcNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    results: Dict[str, List[SolidityError]] = {}
    for target in args.files:
        path = Path(target)
        if path.is_dir():
            results.update(checker.check_directory(target, syntax_only=args.syntax_only))
        else:
            results[target] = checker.check_file(target, syntax_only=args.syntax_only)

    if args.json:
        print(json.dumps({
            path: [{"severity": e.severity, "line": e.line, "column": e.column,
                    "message": e.message, "code": e.code, "file": e.file}
                   for e in errs]
            for path, errs in results.items()
        }, indent=2))
    else:
        for path, errs in results.items():
            if not errs:
                print(f"OK   {path}")
                continue
            print(f"FAIL {path}: {len(errs)} diagnostic(s)")
            for err in errs:
                print(f"  {err}")

    has_error = any(e.severity == "error" for errs in results.values() for e in errs)
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
