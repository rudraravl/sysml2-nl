"""Verify that this machine is ready to run the Modelica Layer 1 experiment."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile

from dotenv import load_dotenv

from .audit_corpus import audit
from .corpus import ExampleCorpus
from .moe import routing
from .openmodelica import OpenModelicaRunner
from .pipeline import ModelicaPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=("auto", "local", "docker"),
                        default="auto")
    parser.add_argument("--llm-backend", choices=("api", "cli"), default="cli")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    os.environ["LLM_BACKEND"] = args.llm_backend
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    runner = OpenModelicaRunner(backend=args.backend)
    resolved = runner.resolved_backend()
    route_report = routing()
    providers = set(route_report["routes"].values())
    binaries = {
        provider: shutil.which(provider)
        for provider in sorted(providers & {"claude", "codex"})
    }

    corpus = ExampleCorpus(subset="full100")
    example = next(item for item in corpus.examples if item.id == "M001")
    output_dir = args.output_dir or Path(
        tempfile.mkdtemp(prefix="modelica-layer1-preflight-")
    )
    build = ModelicaPipeline(corpus=corpus, runner=runner).compile(
        example.code, output_dir=output_dir / "compiler-smoke"
    )
    corpus_report = audit()
    key_present = bool(os.getenv("OPENROUTER_API_KEY"))
    llm_ready = key_present and all(binaries.values())
    if args.llm_backend == "api":
        llm_ready = key_present

    report = {
        "ready": bool(
            corpus_report["ok"]
            and resolved
            and build.passed
            and llm_ready
        ),
        "layer": 1,
        "corpus": {
            "passed": corpus_report["ok"],
            "examples": corpus_report["examples"],
            "evaluation_tasks": corpus_report["evaluation_tasks"],
        },
        "compiler": {
            "requested_backend": args.backend,
            "resolved_backend": resolved,
            "smoke_build_passed": build.passed,
            "diagnostics": [item.message for item in build.build.diagnostics],
        },
        "llm": {
            "backend": args.llm_backend,
            "routes": route_report["routes"],
            "binaries": {
                name: bool(path) for name, path in binaries.items()
            },
            "openrouter_key_present": key_present,
            "ready": llm_ready,
        },
    }
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["ready"] else 1)


if __name__ == "__main__":
    main()
