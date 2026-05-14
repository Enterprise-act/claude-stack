---
name: view-mobile-sessions
description: "List all Claude Code sessions started from a mobile device and view their details on desktop"
argument-hint: "[list | view <session-id> | open <session-id>]"
allowed-tools:
  - Bash
  - Read
---

<objective>
Display all Claude Code sessions that were initiated from a mobile device (claude.ai/code on phone or tablet) so you can review or resume them from your desktop.

Sessions are identified by `entrypoint: remote_mobile` in `~/.claude/sessions/*.json`.

**Subcommands:**
- `list` (default) — Show all mobile sessions in a formatted table
- `view <session-id>` — Print the full conversation transcript for a specific mobile session
- `open <session-id>` — Resume a mobile session in the current desktop context
</objective>

<process>

**Parse $ARGUMENTS first:**

- If $ARGUMENTS is empty or "list": SUBCMD=list
- If $ARGUMENTS starts with "view ": SUBCMD=view, SESSION_ID=remainder (sanitized)
- If $ARGUMENTS starts with "open ": SUBCMD=open, SESSION_ID=remainder (sanitized)
- Otherwise: treat as list

**Session ID sanitization:** Strip any characters not matching `[a-z0-9-]`. Reject IDs longer than 36 chars or containing `..` or `/`. If invalid, output "Invalid session ID." and stop.

---

## LIST subcommand (default)

Run this Python script via Bash:

```python
import json, os, glob, sys
from datetime import datetime, timezone

sessions_dir = os.path.expanduser('~/.claude/sessions/')
projects_dir = os.path.expanduser('~/.claude/projects/')

session_files = sorted(glob.glob(sessions_dir + '*.json'))
mobile_sessions = []

for sf in session_files:
    try:
        d = json.load(open(sf))
        if d.get('entrypoint') != 'remote_mobile':
            continue

        session_id = d.get('sessionId', '')
        cwd = d.get('cwd', '')
        started_ms = d.get('startedAt', 0)
        version = d.get('version', '?')

        # Convert cwd to project directory name (replace / with -, keep leading -)
        proj_key = cwd.replace('/', '-')
        if not proj_key:
            proj_key = '-'

        # Find JSONL conversation file
        jsonl_path = os.path.join(projects_dir, proj_key, session_id + '.jsonl')
        first_message = '(no transcript)'
        if os.path.exists(jsonl_path):
            with open(jsonl_path) as fh:
                for line in fh:
                    try:
                        entry = json.loads(line)
                        if entry.get('type') == 'user' and not entry.get('isSidechain'):
                            msg = entry.get('message', {})
                            content = msg.get('content', '')
                            if isinstance(content, list):
                                for c in content:
                                    if isinstance(c, dict) and c.get('type') == 'text':
                                        first_message = c.get('text', '').strip()
                                        break
                            elif isinstance(content, str):
                                first_message = content.strip()
                            if first_message:
                                break
                    except:
                        pass

        # Truncate long messages for table display
        preview = (first_message[:60] + '…') if len(first_message) > 60 else first_message

        # Format timestamp
        if started_ms:
            dt = datetime.fromtimestamp(started_ms / 1000, tz=timezone.utc)
            date_str = dt.strftime('%Y-%m-%d %H:%M UTC')
        else:
            date_str = 'unknown'

        mobile_sessions.append({
            'id': session_id,
            'cwd': cwd or '(unknown)',
            'date': date_str,
            'version': version,
            'preview': preview,
        })
    except Exception as e:
        pass

if not mobile_sessions:
    print('No mobile sessions found.')
    print('')
    print('Mobile sessions appear when you use Claude Code at claude.ai/code on a phone or tablet.')
    sys.exit(0)

# Print table
print('')
print('Mobile Sessions (claude.ai/code on phone/tablet)')
print('─' * 80)
print(f'  {"Date":<22} {"Version":<10} {"Project":<22} {"First Message"}')
print('─' * 80)
for s in mobile_sessions:
    project = os.path.basename(s['cwd']) if s['cwd'] != '(unknown)' else '(unknown)'
    project = (project[:20] + '…') if len(project) > 20 else project
    print(f'  {s["date"]:<22} {s["version"]:<10} {project:<22} {s["preview"]}')
print('─' * 80)
print(f'  {len(mobile_sessions)} mobile session(s) found')
print('')
print('  Commands:')
for s in mobile_sessions:
    print(f'    /view-mobile-sessions view {s["id"]}   — full transcript')
    print(f'    /view-mobile-sessions open {s["id"]}   — resume this session')
print('')
```

Run the script and display the output. STOP after displaying.

---

## VIEW subcommand

When SESSION_ID is set (sanitized), run:

```python
import json, os, sys
from datetime import datetime, timezone

session_id = 'SESSION_ID_PLACEHOLDER'
sessions_dir = os.path.expanduser('~/.claude/sessions/')
projects_dir = os.path.expanduser('~/.claude/projects/')

# Find session metadata
import glob
meta = None
for sf in glob.glob(sessions_dir + '*.json'):
    try:
        d = json.load(open(sf))
        if d.get('sessionId') == session_id:
            meta = d
            break
    except:
        pass

if not meta:
    print(f'Session not found: {session_id}')
    sys.exit(1)

if meta.get('entrypoint') != 'remote_mobile':
    print(f'Session {session_id} is not a mobile session (entrypoint: {meta.get("entrypoint")})')
    sys.exit(1)

cwd = meta.get('cwd', '')
proj_key = cwd.replace('/', '-') if cwd else '-'
jsonl_path = os.path.join(projects_dir, proj_key, session_id + '.jsonl')

started_ms = meta.get('startedAt', 0)
if started_ms:
    dt = datetime.fromtimestamp(started_ms / 1000, tz=timezone.utc)
    date_str = dt.strftime('%Y-%m-%d %H:%M UTC')
else:
    date_str = 'unknown'

print('')
print(f'Mobile Session: {session_id}')
print(f'Started:  {date_str}')
print(f'Project:  {cwd or "(unknown)"}')
print(f'Version:  {meta.get("version", "?")}')
print('─' * 70)
print('CONVERSATION TRANSCRIPT')
print('─' * 70)

if not os.path.exists(jsonl_path):
    print('(no transcript file found)')
    sys.exit(0)

msg_count = 0
with open(jsonl_path) as fh:
    for line in fh:
        try:
            entry = json.loads(line)
            if entry.get('isSidechain'):
                continue
            t = entry.get('type')
            if t not in ('user', 'assistant'):
                continue

            role = entry.get('message', {}).get('role', t).upper()
            content = entry.get('message', {}).get('content', '')

            if isinstance(content, list):
                text_parts = []
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text_parts.append(c.get('text', ''))
                    elif isinstance(c, dict) and c.get('type') == 'tool_use':
                        text_parts.append(f'[Tool: {c.get("name", "unknown")}]')
                text = '\n'.join(text_parts).strip()
            else:
                text = str(content).strip()

            if not text:
                continue

            print(f'\n[{role}]')
            # Cap very long messages for readability
            if len(text) > 1000:
                print(text[:1000] + '\n… (truncated, ' + str(len(text)) + ' chars total)')
            else:
                print(text)
            msg_count += 1
        except:
            pass

print('')
print('─' * 70)
print(f'{msg_count} messages in transcript')
print('')
```

Replace `SESSION_ID_PLACEHOLDER` with the sanitized session ID before running. Display all output. STOP after displaying.

---

## OPEN subcommand

When SESSION_ID is set (sanitized):

1. Verify the session exists and is a mobile session using the same lookup as VIEW.
2. Read the session's `cwd` from the metadata.
3. Print:
   ```
   Opening mobile session {session-id}
   Project: {cwd}
   
   To resume this session's work, use:
     /gsd-resume-work
   
   Or navigate to the project:
     cd {cwd}
   ```
4. If the project directory exists on this machine, `cd` into it and run `/gsd-resume-work`.
5. If the directory does not exist, print:
   ```
   Note: Project path {cwd} does not exist on this machine.
   The session was started in a different environment.
   You can still review the transcript with:
     /view-mobile-sessions view {session-id}
   ```

STOP after handling.

</process>

<security_notes>
- Session IDs from $ARGUMENTS are sanitized: only [a-z0-9-] allowed, max 36 chars, reject ".." and "/"
- All file paths are constructed using os.path.join with validated components — never via string interpolation into shell commands
- Session content is displayed as plain text only — never eval'd or executed
- The skill only reads from ~/.claude/ — it does not write, modify, or delete any session data
</security_notes>

<notes>
- Mobile sessions are identified by `entrypoint: remote_mobile` in the session metadata file
- Session metadata lives in `~/.claude/sessions/{pid}.json`
- Conversation transcripts live in `~/.claude/projects/{encoded-cwd}/{sessionId}.jsonl`
- The encoded CWD replaces `/` with `-` and strips the leading `/`
- This skill is read-only — it does not modify any session data
</notes>
