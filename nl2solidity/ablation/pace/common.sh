#!/bin/bash
# Shared node setup for every ablation sbatch script. Sourced, never executed.
#
# Holds only what is identical across arms: paths, modules, scratch, caches and
# the concurrency budget for one node. Everything that distinguishes one arm from
# another lives in nl2solidity/ablation/profiles.py, so this file can never drift
# an arm out of spec.
set -euo pipefail

# The sbatch that sourced us set REPO from SLURM_SUBMIT_DIR, so there is no
# hard-coded install path to keep in sync.
REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
if [[ ! -f "$REPO/nl2solidity/ablation/run_ablation.py" ]]; then
  echo "FATAL: \$REPO=$REPO is not the sysml2-nl checkout" >&2
  echo "       submit from the repo root, or export REPO=/path/to/sysml2-nl" >&2
  exit 1
fi
cd "$REPO"
mkdir -p logs

module load python/3.11 2>/dev/null || true
export PATH="$HOME/.foundry/bin:$PATH"

PY="${PY:-$REPO/.venv/bin/python}"
if [[ ! -x "$PY" ]]; then
  echo "FATAL: no interpreter at $PY — run nl2solidity/pace/prestage.sh first" >&2
  exit 1
fi

# Node-local scratch for the throwaway Foundry projects: write-heavy, short-lived,
# and murder on a shared filesystem quota.
export TMPDIR="${SLURM_TMPDIR:-/tmp}/nl2sol-abl.${SLURM_JOB_ID:-$$}.${SLURM_ARRAY_TASK_ID:-0}"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# Caches populated by prestage.sh; no network needed for these at runtime.
export NL2SOLIDITY_CACHE="$HOME/.cache/nl2solidity"
export SOLC_AUTO_INSTALL=false          # fail loudly rather than download silently
export FORGE_STD_AUTO_CLONE=false

# Concurrency budget for --cpus-per-task=8. forge is the CPU hog; the API cap
# bounds in-flight OpenRouter calls across every worker thread in THIS task.
export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-8}"
export SOLC_COMPILER_MAX_CONCURRENCY="${SOLC_COMPILER_MAX_CONCURRENCY:-4}"
export SOLIDITY_RUNNER_MAX_CONCURRENCY="${SOLIDITY_RUNNER_MAX_CONCURRENCY:-3}"
export SECURITY_MAX_CONCURRENCY="${SECURITY_MAX_CONCURRENCY:-2}"

# Claims are a second line of defence behind shard partitioning: they only matter
# when a killed task's seeds are picked up by a rerun.
export BATCH_CLAIM_STALE_SEC="${BATCH_CLAIM_STALE_SEC:-900}"
export BATCH_CLAIM_HEARTBEAT_SEC="${BATCH_CLAIM_HEARTBEAT_SEC:-60}"

# 256 fuzz runs per property was the dominant cost in the pilot; 64 keeps this
# affordable. Every arm is fuzzed at the same setting, or the execution numbers
# would not be comparable down the ladder.
export FUZZ_RUNS="${FUZZ_RUNS:-64}"

export PYTHONUNBUFFERED=1

# --- experiment-wide knobs, identical across arms by construction ------------
ABLATION_N="${ABLATION_N:-500}"                 # evaluation set size (seed file holds 1500)
ABLATION_SHARDS="${ABLATION_SHARDS:-5}"         # parallel instances per arm (4-6)
ABLATION_WORKERS="${ABLATION_WORKERS:-4}"       # seeds in flight within one shard
ABLATION_OUTPUT_ROOT="${ABLATION_OUTPUT_ROOT:-$REPO/nl2solidity/dataset/ablation}"
ABLATION_PROMPT_SOURCE="${ABLATION_PROMPT_SOURCE:-seed_long}"
export ABLATION_N ABLATION_SHARDS ABLATION_WORKERS ABLATION_OUTPUT_ROOT ABLATION_PROMPT_SOURCE

# SLURM array tasks are 1-based; shards are 0-based.
SHARD_INDEX=$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))

run_arm() {
  local arm="$1"
  echo "== ${arm} shard $((SHARD_INDEX + 1))/${ABLATION_SHARDS} on $(hostname) =="
  echo "   TMPDIR=$TMPDIR  started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # `|| status=$?` keeps set -e from killing the job before the trailer line,
  # which is what tells you in the log whether a walltime kill or a real error
  # ended the shard.
  local status=0
  "$PY" "$REPO/nl2solidity/ablation/run_ablation.py" \
    --arm "$arm" \
    --shards "$ABLATION_SHARDS" \
    --shard "$SHARD_INDEX" \
    --num-entries "$ABLATION_N" \
    --workers "$ABLATION_WORKERS" \
    --output-root "$ABLATION_OUTPUT_ROOT" \
    --prompt-source "$ABLATION_PROMPT_SOURCE" \
    ${ABLATION_EXTRA_ARGS:-} || status=$?

  echo "== ${arm} shard $((SHARD_INDEX + 1))/${ABLATION_SHARDS} finished status=$status $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
  return $status
}
