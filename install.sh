#!/bin/bash
# Full Service Pros — Claude Stack Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/Enterprise-act/claude-stack.git"
BRANCH="main"
CLAUDE_DIR="${HOME}/.claude"
STACK_DIR="${CLAUDE_DIR}/fsp-stack"
SKILLS_DIR="${CLAUDE_DIR}/skills"
MANIFEST="${CLAUDE_DIR}/.fsp-skills-manifest"
FSP_MARKER="# FSP-MANAGED-SCRIPT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo ""; echo "  Full Service Pros — Claude Stack"; echo "  ================================"; echo ""

# 1. Check prerequisites
for req in node npm git rsync python3; do
  if ! command -v "${req}" &>/dev/null; then
    echo "Error: '${req}' is required but not found."
    case "${req}" in
      node|npm) echo "  Install Node.js from https://nodejs.org" ;;
      git)      echo "  Install git: brew install git" ;;
      rsync)    echo "  Install rsync: brew install rsync" ;;
    esac
    exit 1
  fi
done

# 2. Install Claude Code CLI if missing
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code@2.1.126
  echo -e "${GREEN}✓ Claude Code installed${NC}"
else
  echo -e "${GREEN}✓ Claude Code already installed${NC}"
fi

# 3. Clone or update — verify remote, disable git hooks during merge
mkdir -p "${CLAUDE_DIR}"
GIT_NO_HOOKS=(-c core.hooksPath=/dev/null)
if [ -d "${STACK_DIR}/.git" ]; then
  ACTUAL_REMOTE=$(git -C "${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
  if [ "${ACTUAL_REMOTE}" != "${REPO}" ]; then
    echo "Error: ${STACK_DIR} points to '${ACTUAL_REMOTE}', expected '${REPO}'."
    echo "Remove it manually: rm -rf ${STACK_DIR}"
    exit 1
  fi
  git "${GIT_NO_HOOKS[@]}" -C "${STACK_DIR}" fetch --quiet origin "${BRANCH}"
  if ! git "${GIT_NO_HOOKS[@]}" -C "${STACK_DIR}" merge --ff-only --quiet "origin/${BRANCH}"; then
    echo -e "${YELLOW}⚠ Cannot fast-forward. Run: git -C ${STACK_DIR} pull${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Stack at $(git -C "${STACK_DIR}" rev-parse --short HEAD)${NC}"
else
  git "${GIT_NO_HOOKS[@]}" clone --quiet --branch "${BRANCH}" "${REPO}" "${STACK_DIR}"
  echo -e "${GREEN}✓ Stack cloned at $(git -C "${STACK_DIR}" rev-parse --short HEAD)${NC}"
fi

# 4. Sync only FSP-managed skills — never touch user's own skills
mkdir -p "${SKILLS_DIR}"
FSP_MARKER_FILE=".fsp-managed"  # Written into each FSP skill dir so we can identify ownership

# Guard: abort retirement + sync if skills dir is missing — prevents wiping installed skills
if [ ! -d "${STACK_DIR}/skills" ] || [ -z "$(ls -A "${STACK_DIR}/skills/" 2>/dev/null)" ]; then
  echo "Error: ${STACK_DIR}/skills is missing or empty after clone. Aborting skill sync."
  exit 1
fi

# Remove retired FSP skills — only if the skill dir contains our ownership marker
if [ -f "${MANIFEST}" ]; then
  while IFS= read -r skill; do
    safe="${skill//[^a-zA-Z0-9_-]/}"
    [ -z "${safe}" ] || [ "${safe}" != "${skill}" ] && continue  # skip unsafe names
    skill_dir="${SKILLS_DIR}/${safe}"
    [ -L "${skill_dir}" ] && continue  # skip symlinked targets
    if [ -d "${skill_dir}" ] && [ -f "${skill_dir}/${FSP_MARKER_FILE}" ]; then
      if ! ls "${STACK_DIR}/skills/" | grep -qx "${safe}"; then
        echo "  Removing retired FSP skill: ${safe}"
        rm -rf "${SKILLS_DIR:?}/${safe}"
      fi
    fi
  done < "${MANIFEST}"
fi

# Sync each skill individually — only overwrite if dir is new OR FSP-owned (has marker)
SKILL_COUNT=0
MANIFEST_TMP=$(mktemp)
shopt -s nullglob
for skill_src in "${STACK_DIR}/skills/"/*/; do
  skill=$(basename "${skill_src}")
  [ -L "${skill_src%/}" ] && { echo "  Skipping symlinked skill: ${skill}"; continue; }
  safe="${skill//[^a-zA-Z0-9_-]/}"
  if [ -z "${safe}" ] || [ "${safe}" != "${skill}" ]; then
    echo "  Skipping unsafe skill name: ${skill}"; continue
  fi
  skill_dest="${SKILLS_DIR}/${safe}"
  [ -L "${skill_dest}" ] && { echo "  Skipping symlinked skill destination: ${safe}"; continue; }
  if [ ! -d "${skill_dest}" ] || [ -f "${skill_dest}/${FSP_MARKER_FILE}" ]; then
    rsync -a --delete --no-links --filter "protect ${FSP_MARKER_FILE}" "${skill_src}" "${skill_dest}/"
    printf 'FSP:Enterprise-act/claude-stack\n' > "${skill_dest}/${FSP_MARKER_FILE}"
    printf '%s\n' "${safe}" >> "${MANIFEST_TMP}"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  else
    echo "  Skipping user-owned skill: ${safe}"
  fi
done
shopt -u nullglob
mv "${MANIFEST_TMP}" "${MANIFEST}"
echo -e "${GREEN}✓ ${SKILL_COUNT} skills installed/updated${NC}"

# 5. Install plugins (exit-code based — avoids false positives from output string matching)
PLUGIN_ERRORS=0
for plugin in everything-claude-code openai-codex ijfw; do
  if claude plugins install "${plugin}" >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ ${plugin}${NC}"
  else
    echo -e "${YELLOW}  ⚠ ${plugin} — run manually: claude plugins install ${plugin}${NC}"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi
done
[ $PLUGIN_ERRORS -gt 0 ] && echo -e "${YELLOW}  Verify: claude plugins list${NC}"

# 6. Add local MCP servers (idempotent — skip if already registered)
# Using parallel arrays for Bash 3.2 compatibility (macOS ships with Bash 3.2)
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
  # Read cmd into an array to avoid word-splitting on uncontrolled strings
  IFS=' ' read -ra cmd_parts <<< "${MCP_CMDS[$i]}"
  if claude mcp list 2>/dev/null | awk -F: -v n="${name}" '$1==n{found=1}END{exit !found}'; then
    echo -e "${GREEN}  ✓ mcp/${name} already registered${NC}"
  else
    claude mcp add "${name}" -- "${cmd_parts[@]}" 2>/dev/null \
      && echo -e "${GREEN}  ✓ mcp/${name}${NC}" \
      || echo -e "${YELLOW}  ⚠ mcp/${name} — add manually: claude mcp add ${name} -- ${MCP_CMDS[$i]}${NC}"
  fi
done

# 6b. Wire n8n-mcp HTTP server (reads N8N_MCP_TOKEN from ~/.claude/.env)
N8N_TOKEN=""
[ -f "${CLAUDE_DIR}/.env" ] && N8N_TOKEN=$(grep -E '^N8N_MCP_TOKEN=' "${CLAUDE_DIR}/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '[:space:]' | sed "s/^['\"]//;s/['\"]$//" || true)

if [ -n "${N8N_TOKEN}" ]; then
  SETTINGS="${CLAUDE_DIR}/settings.json"
  N8N_MCP_TOKEN="${N8N_TOKEN}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os
path = sys.argv[1]
token = os.environ["N8N_MCP_TOKEN"]
if os.path.islink(path):
    sys.exit(f"Error: {path} is a symlink — aborting to prevent writing to unexpected location")
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError:
    import shutil
    shutil.copy2(path, path + ".bak")
    print(f"Warning: {path} had invalid JSON — backed up to {path}.bak, starting fresh", file=sys.stderr)
    cfg = {}
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
  echo -e "${GREEN}  ✓ mcp/n8n-mcp${NC}"
else
  echo -e "${YELLOW}  ⚠ mcp/n8n-mcp — set N8N_MCP_TOKEN in ~/.claude/.env and re-run${NC}"
fi

# 7. Copy CLAUDE.md template if none exists
if [ ! -f "${CLAUDE_DIR}/CLAUDE.md" ]; then
  if [ -f "${STACK_DIR}/config/CLAUDE.md.template" ]; then
    cp "${STACK_DIR}/config/CLAUDE.md.template" "${CLAUDE_DIR}/CLAUDE.md"
    echo -e "${GREEN}✓ CLAUDE.md created${NC}"
  else
    echo -e "${YELLOW}⚠ CLAUDE.md.template missing in repo — skipped${NC}"
  fi
else
  echo -e "${YELLOW}⚠ CLAUDE.md already exists — skipped${NC}"
fi

# 8. Set up .env for personal API keys
if [ ! -f "${CLAUDE_DIR}/.env" ]; then
  if [ -f "${STACK_DIR}/config/.env.template" ]; then
    cp "${STACK_DIR}/config/.env.template" "${CLAUDE_DIR}/.env"
    chmod 600 "${CLAUDE_DIR}/.env"
    echo -e "${YELLOW}⚠ Fill in your API keys: ${CLAUDE_DIR}/.env${NC}"
  else
    echo -e "${YELLOW}⚠ .env.template missing in repo — create ${CLAUDE_DIR}/.env manually${NC}"
  fi
fi

# 8. Install claude-update — skip if an unrelated script already exists there
TMPFILE=$(mktemp)
chmod 600 "${TMPFILE}"
trap 'rm -f "${TMPFILE}"' EXIT

cat > "${TMPFILE}" << 'SCRIPT'
#!/bin/bash
# FSP-MANAGED-SCRIPT
set -euo pipefail
for req in git rsync; do
  command -v "${req}" &>/dev/null || { echo "Error: '${req}' is required. Install it and retry."; exit 1; }
done
REPO="https://github.com/Enterprise-act/claude-stack.git"
BRANCH="main"
STACK_DIR="${HOME}/.claude/fsp-stack"
SKILLS_DIR="${HOME}/.claude/skills"
MANIFEST="${HOME}/.claude/.fsp-skills-manifest"
FSP_MARKER_FILE=".fsp-managed"

if [ ! -d "${STACK_DIR}/.git" ]; then
  echo "FSP stack not found. Run installer:"
  echo "  curl -fsSL https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.sh | bash"
  exit 1
fi
ACTUAL_REMOTE=$(git -C "${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
if [ "${ACTUAL_REMOTE}" != "${REPO}" ]; then
  echo "Error: remote mismatch (${ACTUAL_REMOTE}). Aborting."
  exit 1
fi
git -c core.hooksPath=/dev/null -C "${STACK_DIR}" fetch --quiet origin "${BRANCH}"
if ! git -c core.hooksPath=/dev/null -C "${STACK_DIR}" merge --ff-only --quiet "origin/${BRANCH}"; then
  echo "⚠ Cannot fast-forward. Run: git -C ~/.claude/fsp-stack pull"
  exit 1
fi

mkdir -p "${SKILLS_DIR}"

# Guard: abort if skills dir is missing after pull — prevents wiping all managed skills
if [ ! -d "${STACK_DIR}/skills" ] || [ -z "$(ls -A "${STACK_DIR}/skills/" 2>/dev/null)" ]; then
  echo "Error: ${STACK_DIR}/skills is missing or empty after pull. Aborting skill sync."
  exit 1
fi

# Remove retired FSP skills — only if dir carries the ownership marker
if [ -f "${MANIFEST}" ]; then
  while IFS= read -r skill; do
    safe="${skill//[^a-zA-Z0-9_-]/}"
    [ -z "${safe}" ] || [ "${safe}" != "${skill}" ] && continue
    skill_dir="${SKILLS_DIR}/${safe}"
    [ -L "${skill_dir}" ] && continue  # skip symlinked targets
    if [ -d "${skill_dir}" ] && [ -f "${skill_dir}/${FSP_MARKER_FILE}" ]; then
      if ! ls "${STACK_DIR}/skills/" | grep -qx "${safe}"; then
        echo "  Removing retired FSP skill: ${safe}"
        rm -rf "${SKILLS_DIR:?}/${safe}"
      fi
    fi
  done < "${MANIFEST}"
fi

# Sync only FSP-owned or new skills; skip user-owned dirs
MANIFEST_TMP=$(mktemp)
shopt -s nullglob
for skill_src in "${STACK_DIR}/skills/"/*/; do
  skill=$(basename "${skill_src}")
  [ -L "${skill_src%/}" ] && { echo "  Skipping symlinked skill: ${skill}"; continue; }
  safe="${skill//[^a-zA-Z0-9_-]/}"
  if [ -z "${safe}" ] || [ "${safe}" != "${skill}" ]; then
    echo "  Skipping unsafe skill name: ${skill}"; continue
  fi
  skill_dest="${SKILLS_DIR}/${safe}"
  [ -L "${skill_dest}" ] && { echo "  Skipping symlinked skill destination: ${safe}"; continue; }
  if [ ! -d "${skill_dest}" ] || [ -f "${skill_dest}/${FSP_MARKER_FILE}" ]; then
    rsync -a --delete --no-links --filter "protect ${FSP_MARKER_FILE}" "${skill_src}" "${skill_dest}/"
    printf 'FSP:Enterprise-act/claude-stack\n' > "${skill_dest}/${FSP_MARKER_FILE}"
    printf '%s\n' "${safe}" >> "${MANIFEST_TMP}"
  fi
done
shopt -u nullglob
mv "${MANIFEST_TMP}" "${MANIFEST}"
echo "✓ Claude Stack updated to $(git -C "${STACK_DIR}" rev-parse --short HEAD)"
SCRIPT
chmod +x "${TMPFILE}"

install_update_script() {
  local dest="$1"
  if [ -L "${dest}" ]; then
    echo -e "${YELLOW}⚠ ${dest} is a symlink — skipping to avoid following it${NC}"
    return 1
  fi
  if [ -f "${dest}" ] && ! grep -q "${FSP_MARKER}" "${dest}" 2>/dev/null; then
    echo -e "${YELLOW}⚠ ${dest} exists and is not FSP-managed — skipping to avoid overwrite${NC}"
    return 1
  fi
  cp "${TMPFILE}" "${dest}" && chmod +x "${dest}"
}

UPDATE_SCRIPT="/usr/local/bin/claude-update"
if install_update_script "${UPDATE_SCRIPT}" 2>/dev/null; then
  echo -e "${GREEN}✓ claude-update installed at ${UPDATE_SCRIPT}${NC}"
else
  mkdir -p "${HOME}/bin"
  if install_update_script "${HOME}/bin/claude-update"; then
    echo -e "${GREEN}✓ claude-update installed at ~/bin/claude-update${NC}"
  fi
fi

echo ""
echo -e "${GREEN}  Done!${NC}"
echo ""
echo "  1. Run: claude                 ← start Claude Code"
if command -v claude-update &>/dev/null; then
  echo "  2. Run: claude-update          ← pull latest skills from Mark"
else
  echo "  2. Run updates:                ~/.claude/fsp-stack/install.sh"
  echo "     (add ~/bin to PATH to use claude-update: export PATH=\"\$HOME/bin:\$PATH\")"
fi
echo "  3. Edit: ~/.claude/.env        ← add your personal API keys"
echo "  4. Connect integrations:       https://claude.ai/settings/integrations"
echo ""
