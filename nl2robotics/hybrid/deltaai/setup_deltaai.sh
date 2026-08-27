#!/bin/bash
set -euo pipefail

REPO="${REPO:-$PWD}"
IMAGE="${IMAGE:-$REPO/openmodelica-v1.27.0-arm64.sif}"
PYTHON_ENV="${PYTHON_ENV:-${PYTHON_DEPS:-$REPO/.deltaai-python}}"
MICROMAMBA_VERSION="${MICROMAMBA_VERSION:-2.9.0}"
MICROMAMBA="${MICROMAMBA:-$REPO/.deltaai-tools/bin/micromamba}"
export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${SCRATCH:-/tmp}/apptainer-cache}"
export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-${SCRATCH:-$REPO}/micromamba-root}"

mkdir -p "$APPTAINER_CACHEDIR" "$(dirname "$MICROMAMBA")" "$MAMBA_ROOT_PREFIX"
if test ! -f "$IMAGE"; then
  apptainer pull --arch arm64 "$IMAGE" \
    docker://openmodelica/openmodelica:v1.27.0-ompython
fi

if test ! -x "$MICROMAMBA"; then
  curl -Ls \
    "https://micro.mamba.pm/api/micromamba/linux-aarch64/$MICROMAMBA_VERSION" |
    tar -xj -C "$(dirname "$MICROMAMBA")" --strip-components=1 bin/micromamba
fi

# usd-exchange's ARM64 OpenUSD bindings require a shared libpython.  The
# OpenModelica image intentionally ships a minimal Python executable without
# that library, so create a small, pinned user-space Python runtime for them.
if test ! -x "$PYTHON_ENV/bin/python"; then
  "$MICROMAMBA" create -y -p "$PYTHON_ENV" -c conda-forge \
    python=3.10.21 pip
fi

"$PYTHON_ENV/bin/python" -m pip install --upgrade \
  FMPy==0.3.29 \
  "newton[sim,importers]==1.5.0" \
  newton-usd-schemas==0.5.0 \
  warp-lang==1.16.0 \
  usd-exchange==3.0.0 \
  mujoco==3.11.0 \
  mujoco-warp==3.11.0

apptainer exec "$IMAGE" "$PYTHON_ENV/bin/python" -c "import fmpy, newton, warp; assert fmpy.__version__ == '0.3.29'; assert newton.__version__ == '1.5.0'; assert warp.__version__ == '1.16.0'; from pxr import Usd, UsdPhysics; assert Usd.GetVersion() == (0, 26, 8)"

echo "DeltaAI environment ready"
echo "IMAGE=$IMAGE"
echo "PYTHON_ENV=$PYTHON_ENV"
