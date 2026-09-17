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
PYTHON_ENV="${PYTHON_ENV:-${PYTHON_DEPS:-$REPO/.deltaai-python}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$REPO/outputs/deltaai-${ORACLE,,}-$SLURM_JOB_ID}"
CONTAINER_PYTHON="/workspace/${PYTHON_ENV#"$REPO"/}/bin/python"

test -f "$IMAGE"
test -x "$PYTHON_ENV/bin/python"
test -d "$REPO/nl2robotics/hybrid/oracles/$ORACLE"
case "$OUTPUT_ROOT" in
  "$REPO"/*) ;;
  *) echo "OUTPUT_ROOT must be inside REPO" >&2; exit 2 ;;
esac
mkdir -p "$OUTPUT_ROOT" "$OUTPUT_ROOT/warp-cache"

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace" \
  --env PYTHONNOUSERSITE=1 \
  --env WARP_CACHE_PATH="/workspace/${OUTPUT_ROOT#"$REPO"/}/warp-cache" \
  "$IMAGE" \
  "$CONTAINER_PYTHON" -m nl2robotics.hybrid.deltaai.preflight \
    --stage "/workspace/nl2robotics/hybrid/oracles/$ORACLE/scene.usda" \
    --output "/workspace/${OUTPUT_ROOT#"$REPO"/}/preflight.json"

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace" \
  --env PYTHONNOUSERSITE=1 \
  "$IMAGE" \
  "$CONTAINER_PYTHON" -m nl2robotics.hybrid.newton_prepare \
    --modelica "/workspace/nl2robotics/hybrid/oracles/$ORACLE/model.mo" \
    --usd "/workspace/nl2robotics/hybrid/oracles/$ORACLE/scene.usda" \
    --ir "/workspace/nl2robotics/hybrid/oracles/$ORACLE/requirement_ir.json" \
    --contract "/workspace/nl2robotics/hybrid/oracles/$ORACLE/contract.json" \
    --output-dir "/workspace/${OUTPUT_ROOT#"$REPO"/}/bundle" \
    --modelica-backend local

GPU_SAMPLES="$OUTPUT_ROOT/gpu-memory-samples.csv"
GPU_MONITOR_STDERR="$OUTPUT_ROOT/gpu-memory-monitor.stderr"
GPU_MONITOR_PID=""

stop_gpu_monitor() {
  if [[ -n "$GPU_MONITOR_PID" ]] && kill -0 "$GPU_MONITOR_PID" 2>/dev/null; then
    kill "$GPU_MONITOR_PID" 2>/dev/null || true
    wait "$GPU_MONITOR_PID" 2>/dev/null || true
  fi
  GPU_MONITOR_PID=""
}
trap stop_gpu_monitor EXIT

nvidia-smi \
  --query-gpu=timestamp,index,uuid,name,memory.total,memory.used,utilization.gpu \
  --format=csv,noheader,nounits \
  --loop-ms=200 >"$GPU_SAMPLES" 2>"$GPU_MONITOR_STDERR" &
GPU_MONITOR_PID=$!

apptainer exec --cleanenv --nv \
  --bind "$REPO:/workspace" \
  --env PYTHONPATH="/workspace" \
  --env PYTHONNOUSERSITE=1 \
  --env WARP_CACHE_PATH="/workspace/${OUTPUT_ROOT#"$REPO"/}/warp-cache" \
  "$IMAGE" \
  "$CONTAINER_PYTHON" -m nl2robotics.hybrid.newton_cli \
    --bundle "/workspace/${OUTPUT_ROOT#"$REPO"/}/bundle/execution-input.json" \
    --output-dir "/workspace/${OUTPUT_ROOT#"$REPO"/}/execution" \
    --controller-backend local \
    --device cuda:0 \
    --solver featherstone \
    --repetitions 3 \
    --repeatability-tolerance 1e-6

stop_gpu_monitor
trap - EXIT
PYTHONPATH="$REPO" "$PYTHON_ENV/bin/python" \
  -m nl2robotics.hybrid.deltaai.gpu_profile \
  --samples "$GPU_SAMPLES" \
  --output "$OUTPUT_ROOT/gpu-memory-summary.json"

echo "DeltaAI evidence: $OUTPUT_ROOT"
