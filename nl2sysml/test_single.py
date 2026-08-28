#!/usr/bin/env python3
"""
Test script to run a single example from nl_seed.jsonl through the MoE pipeline.
Usage: python test_single.py [id_or_index] [--no-compiler] [--no-spec-alignment]
       [--no-kernel-feedback] [--llm-backend cli|api]
  - If id_or_index is a number, uses that line number (1-indexed)
  - If id_or_index is a string like "U140", finds that ID
  - If no argument, uses the first entry
  - --no-compiler: Disable compiler checking for faster testing
  - --llm-backend: api (default; OpenRouter) or cli (Claude Code / Codex)
"""

import json
import sys
import os
from pathlib import Path
try:
    from nl2sysml.agent_rag_moe import generate_sysml_moe
except ModuleNotFoundError as exc:
    if exc.name != "nl2sysml":
        raise
    from agent_rag_moe import generate_sysml_moe

def main():
    base = Path(__file__).parent
    seed_file = base / "nl_seed.jsonl"
    
    # Parse arguments
    args = sys.argv[1:]
    disable_compiler = False
    disable_spec_alignment = False
    disable_kernel_feedback = False
    entry_arg = None
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--no-compiler":
            disable_compiler = True
        elif arg == "--no-spec-alignment":
            disable_spec_alignment = True
        elif arg == "--no-kernel-feedback":
            disable_kernel_feedback = True
        elif arg == "--layer2-quality":
            # Deprecated alias kept for compatibility; kernel feedback is on by default.
            pass
        elif arg == "--llm-backend":
            if i + 1 >= len(args):
                print("Error: --llm-backend requires api|cli|codex")
                sys.exit(1)
            os.environ["LLM_BACKEND"] = args[i + 1]
            i += 1
        elif arg.startswith("--llm-backend="):
            os.environ["LLM_BACKEND"] = arg.split("=", 1)[1]
        elif not arg.startswith("--"):
            entry_arg = arg
        i += 1
    
    # Disable compiler if requested
    if disable_compiler:
        os.environ["SYSML_COMPILER_ENABLED"] = "false"
        print("Compiler checking disabled (--no-compiler flag)\n")
    if disable_spec_alignment:
        os.environ["SPEC_ALIGNMENT_ENABLED"] = "false"
        print("Spec alignment disabled (--no-spec-alignment flag)\n")
    if disable_kernel_feedback:
        os.environ["KERNEL_FEEDBACK_ENABLED"] = "false"
        print("Kernel feedback disabled (--no-kernel-feedback flag)\n")
    backend = os.getenv("LLM_BACKEND", "api").lower()
    if backend in ("cli", "codex", "codex-cli", "claude", "claude-cli"):
        print(
            "LLM backend: cli "
            "(claude→Claude Code, gpt→Codex subscription CLIs; everything else→OpenRouter)\n"
        )
    else:
        print("LLM backend: api (OpenRouter HTTP)\n")
    
    if not seed_file.exists():
        print(f"Error: {seed_file} not found")
        sys.exit(1)
    
    # Read all entries
    entries = []
    with open(seed_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    
    if not entries:
        print("Error: No entries found in nl_seed.jsonl")
        sys.exit(1)
    
    # Determine which entry to use
    if entry_arg:
        arg = entry_arg.strip()
        # Try as ID first
        entry = None
        for e in entries:
            if e.get("id") == arg:
                entry = e
                break
        
        # If not found as ID, try as index
        if entry is None:
            try:
                idx = int(arg) - 1  # Convert to 0-indexed
                if 0 <= idx < len(entries):
                    entry = entries[idx]
                else:
                    print(f"Error: Index {arg} out of range (1-{len(entries)})")
                    sys.exit(1)
            except ValueError:
                print(f"Error: '{arg}' is not a valid ID or index")
                sys.exit(1)
    else:
        entry = entries[0]
    
    # Extract information
    entry_id = entry.get("id", "UNKNOWN")
    description = entry.get("description", "")
    domain = entry.get("domain", "unknown")
    source_title = entry.get("source_title", "")
    
    if not description:
        print(f"Error: Entry {entry_id} has no description")
        sys.exit(1)
    
    print("=" * 70)
    print(f"Testing MoE Pipeline")
    print("=" * 70)
    print(f"ID: {entry_id}")
    print(f"Domain: {domain}")
    print(f"Source: {source_title}")
    print(f"Description: {description}")
    print("=" * 70)
    
    # Check compiler status
    compiler_enabled = os.getenv("SYSML_COMPILER_ENABLED", "true").lower() != "false"
    if compiler_enabled:
        try:
            try:
                from nl2sysml.compiler_interface import is_compiler_available
            except ModuleNotFoundError:
                from compiler_interface import is_compiler_available
            if is_compiler_available():
                print("Compiler: Enabled (will validate and refine)")
            else:
                print("Compiler: Disabled (not available)")
        except Exception:
            print("Compiler: Disabled (not available)")
    else:
        print("Compiler: Disabled (via SYSML_COMPILER_ENABLED=false)")
    
    print("\nGenerating SysML v2 model...")
    
    # Generate SysML
    try:
        code, prompt_record = generate_sysml_moe(description)
        
        # Display results
        print("\n" + "=" * 70)
        print("Generated SysML v2 Code:")
        print("=" * 70)
        print(code)
        print("=" * 70)
        
        # Show validation info if available
        if "final_valid" in prompt_record:
            print(f"\nValidation: {'✓ Valid' if prompt_record['final_valid'] else '✗ Invalid'}")
            if prompt_record.get("final_errors", 0) > 0:
                print(f"Errors: {prompt_record['final_errors']}")
                if "final_error_details" in prompt_record:
                    print("\nError Details:")
                    for err in prompt_record["final_error_details"][:5]:  # Show first 5
                        print(f"  Line {err['line']}, Col {err['column']}: {err['message']}")
        quality_report = prompt_record.get("quality_report")
        if quality_report:
            attempts = quality_report.get("attempts", [])
            summary = attempts[-1].get("alignment", {}).get("summary", {}) if attempts else {}
            print(
                f"\nSpec alignment: "
                f"{'✓ Accepted' if quality_report.get('accepted') else '✗ Not accepted'}"
            )
            print(f"Similarity: {summary.get('similarity')}")
            print(f"Repairs: {quality_report.get('repairs', 0)}")
            if quality_report.get("error"):
                print(f"Alignment error: {quality_report['error']}")
        
        # Save dataset-style per-seed folder only:
        # result_rag_moe/{id}/{id}.sysml, {id}.txt, meta.json
        try:
            from nl2sysml.batch_generate import write_entry_output
        except ModuleNotFoundError:
            from batch_generate import write_entry_output

        out_dir = base / "result_rag_moe" / entry_id
        write_entry_output(out_dir, entry, code, prompt_record)
        print(f"\n✓ Saved to: {out_dir}/")
        print(f"  - {entry_id}.sysml")
        print(f"  - {entry_id}.txt")
        print(f"  - meta.json")
        
    except Exception as e:
        print(f"\nError during generation: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
