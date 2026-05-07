#!/bin/bash
# FSP Executive Assistant - Setup Script

set -e

echo "=========================================="
echo "FSP Executive Assistant Setup"
echo "=========================================="

# Check prerequisites
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || echo "Warning: docker-compose not found, using docker compose"

# Navigate to script directory
cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Creating config/.env from template..."
if [ ! -f config/.env ]; then
    cp config/.env.example config/.env
    echo "Created config/.env - please fill in your API keys"
else
    echo "config/.env already exists"
fi

echo ""
echo "Step 2: Creating Python virtual environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    echo "Virtual environment created"
else
    echo "Virtual environment already exists"
fi

echo ""
echo "Step 3: Installing Python dependencies..."
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "Step 4: Starting Docker services (Qdrant, Redis)..."
docker-compose up -d qdrant redis

echo ""
echo "Waiting for services to be ready..."
sleep 5

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Edit config/.env and fill in your API keys:"
echo "   - ANTHROPIC_API_KEY (required)"
echo "   - VOYAGE_API_KEY (required)"
echo "   - SLACK_BOT_TOKEN, SLACK_APP_TOKEN, SLACK_SIGNING_SECRET"
echo "   - Google OAuth credentials"
echo "   - QuickBooks credentials"
echo "   - Frappe credentials (optional)"
echo "   - Encircle credentials (optional)"
echo ""
echo "2. Run initial data ingestion:"
echo "   source .venv/bin/activate"
echo "   python -m src.memory.ingestion"
echo ""
echo "3. Start the assistant:"
echo "   python -m src.api.server"
echo ""
echo "Or run everything with Docker:"
echo "   docker-compose up -d"
echo ""
