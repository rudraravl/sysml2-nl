#!/bin/bash
#SBATCH --job-name=nl2sol
#SBATCH --account=gts-CHANGEME              # your PACE charge account
#SBATCH --partition=cpu-small               # adjust to your PACE queue
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=8:00:00
#SBATCH --array=1-4%4                       # 4 concurrent workers over one shared output dir
#SBATCH --signal=B:TERM@300                 # SIGTERM 5 min before walltime -> graceful drain
#SBATCH --output=logs/nl2sol_%A_%a.out
#SBATCH --error=logs/nl2sol_%A_%a.err
#
# Async generation on PACE.
#
# Array-safe by design: every task points at the SAME --output-dir and competes
# for entries through the atomic .claim directories in batch_generate.py, so
# tasks never generate the same seed twice. Scale by widening the array, not by
# raising --workers past the node's cores.
#
# Resumable: rerun the identical submission. Completed entries are skipped, and
# claims from a killed task age out after BATCH_CLAIM_STALE_SEC (15 min) because
# the heartbeat thread stops refreshing them.

set -euo pipefail

REPO="${REPO:-$HOME/sysml2-nl-creatix}"
cd "$REPO"
mkdir -p logs

module load python/3.11 2>/dev/null || true
export PATH="$HOME/.foundry/bin:$PATH"

# Node-local scratch for the throwaway Foundry projects: they are write-heavy and
# short-lived, so keeping them off the shared filesystem matters for both speed
# and your file quota.
export TMPDIR="${SLURM_TMPDIR:-/tmp}/nl2sol.$SLURM_JOB_ID.${SLURM_ARRAY_TASK_ID:-0}"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# Caches populated by prestage.sh (no network needed at runtime for these)
export NL2SOLIDITY_CACHE="$HOME/.cache/nl2solidity"
export SOLC_AUTO_INSTALL=false          # fail loudly instead of silently downloading
export FORGE_STD_AUTO_CLONE=false

# Concurrency budget for --cpus-per-task=8. forge is the CPU hog; the API cap
# bounds in-flight OpenRouter calls across all worker threads in THIS task.
export OPENROUTER_MAX_CONCURRENCY=8
export SOLC_COMPILER_MAX_CONCURRENCY=4
export SOLIDITY_RUNNER_MAX_CONCURRENCY=3
export SECURITY_MAX_CONCURRENCY=2
export BATCH_CLAIM_STALE_SEC=900
export BATCH_CLAIM_HEARTBEAT_SEC=60

# Cheaper fuzzing: 256 runs per property test was the dominant cost in the pilot.
export FUZZ_RUNS=64

export PYTHONUNBUFFERED=1

echo "task ${SLURM_ARRAY_TASK_ID:-0} on $(hostname) | TMPDIR=$TMPDIR"
./.venv/bin/python nl2solidity/batch_generate.py \
  --prompt-source seed_long \
  --num-entries 1500 \
  --workers 4 \
  --max-api-concurrency 8 \
  --output-dir "$REPO/nl2solidity/dataset/with_kernel_spec"

echo "task ${SLURM_ARRAY_TASK_ID:-0} finished with status $?"
