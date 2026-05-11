# FSP Brain — Shared Team Knowledge Base

Use the FSP Brain MCP tools to access and contribute to the team's shared knowledge base.
This is the single source of truth for all client context, decisions, research, and activity.

## When you are invoked

Activate when the user says things like:
- "What do we know about [client]?"
- "Has anyone researched [topic]?"
- "Log what we did today"
- "Remember this decision"
- "What's the team working on?"
- "Show me all [client] history"
- "What are our SOPs for [topic]?"
- "Brief me on [client] before I start"

---

## Available tools

### `fsp_get_client_context(client_name)`
**Use first, always, before starting any client work.**

Returns: active projects + owner, recent communications, recent memories, activity log,
relevant company decisions.

```
fsp_get_client_context("Acme Corp")
```

---

### `fsp_recall(query, type?, client_name?, limit?)`
Semantic search across everything in the brain. Use natural language.

Types: `decision` | `research` | `output` | `communication` | `sop` | `client_note` | `task_state`

```
fsp_recall("email marketing pricing for SaaS clients")
fsp_recall("competitor analysis", type="research", client_name="Acme")
```

---

### `fsp_remember(content, type, client_name?, project_name?, tags?)`
Store a memory so the whole team has it.

```
fsp_remember(
  content="Acme Corp approved move to $5k monthly retainer starting June 2026",
  type="decision",
  client_name="Acme Corp",
  tags=["pricing", "retainer"]
)
```

---

### `fsp_log_activity(summary, client_name?, project_name?, duration_mins?)`
Log what was accomplished in a session.

```
fsp_log_activity(
  "Finished Acme Q2 proposal. Waiting on client approval before invoicing.",
  client_name="Acme Corp",
  project_name="Q2 Strategy Deck"
)
```

---

### `fsp_list_active_projects(status?)`
See all projects across the team.

```
fsp_list_active_projects()
fsp_list_active_projects(status="active")
```

---

### `fsp_search_decisions(topic, category?)`
Find SOPs and company decisions before making judgment calls.

Categories: `pricing` | `process` | `client` | `vendor` | `product` | `hr`

```
fsp_search_decisions("retainer pricing")
fsp_search_decisions("contract templates", category="vendor")
```

---

### `fsp_get_team_activity(days?, staff_name?)`
See what the team has been working on.

```
fsp_get_team_activity(days=7)
fsp_get_team_activity(days=30, staff_name="Sarah")
```

---

## Standard workflow

**Starting client work:**
1. `fsp_get_client_context("[client]")` — get full picture
2. `fsp_search_decisions("[relevant topic]")` — check any SOPs that apply
3. Proceed with full context

**Ending a session:**
1. `fsp_log_activity("[what was accomplished]", client_name="...", project_name="...")`
2. If a decision was made: `fsp_remember(content, type="decision", ...)`
3. If research was done: `fsp_remember(content, type="research", ...)`

**Handing off to another staff member:**
1. `fsp_get_client_context("[client]")` — pull full brief
2. `fsp_get_team_activity(days=14)` — see recent work
3. Compile handoff summary from results
