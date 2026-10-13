#!/bin/bash
#SBATCH --job-name=mod-title
#SBATCH --account=gts-CHANGEME
#SBATCH --partition=cpu-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --array=1-8%8
#SBATCH --signal=B:TERM@300
#SBATCH --output=logs/mod_title_%A_%a.out
#SBATCH --error=logs/mod_title_%A_%a.err
#
# Modelica title arms: A0, compiler repair with no retrieval, content-free
# repair, and a 3-draw resample. No new SysML or Solidity generation.
#
# Submit from the repo root after the account below is a real PACE account
# and MODELICA_BACKEND is reachable on the compute node (local omc, or docker).
#
#   sbatch ecir2027/pace/modelica_title_arms.sbatch
#
# Resume: resubmit the same script. Finished requirements are skipped.
set -uo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "$REPO"
[[ -f ecir2027/modelica_title_arms.py ]] || { echo "FATAL: \$REPO=$REPO is not the checkout" >&2; exit 1; }
mkdir -p logs

module load python/3.11 2>/dev/null || true
PY="${PY:-$REPO/.venv/bin/python}"
[[ -x "$PY" ]] || { echo "FATAL: no interpreter at $PY" >&2; exit 1; }

SHARDS="${TITLE_SHARDS:-8}"
SHARD_INDEX=$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))
WORKERS="${TITLE_WORKERS:-2}"
export MODELICA_BACKEND="${MODELICA_BACKEND:-local}"
export PYTHONUNBUFFERED=1

if (( SHARD_INDEX >= SHARDS )); then
  echo "FATAL: array task $SLURM_ARRAY_TASK_ID exceeds TITLE_SHARDS=$SHARDS" >&2
  exit 1
fi

echo "== modelica title arms shard $((SHARD_INDEX + 1))/${SHARDS} backend=$MODELICA_BACKEND on $(hostname) $(date -u +%FT%TZ) =="

"$PY" ecir2027/modelica_title_arms.py \
  --execute \
  --shard "$SHARD_INDEX" \
  --shards "$SHARDS" \
  --workers "$WORKERS" &
PID=$!
trap 'echo "SIGTERM: forwarding to python"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== modelica title arms shard $((SHARD_INDEX + 1))/${SHARDS} finished status=$status $(date -u +%FT%TZ) =="
exit "$status"
