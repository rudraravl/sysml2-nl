#!/bin/bash
# Submit ablation arms to SLURM. Run from the repo root.
#
#   bash nl2solidity/ablation/pace/submit_all.sh                 # all six arms
#   bash nl2solidity/ablation/pace/submit_all.sh A1 A2 A3        # just these
#   ABLATION_SHARDS=6 bash ... A1 A2 A3                          # 6 shards each
#   DRY=1 bash ...                                               # print, submit nothing
#
# Each arm is one array job of ABLATION_SHARDS tasks, so `submit_all.sh A2 A3 A4`
# with ABLATION_SHARDS=5 puts 15 tasks in the queue at once. They are fully
# independent: separate output directories per arm, disjoint seeds per shard.
set -euo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
PACE_DIR="$REPO/nl2solidity/ablation/pace"

if [[ ! -d "$PACE_DIR" ]]; then
  echo "FATAL: \$REPO=$REPO is not the sysml2-nl checkout" >&2
  exit 1
fi

ARMS=("$@")
if [[ ${#ARMS[@]} -eq 0 ]]; then
  ARMS=(A0 A1 A2 A3 A4 A5)
fi

SHARDS="${ABLATION_SHARDS:-5}"
if (( SHARDS < 1 || SHARDS > 32 )); then
  echo "FATAL: ABLATION_SHARDS=$SHARDS out of range [1, 32]" >&2
  exit 1
fi

mkdir -p "$REPO/logs"

# Preflight once, not six times: a missing solc or key should stop the whole
# submission, not produce six array jobs that each fail on the first seed.
"$REPO/.venv/bin/python" "$REPO/nl2solidity/ablation/preflight.py" --arms "${ARMS[@]}"

echo
for arm in "${ARMS[@]}"; do
  lower="$(echo "$arm" | tr '[:upper:]' '[:lower:]')"
  script="$PACE_DIR/${lower}.sbatch"
  if [[ ! -f "$script" ]]; then
    echo "FATAL: no sbatch script for arm '$arm' ($script)" >&2
    exit 1
  fi

  cmd=(sbatch --array="1-${SHARDS}%${SHARDS}" "$script")
  if [[ -n "${DRY:-}" ]]; then
    echo "DRY: ABLATION_SHARDS=$SHARDS ${cmd[*]}"
    continue
  fi

  echo -n "$arm ($SHARDS shards): "
  ABLATION_SHARDS="$SHARDS" "${cmd[@]}"
done

if [[ -z "${DRY:-}" ]]; then
  echo
  echo "Submitted ${#ARMS[@]} arm(s) x $SHARDS shards = $(( ${#ARMS[@]} * SHARDS )) tasks."
  echo "Watch:   squeue -u \$USER"
  echo "Progress: bash $PACE_DIR/progress.sh"
fi
