"""Compile, simulate, and property-check the complete Modelica RAG corpus."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .openmodelica import OpenModelicaRunner
from .pipeline import ModelicaPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=("auto", "local", "docker"), default="auto")
    parser.add_argument("--output-dir", type=Path, default=Path("modelica-example-results"))
    parser.add_argument("--subset", choices=("core24", "balanced50", "full100"),
                        default="full100")
    parser.add_argument("--ids", nargs="*", help="optional example IDs to validate")
    args = parser.parse_args()

    root = Path(__file__).with_name("examples")
    rows = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    subsets = json.loads((root / "corpus_subsets.json").read_text(encoding="utf-8"))
    allowed = set(subsets[args.subset])
    if args.ids:
        allowed &= {item.upper() for item in args.ids}
    rows = [row for row in rows if row["id"] in allowed]
    if not rows:
        raise SystemExit("no examples selected")
    pipeline = ModelicaPipeline(runner=OpenModelicaRunner(backend=args.backend))
    summary = []
    for row in rows:
        code = (root / row["model_file"]).read_text(encoding="utf-8")
        result = pipeline.evaluate(
            code,
            row["properties"],
            output_dir=args.output_dir / row["id"],
            **row["simulation"],
        )
        summary.append({"id": row["id"], **result.to_dict()})
        print(f"{row['id']}: {'PASS' if result.passed else 'FAIL'}")
    report = {
        "examples": len(summary),
        "passed": sum(item["passed"] for item in summary),
        "subset": args.subset,
        "results": summary,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "summary.json").write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    raise SystemExit(0 if report["passed"] == report["examples"] else 1)


if __name__ == "__main__":
    main()
