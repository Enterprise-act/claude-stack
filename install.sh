#!/bin/bash
# Full Service Pros — Claude Stack Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/carrmjw/claude-stack.git"
BRANCH="main"
# Set to a known-good git SHA to pin installs to a verified commit.
# Leave empty to track latest main (fine for onboarding; set for production).
PINNED_SHA=""
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
  if [ -n "${PINNED_SHA}" ]; then
    FETCH_SHA=$(git -C "${STACK_DIR}" rev-parse FETCH_HEAD)
    if [ "${FETCH_SHA}" != "${PINNED_SHA}" ]; then
      echo "Error: fetched HEAD ${FETCH_SHA} does not match PINNED_SHA ${PINNED_SHA}. Aborting before merge."
      exit 1
    fi
  fi
  if ! git "${GIT_NO_HOOKS[@]}" -C "${STACK_DIR}" merge --ff-only --quiet FETCH_HEAD; then
    echo -e "${YELLOW}⚠ Cannot fast-forward. Run: git -C ${STACK_DIR} pull${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Stack at $(git -C "${STACK_DIR}" rev-parse --short HEAD)${NC}"
else
  git "${GIT_NO_HOOKS[@]}" clone --quiet --branch "${BRANCH}" "${REPO}" "${STACK_DIR}"
  echo -e "${GREEN}✓ Stack cloned at $(git -C "${STACK_DIR}" rev-parse --short HEAD)${NC}"
fi

# Commit verification — PINNED_SHA should be set to a known-good git SHA before release.
# When empty, trust is placed entirely in the GitHub repo and TLS. Warn loudly.
ACTUAL_SHA=$(git -C "${STACK_DIR}" rev-parse HEAD)
SHA_FILE="${CLAUDE_DIR}/.fsp-pinned-sha"
if [ -n "${PINNED_SHA}" ]; then
  if [ "${ACTUAL_SHA}" != "${PINNED_SHA}" ]; then
    echo "Error: HEAD ${ACTUAL_SHA} does not match PINNED_SHA ${PINNED_SHA}. Aborting."
    echo "Update PINNED_SHA in install.sh to the expected commit SHA."
    exit 1
  fi
  echo "${ACTUAL_SHA}" > "${SHA_FILE}"
  echo -e "${GREEN}✓ Commit verified: ${ACTUAL_SHA:0:8}${NC}"
else
  echo -e "${YELLOW}  ⚠ SECURITY: PINNED_SHA is unset — installing unverified code from mutable main.${NC}"
  echo -e "${YELLOW}    Set PINNED_SHA in install.sh to a known-good SHA before distributing to staff.${NC}"
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
    if [ -d "${skill_dir}" ] && grep -qxF "FSP:carrmjw/claude-stack" "${skill_dir}/${FSP_MARKER_FILE}" 2>/dev/null; then
      if ! ls "${STACK_DIR}/skills/" | grep -qxF -- "${safe}"; then
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
  if [ ! -d "${skill_dest}" ] || grep -qxF "FSP:carrmjw/claude-stack" "${skill_dest}/${FSP_MARKER_FILE}" 2>/dev/null; then
    rsync -a --delete --no-links --filter "protect ${FSP_MARKER_FILE}" "${skill_src}" "${skill_dest}/"
    printf 'FSP:carrmjw/claude-stack\n' > "${skill_dest}/${FSP_MARKER_FILE}"
    printf '%s\n' "${safe}" >> "${MANIFEST_TMP}"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  else
    echo "  Skipping user-owned skill: ${safe}"
  fi
done
shopt -u nullglob
mv "${MANIFEST_TMP}" "${MANIFEST}"
echo -e "${GREEN}✓ ${SKILL_COUNT} skills installed/updated${NC}"

# 4b. Build tools manifest — index all installed FSP skills, flag duplicate trigger phrases
TOOLS_MANIFEST="${CLAUDE_DIR}/.fsp-tools-manifest.json"
python3 - "${SKILLS_DIR}" "${TOOLS_MANIFEST}" << 'PYEOF'
import json, os, re, sys
from pathlib import Path

skills_dir = Path(sys.argv[1])
out_path   = Path(sys.argv[2])

if out_path.is_symlink():
    sys.exit(f"Error: {out_path} is a symlink — aborting")

skills = []
trigger_index = {}  # trigger_phrase -> [skill_name, ...]

for skill_dir in sorted(skills_dir.iterdir()):
    if not skill_dir.is_dir() or skill_dir.is_symlink():
        continue
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        continue
    text = skill_md.read_text(errors="replace")

    name_m = re.search(r'^name:\s*(.+)', text, re.MULTILINE)
    desc_m = re.search(r'^description:\s*(.+)', text, re.MULTILINE)
    trig_m = re.search(r'^triggers:\s*(\[.+?\])', text, re.MULTILINE | re.DOTALL)

    name     = name_m.group(1).strip().strip('"') if name_m else skill_dir.name
    desc     = desc_m.group(1).strip().strip('"')[:200] if desc_m else ""
    triggers = []
    if trig_m:
        try:
            triggers = json.loads(trig_m.group(1))
        except Exception:
            pass

    for t in triggers:
        trigger_index.setdefault(t, []).append(name)

    skills.append({"name": name, "dir": skill_dir.name, "description": desc,
                   "triggers": triggers})

duplicates = {t: names for t, names in trigger_index.items() if len(names) > 1}

manifest = {
    "generated_at": __import__('datetime').datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "skill_count": len(skills),
    "duplicate_triggers": duplicates,
    "skills": skills,
}

out_path.write_text(json.dumps(manifest, indent=2))
os.chmod(out_path, 0o600)

dup_count = len(duplicates)
if dup_count:
    print(f"  ⚠ {dup_count} duplicate trigger phrase(s) — see {out_path}")
    for t, names in list(duplicates.items())[:5]:
        print(f"    '{t}': {', '.join(names)}")
PYEOF
echo -e "${GREEN}✓ Tools manifest written to ${TOOLS_MANIFEST}${NC}"

# 5. Install plugins (exit-code based — avoids false positives from output string matching)
PLUGIN_ERRORS=0
for plugin in "everything-claude-code@1.10.0" "openai-codex@1.0.4" "ijfw@1.0.0"; do
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
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix it manually before re-running.")
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
REPO="https://github.com/carrmjw/claude-stack.git"
BRANCH="main"
STACK_DIR="${HOME}/.claude/fsp-stack"
SKILLS_DIR="${HOME}/.claude/skills"
MANIFEST="${HOME}/.claude/.fsp-skills-manifest"
FSP_MARKER_FILE=".fsp-managed"

if [ ! -d "${STACK_DIR}/.git" ]; then
  echo "FSP stack not found. Run installer:"
  echo "  curl -fsSL https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.sh | bash"
  exit 1
fi
ACTUAL_REMOTE=$(git -C "${STACK_DIR}" remote get-url origin 2>/dev/null || echo "")
if [ "${ACTUAL_REMOTE}" != "${REPO}" ]; then
  echo "Error: remote mismatch (${ACTUAL_REMOTE}). Aborting."
  exit 1
fi
git -c core.hooksPath=/dev/null -C "${STACK_DIR}" fetch --quiet origin "${BRANCH}"

# Verify FETCH_HEAD against pinned SHA before merging — check runs before any new code lands
SHA_FILE="${HOME}/.claude/.fsp-pinned-sha"
if [ -f "${SHA_FILE}" ]; then
  PINNED_SHA=$(cat "${SHA_FILE}")
  ACTUAL_SHA=$(git -C "${STACK_DIR}" rev-parse FETCH_HEAD)
  if [ "${ACTUAL_SHA}" != "${PINNED_SHA}" ]; then
    echo "Error: fetched HEAD ${ACTUAL_SHA} does not match pinned SHA ${PINNED_SHA}."
    echo "If intentional, update ${SHA_FILE} with the new SHA, then re-run claude-update."
    exit 1
  fi
  echo "✓ Commit verified: ${ACTUAL_SHA:0:8}"
else
  # No SHA file means installer ran without PINNED_SHA — accepted risk for curl|bash onboarding.
  echo "⚠ No pinned SHA on file — update is unverified."
fi

if ! git -c core.hooksPath=/dev/null -C "${STACK_DIR}" merge --ff-only --quiet FETCH_HEAD; then
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
    if [ -d "${skill_dir}" ] && grep -qxF "FSP:carrmjw/claude-stack" "${skill_dir}/${FSP_MARKER_FILE}" 2>/dev/null; then
      if ! ls "${STACK_DIR}/skills/" | grep -qxF -- "${safe}"; then
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
  if [ ! -d "${skill_dest}" ] || grep -qxF "FSP:carrmjw/claude-stack" "${skill_dest}/${FSP_MARKER_FILE}" 2>/dev/null; then
    rsync -a --delete --no-links --filter "protect ${FSP_MARKER_FILE}" "${skill_src}" "${skill_dest}/"
    printf 'FSP:carrmjw/claude-stack\n' > "${skill_dest}/${FSP_MARKER_FILE}"
    printf '%s\n' "${safe}" >> "${MANIFEST_TMP}"
  fi
done
shopt -u nullglob
mv "${MANIFEST_TMP}" "${MANIFEST}"

# Sync prompt-quality hook
HOOK_SRC="${STACK_DIR}/config/hooks/fsp-prompt-quality.sh"
HOOK_DEST="${HOME}/.claude/hooks/fsp-prompt-quality.sh"
if [ -f "${HOOK_SRC}" ]; then
  if [ -L "${HOOK_DEST}" ]; then
    echo "  Skipping hook sync: ${HOOK_DEST} is a symlink"
  else
    mkdir -p "${HOME}/.claude/hooks"
    cp "${HOOK_SRC}" "${HOOK_DEST}"
    chmod +x "${HOOK_DEST}"
  fi
fi

echo "✓ Claude Stack updated to $(git -C "${STACK_DIR}" rev-parse --short HEAD)"
SCRIPT
chmod +x "${TMPFILE}"

install_update_script() {
  local dest="$1"
  if [ -L "${dest}" ]; then
    echo -e "${YELLOW}⚠ ${dest} is a symlink — skipping to avoid following it${NC}"
    return 1
  fi
  if [ -f "${dest}" ] && ! grep -qxF "${FSP_MARKER}" "${dest}" 2>/dev/null; then
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

# 9. Install prompt-quality hook — injects FSP output standards on every prompt
HOOKS_DIR="${CLAUDE_DIR}/hooks"
HOOK_SRC="${STACK_DIR}/config/hooks/fsp-prompt-quality.sh"
HOOK_DEST="${HOOKS_DIR}/fsp-prompt-quality.sh"

mkdir -p "${HOOKS_DIR}"

if [ -f "${HOOK_SRC}" ]; then
  if [ -L "${HOOK_DEST}" ]; then
    echo -e "${YELLOW}⚠ ${HOOK_DEST} is a symlink — skipping to avoid following it${NC}"
  else
    cp "${HOOK_SRC}" "${HOOK_DEST}"
    chmod +x "${HOOK_DEST}"
  fi

  # Wire into settings.json — idempotent: skips if already registered
  SETTINGS="${CLAUDE_DIR}/settings.json"
  HOOK_DEST_JSON="${HOOK_DEST}" python3 - "${SETTINGS}" << 'PYEOF'
import json, sys, os, shlex
path = sys.argv[1]
hook_cmd = "bash " + shlex.quote(os.environ["HOOK_DEST_JSON"])

if os.path.islink(path):
    sys.exit(f"Error: {path} is a symlink — aborting")
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    sys.exit(f"Error: {path} has invalid JSON ({e}). Fix it manually before re-running.")

cfg.setdefault("hooks", {})
cfg["hooks"].setdefault("UserPromptSubmit", [])

# Collect all existing hook commands to check for duplicates
existing_cmds = [
    h.get("command", "")
    for entry in cfg["hooks"]["UserPromptSubmit"]
    for h in entry.get("hooks", [])
]

if not any("fsp-prompt-quality" in cmd for cmd in existing_cmds):
    cfg["hooks"]["UserPromptSubmit"].append({
        "hooks": [{"type": "command", "command": hook_cmd}]
    })
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(path, 0o600)
    print("registered")
else:
    print("already registered")
PYEOF

  echo -e "${GREEN}✓ prompt-quality hook installed${NC}"
else
  echo -e "${YELLOW}⚠ fsp-prompt-quality.sh missing from stack — skipped${NC}"
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
