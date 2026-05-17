#!/usr/bin/env bash
# download-settings.sh — sync FSP Claude Code settings (MCP servers + hooks)
#
# Applies the team's standard settings.json entries without touching skills,
# CLAUDE.md, or other installed files. Safe to re-run — all operations are idempotent.
#
# Usage:  bash ~/.claude/fsp-stack/scripts/download-settings.sh
#         Or via the installed shortcut: claude-settings

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
STACK_DIR="${CLAUDE_DIR}/fsp-stack"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS="${CLAUDE_DIR}/settings.json"
REPO="https://github.com/carrmjw/claude-stack.git"
BRANCH="main"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
fail() { printf "${RED}✗${NC} %s\n" "$*"; exit 1; }
bold() { printf "\033[1m%s\033[0m\n" "$*"; }

bold ""
bold "  FSP — Download System Settings"
bold "  ================================"
echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
for req in git node npm python3; do
  command -v "${req}" &>/dev/null || fail "'${req}' is required but not found."
done

command -v claude &>/dev/null || fail "Claude Code CLI not found. Run the full installer first."

# ── Pull latest stack ─────────────────────────────────────────────────────────
if [ -d "${STACK_DIR}/.git" ]; then
  ACTUAL_REMOTE=$(git -C "${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
  if [ "${ACTUAL_REMOTE}" != "${REPO}" ]; then
    fail "${STACK_DIR} points to '${ACTUAL_REMOTE}', expected '${REPO}'."
  fi
  git -c core.hooksPath=/dev/null -C "${STACK_DIR}" fetch --quiet origin "${BRANCH}"
  if git -c core.hooksPath=/dev/null -C "${STACK_DIR}" merge --ff-only --quiet FETCH_HEAD; then
    ok "Stack updated to $(git -C "${STACK_DIR}" rev-parse --short HEAD)"
  else
    warn "Cannot fast-forward stack — using current version ($(git -C "${STACK_DIR}" rev-parse --short HEAD))"
  fi
else
  git -c core.hooksPath=/dev/null clone --quiet --branch "${BRANCH}" "${REPO}" "${STACK_DIR}"
  ok "Stack cloned at $(git -C "${STACK_DIR}" rev-parse --short HEAD)"
fi

# Guard against symlinked settings.json
if [ -L "${SETTINGS}" ]; then
  fail "${SETTINGS} is a symlink — aborting to prevent writing to an unexpected location."
fi

mkdir -p "${HOOKS_DIR}"

# ── Permissions (merge FSP baseline allow-list into settings.json) ────────────
echo ""
bold "Permissions"

PERMS_TEMPLATE="${STACK_DIR}/config/settings.json.template"
if [ -f "${PERMS_TEMPLATE}" ]; then
  PERMS_TEMPLATE="${PERMS_TEMPLATE}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os
src = os.environ["PERMS_TEMPLATE"]
dst = sys.argv[1]
with open(src) as f:
    tmpl = json.load(f)
tmpl.pop("__comment", None)
tmpl_allow = tmpl.get("permissions", {}).get("allow", [])
try:
    with open(dst) as f:
        existing = json.load(f)
except FileNotFoundError:
    existing = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {dst} has invalid JSON ({e}). Fix manually.")
existing_allow = existing.get("permissions", {}).get("allow", [])
new_perms = [a for a in tmpl_allow if a not in existing_allow]
if new_perms:
    merged = list(dict.fromkeys(existing_allow + new_perms))
    existing.setdefault("permissions", {})["allow"] = merged
    with open(dst, "w") as f:
        json.dump(existing, f, indent=2)
    os.chmod(dst, 0o600)
    print(f"  Added {len(new_perms)} permission(s) from template")
else:
    print("  Already up to date")
PYEOF
  ok "permissions"
else
  warn "settings.json.template missing from stack — permissions skipped"
fi

# ── MCP servers (claude mcp add — idempotent) ─────────────────────────────────
echo ""
bold "MCPs"

MCP_NAMES=(github context7 memory playwright sequential-thinking chrome-devtools)
MCP_CMDS=(
  "npx -y @modelcontextprotocol/server-github@2025.4.8"
  "npx -y @upstash/context7-mcp@2.1.4"
  "npx -y @modelcontextprotocol/server-memory@2026.1.26"
  "npx -y @playwright/mcp@0.0.69 --extension"
  "npx -y @modelcontextprotocol/server-sequential-thinking@2025.12.18"
  "npx -y chrome-devtools-mcp@0.23.0 --no-usage-statistics"
)

for i in "${!MCP_NAMES[@]}"; do
  name="${MCP_NAMES[$i]}"
  IFS=' ' read -ra cmd_parts <<< "${MCP_CMDS[$i]}"
  if claude mcp list 2>/dev/null | awk -F: -v n="${name}" '$1==n{found=1}END{exit !found}'; then
    ok "mcp/${name} already registered"
  else
    claude mcp add "${name}" -- "${cmd_parts[@]}" 2>/dev/null \
      && ok "mcp/${name}" \
      || warn "mcp/${name} — add manually: claude mcp add ${name} -- ${MCP_CMDS[$i]}"
  fi
done

# n8n-mcp (token-gated)
N8N_TOKEN=""
[ -f "${CLAUDE_DIR}/.env" ] && N8N_TOKEN=$(grep -E '^N8N_MCP_TOKEN=' "${CLAUDE_DIR}/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '[:space:]' | sed "s/^['\"]//;s/['\"]$//" || true)

if [ -n "${N8N_TOKEN}" ]; then
  N8N_MCP_TOKEN="${N8N_TOKEN}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os
path = sys.argv[1]
token = os.environ["N8N_MCP_TOKEN"]
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix manually.")
cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["n8n-mcp"] = {
    "type": "http",
    "url": "https://enterpriseact.app.n8n.cloud/mcp-server/http",
    "headers": {"Authorization": f"Bearer {token}"}
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
os.chmod(path, 0o600)
PYEOF
  ok "mcp/n8n-mcp"
else
  warn "mcp/n8n-mcp — set N8N_MCP_TOKEN in ~/.claude/.env and re-run"
fi

# FSP Brain MCP (token-gated)
FSP_BRAIN_URL=""
FSP_BRAIN_TOKEN=""
if [ -f "${CLAUDE_DIR}/.env" ]; then
  FSP_BRAIN_URL=$(grep -E '^FSP_BRAIN_URL=' "${CLAUDE_DIR}/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '[:space:]' | sed "s/^['\"]//;s/['\"]$//" || true)
  FSP_BRAIN_TOKEN=$(grep -E '^FSP_BRAIN_TOKEN=' "${CLAUDE_DIR}/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '[:space:]' | sed "s/^['\"]//;s/['\"]$//" || true)
fi

if [ -n "${FSP_BRAIN_URL}" ] && [ -n "${FSP_BRAIN_TOKEN}" ]; then
  FSP_BRAIN_URL="${FSP_BRAIN_URL}" FSP_BRAIN_TOKEN="${FSP_BRAIN_TOKEN}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os
path = sys.argv[1]
url   = os.environ["FSP_BRAIN_URL"].rstrip("/")
token = os.environ["FSP_BRAIN_TOKEN"]
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix manually.")
cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["fsp-brain"] = {
    "type": "http",
    "url": url,
    "headers": {"Authorization": f"Bearer {token}"}
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
os.chmod(path, 0o600)
PYEOF
  ok "mcp/fsp-brain"
else
  warn "mcp/fsp-brain — set FSP_BRAIN_URL and FSP_BRAIN_TOKEN in ~/.claude/.env and re-run"
fi

# ── Hooks ─────────────────────────────────────────────────────────────────────
echo ""
bold "Hooks"

# UserPromptSubmit — prompt quality
HOOK_SRC="${STACK_DIR}/config/hooks/fsp-prompt-quality.sh"
HOOK_DEST="${HOOKS_DIR}/fsp-prompt-quality.sh"

if [ -f "${HOOK_SRC}" ]; then
  if [ -L "${HOOK_DEST}" ]; then
    warn "fsp-prompt-quality.sh is a symlink — skipping"
  else
    cp "${HOOK_SRC}" "${HOOK_DEST}"
    chmod +x "${HOOK_DEST}"
    HOOK_DEST_JSON="${HOOK_DEST}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os, shlex
path = sys.argv[1]
hook_cmd = "bash " + shlex.quote(os.environ["HOOK_DEST_JSON"])
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix manually.")
cfg.setdefault("hooks", {})
cfg["hooks"].setdefault("UserPromptSubmit", [])
existing_cmds = [
    h.get("command", "")
    for entry in cfg["hooks"]["UserPromptSubmit"]
    for h in entry.get("hooks", [])
]
if not any("fsp-prompt-quality" in cmd for cmd in existing_cmds):
    cfg["hooks"]["UserPromptSubmit"].append({"hooks": [{"type": "command", "command": hook_cmd}]})
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(path, 0o600)
    print("registered")
else:
    print("already registered")
PYEOF
    ok "hook/fsp-prompt-quality"
  fi
else
  warn "fsp-prompt-quality.sh missing from stack — skipped"
fi

# Stop — session end
SESSION_END_SRC="${STACK_DIR}/config/hooks/fsp-session-end.sh"
SESSION_END_DEST="${HOOKS_DIR}/fsp-session-end.sh"

if [ -f "${SESSION_END_SRC}" ]; then
  if [ -L "${SESSION_END_DEST}" ]; then
    warn "fsp-session-end.sh is a symlink — skipping"
  else
    cp "${SESSION_END_SRC}" "${SESSION_END_DEST}"
    chmod +x "${SESSION_END_DEST}"
    SESSION_END_DEST_JSON="${SESSION_END_DEST}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os, shlex
path = sys.argv[1]
hook_cmd = "bash " + shlex.quote(os.environ["SESSION_END_DEST_JSON"])
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix manually.")
cfg.setdefault("hooks", {})
cfg["hooks"].setdefault("Stop", [])
existing_cmds = [
    h.get("command", "")
    for entry in cfg["hooks"]["Stop"]
    for h in entry.get("hooks", [])
]
if not any("fsp-session-end" in cmd for cmd in existing_cmds):
    cfg["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": hook_cmd}]})
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(path, 0o600)
    print("registered")
else:
    print("already registered")
PYEOF
    ok "hook/fsp-session-end"
  fi
else
  warn "fsp-session-end.sh missing from stack — skipped"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
ok "Settings sync complete."
echo ""
echo "  Settings file: ${SETTINGS}"
echo "  To verify MCPs: claude mcp list"
echo "  To re-run:      claude-settings"
echo ""
