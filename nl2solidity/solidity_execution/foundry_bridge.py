"""Headless Foundry execution: build a throwaway project and run `forge test`.

The Solidity analog of nl2sysml/sysml_execution/sysml_runtime_bridge.py. Where
that module talks to a Jupyter SysML kernel over ZeroMQ, this one materializes a
temporary Foundry project and shells out to `forge`:

    <tmp>/foundry.toml          fuzz/invariant settings, forge-std remapping
    <tmp>/src/Candidate.sol     the candidate contract
    <tmp>/test/*.t.sol          generated Tier A / Tier B harnesses

`forge build --json` runs first so compile errors are reported structurally and
attributed to the candidate or the harness; `forge test --json` then runs the
tests. Raw execution traces are discarded by default - a single Foundry trace
embeds full contract bytecode and would dwarf every other field in meta.json.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

from .models import HarnessExecutionOutput, HarnessFile, TestOutcome

FORGE_STD_REPO = "https://github.com/foundry-rs/forge-std.git"
CANDIDATE_FILENAME = "Candidate.sol"

# Solidity Panic codes: compiler-inserted invariant violations, i.e. real bugs.
PANIC_CLASSES = {
    1: "panic_assert",
    17: "panic_arithmetic",
    18: "panic_division_by_zero",
    33: "panic_enum_conversion",
    34: "panic_storage_encoding",
    49: "panic_pop_empty_array",
    50: "panic_array_out_of_bounds",
    65: "panic_memory_overflow",
    81: "panic_uninitialized_function",
}

_runner_slots: Optional[threading.BoundedSemaphore] = None
_runner_slots_lock = threading.Lock()
_forge_std_lock = threading.Lock()


def _runner_gate() -> threading.BoundedSemaphore:
    """Bound concurrent forge processes; each one is CPU-hungry."""
    global _runner_slots
    with _runner_slots_lock:
        if _runner_slots is None:
            cap = max(1, int(os.getenv("SOLIDITY_RUNNER_MAX_CONCURRENCY", "3")))
            _runner_slots = threading.BoundedSemaphore(cap)
        return _runner_slots


def forge_binary() -> Optional[str]:
    """Locate the forge executable."""
    explicit = os.getenv("FORGE_BIN")
    if explicit:
        return explicit if Path(explicit).exists() else None
    return shutil.which("forge")


def is_runner_available() -> bool:
    """True when forge and forge-std are both usable."""
    if os.getenv("SOLIDITY_RUNNER_ENABLED", "true").lower() == "false":
        return False
    if forge_binary() is None:
        return False
    try:
        return ensure_forge_std() is not None
    except Exception:
        return False


def forge_version() -> Optional[str]:
    binary = forge_binary()
    if binary is None:
        return None
    try:
        proc = subprocess.run([binary, "--version"], capture_output=True,
                              text=True, timeout=30)
    except Exception:
        return None
    first = (proc.stdout or "").strip().splitlines()
    return first[0] if first else None


def ensure_forge_std() -> Optional[Path]:
    """Path to a forge-std checkout, cloned once and shared by every candidate.

    Cloning per candidate would put a git fetch in the inner generation loop, so
    the checkout is cached under FORGE_STD_PATH (default ~/.cache/nl2solidity).
    """
    explicit = os.getenv("FORGE_STD_PATH")
    if explicit:
        path = Path(explicit)
        return path if (path / "src" / "Test.sol").exists() else None

    cache_root = Path(os.getenv("NL2SOLIDITY_CACHE",
                                Path.home() / ".cache" / "nl2solidity"))
    target = cache_root / "forge-std"
    if (target / "src" / "Test.sol").exists():
        return target

    if os.getenv("FORGE_STD_AUTO_CLONE", "true").lower() == "false":
        return None

    with _forge_std_lock:
        if (target / "src" / "Test.sol").exists():
            return target
        cache_root.mkdir(parents=True, exist_ok=True)
        try:
            subprocess.run(
                ["git", "clone", "--depth", "1", "--quiet", FORGE_STD_REPO, str(target)],
                capture_output=True, text=True, timeout=300, check=True,
            )
        except Exception:
            if target.exists():
                shutil.rmtree(target, ignore_errors=True)
            return None
    return target if (target / "src" / "Test.sol").exists() else None


def _foundry_toml(forge_std: Path, *, fuzz_runs: int, invariant_runs: int,
                  invariant_depth: int, evm_version: Optional[str]) -> str:
    lines = [
        "[profile.default]",
        "src = 'src'",
        "test = 'test'",
        "out = 'out'",
        "libs = []",
        f"remappings = ['forge-std/={forge_std.as_posix()}/src/']",
        # Generated contracts are checked, not shipped: skip optimization so
        # builds stay fast and error messages stay close to the source.
        "optimizer = false",
    ]
    if evm_version:
        lines.append(f"evm_version = '{evm_version}'")
    lines += [
        "",
        "[fuzz]",
        f"runs = {fuzz_runs}",
        "",
        "[invariant]",
        f"runs = {invariant_runs}",
        f"depth = {invariant_depth}",
        "",
    ]
    return "\n".join(lines)


def _write_project(root: Path, candidate: str, harness_files: List[HarnessFile],
                   forge_std: Path, *, fuzz_runs: int, invariant_runs: int,
                   invariant_depth: int, evm_version: Optional[str]) -> None:
    (root / "src").mkdir(parents=True, exist_ok=True)
    (root / "test").mkdir(parents=True, exist_ok=True)
    (root / CANDIDATE_FILENAME).parent.mkdir(parents=True, exist_ok=True)
    (root / "src" / CANDIDATE_FILENAME).write_text(candidate, encoding="utf-8")
    for harness in harness_files:
        (root / "test" / harness.name).write_text(harness.source, encoding="utf-8")
    (root / "foundry.toml").write_text(
        _foundry_toml(forge_std, fuzz_runs=fuzz_runs, invariant_runs=invariant_runs,
                      invariant_depth=invariant_depth, evm_version=evm_version),
        encoding="utf-8")


def _run_forge(binary: str, args: List[str], cwd: Path,
               timeout: float) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    # Keep forge from reading a user-level config that could change remappings.
    env.setdefault("FOUNDRY_PROFILE", "default")
    return subprocess.run([binary, *args], cwd=str(cwd), capture_output=True,
                          text=True, timeout=timeout, env=env)


def _parse_build_errors(stdout: str, stderr: str) -> List[Dict[str, Any]]:
    """Structured solc diagnostics from `forge build --json`."""
    try:
        payload = json.loads(stdout)
    except Exception:
        message = (stderr or stdout or "").strip()
        return ([{"severity": "error", "message": message, "type": "BuildFailure"}]
                if message else [])

    errors = []
    for entry in payload.get("errors", []) or []:
        if entry.get("severity") != "error":
            continue
        location = entry.get("sourceLocation") or {}
        errors.append({
            "severity": "error",
            "type": entry.get("type"),
            "message": entry.get("message", ""),
            "file": location.get("file"),
            "formatted": entry.get("formattedMessage"),
            "line": _line_from_formatted(entry.get("formattedMessage", "")),
            "column": _column_from_formatted(entry.get("formattedMessage", "")),
        })
    return errors


def _line_from_formatted(formatted: str) -> Optional[int]:
    location = _location_from_formatted(formatted)
    return location[0] if location else None


def _column_from_formatted(formatted: str) -> Optional[int]:
    location = _location_from_formatted(formatted)
    return location[1] if location else None


def _location_from_formatted(formatted: str):
    import re
    match = re.search(r"-->\s+\S+:(\d+):(\d+)", formatted or "")
    return (int(match.group(1)), int(match.group(2))) if match else None


def _classify_failure(reason: Optional[str], status: str) -> Optional[str]:
    """Map a failure reason onto an actionable class for the repair loop."""
    if status != "Failure":
        return None
    text = (reason or "").strip()
    lowered = text.lower()

    import re
    panic = re.search(r"panic\((\d+)\)", lowered)
    if panic:
        return PANIC_CLASSES.get(int(panic.group(1)), "panic_other")
    if "setup failed" in lowered or lowered.startswith("setup"):
        return "setup_failed"
    if "next call did not revert" in lowered or "call did not revert" in lowered:
        return "expected_revert_not_raised"
    if "out of gas" in lowered or "outofgas" in lowered:
        return "out_of_gas"
    if "assertion failed" in lowered or lowered.startswith("assert"):
        return "assertion_failed"
    if "revert" in lowered:
        return "unexpected_revert"
    return "test_failed"


def _tier_for_contract(contract_name: str, harness_files: List[HarnessFile]) -> str:
    lowered = contract_name.lower()
    if "props" in lowered or "property" in lowered or "invariant" in lowered:
        return "properties"
    if "fuzz" in lowered:
        return "fuzz"
    return harness_files[0].tier if harness_files else "fuzz"


def _counterexample_text(counterexample: Any) -> Optional[str]:
    """Flatten Foundry's counterexample structure to a readable argument list."""
    if not isinstance(counterexample, dict):
        return None
    single = counterexample.get("Single")
    if isinstance(single, dict):
        args = single.get("args") or single.get("raw_args")
        calldata = single.get("calldata")
        if args:
            return f"args={args}"
        return f"calldata={calldata}" if calldata else None

    sequence = counterexample.get("Sequence")
    if isinstance(sequence, list):
        steps = []
        for call in sequence[:8]:
            if not isinstance(call, dict):
                continue
            name = call.get("func_name") or call.get("signature") or "call"
            args = call.get("args") or call.get("raw_args") or ""
            steps.append(f"{name}({args})")
        return " -> ".join(steps) if steps else None
    return None


def _parse_test_results(stdout: str, harness_files: List[HarnessFile]) -> List[TestOutcome]:
    try:
        payload = json.loads(stdout)
    except Exception:
        return []

    outcomes: List[TestOutcome] = []
    for suite_key, suite in (payload or {}).items():
        if not isinstance(suite, dict):
            continue
        contract_name = suite_key.split(":")[-1]
        tier = _tier_for_contract(contract_name, harness_files)

        for test_name, result in (suite.get("test_results") or {}).items():
            if not isinstance(result, dict):
                continue
            kind_blob = result.get("kind") or {}
            kind = "unit"
            runs = gas = reverts = None
            if isinstance(kind_blob, dict):
                if "Fuzz" in kind_blob:
                    kind = "fuzz"
                    runs = (kind_blob["Fuzz"] or {}).get("runs")
                    gas = (kind_blob["Fuzz"] or {}).get("median_gas")
                elif "Invariant" in kind_blob:
                    kind = "invariant"
                    runs = (kind_blob["Invariant"] or {}).get("runs")
                    reverts = (kind_blob["Invariant"] or {}).get("reverts")
                elif "Unit" in kind_blob:
                    gas = (kind_blob["Unit"] or {}).get("gas")

            status = result.get("status", "Failure")
            reason = result.get("reason")
            outcomes.append(TestOutcome(
                name=test_name,
                contract=contract_name,
                tier=tier,
                status=status,
                kind=kind,
                reason=reason,
                counterexample=_counterexample_text(result.get("counterexample")),
                logs=[str(entry) for entry in (result.get("decoded_logs") or [])][:20],
                gas=gas,
                runs=runs,
                reverts=reverts,
                failure_class=_classify_failure(reason, status),
            ))
    return outcomes


def check_harness_compiles(candidate: str, harness_files: List[HarnessFile],
                           *, build_timeout_sec: float = 180.0,
                           evm_version: Optional[str] = None,
                           forge_bin: Optional[str] = None) -> List[Dict[str, Any]]:
    """Compile candidate + harness without running any test.

    Used to validate LLM-authored property tests before they cost a full fuzz
    campaign: a `forge build` is a fraction of the price of `forge test`.
    Returns the build errors ([] when everything compiles).
    """
    binary = forge_bin or forge_binary()
    forge_std = ensure_forge_std()
    if binary is None or forge_std is None or not harness_files:
        return [{"severity": "error", "message": "forge unavailable",
                 "type": "BuildFailure"}]

    root = Path(tempfile.mkdtemp(prefix="nl2solidity-forge-check-"))
    try:
        _write_project(root, candidate, harness_files, forge_std,
                       fuzz_runs=1, invariant_runs=1, invariant_depth=1,
                       evm_version=evm_version)
        with _runner_gate():
            build = _run_forge(binary, ["build", "--json"], root, build_timeout_sec)
        return _parse_build_errors(build.stdout, build.stderr)
    except subprocess.TimeoutExpired:
        return [{"severity": "error", "type": "BuildTimeout",
                 "message": f"forge build timed out after {build_timeout_sec:g}s"}]
    except Exception as exc:
        return [{"severity": "error", "type": "BuildFailure", "message": str(exc)}]
    finally:
        shutil.rmtree(root, ignore_errors=True)


def execute_solidity_candidate(
    candidate: str,
    harness_files: List[HarnessFile],
    *,
    fuzz_runs: int = 256,
    invariant_runs: int = 64,
    invariant_depth: int = 32,
    build_timeout_sec: float = 180.0,
    execution_timeout_sec: float = 120.0,
    evm_version: Optional[str] = None,
    forge_bin: Optional[str] = None,
    project_path: Optional[str] = None,
    keep_project: bool = False,
) -> HarnessExecutionOutput:
    """Build and run the candidate under Foundry; never raises."""
    binary = forge_bin or forge_binary()
    if binary is None:
        return HarnessExecutionOutput(
            kernel_available=False,
            bridge_error="forge not found (install Foundry or set FORGE_BIN)")

    forge_std = ensure_forge_std()
    if forge_std is None:
        return HarnessExecutionOutput(
            kernel_available=False,
            bridge_error="forge-std unavailable (set FORGE_STD_PATH or allow the "
                         "one-time clone into ~/.cache/nl2solidity)")

    if not harness_files:
        return HarnessExecutionOutput(
            kernel_available=True,
            bridge_error="no harness could be generated for this candidate")

    root = Path(project_path) if project_path else Path(tempfile.mkdtemp(
        prefix="nl2solidity-forge-"))
    cleanup = not keep_project and project_path is None

    try:
        _write_project(root, candidate, harness_files, forge_std,
                       fuzz_runs=fuzz_runs, invariant_runs=invariant_runs,
                       invariant_depth=invariant_depth, evm_version=evm_version)

        with _runner_gate():
            try:
                build = _run_forge(binary, ["build", "--json"], root, build_timeout_sec)
            except subprocess.TimeoutExpired:
                return HarnessExecutionOutput(
                    kernel_available=True, project_path=str(root),
                    bridge_error=f"forge build timed out after {build_timeout_sec:g}s")

            build_errors = _parse_build_errors(build.stdout, build.stderr)
            if build_errors:
                return HarnessExecutionOutput(
                    kernel_available=True,
                    compiled=False,
                    build_errors=build_errors,
                    errors=[e.get("formatted") or e.get("message", "")
                            for e in build_errors],
                    project_path=str(root),
                )

            try:
                run = _run_forge(binary, ["test", "--json"], root, execution_timeout_sec)
            except subprocess.TimeoutExpired:
                return HarnessExecutionOutput(
                    kernel_available=True, compiled=True, project_path=str(root),
                    bridge_error=f"forge test timed out after {execution_timeout_sec:g}s "
                                 f"(fuzz_runs={fuzz_runs})")

        outcomes = _parse_test_results(run.stdout, harness_files)
        if not outcomes and run.returncode != 0:
            message = (run.stderr or run.stdout or "").strip()
            return HarnessExecutionOutput(
                kernel_available=True, compiled=True, project_path=str(root),
                bridge_error=f"forge test produced no results: {message[:1000]}")

        stdout_lines = [line for line in (run.stdout or "").splitlines() if line.strip()]
        return HarnessExecutionOutput(
            stdout=stdout_lines[:5],  # JSON blob; kept only as a breadcrumb
            errors=[],
            trace=[],
            kernel_available=True,
            compiled=True,
            outcomes=outcomes,
            project_path=str(root),
        )

    except Exception as exc:
        return HarnessExecutionOutput(
            kernel_available=True, project_path=str(root),
            bridge_error=f"forge bridge error: {exc}")
    finally:
        if cleanup:
            shutil.rmtree(root, ignore_errors=True)
