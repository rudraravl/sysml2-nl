#!/bin/bash
#SBATCH --job-name=sol-bo6
#SBATCH --account=gts-CHANGEME
#SBATCH --partition=cpu-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --array=1-5%5
#SBATCH --signal=B:TERM@300
#SBATCH --output=logs/sol_bo_%A_%a.out
#SBATCH --error=logs/sol_bo_%A_%a.err
#
# Solidity best-of-N sampling baseline (default N=6): N one-shot samples of arm A0 per seed,
# `solc` picks one, and the winner is then measured exactly as A0..A5 are (Foundry, Slither, spec
# alignment; zero repair passes). See nl2solidity/best_of_n/run_best_of_n.py.
#
# Set --account / --partition above (same values you gave gen_sbatch.py for the ablation arms).
# Submit from the repo root:
#     sbatch nl2solidity/best_of_n/pace/best_of_n.sbatch
#     BON_N=4 sbatch nl2solidity/best_of_n/pace/best_of_n.sbatch
#     ABLATION_SHARDS=6 sbatch --array=1-6%6 nl2solidity/best_of_n/pace/best_of_n.sbatch
#
# Everything shared with the ablation (node setup, solc/forge caches, concurrency budget, FUZZ_RUNS,
# ABLATION_N / ABLATION_SHARDS / prompt source) comes from ablation/pace/common.sh, so the winner is
# measured under identical conditions and the eval set is the same first ABLATION_N seeds.
# ABLATION_SHARDS must equal the array width. Rerun the identical submission to resume: seeds with a
# meta.json are skipped.
#
# Output: nl2solidity/dataset/best_of_n/BoN<N>/U###/

# Each seed fans out to N concurrent samples, so the API gate must admit ABLATION_WORKERS * N calls
# or samples just queue behind it. Set before common.sh, which only supplies defaults.
export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-24}"

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
source "$REPO/nl2solidity/ablation/pace/common.sh"

BON_N="${BON_N:-6}"
BON_OUTPUT_ROOT="${BON_OUTPUT_ROOT:-$REPO/nl2solidity/dataset/best_of_n}"

echo "== solidity best-of-${BON_N} shard $((SHARD_INDEX + 1))/${ABLATION_SHARDS} on $(hostname) =="
echo "   TMPDIR=$TMPDIR  started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$PY" "$REPO/nl2solidity/best_of_n/run_best_of_n.py" \
  --n "$BON_N" \
  --shards "$ABLATION_SHARDS" \
  --shard "$SHARD_INDEX" \
  --num-entries "$ABLATION_N" \
  --workers "$ABLATION_WORKERS" \
  --output-root "$BON_OUTPUT_ROOT" \
  --prompt-source "$ABLATION_PROMPT_SOURCE" \
  ${ABLATION_EXTRA_ARGS:-} &
PID=$!

# SLURM's --signal=B: reaches this shell, not python. Forward it so the generator drains its
# in-flight seeds, then wait for its real exit status.
trap 'echo "SIGTERM: forwarding to python, draining"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== solidity best-of-${BON_N} shard $((SHARD_INDEX + 1))/${ABLATION_SHARDS} finished status=$status $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
exit "$status"
