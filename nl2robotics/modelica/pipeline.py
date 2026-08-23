"""Retrieval, generation, execution, and guarded repair for Modelica robotics."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import asdict
from pathlib import Path
import tempfile

from .corpus import ExampleCorpus
from .fmu_runtime import FMIContainerRunner
from .models import CandidateResult, Layer1CandidateResult
from .openmodelica import OpenModelicaRunner
from .properties import evaluate_properties, read_trace


SYSTEM_PROMPT = """You generate one self-contained, executable Modelica model.
Return Modelica code only, without markdown or prose. Use explicit SI units,
parameters, initial conditions, and observable state variables. Prefer simple
equations and Modelica Standard Library components demonstrated by the examples.
The top-level model must compile in OpenModelica. Standalone plant requests must
be directly simulatable. Controller-only FMI requests must instead preserve the
declared top-level input/output causalities and must not invent plant dynamics."""


class ModelicaPipeline:
    def __init__(self, corpus: ExampleCorpus | None = None,
                 runner: OpenModelicaRunner | None = None,
                 fmi_runner: FMIContainerRunner | None = None):
        self.corpus = corpus or ExampleCorpus()
        self.runner = runner or OpenModelicaRunner()
        self.fmi_runner = fmi_runner or FMIContainerRunner()

    def build_prompt(self, requirement: str, *, k: int = 5) -> str:
        return self._prompt(requirement, self.corpus.retrieve(requirement, k=k))

    def build_messages(self, requirement: str, *, k: int = 5) -> tuple[str, str, list]:
        hits = self.corpus.retrieve(requirement, k=k)
        context = self.corpus.format_context(hits)
        human = (
            f"Retrieved examples:\n{context}\n\n"
            "Generate one complete Modelica model for this requirement:\n"
            f"{requirement.strip()}\n"
        )
        return SYSTEM_PROMPT, human, hits

    def build_baseline_messages(self, requirement: str) -> tuple[str, str]:
        human = (
            "Generate one complete Modelica model for this requirement:\n"
            f"{requirement.strip()}\n"
        )
        return SYSTEM_PROMPT, human

    def _prompt(self, requirement: str, hits: list[tuple]) -> str:
        context = self.corpus.format_context(hits)
        return (
            f"{SYSTEM_PROMPT}\n\nRetrieved examples:\n{context}\n\n"
            f"Requirement:\n{requirement.strip()}\n"
        )

    def evaluate(self, code: str, properties: list[dict], *,
                 output_dir: Path | None = None, **simulation) -> CandidateResult:
        run = self.runner.run(code, output_dir=output_dir, **simulation)
        results = []
        if run.simulated and run.result_file:
            results = evaluate_properties(read_trace(run.result_file), properties)
        return CandidateResult(code=code, run=run, properties=results)

    def compile(self, code: str, *,
                output_dir: Path | None = None) -> Layer1CandidateResult:
        return Layer1CandidateResult(
            code=code,
            build=self.runner.compile(code, output_dir=output_dir),
        )

    def export_and_execute_fmu(
        self,
        code: str,
        *,
        properties: list[dict] | None = None,
        outputs: list[str] | None = None,
        start_values: dict[str, float | int | bool] | None = None,
        start_time: float = 0.0,
        stop_time: float = 5.0,
        step_size: float = 0.01,
        output_dir: Path | None = None,
    ) -> dict:
        """Export FMI 2.0 CS, execute it, and evaluate its trace."""
        root = output_dir or Path(tempfile.mkdtemp(prefix="modelica-fmi-stage-"))
        root.mkdir(parents=True, exist_ok=True)
        fmu = self.runner.export_fmu(code, output_dir=root / "export")
        execution = None
        property_results = []
        if fmu.success and fmu.fmu_path:
            execution = self.fmi_runner.run(
                fmu.fmu_path,
                start_time=start_time,
                stop_time=stop_time,
                step_size=step_size,
                start_values=start_values,
                outputs=outputs,
                output_dir=root / "execution",
            )
            if execution.success and execution.result_file and properties:
                property_results = evaluate_properties(
                    read_trace(execution.result_file), properties
                )
        passed = (
            fmu.success
            and execution is not None
            and execution.success
            and all(item.passed for item in property_results)
        )
        return {
            "stage": "fmi_execution",
            "passed": passed,
            "modelica": code,
            "fmu": fmu.to_dict(),
            "execution": execution.to_dict() if execution else None,
            "properties": [asdict(item) for item in property_results],
        }

    def generate(self, requirement: str, ask: Callable[[str], str], *,
                 k: int = 5, max_repairs: int = 2,
                 output_dir: Path | None = None) -> dict:
        """Layer 1 single-model path: RAG, generation, build, and repair."""
        if not requirement.strip():
            raise ValueError("requirement must be non-empty")
        hits = self.corpus.retrieve(requirement, k=k)
        candidate = clean_code(ask(self._prompt(requirement, hits)))
        return self.refine_layer1(
            requirement,
            candidate,
            ask,
            hits=hits,
            max_repairs=max_repairs,
            output_dir=output_dir,
        )

    def refine_layer1(self, requirement: str, candidate: str,
                      repair: Callable[[str], str], *,
                      hits: list[tuple] | None = None, max_repairs: int = 2,
                      output_dir: Path | None = None) -> dict:
        """Build and compiler-repair a candidate without running a simulation."""
        if hits is None:
            hits = self.corpus.retrieve(requirement, k=5)
        attempts = []
        best: Layer1CandidateResult | None = None
        for attempt in range(max_repairs + 1):
            attempt_dir = (output_dir / f"attempt-{attempt}") if output_dir else Path(
                tempfile.mkdtemp(prefix=f"modelica-layer1-{attempt}-")
            )
            result = self.compile(candidate, output_dir=attempt_dir)
            accepted = best is None or result.quality > best.quality
            if accepted:
                best = result
            attempts.append({
                "attempt": attempt,
                "accepted_as_best": accepted,
                "modelica": result.code,
                **result.to_dict(),
            })
            if result.passed or not result.build.available or attempt >= max_repairs:
                break
            assert best is not None
            repaired = clean_code(repair(
                _compiler_repair_prompt(requirement, best.code, best)
            ))
            if repaired == best.code:
                break
            candidate = repaired
        assert best is not None
        return {
            "stage": "layer1",
            "passed": best.passed,
            "final_modelica": best.code,
            "repairs": len(attempts) - 1,
            "corpus_subset": self.corpus.subset,
            "retrieved_examples": [
                {"id": item.id, "score": score} for item, score in hits
            ],
            "attempts": attempts,
        }

    def generate_and_execute(self, requirement: str, ask: Callable[[str], str], *,
                             properties: list[dict] | None = None, k: int = 5,
                             max_repairs: int = 1,
                             output_dir: Path | None = None,
                             **simulation) -> dict:
        """Legacy combined path retained for later Layer 2 work."""
        if not requirement.strip():
            raise ValueError("requirement must be non-empty")
        hits = self.corpus.retrieve(requirement, k=k)
        candidate = clean_code(ask(self._prompt(requirement, hits)))
        return self.refine(
            requirement,
            candidate,
            ask,
            properties=properties,
            hits=hits,
            max_repairs=max_repairs,
            output_dir=output_dir,
            **simulation,
        )

    def refine(self, requirement: str, candidate: str,
               repair: Callable[[str], str], *, properties: list[dict] | None = None,
               hits: list[tuple] | None = None, max_repairs: int = 1,
               output_dir: Path | None = None, **simulation) -> dict:
        """Evaluate and repair a synthesized candidate, retaining only improvements."""
        properties = properties or []
        if hits is None:
            hits = self.corpus.retrieve(requirement, k=5)
        attempts = []
        best: CandidateResult | None = None
        for attempt in range(max_repairs + 1):
            attempt_dir = (output_dir / f"attempt-{attempt}") if output_dir else Path(
                tempfile.mkdtemp(prefix=f"modelica-attempt-{attempt}-")
            )
            result = self.evaluate(candidate, properties,
                                   output_dir=attempt_dir, **simulation)
            accepted = best is None or result.quality > best.quality
            if accepted:
                best = result
            attempts.append({
                "attempt": attempt,
                "accepted_as_best": accepted,
                "modelica": result.code,
                **result.to_dict(),
            })
            if result.passed or attempt >= max_repairs:
                break
            candidate = clean_code(repair(
                _execution_repair_prompt(requirement, candidate, result)
            ))
        assert best is not None
        return {
            "passed": best.passed,
            "final_modelica": best.code,
            "repairs": len(attempts) - 1,
            "corpus_subset": self.corpus.subset,
            "retrieved_examples": [
                {"id": item.id, "score": score} for item, score in hits
            ],
            "attempts": attempts,
        }


def clean_code(response: str) -> str:
    text = response.strip()
    if "```" in text:
        blocks = text.split("```")
        text = max((block.removeprefix("modelica").strip() for block in blocks), key=len)
    start = text.find("model ")
    if start > 0:
        text = text[start:]
    if not text:
        raise ValueError("generator returned no Modelica code")
    return text


def _compiler_repair_prompt(requirement: str, code: str,
                            result: Layer1CandidateResult) -> str:
    diagnostics = "\n".join(
        item.message for item in result.build.diagnostics
    ) or "OpenModelica did not return a structured diagnostic."
    return f"""{SYSTEM_PROMPT}

Repair the candidate using only the grounded OpenModelica compiler feedback.
Preserve correct content and return one complete, self-contained model. Do not
run or discuss a simulation; this stage ends when the model builds.

Requirement:
{requirement}

Compiler diagnostics:
{diagnostics}

Candidate:
{code}
"""


def _execution_repair_prompt(requirement: str, code: str,
                             result: CandidateResult) -> str:
    diagnostics = "\n".join(item.message for item in result.run.diagnostics) or "None"
    properties = "\n".join(
        f"- {item.formula}: {item.detail}" for item in result.properties if not item.passed
    ) or "No trace properties were evaluated because compilation or simulation failed."
    return f"""{SYSTEM_PROMPT}

Repair the candidate to satisfy the requirement and the grounded feedback.
Preserve correct behavior and return the complete model.

Requirement:
{requirement}

Compiler/simulation diagnostics:
{diagnostics}

Failed properties:
{properties}

Candidate:
{code}
"""
