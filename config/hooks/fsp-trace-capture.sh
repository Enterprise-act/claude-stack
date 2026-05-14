#!/bin/bash
# FSP Brain — Tool Trace Capture Hook (PostToolUse event)
# Silently records signal-bearing tool calls to a local JSONL file during each session.
# The session-end Stop hook reads this file, prepends a usage summary, then deletes it.
# No network calls — zero latency impact on Claude's responses.

# Honour explicit skip request
[ "${FSP_HIVEMIND_SKIP:-0}" = "1" ] && exit 0

# Only capture tools that reveal meaningful work patterns
PAYLOAD=$(cat)
TOOL=$(echo "${PAYLOAD}" | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

case "${TOOL}" in
  Bash|Write|Edit|WebSearch|WebFetch|Agent) ;;
  mcp__github__*) ;;
  *) exit 0 ;;
esac

# Extract session_id — falls back to "default" if not present in payload
SESSION_ID=$(echo "${PAYLOAD}" | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('session_id','default'))" 2>/dev/null \
  || echo "default")

TRACE_FILE="${HOME}/.claude/.fsp-trace-${SESSION_ID}.jsonl"
mkdir -p "${HOME}/.claude"

python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
print(json.dumps({'t': d.get('tool_name'), 'ts': datetime.datetime.utcnow().isoformat()}))
" <<< "${PAYLOAD}" >> "${TRACE_FILE}" 2>/dev/null || true

exit 0
