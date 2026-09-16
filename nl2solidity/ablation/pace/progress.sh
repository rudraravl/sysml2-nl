#!/bin/bash
# Where every arm stands. Safe to run while jobs are in flight.
#
#   bash nl2solidity/ablation/pace/progress.sh
#   watch -n 60 bash nl2solidity/ablation/pace/progress.sh
set -euo pipefail

REPO="${REPO:-${SLURM_SUBMIT_DIR:-$PWD}}"
ROOT="${ABLATION_OUTPUT_ROOT:-$REPO/nl2solidity/dataset/ablation}"
N="${ABLATION_N:-500}"

printf '%-4s %7s %7s %8s %8s  %s\n' arm done inflight errors valid output
printf -- '---------------------------------------------------------------\n'

for arm in A0 A1 A2 A3 A4 A5; do
  dir="$ROOT/$arm"
  if [[ ! -d "$dir" ]]; then
    printf '%-4s %7s %7s %8s %8s  %s\n' "$arm" - - - - "(not started)"
    continue
  fi
  # A seed is done when it has a meta.json; in flight when it holds a .claim.
  done_n=$(find "$dir" -mindepth 2 -maxdepth 2 -name meta.json 2>/dev/null | wc -l | tr -d ' ')
  claim_n=$(find "$dir" -mindepth 2 -maxdepth 2 -name .claim -type d 2>/dev/null | wc -l | tr -d ' ')
  err_n=$(find "$dir" -maxdepth 1 -name '*_error.log' 2>/dev/null | wc -l | tr -d ' ')
  valid_n=$(grep -l '"is_valid": true' "$dir"/*/meta.json 2>/dev/null | wc -l | tr -d ' ')
  printf '%-4s %4s/%-3s %7s %8s %8s  %s\n' \
    "$arm" "$done_n" "$N" "$claim_n" "$err_n" "$valid_n" "$dir"
done

echo
echo "queue:"
squeue -u "$USER" -o '%.18i %.12j %.8T %.10M %.6D %R' 2>/dev/null || echo "  (squeue unavailable)"
