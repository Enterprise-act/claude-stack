# FSP Executive Assistant - Deployment Guide

## Architecture: AWS + n8n

```
┌─────────────────────┐         ┌─────────────────────┐
│       SLACK         │         │        n8n          │
│   @mention bot      │────────▶│   (your instance)   │
└─────────────────────┘         └──────────┬──────────┘
                                           │
                                           ▼
                                ┌─────────────────────┐
                                │   AWS LIGHTSAIL     │
                                │                     │
                                │  ┌───────────────┐  │
                                │  │  Assistant    │  │
                                │  │  API Server   │  │
                                │  └───────┬───────┘  │
                                │          │          │
                                │  ┌───────┴───────┐  │
                                │  │    Qdrant     │  │
                                │  │  (Vector DB)  │  │
                                │  └───────────────┘  │
                                └─────────────────────┘
```

## Total Time: ~45 minutes

| Step | Time | Description |
|------|------|-------------|
| 1. AWS Lightsail | 15 min | Create and configure instance |
| 2. Slack App | 10 min | Create app with manifest |
| 3. n8n Workflow | 10 min | Import and configure |
| 4. Test | 10 min | Verify everything works |

---

## Step 1: Create AWS Lightsail Instance (15 min)

### 1.1 Create the Instance

1. Go to [AWS Lightsail Console](https://lightsail.aws.amazon.com)
2. Click **Create instance**
3. Select:
   - **Region**: US East (N. Virginia) or closest to your team
   - **Platform**: Linux/Unix
   - **Blueprint**: Ubuntu 22.04 LTS
   - **Instance plan**: $20/month (2 GB RAM, 2 vCPUs)
   - **Instance name**: `fsp-executive-assistant`
4. Click **Create instance**

### 1.2 Create Static IP

1. Go to **Networking** tab
2. Click **Create static IP**
3. Attach to `fsp-executive-assistant`
4. **Save this IP** - you'll need it for n8n

### 1.3 Open Firewall Ports

1. Go to your instance → **Networking**
2. Under **IPv4 Firewall**, add rules:
   - Port `8000` (TCP) - API server
   - Port `80` (TCP) - HTTP (for future HTTPS)

### 1.4 SSH and Install

1. Click **Connect using SSH** (or use your terminal)
2. Run the setup script:

```bash
# Download and run setup
curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/executive-assistant/deploy/aws-lightsail/setup.sh | bash

# Log out and back in for Docker permissions
exit
```

3. SSH back in and configure:

```bash
# Edit environment variables
cd /opt/fsp-assistant/executive-assistant
nano config/.env
```

4. Add your API keys:

```env
ANTHROPIC_API_KEY=sk-ant-...
VOYAGE_API_KEY=pa-...
```

5. Start the services:

```bash
docker-compose up -d
```

6. Verify it's running:

```bash
curl http://localhost:8000/health
# Should return: {"status":"healthy","service":"executive-assistant"}
```

**Your API URL**: `http://YOUR_STATIC_IP:8000`

---

## Step 2: Create Slack App (10 min)

### 2.1 Create the App

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Click **Create New App** → **From an app manifest**
3. Select your workspace
4. Paste this manifest:

```yaml
display_information:
  name: FSP Assistant
  description: AI-powered executive assistant for Full Service Pros
  background_color: "#4A154B"

features:
  app_home:
    home_tab_enabled: true
    messages_tab_enabled: true
    messages_tab_read_only_enabled: false
  bot_user:
    display_name: FSP Assistant
    always_online: true

oauth_config:
  scopes:
    bot:
      - app_mentions:read
      - chat:write
      - im:history
      - im:read
      - im:write
      - channels:history
      - channels:read
      - groups:history
      - groups:read
      - users:read
      - reactions:read
      - reactions:write

settings:
  event_subscriptions:
    bot_events:
      - app_mention
      - message.im
  interactivity:
    is_enabled: true
  org_deploy_enabled: false
  socket_mode_enabled: false
  token_rotation_enabled: false
```

5. Click **Create**

### 2.2 Install to Workspace

1. Go to **Install App** in the sidebar
2. Click **Install to Workspace**
3. Authorize the app

### 2.3 Get Your Tokens

1. Go to **OAuth & Permissions**
2. Copy **Bot User OAuth Token** (`xoxb-...`)
3. Save this - you'll need it for n8n

### 2.4 Configure Event URL (after n8n setup)

1. Go to **Event Subscriptions**
2. Enable Events
3. Request URL: `https://enterpriseact.app.n8n.cloud/webhook/fsp-assistant-slack`
4. Wait for verification (n8n must be running)
5. Save Changes

---

## Step 3: Set Up n8n Workflow (10 min)

### 3.1 Import Workflow

1. Open [your n8n instance](https://enterpriseact.app.n8n.cloud)
2. Go to **Workflows** → **Import from file**
3. Upload: `deploy/n8n-workflows/fsp-executive-assistant.json`

### 3.2 Configure Variables

1. Go to **Settings** → **Variables**
2. Add:

| Variable | Value |
|----------|-------|
| `FSP_ASSISTANT_URL` | `http://YOUR_LIGHTSAIL_IP:8000` |
| `SLACK_BOT_TOKEN` | `xoxb-your-token` |

### 3.3 Set Up Slack Credentials

1. Open the imported workflow
2. Click on **Reply in Slack** node
3. Under Credentials, click **Create New**
4. Select **Slack API**
5. Enter your Bot Token (`xoxb-...`)
6. Save

### 3.4 Activate Workflow

1. Toggle the workflow to **Active** (top right)
2. Copy the webhook URL shown

### 3.5 Update Slack Events (Go back to Slack)

1. In Slack App settings → **Event Subscriptions**
2. Set Request URL to your n8n webhook
3. Save and verify

---

## Step 4: Test Everything (10 min)

### 4.1 Test AWS API Directly

```bash
curl -X POST http://YOUR_LIGHTSAIL_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello, are you working?"}'
```

### 4.2 Test in Slack

1. Go to any channel where the bot is added
2. Type: `@FSP Assistant hello, what can you do?`
3. You should see:
   - 👀 reaction appears immediately
   - Response posted in thread within 10-30 seconds

### 4.3 Run Initial Data Ingestion

SSH into your Lightsail instance:

```bash
cd /opt/fsp-assistant/executive-assistant
docker-compose exec assistant python -m src.memory.ingestion
```

This will pull data from Google Drive, Slack history, Gmail, etc.

---

## Maintenance

### View Logs

```bash
docker-compose logs -f assistant
```

### Restart Services

```bash
docker-compose restart
```

### Update Code

```bash
cd /opt/fsp-assistant
git pull origin main
cd executive-assistant
docker-compose up -d --build
```

### Manual Re-sync Data

```bash
# Full sync
curl -X POST http://localhost:8000/sync/now -H "Content-Type: application/json" -d '{"full": true}'

# Incremental sync
curl -X POST http://localhost:8000/sync/now
```

---

## Cost Summary

| Service | Monthly Cost |
|---------|-------------|
| AWS Lightsail (2GB) | $20 |
| n8n | (existing) |
| Slack | (existing) |
| **Total** | **~$20/month** |

---

## Troubleshooting

### Bot not responding

1. Check n8n workflow is Active
2. Check AWS instance is running: `docker-compose ps`
3. Check logs: `docker-compose logs assistant`

### Slack events not arriving

1. Verify Event Subscriptions URL is verified in Slack
2. Check n8n workflow executions for errors

### API timeout

1. Check Lightsail firewall allows port 8000
2. Verify static IP is attached

### Memory/search not working

1. Run ingestion: `docker-compose exec assistant python -m src.memory.ingestion`
2. Check Qdrant is running: `docker-compose ps qdrant`
