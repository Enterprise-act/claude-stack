#!/usr/bin/env bash
# claude-backup.sh — back up your Claude Code setup to Box
#
# What it does:
#   - Bundles ~/.claude/, ~/Library/Application Support/Claude/, peer CLI configs
#   - Strips OAuth tokens, session cookies, and (optionally) API-key .env files
#   - Excludes caches and VM bundles (re-downloadable)
#   - Uploads to box:claude-backup-YYYY-MM-DD/
#   - Includes a restore script
#
# Prerequisites:
#   - rclone installed (brew install rclone)
#   - Box configured as 'box' remote (rclone config)
#
# Usage:  bash ~/Desktop/claude-backup.sh [--small] [--no-secrets]

set -euo pipefail

SMALL_MODE=0
NO_SECRETS=0
for arg in "$@"; do
  case "$arg" in
    --small)      SMALL_MODE=1 ;;
    --no-secrets) NO_SECRETS=1 ;;
    --help|-h) ARG_HELP=1 ;;
    *) printf "\033[31m✗\033[0m Unknown argument: %s\n   Run with --help for usage.\n" "$arg" >&2; exit 2 ;;
  esac
done
if [[ "${ARG_HELP:-0}" == "1" ]]; then
  cat <<EOF
Usage: bash claude-backup.sh [--small] [--no-secrets]

  --small        Skip the Claude desktop app bundle (saves ~1 GB).
  --no-secrets   Strip ~/.claude/.env from the bundle. You'll need to re-add
                 API keys after restore (Slack/OpenAI/etc).

OAuth tokens and browser session data (Cookies, Local/Session Storage,
Local State) are always stripped, regardless of flags.
EOF
  exit 0
fi

STAMP=$(date +%Y-%m-%d)
BOX_DEST="box:claude-backup-$STAMP"
TMP=$(mktemp -d -t claude-backup)
trap 'rm -rf "$TMP"' EXIT

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[33m!\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

bold "=== Pre-flight ==="
command -v rclone >/dev/null 2>&1 || fail "rclone not installed. Run: brew install rclone"
rclone listremotes 2>/dev/null | grep -q "^box:$" \
  || fail "Box not configured. Run: rclone config (see FSP-CLAUDE-BACKUP-GUIDE.md)"
ok "rclone + Box configured"

FREE_GB=$(df -g "$HOME" | tail -1 | awk '{print $4}')
(( FREE_GB >= 3 )) || fail "Only ${FREE_GB} GB free. Need ~3 GB. Empty Trash and retry."
ok "${FREE_GB} GB free disk"

# Sanitized staging area for files we want to alter before bundling
STAGE="$TMP/stage"
mkdir -p "$STAGE"

# ─── Step 1: CLI bundle ──────────────────────────────────────────────────────
bold ""
bold "=== Step 1/4: Bundle Claude Code CLI (sanitized) ==="

if [[ -f "$HOME/.claude.json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$HOME/.claude.json" "$STAGE/.claude.json" <<'PY'
import json, sys, pathlib
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
d = json.loads(src.read_text())
removed = [k for k in ("oauthAccount","userID","claudeCodeFirstTokenDate") if k in d]
for k in removed: d.pop(k)
dst.write_text(json.dumps(d, indent=2))
print(f"  stripped from .claude.json: {removed or 'none'}")
PY
  else
    cp "$HOME/.claude.json" "$STAGE/.claude.json"
    warn "python3 not found — .claude.json copied as-is (OAuth tokens still inside)"
  fi
fi

# Build path list as array — tar this only if non-empty
HAVE_CLI=0
if [[ -d "$HOME/.claude" || -f "$STAGE/.claude.json" ]]; then HAVE_CLI=1; fi

if (( HAVE_CLI == 0 )); then
  warn "No CLI data found — skipping CLI bundle"
  CLI_OUT=""
else
  CLI_OUT="$TMP/claude-cli-$STAMP.tar.gz"

  # Compose tar args portably (no --transform, BSD-tar friendly)
  # We tar from $HOME for .claude/, and from $STAGE for the sanitized .claude.json
  if [[ -d "$HOME/.claude" ]]; then
    # Optionally exclude .env when --no-secrets is set
    EXCLUDE_ENV=()
    if (( NO_SECRETS == 1 )); then
      EXCLUDE_ENV=(--exclude='.claude/.env')
    fi

    tar -czf "$CLI_OUT" \
      "${EXCLUDE_ENV[@]}" \
      --exclude='.claude/nexus-sync/node_modules' \
      --exclude='.claude/plugins/cache' \
      --exclude='.claude/plugins/data' \
      --exclude='.claude/projects/*/sessions' \
      --exclude='.claude/projects/*/*.jsonl' \
      --exclude='.claude/session-env' \
      --exclude='.claude/sessions' \
      --exclude='.claude/session-data' \
      --exclude='.claude/shell-snapshots' \
      --exclude='.claude/cache' \
      --exclude='.claude/logs' \
      --exclude='.claude/telemetry' \
      --exclude='.claude/backups' \
      --exclude='.claude/bash-commands.log' \
      --exclude='.claude/cost-tracker.log' \
      --exclude='.claude/history.jsonl' \
      -C "$HOME" .claude
  else
    : > "$CLI_OUT.empty"
    tar -czf "$CLI_OUT" -T /dev/null
  fi

  # Append the sanitized .claude.json (if present) using a second tar pass via -r
  # Note: -r doesn't work on .tar.gz directly. Workaround: gunzip → append → gzip.
  if [[ -f "$STAGE/.claude.json" ]]; then
    gunzip "$CLI_OUT"
    tar -rf "${CLI_OUT%.gz}" -C "$STAGE" .claude.json
    gzip "${CLI_OUT%.gz}"
  fi

  CLI_SIZE=$(du -h "$CLI_OUT" | cut -f1)
  ok "CLI bundle: $CLI_SIZE  (.claude.json sanitized)"

  if (( NO_SECRETS == 1 )); then
    ok "  ~/.claude/.env excluded (--no-secrets)"
  elif [[ -f "$HOME/.claude/.env" ]]; then
    SECRET_COUNT=$(grep -c '=' "$HOME/.claude/.env" 2>/dev/null || echo 0)
    warn "  ~/.claude/.env included with ${SECRET_COUNT} secrets — keep your Box folder private"
  fi
fi

# ─── Step 2: Desktop app bundle ──────────────────────────────────────────────
bold ""
bold "=== Step 2/4: Bundle Claude desktop app (sanitized) ==="

DESKTOP_OUT=""
if (( SMALL_MODE == 1 )); then
  warn "--small mode: skipping desktop app bundle"
elif [[ ! -d "$HOME/Library/Application Support/Claude" ]]; then
  warn "No Claude desktop app data found — skipping"
else
  DESKTOP_OUT="$TMP/claude-desktop-$STAMP.tar.gz"
  ( cd "$HOME/Library/Application Support" && tar -czf "$DESKTOP_OUT" \
      --exclude='Claude/vm_bundles' \
      --exclude='Claude/Cache' \
      --exclude='Claude/Code Cache' \
      --exclude='Claude/GPUCache' \
      --exclude='Claude/DawnGraphiteCache' \
      --exclude='Claude/DawnWebGPUCache' \
      --exclude='Claude/Crashpad' \
      --exclude='Claude/ServiceWorker' \
      --exclude='Claude/blob_storage' \
      --exclude='Claude/Cookies' \
      --exclude='Claude/Cookies-journal' \
      --exclude='Claude/Local Storage' \
      --exclude='Claude/Session Storage' \
      --exclude='Claude/Local State' \
      Claude )
  DESKTOP_SIZE=$(du -h "$DESKTOP_OUT" | cut -f1)
  ok "Desktop app bundle: $DESKTOP_SIZE  (cookies + local/session storage stripped)"
fi

# ─── Step 3: Peer CLI configs ────────────────────────────────────────────────
bold ""
bold "=== Step 3/4: Bundle peer CLI configs (Codex / IJFW / Gemini) ==="

DOTS_OUT=""
DOT_DIRS=()
[[ -d "$HOME/.codex" ]]  && DOT_DIRS+=(".codex")
[[ -d "$HOME/.ijfw" ]]   && DOT_DIRS+=(".ijfw")
[[ -d "$HOME/.gemini" ]] && DOT_DIRS+=(".gemini")

if [[ ${#DOT_DIRS[@]} -eq 0 ]]; then
  warn "No peer CLI configs found — skipping"
else
  DOTS_OUT="$TMP/dotconfigs-$STAMP.tar.gz"
  ( cd "$HOME" && tar -czf "$DOTS_OUT" \
      --exclude='.codex/cache' \
      --exclude='.codex/logs' \
      --exclude='.codex/auth.json' \
      "${DOT_DIRS[@]}" )
  DOTS_SIZE=$(du -h "$DOTS_OUT" | cut -f1)
  ok "Dotconfigs bundle: $DOTS_SIZE (${DOT_DIRS[*]}; .codex/auth.json stripped)"
fi

# ─── Step 4: Generate restore script ─────────────────────────────────────────
bold ""
bold "=== Step 4/4: Generate restore script ==="

cat > "$TMP/run-restore.sh" <<'RESTORE_SCRIPT'
#!/usr/bin/env bash
# run-restore.sh — restore a Claude backup
# Run AFTER quitting Claude Code CLI and the Claude desktop app.
# Run BEFORE signing into your account on the new machine.

set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[33m!\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✗\033[0m %s\n" "$*"; exit 1; }

# Find bundles using shopt nullglob so missing files don't crash under set -e
shopt -s nullglob
CLI_BUNDLES=( "$HERE"/claude-cli-*.tar.gz )
DESKTOP_BUNDLES=( "$HERE"/claude-desktop-*.tar.gz )
DOTS_BUNDLES=( "$HERE"/dotconfigs-*.tar.gz )
shopt -u nullglob

CLI="${CLI_BUNDLES[0]:-}"
DESKTOP="${DESKTOP_BUNDLES[0]:-}"
DOTS="${DOTS_BUNDLES[0]:-}"

if [[ -z "$CLI" && -z "$DESKTOP" && -z "$DOTS" ]]; then
  fail "No backup bundles found in $HERE"
fi

if pgrep -x "Claude" >/dev/null 2>&1; then
  fail "Claude desktop app is running. Quit it (Cmd+Q) and re-run."
fi
if pgrep -x claude >/dev/null 2>&1; then
  fail "Claude Code CLI is running. Exit it and re-run."
fi
ok "Claude not running — safe to restore"

# Move existing dirs aside (atomically reversible if anything fails)
move_aside() {
  local p="$1"
  if [[ -e "$p" ]]; then
    mv "$p" "${p}.old.$STAMP"
    ok "Backed up: $(basename "$p") → $(basename "$p").old.$STAMP"
  fi
}
[[ -n "$CLI" ]]     && { move_aside "$HOME/.claude"; move_aside "$HOME/.claude.json"; }
[[ -n "$DESKTOP" ]] && move_aside "$HOME/Library/Application Support/Claude"
[[ -n "$DOTS" ]]    && { move_aside "$HOME/.codex"; move_aside "$HOME/.ijfw"; move_aside "$HOME/.gemini"; }

# Extract
[[ -n "$CLI" ]]     && { ( cd "$HOME" && tar -xzf "$CLI" --no-same-owner ); ok "CLI restored"; }
[[ -n "$DESKTOP" ]] && { ( cd "$HOME/Library/Application Support" && tar -xzf "$DESKTOP" --no-same-owner ); ok "Desktop app restored"; }
[[ -n "$DOTS" ]]    && { ( cd "$HOME" && tar -xzf "$DOTS" --no-same-owner ); ok "Peer CLIs restored"; }

echo ""
bold "=== Restore complete. Next steps: ==="
echo "  1. Launch \`claude\` → log in as your FSP account"
echo "  2. Launch the Claude desktop app → log in"
echo "  3. claude.ai → Settings → Connectors → re-auth your MCPs"
if [[ -n "$CLI" && ! -f "$HOME/.claude/.env" ]]; then
  echo "  4. Re-add your API keys to ~/.claude/.env (was stripped from backup)"
fi
echo ""
echo "Old data kept at *.old.$STAMP — delete after a day or two of soak with no issues."
RESTORE_SCRIPT
chmod +x "$TMP/run-restore.sh"
ok "Restore script generated"

# ─── Upload ──────────────────────────────────────────────────────────────────
bold ""
bold "=== Uploading to Box ==="
rclone mkdir "$BOX_DEST" 2>/dev/null

shopt -s nullglob
UPLOADS=( "$TMP"/*.tar.gz "$TMP"/run-restore.sh )
shopt -u nullglob
for f in "${UPLOADS[@]}"; do
  [[ -f "$f" ]] || continue
  echo ""
  echo "→ $(basename "$f")"
  rclone copy "$f" "$BOX_DEST/" \
    --disable-http2 \
    --retries=10 \
    --low-level-retries=20 \
    --progress --stats=30s 2>&1 | tail -3
done

bold ""
bold "=== Verifying ==="
rclone size "$BOX_DEST"

bold ""
ok "Backup complete."
echo "Box folder: $BOX_DEST"
echo ""
echo "To restore on a new Mac later:"
echo "  rclone copy \"$BOX_DEST/\" ~/Desktop/restore --progress --disable-http2"
echo "  bash ~/Desktop/restore/run-restore.sh"
