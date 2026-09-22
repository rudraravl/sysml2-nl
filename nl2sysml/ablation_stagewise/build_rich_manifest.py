#!/usr/bin/env python3
"""Build the frozen, A0-paired rich-prompt manifest for SysML ablations."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from typing import Any


REPOSITORY = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "rich500_manifest.jsonl"
DEFAULT_COUNT = 500
DEFAULT_SEED = 20260922


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_seed(path: Path) -> list[dict[str, Any]]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        task_id = str(row.get("id", "")).strip().upper()
        if not task_id:
            raise ValueError(f"missing id at seed line {line_number}")
        rows.append({**row, "id": task_id})
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("seed corpus contains duplicate task IDs")
    return rows


def _rich_by_task_id(data_dir: Path) -> dict[str, dict[str, Any]]:
    mapped: dict[str, dict[str, Any]] = {}
    for meta_path in sorted(data_dir.glob("*/meta.json")):
        meta = _read_json(meta_path)
        source_path = str(meta.get("source_path", ""))
        if not source_path.startswith("nl_seed.jsonl:"):
            continue
        task_id = source_path.split(":", 1)[1].strip().upper()
        data_id = meta_path.parent.name
        text_path = meta_path.parent / f"{data_id}.txt"
        sysml_path = meta_path.parent / f"{data_id}.sysml"
        if not text_path.is_file() or not sysml_path.is_file():
            continue
        if task_id in mapped:
            raise ValueError(f"duplicate rich prompt mapping for {task_id}")
        mapped[task_id] = {
            "data_id": data_id,
            "text_path": text_path,
            "sysml_path": sysml_path,
            "meta": meta,
        }
    return mapped


def _complete_a0_ids(a0_dir: Path) -> set[str]:
    result = set()
    for task_dir in a0_dir.iterdir():
        if not task_dir.is_dir():
            continue
        task_id = task_dir.name.upper()
        if all((task_dir / f"{task_dir.name}{suffix}").is_file() for suffix in (".txt", ".sysml")) and (task_dir / "meta.json").is_file():
            result.add(task_id)
    return result


def _allocation(rows: list[dict[str, Any]], count: int) -> dict[str, int]:
    """Allocate the sample proportionally by domain using largest remainders."""
    totals = Counter(str(row.get("domain") or "unknown") for row in rows)
    if count > len(rows):
        raise ValueError(f"requested {count} rows from only {len(rows)} eligible rows")
    exact = {domain: count * size / len(rows) for domain, size in totals.items()}
    allocated = {domain: int(value) for domain, value in exact.items()}
    remaining = count - sum(allocated.values())
    order = sorted(totals, key=lambda domain: (-(exact[domain] - allocated[domain]), domain))
    for domain in order[:remaining]:
        allocated[domain] += 1
    return allocated


def build_manifest(repository: Path, *, count: int, seed: int) -> list[dict[str, Any]]:
    seeds = _load_seed(repository / "nl2sysml" / "nl_seed.jsonl")
    rich = _rich_by_task_id(repository / "dataset" / "data")
    a0_dir = repository / "dataset" / "naive_glm"
    a0_ids = _complete_a0_ids(a0_dir)
    eligible = [row for row in seeds if row["id"] in rich and row["id"] in a0_ids]

    # The retrieval implementation uses only dataset IDs 000001--000300. The
    # selected rich prompts must remain outside that pool to prevent exact-pair
    # leakage into the RAG conditions.
    overlap = [row["id"] for row in eligible if int(rich[row["id"]]["data_id"]) <= 300]
    if overlap:
        raise ValueError(f"eligible prompts overlap the retrieval pool: {overlap[:10]}")

    allocations = _allocation(eligible, count)
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in eligible:
        groups[str(row.get("domain") or "unknown")].append(row)

    selected = []
    for domain, domain_rows in sorted(groups.items()):
        ordered = sorted(
            domain_rows,
            key=lambda row: _sha256_bytes(f"{seed}:selection:{domain}:{row['id']}".encode()),
        )
        selected.extend(ordered[: allocations[domain]])
    selected.sort(key=lambda row: _sha256_bytes(f"{seed}:manifest-order:{row['id']}".encode()))

    result = []
    for seed_row in selected:
        task_id = seed_row["id"]
        source = rich[task_id]
        text_path = source["text_path"]
        reference_path = source["sysml_path"]
        a0_path = a0_dir / task_id / f"{task_id}.sysml"
        description = text_path.read_text(encoding="utf-8").strip()
        result.append({
            "id": task_id,
            "description": description,
            "domain": seed_row.get("domain", "unknown"),
            "source_title": seed_row.get("source_title"),
            "provenance": seed_row.get("provenance"),
            "prompt_source": "dataset_rich_nl",
            "dataset_data_id": source["data_id"],
            "dataset_text_path": str(text_path.relative_to(repository)),
            "dataset_text_sha256": _sha256_bytes(text_path.read_bytes()),
            "reference_sysml_path": str(reference_path.relative_to(repository)),
            "reference_sysml_sha256": _sha256_bytes(reference_path.read_bytes()),
            "a0_candidate_path": str(a0_path.relative_to(repository)),
            "a0_candidate_sha256": _sha256_bytes(a0_path.read_bytes()),
            "selection_seed": seed,
        })
    if len(result) != count or len({row["id"] for row in result}) != count:
        raise AssertionError("selection did not produce the requested unique count")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=REPOSITORY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    rows = build_manifest(args.repository.resolve(), count=args.count, seed=args.seed)
    rendered = "".join(json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n" for row in rows)
    if args.check:
        if not args.output.is_file() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit(f"manifest is stale: {args.output}")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(json.dumps({
        "output": str(args.output),
        "prompt_count": len(rows),
        "domain_counts": dict(sorted(Counter(row["domain"] for row in rows).items())),
        "manifest_sha256": _sha256_bytes(rendered.encode("utf-8")),
        "selection_seed": args.seed,
    }, indent=2))


if __name__ == "__main__":
    main()
