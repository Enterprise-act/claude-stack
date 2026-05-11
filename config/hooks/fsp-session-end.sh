#!/bin/bash
# FSP Brain — Session End Hook (Stop event)
# Fires after Claude finishes responding, prompting staff to log the session.
# Requires FSP_BRAIN_URL and FSP_BRAIN_TOKEN in ~/.claude/.env

# Load env
ENV_FILE="${HOME}/.claude/.env"
if [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  set -a; source "${ENV_FILE}"; set +a
fi

# Skip silently if brain not configured
[ -z "${FSP_BRAIN_URL:-}" ] || [ -z "${FSP_BRAIN_TOKEN:-}" ] && exit 0

STAFF_NAME="${FSP_STAFF_NAME:-$(whoami)}"

# Read the hook payload from stdin (Claude Code passes JSON on stdin for Stop hooks)
PAYLOAD=$(cat)
# Extract the transcript summary if available — otherwise prompt the user
STOP_REASON=$(echo "${PAYLOAD}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('stop_reason',''))" 2>/dev/null || echo "")

# Only log if this was a real session end (not a mid-session tool call stop)
[ "${STOP_REASON}" = "end_turn" ] || [ -z "${STOP_REASON}" ] || exit 0

# Prompt for session summary via stderr (visible in terminal, not sent to Claude)
echo "" >&2
echo "─────────────────────────────────────────" >&2
echo "  FSP Brain: What did you accomplish?" >&2
echo "  (2 sentences max — press Enter to skip)" >&2
echo "─────────────────────────────────────────" >&2

# Read from /dev/tty so it works even when stdin is the hook payload
read -r -t 30 SUMMARY < /dev/tty 2>/dev/null || SUMMARY=""

[ -z "${SUMMARY}" ] && exit 0

# POST to FSP Brain log-activity endpoint via MCP tool call pattern
# We call the REST API directly since we're in a shell hook
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

# No output on success — keep it clean
exit 0
