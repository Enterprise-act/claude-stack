#!/usr/bin/env bash
#
# detect-build-context.sh — SessionStart hook for audit-skill-builds
#
# Fires at the start of every Claude Code session. Checks the current
# working directory for build, plan, or code-change context. If found,
# outputs a prompt that Claude reads and uses to ask the user whether
# to run /audit-skill-builds before proceeding.
#
# Install via install.sh or manually:
#   Add to ~/.claude/settings.json under hooks.SessionStart:
#   {
#     "type": "command",
#     "command": "bash ~/.claude/skills/audit-skill-builds/detect-build-context.sh"
#   }
#
# The hook output goes to Claude's context — Claude then decides whether
# to prompt the user based on the signals below.

set -euo pipefail

# ── Build file indicators ──────────────────────────────────────────────────
BUILD_FILES=(
  "package.json"
  "requirements.txt"
  "requirements-dev.txt"
  "Dockerfile"
  "docker-compose.yml"
  "docker-compose.yaml"
  "Makefile"
  "pyproject.toml"
  "setup.py"
  "cargo.toml"
  "Cargo.toml"
  "go.mod"
  "build.gradle"
  "pom.xml"
  "serverless.yml"
  "vercel.json"
  "netlify.toml"
)

# ── CI/deploy indicators ───────────────────────────────────────────────────
DEPLOY_DIRS=(
  ".github/workflows"
  "terraform"
  ".terraform"
  "k8s"
  "kubernetes"
  "helm"
  "ansible"
  "pulumi"
)

# ── Planning indicators ────────────────────────────────────────────────────
PLAN_FILES=(
  "CLAUDE.md"
  "PLAN.md"
  "ARCHITECTURE.md"
)

PLAN_DIRS=(
  ".planning"
)

# ── Detection ──────────────────────────────────────────────────────────────
FOUND_BUILD=""
FOUND_DEPLOY=""
FOUND_PLAN=""
HAS_GIT_CHANGES=false
CHANGE_COUNT=0

for f in "${BUILD_FILES[@]}"; do
  [[ -f "$f" ]] && FOUND_BUILD="$FOUND_BUILD $f"
done

for d in "${DEPLOY_DIRS[@]}"; do
  [[ -d "$d" ]] && FOUND_DEPLOY="$FOUND_DEPLOY $d"
done

for f in "${PLAN_FILES[@]}"; do
  [[ -f "$f" ]] && FOUND_PLAN="$FOUND_PLAN $f"
done

for d in "${PLAN_DIRS[@]}"; do
  [[ -d "$d" ]] && FOUND_PLAN="$FOUND_PLAN $d"
done

if git rev-parse --git-dir > /dev/null 2>&1; then
  CHANGE_COUNT=$(git diff HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
  [[ "$CHANGE_COUNT" -gt 0 ]] && HAS_GIT_CHANGES=true
fi

# ── Exit silently if nothing relevant found ────────────────────────────────
if [[ -z "$FOUND_BUILD" && -z "$FOUND_DEPLOY" && -z "$FOUND_PLAN" && "$HAS_GIT_CHANGES" == "false" ]]; then
  exit 0
fi

# ── Build the context summary ──────────────────────────────────────────────
CONTEXT_LINES=""

[[ -n "$FOUND_BUILD" ]]  && CONTEXT_LINES="${CONTEXT_LINES}\n  Build files:   $(echo "$FOUND_BUILD" | xargs)"
[[ -n "$FOUND_DEPLOY" ]] && CONTEXT_LINES="${CONTEXT_LINES}\n  Deploy/infra:  $(echo "$FOUND_DEPLOY" | xargs)"
[[ -n "$FOUND_PLAN" ]]   && CONTEXT_LINES="${CONTEXT_LINES}\n  Planning docs: $(echo "$FOUND_PLAN" | xargs)"
[[ "$HAS_GIT_CHANGES" == "true" ]] && CONTEXT_LINES="${CONTEXT_LINES}\n  Git changes:   ${CHANGE_COUNT} uncommitted file(s)"

# ── Output the prompt for Claude to act on ────────────────────────────────
printf '\n[audit-skill-builds] Build/plan context detected in this directory:%b\n\nAsk the user: "I detected build/plan context in this project. Would you like me to run /audit-skill-builds before we start — a 3-pass multi-agent audit that checks for bugs, security issues, redundancy, and execution failures? (Type yes to run now, or no to skip.)"\n\nIf the user says yes, invoke the audit-skill-builds skill immediately.\nIf the user says no or does not respond within their first message, skip the audit silently.\n' "$CONTEXT_LINES"

exit 0
