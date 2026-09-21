#!/bin/bash
#SBATCH --job-name=rob-bon6
#SBATCH --account=gts-CHANGEME
#SBATCH --partition=cpu-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --array=1-16%16
#SBATCH --signal=B:TERM@300
#SBATCH --output=logs/rob_bon_%A_%a.out
#SBATCH --error=logs/rob_bon_%A_%a.err
#
# Modelica best-of-N sampling baseline (default N=6): condition BoN6 = B0 with its one generation
# call fanned out to N, selected by OpenModelica. See nl2robotics/experiments/best_of_n.py.
#
# READ FIRST -- this needs a container runtime the job can reach:
#   * FMU execution runs through `docker run` (modelica/fmu_runtime.py hard-codes it), and
#     OpenModelica uses docker unless MODELICA_BACKEND=local (omc on PATH).
#   * If PACE gives you no docker, this job stops in the runtime preflight, BEFORE any model call,
#     and says which piece is missing. Nothing is spent and nothing is recorded as a model failure.
#
# 1. Freeze the protocol ONCE, before submitting (no model calls, safe on a login node). Array
#    tasks must not race to write study-protocol.json, so this script refuses to start without it:
#
#      python3 -m nl2robotics.experiments.run_best_of_n \
#        --benchmark-manifest nl2robotics/corpus/pipeline_prompt_manifest.json \
#        --profile capability --benchmark-split all --variant rich --repetitions 1 \
#        --randomization-seed 20260830 --support-model z-ai/glm-5.2 --provider openrouter \
#        --baseline-model z-ai/glm-5.2 --modelica-backend docker --modelica-subset full1500 \
#        --max-tool-repairs 2 --shard-count 16 --n 6 \
#        --output-dir outputs/robotics-corpus-bon6 --dry-run
#
# 2. sbatch nl2robotics/experiments/pace/best_of_n.sbatch
#      BON_SHARDS must equal the array width and the --shard-count you froze with.
#      Different width:  BON_SHARDS=8 sbatch --array=1-8%8 ...  (re-freeze with --shard-count 8)
#
# Why 16 shards: cells run sequentially within a shard at ~4-5 min each (the B0 run averaged 246 s),
# so 1560 cells / 16 = ~98 cells ~ 7-8 h. The 4-shard B0 layout would need ~28 h. Results are
# per-cell and independent of the shard count, so pairing with B0 (by task) is unaffected.
#
# Resume: resubmit the identical command; finished cells are skipped, interrupted ones rerun.
# Cells excluded as infrastructure (study_validity.eligible=false) are rerun identically.
#
# Needs: OPENROUTER_API_KEY in $REPO/.env (never in this file), the frozen protocol above.
set -uo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "$REPO"
[[ -f nl2robotics/experiments/run_best_of_n.py ]] || { echo "FATAL: \$REPO=$REPO is not the sysml2-nl checkout" >&2; exit 1; }
mkdir -p logs

module load python/3.11 2>/dev/null || true
PY="${PY:-$REPO/.venv/bin/python}"
[[ -x "$PY" ]] || { echo "FATAL: no interpreter at $PY" >&2; exit 1; }

BON_N="${BON_N:-6}"
BON_SHARDS="${BON_SHARDS:-16}"
BON_OUTPUT_DIR="${BON_OUTPUT_DIR:-$REPO/outputs/robotics-corpus-bon${BON_N}}"
MODELICA_BACKEND="${MODELICA_BACKEND:-docker}"
BON_COMPILE_PARALLELISM="${BON_COMPILE_PARALLELISM:-3}"
SHARD_INDEX=$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))

if [[ ! -f "$BON_OUTPUT_DIR/study-protocol.json" ]]; then
  echo "FATAL: no frozen protocol at $BON_OUTPUT_DIR/study-protocol.json" >&2
  echo "       run the --dry-run freeze command in this script's header first" >&2
  exit 1
fi
if (( SHARD_INDEX >= BON_SHARDS )); then
  echo "FATAL: array task $SLURM_ARRAY_TASK_ID exceeds BON_SHARDS=$BON_SHARDS" >&2
  exit 1
fi

export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-8}"
export PYTHONUNBUFFERED=1

echo "== robotics BoN${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} on $(hostname) $(date -u +%FT%TZ) =="

# Must match the frozen protocol argument for argument; a mismatch fails closed at freeze time.
"$PY" -m nl2robotics.experiments.run_best_of_n \
  --benchmark-manifest nl2robotics/corpus/pipeline_prompt_manifest.json \
  --profile capability --benchmark-split all --variant rich --repetitions 1 \
  --randomization-seed 20260830 \
  --support-model z-ai/glm-5.2 --provider openrouter --baseline-model z-ai/glm-5.2 \
  --modelica-backend "$MODELICA_BACKEND" --modelica-subset full1500 \
  --max-tool-repairs 2 \
  --shard-count "$BON_SHARDS" --shard-index "$SHARD_INDEX" \
  --n "$BON_N" --compile-parallelism "$BON_COMPILE_PARALLELISM" \
  --output-dir "$BON_OUTPUT_DIR" ${BON_EXTRA_ARGS:-} &
PID=$!

# SLURM's --signal=B: reaches this shell, not python. The runner checkpoints every cell, so a
# forwarded TERM at worst loses the one in-flight cell, which reruns on resume.
trap 'echo "SIGTERM: forwarding to python"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== robotics BoN${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} finished status=$status $(date -u +%FT%TZ) =="
exit "$status"
