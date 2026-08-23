#!/bin/bash
set -euo pipefail

REPO="${REPO:-$PWD}"
IMAGE="${IMAGE:-$REPO/openmodelica-v1.27.0-arm64.sif}"
PYTHON_DEPS="${PYTHON_DEPS:-$REPO/.deltaai-python}"
export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${SCRATCH:-/tmp}/apptainer-cache}"

mkdir -p "$APPTAINER_CACHEDIR" "$PYTHON_DEPS"
if test ! -f "$IMAGE"; then
  apptainer pull --arch arm64 "$IMAGE" \
    docker://openmodelica/openmodelica:v1.27.0-ompython
fi

apptainer exec "$IMAGE" python3 -m pip install --upgrade --target "$PYTHON_DEPS" \
  FMPy==0.3.29 \
  "newton[sim,importers]==1.5.0" \
  newton-usd-schemas==0.5.0 \
  warp-lang==1.16.0 \
  usd-core==26.3 \
  mujoco==3.11.0 \
  mujoco-warp==3.11.0

apptainer exec \
  --env PYTHONPATH="$PYTHON_DEPS" \
  "$IMAGE" \
  python3 -c "import fmpy, newton, warp; assert fmpy.__version__ == '0.3.29'; assert newton.__version__ == '1.5.0'; assert warp.__version__ == '1.16.0'; from pxr import Usd, UsdPhysics"

echo "DeltaAI environment ready"
echo "IMAGE=$IMAGE"
echo "PYTHON_DEPS=$PYTHON_DEPS"
