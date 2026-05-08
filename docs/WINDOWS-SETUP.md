# FSP Claude Stack — Windows Setup Guide

> Written by Claude after Jordan surfaced this gap. Validated against install.sh source.
> Jordan: if you hit anything not covered here, open a PR — you offered, and we're counting on it.

---

## Two paths

| | WSL2 (recommended) | Native PowerShell |
|---|---|---|
| **Works on** | Win10 v2004+, Win11 | Win10, Win11 |
| **Effort** | ~20 min one-time WSL setup | ~5 min |
| **Compatibility** | 100% — runs install.sh as-is | 99% — install.ps1 port |
| **voice-jarvis / notify** | Win11 WSLg only | Not supported |
| **Claude in Chrome ext** | Windows-side Chrome | Windows-side Chrome |
| **When to pick** | First-time setup, dev work | Corp image without WSL, quick bootstrap |

**If you're Jordan or any first-time Windows staff: use Path A (WSL2).**

---

## Path A — WSL2 (runs install.sh natively)

### Step 1 — Enable WSL2

Open PowerShell **as Administrator**:

```powershell
winver   # confirm Win10 v2004+ (build 19041+) or Win11
wsl --install
# Reboot when prompted
```

After reboot, Ubuntu opens automatically. Set a username and password.

### Step 2 — Update Ubuntu and install prerequisites

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential ca-certificates unzip
```

### Step 3 — Install Node.js via nvm

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts && nvm use --lts
node --version   # confirm e.g. v22.x
```

### Step 4 — Install Claude Code CLI inside WSL

```bash
npm install -g @anthropic-ai/claude-code
claude --version   # confirm it responds
```

### Step 5 — Log in

```bash
claude login
# Use your FSP email: yourname@fullservicepros.net
# NOT carrmjw@gmail.com — that's Mark's personal Codex seat
```

### Step 6 — Run the FSP installer

```bash
curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.sh | bash
```

### Step 7 — Add your API keys

```bash
nano ~/.claude/.env
# Add N8N_MCP_TOKEN and any other keys Mark shares with you
```

### Step 8 — Install Refero MCP

```bash
claude mcp add refero -- npx -y refero-mcp
npx skills add refero/refero-mcp --yes --global
```

### Step 9 — Verify

```bash
claude --version
ls ~/.claude/skills/        # should list FSP skills
claude mcp list             # should show github, context7, memory, playwright, etc.
claude                      # start a session → type /gsd-help → should respond
```

---

## Filesystem rule (important)

**All FSP work lives in `/home/<you>/` — never `/mnt/c/`.**

WSL2 mounts your Windows C: drive at `/mnt/c/`, but I/O across the boundary is
10× slower and breaks `chmod`/symlink operations. Keep everything native Linux:

```
✅ /home/jordan/.claude/        ← Claude config, skills, hooks
✅ /home/jordan/Desktop/Claude/ ← project work
❌ /mnt/c/Users/jordan/...      ← slow, symlink-hostile
```

---

## FSP-specific gotchas

### voice-jarvis + notify skills
- **Windows 11 + WSLg** (kernel ≥ 5.15): audio works natively.
- **Windows 10**: PulseAudio passthrough required (non-trivial). Skip for now.

```bash
echo $DISPLAY   # :0 or similar = WSLg active; empty = no audio
```

If `$DISPLAY` is empty, voice skills silently fail — everything else works fine.

### Claude in Chrome extension
Install in **Windows-side Chrome**, not inside WSL. The CLI in WSL connects to
it over localhost automatically.

### claude-update
```bash
claude-update   # identical in WSL2 bash
```

### Codex (/codex:review)
Use `yourname@fullservicepros.net` for `claude login`.
`carrmjw@gmail.com` is Mark's personal ChatGPT Pro seat — not shareable.

---

## Path B — Native PowerShell (no WSL2 required)

### Step 1 — Prerequisites

| Tool | Download |
|------|----------|
| Node.js (LTS) | https://nodejs.org |
| Git for Windows | https://git-scm.com |
| Python 3.x | https://python.org or Microsoft Store |

### Step 2 — Allow script execution (one time, as Administrator)

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

### Step 3 — Download, review, then run the installer

```powershell
# Download first so you can inspect it
iwr -OutFile install.ps1 https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.ps1
notepad install.ps1   # review the script before running

# Then run it
.\install.ps1
```

> **Why not `iwr | iex` directly?**
> `iwr | iex` executes remote code without saving a local copy first. Combined
> with an unpinned `main` branch, it means any commit to the repo runs on your
> machine automatically. Download-then-inspect gives you a chance to verify.
> Once Mark sets `$PINNED_SHA` in the script (pointing to a known-good SHA),
> the risk drops significantly — the script will refuse to run if the fetched
> commit doesn't match.

### Step 4 — Log in

```powershell
claude login
# Use yourname@fullservicepros.net
```

### Step 5 — Add your API keys

Open `%USERPROFILE%\.claude\.env` in Notepad or VS Code.

### Step 6 — Add claude-update to PATH (one time)

```powershell
[Environment]::SetEnvironmentVariable(
    'PATH',
    $env:PATH + ';' + (Join-Path $env:USERPROFILE '.local\bin'),
    'User'
)
# Restart PowerShell, then:
claude-update.ps1
```

### Step 7 — Verify

```powershell
claude --version
ls $env:USERPROFILE\.claude\skills\
claude mcp list
claude   # /gsd-help should respond
```

---

## Staying up to date

```bash
# WSL2:
claude-update

# PowerShell:
claude-update.ps1
```

---

## Known gaps

| Feature | WSL2 | Native PS | Notes |
|---------|------|-----------|-------|
| voice-jarvis | Win11 WSLg only | ✗ | Audio passthrough required |
| notify (TTS) | Win11 WSLg only | ✗ | Same audio requirement |
| claude-backup.sh | ✅ | ✗ | No PS port yet |
| All skills | ✅ | ✅ | Pure markdown |
| All MCP integrations | ✅ | ✅ | Node/npm-based |
| Claude in Chrome | ✅ (Windows Chrome) | ✅ | |
| claude-update | ✅ | ✅ (.ps1) | |

---

## Contributing

Hit something not in this guide? Open a PR against `docs/WINDOWS-SETUP.md`.
