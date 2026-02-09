#!/bin/bash
# SysML-NL Backend Runner
# Run this script to start the FastAPI backend
# Uses conda base environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")/backend"

cd "$BACKEND_DIR"

echo "=== SysML-NL Backend ==="
echo "Directory: $BACKEND_DIR"

# Activate conda base environment
eval "$(conda shell.bash hook)"
conda activate base

# Install dependencies if needed (first time only)
echo "Checking dependencies..."
pip install -q -r requirements.txt

# Run the server (single worker for model management)
echo "Starting FastAPI server on 0.0.0.0:8000..."
echo "Model idle timeout: ${IDLE_UNLOAD_SECONDS:-600}s"
echo "----------------------------------------"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
