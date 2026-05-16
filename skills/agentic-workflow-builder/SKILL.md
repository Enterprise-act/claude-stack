---
name: agentic-workflow-builder
description: Build "agentic workflows" — code-native automations where Claude writes the integration code (APIs, dedupe, polling, error handling) on a durable runtime like trigger.dev, replacing the n8n/Make/Zapier drag-and-drop approach. Invoke when the user says "build an automation / agent / workflow that [triggers on X] and [does Y]", wants to replace an n8n/Make flow with code, or asks to scaffold a scheduled poller or task-triggered agent.
---

# agentic-workflow-builder

Turns a natural-language automation request into a working trigger.dev task (or pair of tasks) with the right defaults for scheduling, idempotency, tool-using agent loops, polling external APIs, observability, and deployment.

Origin: [Stop Learning n8n in 2026…Learn THIS Instead](https://youtu.be/ZeJXI2MAhj0). Thesis: drag-and-drop automation is becoming the slow path. Describing the outcome in plain English and letting Claude Code generate the trigger.dev code is now faster for most real workflows — especially once you factor in dedupe, multi-step agent logic, and long-running polls.

## When to invoke

Triggers:
- "Build an automation/agent/workflow that [verb] every [interval]…"
- "Watch [system] for [event] and then [action]…"
- "I want to replace this n8n/Make/Zapier flow with code"
- "Scaffold a scheduled poller" or "scaffold a task-triggered agent"
- User drops a ClickUp/Linear/Notion/Slack URL and says "when something happens there, do X"

Do NOT invoke for: one-shot scripts, pure data analysis, or UI work. Those don't need a durable runtime.

## The two reusable shapes

Almost every automation in the video collapses to one of two patterns:

1. **Scheduled poller** — cron fires → fetch source → filter out already-processed items via idempotency key → for each new item, trigger a worker task. See [patterns/scheduled-poller.md](patterns/scheduled-poller.md).
2. **Task-triggered agent** — external event (ClickUp task, webhook, email) → poller sees it → triggers an agent with a small toolset (`search_web`, `read_url`, domain tools, `finish`) → agent loops until done → posts result back to the source system. See [patterns/task-triggered-agent.md](patterns/task-triggered-agent.md).

When in doubt, ask the user which shape fits. Most "check X every Y and do Z" requests are #1. Most "when someone does X in [SaaS tool]" requests are #2.

## Workflow (run this, in order)

### 1. Clarify the outcome (plan mode, always)

Before writing a line of code, confirm:

- **Trigger** — cron interval, webhook, manual task creation, something else?
- **Source** — where does data come from? (YouTube channel, ClickUp list, RSS, API, inbox)
- **Unit of work** — what's one "item"? (one video, one task, one row) → this is the idempotency key
- **Agent tools** — does it need to browse the web, call APIs, generate images, write files?
- **Output destination** — where does the result land? (ClickUp comment, Slack message, Notion page, email)
- **Failure mode** — what should happen when the agent fails? Retry? Ping a human?

Ask these as a single `AskUserQuestion` block if any are missing. Don't build until all six are answered.

### 2. Pick the pattern

Map the answers to either `patterns/scheduled-poller.md` or `patterns/task-triggered-agent.md`. If the answer is "both" (poller that spawns an agent), use both — the poller triggers the agent task.

### 3. Scaffold the project

If no trigger.dev project exists in the cwd yet, run the bootstrap from [stack/trigger-dev-setup.md](stack/trigger-dev-setup.md). If one exists, extend it — don't create a new one per automation.

### 4. Write the task files

Use the templates in `patterns/` as starting points. The key APIs:

```ts
import { task, schedules, idempotencyKeys, logger } from "@trigger.dev/sdk";
```

- `schedules.task({ id, cron, run })` — cron-driven
- `task({ id, run, retry })` — normal task, triggered by another task or from your app
- `idempotencyKeys.create(key)` → pass to `otherTask.trigger(payload, { idempotencyKey })` to make the child run at most once per key

### 5. Wire integrations

For each integration mentioned, check `stack/` for a reference file:
- [stack/claude-skills.md](stack/claude-skills.md) — **invoke any of the 191 claude-stack skills** from a trigger.dev task via the Anthropic API (`invokeSkill` helper, multi-skill pipeline examples)
- [stack/skills-catalog.md](stack/skills-catalog.md) — full catalog of all 191 skills by use case — pick the right skill for each automation step
- [stack/clickup-integration.md](stack/clickup-integration.md) — task create/update/comment + list watching
- [stack/kie-ai-images.md](stack/kie-ai-images.md) — Nano Banana Pro image generation + polling
- [stack/youtube-source.md](stack/youtube-source.md) — channel polling + transcript fetch

If an integration isn't in `stack/`, write a new reference file for it before embedding logic in the task. See [CONTRIBUTING.md](CONTRIBUTING.md).

### 6. Run in dev, then ship

```bash
npx trigger.dev@latest dev
```

Create one test trigger from the UI. Verify the run graph in trigger.dev's dashboard — every step should be visible. Only after a green dev run, ask the user before pushing:

```bash
npx trigger.dev@latest deploy
```

## Guardrails (always apply)

See [guardrails.md](guardrails.md) for the long version. Non-negotiable rules:

1. **Plan mode first.** Never skip clarifying questions — the video specifically calls out scoping drift as the #1 failure mode.
2. **Every external item gets an idempotency key.** No exceptions. Use the natural ID (video ID, task ID, email message-id). Pollers will re-fire; idempotency stops double-processing.
3. **Polling loops need a max-attempts + backoff.** External APIs (image gen, transcription) can stall. Bound the wait.
4. **Run what builds.** After scaffolding, actually execute a dev run before claiming done. The video explicitly warns: "always run what builds" to catch hallucinated APIs.
5. **Wire error notifications before production.** At minimum, a Slack or email hook on `onFailure`. Silent failures at 2am are the classic post-build trap.

## Prompt templates

Copy-paste starters for the user's first prompt to Claude Code, once the skill has gathered requirements. See `prompts/`:
- [prompts/scaffold-poller.md](prompts/scaffold-poller.md)
- [prompts/scaffold-agent.md](prompts/scaffold-agent.md)

## Examples

Real builds from the source video, fully spec'd:
- [examples/youtube-digest.md](examples/youtube-digest.md) — poll a channel every 8h, summarize new videos, post to ClickUp
- [examples/company-researcher.md](examples/company-researcher.md) — ClickUp task with a company name → research agent → competitive brief back on the task
- [examples/linkedin-content.md](examples/linkedin-content.md) — ClickUp task with a topic → research + post + infographic via Nano Banana Pro
