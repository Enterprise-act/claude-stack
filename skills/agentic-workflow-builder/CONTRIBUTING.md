# Contributing

The skill gets better only when the patterns, integrations, and guardrails get sharper. The highest-leverage contribution is writing a new reference file after you hit something the skill didn't cover.

## What's worth adding

**New integration reference** (`stack/<service>.md`) — if you built something against a service this skill doesn't document. Follow the shape of [stack/clickup-integration.md](stack/clickup-integration.md): auth, minimal wrapper, pitfalls, idempotency key.

**New pattern** (`patterns/<name>.md`) — if you discover a reusable agent shape that isn't scheduled-poller or task-triggered-agent. Examples: webhook-driven agent, human-in-the-loop approval, fan-out / fan-in.

**New example** (`examples/<workflow>.md`) — concrete automation specs people can copy. Point to which pattern + which stack references it uses.

**Guardrail additions** — a new failure mode you hit in production that isn't in [guardrails.md](guardrails.md).

## What NOT to add

- **Full working code**. The skill is a guide for Claude Code; it generates code on demand. Exception: small illustrative snippets in patterns.
- **Raw cookies, tokens, or user-specific IDs**. The repo is public. Use env var names, not values.
- **"Wait, let me try…" narration**. Capture the durable lesson, not the debugging story.

## Format

- Keep files under ~200 lines. Longer ones get ignored.
- Put the core idea in the first paragraph. Everything after is reference.
- Link between files rather than duplicating content.
- Use absolute dates (`2026-04-21`), not relative (`today`, `yesterday`).

## Testing a change

1. Save your file under the skill directory
2. Start a new Claude Code session
3. Trigger the skill with a request that should hit your new file
4. Verify Claude references it

## PR checklist

- [ ] Content is source-specific, not invented
- [ ] No secrets, no PII, no user-specific IDs
- [ ] Links between files use relative paths
- [ ] The file's core claim is falsifiable — a future reader could test it
