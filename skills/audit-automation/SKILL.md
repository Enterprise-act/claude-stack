---
name: audit-automation
description: Audit all background automation — scheduled tasks, cron jobs, launchd agents, running daemons, hooks, and long-lived processes — and report what's consuming kernel/RAM/Claude budget. Use when the user asks to "audit automation", "what's running", "what's scheduled", "what's eating my usage", "clean up background tasks", or suspects dormant projects are burning resources. Surfaces stale automation tied to DEV/abandoned projects so it can be disabled.
---

# audit-automation — surface every background process burning budget

One command that gives the user the full automation surface area: every scheduled task, cron job, launchd entry, running daemon, hook, and the project each one belongs to. Flags anything tied to a non-LIVE project.

Related: [[CLAUDE]] · section 10 Project Lifecycle Gate

## When to invoke

- User asks: "what's running", "audit automation", "what's scheduled", "what's eating my usage", "clean up background tasks"
- User reports unexpectedly high Claude usage
- Starting a new session on a Mac that feels slow
- After pivoting away from a project (sweep for stale automation)
- Before creating a new scheduled task (check if similar exists)

## What the audit covers

1. **Claude scheduled tasks** (`mcp__scheduled-tasks__list_scheduled_tasks`)
   — name, cadence, enabled state, last run, inferred project
2. **User crontab** (`crontab -l`)
3. **launchd agents** (`launchctl list | grep -v com.apple`)
   — user-installed `~/Library/LaunchAgents/*.plist`
4. **Running background processes** — ports listening (`lsof -iTCP -sTCP:LISTEN`), long-running Python/Node/Ruby on non-standard ports
5. **Claude Code hooks** (`~/.claude/settings.json` + project `settings.json`)
   — SessionStart, PostToolUse, Stop, Notification, SubagentStop
6. **Project status markers** — grep for `STATUS:` in every `CLAUDE.md` under common project roots

## How to run

Step through each check, build a report grouped by project. Flag in **red** anything that is enabled/running and belongs to a project without `STATUS: LIVE`.

```bash
# 1. Running daemons
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -v -E "(127\.0\.0\.1:(5353|5000|7000|7001|3306|5432))" | head -30
ps -eo pid,pcpu,pmem,etime,command | awk '$3 > 1.0 || $2 > 5.0' | head -20

# 2. Crontab
crontab -l 2>/dev/null || echo "no user crontab"

# 3. launchd (user)
launchctl list 2>/dev/null | grep -v -E "^(-|[0-9])[^ ]*\t[^ ]*\tcom\.apple" | head -30
ls -la ~/Library/LaunchAgents/ 2>/dev/null

# 4. Scheduled tasks — use mcp__scheduled-tasks__list_scheduled_tasks
# 5. Hooks — read ~/.claude/settings.json .hooks

# 6. Project STATUS markers
for f in ~/Desktop/Claude/Projects/*/CLAUDE.md ~/Documents/Claude/Projects/*/CLAUDE.md ~/Documents/Claude/Projects/*/*/CLAUDE.md; do
  [ -f "$f" ] || continue
  status=$(grep -m1 -iE '^STATUS:' "$f" || echo "STATUS: (unmarked — treat as DEV)")
  echo "$f → $status"
done
```

## Report format

```
## Automation Audit — YYYY-MM-DD

### 🟢 LIVE project automation (keep)
- <project> → <task/daemon/hook> (<cadence>, last run <time>)

### 🟡 STAGED (disabled, safe)
- <task> — enabled=false, belongs to <project>

### 🔴 DEV/unmarked project with ENABLED automation (review now)
- <task> — <cadence> — <project> is STATUS: DEV → recommend disable
- <running daemon> — PID <x>, <ram>, belongs to <project>

### ⚪ Unattributed (can't match to project)
- <item> — investigate

### Hooks fired every turn
- <hook path> (cost: <shell|node|bash once per X>)

### Recommendations
1. Disable: <list>
2. Kill: <list>
3. Keep: <list>
```

## After the audit

Ask the user per 🔴 group: "Disable these now?" Never auto-disable without confirmation — some may be intentionally dormant. Delete task directories from `~/.claude/scheduled-tasks/` only after explicit "delete" (not "disable").

## 🔒 Protected items — always exclude from the audit

Per CLAUDE.md §10 carve-out, **never list, flag, or recommend removal** of:

- Hooks whose command path contains `/skills/notify/` (stop_hook.sh, notification_hook.sh, subagent_stop_hook.sh)
- Hooks or processes tied to `/skills/voice-jarvis/`
- Kokoro TTS daemon, ElevenLabs cache, or any TTS fallback process
- Any skill/folder named `notify` or `voice-*`

These are user-account infrastructure, not project automation. Silently skip them in every section of the report. If the user asks "what about the voice hooks?", confirm they are intentionally excluded and explain they are protected infrastructure.

## Related rules

Section 10 of `~/.claude/CLAUDE.md` defines the DEV/STAGED/LIVE gate. This skill enforces it retroactively. New automation should never need this skill to clean up — but it exists because the rule didn't exist yet for old projects.
