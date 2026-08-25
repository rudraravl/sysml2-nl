#!/bin/bash
#SBATCH --job-name=nl2robotics-rhy201
#SBATCH --partition=ghx4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gpus=1
#SBATCH --time=00:30:00
#SBATCH --output=nl2robotics-rhy201-%j.out

set -euo pipefail

REPO="${REPO:-$SLURM_SUBMIT_DIR}"
ORACLE="${ORACLE:-RHY201}"
IMAGE="${IMAGE:-$REPO/openmodelica-v1.27.0-arm64.sif}"
PYTHON_DEPS="${PYTHON_DEPS:-$REPO/.deltaai-python}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$REPO/outputs/deltaai-${ORACLE,,}-$SLURM_JOB_ID}"

test -f "$IMAGE"
test -d "$PYTHON_DEPS"
test -d "$REPO/nl2robotics/hybrid/oracles/$ORACLE"
case "$OUTPUT_ROOT" in
  "$REPO"/*) ;;
  *) echo "OUTPUT_ROOT must be inside REPO" >&2; exit 2 ;;
esac
mkdir -p "$OUTPUT_ROOT" "$OUTPUT_ROOT/warp-cache"

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace:/workspace/${PYTHON_DEPS#"$REPO"/}" \
  --env WARP_CACHE_PATH="/workspace/${OUTPUT_ROOT#"$REPO"/}/warp-cache" \
  "$IMAGE" \
  python3 -m nl2robotics.hybrid.deltaai.preflight \
    --stage "/workspace/nl2robotics/hybrid/oracles/$ORACLE/scene.usda" \
    --output "/workspace/${OUTPUT_ROOT#"$REPO"/}/preflight.json"

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace:/workspace/${PYTHON_DEPS#"$REPO"/}" \
  "$IMAGE" \
  python3 -m nl2robotics.hybrid.newton_prepare \
    --modelica "/workspace/nl2robotics/hybrid/oracles/$ORACLE/model.mo" \
    --usd "/workspace/nl2robotics/hybrid/oracles/$ORACLE/scene.usda" \
    --ir "/workspace/nl2robotics/hybrid/oracles/$ORACLE/requirement_ir.json" \
    --contract "/workspace/nl2robotics/hybrid/oracles/$ORACLE/contract.json" \
    --output-dir "/workspace/${OUTPUT_ROOT#"$REPO"/}/bundle" \
    --modelica-backend local

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace:/workspace/${PYTHON_DEPS#"$REPO"/}" \
  --env WARP_CACHE_PATH="/workspace/${OUTPUT_ROOT#"$REPO"/}/warp-cache" \
  "$IMAGE" \
  python3 -m nl2robotics.hybrid.newton_cli \
    --bundle "/workspace/${OUTPUT_ROOT#"$REPO"/}/bundle/execution-input.json" \
    --output-dir "/workspace/${OUTPUT_ROOT#"$REPO"/}/execution" \
    --controller-backend local \
    --device cuda:0 \
    --solver featherstone \
    --repetitions 3 \
    --repeatability-tolerance 1e-6

echo "DeltaAI evidence: $OUTPUT_ROOT"
