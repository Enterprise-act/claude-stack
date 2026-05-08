# FSP-MANAGED-SCRIPT
# Full Service Pros — Claude Stack Updater (Windows / PowerShell)
# Installed to %USERPROFILE%\.local\bin\claude-update.ps1 by install.ps1

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$REPO            = "https://github.com/carrmjw/claude-stack.git"
$BRANCH          = "main"
$STACK_DIR       = Join-Path $env:USERPROFILE ".claude\fsp-stack"
$SKILLS_DIR      = Join-Path $env:USERPROFILE ".claude\skills"
$MANIFEST        = Join-Path $env:USERPROFILE ".claude\.fsp-skills-manifest"
$FSP_MARKER_FILE = ".fsp-managed"

foreach ($req in @("git")) {
    if (-not (Get-Command $req -ErrorAction SilentlyContinue)) {
        Write-Error "Error: '$req' is required. Install from https://git-scm.com and retry."
        exit 1
    }
}

if (-not (Test-Path (Join-Path $STACK_DIR ".git"))) {
    Write-Host "FSP stack not found at $STACK_DIR. Run the installer first:"
    Write-Host "  iwr -OutFile install.ps1 https://raw.githubusercontent.com/carrmjw/claude-stack/main/install.ps1"
    Write-Host "  .\install.ps1"
    exit 1
}

$normUrl      = { param($u) $u.TrimEnd('/') -replace '\.git$','' -replace '^git@github\.com:','https://github.com/' }
$actualRemote = (git -C $STACK_DIR remote get-url origin 2>$null).Trim()
if ((& $normUrl $actualRemote) -ne (& $normUrl $REPO)) {
    Write-Error "Error: remote mismatch ('$actualRemote'). Expected '$REPO' (or SSH/no-.git equivalent). Aborting."
    exit 1
}

git -c core.hooksPath=NUL -C $STACK_DIR fetch --quiet origin $BRANCH
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: git fetch failed (exit $LASTEXITCODE). Check network and retry."
    exit 1
}

$shaFile = Join-Path $env:USERPROFILE ".claude\.fsp-pinned-sha"
if (Test-Path $shaFile) {
    $pinnedSha = (Get-Content $shaFile -Raw).Trim()
    $actualSha = (git -C $STACK_DIR rev-parse FETCH_HEAD).Trim()
    if ($actualSha -ne $pinnedSha) {
        Write-Error "Error: fetched HEAD $actualSha does not match pinned SHA $pinnedSha."
        Write-Host "If intentional, update $shaFile with the new SHA, then re-run."
        exit 1
    }
    Write-Host "✓ Commit verified: $($actualSha.Substring(0,8))"
} else {
    Write-Host "⚠ No pinned SHA on file — update is unverified."
}

git -c core.hooksPath=NUL -C $STACK_DIR merge --ff-only --quiet FETCH_HEAD 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Cannot fast-forward. Run: git -C '$STACK_DIR' pull"
    exit 1
}

New-Item -ItemType Directory -Force -Path $SKILLS_DIR | Out-Null
$skillsSrcDir = Join-Path $STACK_DIR "skills"
if (-not (Test-Path $skillsSrcDir) -or
    -not (Get-ChildItem $skillsSrcDir -Directory -ErrorAction SilentlyContinue)) {
    Write-Error "Error: $skillsSrcDir is missing or empty after pull. Aborting skill sync."
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

$manifestLines = [System.Collections.Generic.List[string]]::new()
$fatalErrors   = 0
Get-ChildItem $skillsSrcDir -Directory | ForEach-Object {
    $skill      = $_.Name
    $safe       = $skill -replace '[^a-zA-Z0-9_-]', ''
    if ([string]::IsNullOrEmpty($safe) -or $safe -ne $skill) { return }
    $skillDest  = Join-Path $SKILLS_DIR $safe
    $markerPath = Join-Path $skillDest $FSP_MARKER_FILE
    $isOwned    = (Test-Path $markerPath) -and
                  ((Get-Content $markerPath -Raw -ErrorAction SilentlyContinue).Trim() -eq "FSP:carrmjw/claude-stack")
    if (-not (Test-Path $skillDest) -or $isOwned) {
        robocopy $_.FullName $skillDest /MIR /E /NFL /NDL /NJH /NJS 2>$null | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -le 7) {
            Set-Content -Path $markerPath -Value "FSP:carrmjw/claude-stack" -Encoding UTF8
            $manifestLines.Add($safe)
        } elseif ($rc -lt 16) {
            # 8-15: partial failure — excluded from manifest so re-run retries it
            Write-Host "  ⚠ robocopy partial failure (exit $rc) for skill '$safe' — some files may be missing"
            $fatalErrors++
        } else {
            Write-Host "  ✗ robocopy fatal failure (exit $rc) for skill '$safe' — skipped"
            $fatalErrors++
        }
    }
}
if ($fatalErrors -gt 0) {
    # Don't overwrite the manifest — preserve the last known-good ownership state
    # so a re-run can still retire skills that were previously tracked.
    Write-Error "Update aborted: $fatalErrors skill(s) had robocopy failures (exit ≥ 8). Re-run after checking disk space and folder permissions."
    exit 1
}
Set-Content -Path $MANIFEST -Value ($manifestLines -join "`n") -Encoding UTF8

$hookSrc  = Join-Path $STACK_DIR "config\hooks\fsp-prompt-quality.sh"
$hookDest = Join-Path $env:USERPROFILE ".claude\hooks\fsp-prompt-quality.sh"
if (Test-Path $hookSrc) {
    New-Item -ItemType Directory -Force -Path (Split-Path $hookDest) | Out-Null
    Copy-Item $hookSrc $hookDest -Force
}

Write-Host "✓ Claude Stack updated to $(git -C $STACK_DIR rev-parse --short HEAD)"
