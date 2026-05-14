#!/bin/bash
# FSP Brain — Session End Hook (Stop event)
# Fires automatically after every Claude session ends.
# Extracts the summary from the transcript — no user prompt, always logs.
# Requires FSP_BRAIN_URL and FSP_BRAIN_TOKEN in ~/.claude/.env

# Load env
ENV_FILE="${HOME}/.claude/.env"
if [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  set -a; source "${ENV_FILE}"; set +a
fi

# Skip silently if brain not configured or explicitly disabled
[ -z "${FSP_BRAIN_URL:-}" ] || [ -z "${FSP_BRAIN_TOKEN:-}" ] && exit 0
[ "${FSP_HIVEMIND_SKIP:-0}" = "1" ] && exit 0

STAFF_NAME="${FSP_STAFF_NAME:-$(whoami)}"

# Read the hook payload from stdin (Claude Code passes JSON on stdin for Stop hooks)
PAYLOAD=$(cat)

# Only log real session ends
STOP_REASON=$(echo "${PAYLOAD}" | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('stop_reason',''))" 2>/dev/null || echo "")
[ "${STOP_REASON}" = "end_turn" ] || [ -z "${STOP_REASON}" ] || exit 0

# Extract session_id for trace file lookup
SESSION_ID=$(echo "${PAYLOAD}" | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")

# Auto-extract summary from the last assistant message in the transcript
SUMMARY=$(echo "${PAYLOAD}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for msg in reversed(d.get('transcript', [])):
    if msg.get('role') == 'assistant':
        c = msg.get('content', '')
        if isinstance(c, str):
            text = c
        elif isinstance(c, list):
            text = ' '.join(
                x.get('text', '') for x in c
                if isinstance(x, dict) and x.get('type') == 'text'
            )
        else:
            continue
        t = text.strip()[:400]
        if t:
            print(t)
            break
" 2>/dev/null || echo "")

[ -z "${SUMMARY}" ] && SUMMARY="Session completed — $(date '+%Y-%m-%d %H:%M')"

# Prepend tool-call trace counts if a trace file exists for this session
if [ -n "${SESSION_ID}" ]; then
  TRACE_FILE="${HOME}/.claude/.fsp-trace-${SESSION_ID}.jsonl"
else
  # Fallback: find the most recently modified trace file (orphaned session)
  TRACE_FILE=$(ls -t "${HOME}/.claude/.fsp-trace-"*.jsonl 2>/dev/null | head -1 || echo "")
fi

if [ -f "${TRACE_FILE}" ]; then
  COUNTS=$(python3 -c "
import json, sys, collections
counts = collections.Counter()
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        counts[json.loads(line)['t']] += 1
    except Exception:
        pass
if counts:
    print('[' + ', '.join(f'{k}×{v}' for k, v in counts.most_common()) + '] ')
" < "${TRACE_FILE}" 2>/dev/null || echo "")
  SUMMARY="${COUNTS}${SUMMARY}"
  rm -f "${TRACE_FILE}"
fi

# Also clean up any trace files older than 24 h (orphaned from crashed sessions)
find "${HOME}/.claude" -maxdepth 1 -name '.fsp-trace-*.jsonl' -mmin +1440 -delete 2>/dev/null || true

# POST to FSP Brain — unconditional (was conditional on user input before)
curl -sf \
  -X POST \
  -H "Authorization: Bearer ${FSP_BRAIN_TOKEN}" \
  -H "Content-Type: application/json" \
  "${FSP_BRAIN_URL}/log" \
  -d "$(python3 -c "
import json, sys
print(json.dumps({
  'summary': sys.argv[1],
  'staff_name': sys.argv[2]
}))
" "${SUMMARY}" "${STAFF_NAME}")" > /dev/null 2>&1 || true

exit 0
