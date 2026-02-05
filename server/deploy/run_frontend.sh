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

# Run the server
echo "Starting Next.js server on 127.0.0.1:3000..."
echo "----------------------------------------"
npm run start -- -p 3000 -H 127.0.0.1
