"""
Simple compiler interface for Solidity syntax and semantic checking.

This module provides a simple interface that can be easily swapped out
without modifying the core generation loop in agent_rag_moe.py. The public
surface (CompilerError, CompilerResult, check_code, is_compiler_available)
matches nl2sysml/compiler_interface.py exactly, so the generation engine is
language-agnostic.

============================== DANGLING STUB ==============================
The real implementation should shell out to `solc` (or forge build) and parse
its JSON diagnostics into CompilerError objects. Until that is wired up,
is_compiler_available() returns False and check_code() reports the compiler as
unavailable, which makes the compiler-refine loop in agent_rag_moe.py no-op
cleanly (same behavior as running nl2sysml with no SysML JAR present).

To implement:
  1. Locate solc (env SOLC_BIN or PATH), pick an EVM/pragma version.
  2. Run: solc --standard-json  (feed {language:"Solidity", sources:{...},
     settings:{outputSelection:{}}}) OR `forge build --json`.
  3. Map each diagnostic to CompilerError(severity, line, column, message,
     code, file). Set is_valid = (no severity=="error").
  4. Flip is_compiler_available() to probe `solc --version`.
Everything downstream already consumes CompilerResult, so no other file changes.
===========================================================================
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
            lines.append(f"{i}. Line {error.line}, Column {error.column}: {error.message}")
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

    DANGLING: returns None today. A real build would locate solc and construct
    a SolidityChecker wrapper analogous to nl2sysml's SysMLChecker.
    """
    global _compiler_instance

    enabled = os.getenv("SOLC_COMPILER_ENABLED", "true").lower()
    if enabled == "false":
        return None

    # ---- BEGIN dangling solc wiring -----------------------------------
    # solc_bin = os.getenv("SOLC_BIN") or shutil.which("solc")
    # if not solc_bin:
    #     return None
    # _compiler_instance = SolidityChecker(solc_bin=solc_bin,
    #                                      evm_version=os.getenv("SOLC_EVM_VERSION"))
    # return _compiler_instance
    # ---- END dangling solc wiring -------------------------------------

    return None


def is_compiler_available() -> bool:
    """Check if the compiler is available and ready to use.

    DANGLING: always False until _init_compiler wires up solc. This keeps the
    compiler-refine stage in agent_rag_moe.py disabled (it silently skips when
    no compiler is present), exactly as nl2sysml behaves without its JAR.
    """
    compiler = _get_compiler()
    if compiler is None:
        return False

    # Smoke-test the wired compiler once it exists.
    try:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sol', delete=False) as f:
            f.write("// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\ncontract T {}")
            test_file = f.name
        try:
            compiler.check_file(test_file, syntax_only=False)
            return True
        except Exception:
            return False
        finally:
            try:
                os.unlink(test_file)
            except Exception:
                pass
    except Exception:
        return False


def check_code(code: str, syntax_only: bool = False) -> CompilerResult:
    """
    Check Solidity code for errors.

    Args:
        code: The Solidity source to check
        syntax_only: If True, only parse (no type/semantic checks)

    Returns:
        CompilerResult with errors and validation status

    DANGLING: with no compiler wired, returns is_valid=False and a single
    "Compiler not available" error. The generation loop treats an unavailable
    compiler as "skip refine", so this does not block generation.
    """
    compiler = _get_compiler()

    if compiler is None:
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, "Compiler not available")],
            is_valid=False
        )

    # Write code to temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sol', delete=False, encoding='utf-8') as f:
        f.write(code)
        temp_file = f.name

    try:
        # Check the file (bounded: one solc process per in-flight check)
        with _compiler_gate():
            solc_errors = compiler.check_file(temp_file, syntax_only=syntax_only)

        errors = []
        for err in solc_errors:
            errors.append(CompilerError(
                severity=err.severity,
                line=err.line,
                column=err.column,
                message=err.message,
                code=err.code,
                file=err.file
            ))

        is_valid = len(errors) == 0
        return CompilerResult(errors=errors, is_valid=is_valid)

    except Exception as exc:
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, f"Compiler error: {str(exc)}")],
            is_valid=False
        )
    finally:
        try:
            os.unlink(temp_file)
        except Exception:
            pass
