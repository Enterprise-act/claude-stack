---
name: fsp-job-context
description: >
  Load full context on an FSP job before starting work on it. Use when a staff
  member references a job channel, job number, or client name — e.g. "brief me
  on job 1234", "what's the status on the Smith job", "#fsp-1234-smith",
  "catch me up on the Johnson claim", or any variant of "what's happening with
  [client]". Pulls job history from FSP Brain and reads the Slack channel.
allowed-tools:
  - mcp__fsp_brain__fsp_get_client_context
  - mcp__fsp_brain__fsp_recall
  - Slack (read channel, read thread)
---

# FSP Job Context Loader

You are briefing a staff member on a specific FSP job before they start work on
it. Your goal is a concise, action-oriented summary — what's happening, what's
open, and who owns what.

## Step 1 — Extract the identifiers

From the user's message, identify:
- **Job number** (e.g. `1234` from `#fsp-1234-smith`)
- **Client name** (e.g. `Smith` from the channel name or what the user said)
- **Channel name** (construct as `#fsp-{job_number}-{client_name}` if not given)

If the job is an insurance claim, the channel ends in `-claim-job`.

## Step 2 — Load FSP Brain context

Call `fsp_get_client_context` with the client name extracted above.

This returns: active projects, recent communications, decisions, and team
activity for this client. If no result, call `fsp_recall("{client name} {job number}")`
as a fallback semantic search.

## Step 3 — Read the Slack job channel

Read the last 30–50 messages from the job channel. Focus on:
- Most recent status update
- Last client communication
- Any open items flagged by Intake or Billing
- Check collection status (if claim job)

## Step 4 — Output the Job Brief

Format the brief as:

```
## Job Brief: [Client Name] — Job #[Number]
**Channel:** #fsp-[number]-[client]
**Type:** [Remediation / Remodel / Insurance Claim]
**Status:** [One sentence — where the job is right now]

### What's Open
- [Action item] — Owner: [Intake / Billing / Field]
- [Action item] — Owner: ...

### Last Client Contact
[Date and what was communicated]

### Billing Status
[Invoice submitted? Check pending? Collections?]

### Next Step
[The single most important thing to do right now]
```

Keep the brief scannable. If there's nothing in the brain or channel, say so
clearly and ask the staff member to share what they know so you can help.

## Rules

- Never start client work without first loading this context
- If the client has a pending insurance claim, always note the adjuster status
  and last check-in date
- If the last channel message is > 7 days old, flag it: "Channel has been
  silent for X days — weekly check-in may be overdue"
- Always end with a clear next step
