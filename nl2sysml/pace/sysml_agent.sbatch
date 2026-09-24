#!/bin/bash
#SBATCH --job-name=sysml-agent
#SBATCH --account=gts-CHANGEME              # your PACE charge account
#SBATCH --partition=cpu-small               # adjust to your PACE queue
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G                           # one JVM + one ANTLR parser per in-flight seed
#SBATCH --time=8:00:00
#SBATCH --array=1-5%5                       # 5 disjoint shards; widen with --array=1-8%8 + SA_SHARDS=8
#SBATCH --signal=B:TERM@300                 # SIGTERM 5 min before walltime -> drain
#SBATCH --output=logs/sysml_agent_%A_%a.out
#SBATCH --error=logs/sysml_agent_%A_%a.err
#
# SysMLAgent baseline (Cibrian et al. 2025, reimplemented): retrieval + generation + ANTLR
# validation + up to 6 fix rounds per seed, GLM-5.2 at T=0.2. See nl2sysml/sysml_agent/.
#
# Submit from the repo root:
#     sbatch nl2sysml/pace/sysml_agent.sbatch
#     SA_SHARDS=8 sbatch --array=1-8%8 nl2sysml/pace/sysml_agent.sbatch
#     SA_EXTRA_ARGS="--model openai/gpt-4o-mini --out-dir dataset/sysml_agent_4omini" \
#         sbatch nl2sysml/pace/sysml_agent.sbatch           # optional as-published arm
#
# Shard k takes the sorted seed ids at positions p with p % SA_SHARDS == k, so array tasks are
# disjoint. Rerunning the identical submission resumes: a seed is done once its meta.json has a
# `sysml_agent` block; a seed killed mid-flight, or one that hit a provider error, has none and is
# simply redone. When every shard is done, build the iter-0 / iter-1 corpora (login node is fine):
#     .venv/bin/python nl2sysml/sysml_agent/materialize.py
#
# Needs: java + the parser jar (sysml2-compiler) for the per-snapshot compile, OPENROUTER_API_KEY in
# $REPO/.env, dataset/with_kernel_spec/<ID>/<ID>.txt, dataset/data/0000*/ (retrieval database), and
# in the venv: antlr4-python3-runtime==4.13.2, numpy, python-dotenv. The ANTLR parser, the
# std-library symbol table and all query/database embeddings are committed under
# nl2sysml/sysml_agent/, so nodes need neither torch nor the Hugging Face hub nor a Pilot checkout.
set -uo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
if [[ ! -f "$REPO/nl2sysml/sysml_agent/run_sysml_agent.py" ]]; then
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
"$PY" -c "import antlr4, numpy" || { echo "FATAL: pip install antlr4-python3-runtime==4.13.2 numpy" >&2; exit 1; }

SA_SHARDS="${SA_SHARDS:-5}"
SA_WORKERS="${SA_WORKERS:-8}"                 # seeds in flight; each is one sequential conversation
SHARD_INDEX=$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))

export OPENROUTER_MAX_CONCURRENCY="${OPENROUTER_MAX_CONCURRENCY:-8}"
export PYTHONUNBUFFERED=1
export HF_HUB_OFFLINE=1                       # query embeddings are precomputed; never download

echo "== sysml-agent shard $((SHARD_INDEX + 1))/${SA_SHARDS} on $(hostname) $(date -u +%FT%TZ) =="

"$PY" nl2sysml/sysml_agent/run_sysml_agent.py \
  --workers "$SA_WORKERS" --shards "$SA_SHARDS" --shard "$SHARD_INDEX" ${SA_EXTRA_ARGS:-} &
PID=$!

# SLURM's --signal=B: reaches this shell, not the child. Forward it so python drains in-flight
# seeds instead of being SIGKILLed mid-write, then wait for it to actually finish.
trap 'echo "SIGTERM: forwarding to python, draining"; kill -TERM "$PID" 2>/dev/null' TERM
status=0
wait "$PID" || status=$?
if kill -0 "$PID" 2>/dev/null; then status=0; wait "$PID" || status=$?; fi

echo "== sysml-agent shard $((SHARD_INDEX + 1))/${SA_SHARDS} finished status=$status $(date -u +%FT%TZ) =="
exit "$status"
