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

# 1. Check for Node.js
if ! command -v node &>/dev/null; then
  echo "Node.js is required. Install from https://nodejs.org then re-run."
  exit 1
fi

# 2. Install Claude Code CLI if missing
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
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
NEW_MANIFEST=$(ls "${STACK_DIR}/skills")

# Remove skills that were previously FSP-managed but no longer exist in the stack
# Sanitize each name: allow only alphanumeric, dash, underscore — no path traversal
if [ -f "${MANIFEST}" ]; then
  while IFS= read -r skill; do
    safe="${skill//[^a-zA-Z0-9_-]/}"
    if [ -n "${safe}" ] && [ "${safe}" = "${skill}" ] && ! echo "${NEW_MANIFEST}" | grep -qx "${safe}"; then
      [ -d "${SKILLS_DIR}/${safe}" ] && echo "  Removing retired skill: ${safe}" && rm -rf "${SKILLS_DIR:?}/${safe}"
    fi
  done < "${MANIFEST}"
fi

# --no-links: skip upstream symlinks to prevent unexpected path traversal by consumers
rsync -a --no-links "${STACK_DIR}/skills/" "${SKILLS_DIR}/"
echo "${NEW_MANIFEST}" > "${MANIFEST}"
SKILL_COUNT=$(echo "${NEW_MANIFEST}" | wc -l | tr -d ' ')
echo -e "${GREEN}✓ ${SKILL_COUNT} skills installed${NC}"

# 5. Install plugins
PLUGIN_ERRORS=0
for plugin in everything-claude-code openai-codex ijfw; do
  OUTPUT=$(claude plugins install "${plugin}" 2>&1 || true)
  if echo "${OUTPUT}" | grep -qE "installed|already|success"; then
    echo -e "${GREEN}  ✓ ${plugin}${NC}"
  else
    echo -e "${YELLOW}  ⚠ ${plugin} — run manually: claude plugins install ${plugin}${NC}"
    PLUGIN_ERRORS=$((PLUGIN_ERRORS + 1))
  fi
done
[ $PLUGIN_ERRORS -gt 0 ] && echo -e "${YELLOW}  Verify: claude plugins list${NC}"

# 6. Copy CLAUDE.md template if none exists
if [ ! -f "${CLAUDE_DIR}/CLAUDE.md" ]; then
  cp "${STACK_DIR}/config/CLAUDE.md.template" "${CLAUDE_DIR}/CLAUDE.md"
  echo -e "${GREEN}✓ CLAUDE.md created${NC}"
else
  echo -e "${YELLOW}⚠ CLAUDE.md already exists — skipped${NC}"
fi

# 7. Set up .env for personal API keys
if [ ! -f "${CLAUDE_DIR}/.env" ]; then
  cp "${STACK_DIR}/config/.env.template" "${CLAUDE_DIR}/.env"
  echo -e "${YELLOW}⚠ Fill in your API keys: ${CLAUDE_DIR}/.env${NC}"
fi

# 8. Install claude-update — skip if an unrelated script already exists there
TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT

cat > "${TMPFILE}" << SCRIPT
#!/bin/bash
${FSP_MARKER}
set -euo pipefail
REPO="https://github.com/Enterprise-act/claude-stack.git"
BRANCH="main"
STACK_DIR="\${HOME}/.claude/fsp-stack"
SKILLS_DIR="\${HOME}/.claude/skills"
MANIFEST="\${HOME}/.claude/.fsp-skills-manifest"

if [ ! -d "\${STACK_DIR}/.git" ]; then
  echo "FSP stack not found. Run installer:"
  echo "  curl -fsSL https://raw.githubusercontent.com/Enterprise-act/claude-stack/main/install.sh | bash"
  exit 1
fi
ACTUAL_REMOTE=\$(git -C "\${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
if [ "\${ACTUAL_REMOTE}" != "\${REPO}" ]; then
  echo "Error: remote mismatch (\${ACTUAL_REMOTE}). Aborting."
  exit 1
fi
git -c core.hooksPath=/dev/null -C "\${STACK_DIR}" fetch --quiet origin "\${BRANCH}"
if ! git -c core.hooksPath=/dev/null -C "\${STACK_DIR}" merge --ff-only --quiet "origin/\${BRANCH}"; then
  echo "⚠ Cannot fast-forward. Run: git -C ~/.claude/fsp-stack pull"
  exit 1
fi
NEW_MANIFEST=\$(ls "\${STACK_DIR}/skills")
if [ -f "\${MANIFEST}" ]; then
  while IFS= read -r skill; do
    safe="\${skill//[^a-zA-Z0-9_-]/}"
    if [ -n "\${safe}" ] && [ "\${safe}" = "\${skill}" ] && ! echo "\${NEW_MANIFEST}" | grep -qx "\${safe}"; then
      [ -d "\${SKILLS_DIR}/\${safe}" ] && rm -rf "\${SKILLS_DIR:?}/\${safe}"
    fi
  done < "\${MANIFEST}"
fi
rsync -a --no-links "\${STACK_DIR}/skills/" "\${SKILLS_DIR}/"
echo "\${NEW_MANIFEST}" > "\${MANIFEST}"
echo "✓ Claude Stack updated to \$(git -C "\${STACK_DIR}" rev-parse --short HEAD)"
SCRIPT
chmod +x "${TMPFILE}"

install_update_script() {
  local dest="$1"
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
echo "  2. Run: claude-update          ← pull latest skills from Mark"
echo "  3. Edit: ~/.claude/.env        ← add your personal API keys"
echo "  4. Connect integrations:       https://claude.ai/settings/integrations"
echo ""
