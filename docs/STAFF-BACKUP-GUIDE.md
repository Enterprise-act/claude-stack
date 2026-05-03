# How to Back Up Your Claude Setup — FSP Staff Walkthrough

**Audience:** Anyone at Full Service Pros using Claude Code on a work Mac.
**Time:** ~15 min one-time setup, ~5 min per backup after.
**What you get:** A 1–2 GB tarball on your Box account that lets you fully restore your Claude setup if your Mac dies.

> **Heads up:** This guide is friendly to people who've never opened Terminal before. If you're comfortable in a shell, skip to the bottom for the TL;DR command list.

---

## Why bother

Over time Claude accumulates a lot of stuff that's specific to *you*: skills you installed, custom agents for your role, memory of your projects and preferences, scheduled routines, hooks. None of that is in iCloud or Time Machine in a useful way. If you lose your Mac without a backup, you're rebuilding from scratch — that's a full afternoon at minimum.

This guide gives you a one-command backup to your Box account. Run it before any big OS update, before switching computers, or just quarterly.

---

## Before you start — what you need

- [ ] A work Mac with Claude Code installed and logged in
- [ ] An FSP Box account (the one tied to `mark@fullservicepros.net`-style email — same one you use for FSP files)
- [ ] About 15 minutes of attention

You do **not** need to be technical. Every command is in a copy-paste box.

---

## Setup — one time only

### Step 1 — Open Terminal

1. Press `Cmd + Space` (opens Spotlight search)
2. Type `Terminal`
3. Hit `Enter`

A black window appears with a prompt that looks like:

```
yourname@MacBook ~ %
```

That's where you'll paste commands. Click in the window and you can paste with `Cmd + V`.

### Step 2 — Install Homebrew (if you don't already have it)

Type this to check:

```bash
which brew
```

**If you see something like `/opt/homebrew/bin/brew`** → you have it. Skip to Step 3.

**If you see nothing or "brew not found"** → install it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It'll ask for your Mac password. Type it (you won't see characters as you type — that's normal). Press Enter. Wait 3–5 minutes. When it's done, **read the last few lines** — Homebrew sometimes prints two extra commands you need to run to finish setup. Copy-paste them and run them.

### Step 3 — Install rclone

```bash
brew install rclone
```

Wait ~30 seconds. When you see your prompt back, verify:

```bash
rclone --version
```

You should see something starting with `rclone v1.74.0` or higher. ✅

### Step 4 — Connect rclone to your FSP Box

```bash
rclone config
```

You'll be walked through prompts. Type these answers in order:

| Prompt you'll see | What to type |
|---|---|
| `n/s/q>` | `n` |
| `name>` | `box` |
| `Storage>` | `box` |
| `client_id>` | (just press Enter) |
| `client_secret>` | (just press Enter) |
| `box_config_file>` | (just press Enter) |
| `access_token>` | (just press Enter) |
| `box_sub_type>` | `1` |
| `Edit advanced config?` | `n` |
| `Use web browser to automatically authenticate?` | `y` |

**Your browser will open to Box.** Log in with your FSP Box account (the one that ends in `@fullservicepros.net`) and click **Grant Access**.

Back in Terminal you'll see one more prompt:

| Prompt | Type |
|---|---|
| `Yes this is OK` | `y` |
| `e/n/d/r/c/s/q>` | `q` |

Test it worked:

```bash
rclone listremotes
```

You should see `box:` printed. ✅ Setup complete.

### Step 5 — Save the backup script

Ask Mark (or your IT contact) for `claude-backup.sh`. Save it to your Desktop. Then make it runnable:

```bash
chmod +x ~/Desktop/claude-backup.sh
```

---

## Running a backup — every quarter (or before big changes)

Just one command:

```bash
bash ~/Desktop/claude-backup.sh
```

Here's what you'll see — match it against your screen so you know it's working:

```
=== Pre-flight ===
✓ rclone + Box configured
✓ 14 GB free disk

=== Step 1/4: Bundle Claude Code CLI (sanitized) ===
  stripped from .claude.json: ['oauthAccount', 'userID', 'claudeCodeFirstTokenDate']
✓ CLI bundle: 212M  (.claude.json sanitized)
!  ~/.claude/.env included with 11 secrets — keep your Box folder private

=== Step 2/4: Bundle Claude desktop app (sanitized) ===
✓ Desktop app bundle: 1.1G  (cookies + local/session storage stripped)

=== Step 3/4: Bundle peer CLI configs (Codex / IJFW / Gemini) ===
✓ Dotconfigs bundle: 92M (.codex .ijfw .gemini; .codex/auth.json stripped)

=== Step 4/4: Generate restore script ===
✓ Restore script generated

=== Uploading to Box ===
→ claude-cli-2026-XX-XX.tar.gz
Transferred:        212.329 MiB / 212.329 MiB, 100%

→ claude-desktop-2026-XX-XX.tar.gz
Transferred:        1.073 GiB / 1.073 GiB, 100%

→ dotconfigs-2026-XX-XX.tar.gz
Transferred:        92.435 MiB / 92.435 MiB, 100%

→ run-restore.sh
Transferred:        4.5 KiB / 4.5 KiB, 100%

=== Verifying ===
Total objects: 4
Total size: 1.369 GiB

✓ Backup complete.
Box folder: box:claude-backup-2026-XX-XX/
```

If you see the green ✓ marks all the way down and `Backup complete.` at the end → you're done.

**Total time:** ~5 minutes for the bundle, then 5–15 min for upload depending on your connection.

### Variations

| Want to do this | Run this |
|---|---|
| Backup, but skip the desktop app (faster, smaller) | `bash ~/Desktop/claude-backup.sh --small` |
| Backup without API keys (if your Box folder might be shared) | `bash ~/Desktop/claude-backup.sh --no-secrets` |
| See all options | `bash ~/Desktop/claude-backup.sh --help` |

---

## What if something goes wrong?

### "rclone: command not found"

You skipped Step 3. Run `brew install rclone` and try again.

### "Box not configured"

You skipped Step 4. Run `rclone config` and follow the prompts in the table above.

### "Only X GB free. Need ~3 GB"

Empty your Trash, then re-run. Or use `--small` to skip the desktop app bundle (uses less temp space).

### Browser didn't open during Step 4

Run `rclone config` again. When asked "Use web browser to automatically authenticate?", say `n` instead of `y`. It'll print a URL — copy it, paste into your browser manually, log in, and copy the verification code back into Terminal.

### Upload fails partway

Just re-run `bash ~/Desktop/claude-backup.sh`. rclone is resumable — it skips files already uploaded.

### The script printed red ✗ marks

Read the message after the ✗. Common causes:
- Claude is still running (close any open Claude Code terminals; Cmd+Q the desktop app; re-run)
- `.claude/` doesn't exist (you've never run Claude Code — nothing to back up yet)

---

## Restoring on a new Mac (or a Mac that broke)

You'll need:
- Homebrew, rclone, and Box configured (Steps 1–4 above)
- Your FSP Box account login

Then:

```bash
# Find your latest backup
rclone lsd box: | grep claude-backup

# Pick the most recent date and download it
mkdir -p ~/Desktop/restore && cd ~/Desktop/restore
rclone copy "box:claude-backup-YYYY-MM-DD/" . --progress --disable-http2

# Quit Claude Code and the desktop app completely first!
# Then run the restore script (it came in the backup):
bash ~/Desktop/restore/run-restore.sh
```

The restore script:
1. Backs up any existing `.claude/` so nothing is lost
2. Extracts the three bundles
3. Prints next steps

After restore:
1. Launch `claude` → log in
2. Launch the Claude desktop app → log in
3. Visit **claude.ai → Settings → Connectors** → re-authorize each MCP (Gmail, Slack, GitHub, etc.)
4. If you used `--no-secrets` when backing up, manually re-add API keys to `~/.claude/.env`

---

## Important things to know

### Your backup contains some secrets

Even with sanitization, the backup may contain:
- Your `~/.claude/.env` API keys (Slack, OpenAI, etc. — unless you used `--no-secrets`)
- Your custom hooks and any tokens hard-coded in skills

**Keep your Box folder private to you.** Don't share backup tarballs. Don't put them in shared Box folders. Box's per-user permissions handle this by default — just don't override them.

### Don't restore someone else's backup onto your Mac

Backups have hardcoded paths like `/Users/yourname/`. Restoring someone else's onto your Mac will break things. Each person backs up their own.

### What's stripped automatically

For your safety the backup always strips:
- OAuth tokens (`oauthAccount`, `userID` from `.claude.json`)
- Codex auth tokens (`.codex/auth.json`)
- Browser cookies and Local Storage in the desktop app

You'll re-login on restore — that's expected and quick.

---

## TL;DR for technical staff

```bash
# One-time:
brew install rclone
rclone config              # answers: n, box, box, blanks, 1, n, y → browser → y, q

# Per-backup:
chmod +x ~/Desktop/claude-backup.sh
bash ~/Desktop/claude-backup.sh

# Per-restore:
rclone copy "box:claude-backup-YYYY-MM-DD/" ~/Desktop/restore --disable-http2
bash ~/Desktop/restore/run-restore.sh
```

---

## Questions

Ping Mark or post in the FSP Slack `#claude-help` channel.

The backup script (`claude-backup.sh`) is also published in the FSP Claude Stack repo: `github.com/carrmjw/claude-stack` → `scripts/claude-backup.sh` (when Mark publishes it there).
