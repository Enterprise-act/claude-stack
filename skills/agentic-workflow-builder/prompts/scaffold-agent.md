# Prompt template: scaffold a task-triggered agent

Copy-paste, fill in the `{{…}}` placeholders, paste into Claude Code.

---

I want to build a trigger.dev automation where an external event triggers an AI agent that does work and posts results back. Specifically:

- **Trigger source**: {{system — e.g. "a new ClickUp task in list <URL>"}}
- **Payload shape**: {{what the trigger provides — e.g. "the task title is a company name"}}
- **Agent goal**: {{in one sentence — e.g. "produce a structured competitive brief on the company"}}
- **Agent tools it needs**: {{list — e.g. "search_web, read_url, finish"}}
- **Max steps**: {{default 20}}
- **Output destination**: {{where results go — e.g. "as a comment on the same ClickUp task, then mark task complete"}}
- **On failure**: {{Slack/email alert + mark task failed}}

Use plan mode. Ask clarifying questions first. Follow these rules:

1. Two tasks: a `schedules.task` poller (every 1–2 min) that watches for new items + triggers the agent with the task ID as idempotency key; and a `task` that runs the agent loop.
2. Agent tools are named by intent, not by API. Keep the toolset at 3–5.
3. Always include a `finish(result)` tool; bound the loop with `maxSteps`.
4. Status updates on the source system: **in_progress** on pickup → **complete** or **failed** at end. Never leave a silent run.
5. Every agent step emits a structured log event (`logger.info("step", { n, tool, args })`).
6. Before claiming done, run `npx trigger.dev@latest dev`, create one real trigger in the source system, and verify the full flow.

Stack: trigger.dev + TypeScript + an LLM for the agent (use Claude via `@anthropic-ai/sdk` unless I specify otherwise). No extra queues, no extra databases.
