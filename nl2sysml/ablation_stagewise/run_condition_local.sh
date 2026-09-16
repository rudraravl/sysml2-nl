#!/usr/bin/env bash

set -euo pipefail

if (( $# != 2 )); then
  echo "usage: $0 CONDITION_ID WORKER_COUNT" >&2
  exit 2
fi

CONDITION_ID="$1"
WORKER_COUNT="$2"
if ! [[ "$CONDITION_ID" =~ ^A[1-4]$ ]]; then
  echo "condition must be A1, A2, A3, or A4" >&2
  exit 2
fi
if ! [[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] || \
   (( WORKER_COUNT < 4 || WORKER_COUNT > 6 )); then
  echo "worker count must be between 4 and 6" >&2
  exit 2
fi

REPO_ROOT="${SYSML_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=no)" ]]; then
  echo "tracked files are dirty; commit the frozen study before launching" >&2
  exit 2
fi

COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
RUN_ID="${SYSML_ABLATION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${COMMIT:0:8}}"
OUTPUT_ROOT="${SYSML_ABLATION_OUTPUT_ROOT:-$REPO_ROOT/outputs/sysml-ablation-$RUN_ID}"
CONDITION_OUTPUT="$OUTPUT_ROOT/$CONDITION_ID"
LOG_DIR="$CONDITION_OUTPUT/logs"
mkdir -p "$LOG_DIR"

if [[ -n "${SYSML_PYTHON:-}" ]]; then
  PYTHON_BIN="$SYSML_PYTHON"
elif [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
  PYTHON_BIN="$REPO_ROOT/.venv/bin/python"
else
  PYTHON_BIN="python3"
fi

# Prefer the kernel installed in this frozen worktree. An explicitly exported
# override still wins, but a stale path inside a dotenv file cannot silently
# replace the runtime whose resources are fingerprinted in protocol.json.
if [[ -z "${SYSML_JUPYTER_PATH:-}" ]] && \
   [[ -d "$REPO_ROOT/.venv/share/jupyter/kernels/sysml" ]]; then
  export SYSML_JUPYTER_PATH="$REPO_ROOT/.venv/share/jupyter"
fi

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup INT TERM

for (( SHARD_INDEX=0; SHARD_INDEX<WORKER_COUNT; SHARD_INDEX++ )); do
  COMMAND=(
    "$PYTHON_BIN" -m nl2sysml.ablation_stagewise.run_study
    --condition "$CONDITION_ID"
    --output-dir "$CONDITION_OUTPUT"
    --shard-count "$WORKER_COUNT"
    --shard-index "$SHARD_INDEX"
  )
  if [[ -n "${SYSML_ENV_FILE:-}" ]]; then
    COMMAND+=(--env-file "$SYSML_ENV_FILE")
  fi
  if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -dimsu "${COMMAND[@]}" \
      >"$LOG_DIR/shard-$SHARD_INDEX.log" \
      2>"$LOG_DIR/shard-$SHARD_INDEX.err" &
  else
    "${COMMAND[@]}" \
      >"$LOG_DIR/shard-$SHARD_INDEX.log" \
      2>"$LOG_DIR/shard-$SHARD_INDEX.err" &
  fi
  PIDS+=("$!")
done

STATUS=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || STATUS=1
done

"$PYTHON_BIN" -m nl2sysml.ablation_stagewise.aggregate \
  --output-dir "$CONDITION_OUTPUT"

echo "condition: $CONDITION_ID"
echo "commit: $COMMIT"
echo "output: $CONDITION_OUTPUT"
exit "$STATUS"
