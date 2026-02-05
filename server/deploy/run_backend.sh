#!/bin/bash
# SysML-NL Backend Runner
# Run this script to start the FastAPI backend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")/backend"

cd "$BACKEND_DIR"

echo "=== SysML-NL Backend ==="
echo "Directory: $BACKEND_DIR"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt

# Run the server
echo "Starting FastAPI server on 127.0.0.1:8000..."
echo "----------------------------------------"
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
