# Claude AI Setup Guide — Full Service Pros Staff
### Get the same Claude setup as Mark in 5 steps

---

## Before you start

You need two things:
- A **Mac or PC running macOS or Windows** (most of this is Mac — ask Mark if you're on Windows)
- **30 minutes** the first time

---

## Step 1 — Get a Claude Account

1. Go to **[claude.ai](https://claude.ai)**
2. Sign up with your **work email** (e.g. yourname@fullservicepros.net)
3. Choose a paid plan — **Claude Pro ($20/mo)** is the minimum to get full access
   - Ask Mark if the company is covering this cost
4. Log in and make sure you can chat with Claude before moving on

---

## Step 2 — Install Node.js

Node.js is a small program that lets you run Claude Code on your computer.

1. Go to **[nodejs.org](https://nodejs.org)**
2. Click the big green **"LTS"** download button
3. Open the downloaded file and follow the installer (just click Next/Continue through everything)
4. When it's done, open **Terminal** (Mac: press `Cmd + Space`, type "Terminal", hit Enter)
5. Type this and press Enter to verify it worked:
   ```
   node --version
   ```
   You should see something like `v22.0.0` — any number is fine

---

## Step 3 — Run the FSP Installer

This one command sets up everything: Claude Code, all 196 skills, and the update tool.

1. Open **Terminal**
2. Copy and paste this entire line, then press Enter:
   ```
   curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.sh | bash
   ```
3. Wait about 2–3 minutes while it installs
4. You'll see green checkmarks as each step completes
5. When you see **"Done!"** — you're set

> **Stuck?** Screenshot the Terminal and send it to Mark.

---

## Step 4 — Bookmark the Team Repo

The FSP Claude stack is hosted publicly at **[github.com/carrmjw/claude-stack](https://github.com/carrmjw/claude-stack)**. No GitHub account needed — you can browse skills and updates there any time.

If you want to be notified when Mark pushes new skills:
1. Create a free GitHub account at **[github.com](https://github.com)** (use your work email)
2. Go to **[github.com/carrmjw/claude-stack](https://github.com/carrmjw/claude-stack)**
3. Click **Watch → All Activity** in the top-right corner

---

## Step 5 — Connect Your Integrations

This is what gives Claude access to your Slack, Gmail, Calendar, and other tools.

1. Go to **[claude.ai/settings/integrations](https://claude.ai/settings/integrations)**
2. Connect each tool you use:
   - **Gmail** — click Connect, sign in with your work Google account
   - **Google Calendar** — same login as Gmail
   - **Slack** — click Connect, sign into the FSP Slack workspace
3. That's it — Claude can now read and send on your behalf when you ask it to

---

## Step 6 — Start Claude Code

1. Open **Terminal**
2. Type `claude` and press Enter
3. Claude Code will open — you're ready to go

---

## Staying Up to Date

When Mark builds new skills or automations, you'll get a Slack message. To update, just open Terminal and run:

```
claude-update
```

Takes about 30 seconds. Your personal settings are never touched.

---

## Quick Reference

| What | How |
|---|---|
| Start Claude Code | Open Terminal → type `claude` |
| Get latest skills | Open Terminal → type `claude-update` |
| Claude web chat | [claude.ai](https://claude.ai) |
| Team GitHub | [github.com/carrmjw/claude-stack](https://github.com/carrmjw/claude-stack) |
| Integrations | [claude.ai/settings/integrations](https://claude.ai/settings/integrations) |

---

## Need Help?

Slack Mark or Jordan. Include a screenshot of your Terminal if something went wrong.
