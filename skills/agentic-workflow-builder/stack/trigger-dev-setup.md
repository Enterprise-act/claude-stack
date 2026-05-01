# trigger.dev setup

First-time bootstrap for a new automation project. Run once per project, not once per automation.

## Install

```bash
npx trigger.dev@latest init
```

This drops a `trigger.config.ts` at the repo root, a `src/trigger/` directory for task files, and wires package.json. Pick TypeScript.

## Required env vars

```bash
# .env (dev) — trigger.dev's CLI will prompt for these
TRIGGER_SECRET_KEY=tr_dev_...
TRIGGER_API_URL=https://api.trigger.dev

# Your integration secrets
CLICKUP_TOKEN=pk_...
KIE_AI_API_KEY=...
OPENAI_API_KEY=sk-...
```

For production, set these in the trigger.dev dashboard under Project → Env Vars. **Never commit them.**

## Run locally

```bash
npx trigger.dev@latest dev
```

Opens the local dashboard. Every task file under `src/trigger/` auto-registers. Firing a test run shows the full execution graph in real time.

## Deploy

```bash
npx trigger.dev@latest deploy
```

Only run after a green dev run. Deploys build the task bundle and register schedules. Schedules do not run in dev unless you explicitly test them.

## File layout convention

```
src/
  trigger/
    youtube-poller.ts        # schedules.task
    summarize-video.ts       # task (worker)
    clickup-poller.ts        # schedules.task
    research-agent.ts        # task (agent)
    content-creator.ts       # task (agent)
  lib/
    clickup.ts               # thin wrapper around ClickUp API
    kie-ai.ts                # Nano Banana Pro wrapper
    agent.ts                 # runAgentLoop — generic agent harness
```

One task per file. The task ID (`id: "..."`) must be unique across the project and stable — it's how trigger.dev tracks schedules and idempotency keys across deploys.

## Global error hook

Add to `trigger.config.ts`:

```ts
import { defineConfig } from "@trigger.dev/sdk";

export default defineConfig({
  project: "proj_...",
  runtime: "node",
  logLevel: "info",
  defaultMachine: "small-1x",
  maxDuration: 3600,
  onFailure: async ({ payload, error, ctx }) => {
    // Send to Slack / PagerDuty / email
    await notifyFailure({ task: ctx.task.id, error: error.message, payload });
  },
});
```

## Reference

Context7: `/websites/trigger_dev`. For any unfamiliar API, query docs before writing code.
