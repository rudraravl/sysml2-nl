"""Best-of-N sampling baseline for the Modelica robotics study.

Answers the compute-fairness question "does the harness beat plain best-of-N sampling from the
same cheap model, scored by the same compiler?". FORGE spends several model calls per requirement;
this condition spends the same budget on N independent one-shot samples of the B0 baseline and keeps
the one OpenModelica likes best. No retrieval, no experts, no combiner, no repair, no contract, no
semantic alignment.

It is B0 with the single generation call replaced by N. The prompt, the frozen baseline model and
transport (`baseline_ask`), `clean_code`, the compile check (`ModelicaPipeline.compile`) and the
whole downstream funnel are B0's, unchanged: FMU export, FMU initialization, execution and finite
trace validation run on the ONE selected model through
`ModelicaCapabilityOrchestrator.run_compiler_execution_baseline`. So B0 -> BoN isolates sampling and
nothing else, and BoN is scored by exactly the harness that scores B0 and FULL.

Selection rule (deterministic, compiler-only, no oracle):
    maximize `Layer1CandidateResult.quality` = (compiled, checked, -error_count) -- the ordering
    FORGE's own compile-repair loop uses to decide which attempt to keep -- and break ties on the
    lowest sample index. A sample with no extractable code is a failed candidate, ranked last.
Nothing downstream of the compiler (FMU export, execution, trace) informs the choice.

A transport failure on ANY sample aborts the cell as infrastructure (identical rerun), the same
rule the frozen protocol applies to a missing MoE expert: a partial ensemble is never compared as if
it were complete. A model that answers with no code is a legitimate failed candidate, not an
infrastructure event.

Recorded in `generation.json` (and the cell's `run.json` under `best_of_n`): every candidate's
compile result, the selected index, and the distinct / compiling counts. `attempts[0]` is sample 0,
so the existing `modelica_build_attempt_0` metric is the single-sample rate B0 measures, from
which any-of-N and mean-per-sample compile rates follow.

Run it with `python -m nl2robotics.experiments.run_best_of_n` (a thin wrapper over `run_cli`).
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkTask
from nl2robotics.modelica.pipeline import clean_code
from nl2robotics.modelica.models import Layer1CandidateResult
from nl2robotics.orchestrator.modelica_capability import ModelicaCapabilityOrchestrator

from .conditions import AblationCondition
from .executor import (
    PipelineExperimentExecutor,
    _annotate_generation_report,
    _baseline_execution_clock,
)

DEFAULT_N = 6
CONDITION_PREFIX = "BoN"
SELECTION_RULE = "max (compiled, checked, -error_count) > lowest sample index"


def best_of_n_condition(n: int = DEFAULT_N) -> AblationCondition:
    """B0's controls with a sampling budget: nothing but the id/label differs from B0."""
    if n < 1:
        raise ValueError("n must be >= 1")
    return AblationCondition(
        f"{CONDITION_PREFIX}{n}", f"best_of_{n}", False, False, False, False, False
    )


def is_best_of_n(condition: AblationCondition) -> bool:
    return condition.id.startswith(CONDITION_PREFIX) and condition.label.startswith("best_of_")


def rank_key(row: dict) -> tuple:
    """Sort key whose minimum is the selected candidate. `quality` is None for a failed candidate."""
    quality = row.get("quality")
    if quality is None:
        return (1, 0, 0, 0, row["index"])
    compiled, checked, neg_errors = quality
    return (0, -compiled, -checked, -neg_errors, row["index"])


def select_best(rows: list[dict]) -> dict | None:
    return min(rows, key=rank_key) if rows else None


class BestOfNExecutor(PipelineExperimentExecutor):
    """B0's executor with `_generate_modelica` fanned out into N compiler-ranked samples."""

    def __init__(self, *, n: int = DEFAULT_N, compile_parallelism: int = 3, **kwargs):
        if n < 1:
            raise ValueError("n must be >= 1")
        super().__init__(**kwargs)
        self.n = n
        self.compile_parallelism = max(1, compile_parallelism)
        self._last_block: dict | None = None   # handed from _generate_modelica to _run_hybrid

    @staticmethod
    def requires_block_context(task: BenchmarkTask, condition: AblationCondition) -> bool:
        """Like B0, BoN consumes the raw request: no normalizer, no paired IR block."""
        if is_best_of_n(condition):
            return False
        return PipelineExperimentExecutor.requires_block_context(task, condition)

    # -- the run: B0's compile/export/execute baseline over the selected sample ----
    def _run_hybrid(self, task: BenchmarkTask, condition: AblationCondition,
                    prompt: str, output_dir: Path, *, block_context: dict | None = None) -> dict:
        if not is_best_of_n(condition):
            return super()._run_hybrid(task, condition, prompt, output_dir,
                                       block_context=block_context)
        if task.profile != "capability":
            raise NotImplementedError(
                "best-of-N is defined for the Modelica-only capability profile "
                f"(got profile {task.profile!r})"
            )
        orchestrator = ModelicaCapabilityOrchestrator(
            modelica_pipeline=self.modelica,
            modelica_generator=lambda requirement, generation_dir: self._generate_modelica(
                requirement, condition, generation_dir),
            normalizer=self.normalizer,
        )
        self._last_block = None
        result = orchestrator.run_compiler_execution_baseline(
            prompt,
            output_dir=output_dir,
            task_id=task.id,
            clock=_baseline_execution_clock(task, prompt),
        )
        # Attached before the study-validity scan runs, so an infrastructure diagnostic inside it
        # (below) marks the cell for an identical rerun instead of counting as a model failure.
        if self._last_block is not None:
            result["best_of_n"] = self._last_block
        return result

    # -- the sampler ---------------------------------------------------------------
    def _generate_modelica(self, requirement: str, condition: AblationCondition,
                           output_dir: Path, *,
                           preferred_categories: tuple[str, ...] = ()) -> tuple[str, dict]:
        if not is_best_of_n(condition):
            return super()._generate_modelica(
                requirement, condition, output_dir,
                preferred_categories=preferred_categories)

        system, human = self.modelica.build_baseline_messages(requirement)
        request = f"{system}\n\n{human}"

        # N draws in flight. A transport error on any of them propagates (see module docstring).
        with ThreadPoolExecutor(max_workers=self.n) as pool:
            raws = list(pool.map(lambda _: self.baseline_ask(request), range(self.n)))

        samples: list[dict] = []
        for index, raw in enumerate(raws):
            try:
                code = clean_code(raw)
            except ValueError as exc:       # the model returned no Modelica: a failed candidate
                samples.append({"index": index, "code": "", "result": None, "extraction_error": str(exc)})
                continue
            samples.append({"index": index, "code": code, "result": None, "extraction_error": None})

        if not any(s["code"] for s in samples):
            # B0's clean_code raises here, which the orchestrator records as a
            # `modelica_generation` failure. Keep the failure stage identical.
            raise ValueError(f"generator returned no Modelica code in any of {self.n} samples")

        # Compile every extractable sample with the exact check B0 applies. Each gets its own
        # working directory, so parallel compiles cannot collide.
        def compile_sample(sample: dict) -> dict:
            if sample["code"]:
                sample["result"] = self.modelica.compile(
                    sample["code"], output_dir=output_dir / f"attempt-{sample['index']}")
            return sample

        with ThreadPoolExecutor(max_workers=min(self.compile_parallelism, self.n)) as pool:
            samples = list(pool.map(compile_sample, samples))

        rows = [_row(s) for s in samples]
        # Six compiles per task (some in parallel containers) make a flaky backend likelier than
        # under B0. A candidate the compiler never scored is infrastructure, not a model outcome.
        infrastructure = [
            {"stage": d.stage, "severity": d.severity, "message": d.message, "sample": s["index"]}
            for s in samples if s["result"] is not None and not s["result"].build.available
            for d in s["result"].build.diagnostics if d.stage == "infrastructure"
        ]
        chosen = select_best(rows)
        chosen_sample = samples[chosen["index"]]
        selected: Layer1CandidateResult | None = chosen_sample["result"]

        attempts = []
        for sample, row in zip(samples, rows):
            attempts.append({
                "attempt": sample["index"],
                "accepted_as_best": sample["index"] == chosen["index"],
                "modelica": sample["code"],
                **(sample["result"].to_dict() if sample["result"] is not None else
                   {"passed": False, "quality": None,
                    "build": _extraction_failure_build(sample["extraction_error"]),
                    "extraction_error": sample["extraction_error"]}),
            })
        report = {
            "stage": "layer1",
            "passed": bool(selected is not None and selected.passed),
            "final_modelica": chosen_sample["code"],
            "repairs": 0,
            "corpus_subset": self.modelica.corpus.subset,
            "retrieved_examples": [],
            "attempts": attempts,
            "generation_mode": "direct",
            "generation_model": self.baseline_model,
            "best_of_n": {
                "n": self.n,
                "selection_rule": SELECTION_RULE,
                "selected_index": chosen["index"],
                "n_compiling": sum(bool(r["passed"]) for r in rows),
                "any_compiling": any(r["passed"] for r in rows),
                "n_extraction_failures": sum(r["quality"] is None for r in rows),
                "n_distinct": len({s["code"] for s in samples if s["code"]}),
                "candidates": rows,
                "infrastructure_diagnostics": infrastructure,
            },
        }
        _annotate_generation_report(report, condition, self.k, self.max_tool_repairs)
        self._last_block = report["best_of_n"]
        return report["final_modelica"], report


def _extraction_failure_build(message: str | None) -> dict:
    """Build-shaped record for a sample with no code, in ModelicaBuild.to_dict()'s vocabulary."""
    return {
        "available": True, "model_name": "", "checked": False, "compiled": False,
        "executable": None, "check_message": "", "build_message": "",
        "diagnostics": [{"stage": "source", "severity": "error", "message": message or ""}],
        "duration_seconds": 0.0, "success": False, "error_count": 1,
    }


def _row(sample: dict) -> dict:
    """One candidate's compact compile record (the code itself lives in `attempts`)."""
    result: Layer1CandidateResult | None = sample["result"]
    if result is None:
        return {"index": sample["index"], "passed": False, "quality": None,
                "error_count": None, "extraction_error": sample["extraction_error"]}
    return {
        "index": sample["index"],
        "passed": result.passed,
        "quality": list(result.quality),
        "error_count": result.build.error_count,
        "compiler_available": result.build.available,
        "extraction_error": None,
    }
