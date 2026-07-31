#!/usr/bin/env python3
"""
Batch generation script for NL-SysML pairs from nl_seed.jsonl.

Generates SysML v2 models for the first N entries in nl_seed.jsonl,
saving them in dataset/with_kernel_spec/ with the same structure as dataset/data/.

Features:
- Progress tracking and resume capability
- Error handling and logging
- Consistent output format matching dataset/data structure
"""

import json
import sys
import os
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

def create_meta_json(entry: Dict[str, Any], sysml_code: str, prompt_record: Dict) -> Dict[str, Any]:
    """Create meta.json matching the dataset structure."""
    alignment_enabled = prompt_record.get("spec_alignment_enabled", False)
    quality_report = prompt_record.get("quality_report") or {}
    validation_ok = prompt_record.get("final_valid", False)
    alignment_ok = not alignment_enabled or quality_report.get("accepted", False)

    # Base structure matching dataset/data format
    meta = {
        "id": entry.get("id", "UNKNOWN"),
        "source_path": f"nl_seed.jsonl:{entry.get('id', 'UNKNOWN')}",
        "split": "generated",
        "quality": "A" if validation_ok and alignment_ok else "B",
        "category": entry.get("domain", "unknown"),
        "created": datetime.now().isoformat(),
    }
    
    # Add optional fields from entry
    if entry.get("provenance"):
        meta["provenance"] = entry.get("provenance")
    if entry.get("source_title"):
        meta["source_title"] = entry.get("source_title")
    
    # Add validation info if available
    if "final_valid" in prompt_record:
        meta["validation"] = {
            "is_valid": validation_ok,
            "error_count": prompt_record.get("final_errors", 0),
        }
    if alignment_enabled:
        attempts = quality_report.get("attempts", [])
        last_summary = (
            attempts[-1].get("alignment", {}).get("summary", {})
            if attempts else {}
        )
        meta["spec_alignment"] = {
            "accepted": quality_report.get("accepted", False),
            "similarity": last_summary.get("similarity"),
            "repairs": quality_report.get("repairs", 0),
            "threshold": quality_report.get("threshold"),
            "error": quality_report.get("error"),
        }
    
    return meta


def write_entry_output(
    entry_dir: Path,
    entry: Dict[str, Any],
    sysml_code: str,
    prompt_record: Dict,
) -> None:
    """Write dataset-style per-seed folder: {id}.sysml, {id}.txt, meta.json."""
    entry_dir.mkdir(parents=True, exist_ok=True)
    entry_id = str(entry.get("id", "UNKNOWN")).strip() or "UNKNOWN"
    description = str(entry.get("description", "")).strip()

    (entry_dir / f"{entry_id}.sysml").write_text(
        sysml_code.strip() + "\n", encoding="utf-8"
    )
    (entry_dir / f"{entry_id}.txt").write_text(description + "\n", encoding="utf-8")
    meta_data = create_meta_json(entry, sysml_code, prompt_record)
    (entry_dir / "meta.json").write_text(
        json.dumps(meta_data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def generate_batch(
    seed_file: Path,
    output_dir: Path,
    num_entries: int = 100,
    start_from: int = 0,
    resume: bool = True
):
    """
    Generate SysML models for entries in nl_seed.jsonl.
    
    Args:
        seed_file: Path to nl_seed.jsonl
        output_dir: Output directory (dataset/with_kernel_spec)
        num_entries: Number of entries to process
        start_from: Index to start from (for resuming)
        resume: If True, skip entries that already exist
    """
    try:
        from nl2sysml.agent_rag_moe import generate_sysml_moe
    except ModuleNotFoundError as exc:
        if exc.name != "nl2sysml":
            raise
        from agent_rag_moe import generate_sysml_moe

    # Read entries
    print(f"Reading entries from {seed_file}...")
    entries = []
    with open(seed_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    
    if not entries:
        print("Error: No entries found in nl_seed.jsonl")
        sys.exit(1)
    
    # Limit to requested number
    entries_to_process = entries[:num_entries]
    total = len(entries_to_process)
    
    print(f"Found {len(entries)} total entries")
    print(f"Processing first {total} entries")
    print(f"Output directory: {output_dir}")
    print(f"Starting from index {start_from}")
    print("=" * 70)
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Statistics
    stats = {
        "total": total,
        "processed": 0,
        "skipped": 0,
        "errors": 0,  # entry-level soft-fails (generation failed; batch continues)
        "expert_soft_fails": 0,  # individual MoE experts that failed within a sample
        "valid": 0,
        "invalid": 0,
        "aligned": 0,
        "misaligned": 0,
    }
    
    # Log file
    log_file = output_dir / "generation.log"
    
    def log(message: str, level: str = "INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] [{level}] {message}"
        print(log_msg)
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(log_msg + "\n")
    
    log(f"Starting batch generation: {total} entries")
    
    # Process each entry
    for idx, entry in enumerate(entries_to_process[start_from:], start=start_from):
        entry_id = entry.get("id", f"UNKNOWN_{idx}")
        description = entry.get("description", "")
        domain = entry.get("domain", "unknown")
        
        # Create entry directory (dataset-style: {id}/{id}.sysml, {id}.txt, meta.json)
        entry_dir = output_dir / entry_id
        sysml_file = entry_dir / f"{entry_id}.sysml"
        txt_file = entry_dir / f"{entry_id}.txt"
        meta_file = entry_dir / "meta.json"
        
        # Check if already exists (resume)
        complete = sysml_file.exists() and txt_file.exists() and meta_file.exists()
        if resume and complete:
            log(f"[{idx+1}/{total}] {entry_id}: Already exists, skipping")
            stats["skipped"] += 1
            continue
        
        log(f"[{idx+1}/{total}] {entry_id}: Generating... (Domain: {domain})")
        log(f"  Description: {description[:80]}...")
        
        try:
            # Generate SysML
            start_time = time.time()
            sysml_code, prompt_record = generate_sysml_moe(description)
            elapsed = time.time() - start_time
            
            if not sysml_code or not sysml_code.strip():
                raise RuntimeError("Generation returned empty SysML")
            
            write_entry_output(entry_dir, entry, sysml_code, prompt_record)
            quality_report = prompt_record.get("quality_report")
            expert_soft = int(prompt_record.get("expert_soft_fail_count") or 0)
            stats["expert_soft_fails"] += expert_soft

            # Update stats
            stats["processed"] += 1
            note = ""
            if expert_soft:
                note = f", expert_soft_fails={expert_soft}"
            if prompt_record.get("final_valid", False):
                stats["valid"] += 1
                log(f"  ✓ Generated (valid, {elapsed:.1f}s{note})")
            else:
                stats["invalid"] += 1
                error_count = prompt_record.get("final_errors", 0)
                log(
                    f"  ⚠ Generated (invalid, {error_count} errors, "
                    f"{elapsed:.1f}s{note})"
                )
            if prompt_record.get("spec_alignment_enabled"):
                if (quality_report or {}).get("accepted", False):
                    stats["aligned"] += 1
                else:
                    stats["misaligned"] += 1
            
        except KeyboardInterrupt:
            log("Interrupted by user", "WARNING")
            print("\n" + "=" * 70)
            print("Generation interrupted. Progress saved.")
            print(f"Processed: {stats['processed']}/{total}")
            print(f"Entry soft-fails: {stats['errors']}")
            print(f"Expert soft-fails: {stats['expert_soft_fails']}")
            print(f"To resume, run with: --start-from {idx}")
            sys.exit(0)

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
            # Hard usage quotas still stop the batch (continuing would burn time).
            # Everything else soft-fails the entry and continues.
            if is_usage_limit:
                log(f"  ✗ Stopping batch (CLI usage limit): {e}", "ERROR")
                print("\n" + "=" * 70)
                print("Stopped: CLI 5-hour/weekly usage limit.")
                print("Completed entries are saved; fix the issue then resume.")
                print(f"Failed entry: {entry_id} (index {idx})")
                print(f"Processed: {stats['processed']}/{total}")
                print(f"Entry soft-fails: {stats['errors']}")
                print(f"Expert soft-fails: {stats['expert_soft_fails']}")
                print(f"Error log: {error_log}")
                print(f"To resume, run with: --start-from {idx}")
                print("=" * 70)
                log(
                    f"Batch stopped at {entry_id} (index {idx}) due to CLI usage limit",
                    "ERROR",
                )
                sys.exit(2)

            stats["errors"] += 1
            log(
                f"  ✗ Soft-fail entry {entry_id}: {e} (log: {error_log})",
                "ERROR",
            )
        
        # Progress update every 10 entries
        if (idx + 1) % 10 == 0:
            log(
                f"Progress: {idx+1}/{total} "
                f"({stats['processed']} generated, {stats['valid']} valid, "
                f"{stats['errors']} entry soft-fails, "
                f"{stats['expert_soft_fails']} expert soft-fails)"
            )
    
    # Final summary
    print("\n" + "=" * 70)
    print("Batch Generation Complete")
    print("=" * 70)
    print(f"Total entries: {total}")
    print(f"Processed: {stats['processed']}")
    print(f"Skipped (already existed): {stats['skipped']}")
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
        f"{stats['expert_soft_fails']} expert soft-fails"
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
        description="Batch generate NL-SysML pairs from nl_seed.jsonl"
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
        help="Path to nl_seed.jsonl (default: nl2sysml/nl_seed.jsonl)"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Output directory (default: dataset/with_kernel_spec)"
    )
    parser.add_argument(
        "--no-spec-alignment",
        action="store_true",
        help="Disable the post-generation spec mismatch gate",
    )
    parser.add_argument(
        "--no-kernel-feedback",
        action="store_true",
        help="Disable SysML kernel execution refine after compiler checks",
    )
    parser.add_argument(
        "--layer2-quality",
        action="store_true",
        help="Deprecated alias: enable kernel feedback (same as default)",
    )
    parser.add_argument(
        "--llm-backend",
        choices=("api", "cli", "codex"),
        default=None,
        help="Model transport: api (HTTP) or cli (Claude Code / Codex subscription; llama via OpenRouter)",
    )
    
    args = parser.parse_args()
    if args.no_spec_alignment:
        os.environ["SPEC_ALIGNMENT_ENABLED"] = "false"
    if args.no_kernel_feedback:
        os.environ["KERNEL_FEEDBACK_ENABLED"] = "false"
    if args.layer2_quality:
        os.environ["KERNEL_FEEDBACK_ENABLED"] = "true"
    if args.llm_backend:
        os.environ["LLM_BACKEND"] = args.llm_backend
    
    # Determine paths
    base = Path(__file__).parent
    if args.seed_file:
        seed_file = Path(args.seed_file)
    else:
        seed_file = base / "nl_seed.jsonl"
    
    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = base.parent / "dataset" / "with_kernel_spec"
    
    if not seed_file.exists():
        print(f"Error: Seed file not found: {seed_file}")
        sys.exit(1)
    
    # Run generation
    generate_batch(
        seed_file=seed_file,
        output_dir=output_dir,
        num_entries=args.num_entries,
        start_from=args.start_from,
        resume=not args.no_resume
    )


if __name__ == "__main__":
    main()
