# Prompt template: scaffold a scheduled poller

Copy-paste, fill in the `{{…}}` placeholders, paste into Claude Code.

---

I want to build a trigger.dev automation that runs on a schedule. Specifically:

- **What to check**: {{source — e.g. "the Nate B Jones YouTube channel"}}
- **How often**: {{interval — e.g. "every 8 hours"}}
- **Unit of work**: {{one-item description — e.g. "one new video"}}
- **Idempotency key**: {{natural ID — e.g. "video ID"}}
- **What to do with each new item**: {{action — e.g. "fetch the transcript, summarize it, and post the summary to this ClickUp list: <URL>"}}
- **Output destination**: {{where results go}}
- **On failure**: {{Slack/email alert, or just log}}

Use plan mode. Ask clarifying questions before writing code. Follow these rules:

1. Split into two tasks: one `schedules.task` that polls and hands off, one `task` that processes a single item. The worker gets the idempotency key.
2. Overlap the poll window by at least 2×, rely on idempotency to dedupe.
3. Bound any polling loops on external APIs (`maxAttempts` + `wait.for`).
4. Log step-level structured events on every meaningful action.
5. Before claiming done, run `npx trigger.dev@latest dev` and fire one test run end-to-end.

Project stack: trigger.dev (runtime + schedules + observability), TypeScript. No additional databases, no additional queues. If I've asked for anything that needs more infrastructure, call that out in plan mode before building.
