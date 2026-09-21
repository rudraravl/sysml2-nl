"""Run the Modelica best-of-N baseline: `run_cli` with B0's one generation call fanned out to N.

A thin wrapper. Everything except the executor and the condition is `run_cli` unchanged: the
manifest and task selection, the randomization seed and shard assignment, the protocol freeze, the
runtime/LLM preflights, resume, and the per-cell `run.json`. Give it the SAME task-selection
arguments as your B0 run and the two conditions pair cell for cell, on the same shard assignment
(the assignment depends on tasks and seed, not on the condition).

Wrapper-only options (everything else is forwarded to run_cli; `--help` shows those):
    --n N                   samples per task (default 6)
    --compile-parallelism K OpenModelica containers per task at once (default 3; results do not
                            depend on it, only wall time and memory)

Do not pass --condition: it is BoN<N> by construction.

Example (mirrors the B0 corpus run in nl2robotics/corpus/README.md; freeze first with --dry-run):
    python3 -m nl2robotics.experiments.run_best_of_n \\
      --benchmark-manifest nl2robotics/corpus/pipeline_prompt_manifest.json \\
      --profile capability --benchmark-split all --variant rich \\
      --repetitions 1 --randomization-seed 20260830 \\
      --support-model z-ai/glm-5.2 --provider openrouter --baseline-model z-ai/glm-5.2 \\
      --modelica-backend docker --modelica-subset full1500 --max-tool-repairs 2 \\
      --shard-count 4 --shard-index 0 --output-dir outputs/robotics-corpus-bon6 --n 6

Analyse against B0 or FULL with the existing paired script, pointing --naive-condition at BoN<N>:
    python nl2robotics/modelica/analyze_naive_vs_full.py \\
      --naive-root outputs/robotics-corpus-bon6 --naive-condition BoN6 \\
      --full-root  nl2robotics/robotics-corpus-full-v1
"""

from __future__ import annotations

import argparse
from functools import partial
import sys

from . import run_cli
from .best_of_n import DEFAULT_N, BestOfNExecutor, best_of_n_condition
from .conditions import CONDITIONS


def main(argv: list[str] | None = None) -> None:
    wrapper = argparse.ArgumentParser(add_help=False)
    wrapper.add_argument("--n", type=int, default=DEFAULT_N)
    wrapper.add_argument("--compile-parallelism", type=int, default=3)
    own, forwarded = wrapper.parse_known_args(sys.argv[1:] if argv is None else argv)

    if own.n < 1:
        raise SystemExit("--n must be >= 1")
    if any(a == "--condition" or a.startswith("--condition=") for a in forwarded):
        raise SystemExit("--condition is fixed to BoN<N> by this wrapper; drop it")
    if any(a in ("-h", "--help") for a in forwarded):
        print(__doc__)

    condition = best_of_n_condition(own.n)
    # run_cli resolves --condition through the module-level table and builds its executor by name,
    # so registering the condition and swapping the executor class is all the wiring needed.
    CONDITIONS[condition.id] = condition
    run_cli.PipelineExperimentExecutor = partial(
        BestOfNExecutor, n=own.n, compile_parallelism=own.compile_parallelism)
    if not any(a == "--profile" or a.startswith("--profile=") for a in forwarded):
        forwarded += ["--profile", "capability"]

    sys.argv = [sys.argv[0], *forwarded, "--condition", condition.id]
    run_cli.main()


if __name__ == "__main__":
    main()
