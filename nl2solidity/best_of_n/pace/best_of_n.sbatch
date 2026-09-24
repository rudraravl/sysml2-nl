#!/bin/bash
#SBATCH --job-name=sol-bon6
#SBATCH --account=gts-CHANGEME
#SBATCH --partition=cpu-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --array=1-15%15
#SBATCH --signal=B:TERM@300
#SBATCH --output=logs/sol_bon_%A_%a.out
#SBATCH --error=logs/sol_bon_%A_%a.err
#
# Solidity best-of-N sampling baseline (default N=6), a REPLACEMENT for the naive GLM data over all
# 1500 seeds: N samples of naive_glm_generate.py's call per seed, `solc` picks one, and the winner is
# measured like the other corpora (Foundry, Slither, spec alignment; zero repair passes).
# Not part of the ablation ladder. See nl2solidity/best_of_n/run_best_of_n.py.
#
# Set --account / --partition above. Submit from the repo root:
#     sbatch nl2solidity/best_of_n/pace/best_of_n.sbatch
#     BON_N=4 sbatch nl2solidity/best_of_n/pace/best_of_n.sbatch
#     BON_SHARDS=30 sbatch --array=1-30%30 nl2solidity/best_of_n/pace/best_of_n.sbatch
#
# Sizing: 1500 seeds / 15 shards = 100 seeds per shard, which is what the ablation's 10 h A0 budget
# was sized for; 12 h leaves headroom for the N-way fan-out. Fewer shards need proportionally more
# walltime. BON_SHARDS must equal the array width. Rerun the identical submission to resume: seeds
# with a meta.json are skipped.
#
# Only the node setup (solc/forge caches, TMPDIR, concurrency budget, FUZZ_RUNS) is borrowed from
# ablation/pace/common.sh; everything about the run itself is set by the BON_* variables here.
#
# Output: nl2solidity/dataset/best_of_n/BoN<N>/U###/

# Each seed fans out to N concurrent samples, so the API gate must admit BON_WORKERS * N calls
# or samples just queue behind it. Set before common.sh, which only supplies defaults.
export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-24}"

BON_N="${BON_N:-6}"
BON_SHARDS="${BON_SHARDS:-15}"
BON_NUM_ENTRIES="${BON_NUM_ENTRIES:-1500}"
BON_WORKERS="${BON_WORKERS:-4}"
# common.sh reads the ABLATION_* names for its shard bookkeeping; feed it ours.
export ABLATION_SHARDS="$BON_SHARDS" ABLATION_WORKERS="$BON_WORKERS"

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
source "$REPO/nl2solidity/ablation/pace/common.sh"

BON_OUTPUT_ROOT="${BON_OUTPUT_ROOT:-$REPO/nl2solidity/dataset/best_of_n}"

echo "== solidity best-of-${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} on $(hostname) =="
echo "   TMPDIR=$TMPDIR  started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$PY" "$REPO/nl2solidity/best_of_n/run_best_of_n.py" \
  --n "$BON_N" \
  --shards "$BON_SHARDS" \
  --shard "$SHARD_INDEX" \
  --num-entries "$BON_NUM_ENTRIES" \
  --workers "$BON_WORKERS" \
  --output-root "$BON_OUTPUT_ROOT" \
  ${BON_EXTRA_ARGS:-} &
PID=$!

# SLURM's --signal=B: reaches this shell, not python. Forward it so the generator drains its
# in-flight seeds, then wait for its real exit status.
trap 'echo "SIGTERM: forwarding to python, draining"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== solidity best-of-${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} finished status=$status $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
exit "$status"
