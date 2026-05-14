#!/usr/bin/env bash
#
# install.sh — Install audit-skill-builds for Claude Code
#
# Copies the skill to ~/.claude/skills/ and optionally installs the
# SessionStart hook that detects build/plan context at session start.
#
# Usage:
#   bash install.sh              # Install skill only (manual /audit-skill-builds)
#   bash install.sh --auto       # Install skill + SessionStart hook
#   bash install.sh --uninstall  # Remove skill and hook

set -euo pipefail

SKILL_NAME="audit-skill-builds"
SKILL_DIR="$HOME/.claude/skills/${SKILL_NAME}"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
ok()      { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
err()     { printf "${RED}[ERR]${NC}   %s\n" "$1"; }

# ── Install skill files ────────────────────────────────────────────────────
install_skill() {
  info "Installing ${SKILL_NAME} to ${SKILL_DIR}"
  mkdir -p "$SKILL_DIR"

  cp "${SCRIPT_DIR}/SKILL.md"                  "${SKILL_DIR}/SKILL.md"
  cp "${SCRIPT_DIR}/detect-build-context.sh"   "${SKILL_DIR}/detect-build-context.sh"
  cp "${SCRIPT_DIR}/install.sh"                "${SKILL_DIR}/install.sh"

  chmod +x "${SKILL_DIR}/detect-build-context.sh"
  chmod +x "${SKILL_DIR}/install.sh"

  ok "Skill installed. Use /audit-skill-builds in Claude Code to run manually."
  echo ""
  info "To also enable the auto-detection hook (prompts at every session start):"
  info "  bash ${SKILL_DIR}/install.sh --auto"
}

# ── Install the SessionStart hook ─────────────────────────────────────────
install_hook() {
  info "Configuring SessionStart hook in ${SETTINGS_FILE}"

  # Create settings file if it doesn't exist
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    printf '{}' > "$SETTINGS_FILE"
    info "Created ${SETTINGS_FILE}"
  fi

  local hook_command="bash ~/.claude/skills/${SKILL_NAME}/detect-build-context.sh"

  python3 - "$SETTINGS_FILE" "$hook_command" << 'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_command  = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

settings.setdefault("hooks", {})
settings["hooks"].setdefault("SessionStart", [])

already_installed = any(
    "audit-skill-builds" in h.get("command", "")
    for h in settings["hooks"]["SessionStart"]
)

if already_installed:
    print("Hook already installed — skipping.")
else:
    settings["hooks"]["SessionStart"].append({
        "type": "command",
        "command": hook_command
    })
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("Hook added.")
PYEOF

  ok "SessionStart hook configured."
  echo ""
  info "How it works:"
  info "  1. Every Claude Code session start fires detect-build-context.sh"
  info "  2. Script checks for: package.json, Dockerfile, PLAN.md, git changes, etc."
  info "  3. If build/plan context found, Claude asks: 'Run /audit-skill-builds?'"
  info "  4. Say yes → 3-pass multi-agent audit starts"
  info "  5. Say no → session proceeds normally"
  info "  6. No context found → hook exits silently (zero overhead)"
}

# ── Uninstall ──────────────────────────────────────────────────────────────
uninstall() {
  info "Removing ${SKILL_NAME}"

  if [[ -d "$SKILL_DIR" ]]; then
    rm -rf "$SKILL_DIR"
    ok "Removed ${SKILL_DIR}"
  else
    warn "Skill directory not found at ${SKILL_DIR} — nothing to remove."
  fi

  if [[ -f "$SETTINGS_FILE" ]]; then
    python3 - "$SETTINGS_FILE" << 'PYEOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

if "hooks" in settings and "SessionStart" in settings["hooks"]:
    before = len(settings["hooks"]["SessionStart"])
    settings["hooks"]["SessionStart"] = [
        h for h in settings["hooks"]["SessionStart"]
        if "audit-skill-builds" not in h.get("command", "")
    ]
    after = len(settings["hooks"]["SessionStart"])

    if not settings["hooks"]["SessionStart"]:
        del settings["hooks"]["SessionStart"]
    if not settings["hooks"]:
        del settings["hooks"]

    if before != after:
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
            f.write("\n")
        print(f"Hook removed from {settings_path}")
    else:
        print("No hook found in settings — nothing to remove.")
else:
    print("No SessionStart hooks in settings — nothing to remove.")
PYEOF
  fi

  ok "Uninstall complete."
}

# ── Print quick-start after install ───────────────────────────────────────
print_quickstart() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│              audit-skill-builds — Quick Start                   │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  echo "│  Manual run:    /audit-skill-builds                             │"
  echo "│  Quick (1-pass): /audit-skill-builds --quick                    │"
  echo "│  Report only:   /audit-skill-builds --no-fix                    │"
  echo "│  Diff only:     /audit-skill-builds --scope=diff                │"
  echo "│                                                                  │"
  echo "│  Add audit/ to .gitignore to exclude session reports from git.  │"
  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""
}

# ── Entry point ────────────────────────────────────────────────────────────
case "${1:-}" in
  --auto)
    install_skill
    install_hook
    print_quickstart
    ;;
  --uninstall)
    uninstall
    ;;
  --hook-only)
    install_hook
    ;;
  *)
    install_skill
    print_quickstart
    ;;
esac
