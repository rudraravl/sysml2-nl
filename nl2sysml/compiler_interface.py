"""
Simple compiler interface for SysML v2 syntax and semantic checking.

This module provides a simple interface that can be easily swapped out
without modifying the core generation loop in agent_rag_moe.py.
"""

import os
import tempfile
from pathlib import Path
from typing import List, Optional


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
        return self.code and 'Syntax' in self.code
    
    def is_semantic_error(self) -> bool:
        """Returns True if this is a semantic error."""
        return self.code and 'Linking' in self.code
    
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


def _get_compiler():
    """Get or initialize the compiler instance."""
    global _compiler_instance
    
    if _compiler_instance is not None:
        return _compiler_instance
    
    # Check if compiler is enabled
    enabled = os.getenv("SYSML_COMPILER_ENABLED", "true").lower()
    if enabled == "false":
        return None
    
    try:
        # Import the checker from sysml2-compiler
        import sys
        compiler_path = Path(__file__).parent.parent / "sysml2-compiler"
        if compiler_path.exists():
            sys.path.insert(0, str(compiler_path))
        
        from check_sysml import SysMLChecker
        
        # Try to find JAR if not provided
        jar_path = os.getenv("SYSML_COMPILER_JAR_PATH")
        if jar_path is None:
            project_root = Path(__file__).parent.parent
            possible_jars = [
                project_root / "sysml2-compiler" / "sysml-parser-cli" / "target" / "sysml-parser-cli-1.0.0-shaded.jar",
                project_root / "sysml2-compiler" / "target" / "sysml-parser-cli-1.0.0-shaded.jar",
            ]
            for jar in possible_jars:
                if jar.exists():
                    jar_path = str(jar)
                    break
        
        # Get configuration
        load_library = os.getenv("SYSML_COMPILER_LOAD_LIBRARY", "true").lower() == "true"
        library_path = os.getenv("SYSML_COMPILER_LIBRARY_PATH")
        
        # Initialize checker
        if jar_path and os.path.exists(jar_path):
            _compiler_instance = SysMLChecker(
                jar_path=jar_path,
                load_library=load_library,
                library_path=library_path
            )
        else:
            # Try auto-detection
            try:
                _compiler_instance = SysMLChecker(
                    load_library=load_library,
                    library_path=library_path
                )
            except FileNotFoundError:
                _compiler_instance = None
        
        return _compiler_instance
        
    except ImportError:
        return None
    except Exception:
        return None


def is_compiler_available() -> bool:
    """Check if the compiler is available and ready to use."""
    compiler = _get_compiler()
    if compiler is None:
        return False
    
    # Test with a simple check
    try:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sysml', delete=False) as f:
            f.write("package Test {}")
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
    Check SysML code for errors.
    
    Args:
        code: The SysML v2 code to check
        syntax_only: If True, only check for syntax errors (default: False, checks both syntax and semantic)
    
    Returns:
        CompilerResult with errors and validation status
    """
    compiler = _get_compiler()
    
    if compiler is None:
        # Compiler not available, return invalid result
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, "Compiler not available")],
            is_valid=False
        )
    
    # Write code to temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sysml', delete=False, encoding='utf-8') as f:
        f.write(code)
        temp_file = f.name
    
    try:
        # Check the file
        sysml_errors = compiler.check_file(temp_file, syntax_only=syntax_only)
        
        # Convert to our CompilerError format
        errors = []
        for err in sysml_errors:
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
        # Return error result
        return CompilerResult(
            errors=[CompilerError("error", 0, 0, f"Compiler error: {str(exc)}")],
            is_valid=False
        )
    finally:
        # Clean up temp file
        try:
            os.unlink(temp_file)
        except Exception:
            pass
