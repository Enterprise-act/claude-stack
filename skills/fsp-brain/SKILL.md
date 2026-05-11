---
name: fsp-brain
description: Teaches Claude how to use the FSP shared knowledge base. Use when starting any client task, storing decisions or research, or checking what the team has been working on. The brain is the first source of truth — always check it before starting client work cold.
---

# FSP Brain — Shared Team Knowledge Base

All staff Claude sessions connect to a shared memory layer. Everything stored by any team member — client notes, decisions, research, session activity — is searchable by everyone.

---

## The Three Moments That Matter

### 1. Before client work — pull context
Never start a client task without checking what we already know.

```
fsp_get_client_context("Acme Corp")
```
Returns: active projects, recent communications, past decisions, what the team has been doing.

If you're researching a topic rather than a specific client:
```
fsp_recall("pricing strategy for SaaS clients")
fsp_search_decisions("referral fee policy")
```

### 2. During work — store findings
When you make a decision, complete research, or finish an output — store it immediately.

```
fsp_remember(
  content="Decided to use Stripe for Acme Corp payment integration — avoids PayPal fees and they already have a Stripe account",
  type="decision",
  client_name="Acme Corp"
)

fsp_remember(
  content="Competitor analysis: main rivals are X, Y, Z. X leads on SEO, Y on pricing. Full report in Box /Acme/Research/2026-05.",
  type="research",
  client_name="Acme Corp"
)
```

### 3. After work — log the session
At the end of any significant session, log what happened.

```
fsp_log_activity(
  summary="Built Acme Corp email sequence (5 emails). Uploaded to Box. Needs review from Jordan before send.",
  client_name="Acme Corp"
)
```

The Stop hook does this automatically — it prompts at session end. Call it manually for mid-session milestones.

---

## All 7 Tools

### `fsp_get_client_context(client_name)`
Full snapshot of a client: projects, memories, activity, decisions.
Call this first. Always.

```
fsp_get_client_context("Globex")
```

### `fsp_recall(query, type?, client_name?, limit?)`
Semantic search across all team memories. Uses natural language — no exact match needed.

```
fsp_recall("email campaign results")
fsp_recall("what do we charge for social media management", type="decision")
fsp_recall("logo files", client_name="Acme Corp")
```

Memory types: `decision` · `research` · `output` · `communication` · `sop` · `client_note` · `task_state`

### `fsp_remember(content, type, client_name?, project_name?, tags?, created_by?)`
Store anything worth keeping. Tag it so others can find it.

```
fsp_remember(
  content="Acme Corp CEO prefers updates via text, not email. CC assistant Maria on all formal comms.",
  type="client_note",
  client_name="Acme Corp",
  tags=["communication-preference", "stakeholder"]
)
```

### `fsp_log_activity(summary, client_name?, project_name?, duration_mins?)`
Log what was done in a session. 2–3 sentences. Factual.

```
fsp_log_activity(
  summary="Completed Q2 social content calendar for Globex. 30 posts scheduled in Buffer. Waiting on image assets from their designer.",
  client_name="Globex",
  duration_mins=45
)
```

### `fsp_list_active_projects(status?)`
See all open work across the team.

```
fsp_list_active_projects()
fsp_list_active_projects(status="all")   # includes completed/paused
```

### `fsp_search_decisions(topic, category?)`
Look up company decisions and SOPs before making a judgment call.

```
fsp_search_decisions("rush project pricing")
fsp_search_decisions("contractor vs employee", category="hr")
```

Categories: `pricing` · `process` · `client` · `vendor` · `product` · `hr`

### `fsp_get_team_activity(days?, staff_name?)`
See what the team has been working on. Good for standup context or picking up someone else's work.

```
fsp_get_team_activity()                        # last 7 days, all staff
fsp_get_team_activity(days=1)                  # yesterday only
fsp_get_team_activity(staff_name="Jordan")     # one person
```

---

## Standard Workflows

### Starting a new client project
```
1. fsp_get_client_context("[client]")         ← what do we know?
2. fsp_recall("[project type] examples")      ← any past work to reference?
3. fsp_search_decisions("[relevant policy]")  ← any rules that apply?
4. ... do the work ...
5. fsp_remember(findings, type="output")      ← store what was produced
6. fsp_log_activity(summary)                  ← log the session
```

### Making a pricing or process decision
```
1. fsp_search_decisions("[topic]")   ← does a policy already exist?
2. ... make the decision ...
3. fsp_remember(decision, type="decision", tags=["pricing"])  ← record it
```

### Picking up someone else's work
```
1. fsp_get_client_context("[client]")   ← full history
2. fsp_get_team_activity(days=7)        ← recent team activity
3. fsp_recall("[specific topic]")       ← any relevant notes
```

### Storing a completed deliverable
```
fsp_remember(
  content="Completed brand guidelines for Acme Corp v2. PDF in Box /Acme/Brand/2026. Key changes: new logo lockups, updated color palette (#1A2B3C primary), new font stack (Inter/Georgia).",
  type="output",
  client_name="Acme Corp",
  tags=["brand", "deliverable"]
)
```

---

## What to Store vs. What to Skip

**Store:**
- Decisions (any judgment call on price, process, vendor, approach)
- Research findings (competitor analysis, market data, tool evaluations)
- Deliverable summaries (what was produced, where it lives)
- Client preferences and stakeholder notes
- Anything that would take >15 minutes to reconstruct

**Skip:**
- Raw conversation transcripts (too noisy)
- Intermediate drafts (store the final version or a pointer)
- Info that's already in a system of record (CRM, Box, project manager)

---

## Quick Reference

| Situation | Tool |
|-----------|------|
| Starting any client work | `fsp_get_client_context` |
| Looking something up | `fsp_recall` |
| Made a decision | `fsp_remember` (type=decision) |
| Finished research | `fsp_remember` (type=research) |
| Completed a deliverable | `fsp_remember` (type=output) |
| End of session | `fsp_log_activity` |
| What's everyone working on? | `fsp_get_team_activity` |
| Open projects | `fsp_list_active_projects` |
| What's our policy on X? | `fsp_search_decisions` |
