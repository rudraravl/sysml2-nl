#!/usr/bin/env python3
"""Ablation arms for the nl2solidity study: the single source of truth.

Every arm is the same generator (`batch_generate.py` -> `generate_solidity_moe`)
with stages switched off by environment variable, so the only thing that differs
between two arms is the stage named in `adds`. Nothing about an arm lives in a
shell script; the sbatch files call `run_ablation.py --arm A3` and this module
decides what that means.

The ladder is monotone - each arm is the one above it plus exactly one stage:

    A0  one-shot GLM-5.2               bare requirement -> one model call
    A1  + RAG                          retrieval-augmented prompt
    A2  + MoE                          4 experts -> combiner synthesis
    A3  + compiler-guided repair       solc errors fed back (<=2 passes)
    A4  + execution-guided repair      Foundry fuzz/property failures fed back
    A5  + security + spec alignment    Slither and the twin-blind aligner

Measurement vs. repair
----------------------
A stage that is off for an arm is off as *feedback*, never as *measurement*.
Every `_refine_*` helper in agent_rag_moe.py runs its checker once even at zero
repair iterations, so an arm that cannot repair against Foundry is still scored
by it.

This is the default (`measure_all=True`) and it is what makes the study a
comparison: all six arms carry compile validity, Foundry fuzz + property results,
Slither findings and spec-alignment similarity, so any metric can be read down
the whole ladder. A2 is measured by Foundry, Slither and the aligner while being
repaired by none of them.

`measure_all=False` is the cheap mode: each arm records only the metrics its own
stages produce. It runs A0-A3 far faster and is useful for a smoke test, but the
only metric all six arms then share is compile validity.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from typing import Dict, List

# Stage defaults shared by every arm. Individual arms only state their deltas,
# which is what keeps the ladder auditable at a glance.
_BASE: Dict[str, str] = {
    "LLM_BACKEND": "api",
    "RAG_ENABLED": "false",
    "MOE_ENABLED": "false",
    "COMPILER_FEEDBACK_ENABLED": "false",
    "KERNEL_FEEDBACK_ENABLED": "false",
    "PROPERTY_TESTS_ENABLED": "false",
    "SECURITY_ANALYSIS_ENABLED": "false",
    "SPEC_ALIGNMENT_ENABLED": "false",
    # Repair budgets. These only bite once the matching stage is enabled.
    "MAX_REFINEMENT_ITERATIONS": "2",
    "MAX_KERNEL_REFINEMENT_ITERATIONS": "2",
    "MAX_SECURITY_REFINEMENT_ITERATIONS": "1",
    "SPEC_ALIGNMENT_MAX_REPAIRS": "1",
}

# How to switch a checker on for measurement only: enable the stage, spend zero
# repair passes on it. Keyed by stage rather than by variable, because a stage's
# flag and its repair budget have to move together - forcing the budget to 0 on a
# stage the arm actually owns would quietly delete the thing being ablated.
_MEASURE_ONLY_STAGES: Dict[str, Dict[str, str]] = {
    "COMPILER_FEEDBACK_ENABLED": {
        "COMPILER_FEEDBACK_ENABLED": "true",
        "MAX_REFINEMENT_ITERATIONS": "0",
    },
    "KERNEL_FEEDBACK_ENABLED": {
        "KERNEL_FEEDBACK_ENABLED": "true",
        "PROPERTY_TESTS_ENABLED": "true",
        "MAX_KERNEL_REFINEMENT_ITERATIONS": "0",
    },
    "SECURITY_ANALYSIS_ENABLED": {
        "SECURITY_ANALYSIS_ENABLED": "true",
        "MAX_SECURITY_REFINEMENT_ITERATIONS": "0",
    },
    "SPEC_ALIGNMENT_ENABLED": {
        "SPEC_ALIGNMENT_ENABLED": "true",
        "SPEC_ALIGNMENT_MAX_REPAIRS": "0",
    },
}


class Arm:
    """One rung of the ablation ladder."""

    def __init__(self, arm_id: str, title: str, adds: str, env: Dict[str, str],
                 hours: int):
        self.id = arm_id
        self.title = title
        self.adds = adds
        self.env = env
        # SLURM walltime, sized for the default measure-all mode: every arm pays
        # for the full checker suite, so the arms differ only by their repair and
        # expert calls and the spread is much narrower than the stage list suggests.
        self.hours = hours

    def resolved_env(self, measure_all: bool = True) -> Dict[str, str]:
        """Full environment for this arm, base defaults included."""
        env = dict(_BASE)
        env.update(self.env)
        if measure_all:
            # Re-enable every checker the arm left off, at zero repair passes.
            # RAG and MoE are generation stages, not checkers, so they are never
            # touched here - measure-all changes what is observed, not what is
            # generated.
            for stage, overrides in _MEASURE_ONLY_STAGES.items():
                if self.env.get(stage) == "true":
                    continue        # the arm owns this stage; keep its budget
                env.update(overrides)
            env["ABLATION_MEASURE_ALL"] = "1"
        env["ABLATION_ID"] = self.id
        return env


ARMS: Dict[str, Arm] = {
    "A0": Arm(
        "A0", "one-shot GLM-5.2", "baseline: no retrieval, no experts, no repair",
        {},
        hours=10,
    ),
    "A1": Arm(
        "A1", "GLM-5.2 + RAG", "retrieval of dataset exemplars and Solidity spec chunks",
        {"RAG_ENABLED": "true"},
        hours=10,
    ),
    "A2": Arm(
        "A2", "RAG + MoE", "4 parallel experts synthesised by the combiner",
        {"RAG_ENABLED": "true", "MOE_ENABLED": "true"},
        hours=12,
    ),
    "A3": Arm(
        "A3", "RAG + MoE + compiler repair", "solc diagnostics fed back to the combiner",
        {"RAG_ENABLED": "true", "MOE_ENABLED": "true",
         "COMPILER_FEEDBACK_ENABLED": "true"},
        hours=12,
    ),
    "A4": Arm(
        "A4", "A3 + execution repair", "Foundry fuzz + requirement-derived property failures fed back",
        {"RAG_ENABLED": "true", "MOE_ENABLED": "true",
         "COMPILER_FEEDBACK_ENABLED": "true",
         "KERNEL_FEEDBACK_ENABLED": "true", "PROPERTY_TESTS_ENABLED": "true"},
        hours=16,
    ),
    "A5": Arm(
        "A5", "full pipeline", "Slither static analysis + twin-blind spec alignment",
        {"RAG_ENABLED": "true", "MOE_ENABLED": "true",
         "COMPILER_FEEDBACK_ENABLED": "true",
         "KERNEL_FEEDBACK_ENABLED": "true", "PROPERTY_TESTS_ENABLED": "true",
         "SECURITY_ANALYSIS_ENABLED": "true", "SPEC_ALIGNMENT_ENABLED": "true"},
        hours=16,
    ),
}

ARM_IDS: List[str] = sorted(ARMS)


def get(arm_id: str) -> Arm:
    key = (arm_id or "").strip().upper()
    if key not in ARMS:
        raise KeyError(f"unknown ablation arm {arm_id!r}; expected one of {', '.join(ARM_IDS)}")
    return ARMS[key]


# Flags that *define* an arm. These are forced onto the environment even if the
# caller exported something else, because an arm that silently runs a stage it is
# supposed to be missing invalidates the comparison rather than merely tuning it.
_IDENTITY_KEYS = frozenset({
    "ABLATION_ID",
    "RAG_ENABLED",
    "MOE_ENABLED",
    "COMPILER_FEEDBACK_ENABLED",
    "KERNEL_FEEDBACK_ENABLED",
    "PROPERTY_TESTS_ENABLED",
    "SECURITY_ANALYSIS_ENABLED",
    "SPEC_ALIGNMENT_ENABLED",
})


def apply(arm_id: str, measure_all: bool = True) -> Dict[str, str]:
    """Set this arm's stage flags on os.environ and return what took effect.

    Stage on/off flags (`_IDENTITY_KEYS`) are forced. Everything else - repair
    budgets, walltime-shaped tuning - yields to a value already exported, so a
    sweep can lower FUZZ_RUNS or MAX_REFINEMENT_ITERATIONS from the sbatch file
    without forking a profile.

    Must be called before agent_rag_moe is imported: a few of its stage switches
    are module-level constants read once at import.
    """
    env = get(arm_id).resolved_env(measure_all)
    applied = {}
    for key, value in env.items():
        if key not in _IDENTITY_KEYS and key in os.environ:
            applied[key] = os.environ[key]
            continue
        os.environ[key] = value
        applied[key] = value
    return applied


def _main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("arm", nargs="?", help=f"one of {', '.join(ARM_IDS)}")
    parser.add_argument("--no-measure-all", dest="measure_all",
                        action="store_false", default=True,
                        help="cheap mode: record only the metrics each arm's own stages produce")
    parser.add_argument("--format", choices=("table", "sh", "json"), default="table",
                        help="table (default), sh (eval-able exports), or json")
    args = parser.parse_args()

    if not args.arm:
        print(f"{'arm':<5} {'title':<32} adds")
        print("-" * 78)
        for arm_id in ARM_IDS:
            arm = ARMS[arm_id]
            print(f"{arm.id:<5} {arm.title:<32} {arm.adds}")
        return 0

    try:
        arm = get(args.arm)
    except KeyError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    env = arm.resolved_env(args.measure_all)
    if args.format == "sh":
        for key, value in sorted(env.items()):
            print(f"export {key}={shlex.quote(value)}")
    elif args.format == "json":
        print(json.dumps(env, indent=2, sort_keys=True))
    else:
        print(f"{arm.id}: {arm.title}")
        print(f"  adds: {arm.adds}")
        print(f"  walltime: {arm.hours}h")
        for key, value in sorted(env.items()):
            print(f"  {key}={value}")
    return 0


if __name__ == "__main__":
    sys.exit(_main())
