"""
Simple compiler interface for Solidity syntax and semantic checking.

This module provides a simple interface that can be easily swapped out
without modifying the core generation loop in agent_rag_moe.py. The public
surface (CompilerError, CompilerResult, check_code, is_compiler_available)
matches nl2sysml/compiler_interface.py exactly, so the generation engine is
language-agnostic.

Backed by `solc` through nl2solidity/check_solidity.py, which drives
`solc --standard-json` and returns structured diagnostics. Compilation only -
runtime execution belongs to nl2solidity/solidity_execution.

Environment knobs (all optional):
  SOLC_COMPILER_ENABLED         "false" disables the compiler entirely
  SOLC_BIN                      pin one solc binary (skips pragma selection)
  SOLC_EVM_VERSION              settings.evmVersion, e.g. "paris", "cancun"
  SOLC_DEFAULT_VERSION          version for sources with no pragma (0.8.26)
  SOLC_AUTO_INSTALL             "false" forbids downloading a missing version
  SOLC_INCLUDE_WARNINGS         "true" reports warnings as well as errors
  SOLC_CODEGEN                  "true" also runs codegen (catches stack-too-deep)
  SOLC_TIMEOUT_SEC              per-invocation timeout (default 60)
  SOLC_COMPILER_MAX_CONCURRENCY parallel solc processes (default 4)
"""

import os
import tempfile
import threading
from pathlib import Path
from typing import List, Optional

try:
    from dotenv import load_dotenv

    _env_file = Path(__file__).resolve().parents[1] / ".env"
    if _env_file.exists():
        load_dotenv(_env_file)
except Exception:
    pass


class CompilerError:
    """Represents a single compiler error/warning."""

    def __init__(self, severity: str, line: int, column: int, message: str,
                 code: Optional[str] = None, file: Optional[str] = None):
        self.severity = severity
        self.line = line
        self.column = column
        self.message = message
        self.code = code
        self.file = file

    def is_syntax_error(self) -> bool:
        """Returns True if this is a syntax error."""
        # solc parser errors carry type "ParserError"/"DeclarationError" etc.
        return bool(self.code and ("Parser" in self.code or "Syntax" in self.code))

    def is_semantic_error(self) -> bool:
        """Returns True if this is a semantic (type/decl) error."""
        return bool(self.code and ("TypeError" in self.code or "Declaration" in self.code))

    def __str__(self) -> str:
        location = f"{self.file or 'unknown'}:{self.line}:{self.column}"
        return f"[{self.severity.upper()}] {location}: {self.message}"


class CompilerResult:
    """Result of a compiler check operation."""

    def __init__(self, errors: List[CompilerError], is_valid: bool):
        self.errors = errors
        self.is_valid = is_valid

    @property
    def error_count(self) -> int:
        """Returns the total number of errors."""
        return len(self.errors)

    def format_errors(self) -> str:
        """Formats errors as a human-readable string for feedback."""
        if not self.errors:
            return "No errors found."

        lines = [f"Found {len(self.errors)} error(s):"]
        for i, error in enumerate(self.errors, 1):
            kind = f"{error.code}: " if error.code else ""
            lines.append(
                f"{i}. Line {error.line}, Column {error.column}: {kind}{error.message}")
        return "\n".join(lines)


# Global compiler instance (lazy-loaded)
_compiler_instance = None
_compiler_init_lock = threading.Lock()

# Each check_code call spawns a solc process, so parallel batch workers must not
# launch an unbounded number of them at once.
_compiler_slots: Optional[threading.BoundedSemaphore] = None
_compiler_slots_lock = threading.Lock()


def _compiler_gate() -> threading.BoundedSemaphore:
    global _compiler_slots
    with _compiler_slots_lock:
        if _compiler_slots is None:
            cap = max(1, int(os.getenv("SOLC_COMPILER_MAX_CONCURRENCY", "4")))
            _compiler_slots = threading.BoundedSemaphore(cap)
        return _compiler_slots


_compiler_init_done = False
_compiler_probe_ok: Optional[bool] = None


def _get_compiler():
    """Get or initialize the compiler instance (thread-safe, init once)."""
    global _compiler_init_done

    if _compiler_instance is not None:
        return _compiler_instance
    if _compiler_init_done:
        return None

    with _compiler_init_lock:
        if _compiler_instance is not None:
            return _compiler_instance
        if _compiler_init_done:
            return None
        try:
            return _init_compiler()
        finally:
            _compiler_init_done = True


def _init_compiler():
    """Build the checker instance. Callers must hold _compiler_init_lock.

    Returns None (compiler unavailable) when solc is disabled or cannot be
    located, which makes the compiler-refine loop in agent_rag_moe.py skip
    cleanly - the same behavior as nl2sysml with no SysML JAR present.
    """
    global _compiler_instance

    enabled = os.getenv("SOLC_COMPILER_ENABLED", "true").lower()
    if enabled == "false":
        return None

    try:
        import sys
        repo_root = Path(__file__).resolve().parents[1]
        if str(repo_root) not in sys.path:
            sys.path.insert(0, str(repo_root))

        try:
            from nl2solidity.check_solidity import SolidityChecker
        except ImportError:
            from check_solidity import SolidityChecker  # type: ignore

        _compiler_instance = SolidityChecker(
            solc_binary=os.getenv("SOLC_BIN"),
            evm_version=os.getenv("SOLC_EVM_VERSION"),
            default_version=os.getenv("SOLC_DEFAULT_VERSION", "0.8.26"),
            auto_install=os.getenv("SOLC_AUTO_INSTALL", "true").lower() != "false",
            include_warnings=os.getenv("SOLC_INCLUDE_WARNINGS", "false").lower() == "true",
            codegen=os.getenv("SOLC_CODEGEN", "false").lower() == "true",
            timeout=float(os.getenv("SOLC_TIMEOUT_SEC", "60")),
        )
        return _compiler_instance

    except Exception as exc:
        # No solc binary, no py-solc-x, or a broken install: stay unavailable,
        # but say so once rather than failing silently forever.
        if os.getenv("SOLC_DEBUG", "false").lower() == "true":
            print(f"[nl2solidity] solc unavailable: {exc}", flush=True)
        return None


def is_compiler_available() -> bool:
    """Check if the compiler is available and ready to use."""
    compiler = _get_compiler()
    if compiler is None:
        return False

    global _compiler_probe_ok
    if _compiler_probe_ok is not None:
        return _compiler_probe_ok

    with _compiler_init_lock:
        if _compiler_probe_ok is not None:
            return _compiler_probe_ok
        # Smoke-test once: a trivial contract must come back with no errors.
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.sol', delete=False,
                                             encoding='utf-8') as f:
                f.write("// SPDX-License-Identifier: MIT\n"
                        "pragma solidity ^0.8.0;\n"
                        "contract T {}\n")
                test_file = f.name
            try:
                with _compiler_gate():
                    errors = compiler.check_file(test_file, syntax_only=False)
                _compiler_probe_ok = not any(
                    getattr(e, "severity", "error") == "error" for e in errors)
            except Exception:
                _compiler_probe_ok = False
            finally:
                try:
                    os.unlink(test_file)
                except Exception:
                    pass
        except Exception:
            _compiler_probe_ok = False
        return _compiler_probe_ok


def compiler_version() -> Optional[str]:
    """Version string of the solc in use, or None when unavailable."""
    compiler = _get_compiler()
    if compiler is None:
        return None
    try:
        return compiler.version()
    except Exception:
        return None


def check_code(code: str, syntax_only: bool = False) -> CompilerResult:
    """
    Check Solidity code for errors.

    Args:
        code: The Solidity source to check
        syntax_only: If True, only parse (no type/semantic checks)

    Returns:
        CompilerResult with errors and validation status. is_valid is True when
        no diagnostic has severity "error"; warnings (only present when
        SOLC_INCLUDE_WARNINGS=true) never invalidate a candidate.

    When no compiler is wired, returns is_valid=False with a single
    "Compiler not available" error. The generation loop treats an unavailable
    compiler as "skip refine", so this does not block generation.
    """
    compiler = _get_compiler()

    if compiler is None:
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, "Compiler not available")],
            is_valid=False
        )

    temp_file = None
    try:
        # Bounded: one solc process per in-flight check.
        check_source = getattr(compiler, "check_source", None)
        if check_source is not None:
            # Preferred path: solc reads the source over stdin, so diagnostics
            # are anchored to "Candidate.sol" instead of a random temp name.
            with _compiler_gate():
                solc_errors = check_source(code, syntax_only=syntax_only)
        else:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.sol', delete=False,
                                             encoding='utf-8') as f:
                f.write(code)
                temp_file = f.name
            with _compiler_gate():
                solc_errors = compiler.check_file(temp_file, syntax_only=syntax_only)

        errors = []
        for err in solc_errors:
            # solc messages are frequently location-only ("Undeclared
            # identifier."); fold in the offending source line so the refine
            # prompt says which code is wrong, not just where.
            message = err.message
            snippet = getattr(err, "snippet", None)
            if snippet and snippet not in message:
                message = f"{message} (near: {snippet})"
            errors.append(CompilerError(
                severity=err.severity,
                line=err.line,
                column=err.column,
                message=message,
                code=err.code,
                file=err.file
            ))

        is_valid = not any(e.severity == "error" for e in errors)
        return CompilerResult(errors=errors, is_valid=is_valid)

    except Exception as exc:
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, f"Compiler error: {str(exc)}")],
            is_valid=False
        )
    finally:
        if temp_file:
            try:
                os.unlink(temp_file)
            except Exception:
                pass
