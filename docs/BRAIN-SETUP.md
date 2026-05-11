# FSP Brain — Setup Guide (Mark only)

One-time infrastructure setup. Staff never see this guide — they just run `claude-update`.

---

## Overview

Two services to stand up:
1. **Supabase** — the database (managed, free tier works to start)
2. **AWS EC2** — runs the MCP server Docker container

Total cost: ~$45/month at full team scale.

---

## Step 1: Supabase Setup (~30 min)

1. Create a free account at **supabase.com**
2. Create a new project (call it `fsp-brain`)
3. In the SQL Editor, run the full contents of `mcp-server/schema.sql`
   - This creates all tables, indexes, RLS policies, and the pgvector search function
4. Go to **Settings → API** and copy:
   - **Project URL** → `SUPABASE_URL`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (keep this secret — server only)

---

## Step 2: EC2 Setup (~60 min)

### Launch instance
- **AMI:** Ubuntu 24.04 LTS
- **Type:** t3.small (1 vCPU, 2GB RAM) — ~$17/month
- **Storage:** 20GB gp3
- **Security group — open inbound:**
  - Port 22 (SSH) — your IP only
  - Port 80 (HTTP) — 0.0.0.0/0
  - Port 443 (HTTPS) — 0.0.0.0/0
- **Key pair:** Create or use existing

### DNS (optional but recommended)
Point `brain.fspros.com` → EC2 public IP as an A record.
Caddy handles HTTPS automatically once DNS propagates.

### Deploy

```bash
# From your local machine: copy the mcp-server directory to EC2
scp -r mcp-server/ ubuntu@YOUR_EC2_IP:~/fsp-brain/

# SSH into EC2
ssh ubuntu@YOUR_EC2_IP

# Set domain if you added DNS (or skip for IP-only)
export FSP_BRAIN_DOMAIN=brain.fspros.com

# Run setup (installs Docker, Caddy, builds container)
cd ~/fsp-brain
bash deploy.sh
```

When the script pauses to ask you to fill in `.env.production`, edit it:

```bash
nano ~/fsp-brain/.env.production
```

Fill in real values:
```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
OPENAI_API_KEY=your_openai_key
FSP_BRAIN_TOKEN=generate_a_strong_random_secret
PORT=3000
```

Then re-run `bash deploy.sh`. It completes in ~2 minutes.

### Verify
```bash
curl https://brain.fspros.com/health
# → {"status":"ok","service":"fsp-brain","version":"1.0.0"}
```

---

## Step 3: Distribute to Staff (~15 min)

Send this Slack message:

> **Action needed — FSP Brain setup (2 min)**
>
> We now have a shared team knowledge base. All your Claude sessions will have access to client history, past decisions, and team activity.
>
> 1. Open `~/.claude/.env` in any text editor
> 2. Add these 3 lines at the bottom:
>
> ```
> FSP_BRAIN_URL=https://brain.fspros.com
> FSP_BRAIN_TOKEN=THE_SHARED_TOKEN
> FSP_STAFF_NAME=Your Full Name
> ```
>
> 3. Run: `claude-update`
>
> That's it. Next time you open Claude, ask: "What do we know about [any client]?"

---

## Step 4: Seed Initial Data (~30 min)

In Claude Code with the fsp-brain MCP active, run these to seed your existing clients:

```
fsp_remember("Acme Corp — $5k/month retainer, contacts: john@acme.com", type="client_note", client_name="Acme Corp")
```

Or import a CSV directly into Supabase's Table Editor under the `clients` table.

---

## Ongoing Maintenance

**Update the server** when code changes:
```bash
ssh ubuntu@YOUR_EC2_IP
cd ~/fsp-brain
git pull  # if you set up git on the server, or scp new files
sudo docker compose up -d --build
```

**View logs:**
```bash
sudo docker compose logs -f fsp-brain
```

**Backup:** Supabase Pro includes automatic daily backups. Free tier: export manually via
Dashboard → Database → Backups.

---

## n8n Automation (Phase 4 — after staff rollout)

Build these workflows in `enterpriseact.app.n8n.cloud`:

### Workflow 1: Slack → Brain
- **Trigger:** Slack — watch `#client-*` channels for new messages
- **Action:** HTTP POST to `https://brain.fspros.com/mcp` with `fsp_remember` tool call
- **What it stores:** `type=communication`, `source=slack`, extracts client from channel name

### Workflow 2: Gmail → Brain
- **Trigger:** Gmail — new email from `@[known-client-domain].com`
- **Action:** Summarize email body (via Claude API node), POST to brain
- **What it stores:** `type=communication`, `source=gmail`

### Workflow 3: Daily Digest
- **Trigger:** Schedule — 9am weekdays
- **Action:** GET `https://brain.fspros.com/mcp` → `fsp_get_team_activity(days=1)`
- **Action:** Format and POST to `#team` Slack channel
- **What it shows:** Yesterday's sessions by staff member

n8n HTTP requests need the Authorization header:
```
Authorization: Bearer YOUR_FSP_BRAIN_TOKEN
```
