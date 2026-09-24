#!/bin/bash
#SBATCH --job-name=sol-fsmscg
#SBATCH --account=gts-CHANGEME
#SBATCH --partition=cpu-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=10:00:00
#SBATCH --array=1-15%15
#SBATCH --signal=B:TERM@300
#SBATCH --output=logs/sol_fsmscg_%A_%a.out
#SBATCH --error=logs/sol_fsmscg_%A_%a.err
#
# FSM-SCG* baseline (prompting variant of Luo et al., IJCAI 2025, GLM-5.2 backbone) over all 1500
# seeds of sol_seed.jsonl, the same set as naive_glm and with_kernel_spec. Each array task:
#   1. generates its shard      nl2solidity/fsm_scg/run_fsm_scg.py   (2-6 GLM calls per seed)
#   2. scores the same seeds    nl2solidity/score_naive_glm.py        (measure-only, unchanged)
# so a finished task leaves its 100 seeds ready for analyze_naive_vs_full.py. Independent of the
# Best-of-6 array (best_of_n.sbatch); launch both at once.
#
# Set --account / --partition above. Submit from the repo root:
#     sbatch nl2solidity/fsm_scg/pace/fsm_scg.sbatch                         # all 1500 seeds
#     FSM_SCG_NUM_ENTRIES=500 FSM_SCG_SHARDS=5 sbatch --array=1-5%5 \
#         nl2solidity/fsm_scg/pace/fsm_scg.sbatch                            # the ablation's 500
#     FSM_SCG_SCORE=0 sbatch nl2solidity/fsm_scg/pace/fsm_scg.sbatch         # generation only
#
# FSM_SCG_NUM_ENTRIES=N takes the first N seeds of sol_seed.jsonl in file order, exactly as
# run_ablation.py --num-entries does (ABLATION_N=500 in common.sh), and shards them the same way.
#
# FSM_SCG_SHARDS must equal the array width. Rerun the identical submission to resume: generation
# skips seeds whose meta.json has a `validation` block, scoring skips seeds with a `scoring` block,
# and seeds that failed for provider reasons were never written, so they are redone.
#
# Sizing (20-seed pilot: 4.5 GLM calls, ~25k tokens, ~$0.06 and 93 s mean / 55 s median per seed
# for generation, one 518 s outlier from provider timeouts; scoring ~60-150 s per seed):
# 100 seeds / 4 workers is ~40 min of generation and ~40-60 min of scoring per task. 10 h is
# headroom for rate limiting when this runs alongside the Best-of-6 array.
#
# Output: nl2solidity/dataset/fsm_scg/U###/

# naive_glm and with_kernel_spec were both fuzzed at 256 runs (execution.fuzz_runs in every
# meta.json). common.sh defaults to the ablation's 64, which would make the fuzz and property tiers
# easier for this arm than for the arms it is paired with. Set before common.sh.
export FUZZ_RUNS="${FUZZ_RUNS:-256}"

FSM_SCG_NUM_ENTRIES="${FSM_SCG_NUM_ENTRIES:-1500}"
FSM_SCG_SHARDS="${FSM_SCG_SHARDS:-15}"
FSM_SCG_WORKERS="${FSM_SCG_WORKERS:-4}"
FSM_SCG_SCORE="${FSM_SCG_SCORE:-1}"
# common.sh reads the ABLATION_* names for its shard bookkeeping; feed it ours.
export ABLATION_SHARDS="$FSM_SCG_SHARDS" ABLATION_WORKERS="$FSM_SCG_WORKERS"

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
source "$REPO/nl2solidity/ablation/pace/common.sh"

FSM_SCG_OUTPUT_DIR="${FSM_SCG_OUTPUT_DIR:-$REPO/nl2solidity/dataset/fsm_scg}"
TAG="fsm-scg shard $((SHARD_INDEX + 1))/${FSM_SCG_SHARDS} (first ${FSM_SCG_NUM_ENTRIES} seeds)"

"$PY" -c "import networkx, json_repair" || {
  echo "FATAL: networkx / json_repair missing: $PY -m pip install -r requirements.txt" >&2; exit 1; }

echo "== $TAG on $(hostname) =="
echo "   FUZZ_RUNS=$FUZZ_RUNS  TMPDIR=$TMPDIR  started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# SLURM's --signal=B: reaches this shell, not python. Forward it so the running step drains.
PID=""
trap 'echo "SIGTERM: forwarding to python, draining"; [[ -n "$PID" ]] && kill -TERM "$PID" 2>/dev/null' TERM
step() {  # run "$@" in the background so the trap can forward TERM; return its real status
  "$@" &
  PID=$!
  local s=0
  wait "$PID" || s=$?
  if kill -0 "$PID" 2>/dev/null; then s=0; wait "$PID" || s=$?; fi
  PID=""
  return $s
}

gen=0
step "$PY" "$REPO/nl2solidity/fsm_scg/run_fsm_scg.py" \
  --shards "$FSM_SCG_SHARDS" --shard "$SHARD_INDEX" --num-entries "$FSM_SCG_NUM_ENTRIES" \
  --workers "$FSM_SCG_WORKERS" --output-dir "$FSM_SCG_OUTPUT_DIR" \
  ${FSM_SCG_EXTRA_ARGS:-} || gen=$?
echo "== $TAG generation status=$gen $(date -u +%Y-%m-%dT%H:%M:%SZ) =="

score=0
if [[ "$FSM_SCG_SCORE" == "1" ]]; then
  # Score whatever this shard has generated, even if some seeds failed: they are simply absent.
  IDS=$("$PY" "$REPO/nl2solidity/fsm_scg/run_fsm_scg.py" --shards "$FSM_SCG_SHARDS" \
        --shard "$SHARD_INDEX" --num-entries "$FSM_SCG_NUM_ENTRIES" --print-ids | tail -n 1)
  step "$PY" "$REPO/nl2solidity/score_naive_glm.py" \
    --naive-dir "$FSM_SCG_OUTPUT_DIR" --workers "$FSM_SCG_WORKERS" --ids $IDS || score=$?
  echo "== $TAG scoring status=$score $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
fi

status=$(( gen != 0 ? gen : score ))
echo "== $TAG finished status=$status $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
exit "$status"
