# Full Service Pros — Claude Stack

Central source of truth for the FSP team's Claude Code setup.
Managed by Mark. Staff pull updates with one command.

---

## For staff: getting set up

**Prerequisites:** [Node.js](https://nodejs.org) and [Git](https://git-scm.com) installed.

**Step 1 — Run the installer** (one time only):
```bash
curl -fsSL https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
# Download and review before running:
iwr -OutFile install.ps1 https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.ps1
notepad install.ps1
.\install.ps1
```

**Windows users:** see [`docs/WINDOWS-SETUP.md`](docs/WINDOWS-SETUP.md) for the full guide (WSL2 recommended; native PS path also available).


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

## Backing up your Claude setup

Once you've used Claude for a while you'll have a personal fingerprint — installed skills, custom agents, memory of your projects, scheduled routines. **None of that is in iCloud or Time Machine.** If your Mac dies without a backup, it's a full afternoon to rebuild.

We provide a one-command backup that uploads your Claude state to your own FSP Box folder. Run it before any big OS update or quarterly.

**Setup:** [`docs/STAFF-BACKUP-GUIDE.md`](docs/STAFF-BACKUP-GUIDE.md) — non-technical walkthrough (~15 min one-time)
**Script:** [`scripts/claude-backup.sh`](scripts/claude-backup.sh) — the backup tool itself

```bash
# After one-time setup (see guide):
bash ~/Desktop/claude-backup.sh
```

Auth tokens and browser session data are stripped automatically. Use `--no-secrets` to also strip your `~/.claude/.env` API keys if your Box folder might be shared.

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
| `install.ps1` | One-command setup — Windows (native PowerShell) |
| `scripts/claude-update.ps1` | Windows update script |
| `docs/WINDOWS-SETUP.md` | Full Windows onboarding guide |

## What's NOT included (personal — each person sets up their own)

| Component | Where to get it |
|---|---|
| Anthropic account | [claude.ai](https://claude.ai) — paid plan required |
| MCP integrations | [claude.ai/settings/integrations](https://claude.ai/settings/integrations) |
| Personal API keys | Fill into `~/.claude/.env` |
| Voice/Jarvis TTS | Personal ElevenLabs account |

---

## Org: [github.com/Enterprise-act](https://github.com/Enterprise-act)
