#!/usr/bin/env bash
# install-fsp-context.sh
# Installs FSP shared context and shortcuts into a staff member's Claude setup.
# Run once on new machines, or run again to update.
# Usage: bash install-fsp-context.sh [--role intake|billing|field|management]
#
# What this does:
#   1. Writes fsp-CLAUDE.md to ~/.claude/fsp-context/ (auto-loaded by Claude Code)
#   2. Writes fsp-shortcuts.md to ~/.claude/ for quick reference
#   3. Patches ~/.claude/CLAUDE.md to import the FSP context
#   4. Optionally seeds a starter IJFW memory file for FSP project context

set -euo pipefail

ROLE="${1:-}"
if [[ "$ROLE" == "--role" ]]; then ROLE="${2:-}"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
FSP_CONTEXT_DIR="$CLAUDE_DIR/fsp-context"

# --- colours ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[FSP]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Refuse to write through a symlink — avoids modifying unintended files
_assert_real_dir() {
    local dir="$1"
    [[ -L "$dir" ]] && die "$dir is a symlink — refusing to write through it"
}

# Copy src→dst safely: skip if identical, backup if changed, refuse symlink dst.
# Uses write-to-tmp + atomic mv so the final write never follows a symlink
# (rename(2) replaces the directory entry, not the symlink target).
# Residual TOCTOU on the backup cp is accepted — user-level installer only.
_safe_copy() {
    local src="$1" dst="$2" dst_dir
    dst_dir="$(dirname "$dst")"

    # Stage into a temp file in the same directory (required for atomic same-fs mv)
    local tmp
    tmp="$(mktemp "$dst_dir/.fsp_install.XXXXXX")"

    cp "$src" "$tmp"

    # Skip if destination already matches source
    if [[ -f "$dst" ]] && cmp -s "$tmp" "$dst"; then
        rm -f "$tmp"
        info "$(basename "$dst") unchanged — skipping"
        return
    fi

    # Symlink check immediately before swap to minimise TOCTOU window
    if [[ -L "$dst" ]]; then
        rm -f "$tmp"
        die "$dst is a symlink — refusing to overwrite"
    fi

    # Backup existing file — ns+PID suffix prevents collision on rapid reruns
    if [[ -f "$dst" ]]; then
        cp "$dst" "$dst.bak.$(date +%s%N).$$"
        warn "Backed up existing $(basename "$dst") (local edits preserved in .bak)"
    fi

    # Atomic replace — rename(2) does not follow symlinks for the destination
    mv "$tmp" "$dst"
}

echo ""
echo "  Full Service Pros — Claude Context Installer"
echo "  ============================================="
echo ""

# 1. Create dirs — verify neither target path is a symlink
_assert_real_dir "$CLAUDE_DIR"
mkdir -p "$FSP_CONTEXT_DIR"
_assert_real_dir "$FSP_CONTEXT_DIR"
info "Verified $FSP_CONTEXT_DIR"

# 2. Copy context file — backup if staff has made local edits
_safe_copy "$SCRIPT_DIR/fsp-CLAUDE.md" "$FSP_CONTEXT_DIR/CLAUDE.md"
info "Installed FSP context → $FSP_CONTEXT_DIR/CLAUDE.md"

# 3. Copy shortcuts file — backup if staff has made local edits
_safe_copy "$SCRIPT_DIR/fsp-shortcuts.md" "$CLAUDE_DIR/fsp-shortcuts.md"
info "Installed FSP shortcuts → $CLAUDE_DIR/fsp-shortcuts.md"

# 4. Patch root CLAUDE.md to load FSP context
ROOT_CLAUDE="$CLAUDE_DIR/CLAUDE.md"
FSP_IMPORT='@~/.claude/fsp-context/CLAUDE.md'

[[ -L "$ROOT_CLAUDE" ]] && die "$ROOT_CLAUDE is a symlink — refusing to patch it"

if [[ ! -f "$ROOT_CLAUDE" ]]; then
    echo "# Claude Global Config" > "$ROOT_CLAUDE"
fi

# Backup before modifying — restored automatically if script exits non-zero
# Use nanoseconds + PID so repeated rapid runs never collide on the same backup name
BACKUP="$ROOT_CLAUDE.bak.$(date +%s%N).$$"
cp "$ROOT_CLAUDE" "$BACKUP"
_restore_backup() { cp "$BACKUP" "$ROOT_CLAUDE" 2>/dev/null || true; }
trap '_restore_backup' ERR

# Only match an uncommented active import line — -x anchors to full line, -F disables regex
# Capture exit code explicitly: 0=found, 1=not found, 2=error
# Use || pattern so set -e doesn't fire on exit 1 (not found) before we capture the code
_grep_rc=0
grep -qxF "$FSP_IMPORT" "$ROOT_CLAUDE" || _grep_rc=$?
if [[ $_grep_rc -eq 2 ]]; then
    echo "ERROR: could not read $ROOT_CLAUDE — aborting patch" >&2
    exit 1
elif [[ $_grep_rc -eq 1 ]]; then
    printf '\n# FSP Shared Context (auto-installed by FSP stack)\n%s\n' "$FSP_IMPORT" >> "$ROOT_CLAUDE"
    info "Patched ~/.claude/CLAUDE.md to load FSP context"
else
    info "CLAUDE.md already imports FSP context — skipping"
fi

# Patch succeeded — disarm the restore trap and clean up backup
trap - ERR
rm -f "$BACKUP"

# 5. Seed IJFW starter memory (if IJFW is installed)
IJFW_MEMORY="$HOME/.ijfw/memory"
if [[ -d "$HOME/.ijfw" ]]; then
    _assert_real_dir "$HOME/.ijfw"
    mkdir -p "$IJFW_MEMORY"
    _assert_real_dir "$IJFW_MEMORY"
    [[ -L "$IJFW_MEMORY/project_fsp.md" ]] && die "$IJFW_MEMORY/project_fsp.md is a symlink — refusing to write"
    if [[ ! -f "$IJFW_MEMORY/project_fsp.md" ]]; then
        cat > "$IJFW_MEMORY/project_fsp.md" <<'MEMEOF'
# FSP — Full Service Pros

## What FSP Does
Licensed general contractor specializing in water/fire/mold remediation and property insurance claims.
Two divisions: Remediation + Repairs & Remodeling.
Insurance claim specialists — help clients recover their entitlements from carriers.

## My Role
[Staff member should fill this in after first session]

## Key Contacts
- Mark Carr — Owner/CEO — mark@fullservicepros.net
- Jordan Wong — Operations Manager
- Kenya Gilfillian — Field Operations Manager
- Jasmine Ann Tambong — Billing Manager

## Systems
- Job channels: #fsp-{job_number}-{client-name} in Slack
- ARWF — internal activity log
- HG Law / Cohen Legal — collections and litigation

## My Active Jobs
[Will build from session history]
MEMEOF
        info "Seeded IJFW FSP memory → $IJFW_MEMORY/project_fsp.md"
    else
        info "IJFW FSP memory already exists — skipping"
    fi
else
    warn "IJFW not installed — skipping memory seed (not required)"
fi

# 6. Role-specific note
echo ""
echo "  ✅ FSP context installed successfully."
echo ""

case "$ROLE" in
    intake)
        echo "  Role: Intake Team"
        echo "  Key shortcuts: 'intake first contact', 'intake schedule', 'intake follow up'"
        ;;
    billing)
        echo "  Role: Billing Team"
        echo "  Key shortcuts: 'billing insurance follow-up', 'billing collections update', 'billing dispute response'"
        ;;
    field)
        echo "  Role: Field Operations"
        echo "  Key shortcuts: 'field check pickup', 'field job report', 'ops schedule'"
        ;;
    management)
        echo "  Role: Management"
        echo "  Key shortcuts: 'mgmt job review', 'mgmt litigation decision', 'mgmt review pipeline'"
        ;;
    *)
        echo "  Tip: Re-run with --role intake|billing|field|management for role-specific hints"
        ;;
esac

echo ""
echo "  Open Claude Code and type 'fsp job update' to test."
echo "  Full shortcut reference: ~/.claude/fsp-shortcuts.md"
echo ""
