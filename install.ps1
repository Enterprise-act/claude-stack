#Requires -Version 5.1
# Full Service Pros — Claude Stack Installer (Windows / PowerShell)
#
# RECOMMENDED — download, review, then run:
#   iwr -OutFile install.ps1 https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.ps1
#   notepad install.ps1    # review before executing
#   .\install.ps1
#
# One-liner (only if you have verified the commit SHA matches a known-good release):
#   iwr -useb https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.ps1 | iex
#
# WSL2 users: use install.sh instead — it runs natively inside WSL2 Ubuntu.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$REPO            = "https://github.com/carrmjw/claude-stack.git"
$BRANCH          = "main"
# -------------------------------------------------------------------------
# PINNED_SHA: set this to a known-good commit SHA before distributing to
# staff. Leaving it empty trusts the mutable 'main' branch — acceptable for
# personal use, NOT for org-wide rollout.
#
# Find the current HEAD SHA:  gh api repos/carrmjw/claude-stack/commits/main --jq .sha
# Then set:  $PINNED_SHA = "abc123..."
# -------------------------------------------------------------------------
$PINNED_SHA      = ""
$CLAUDE_DIR      = Join-Path $env:USERPROFILE ".claude"
$STACK_DIR       = Join-Path $CLAUDE_DIR "fsp-stack"
$SKILLS_DIR      = Join-Path $CLAUDE_DIR "skills"
$MANIFEST        = Join-Path $CLAUDE_DIR ".fsp-skills-manifest"
$FSP_MARKER      = "# FSP-MANAGED-SCRIPT"
$FSP_MARKER_FILE = ".fsp-managed"

function Write-Ok   { param($m) Write-Host "  $m" -ForegroundColor Green  }
function Write-Warn { param($m) Write-Host "  $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  $m" -ForegroundColor Red    }

Write-Host ""
Write-Host "  Full Service Pros — Claude Stack" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# Early warning — loud, before anything is installed
if ($PINNED_SHA -eq "") {
    Write-Warn "============================================================"
    Write-Warn "  SECURITY: PINNED_SHA is not set."
    Write-Warn "  This script will install whatever is currently on 'main'."
    Write-Warn "  For personal use this is fine."
    Write-Warn "  Before distributing to FSP staff, pin a verified SHA:"
    Write-Warn "    gh api repos/carrmjw/claude-stack/commits/main --jq .sha"
    Write-Warn "  then set `$PINNED_SHA in this script and re-distribute."
    Write-Warn "============================================================"
    Write-Host ""
}

# 1. Prerequisites
$prereqFail = $false
foreach ($req in @("node", "npm", "git")) {
    if (-not (Get-Command $req -ErrorAction SilentlyContinue)) {
        $prereqFail = $true
        switch ($req) {
            "node" { Write-Err "Missing: node  — Install Node.js from https://nodejs.org" }
            "npm"  { Write-Err "Missing: npm   — comes with Node.js" }
            "git"  { Write-Err "Missing: git   — Install from https://git-scm.com" }
        }
    }
}
$pythonCmd = $null
foreach ($py in @("python3", "python")) {
    if (Get-Command $py -ErrorAction SilentlyContinue) { $pythonCmd = $py; break }
}
if (-not $pythonCmd) {
    $prereqFail = $true
    Write-Err "Missing: python — Install from https://python.org or the Microsoft Store"
}
if ($prereqFail) { exit 1 }

# 2. Install Claude Code CLI if missing
if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
    npm install -g "@anthropic-ai/claude-code@2.1.126" *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "✗ npm install failed (exit $LASTEXITCODE). Fix npm, then re-run."
        exit 1
    }
    Write-Ok "✓ Claude Code installed"
} else {
    Write-Ok "✓ Claude Code already installed"
}

# 3. Clone or update the stack repo
New-Item -ItemType Directory -Force -Path $CLAUDE_DIR | Out-Null
$gitNoHooks  = @("-c", "core.hooksPath=NUL")   # NUL = Windows /dev/null for git hooks
$freshClone  = $false   # initialized here so StrictMode never sees it undefined

$normUrl = { param($u) $u.TrimEnd('/') -replace '\.git$','' -replace '^git@github\.com:','https://github.com/' }

if (Test-Path (Join-Path $STACK_DIR ".git")) {
    $actualRemote = (git -C $STACK_DIR remote get-url origin 2>$null).Trim()
    if ((& $normUrl $actualRemote) -ne (& $normUrl $REPO)) {
        Write-Err "Error: $STACK_DIR points to '$actualRemote', expected '$REPO' (or SSH/no-.git equivalent)."
        Write-Err "Remove it manually:  Remove-Item -Recurse -Force '$STACK_DIR'"
        exit 1
    }
    git @gitNoHooks -C $STACK_DIR fetch --quiet origin $BRANCH
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Error: git fetch failed (exit $LASTEXITCODE). Check network and retry."
        exit 1
    }
    if ($PINNED_SHA -ne "") {
        $fetchSha = (git -C $STACK_DIR rev-parse FETCH_HEAD).Trim()
        if ($fetchSha -ne $PINNED_SHA) {
            Write-Err "Error: fetched HEAD $fetchSha does not match PINNED_SHA $PINNED_SHA. Aborting."
            exit 1
        }
    }
    git @gitNoHooks -C $STACK_DIR merge --ff-only --quiet FETCH_HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Cannot fast-forward. Run: git -C '$STACK_DIR' pull"
        exit 1
    }
    Write-Ok "✓ Stack at $(git -C $STACK_DIR rev-parse --short HEAD)"
} else {
    $freshClone = $true
    git @gitNoHooks clone --quiet --branch $BRANCH $REPO $STACK_DIR
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Error: git clone failed (exit $LASTEXITCODE). Check network and retry."
        exit 1
    }
    Write-Ok "✓ Stack cloned at $(git -C $STACK_DIR rev-parse --short HEAD)"
}

# Commit verification — on a fresh clone, remove the untrusted checkout if SHA mismatches
# so the next install run doesn't treat it as a valid pre-existing stack.
$actualSha = (git -C $STACK_DIR rev-parse HEAD).Trim()
$shaFile   = Join-Path $CLAUDE_DIR ".fsp-pinned-sha"
if ($PINNED_SHA -ne "") {
    if ($actualSha -ne $PINNED_SHA) {
        Write-Err "Error: HEAD $actualSha does not match PINNED_SHA $PINNED_SHA. Aborting."
        if ($freshClone) {
            Write-Err "Removing unverified clone at $STACK_DIR"
            Remove-Item -Recurse -Force $STACK_DIR -ErrorAction SilentlyContinue
        }
        exit 1
    }
    Set-Content -Path $shaFile -Value $actualSha -Encoding UTF8
    Write-Ok "✓ Commit verified: $($actualSha.Substring(0,8))"
}

# 4. Sync FSP-managed skills
New-Item -ItemType Directory -Force -Path $SKILLS_DIR | Out-Null
$skillsSrcDir = Join-Path $STACK_DIR "skills"
if (-not (Test-Path $skillsSrcDir) -or
    -not (Get-ChildItem $skillsSrcDir -Directory -ErrorAction SilentlyContinue)) {
    Write-Err "Error: $skillsSrcDir is missing or empty after clone. Aborting skill sync."
    exit 1
}

if (Test-Path $MANIFEST) {
    Get-Content $MANIFEST | ForEach-Object {
        $safe = $_ -replace '[^a-zA-Z0-9_-]', ''
        if (-not [string]::IsNullOrEmpty($safe) -and $safe -eq $_) {
            $skillDir   = Join-Path $SKILLS_DIR $safe
            $markerPath = Join-Path $skillDir $FSP_MARKER_FILE
            if ((Test-Path $skillDir) -and (Test-Path $markerPath)) {
                $marker = (Get-Content $markerPath -Raw -ErrorAction SilentlyContinue).Trim()
                if ($marker -eq "FSP:carrmjw/claude-stack" -and
                    -not (Test-Path (Join-Path $skillsSrcDir $safe))) {
                    Write-Host "  Removing retired FSP skill: $safe"
                    Remove-Item -Recurse -Force $skillDir
                }
            }
        }
    }
}

$skillCount    = 0
$fatalErrors   = 0
$manifestLines = [System.Collections.Generic.List[string]]::new()
Get-ChildItem $skillsSrcDir -Directory | ForEach-Object {
    $skill      = $_.Name
    $safe       = $skill -replace '[^a-zA-Z0-9_-]', ''
    if ([string]::IsNullOrEmpty($safe) -or $safe -ne $skill) {
        Write-Host "  Skipping unsafe skill name: $skill"; return
    }
    $skillDest  = Join-Path $SKILLS_DIR $safe
    $markerPath = Join-Path $skillDest $FSP_MARKER_FILE
    $isOwned    = (Test-Path $markerPath) -and
                  ((Get-Content $markerPath -Raw -ErrorAction SilentlyContinue).Trim() -eq "FSP:carrmjw/claude-stack")

    if (-not (Test-Path $skillDest) -or $isOwned) {
        robocopy $_.FullName $skillDest /MIR /E /NFL /NDL /NJH /NJS 2>$null | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -le 7) {
            # 0-7: success variants (0=no change, 1=copied, 3=copied+extra, etc.)
            Set-Content -Path $markerPath -Value "FSP:carrmjw/claude-stack" -Encoding UTF8
            $manifestLines.Add($safe)
            $skillCount++
        } elseif ($rc -lt 16) {
            # 8-15: partial failure — exclude from manifest so a re-run retries rather
            # than treating partial state as installed.
            Write-Warn "  ⚠ robocopy partial failure (exit $rc) for skill '$safe' — some files may be missing"
            $fatalErrors++
        } else {
            # 16+: fatal failure — skill skipped entirely
            Write-Err "  ✗ robocopy fatal failure (exit $rc) for skill '$safe' — skipped entirely"
            $fatalErrors++
        }
    } else {
        Write-Host "  Skipping user-owned skill: $safe"
    }
}
if ($fatalErrors -gt 0) {
    # Don't overwrite the manifest — preserve the last known-good ownership state
    # so a re-run can still retire skills that were previously tracked.
    Write-Err "✗ $fatalErrors skill(s) had robocopy failures (exit ≥ 8). Re-run after checking disk space and folder permissions."
    exit 1
}
Set-Content -Path $MANIFEST -Value ($manifestLines -join "`n") -Encoding UTF8
Write-Ok "✓ $skillCount skills installed/updated"

# 5. Install plugins
$pluginErrors = 0
@("everything-claude-code@1.10.0", "openai-codex@1.0.4", "ijfw@1.0.0") | ForEach-Object {
    claude plugins install $_ *>$null
    if ($LASTEXITCODE -eq 0) { Write-Ok "  ✓ $_" }
    else { Write-Warn "  ⚠ $_ — run manually: claude plugins install $_"; $pluginErrors++ }
}
if ($pluginErrors -gt 0) { Write-Warn "  Verify: claude plugins list" }

# 6. Add local MCP servers
# Commands stored as arrays — avoids -split ' ' fragility with future quoted args.
$mcpSpecs = @(
    @{ Name="github";              Args=@("npx","-y","@modelcontextprotocol/server-github@2025.4.8") }
    @{ Name="context7";            Args=@("npx","-y","@upstash/context7-mcp@2.1.4") }
    @{ Name="memory";              Args=@("npx","-y","@modelcontextprotocol/server-memory@2026.1.26") }
    @{ Name="playwright";          Args=@("npx","-y","@playwright/mcp@0.0.69","--extension") }
    @{ Name="sequential-thinking"; Args=@("npx","-y","@modelcontextprotocol/server-sequential-thinking@2025.12.18") }
    @{ Name="chrome-devtools";     Args=@("npx","-y","chrome-devtools-mcp@0.23.0","--no-usage-statistics") }
)
$mcpListOutput = (claude mcp list 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0) {
    Write-Warn "  ⚠ 'claude mcp list' failed — will attempt to register all MCPs (already-registered ones will warn)"
    $mcpListOutput = ""
}
foreach ($spec in $mcpSpecs) {
    $name    = $spec.Name
    $mcpArgs = $spec.Args   # avoid $args — that's a PowerShell automatic variable
    if ($mcpListOutput -match "(?m)^${name}:") { Write-Ok "  ✓ mcp/$name already registered" }
    else {
        claude mcp add $name -- @mcpArgs *>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "  ✓ mcp/$name" }
        else { Write-Warn "  ⚠ mcp/$name — add manually: claude mcp add $name -- $($mcpArgs -join ' ')" }
    }
}

# Helper: edit settings.json safely.
# Returns $true on success, $false on any failure (restores backup automatically).
# Python scripts must exit non-zero on ALL error paths — including JSONDecodeError —
# so this function's $LASTEXITCODE check correctly surfaces every failure.
function Edit-SettingsJson {
    param([string]$SettingsPath, [string]$PyScript, [string[]]$ExtraArgs)
    $backup = $SettingsPath + ".bak"
    if (Test-Path $SettingsPath) {
        Copy-Item $SettingsPath $backup -Force
    }
    try {
        & $pythonCmd -c $PyScript $SettingsPath @ExtraArgs
        if ($LASTEXITCODE -ne 0) { throw "Python exited $LASTEXITCODE" }
        if (Test-Path $backup) { Remove-Item $backup -Force }
        return $true
    } catch {
        Write-Warn "  ⚠ settings.json edit failed: $_"
        if (Test-Path $backup) {
            Write-Warn "  Restoring backup from $backup"
            Copy-Item $backup $SettingsPath -Force
            Remove-Item $backup -Force
        }
        return $false
    }
}

# 6b. n8n-mcp HTTP server
$envFile  = Join-Path $CLAUDE_DIR ".env"
$n8nToken = ""
if (Test-Path $envFile) {
    $line = Get-Content $envFile | Where-Object { $_ -match '^N8N_MCP_TOKEN=' } | Select-Object -First 1
    if ($line) { $n8nToken = ($line -split '=', 2)[1].Trim().Trim("`"'") }
}
if ($n8nToken -ne "") {
    $pyN8n = @'
import json, sys
path, token = sys.argv[1], sys.argv[2]
try:
    cfg = json.load(open(path))
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    print(f"WARN: {path} has invalid JSON ({e}) — skipping n8n-mcp registration", file=sys.stderr)
    sys.exit(1)
cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["n8n-mcp"] = {
    "type": "http",
    "url": "https://enterpriseact.app.n8n.cloud/mcp-server/http",
    "headers": {"Authorization": f"Bearer {token}"}
}
json.dump(cfg, open(path, "w"), indent=2)
'@
    if (Edit-SettingsJson -SettingsPath (Join-Path $CLAUDE_DIR "settings.json") `
                          -PyScript $pyN8n -ExtraArgs @($n8nToken)) {
        Write-Ok "  ✓ mcp/n8n-mcp"
    } else {
        Write-Warn "  ⚠ mcp/n8n-mcp — settings.json edit failed; fix JSON then re-run"
    }
} else { Write-Warn "  ⚠ mcp/n8n-mcp — set N8N_MCP_TOKEN in $envFile and re-run" }

# 7. CLAUDE.md template
$claudeMd       = Join-Path $CLAUDE_DIR "CLAUDE.md"
$claudeTemplate = Join-Path $STACK_DIR "config\CLAUDE.md.template"
if (-not (Test-Path $claudeMd)) {
    if (Test-Path $claudeTemplate) { Copy-Item $claudeTemplate $claudeMd; Write-Ok "✓ CLAUDE.md created" }
    else { Write-Warn "⚠ CLAUDE.md.template missing in repo — skipped" }
} else { Write-Warn "⚠ CLAUDE.md already exists — skipped" }

# 8. .env setup
if (-not (Test-Path $envFile)) {
    $envTemplate = Join-Path $STACK_DIR "config\.env.template"
    if (Test-Path $envTemplate) {
        Copy-Item $envTemplate $envFile
        # Restrict .env to current user while preserving SYSTEM + Administrators.
        # icacls is safer than SetAccessRuleProtection($true,$false), which strips
        # inherited SYSTEM/Admin rules and can break backup tools and admin access.
        # Use the full Windows identity — $env:USERNAME is truncated for domain/MSA accounts.
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        icacls $envFile /inheritance:r `
            /grant "${currentUser}:F" /grant "SYSTEM:F" /grant "Administrators:F" `
            2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "  ⚠ icacls failed (exit $LASTEXITCODE) — .env permissions may be too broad."
            Write-Warn "    Fix manually: icacls `"$envFile`" /inheritance:r /grant `"${currentUser}:F`""
        }
        Write-Warn "⚠ Fill in your API keys: $envFile"
    } else { Write-Warn "⚠ .env.template missing in repo — create $envFile manually" }
}

# 8b. claude-update.ps1
$updateSrc  = Join-Path $STACK_DIR "scripts\claude-update.ps1"
$userBin    = Join-Path $env:USERPROFILE ".local\bin"
$updateDest = Join-Path $userBin "claude-update.ps1"
if (Test-Path $updateSrc) {
    New-Item -ItemType Directory -Force -Path $userBin | Out-Null
    $existing = if (Test-Path $updateDest) { Get-Content $updateDest -Raw } else { "" }
    if ($existing -match [regex]::Escape($FSP_MARKER) -or -not (Test-Path $updateDest)) {
        Copy-Item $updateSrc $updateDest -Force
        Write-Ok "✓ claude-update.ps1 installed at $updateDest"
        Write-Warn "  Add to PATH: [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$userBin', 'User')"
    } else { Write-Warn "⚠ $updateDest exists and is not FSP-managed — skipped" }
}

# 9. Prompt-quality hook (bash-only — skipped when bash is not available)
$hooksDir = Join-Path $CLAUDE_DIR "hooks"
$hookSrc  = Join-Path $STACK_DIR "config\hooks\fsp-prompt-quality.sh"
$hookDest = Join-Path $hooksDir "fsp-prompt-quality.sh"
$bashCmd  = Get-Command "bash" -ErrorAction SilentlyContinue
if (-not $bashCmd) {
    Write-Warn "⚠ prompt-quality hook skipped — bash not found. Install WSL2 or Git for Windows and re-run to enable."
} elseif (Test-Path $hookSrc) {
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
    Copy-Item $hookSrc $hookDest -Force
    $pyHook = @'
import json, sys, shlex
path, hook_path = sys.argv[1], sys.argv[2]
hook_cmd = "bash " + shlex.quote(hook_path.replace("\\", "/"))
try:
    cfg = json.load(open(path))
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as e:
    print(f"WARN: {path} has invalid JSON ({e}) — skipping hook registration", file=sys.stderr)
    sys.exit(1)
cfg.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
existing = [h.get("command","") for e in cfg["hooks"]["UserPromptSubmit"] for h in e.get("hooks",[])]
if not any("fsp-prompt-quality" in c for c in existing):
    cfg["hooks"]["UserPromptSubmit"].append({"hooks": [{"type":"command","command": hook_cmd}]})
    json.dump(cfg, open(path, "w"), indent=2)
'@
    if (Edit-SettingsJson -SettingsPath (Join-Path $CLAUDE_DIR "settings.json") `
                          -PyScript $pyHook -ExtraArgs @($hookDest)) {
        Write-Ok "✓ prompt-quality hook installed"
    } else {
        Write-Warn "⚠ prompt-quality hook — settings.json edit failed; fix JSON then re-run"
    }
} else { Write-Warn "⚠ fsp-prompt-quality.sh missing from stack — skipped" }

Write-Host ""
Write-Ok "Done!"
Write-Host ""
Write-Host "  1. Run: claude                    <- start Claude Code"
Write-Host "  2. Run: claude-update.ps1         <- pull latest skills from Mark"
Write-Host "  3. Edit: $envFile"
Write-Host "           Add your personal API keys (N8N, Nimble, etc.)"
Write-Host "  4. Connect integrations:  https://claude.ai/settings/integrations"
Write-Host ""
