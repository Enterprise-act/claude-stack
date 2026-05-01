# Example: ClickUp → Company researcher agent

Video reference: the "Lovable" research demo in [ZeJXI2MAhj0](https://youtu.be/ZeJXI2MAhj0).

## What it does

User creates a task in a ClickUp "Research Queue" list with a company name as the title. A poller picks it up, an agent does iterative web research, writes a structured competitive brief, posts it as a comment on the task, and marks complete.

## Spec

- **Pattern**: [task-triggered-agent](../patterns/task-triggered-agent.md)
- **Trigger**: `cron: "*/2 * * * *"` (every 2 minutes)
- **Source**: ClickUp list (env: `CLICKUP_RESEARCH_LIST_ID`)
- **Idempotency key**: `clickup-task:<taskId>`
- **Agent tools**: `search_web`, `read_url`, `finish`
- **Max steps**: 20
- **Output**: Comment on the source ClickUp task + status: complete

## Brief structure (prompt the agent with this)

- 2–3 sentence company summary
- Product / service lines (bulleted)
- Recent news (last 6 months, with sources)
- Growth signals (hiring, funding, traffic)
- Competitors (with 1-line positioning each)
- Sources list (URLs)

## Files

```
src/trigger/clickup-poller.ts       # every 2min, picks up "to do" tasks
src/trigger/research-agent.ts       # the agent task
src/lib/agent.ts                    # runAgentLoop — generic harness
src/lib/search.ts                   # search_web (Exa / Brave / Serper)
src/lib/clickup.ts                  # listNewTasks, markInProgress, postComment, markComplete
```

## Why agent loop, not a deterministic chain

The research depth varies by company. A well-known SaaS needs 2–3 searches; an obscure B2B needs 10+. Hard-coding the step count wastes time or cuts off early. The agent decides when it's done via `finish()`.
