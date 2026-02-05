# SysML-NL Converter

A web service that converts natural language to SysML.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              GCP VM                      │
                    │           34.83.162.173                  │
   ┌────────┐       │  ┌───────┐    ┌──────────┐ ┌──────────┐ │
   │ Client │──:80──┼─▶│ Nginx │───▶│ Next.js  │ │ FastAPI  │ │
   └────────┘       │  └───────┘    │  :3000   │ │  :8000   │ │
                    │      │        └──────────┘ └──────────┘ │
                    │      │ /api/*      ▲            ▲       │
                    │      └─────────────┼────────────┘       │
                    │                    │                    │
                    └────────────────────┼────────────────────┘
                                   127.0.0.1 only
```

## Directory Structure

```
server/
├── frontend/           # Next.js frontend
│   ├── src/app/        # Application pages
│   └── package.json
├── backend/            # FastAPI backend
│   ├── app/main.py     # API entry point
│   └── requirements.txt
├── deploy/             # Deployment scripts
│   ├── nginx.conf      # Nginx configuration
│   ├── tmux_start.sh   # Start services
│   ├── stop.sh         # Stop services
│   └── status.sh       # Check status
└── README.md
```

## Quick Start

### 1. Install Nginx

```bash
sudo apt update
sudo apt install nginx -y
```

### 2. Configure Nginx

```bash
# Copy configuration file
sudo cp deploy/nginx.conf /etc/nginx/sites-available/sysml-nl

# Create symlink
sudo ln -sf /etc/nginx/sites-available/sysml-nl /etc/nginx/sites-enabled/

# Remove default config (optional)
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload configuration
sudo nginx -t && sudo systemctl reload nginx
```

### 3. Start Services

```bash
cd server/deploy
chmod +x *.sh

# Start with tmux (recommended)
./tmux_start.sh

# Or start separately
./run_backend.sh   # In one terminal
./run_frontend.sh  # In another terminal
```

### 4. Verify Deployment

```bash
# Check service status
./status.sh

# Test API
curl -X POST http://34.83.162.173/api/nl2llm \
  -H "Content-Type: application/json" \
  -d '{"text":"test"}'
# Returns: {"result":"hello-sysml"}

# Access frontend
# Open http://34.83.162.173/ in browser
```

## API Documentation

### POST /api/nl2llm

Convert natural language to SysML.

**Request:**
```json
{
  "text": "some natural language"
}
```

**Response:**
```json
{
  "result": "hello-sysml"
}
```

**Error Response (400):**
```json
{
  "detail": "Text cannot be empty"
}
```

### GET /api/version

Get API version information.

**Response:**
```json
{
  "version": "0.1.0",
  "stage": "MVP",
  "description": "SysML-NL Converter"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy"
}
```

## Operations Commands

```bash
# Start services
./deploy/tmux_start.sh

# Stop services
./deploy/stop.sh

# Check status
./deploy/status.sh

# Attach to tmux session
tmux attach -t sysml

# Switch windows in tmux
# Ctrl+b 0 - backend
# Ctrl+b 1 - frontend
# Ctrl+b 2 - logs
# Ctrl+b d - detach

# Restart nginx
sudo systemctl restart nginx

# View nginx logs
tail -f /var/log/nginx/sysml-nl-access.log
tail -f /var/log/nginx/sysml-nl-error.log
```

## GCP Firewall Configuration

Ensure only port 80 is open:

```bash
# In GCP Console or using gcloud command
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags=http-server \
  --description="Allow HTTP traffic"
```

## Development Mode

### Backend Development

```bash
cd server/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Development mode (auto-reload)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# API docs
# http://localhost:8000/docs
```

### Frontend Development

```bash
cd server/frontend
npm install

# Development mode (hot reload)
npm run dev

# Build for production
npm run build
npm run start
```

## Next Phase Roadmap

- [ ] Integrate actual model (Qwen3-Embedding + Qwen3-Instruct)
- [ ] Add `/api/convert/text` and `/api/convert/diagram`
- [ ] Add simple authentication (API key / basic auth)
- [ ] Add HTTPS (Let's Encrypt)
- [ ] Add logging system

## License

MIT
