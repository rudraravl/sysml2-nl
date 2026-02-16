#!/bin/bash
# SysML-NL Frontend Runner
# Run this script to start the Next.js frontend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")/frontend"

cd "$FRONTEND_DIR"

echo "=== SysML-NL Frontend ==="
echo "Directory: $FRONTEND_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build if .next doesn't exist
if [ ! -d ".next" ]; then
    echo "Building Next.js application..."
    npm run build
fi

# Run the server on port 80 (requires sudo for privileged port)
echo "Starting Next.js server on 0.0.0.0:80..."
echo "----------------------------------------"
sudo env "PATH=$PATH" npm run start -- -p 80 -H 0.0.0.0
