"""Validate the balanced OpenUSD retrieval corpus and write a summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .corpus import OpenUSDExampleCorpus
from .validator import OpenUSDValidator


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    corpus = OpenUSDExampleCorpus(subset="semantic100")
    validator = OpenUSDValidator()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for example in corpus.examples:
        validation = validator.validate(
            example.model_path, output_dir=args.output_dir / example.id
        )
        results.append({
            "id": example.id,
            "category": example.category,
            **validation.to_dict(),
        })
        print(f"{example.id}: {'PASS' if validation.success else 'FAIL'}")
    categories = {}
    for example in corpus.examples:
        categories[example.category] = categories.get(example.category, 0) + 1
    summary = {
        "passed": sum(item["success"] for item in results),
        "total": len(results),
        "categories": categories,
        "balanced": set(categories.values()) == {10},
        "results": results,
    }
    (args.output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, allow_nan=False), encoding="utf-8"
    )
    print(json.dumps({key: value for key, value in summary.items()
                      if key != "results"}, indent=2))
    raise SystemExit(0 if summary["passed"] == summary["total"] else 1)


if __name__ == "__main__":
    main()
