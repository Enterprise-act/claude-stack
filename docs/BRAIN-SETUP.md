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

## Step 1: Schema (already applied)

The `fsp_` tables are live in project `kycmufnisrdrvwsgydnh`.
If you ever need to re-apply from scratch, run `mcp-server/schema.sql`
in the Supabase SQL Editor.

---

## Step 2: Edge Function (already deployed)

The MCP server is deployed at:

```
https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
```

Verify it's up:
```bash
curl https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
# → {"status":"ok","service":"fsp-brain","version":"1.0.0"}
```

To update the function after code changes, redeploy via the Supabase MCP tool
`deploy_edge_function` with the contents of `supabase/functions/fsp-brain/index.ts`.

---

## Step 3: Set Secrets (one-time — required for semantic search + auth)

Go to: **Supabase Dashboard → Project `kycmufnisrdrvwsgydnh` → Settings → Edge Functions → Secrets**

Add these two secrets:

| Key | Value |
|-----|-------|
| `FSP_BRAIN_TOKEN` | `4ee134f0d657f7dbf35030b1564a96a19c0c21ec83d4fc799b047ef708f70486` |
| `OPENAI_API_KEY` | your OpenAI key (from platform.openai.com) |

`FSP_BRAIN_TOKEN` is the shared secret all staff put in their `~/.claude/.env`.
Without `OPENAI_API_KEY` the system still works — it falls back to text search.

---

## Step 4: Distribute to Staff (~5 min)

Send this Slack message:

> **Action needed — FSP Brain setup (2 min)**
>
> We now have a shared team knowledge base. All your Claude sessions will have access
> to client history, past decisions, and team activity.
>
> 1. Open `~/.claude/.env` in any text editor
> 2. Add these 3 lines:
>
> ```
> FSP_BRAIN_URL=https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain
> FSP_BRAIN_TOKEN=4ee134f0d657f7dbf35030b1564a96a19c0c21ec83d4fc799b047ef708f70486
> FSP_STAFF_NAME=Your Full Name
> ```
>
> 3. Run: `claude-update`
>
> That's it. Next time you open Claude, ask: "What do we know about [any client]?"

---

## Step 5: Seed Initial Data

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

**Update function code:**
Redeploy `supabase/functions/fsp-brain/index.ts` via Supabase MCP or CLI:
```bash
supabase functions deploy fsp-brain --project-ref kycmufnisrdrvwsgydnh
```

**View logs:**
Supabase Dashboard → Edge Functions → `fsp-brain` → Logs

**Backup:**
Supabase Dashboard → Database → Backups (automatic on Pro, manual export on Free).

---

## n8n Automation (Phase 4 — after staff rollout)

### Workflow 1: Slack → Brain
- **Trigger:** Slack — watch `#client-*` channels
- **Action:** HTTP POST to `https://kycmufnisrdrvwsgydnh.supabase.co/functions/v1/fsp-brain`
- **Body:** `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fsp_remember","arguments":{...}}}`
- **Header:** `Authorization: Bearer 4ee134f0d657f7dbf35030b1564a96a19c0c21ec83d4fc799b047ef708f70486`

### Workflow 2: Daily Digest
- **Trigger:** Schedule — 9am weekdays
- **Action:** Call `fsp_get_team_activity` and post result to `#team` Slack channel
