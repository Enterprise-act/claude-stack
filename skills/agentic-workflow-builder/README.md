# agentic-workflow-builder

A Claude Code skill for building "agentic workflows" — code-native automations where you describe the outcome in plain English and Claude generates the integration code on top of [trigger.dev](https://trigger.dev), ClickUp, and external APIs (kie.ai, YouTube, etc.). Replaces the n8n / Make / Zapier drag-and-drop approach with something faster for non-trivial flows.

Derived from the strategy in [Stop Learning n8n in 2026…Learn THIS Instead](https://youtu.be/ZeJXI2MAhj0).

## What it gives you

Two reusable agent shapes, codified as Claude Code patterns:

1. **Scheduled poller** — cron → source → idempotency-keyed handoff → worker
2. **Task-triggered agent** — external event (ClickUp/Linear/Notion) → agent loop with small toolset → post result back

Plus reference integrations for trigger.dev, ClickUp, kie.ai's Nano Banana Pro, and YouTube; prompt templates; guardrails distilled from the video's four failure modes (context drift, hallucinated APIs, scoping, post-build ops).

## Install

**Personal / global install (recommended):**

```bash
git clone https://github.com/<you>/agentic-workflow-builder.git ~/.claude/skills/agentic-workflow-builder
```

Claude Code picks up any skill under `~/.claude/skills/<skill-name>/` automatically on next session start. Verify it loaded:

```
/skills list
```

You should see `agentic-workflow-builder` in the output.

**Project-scoped install:**

```bash
git submodule add https://github.com/<you>/agentic-workflow-builder.git .claude/skills/agentic-workflow-builder
```

## Trigger the skill

Claude Code auto-invokes it when you say things like:

- "Build a workflow that checks [source] every [interval]…"
- "Build an agent that runs when [task/webhook] happens…"
- "I want to replace this n8n flow with code"
- "Scaffold a scheduled poller / task-triggered agent"

## Structure

```
SKILL.md                     # main entry — when to invoke + workflow
patterns/
  scheduled-poller.md
  task-triggered-agent.md
  polling-external-api.md
stack/
  trigger-dev-setup.md
  clickup-integration.md
  kie-ai-images.md
  youtube-source.md
guardrails.md
prompts/
  scaffold-poller.md
  scaffold-agent.md
examples/
  youtube-digest.md
  company-researcher.md
  linkedin-content.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). New patterns and integration references are the highest-leverage contribution — if you hit a site/API the skill didn't cover, file what you learned as a new file in `stack/` or `patterns/`.

## License

MIT. See [LICENSE](LICENSE).
