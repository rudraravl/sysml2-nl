#!/usr/bin/env bash

set -euo pipefail

WORKERS="${1:-4}"
if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || (( WORKERS < 4 || WORKERS > 6 )); then
  echo "worker count must be between 4 and 6" >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SYSML_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
export SYSML_ABLATION_RUN_ID="${SYSML_ABLATION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${COMMIT:0:8}}"

PIDS=()
for SCRIPT in run_a1_rag.sh run_a2_moe.sh run_a3_compiler.sh run_a4_execution.sh; do
  "$HERE/$SCRIPT" "$WORKERS" &
  PIDS+=("$!")
done

STATUS=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || STATUS=1
done
if (( STATUS == 0 )); then
  if [[ -n "${SYSML_PYTHON:-}" ]]; then
    PYTHON_BIN="$SYSML_PYTHON"
  elif [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
    PYTHON_BIN="$REPO_ROOT/.venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
  OUTPUT_ROOT="${SYSML_ABLATION_OUTPUT_ROOT:-$REPO_ROOT/outputs/sysml-ablation-$SYSML_ABLATION_RUN_ID}"
  "$PYTHON_BIN" -m nl2sysml.ablation_stagewise.compare \
    --output-root "$OUTPUT_ROOT"
fi
exit "$STATUS"
