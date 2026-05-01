# Pattern: Task-Triggered Agent

**Use when:** "When someone creates a task in [ClickUp/Linear/Notion], [do research / write / generate / deliver]."

The external system is the UI. The user creates a task with a minimal payload (a company name, a topic, a URL). An agent picks it up, loops through tools until it's done, and posts the result back as a comment/update on the same task.

## Shape

```
schedules.task (short cron, e.g. every 1–2 min)
  → list new tasks in the watched list
  → for each new task:
      idempotencyKey = task ID
      await agentTask.trigger({ taskId, topic }, { idempotencyKey })

task (agentTask)
  → mark source task "in progress"
  → agent loop:
      while not done and attempts < max:
        decide next tool call
        execute tool (search_web, read_url, generate_image, ...)
        feed result back into the loop
  → post result as comment
  → mark source task "complete"
```

## The agent tool shape

Keep the toolset small and named by intent, not by API:

- `search_web(query)` → returns ranked snippets
- `read_url(url)` → returns cleaned text
- `generate_image(prompt)` → returns image URL (handles polling internally)
- `finish(result)` → ends the loop

Three to five tools is plenty. More tools = more scope confusion. If you need more capability, prefer richer inputs/outputs on existing tools rather than adding new ones.

## Template

```ts
// src/trigger/clickup-poller.ts
import { schedules, idempotencyKeys, logger } from "@trigger.dev/sdk";
import { researchAgent } from "./research-agent";
import { listNewTasks, markInProgress } from "../lib/clickup";

export const clickupPoller = schedules.task({
  id: "clickup-research-poller",
  cron: "*/2 * * * *", // every 2 minutes
  run: async () => {
    const tasks = await listNewTasks(process.env.CLICKUP_RESEARCH_LIST_ID!);
    for (const t of tasks) {
      await markInProgress(t.id);
      const key = await idempotencyKeys.create(`clickup-task:${t.id}`);
      await researchAgent.trigger(
        { taskId: t.id, topic: t.name },
        { idempotencyKey: key }
      );
    }
    return { picked: tasks.length };
  },
});
```

```ts
// src/trigger/research-agent.ts
import { task, logger } from "@trigger.dev/sdk";
import { runAgentLoop } from "../lib/agent";
import { postComment, markComplete } from "../lib/clickup";

export const researchAgent = task({
  id: "research-agent",
  retry: { maxAttempts: 2 },
  run: async (payload: { taskId: string; topic: string }) => {
    const result = await runAgentLoop({
      goal: `Produce a competitive brief on: ${payload.topic}`,
      tools: ["search_web", "read_url", "finish"],
      maxSteps: 20,
    });
    await postComment(payload.taskId, result.markdown);
    await markComplete(payload.taskId);
    return { ok: true };
  },
});
```

## Agent loop essentials

- **Bound the loop.** Always set `maxSteps`. 15–25 for research, 5–10 for single-tool tasks.
- **Log every step.** `logger.info("step", { n, tool, args })` — this is what makes trigger.dev's dashboard useful.
- **Separate "think" from "act".** Let the agent plan its next step, then execute — don't conflate them. Makes the trace readable.
- **Always provide `finish`.** Without it, agents hit `maxSteps` and return incomplete work.

## Status updates on the source task

In the source system (ClickUp, Linear), keep three states visible:

1. **in_progress** — set as soon as the poller picks the task. Tells the user you're on it.
2. **commenting** progress updates — optional, useful for long agents. Post "researching X…" every few steps.
3. **complete** — set only after the final comment posts.

If the agent fails, set a **failed** state and post the error as a comment. Silent failures in SaaS tools look like "nothing happened," which is worse than a visible error.

## Anti-patterns

- Polling every 10 seconds. 1–2 minutes is plenty — users create tasks, not streams.
- Giving the agent 15+ tools. Cut to 3–5 intent-level tools.
- Doing the work in the poller. Poller's only job is discover + hand off.
- No `maxSteps`. Agents will loop on ambiguity until your wallet cries.
