# Full Service Pros — Claude Stack

Central source of truth for the FSP team's Claude Code setup.
Managed by Mark. Staff pull updates with one command.

---

## For staff: getting set up

**Prerequisites:** macOS or Linux, [Node.js](https://nodejs.org) installed.

**Step 1 — Run the installer** (one time only):
```bash
curl -fsSL https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.sh | bash
```

This will:
- Install Claude Code CLI
- Install 196 skills into `~/.claude/skills/`
- Install plugins (everything-claude-code, codex, ijfw)
- Create `~/.claude/CLAUDE.md` with team defaults
- Add the `claude-update` command

**Step 2 — Add your API keys:**
```bash
open ~/.claude/.env
```
Fill in your personal keys (Slack, Gmail, etc.). Each person has their own.

**Step 3 — Connect your integrations:**
Go to [claude.ai/settings/integrations](https://claude.ai/settings/integrations) and connect:
- Gmail
- Slack
- Calendar
- Any others you use

**Step 4 — Start Claude Code:**
```bash
claude
```

---

## Staying up to date

When Mark ships new skills or automations, run:
```bash
claude-update
```

That's it. Your personal settings and CLAUDE.md are never touched.

---

## For Mark: pushing updates

1. Add/edit skills in `skills/`
2. Commit and push to `main`
3. Slack the team to run `claude-update`

```bash
git add skills/
git commit -m "add: new-skill-name"
git push
```

---

## What's included

| Component | What it does |
|---|---|
| `skills/` | 196 Claude Code skills for marketing, ops, dev, content, and more |
| `config/CLAUDE.md.template` | Team-default Claude instructions |
| `config/.env.template` | Personal API key setup guide |
| `install.sh` | One-command setup for new staff |

## What's NOT included (personal — each person sets up their own)

| Component | Where to get it |
|---|---|
| Anthropic account | [claude.ai](https://claude.ai) — paid plan required |
| MCP integrations | [claude.ai/settings/integrations](https://claude.ai/settings/integrations) |
| Personal API keys | Fill into `~/.claude/.env` |
| Voice/Jarvis TTS | Personal ElevenLabs account |

---

## Org: [github.com/Enterprise-act](https://github.com/Enterprise-act)
