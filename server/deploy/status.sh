#!/bin/bash
# Check status of SysML-NL Services

echo "=== SysML-NL Service Status ==="
echo ""

# Check tmux session
SESSION_NAME="sysml"
echo "1. tmux Session:"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "   ✓ Session '$SESSION_NAME' is running"
    echo "   Windows:"
    tmux list-windows -t "$SESSION_NAME" 2>/dev/null | sed 's/^/     /'
else
    echo "   ✗ Session '$SESSION_NAME' is not running"
fi
echo ""

# Check backend
echo "2. Backend (FastAPI - port 8000):"
if curl -s http://127.0.0.1:8000/health > /dev/null 2>&1; then
    echo "   ✓ Backend is responding"
    curl -s http://127.0.0.1:8000/health | sed 's/^/     /'
    echo ""
else
    echo "   ✗ Backend is not responding"
fi
echo ""

# Check frontend
echo "3. Frontend (Next.js - port 3000):"
if curl -s http://127.0.0.1:3000 > /dev/null 2>&1; then
    echo "   ✓ Frontend is responding"
else
    echo "   ✗ Frontend is not responding"
fi
echo ""

# Check nginx
echo "4. Nginx:"
if systemctl is-active --quiet nginx; then
    echo "   ✓ Nginx is running"
else
    echo "   ✗ Nginx is not running"
fi
echo ""

# Test API endpoint
echo "5. API Test (/api/nl2llm):"
RESULT=$(curl -s -X POST http://127.0.0.1:8000/api/nl2llm \
    -H "Content-Type: application/json" \
    -d '{"text":"test"}' 2>/dev/null)
if [ -n "$RESULT" ]; then
    echo "   ✓ API responding"
    echo "   $RESULT"
else
    echo "   ✗ API not responding"
fi
echo ""

# Check public access (via nginx)
echo "6. Public Access (via Nginx):"
PUBLIC_RESULT=$(curl -s -X POST http://127.0.0.1/api/nl2llm \
    -H "Content-Type: application/json" \
    -d '{"text":"test"}' 2>/dev/null)
if [ -n "$PUBLIC_RESULT" ]; then
    echo "   ✓ Public API accessible"
    echo "   $PUBLIC_RESULT"
else
    echo "   ✗ Public API not accessible (check nginx config)"
fi
