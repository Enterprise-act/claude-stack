#!/bin/bash
# FSP Executive Assistant - AWS Lightsail Setup Script
# Run this ON the Lightsail instance after SSH'ing in

set -e

echo "=========================================="
echo "FSP Executive Assistant - AWS Setup"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create app directory
echo "Creating application directory..."
sudo mkdir -p /opt/fsp-assistant
sudo chown $USER:$USER /opt/fsp-assistant
cd /opt/fsp-assistant

# Clone the repo
echo "Cloning repository..."
git clone https://github.com/carrmjw/claude-stack.git .

# Navigate to assistant
cd executive-assistant

# Create .env file
echo "Creating environment file..."
cp config/.env.example config/.env

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Edit the environment file:"
echo "   nano /opt/fsp-assistant/executive-assistant/config/.env"
echo ""
echo "2. Add your API keys (at minimum):"
echo "   - ANTHROPIC_API_KEY"
echo "   - VOYAGE_API_KEY"
echo "   - SLACK_BOT_TOKEN (from n8n, not needed if using n8n webhooks)"
echo ""
echo "3. Start the services:"
echo "   cd /opt/fsp-assistant/executive-assistant"
echo "   docker-compose up -d"
echo ""
echo "4. Check status:"
echo "   docker-compose ps"
echo "   curl http://localhost:8000/health"
echo ""
echo "5. Run initial data ingestion:"
echo "   docker-compose exec assistant python -m src.memory.ingestion"
echo ""
echo "Your API endpoint will be: http://YOUR_LIGHTSAIL_IP:8000"
echo ""
