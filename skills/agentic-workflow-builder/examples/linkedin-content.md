# Example: ClickUp topic → LinkedIn post + infographic

Video reference: the live-built demo in the second half of [ZeJXI2MAhj0](https://youtu.be/ZeJXI2MAhj0).

## What it does

User drops a topic as a new task in a ClickUp "LinkedIn Content Q" list. An agent researches the topic, writes a thought-leadership first-person LinkedIn post, generates a matching infographic via kie.ai Nano Banana Pro, and posts both back as a comment on the original task.

## Spec

- **Pattern**: [task-triggered-agent](../patterns/task-triggered-agent.md) + [polling-external-api](../patterns/polling-external-api.md)
- **Trigger**: `cron: "*/2 * * * *"`
- **Source**: ClickUp list (env: `CLICKUP_LINKEDIN_LIST_ID`)
- **Idempotency key**: `clickup-task:<taskId>`
- **Agent tools**: `search_web`, `read_url`, `generate_infographic`, `finish`
- **Max steps**: 15 (research + write + image = roughly 5–10 tool calls)
- **Output**: ClickUp comment with post text + infographic URL

## Phases inside the agent

1. **Research** — 2–4 `search_web` + `read_url` calls to gather stats and examples
2. **Write** — generate the LinkedIn post (first person, thought-leadership tone, 200–350 words)
3. **Infographic** — call `generate_infographic` with a prompt that includes verbatim stats from the post
4. **Poll** — `generate_infographic` blocks on the kie.ai polling loop (see [polling-external-api](../patterns/polling-external-api.md))
5. **Finish** — post comment + mark complete

## Gotchas the demo hit (so you don't)

- **Interval too short**: initial poll interval on the infographic was 2s; the logs were unreadable. Use 5–10s.
- **ClickUp 401 "expected ID"**: the agent called ClickUp with the list *name* instead of the list *ID*. Always use numeric IDs.
- **Infographic prompt field shape**: kie.ai's `prompt` field format differs by endpoint version. Keep the wrapper in `src/lib/kie-ai.ts` and pin the version.

Total runtime in the demo: ~2m 23s end to end, with one retry after the first run caught both bugs. The agent self-corrected after seeing the trigger.dev run logs.
