#!/bin/bash
# SysML-NL tmux Session Manager
# Creates a tmux session with backend and frontend windows

SESSION_NAME="sysml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Kill existing session if it exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

echo "=== Starting SysML-NL Services ==="
echo "Creating tmux session: $SESSION_NAME"
echo ""

# Create new session with backend window
tmux new-session -d -s "$SESSION_NAME" -n "backend"
tmux send-keys -t "$SESSION_NAME:backend" "cd $SCRIPT_DIR && ./run_backend.sh" C-m

# Create frontend window
tmux new-window -t "$SESSION_NAME" -n "frontend"
tmux send-keys -t "$SESSION_NAME:frontend" "cd $SCRIPT_DIR && ./run_frontend.sh" C-m

# Create a logs window (optional, for monitoring)
tmux new-window -t "$SESSION_NAME" -n "logs"
tmux send-keys -t "$SESSION_NAME:logs" "echo 'Use this window for logs or debugging'" C-m
tmux send-keys -t "$SESSION_NAME:logs" "echo 'tail -f /var/log/nginx/sysml-nl-access.log'" C-m

# Select backend window
tmux select-window -t "$SESSION_NAME:backend"

echo "tmux session '$SESSION_NAME' created!"
echo ""
echo "To attach to the session:"
echo "  tmux attach -t $SESSION_NAME"
echo ""
echo "Windows:"
echo "  0: backend  - FastAPI server"
echo "  1: frontend - Next.js server"
echo "  2: logs     - Monitoring/debugging"
echo ""
echo "Navigation:"
echo "  Ctrl+b 0  - Switch to backend"
echo "  Ctrl+b 1  - Switch to frontend"
echo "  Ctrl+b 2  - Switch to logs"
echo "  Ctrl+b d  - Detach from session"
echo ""

# Attach to session
tmux attach -t "$SESSION_NAME"
