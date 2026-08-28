"""Retrieval, generation, validation, and guarded repair for OpenUSD."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
import tempfile

from .corpus import OpenUSDExampleCorpus
from .validator import OpenUSDValidation, OpenUSDValidator


SYSTEM_PROMPT = """You generate one self-contained textual OpenUSD USDA stage
for a robotics requirement. Return USDA only, without markdown or prose. Use
portable OpenUSD and UsdPhysics core schemas. Explicitly author defaultPrim,
metersPerUnit = 1, kilogramsPerUnit = 1, upAxis = Z, and timeCodesPerSecond.
Use primitive geometry or provided asset references, valid prim relationships,
grounded positive masses, grounded collision geometry on dynamic links, and an
articulation root for jointed robots. Never copy numeric values from retrieved
examples; only the requirement and grounded IR are factual sources. Preserve a
component with missing required physical values as an explicitly unresolved
semantic placeholder instead of fabricating dimensions, mass, pose, or physics.
Do not use Isaac-, PhysX-, or simulator-specific schemas unless the requirement
explicitly requests the named extension profile."""


class OpenUSDPipeline:
    def __init__(self, corpus: OpenUSDExampleCorpus | None = None,
                 validator: OpenUSDValidator | None = None):
        self.corpus = corpus or OpenUSDExampleCorpus()
        self.validator = validator or OpenUSDValidator()

    def build_messages(self, requirement: str, *, k: int = 5) -> tuple[str, str, list]:
        hits = self.corpus.retrieve(requirement, k=k)
        human = (
            f"Retrieved examples:\n{self.corpus.format_context(hits)}\n\n"
            "Generate one complete USDA stage for this requirement:\n"
            f"{requirement.strip()}\n"
        )
        return SYSTEM_PROMPT, human, hits

    def build_baseline_messages(self, requirement: str) -> tuple[str, str]:
        return SYSTEM_PROMPT, (
            "Generate one complete USDA stage for this requirement:\n"
            f"{requirement.strip()}\n"
        )

    def generate(self, requirement: str, ask: Callable[[str], str], *,
                 k: int = 5, max_repairs: int = 2,
                 output_dir: Path | None = None) -> dict:
        if not requirement.strip():
            raise ValueError("requirement must be non-empty")
        _, human, hits = self.build_messages(requirement, k=k)
        candidate = clean_usda(ask(f"{SYSTEM_PROMPT}\n\n{human}"))
        return self.refine(
            requirement, candidate, ask, hits=hits,
            max_repairs=max_repairs, output_dir=output_dir,
        )

    def refine(self, requirement: str, candidate: str,
               repair: Callable[[str], str], *, hits: list[tuple] | None = None,
               max_repairs: int = 2,
               output_dir: Path | None = None) -> dict:
        hits = hits if hits is not None else self.corpus.retrieve(requirement, k=5)
        attempts = []
        best_code = ""
        best_validation: OpenUSDValidation | None = None
        best_quality: tuple[int, int, int] | None = None
        for attempt in range(max_repairs + 1):
            attempt_dir = (
                output_dir / f"attempt-{attempt}" if output_dir
                else Path(tempfile.mkdtemp(prefix=f"openusd-attempt-{attempt}-"))
            )
            attempt_dir.mkdir(parents=True, exist_ok=True)
            stage_path = attempt_dir / "candidate.usda"
            stage_path.write_text(candidate, encoding="utf-8")
            validation = self.validator.validate(
                stage_path, output_dir=attempt_dir / "validation"
            )
            quality = (
                int(validation.semantic_valid),
                int(validation.syntax_valid),
                -validation.error_count,
            )
            accepted = best_quality is None or quality > best_quality
            if accepted:
                best_code = candidate
                best_validation = validation
                best_quality = quality
            attempts.append({
                "attempt": attempt,
                "accepted_as_best": accepted,
                "quality": list(quality),
                "openusd": candidate,
                "validation": validation.to_dict(),
            })
            if validation.success or not validation.available or attempt >= max_repairs:
                break
            assert best_validation is not None
            repaired = clean_usda(repair(_repair_prompt(
                requirement, best_code, best_validation
            )))
            if repaired == best_code:
                break
            candidate = repaired
        assert best_validation is not None and best_quality is not None
        return {
            "stage": "openusd_generation",
            "passed": best_validation.success,
            "final_openusd": best_code,
            "repairs": len(attempts) - 1,
            "retrieved_examples": [
                {"id": item.id, "score": score} for item, score in hits
            ],
            "attempts": attempts,
        }


def clean_usda(response: str) -> str:
    text = response.strip()
    if "```" in text:
        blocks = text.split("```")
        text = max(
            (block.removeprefix("usda").removeprefix("usd").strip()
             for block in blocks),
            key=len,
        )
    start = text.find("#usda")
    if start > 0:
        text = text[start:]
    if not text.startswith("#usda"):
        raise ValueError("generator returned no textual USDA stage")
    return text


def _repair_prompt(requirement: str, code: str,
                   validation: OpenUSDValidation) -> str:
    diagnostics = "\n".join(
        f"- [{item.stage}/{item.code}] {item.message}"
        + (f" at {item.prim}" if item.prim else "")
        for item in validation.issues if item.severity == "error"
    ) or "The validator returned no structured error."
    return f"""{SYSTEM_PROMPT}

Repair only the grounded defects listed below. Preserve correct scene content,
component identity, topology, values, and portable semantics. Return the full
USDA stage.

Requirement:
{requirement}

Validator diagnostics:
{diagnostics}

Candidate:
{code}
"""
