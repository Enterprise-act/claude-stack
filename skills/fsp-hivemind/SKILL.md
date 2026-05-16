# FSP Hivemind

Trigger: `/fsp-hivemind` or when asked to "synthesize sessions", "what are we pattern-matching on", or "what should we skill up on".

## What this system does automatically (no action needed)

Every Claude session now self-logs:

1. **Tool trace capture** — While you work, a background hook records which tools Claude calls (Bash, Edit, WebSearch, GitHub, etc.) to a local file. You never see this; it's silent.

2. **Auto session log** — When your session ends, the Stop hook extracts the last assistant response as a summary and prepends the tool-call counts (e.g. `[Bash×4, Edit×3, WebSearch×1]`). This posts automatically to the FSP Brain — no typing required.

3. **Weekly synthesis** — Every Monday at 9 AM, an n8n workflow queries the last 7 days of activity, asks Claude to identify the top recurring workflows, and posts drafted `SKILL.md`s to `#claude-stack` for Mark to review and ship.

## What you can do manually

### Check what was captured this week
Use the FSP Brain MCP recall tool to see recent activity:
```
fsp_recall("last week sessions")
fsp_get_team_activity()
```

### Trigger synthesis early
If you want to synthesise before Monday, ask Claude:
> "Look at the recent FSP activity log and draft skills for any workflows that appear 3+ times."

Claude will query the brain and produce the same output the n8n workflow would.

### Review and ship a drafted skill
When you see a skill draft in `#claude-stack`:
1. Copy the `SKILL.md` content into a new `skills/<skill-name>/SKILL.md` file
2. Commit and push
3. Staff get it on their next `claude-update`

## How the session-end hook extracts the summary

It reads the `transcript` array Claude Code provides to the Stop hook — no AI call, no
network, just JSON parsing. The last assistant message is trimmed to 400 characters.
If the session ended mid-task (not `end_turn`), nothing is logged.

## Disabling for a session

Set `FSP_HIVEMIND_SKIP=1` before starting Claude:
```bash
FSP_HIVEMIND_SKIP=1 claude
```

The hooks check this variable and exit silently if set.

## Files involved

| File | Role |
|------|------|
| `config/hooks/fsp-session-end.sh` | Stop hook — auto-logs every session |
| `config/hooks/fsp-trace-capture.sh` | PostToolUse hook — traces tool calls |
| `config/hooks/fsp-prompt-quality.sh` | UserPromptSubmit hook — injects FSP quality standards |
| `~/.claude/.fsp-trace-{session_id}.jsonl` | Temporary trace buffer (deleted at session end) |
| n8n workflow `fsp-skill-synthesis` (ID: WN0MZ1cXSmeK0Qgm) | Weekly synthesis → `#claude-stack` |
