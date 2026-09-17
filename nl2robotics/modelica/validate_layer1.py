"""Check and build the Modelica RAG corpus without executing any model."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .openmodelica import OpenModelicaRunner
from .pipeline import ModelicaPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=("auto", "local", "docker"),
                        default="auto")
    parser.add_argument("--output-dir", type=Path,
                        default=Path("modelica-layer1-validation"))
    parser.add_argument("--subset", choices=(
        "core24", "balanced50", "full100", "semantic500",
    ),
                        default="full100")
    parser.add_argument("--ids", nargs="*", help="optional RAG example IDs")
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
    results = []
    for row in rows:
        code = (root / row["model_file"]).read_text(encoding="utf-8")
        result = pipeline.compile(code, output_dir=args.output_dir / row["id"])
        results.append({"id": row["id"], **result.to_dict()})
        print(f"{row['id']}: {'PASS' if result.passed else 'FAIL'}", flush=True)

    report = {
        "stage": "layer1",
        "operation": "check-and-build-only",
        "subset": args.subset,
        "examples": len(results),
        "passed": sum(item["passed"] for item in results),
        "failed": sum(not item["passed"] for item in results),
        "compiler_seconds": round(sum(
            item["build"]["duration_seconds"] for item in results
        ), 6),
        "results": results,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "summary.json").write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    print(
        f"Layer 1 builds: {report['passed']}/{report['examples']} passed",
        flush=True,
    )
    raise SystemExit(0 if report["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
