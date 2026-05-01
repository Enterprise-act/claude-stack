# Guardrails

The four failure modes called out in [the source video](https://youtu.be/ZeJXI2MAhj0), plus the fixes.

## 1. Context drift

**Symptom:** Agent forgets earlier instructions in a long session, references deleted code, reintroduces patterns you just rejected.

**Fix:**
- Start every new workflow build in a fresh session. Don't stack automations in one conversation.
- Keep a `PROJECT.md` at the root of the trigger.dev project summarizing: tasks that exist, tools they use, secrets they need, production deploy status. Read it at the start of every session.
- When a session gets long, summarize the current state into `PROJECT.md` before continuing.

## 2. Hallucinated APIs / code

**Symptom:** Code compiles but references functions, endpoints, or SDK methods that don't exist. Usually surfaces only at runtime.

**Fix:**
- After every scaffold, run `npx trigger.dev@latest dev` and fire a test run. Don't accept "it should work."
- For unfamiliar SDKs, pull docs via Context7 (`mcp__plugin_everything-claude-code_context7__*`) or the `documentation-lookup` skill before writing integration code.
- Add a code-review sub-agent pass before shipping. The video notes this is how big teams catch things humans miss.

## 3. Wrong scope (over- or under-engineered)

**Symptom — overengineered:** a multi-layer framework for a 40-line cron. **Under:** a band-aid that'll break the next time the source API blinks.

**Fix:**
- Always use plan mode for the first pass. Have the agent ask questions before writing.
- Set the six requirements explicitly (see `SKILL.md` step 1) before touching files.
- If the agent proposes adding a framework, a new DB, a message queue, or abstractions beyond trigger.dev itself — stop and ask whether the simpler version is enough.

## 4. No ops surface after ship

**Symptom:** Automation "works" but fails silently at 2am, or runs duplicate work, or is impossible to debug.

**Fix — wire all four before deploying to prod:**

1. **Error notifications.** At minimum: Slack/email on the task's `onFailure`. trigger.dev supports this natively per task.
2. **Observability.** Log every meaningful step. The trigger.dev dashboard is only as useful as the logs you emit.
3. **Idempotency.** Every external item gets a key. See `patterns/scheduled-poller.md`.
4. **Version control.** The task file is just TypeScript in git. Require PRs on production changes to the workflow.

## The pre-deploy checklist

Run this before every `trigger.dev deploy`:

- [ ] Every external-item task has an `idempotencyKey`
- [ ] Every polling loop has a `maxAttempts` bound
- [ ] Every task has `retry.maxAttempts` set (3 for normal, 1 for schedulers)
- [ ] Every task logs step-level structured events (not just start/end)
- [ ] `onFailure` or global error hook notifies a human channel
- [ ] Secrets are in `.env` / trigger.dev env vars, not committed
- [ ] At least one dev run has completed green end-to-end
- [ ] Status updates happen on the source system (ClickUp/Linear) — no silent work
