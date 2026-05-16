# FSP Brain — Setup Guide (Mark only)

One-time infrastructure setup. Staff never see this guide.

---

## Overview

FSP Brain is a Supabase Edge Function — **no server, no Docker, no EC2**.
Everything runs on Supabase's managed infrastructure.

| Component | What it is | Cost |
|-----------|-----------|------|
| Supabase DB | Postgres + pgvector | Free tier (up to 500MB) |
| Edge Function | Deno runtime, auto-scales | Free (2M requests/month) |

---

## Step 1: Schema

The `fsp_` tables are live in project `kycmufnisrdrvwsgydnh`.
If you ever need to re-apply from scratch, run `mcp-server/schema.sql`
in the Supabase SQL Editor.

**v2 migration** (per-staff auth + rate limiting) — apply once via Supabase MCP
`apply_migration` using the contents of `supabase/migrations/v2-auth-ratelimit.sql`.

---

## Step 2: Edge Function

The MCP server is deployed at:

```
https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
```

Verify it's up:
```bash
curl https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
# → {"status":"ok","service":"fsp-brain","version":"1.0.0"}
```

**Deployments are now automatic via CI/CD** (see Step 3). Any push to `main`
that touches `supabase/functions/fsp-brain/**` triggers a GitHub Actions deploy.

To deploy manually:
```bash
supabase functions deploy fsp-brain --project-ref kycmufnisrdrvwsgydnh
```

---

## Step 3: CI/CD Setup (one-time GitHub secret)

The workflow `.github/workflows/deploy-fsp-brain.yml` deploys automatically on
merge to `main`. It needs one GitHub secret:

1. Go to: **Supabase Dashboard → Account → Access Tokens** — create a token
2. Go to: **GitHub repo → Settings → Secrets → Actions → New repository secret**
3. Name: `SUPABASE_ACCESS_TOKEN`, Value: the token from step 1

After that, every merge to `main` that changes the Edge Function deploys it automatically.

---

## Step 4: Set Edge Function Secrets (one-time)

Go to: **Supabase Dashboard → Project `kycmufnisrdrvwsgydnh` → Settings → Edge Functions → Secrets**

| Key | Value |
|-----|-------|
| `FSP_BRAIN_TOKEN` | The shared legacy token (keep during staff migration, remove after) |
| `OPENAI_API_KEY` | Your OpenAI key (from platform.openai.com) |

Without `OPENAI_API_KEY` the system still works — it falls back to text search.

---

## Step 5: Per-Staff Tokens (v2)

Each staff member gets a unique personal token. This replaces the shared token
and makes all memories, activity logs, and decisions auditable per person.

**Generate a token for one staff member:**
```bash
# Run locally — never commit these values
TOKEN=$(openssl rand -hex 32)
HASH=$(echo -n "$TOKEN" | sha256sum | cut -d' ' -f1)
echo "Give to staff (DM only): $TOKEN"
echo "Store in DB:             $HASH"
```

**Insert into Supabase** (SQL editor or MCP `execute_sql`):
```sql
insert into fsp_staff_tokens (token_hash, staff_name)
values ('<HASH from above>', 'Jane Smith');
```

**To deactivate a staff member's access:**
```sql
update fsp_staff_tokens set active = false where staff_name = 'Jane Smith';
```

---

## Step 6: Distribute to Staff (~5 min)

Send this Slack message (replace `<TOKEN>` with each person's unique token — DM individually):

> **Action needed — FSP Brain personal token (2 min)**
>
> We've upgraded the brain to per-staff tokens. Please update your `~/.claude/.env`:
>
> 1. Open `~/.claude/.env` in any text editor
> 2. Update these 3 lines:
>
> ```
> FSP_BRAIN_URL=https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
> FSP_BRAIN_TOKEN=<YOUR PERSONAL TOKEN — see this DM>
> FSP_STAFF_NAME=Your Full Name
> ```
>
> 3. Run: `claude-update`
>
> Your old token keeps working for now — no rush, but update when you get a chance.

---

## Step 7: Seed Initial Data

In Claude Code with the fsp-brain MCP active:

```
Use fsp_remember to store: "Acme Corp — $5k/month retainer, contact: john@acme.com"
type=client_note, client_name="Acme Corp"
```

Or import a CSV directly into Supabase's Table Editor under `fsp_clients`.

---

## Available MCP Tools

| Tool | When Claude uses it |
|------|---------------------|
| `fsp_get_client_context` | Before starting any client work |
| `fsp_recall` | Semantic search across all memories |
| `fsp_remember` | Store a note, decision, or finding |
| `fsp_log_activity` | End-of-session summary (auto via hook) |
| `fsp_list_active_projects` | See all open projects across the team |
| `fsp_search_decisions` | Look up SOPs before making a judgment call |
| `fsp_get_team_activity` | See what staff worked on recently |

---

## Ongoing Maintenance

**View logs:**
Supabase Dashboard → Edge Functions → `fsp-brain` → Logs

**Rate limit monitoring:**
```sql
select token_hash, sum(req_count) as reqs_last_10min
from fsp_rate_limit
where window_min > floor(extract(epoch from now()) / 60) - 10
group by token_hash order by reqs_last_10min desc;
```

**Backup:**
Supabase Dashboard → Database → Backups (automatic on Pro, manual export on Free).

---

## n8n Automation (Phase 4 — after staff rollout)

### Workflow 1: Slack → Brain
- **Trigger:** Slack — watch `#client-*` channels
- **Action:** HTTP POST to `https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain`
- **Body:** `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fsp_remember","arguments":{...}}}`
- **Header:** `Authorization: Bearer <n8n service token from fsp_staff_tokens>`

### Workflow 2: Daily Digest
- **Trigger:** Schedule — 9am weekdays
- **Action:** Call `fsp_get_team_activity` and post result to `#team` Slack channel
