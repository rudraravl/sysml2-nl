#!/usr/bin/env python3
"""Run GPT-5.5 on dataset.json and evaluate executable SysML rules."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

ABLATION_DIR = Path(__file__).resolve().parent
NL2SYSML_DIR = ABLATION_DIR.parent
if str(NL2SYSML_DIR) not in sys.path:
    sys.path.insert(0, str(NL2SYSML_DIR))
if str(ABLATION_DIR) not in sys.path:
    sys.path.insert(0, str(ABLATION_DIR))

from agent_rag_moe import (  # noqa: E402
    PROMPT_HUMAN_TEMPLATE,
    _default_system_prompt,
    _invoke_with_retry,
    _load_env,
    _rag_context,
)
from compiler_interface import check_code  # noqa: E402
from config import (  # noqa: E402
    COMPILER_SYNTAX_ONLY,
    DEFAULT_DATASET,
    GENERATED_DIR,
    GPT55_MODEL,
    HTML_REPORT,
    RAG_K,
    REPO_ROOT,
    RESULT_CSV,
)
from executable_rules import EXECUTABLE_RULE_IDS, evaluate_executable_rules  # noqa: E402
from report import render_html  # noqa: E402


CSV_FIELDS = [
    "prompt_id",
    "description",
    "model",
    "generated_path",
    "compiler_valid",
    "compiler_error_count",
    "compiler_syntax_error_count",
    "compiler_semantic_error_count",
    "rule_pass_count",
    "rule_fail_count",
    "rule_not_applicable_count",
    "rule_unsupported_count",
]

for _rule_id in EXECUTABLE_RULE_IDS:
    CSV_FIELDS.extend(
        [
            f"{_rule_id}_status",
            f"{_rule_id}_support_mode",
            f"{_rule_id}_checked_elements",
            f"{_rule_id}_failing_elements",
            f"{_rule_id}_rationale",
        ]
    )


def _bool_text(value: bool) -> str:
    return "true" if value else "false"


def load_dataset(path: Path, ids_filter: set[str] | None) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    rows: list[dict[str, str]] = []
    for item in data.get("prompts", []):
        pid = str(item.get("id", "")).strip().upper()
        desc = str(item.get("description", "")).strip()
        if not pid or not desc:
            continue
        if ids_filter and pid not in ids_filter:
            continue
        rows.append({"id": pid, "description": desc})
    return rows


def generate_gpt55(description: str) -> tuple[str, dict[str, Any]]:
    _gkey, openrouter_key = _load_env()
    if not openrouter_key:
        raise RuntimeError("OPENROUTER_API_KEY missing in environment/.env")

    context = _rag_context(description, REPO_ROOT, k=RAG_K)
    executable_hint = (
        "Generate SysML v2 code only. Include executable behavior when applicable. "
        "For signal accepts, expose typed payload/output parameters. "
        "For messages, assign signatures and realize signal messages with flows/connectors. "
        "For state machines, call only locally defined or structurally reachable actions. "
        "For submachine states, reference defined state machines in the owning structure."
    )
    system_msg = _default_system_prompt(executable_hint)
    human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=description)
    code = _invoke_with_retry(GPT55_MODEL, system_msg, human_msg, openrouter_key)
    return code, {
        "model": GPT55_MODEL,
        "context_length": len(context),
        "system_prompt": system_msg,
        "human_prompt": human_msg,
    }


def compiler_counts(result: Any) -> tuple[int, int]:
    errors = getattr(result, "errors", []) or []
    syntax_count = sum(1 for e in errors if e.is_syntax_error())
    semantic_count = sum(1 for e in errors if e.is_semantic_error())
    return syntax_count, semantic_count


def evaluate_prompt(prompt_id: str, description: str, *, resume: bool) -> dict[str, str]:
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    sysml_path = GENERATED_DIR / f"{prompt_id}.sysml"
    prompt_path = GENERATED_DIR / f"{prompt_id}_prompt.json"

    if resume and sysml_path.exists():
        code = sysml_path.read_text(encoding="utf-8")
        prompt_record = {"model": GPT55_MODEL}
        print(f"  {prompt_id}: using existing {sysml_path}")
    else:
        print(f"  {prompt_id}: generating with {GPT55_MODEL}...", flush=True)
        code, prompt_record = generate_gpt55(description)
        sysml_path.write_text(f"// {description}\n{code.strip()}\n", encoding="utf-8")
        prompt_path.write_text(json.dumps(prompt_record, indent=2), encoding="utf-8")

    compiler_result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
    syntax_count, semantic_count = compiler_counts(compiler_result)
    rule_results = evaluate_executable_rules(code)

    status_counts = {
        "pass": sum(1 for r in rule_results if r.status == "pass"),
        "fail": sum(1 for r in rule_results if r.status == "fail"),
        "not_applicable": sum(1 for r in rule_results if r.status == "not_applicable"),
        "unsupported": sum(1 for r in rule_results if r.status == "unsupported"),
    }

    row: dict[str, str] = {
        "prompt_id": prompt_id,
        "description": description,
        "model": str(prompt_record.get("model", GPT55_MODEL)),
        "generated_path": str(sysml_path),
        "compiler_valid": _bool_text(bool(getattr(compiler_result, "is_valid", False))),
        "compiler_error_count": str(getattr(compiler_result, "error_count", 0)),
        "compiler_syntax_error_count": str(syntax_count),
        "compiler_semantic_error_count": str(semantic_count),
        "rule_pass_count": str(status_counts["pass"]),
        "rule_fail_count": str(status_counts["fail"]),
        "rule_not_applicable_count": str(status_counts["not_applicable"]),
        "rule_unsupported_count": str(status_counts["unsupported"]),
    }

    for result in rule_results:
        prefix = result.rule_id
        row[f"{prefix}_status"] = result.status
        row[f"{prefix}_support_mode"] = result.support_mode
        row[f"{prefix}_checked_elements"] = str(result.checked_elements)
        row[f"{prefix}_failing_elements"] = "; ".join(result.failing_elements)
        row[f"{prefix}_rationale"] = result.rationale

    return row


def write_csv(rows: list[dict[str, str]], csv_path: Path = RESULT_CSV) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="GPT-5.5 executable-rule ablation study")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--ids", default="", help="Comma-separated prompt IDs, e.g. U1,U9")
    parser.add_argument("--resume", action="store_true", help="Reuse existing generated/*.sysml files")
    parser.add_argument("--dry-run", action="store_true", help="Print plan without model calls")
    parser.add_argument("--summary-only", action="store_true", help="Render HTML from existing result.csv")
    args = parser.parse_args()

    if args.summary_only:
        if not RESULT_CSV.exists():
            raise SystemExit(f"Missing {RESULT_CSV}")
        render_html(RESULT_CSV, HTML_REPORT)
        print(f"Wrote {HTML_REPORT}")
        return

    ids_filter = None
    if args.ids.strip():
        ids_filter = {x.strip().upper() for x in args.ids.split(",") if x.strip()}
    prompts = load_dataset(args.dataset, ids_filter)
    if not prompts:
        raise SystemExit("No prompts to run.")

    if args.dry_run:
        print("Dry run - would execute:")
        print(f"  Model: {GPT55_MODEL}")
        print(f"  Dataset: {args.dataset} ({len(prompts)} prompts)")
        print(f"  Generated SysML: {GENERATED_DIR}/")
        print(f"  CSV: {RESULT_CSV}")
        print(f"  HTML: {HTML_REPORT}")
        return

    rows = []
    for item in prompts:
        rows.append(evaluate_prompt(item["id"], item["description"], resume=args.resume))
        write_csv(rows, RESULT_CSV)
        render_html(RESULT_CSV, HTML_REPORT)
        print(f"  {item['id']}: wrote partial CSV/HTML", flush=True)

    print(f"Wrote {RESULT_CSV}")
    print(f"Wrote {HTML_REPORT}")


if __name__ == "__main__":
    main()
