#!/usr/bin/env bash
# download-settings.sh — Download and apply the FSP settings.json template
#
# Downloads config/settings.json.template from the FSP stack and merges it
# into ~/.claude/settings.json, preserving any MCP servers and hooks already
# wired by the installer or registered manually.
#
# Usage:
#   bash ~/.claude/fsp-stack/scripts/download-settings.sh
#   bash ~/.claude/fsp-stack/scripts/download-settings.sh --reset
#
# Flags:
#   --reset    Overwrite settings.json completely with the template (removes
#              any custom entries). You will need to re-run install.sh after
#              to re-wire MCPs and hooks.

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
STACK_DIR="${CLAUDE_DIR}/fsp-stack"
TEMPLATE="${STACK_DIR}/config/settings.json.template"
REPO="https://github.com/carrmjw/claude-stack.git"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }

RESET_MODE=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET_MODE=1 ;;
    --help|-h)
      cat <<EOF
Usage: bash download-settings.sh [--reset]

  (default)  Merge template permissions into existing settings.json,
             preserving mcpServers and hooks already registered.
  --reset    Overwrite settings.json with the template from scratch.
             MCPs and hooks will need to be re-wired (re-run install.sh).
EOF
      exit 0 ;;
    *) fail "Unknown argument: $arg. Run with --help for usage." ;;
  esac
done

echo ""
echo "  FSP — Download System Settings"
echo "  ================================"
echo ""

# Ensure stack is cloned
if [ ! -d "${STACK_DIR}/.git" ]; then
  fail "FSP stack not found at ${STACK_DIR}. Run installer first:\n  curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.sh | bash"
fi

# Verify the remote is the expected repo
ACTUAL_REMOTE=$(git -C "${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
if [ "${ACTUAL_REMOTE}" != "${REPO}" ]; then
  fail "Remote mismatch: expected '${REPO}', found '${ACTUAL_REMOTE}'. Aborting."
fi

# Pull latest stack
git -c core.hooksPath=/dev/null -C "${STACK_DIR}" fetch --quiet origin main
if ! git -c core.hooksPath=/dev/null -C "${STACK_DIR}" merge --ff-only --quiet FETCH_HEAD; then
  warn "Cannot fast-forward. Run: git -C ${STACK_DIR} pull"
else
  ok "Stack at $(git -C "${STACK_DIR}" rev-parse --short HEAD)"
fi

# Verify template exists after pull
if [ ! -f "${TEMPLATE}" ]; then
  fail "Template not found: ${TEMPLATE}"
fi

# Safety: never follow symlinks for settings.json
if [ -L "${SETTINGS}" ]; then
  fail "${SETTINGS} is a symlink — aborting to prevent writing to unexpected location."
fi

mkdir -p "${CLAUDE_DIR}"

if (( RESET_MODE == 1 )); then
  # --reset: overwrite entirely with the template (strip __comment key)
  python3 - "${TEMPLATE}" "${SETTINGS}" << 'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    tmpl = json.load(f)
tmpl.pop("__comment", None)
with open(dst, "w") as f:
    json.dump(tmpl, f, indent=2)
PYEOF
  chmod 600 "${SETTINGS}"
  ok "settings.json reset to FSP template"
  warn "MCPs and hooks have been cleared — re-run install.sh to re-wire them."
else
  # Default: merge — apply template permissions, keep existing mcpServers + hooks
  python3 - "${TEMPLATE}" "${SETTINGS}" << 'PYEOF'
import json, sys, os

src, dst = sys.argv[1], sys.argv[2]

with open(src) as f:
    tmpl = json.load(f)
tmpl.pop("__comment", None)

try:
    with open(dst) as f:
        existing = json.load(f)
except FileNotFoundError:
    existing = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {dst} has invalid JSON ({e}). Fix it manually before re-running.")

# Merge permissions.allow — union, deduplicated, order preserved
tmpl_allow = tmpl.get("permissions", {}).get("allow", [])
existing_allow = existing.get("permissions", {}).get("allow", [])
merged_allow = list(dict.fromkeys(existing_allow + [a for a in tmpl_allow if a not in existing_allow]))

# Merge permissions.deny — keep existing entries
existing_deny = existing.get("permissions", {}).get("deny", [])

# Preserve mcpServers and hooks from existing settings
result = {
    "permissions": {
        "allow": merged_allow,
        "deny": existing_deny,
    },
    "hooks": existing.get("hooks", tmpl.get("hooks", {})),
    "mcpServers": existing.get("mcpServers", tmpl.get("mcpServers", {})),
}

# Carry over any other top-level keys from existing settings not covered above
for k, v in existing.items():
    if k not in result:
        result[k] = v

with open(dst, "w") as f:
    json.dump(result, f, indent=2)
os.chmod(dst, 0o600)

added = [a for a in tmpl_allow if a not in existing_allow]
if added:
    print(f"  Added {len(added)} permission(s) from template")
else:
    print("  Permissions already up to date")
PYEOF
  ok "settings.json updated (mcpServers and hooks preserved)"
fi

echo ""
ok "Done. View your settings: cat ${SETTINGS}"
echo ""
