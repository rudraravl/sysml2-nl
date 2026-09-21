#!/bin/bash
#SBATCH --job-name=sysml-bo6
#SBATCH --account=gts-CHANGEME              # your PACE charge account
#SBATCH --partition=cpu-small               # adjust to your PACE queue
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G                           # one JVM per in-flight seed
#SBATCH --time=8:00:00
#SBATCH --array=1-5%5                       # 5 disjoint shards; widen with --array=1-8%8 + BON_SHARDS=8
#SBATCH --signal=B:TERM@300                 # SIGTERM 5 min before walltime -> drain
#SBATCH --output=logs/sysml_bo_%A_%a.out
#SBATCH --error=logs/sysml_bo_%A_%a.err
#
# SysML best-of-N sampling baseline (default N=6): N one-shot GLM-5.2 samples per seed, the SysML
# compiler picks one. See nl2sysml/best_of_n_generate.py for the selection rule.
#
# Submit from the repo root:
#     sbatch nl2sysml/pace/best_of_n.sbatch
#     BON_N=4 BON_SHARDS=8 sbatch --array=1-8%8 nl2sysml/pace/best_of_n.sbatch
#
# Shard k takes the sorted seed ids at positions p with p % BON_SHARDS == k, so array tasks are
# disjoint. Rerunning the identical submission resumes: seeds with a meta.json are skipped, and a
# seed killed mid-flight has no meta.json and is simply redone.
#
# Needs: java + the parser jar (sysml2-compiler), OPENROUTER_API_KEY in $REPO/.env, and
# dataset/with_kernel_spec/<ID>/<ID>.txt for the prompts (the same set the naive arm used).
set -uo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
if [[ ! -f "$REPO/nl2sysml/best_of_n_generate.py" ]]; then
  echo "FATAL: \$REPO=$REPO is not the sysml2-nl checkout (submit from the repo root)" >&2
  exit 1
fi
cd "$REPO"
mkdir -p logs

module load python/3.11 2>/dev/null || true
module load openjdk 2>/dev/null || true       # adjust to your PACE Java module
PY="${PY:-$REPO/.venv/bin/python}"
[[ -x "$PY" ]] || { echo "FATAL: no interpreter at $PY" >&2; exit 1; }
command -v java >/dev/null || { echo "FATAL: java not on PATH" >&2; exit 1; }

BON_N="${BON_N:-6}"
BON_SHARDS="${BON_SHARDS:-5}"
BON_WORKERS="${BON_WORKERS:-6}"               # seeds in flight; <= cpus-per-task
SHARD_INDEX=$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))

# Each worker process runs its own JVM; the API gate caps in-flight OpenRouter calls per process.
export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-8}"
export PYTHONUNBUFFERED=1

echo "== sysml best-of-${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} on $(hostname) $(date -u +%FT%TZ) =="

"$PY" nl2sysml/best_of_n_generate.py \
  --n "$BON_N" --workers "$BON_WORKERS" \
  --shards "$BON_SHARDS" --shard "$SHARD_INDEX" ${BON_EXTRA_ARGS:-} &
PID=$!

# SLURM's --signal=B: reaches this shell, not the child. Forward it so python drains in-flight
# seeds instead of being SIGKILLed mid-write, then wait for it to actually finish.
trap 'echo "SIGTERM: forwarding to python, draining"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
# A trapped signal interrupts the first wait while python is still draining; wait again for its
# real status. (Guarded: waiting on an already-reaped PID would return 127 and mask the result.)
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== sysml best-of-${BON_N} shard $((SHARD_INDEX + 1))/${BON_SHARDS} finished status=$status $(date -u +%FT%TZ) =="
exit "$status"
