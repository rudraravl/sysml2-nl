#!/bin/bash
#SBATCH --job-name=nl2robotics-articulated
#SBATCH --partition=ghx4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gpus=1
#SBATCH --time=00:30:00
#SBATCH --array=0-2%1
#SBATCH --output=nl2robotics-articulated-%A-%a.out

set -euo pipefail

REPO="${REPO:-$SLURM_SUBMIT_DIR}"
ORACLES=(RHY201 RHY202 RHY203)
INDEX="${SLURM_ARRAY_TASK_ID:?submit this file with sbatch}"
if (( INDEX < 0 || INDEX >= ${#ORACLES[@]} )); then
  echo "invalid articulated study array index: $INDEX" >&2
  exit 2
fi

export ORACLE="${ORACLES[$INDEX]}"
export OUTPUT_ROOT="$REPO/outputs/deltaai-${ORACLE,,}-${SLURM_ARRAY_JOB_ID}-${INDEX}"
bash "$REPO/nl2robotics/hybrid/deltaai/run_rhy201.sbatch"
