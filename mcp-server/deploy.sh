#!/bin/bash
# FSP Brain — EC2 one-time setup script
# Run this on a fresh Ubuntu 24.04 t3.small instance as the ubuntu user.
# Prerequisites: EC2 has ports 80, 443, and 3000 open in its security group.

set -euo pipefail

DOMAIN="${FSP_BRAIN_DOMAIN:-}"  # e.g. brain.fspros.com — leave empty to use IP only

echo "=== FSP Brain EC2 Setup ==="

# 1. System packages
sudo apt-get update -q
sudo apt-get install -y -q docker.io docker-compose-v2 curl wget ufw

# 2. Caddy (reverse proxy + automatic HTTPS)
sudo apt-get install -y -q debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update -q && sudo apt-get install -y -q caddy

# 3. Start Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

# 4. Clone / copy the MCP server files
# Assumes you're running this from inside the mcp-server/ directory
# or that you've scp'd the files to ~/fsp-brain/
mkdir -p ~/fsp-brain
cp -r . ~/fsp-brain/
cd ~/fsp-brain

# 5. Create .env.production — FILL THESE IN before running
if [ ! -f .env.production ]; then
cat > .env.production <<'EOF'
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
OPENAI_API_KEY=YOUR_OPENAI_KEY
FSP_BRAIN_TOKEN=GENERATE_A_STRONG_SECRET_HERE
PORT=3000
EOF
echo ""
echo "⚠  STOP: Edit ~/fsp-brain/.env.production with your real values, then re-run this script."
exit 1
fi

# 6. Build and start the container
cd ~/fsp-brain
sudo docker compose up -d --build

# 7. Configure Caddy (HTTPS if domain set, plain HTTP if not)
if [ -n "${DOMAIN}" ]; then
sudo tee /etc/caddy/Caddyfile > /dev/null <<CADDY
${DOMAIN} {
    reverse_proxy localhost:3000
}
CADDY
  sudo systemctl reload caddy
  echo "✓ Caddy configured for https://${DOMAIN}"
else
  echo "⚠  No DOMAIN set — server accessible on port 3000 via IP (HTTP only)."
  echo "   Set FSP_BRAIN_DOMAIN=brain.yourdomain.com and re-run for HTTPS."
fi

# 8. Firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# 9. Health check
sleep 3
if curl -sf http://localhost:3000/health > /dev/null; then
  echo "✓ FSP Brain is running"
  if [ -n "${DOMAIN}" ]; then
    echo "   Endpoint: https://${DOMAIN}/mcp"
  else
    PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 || echo "YOUR_EC2_IP")
    echo "   Endpoint: http://${PUBLIC_IP}:3000/mcp"
  fi
else
  echo "✗ Health check failed — check: sudo docker compose logs fsp-brain"
  exit 1
fi

echo ""
echo "=== Next steps ==="
echo "1. Add FSP_BRAIN_URL and FSP_BRAIN_TOKEN to ~/.claude/.env on each staff machine"
echo "2. Staff run: claude-update"
echo "3. Test: ask Claude 'What do we know about [any client]?'"
