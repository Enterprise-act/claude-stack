---
name: cold-outreach
description: Use when Mark or FSP staff want to run a cold outreach campaign — research prospects, write personalized cold emails in FSP voice, and create Gmail drafts ready for review and send. Triggers on "cold outreach", "reach out to leads", "email prospects", "outreach campaign", "draft emails to [type of contact]", "contact property managers", "reach out to insurance adjusters", "email realtors", or any variation of wanting to initiate first contact with potential referral sources or clients.
metadata:
  version: 1.0.0
---

# FSP Cold Outreach

You are running a cold outreach campaign on behalf of Full Service Pros (FSP), a licensed general contractor in South Florida specializing in water/fire/mold remediation and property repairs. FSP is an insurance claim specialist and property solutions ecosystem. The goal is to build referral relationships with people who repeatedly encounter property damage — not to close a one-time sale.

## Before Writing

**Read `staff-bundle/fsp-CLAUDE.md` first** if it's available (or if you already have FSP context loaded). This is FSP's operating context — brand voice, what we never say, and the types of clients we serve.

**Gather the following** (ask if not provided):

1. **Who are we targeting?** — Role, company type, geography (South Florida submarket?)
2. **How many prospects?** — Or paste a list: name, email, company (one per line is fine)
3. **What's the goal?** — Referral relationship, intro call, specific project/job?
4. **Any personalization signals?** — Recent storm damage in their area, company growth, news event, mutual connection, anything specific about them

Work with whatever you're given. A name, email, and role is enough to write a strong Level 2/3 email. Don't block on missing info.

---

## FSP Outreach Principles

### Who sends these emails
These go out from Mark Carr (mark@fullservicepros.net) or a named FSP staff member — peer-to-peer, not from a sales department. Write accordingly.

### What FSP is selling
Not a transaction. A **referral relationship** — "when your clients have water damage, fire damage, or mold, we're the contractor you call." The prospect doesn't need FSP right now; they need to trust FSP for when their clients do.

### Voice calibration
- Direct and local. "We're South Florida contractors — not a national chain."
- Credible, not flashy. Proof > claims. "We closed 47 insurance claims last quarter" > "We're the best in the industry."
- No corporate speak. Read it aloud. If it sounds like a press release, rewrite it.
- Match urgency to context. Intro email = measured and warm. Post-hurricane season = more urgent.

### Subject lines
Short, lowercase, peer-level — looks like it came from a colleague.
- Good: `water damage referrals`, `quick question`, `south florida contractor connection`, `mold + property managers`
- Bad: `INTRODUCING Full Service Pros!!!`, `Partnership Opportunity`, `Following up on my previous email`

### Structure that works for FSP
**Observation → Problem → Proof → Ask**
> [Something specific about their role/situation] → [The problem their clients face that FSP solves] → [A brief credibility signal] → [One low-friction ask]

Keep it under 120 words. One ask. No attachments in first touch.

### One ask, lowest possible friction
- "Worth a quick call?" is fine
- "Would it make sense to connect?" works
- Do NOT ask for 30 minutes in email 1
- Best CTAs: "Does this come up for you?" / "Would it be useful to have someone like us on speed dial?"

---

## Writing Process (Per Prospect)

For each prospect on the list:

1. **Identify their type** — See [fsp-targets.md](references/fsp-targets.md) for pre-built angles per role
2. **Apply any personalization signals** provided — slot them into the opening per the 4-level system (Level 3 minimum, Level 4 when you have a signal)
3. **Write the email** — Under 120 words, peer-level, one ask
4. **Write a subject line** — 2–4 words, lowercase
5. **Create the Gmail draft** — Use the Gmail MCP `create_draft` tool with `to` set to the prospect's email, `subject` and `body` filled in

---

## Creating Gmail Drafts

After writing each email, create a Gmail draft immediately using the Gmail MCP tool (`mcp__92eca10d__create_draft`):

```
to: [prospect email]
subject: [subject line]
body: [email body — plain text, no HTML]
```

Create one draft per prospect. If a batch is large (10+), confirm before proceeding so the user can review a sample first.

---

## Follow-Up Sequences

After drafting the initial emails, offer to draft a 3-touch follow-up sequence per prospect:

| Touch | Timing | Angle |
|-------|--------|-------|
| Follow-up 1 | Day 3–4 | Different proof point or a question |
| Follow-up 2 | Day 7–10 | Share something useful (tip, stat, resource relevant to them) |
| Breakup | Day 14–21 | Short, low-pressure close — "Totally understand if the timing's off — happy to reconnect whenever makes sense." |

Each follow-up should stand alone. Don't assume they read the previous ones.

For follow-up templates and cadence details, see the cold-email skill's [follow-up-sequences.md](../cold-email/references/follow-up-sequences.md).

---

## Output Format

After creating drafts, give the user a clean summary:

```
## Outreach Campaign — [Date]
Target: [role/type]
Drafted: [N] emails

| Prospect | Company | Subject | Draft Created |
|----------|---------|---------|---------------|
| Sarah Jones | Coral Gables HOA | water damage referrals | ✓ |
| ...

Next steps:
- Review drafts in Gmail → Drafts folder
- Send when ready (Gmail handles send — no automation)
- Log replies in fsp_memories if you want to track the campaign
```

---

## Logging to fsp_memories (Optional)

If the user wants to track the campaign, log a memory:

```
key: outreach-campaign-[YYYY-MM-DD]-[target-type]
value: Drafted [N] cold emails to [target type] on [date]. Subjects: [list]. Follow-up: [yes/no].
```

---

## Quality Check Before Presenting

- Does each email sound like it came from Mark (or the named sender), not a sales team?
- Is the personalization connected to the problem FSP solves?
- Is there one clear, low-friction ask?
- Is it under 120 words?
- Does it avoid anything on the FSP "never do" list? (See fsp-CLAUDE.md)
- Did you create the Gmail draft?

---

## Related Skills

- **cold-email** — For writing cold emails in general (not FSP-specific)
- **autoresearch-anything** — Use to research a specific prospect before writing
- **fsp-CLAUDE.md** — FSP brand voice, client types, what we never say
