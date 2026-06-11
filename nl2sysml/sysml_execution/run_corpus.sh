#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS_ROOT="${SYSML_TOOLS_ROOT:-$(cd "$REPO_ROOT/../../.." && pwd)/.tools}"
PYTHON="${SYSML_PYTHON:-$TOOLS_ROOT/sysml-env/bin/python}"
JAVA_HOME="${JAVA_HOME:-$TOOLS_ROOT/sysml-env/lib/jvm}"
OUTPUT_DIR="${SYSML_CORPUS_OUTPUT:-$REPO_ROOT/results/sysml_execution_corpus_v3}"

if [[ ! -x "$PYTHON" ]]; then
  echo "SysML Python environment not found at: $PYTHON" >&2
  echo "Set SYSML_PYTHON to the Python executable containing jupyter_client and the sysml kernel." >&2
  exit 1
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$(dirname "$PYTHON"):$PATH"
export JUPYTER_CONFIG_DIR="${JUPYTER_CONFIG_DIR:-$TOOLS_ROOT/jupyter/config}"
export JUPYTER_DATA_DIR="${JUPYTER_DATA_DIR:-$TOOLS_ROOT/jupyter/data}"
export JUPYTER_RUNTIME_DIR="${JUPYTER_RUNTIME_DIR:-$TOOLS_ROOT/jupyter/runtime}"

mkdir -p "$OUTPUT_DIR"
cd "$REPO_ROOT"

RUNNER=("$PYTHON" -u -m nl2sysml.sysml_execution.corpus_runner --output "$OUTPUT_DIR" "$@")
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -i "${RUNNER[@]}" 2>&1 | tee -a "$OUTPUT_DIR/run.log"
else
  "${RUNNER[@]}" 2>&1 | tee -a "$OUTPUT_DIR/run.log"
fi
