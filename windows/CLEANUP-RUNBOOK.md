# Claude Cleanup — Staff Runbook

Plain-English guide for when something's slow, Claude feels sluggish, or disk space is running low. No admin skills required beyond what's listed.

---

## Quick reference

| Symptom | First action |
|---|---|
| PC is slow / laggy | Run cleanup now (see below) |
| "Low memory" warning | Run cleanup now |
| Claude Desktop slow to respond | Restart Claude Desktop after cleanup |
| Disk space low | Run cleanup, then check results |
| Cleanup script won't open | See [Troubleshooting](#troubleshooting) |

---

## Run cleanup right now (Windows)

1. Find **"Run Claude Cleanup Now"** on your Desktop
2. Double-click it
3. A black terminal window will appear — let it finish (usually 30–60 seconds)
4. When it says **"Cleanup complete"**, you're done

The script logs everything it did to `C:\ProgramData\ClaudeCleanup\logs\`. If you want to see how much space was freed, open the most recent log file there.

---

## Run cleanup right now (Mark's Mac)

Open Terminal and run:

```bash
~/.claude/ops/cleanup/claude-cleanup.sh
```

For a deeper clean (run weekly or when disk is really full):

```bash
~/.claude/ops/cleanup/claude-cleanup.sh --deep
```

---

## When cleanup runs automatically

Cleanup is scheduled to run on its own — you don't need to do anything.

| Time | What runs |
|---|---|
| Every night at 2am | Standard cleanup |
| Every Sunday at 3am | Deep cleanup (clears more cache) |

The machine doesn't need to be awake. If it was off or asleep, cleanup runs the next time it starts up.

---

## What cleanup actually does

**Every night:**
- Closes bloated Claude Helper processes (ones using >800MB RAM for >30 minutes)
- Clears Claude's renderer cache — the temporary files it builds up while you're using it
- Deletes session logs older than 7 days
- Removes temp files Claude left in your TEMP folder

**Every Sunday (deep clean):**
- Everything above, plus:
- Clears the GPU shader cache (can reach 1–2GB over time)
- Clears the JavaScript code cache
- Removes older session storage files

**What it never touches:**
- Your Claude conversations or history
- Your files, documents, or downloads
- Claude settings or preferences
- Any other applications

---

## Troubleshooting

### "The script won't run" / PowerShell execution error

Right-click the desktop shortcut → **Run as administrator**. If that still fails:

1. Press `Win + X` → **Windows PowerShell (Admin)**
2. Paste this and press Enter:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
   ```
3. Try the shortcut again

### "I don't see the desktop shortcut"

The shortcut should be on your Desktop. If it's missing:

1. Press `Win + R`, type `C:\ProgramData\ClaudeCleanup\` and press Enter
2. Right-click `claude-cleanup.ps1` → **Run with PowerShell**

If that folder doesn't exist, the installer hasn't been run yet. Contact Mark.

### Cleanup ran but the PC is still slow

Cleanup handles Claude's own processes. If the machine is still sluggish:

1. Restart the PC — this clears everything cleanup can't reach
2. Check Task Manager (`Ctrl+Shift+Esc`) for other processes using >1GB RAM
3. If it keeps happening, let Mark know — it may need a deeper look

### "Low disk space" warning persists after cleanup

Claude's cache is cleared by cleanup, but other things can fill your disk:

- Windows Update files: run **Disk Cleanup** (search in Start menu) and check "Windows Update Cleanup"
- Downloads folder: check `C:\Users\<you>\Downloads` — large files accumulate there
- Recycle Bin: right-click Recycle Bin → **Empty Recycle Bin**

If you're still under 10GB free after all that, let Mark know.

### Cleanup log says errors

Open the latest log at `C:\ProgramData\ClaudeCleanup\logs\`. Lines marked `⚠` are warnings — cleanup continued but skipped that step. Send the log to Mark if you're not sure what it means.

---

## Re-installing cleanup (if something breaks)

Ask Mark to re-send the install files. Then:

1. Right-click `install-windows-cleanup.ps1` → **Run as administrator**
2. Follow the prompts
3. Done — the old schedule is replaced

---

## Contact

Something not working after following this guide? Send Mark the log file from `C:\ProgramData\ClaudeCleanup\logs\` and describe what you saw.
