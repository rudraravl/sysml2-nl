#!/usr/bin/env python3
"""
Batch generation script for NL-Solidity pairs from sol_seed.jsonl.

Retargeted from nl2sysml/batch_generate.py. Same parallel claim/resume/stats
framework; the target artifact is a Solidity `.sol` file instead of `.sysml`.

By default, generation prompts come from the richer NL text in
nl2solidity/dataset/data/XXXXXX/XXXXXX.txt (linked via meta.json source_path
sol_seed.jsonl:U###). Seed IDs and output folders stay U### for resume
compatibility. Use --prompt-source seed to fall back to short seeds.

Saves under nl2solidity/dataset/with_kernel_spec/ with the same structure as
nl2solidity/dataset/data/.

Features:
- Parallel generation across seeds (--workers), with per-entry atomic claims so
  concurrent workers (and concurrent batch processes) never regenerate the same
  sample
- Progress tracking and resume capability
- Error handling and logging
- Consistent output format matching dataset/data structure
"""

import io
import json
import socket
import sys
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple

# A claim left behind by a crashed run is reclaimable after this long.
CLAIM_STALE_SEC = float(os.getenv("BATCH_CLAIM_STALE_SEC", "7200"))
CLAIM_DIRNAME = ".claim"


def load_rich_nl_by_seed_id(dataset_data_dir: Path) -> Dict[str, Dict[str, Any]]:
    """Map sol_seed id (e.g. U140) -> rich NL from dataset/data/<id>/<id>.txt."""
    mapping: Dict[str, Dict[str, Any]] = {}
    if not dataset_data_dir.is_dir():
        return mapping

    for meta_path in sorted(dataset_data_dir.glob("*/meta.json")):
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        source_path = str(meta.get("source_path") or "")
        if not source_path.startswith("sol_seed.jsonl:"):
            continue
        seed_id = source_path.split(":", 1)[1].strip()
        if not seed_id:
            continue
        data_id = meta_path.parent.name
        txt_path = meta_path.parent / f"{data_id}.txt"
        if not txt_path.is_file():
            continue
        try:
            description = txt_path.read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if not description:
            continue
        mapping[seed_id] = {
            "data_id": data_id,
            "description": description,
            "source_path": f"nl2solidity/dataset/data/{data_id}/{data_id}.txt",
            "seed_source_path": source_path,
            "category": meta.get("category"),
        }
    return mapping


def resolve_entry_prompt(
    entry: Dict[str, Any],
    rich_nl: Dict[str, Dict[str, Any]],
    prompt_source: str,
    require_dataset_nl: bool,
) -> Optional[Dict[str, Any]]:
    """
    Return a working entry dict with description set for generation/output.

    Returns None when prompt_source=dataset, require_dataset_nl, and no rich NL.
    """
    entry_id = str(entry.get("id", "UNKNOWN")).strip() or "UNKNOWN"
    seed_description = str(entry.get("description") or "").strip()
    rich = rich_nl.get(entry_id)

    out = dict(entry)
    if prompt_source == "seed":
        out["description"] = seed_description
        out["nl_prompt_source"] = "sol_seed"
        out["nl_source_path"] = f"sol_seed.jsonl:{entry_id}"
        return out

    # default: dataset rich NL
    if rich:
        out["description"] = rich["description"]
        out["nl_prompt_source"] = "dataset"
        out["nl_source_path"] = rich["source_path"]
        out["dataset_data_id"] = rich["data_id"]
        if rich.get("category") and not out.get("domain"):
            out["domain"] = rich["category"]
        return out

    if require_dataset_nl:
        return None

    out["description"] = seed_description
    out["nl_prompt_source"] = "sol_seed_fallback"
    out["nl_source_path"] = f"sol_seed.jsonl:{entry_id}"
    return out


def _kernel_status() -> str:
    """Report whether the Foundry runner can actually execute in this env."""
    try:
        from nl2solidity import agent_rag_moe as moe
    except ModuleNotFoundError:
        import agent_rag_moe as moe  # type: ignore[no-redef]

    if os.getenv("KERNEL_FEEDBACK_ENABLED", "true").strip().lower() in ("0", "false", "no", "off"):
        return "DISABLED (KERNEL_FEEDBACK_ENABLED=false)"
    if not moe.KERNEL_EXECUTION_AVAILABLE:
        return "UNAVAILABLE (nl2solidity.solidity_execution did not import)"

    try:
        from nl2solidity.solidity_execution import forge_version, is_runner_available
    except ImportError as exc:
        return f"UNAVAILABLE (solidity_execution import failed: {exc})"

    if not is_runner_available():
        return ("UNAVAILABLE (forge not found or forge-std missing) "
                "— execution refine WILL BE SKIPPED")
    version = forge_version() or "forge"
    return f"available ({version}, fuzz_runs={moe.FUZZ_RUNS})"


def _security_status() -> str:
    """Report whether the static-analysis stage can run."""
    if os.getenv("SECURITY_ANALYSIS_ENABLED", "true").strip().lower() in (
            "0", "false", "no", "off"):
        return "DISABLED (SECURITY_ANALYSIS_ENABLED=false)"
    try:
        from nl2solidity.security_analysis import analyzer_version, is_analysis_available
    except ImportError as exc:
        return f"UNAVAILABLE (security_analysis import failed: {exc})"
    if not is_analysis_available():
        return ("UNAVAILABLE (pip install slither-analyzer) "
                "— security refine WILL BE SKIPPED")
    return f"available ({analyzer_version()})"


def print_preflight() -> None:
    """Print stage/model availability so a long batch is not started half-blind."""
    try:
        from nl2solidity import agent_rag_moe as moe
    except ModuleNotFoundError:
        import agent_rag_moe as moe  # type: ignore[no-redef]

    try:
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).parent.parent / ".env")
    except ImportError:
        pass

    print("-" * 70)
    print("Preflight:")
    print(f"  Python:            {sys.executable}")
    print(f"  LLM backend:       {moe._llm_backend()}")
    print(f"  Experts:           {', '.join(moe._active_expert_models())}")
    print(f"  Expert parallelism:{moe.EXPERT_PARALLELISM}")
    print(f"  API concurrency:   {os.getenv('OPENROUTER_MAX_CONCURRENCY', '8')} "
          f"(min interval {os.getenv('OPENROUTER_MIN_INTERVAL', '0')}s, "
          f"retries {os.getenv('OPENROUTER_MAX_RETRIES', '5')})")
    print(f"  Compiler/runner:   max {os.getenv('SOLC_COMPILER_MAX_CONCURRENCY', '4')} "
          f"compiles, max {os.getenv('SOLIDITY_RUNNER_MAX_CONCURRENCY', '3')} runners")
    print(f"  Combiner:          {moe._active_combiner_model()}")
    print(f"  OPENROUTER_API_KEY:{'set' if os.getenv('OPENROUTER_API_KEY') else 'MISSING'}")

    try:
        from nl2solidity.compiler_interface import compiler_version, is_compiler_available
    except ModuleNotFoundError:
        from compiler_interface import (  # type: ignore[no-redef]
            compiler_version, is_compiler_available)
    if is_compiler_available():
        version = compiler_version()
        compiler_state = f"available (solc {version})" if version else "available"
    else:
        compiler_state = "UNAVAILABLE — compiler refine WILL BE SKIPPED"
    print(f"  Compiler (solc):   {compiler_state}")
    print(f"  Execution (forge): {_kernel_status()}")
    try:
        from nl2solidity.agent_rag_moe import PROPERTY_TESTS_ENABLED
    except ModuleNotFoundError:
        PROPERTY_TESTS_ENABLED = True  # type: ignore[assignment]
    print(f"  Property tests:    {'enabled' if PROPERTY_TESTS_ENABLED else 'disabled'} (Tier B)")
    print(f"  Security analysis: {_security_status()}")

    alignment_on = os.getenv("SPEC_ALIGNMENT_ENABLED", "true").strip().lower() not in (
        "0", "false", "no", "off"
    )
    print(f"  Spec alignment:    {'enabled' if alignment_on else 'disabled'}")
    print("-" * 70)


def create_meta_json(entry: Dict[str, Any], solidity_code: str, prompt_record: Dict) -> Dict[str, Any]:
    """Create meta.json matching the dataset structure."""
    alignment_enabled = prompt_record.get("spec_alignment_enabled", False)
    quality_report = prompt_record.get("quality_report") or {}
    validation_ok = prompt_record.get("final_valid", False)
    alignment_ok = not alignment_enabled or quality_report.get("accepted", False)
    execution_stats = prompt_record.get("execution_tests") or {}
    execution_ok = not execution_stats or not execution_stats.get("contract_defects")
    security_stats = prompt_record.get("security_analysis") or {}
    security_ok = not security_stats.get("n_actionable")

    entry_id = entry.get("id", "UNKNOWN")
    source_path = entry.get("nl_source_path") or f"sol_seed.jsonl:{entry_id}"

    meta = {
        "id": entry_id,
        "source_path": source_path,
        "split": "generated",
        # A requires every wired stage to be clean: compiles, no contract-level
        # execution defect, no actionable finding, and semantically aligned.
        "quality": "A" if (validation_ok and alignment_ok and execution_ok
                           and security_ok) else "B",
        "category": entry.get("domain", "unknown"),
        "created": datetime.now().isoformat(),
        "nl_prompt_source": entry.get("nl_prompt_source", "sol_seed"),
    }
    if entry.get("dataset_data_id"):
        meta["dataset_data_id"] = entry["dataset_data_id"]
        meta["seed_id"] = entry_id

    if entry.get("provenance"):
        meta["provenance"] = entry.get("provenance")
    if entry.get("source_title"):
        meta["source_title"] = entry.get("source_title")

    if "final_valid" in prompt_record:
        meta["validation"] = {
            "is_valid": validation_ok,
            "error_count": prompt_record.get("final_errors", 0),
        }

    if prompt_record.get("execution_tests") is not None:
        meta["execution"] = {
            "tier_status": prompt_record.get("execution_tier_status", {}),
            **(prompt_record.get("execution_tests") or {}),
            "compiled": prompt_record.get("kernel_compiled"),
            "property_tests": (prompt_record.get("property_tests") or {}).get(
                "n_functions", 0),
        }
        notes = prompt_record.get("execution_harness_notes")
        if notes:
            meta["execution"]["harness_notes"] = notes

    security = prompt_record.get("security_analysis")
    if security:
        meta["security"] = {
            "tool": security.get("tool"),
            "n_findings": security.get("n_findings"),
            "n_actionable": security.get("n_actionable"),
            "by_impact": security.get("by_impact"),
            "actionable": security.get("actionable", [])[:10],
        }
    if alignment_enabled:
        attempts = quality_report.get("attempts", [])
        kept_idx = quality_report.get("kept_attempt")
        if kept_idx is None:
            kept_idx = len(attempts) - 1 if attempts else 0
        kept_summary = (
            attempts[kept_idx].get("alignment", {}).get("summary", {})
            if attempts and 0 <= kept_idx < len(attempts) else {}
        )
        initial_summary = (
            attempts[0].get("alignment", {}).get("summary", {})
            if attempts else {}
        )
        initial_similarity = initial_summary.get("similarity")
        meta["spec_alignment"] = {
            "accepted": quality_report.get("accepted", False),
            "similarity": kept_summary.get("similarity"),
            "initial_similarity": initial_similarity,
            "repairs": quality_report.get("repairs", 0),
            "repairs_kept": quality_report.get("repairs_kept", 0),
            "kept_attempt": kept_idx,
            "threshold": quality_report.get("threshold"),
            "error": quality_report.get("error"),
            "attempts": _alignment_attempt_summaries(attempts, initial_similarity),
        }

    return meta


def _alignment_attempt_summaries(
    attempts: list,
    initial_similarity: Any,
) -> list:
    """Compact per-attempt scores for meta.json (baseline + each repair)."""
    out = []
    for attempt in attempts or []:
        summary = (attempt.get("alignment") or {}).get("summary") or {}
        similarity = summary.get("similarity")
        delta = None
        if similarity is not None and initial_similarity is not None:
            delta = round(float(similarity) - float(initial_similarity), 4)
        out.append({
            "attempt": attempt.get("attempt"),
            "similarity": similarity,
            "delta_vs_initial": delta,
            "accepted": attempt.get("accepted"),
            "kept": attempt.get("kept"),
            "rejected_reason": attempt.get("rejected_reason"),
            "validation_status": attempt.get("validation_status"),
            "execution_status": attempt.get("execution_status"),
            "scored": summary.get("scored"),
            "domain_mismatch": summary.get("domain_mismatch"),
        })
    return out


def write_entry_output(
    entry_dir: Path,
    entry: Dict[str, Any],
    solidity_code: str,
    prompt_record: Dict,
) -> None:
    """Write dataset-style per-seed folder: {id}.sol, {id}.txt, meta.json."""
    entry_dir.mkdir(parents=True, exist_ok=True)
    entry_id = str(entry.get("id", "UNKNOWN")).strip() or "UNKNOWN"
    description = str(entry.get("description", "")).strip()

    (entry_dir / f"{entry_id}.sol").write_text(
        solidity_code.strip() + "\n", encoding="utf-8"
    )
    (entry_dir / f"{entry_id}.txt").write_text(description + "\n", encoding="utf-8")
    meta_data = create_meta_json(entry, solidity_code, prompt_record)
    (entry_dir / "meta.json").write_text(
        json.dumps(meta_data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


class _ThreadRoutedStdout:
    """Route each worker thread's prints into its own buffer."""

    def __init__(self, base):
        self._base = base
        self._local = threading.local()

    def set_buffer(self, buffer) -> None:
        self._local.buffer = buffer

    def clear_buffer(self) -> None:
        self._local.buffer = None

    def _target(self):
        return getattr(self._local, "buffer", None) or self._base

    def write(self, text):
        return self._target().write(text)

    def flush(self):
        try:
            self._target().flush()
        except Exception:
            pass

    def isatty(self) -> bool:
        try:
            return bool(self._base.isatty())
        except Exception:
            return False

    def __getattr__(self, name):
        return getattr(self._base, name)


def entry_is_complete(entry_dir: Path, entry_id: str) -> bool:
    """True when all three dataset-style output files exist."""
    return (
        (entry_dir / f"{entry_id}.sol").exists()
        and (entry_dir / f"{entry_id}.txt").exists()
        and (entry_dir / "meta.json").exists()
    )


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except OSError:
        return True
    return True


def _claim_is_stale(claim_dir: Path, stale_after_sec: float) -> bool:
    """A claim is stale when its owner process is gone, or it is simply old."""
    try:
        info = json.loads((claim_dir / "owner.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        info = {}

    pid = info.get("pid")
    if info.get("host") == socket.gethostname() and isinstance(pid, int) and pid > 0:
        if not _pid_alive(pid):
            return True

    try:
        return (time.time() - claim_dir.stat().st_mtime) > stale_after_sec
    except OSError:
        return True


def claim_entry(entry_dir: Path, stale_after_sec: float = CLAIM_STALE_SEC) -> bool:
    """Atomically claim an entry for this worker.

    mkdir is atomic on POSIX, so this also keeps two *separate* batch processes
    pointed at the same output dir from generating the same seed twice.
    """
    claim_dir = entry_dir / CLAIM_DIRNAME
    try:
        entry_dir.mkdir(parents=True, exist_ok=True)
        claim_dir.mkdir()
    except FileExistsError:
        if not _claim_is_stale(claim_dir, stale_after_sec):
            return False
        # Owner died or the claim aged out: take it over.
    except OSError:
        return False

    try:
        (claim_dir / "owner.json").write_text(
            json.dumps({
                "pid": os.getpid(),
                "host": socket.gethostname(),
                "started": datetime.now().isoformat(),
            }),
            encoding="utf-8",
        )
        os.utime(claim_dir, None)
    except OSError:
        pass
    return True


def release_claim(entry_dir: Path) -> None:
    claim_dir = entry_dir / CLAIM_DIRNAME
    try:
        (claim_dir / "owner.json").unlink()
    except OSError:
        pass
    try:
        claim_dir.rmdir()
    except OSError:
        pass


def _generate_one(
    idx: int,
    entry_id: str,
    working: Dict[str, Any],
    entry_dir: Path,
    generate_solidity_moe,
    total: int,
    output_dir: Path,
    stats: Dict[str, int],
    stats_lock: threading.Lock,
    log,
    stop_event: threading.Event,
    usage_limit: Dict[str, Any],
) -> str:
    """Generate + write one entry. Caller owns the claim on entry_dir."""
    description = working.get("description", "")
    domain = working.get("domain", "unknown")
    data_note = ""
    if working.get("dataset_data_id"):
        data_note = f", data={working['dataset_data_id']}"
    log(
        f"[{idx+1}/{total}] {entry_id}: Generating... "
        f"(Domain: {domain}, prompt={working.get('nl_prompt_source')}{data_note})"
    )
    log(f"  Description: {description[:80]}...")

    try:
        start_time = time.time()
        solidity_code, prompt_record = generate_solidity_moe(description)
        elapsed = time.time() - start_time

        if not solidity_code or not solidity_code.strip():
            raise RuntimeError("Generation returned empty Solidity")

        write_entry_output(entry_dir, working, solidity_code, prompt_record)
        quality_report = prompt_record.get("quality_report")
        expert_soft = int(prompt_record.get("expert_soft_fail_count") or 0)
        valid = bool(prompt_record.get("final_valid", False))

        with stats_lock:
            stats["expert_soft_fails"] += expert_soft
            stats["processed"] += 1
            if valid:
                stats["valid"] += 1
            else:
                stats["invalid"] += 1
            if prompt_record.get("spec_alignment_enabled"):
                if (quality_report or {}).get("accepted", False):
                    stats["aligned"] += 1
                else:
                    stats["misaligned"] += 1

        note = f", expert_soft_fails={expert_soft}" if expert_soft else ""
        if valid:
            log(f"  ✓ Generated (valid, {elapsed:.1f}s{note})")
        else:
            error_count = prompt_record.get("final_errors", 0)
            log(
                f"  ⚠ Generated (invalid, {error_count} errors, "
                f"{elapsed:.1f}s{note})"
            )
        return "ok"

    except Exception as e:
        import traceback
        error_log = output_dir / f"{entry_id}_error.log"
        with open(error_log, "w", encoding="utf-8") as f:
            f.write(f"Error processing {entry_id}:\n")
            f.write(f"{str(e)}\n\n")
            f.write(traceback.format_exc())

        try:
            from spec_aligner.llm import CliUsageLimitError
        except ImportError:
            CliUsageLimitError = ()  # type: ignore[misc, assignment]

        is_usage_limit = (
            isinstance(e, CliUsageLimitError) or _looks_like_cli_usage_limit(e)
        )
        if is_usage_limit:
            log(f"  ✗ Stopping batch (CLI usage limit): {e}", "ERROR")
            log(
                f"Batch stopping at {entry_id} (index {idx}) due to CLI usage limit",
                "ERROR",
            )
            usage_limit.setdefault("entry_id", entry_id)
            usage_limit.setdefault("idx", idx)
            usage_limit.setdefault("error_log", str(error_log))
            stop_event.set()
            return "usage_limit"

        with stats_lock:
            stats["errors"] += 1
        log(f"  ✗ Soft-fail entry {entry_id}: {e} (log: {error_log})", "ERROR")
        return "error"


def generate_batch(
    seed_file: Path,
    output_dir: Path,
    num_entries: int = 100,
    start_from: int = 0,
    resume: bool = True,
    dataset_data_dir: Optional[Path] = None,
    prompt_source: str = "dataset",
    require_dataset_nl: bool = False,
    workers: int = 4,
):
    """
    Generate Solidity contracts for entries in sol_seed.jsonl.

    Args:
        workers: Entries generated concurrently (each still fans out to experts)
        seed_file: Path to sol_seed.jsonl (defines order / U### ids)
        output_dir: Output directory (nl2solidity/dataset/with_kernel_spec)
        num_entries: Number of entries to process
        start_from: Index to start from (for resuming)
        resume: If True, skip entries that already exist
        dataset_data_dir: Path to dataset/data with rich XXXXXX.txt prompts
        prompt_source: "dataset" (rich NL) or "seed" (short seeds)
        require_dataset_nl: If True, skip seeds with no dataset/data NL
    """
    try:
        from nl2solidity.agent_rag_moe import generate_solidity_moe
    except ModuleNotFoundError as exc:
        if exc.name != "nl2solidity":
            raise
        from agent_rag_moe import generate_solidity_moe

    print(f"Reading entries from {seed_file}...")
    entries = []
    with open(seed_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    if not entries:
        print("Error: No entries found in sol_seed.jsonl")
        sys.exit(1)

    rich_nl: Dict[str, Dict[str, Any]] = {}
    if prompt_source == "dataset":
        if dataset_data_dir is None:
            print("Error: --dataset-data-dir is required when --prompt-source dataset")
            sys.exit(1)
        print(f"Loading rich NL prompts from {dataset_data_dir}...")
        rich_nl = load_rich_nl_by_seed_id(dataset_data_dir)
        print(f"Mapped {len(rich_nl)} seed ids to dataset/data/*.txt")
        if not rich_nl:
            print(
                f"Error: No rich NL prompts found under {dataset_data_dir} "
                "(expected meta.json with source_path sol_seed.jsonl:U###)"
            )
            sys.exit(1)

    entries_to_process = entries[:num_entries]
    total = len(entries_to_process)

    print(f"Found {len(entries)} total entries")
    print(f"Processing first {total} entries")
    print(f"Prompt source: {prompt_source}")
    print(f"Output directory: {output_dir}")
    print(f"Starting from index {start_from}")
    print(f"Workers: {workers}")
    print_preflight()
    print("=" * 70)

    output_dir.mkdir(parents=True, exist_ok=True)

    stats = {
        "total": total,
        "processed": 0,
        "skipped": 0,
        "claimed_elsewhere": 0,
        "no_dataset_nl": 0,
        "errors": 0,
        "expert_soft_fails": 0,
        "valid": 0,
        "invalid": 0,
        "aligned": 0,
        "misaligned": 0,
        "rich_nl": 0,
        "seed_fallback": 0,
    }

    log_file = output_dir / "generation.log"
    log_lock = threading.Lock()
    stats_lock = threading.Lock()

    def log(message: str, level: str = "INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] [{level}] {message}"
        print(log_msg)
        with log_lock:
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(log_msg + "\n")

    log(
        f"Starting batch generation: {total} entries "
        f"(prompt_source={prompt_source}, workers={workers})"
    )

    # ---- Build the worklist ------------------------------------------------
    jobs: List[Tuple[int, str, Dict[str, Any]]] = []
    for idx, entry in enumerate(entries_to_process[start_from:], start=start_from):
        entry_id = entry.get("id", f"UNKNOWN_{idx}")
        entry_dir = output_dir / entry_id

        if resume and entry_is_complete(entry_dir, entry_id):
            log(f"[{idx+1}/{total}] {entry_id}: Already exists, skipping")
            stats["skipped"] += 1
            continue

        working = resolve_entry_prompt(
            entry, rich_nl, prompt_source, require_dataset_nl
        )
        if working is None:
            log(
                f"[{idx+1}/{total}] {entry_id}: No dataset/data NL; skipping "
                "(--require-dataset-nl)",
                level="WARN",
            )
            stats["no_dataset_nl"] += 1
            continue

        if working.get("nl_prompt_source") == "sol_seed_fallback":
            log(
                f"[{idx+1}/{total}] {entry_id}: No dataset/data NL; "
                "falling back to sol_seed description",
                level="WARN",
            )
            stats["seed_fallback"] += 1
        elif working.get("nl_prompt_source") == "dataset":
            stats["rich_nl"] += 1

        jobs.append((idx, entry_id, working))

    log(f"Worklist: {len(jobs)} entries to generate with {workers} worker(s)")

    # ---- Parallel execution -------------------------------------------------
    stop_event = threading.Event()
    usage_limit: Dict[str, Any] = {}
    real_stdout = sys.stdout
    routed_stdout = _ThreadRoutedStdout(real_stdout) if workers > 1 else None

    def console(message: str) -> None:
        with log_lock:
            print(message, file=real_stdout, flush=True)

    def process_job(job: Tuple[int, str, Dict[str, Any]]) -> str:
        idx, entry_id, working = job
        if stop_event.is_set():
            return "aborted"

        entry_dir = output_dir / entry_id
        if resume and entry_is_complete(entry_dir, entry_id):
            with stats_lock:
                stats["skipped"] += 1
            return "skipped"

        if not claim_entry(entry_dir):
            log(
                f"[{idx+1}/{total}] {entry_id}: In progress elsewhere, skipping",
                "WARN",
            )
            with stats_lock:
                stats["claimed_elsewhere"] += 1
            return "claimed"

        buffer = io.StringIO()
        if routed_stdout is not None:
            routed_stdout.set_buffer(buffer)
            console(f"▶ [{idx+1}/{total}] {entry_id}: started")

        try:
            return _generate_one(
                idx, entry_id, working, entry_dir, generate_solidity_moe,
                total, output_dir, stats, stats_lock, log, stop_event,
                usage_limit,
            )
        finally:
            if routed_stdout is not None:
                routed_stdout.clear_buffer()
            release_claim(entry_dir)
            if not entry_is_complete(entry_dir, entry_id):
                try:
                    entry_dir.rmdir()
                except OSError:
                    pass
            if routed_stdout is not None:
                text = buffer.getvalue().rstrip()
                if text:
                    with log_lock:
                        print(
                            f"\n--- [{idx+1}/{total}] {entry_id} "
                            + "-" * 30 + f"\n{text}",
                            file=real_stdout,
                            flush=True,
                        )

    interrupted = False
    if routed_stdout is not None:
        sys.stdout = routed_stdout  # type: ignore[assignment]
    pool = ThreadPoolExecutor(max_workers=workers)
    try:
        futures = [pool.submit(process_job, job) for job in jobs]
        done = 0
        try:
            for future in futures:
                future.result()
                done += 1
                if done % 10 == 0:
                    with stats_lock:
                        snapshot = dict(stats)
                    log(
                        f"Progress: {done}/{len(jobs)} "
                        f"({snapshot['processed']} generated, {snapshot['valid']} valid, "
                        f"{snapshot['errors']} entry soft-fails, "
                        f"{snapshot['expert_soft_fails']} expert soft-fails)"
                    )
        except KeyboardInterrupt:
            interrupted = True
            stop_event.set()
            log("Interrupted by user; finishing in-flight entries", "WARNING")
            pool.shutdown(wait=True, cancel_futures=True)
    finally:
        if routed_stdout is not None:
            sys.stdout = real_stdout
        pool.shutdown(wait=True)

    if usage_limit:
        print("\n" + "=" * 70)
        print("Stopped: CLI 5-hour/weekly usage limit.")
        print("Completed entries are saved; fix the issue then resume.")
        print(f"Failed entry: {usage_limit['entry_id']} (index {usage_limit['idx']})")
        print(f"Processed: {stats['processed']}/{total}")
        print(f"Entry soft-fails: {stats['errors']}")
        print(f"Expert soft-fails: {stats['expert_soft_fails']}")
        print(f"Error log: {usage_limit['error_log']}")
        print("Resume by re-running the same command (completed entries are skipped).")
        print("=" * 70)
        sys.exit(2)

    if interrupted:
        print("\n" + "=" * 70)
        print("Generation interrupted. Progress saved.")
        print(f"Processed: {stats['processed']}/{total}")
        print(f"Entry soft-fails: {stats['errors']}")
        print(f"Expert soft-fails: {stats['expert_soft_fails']}")
        print("Resume by re-running the same command (completed entries are skipped).")
        sys.exit(0)

    # Final summary
    print("\n" + "=" * 70)
    print("Batch Generation Complete")
    print("=" * 70)
    print(f"Total entries: {total}")
    print(f"Processed: {stats['processed']}")
    print(f"Skipped (already existed): {stats['skipped']}")
    print(f"Skipped (claimed elsewhere): {stats['claimed_elsewhere']}")
    print(f"Skipped (no dataset NL): {stats['no_dataset_nl']}")
    print(f"Rich NL prompts (dataset/data): {stats['rich_nl']}")
    print(f"Seed NL fallbacks: {stats['seed_fallback']}")
    print(f"Entry soft-fails: {stats['errors']}")
    print(f"Expert soft-fails: {stats['expert_soft_fails']}")
    print(f"Valid outputs: {stats['valid']}")
    print(f"Invalid outputs: {stats['invalid']}")
    print(f"Spec-aligned outputs: {stats['aligned']}")
    print(f"Spec-misaligned outputs: {stats['misaligned']}")
    print(f"Output directory: {output_dir}")
    print(f"Log file: {log_file}")
    print("=" * 70)

    log(
        f"Batch generation complete: {stats['processed']} processed, "
        f"{stats['valid']} valid, {stats['errors']} entry soft-fails, "
        f"{stats['expert_soft_fails']} expert soft-fails, "
        f"rich_nl={stats['rich_nl']}, seed_fallback={stats['seed_fallback']}"
    )


def _looks_like_cli_usage_limit(exc: BaseException) -> bool:
    """Fallback detector if CliUsageLimitError could not be imported."""
    try:
        from spec_aligner.llm import is_cli_usage_limit_message
    except ImportError:
        return False
    return is_cli_usage_limit_message(str(exc))


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description=(
            "Batch generate NL-Solidity pairs. Prompts default to rich NL from "
            "nl2solidity/dataset/data/XXXXXX/XXXXXX.txt (seed order from sol_seed.jsonl)."
        )
    )
    parser.add_argument(
        "--num-entries",
        type=int,
        default=1574,
        help="Number of entries to process (default: 1574)"
    )
    parser.add_argument(
        "--start-from",
        type=int,
        default=0,
        help="Index to start from (for resuming, default: 0)"
    )
    parser.add_argument(
        "--no-resume",
        action="store_true",
        help="Don't skip existing entries (overwrite)"
    )
    parser.add_argument(
        "--seed-file",
        type=str,
        default=None,
        help="Path to sol_seed.jsonl (default: nl2solidity/sol_seed.jsonl)"
    )
    parser.add_argument(
        "--dataset-data-dir",
        type=str,
        default=None,
        help="Path to dataset/data with rich XXXXXX.txt prompts (default: nl2solidity/dataset/data)",
    )
    parser.add_argument(
        "--prompt-source",
        choices=("dataset", "seed"),
        default="dataset",
        help=(
            "NL prompt source: dataset = nl2solidity/dataset/data/*.txt (default); "
            "seed = short sol_seed.jsonl descriptions"
        ),
    )
    parser.add_argument(
        "--require-dataset-nl",
        action="store_true",
        help="Skip seeds with no matching dataset/data/*.txt (no seed fallback)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Output directory (default: nl2solidity/dataset/with_kernel_spec)"
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=int(os.getenv("BATCH_WORKERS", "4")),
        help=(
            "Entries generated concurrently (default: 4, env BATCH_WORKERS). "
            "Each entry still queries its experts in parallel, so total in-flight "
            "OpenRouter calls are bounded by --max-api-concurrency"
        ),
    )
    parser.add_argument(
        "--max-api-concurrency",
        type=int,
        default=None,
        help=(
            "Global cap on concurrent OpenRouter requests across all workers "
            "(default: 8, env OPENROUTER_MAX_CONCURRENCY)"
        ),
    )
    parser.add_argument(
        "--min-api-interval",
        type=float,
        default=None,
        help=(
            "Minimum seconds between OpenRouter requests, for strict per-minute "
            "rate limits (default: 0 = off, env OPENROUTER_MIN_INTERVAL)"
        ),
    )
    parser.add_argument(
        "--no-spec-alignment",
        action="store_true",
        help="Disable the post-generation spec mismatch gate",
    )
    parser.add_argument(
        "--no-kernel-feedback",
        action="store_true",
        help="Disable Solidity execution refine after compiler checks",
    )
    parser.add_argument(
        "--layer2-quality",
        action="store_true",
        help="Deprecated alias: enable execution feedback (same as default)",
    )
    parser.add_argument(
        "--llm-backend",
        choices=("api", "cli", "codex"),
        default=None,
        help="Model transport: api (default; OpenRouter HTTP) or cli (Claude Code / Codex)",
    )

    args = parser.parse_args()
    if args.workers < 1:
        print("Error: --workers must be >= 1")
        sys.exit(1)
    if args.max_api_concurrency is not None:
        os.environ["OPENROUTER_MAX_CONCURRENCY"] = str(max(1, args.max_api_concurrency))
    if args.min_api_interval is not None:
        os.environ["OPENROUTER_MIN_INTERVAL"] = str(max(0.0, args.min_api_interval))
    if args.no_spec_alignment:
        os.environ["SPEC_ALIGNMENT_ENABLED"] = "false"
    if args.no_kernel_feedback:
        os.environ["KERNEL_FEEDBACK_ENABLED"] = "false"
    if args.layer2_quality:
        os.environ["KERNEL_FEEDBACK_ENABLED"] = "true"
    if args.llm_backend:
        os.environ["LLM_BACKEND"] = args.llm_backend

    base = Path(__file__).parent
    repo_root = base.parent
    if args.seed_file:
        seed_file = Path(args.seed_file)
    else:
        seed_file = base / "sol_seed.jsonl"

    if args.dataset_data_dir:
        dataset_data_dir = Path(args.dataset_data_dir)
    else:
        dataset_data_dir = base / "dataset" / "data"

    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = base / "dataset" / "with_kernel_spec"

    if not seed_file.exists():
        print(f"Error: Seed file not found: {seed_file}")
        sys.exit(1)
    if args.prompt_source == "dataset" and not dataset_data_dir.is_dir():
        print(f"Error: Dataset data dir not found: {dataset_data_dir}")
        sys.exit(1)

    generate_batch(
        seed_file=seed_file,
        output_dir=output_dir,
        num_entries=args.num_entries,
        start_from=args.start_from,
        resume=not args.no_resume,
        dataset_data_dir=dataset_data_dir,
        prompt_source=args.prompt_source,
        require_dataset_nl=args.require_dataset_nl,
        workers=args.workers,
    )


if __name__ == "__main__":
    main()
