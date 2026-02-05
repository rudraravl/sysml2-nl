#!/bin/bash
# Stop SysML-NL Services

SESSION_NAME="sysml"

echo "=== Stopping SysML-NL Services ==="

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
    echo "tmux session '$SESSION_NAME' stopped."
else
    echo "tmux session '$SESSION_NAME' is not running."
fi
