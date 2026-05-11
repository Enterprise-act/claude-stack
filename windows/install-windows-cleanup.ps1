#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-time setup: schedules automated Claude cleanup on a Windows staff machine.

.DESCRIPTION
    Copies claude-cleanup.ps1 to C:\ProgramData\ClaudeCleanup\, creates two
    Task Scheduler jobs (nightly 2am + Sunday 3am deep), and creates a desktop
    shortcut for on-demand runs. Safe to re-run (idempotent).

.NOTES
    Run as Administrator. No MDM required — uses built-in Task Scheduler.
    Tested on Windows 10 21H2+ and Windows 11.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallDir   = 'C:\ProgramData\ClaudeCleanup'
$ScriptSrc    = Join-Path $PSScriptRoot 'claude-cleanup.ps1'
$ScriptDst    = Join-Path $InstallDir  'claude-cleanup.ps1'
$LogDir       = Join-Path $InstallDir  'logs'
$TaskNightly  = 'ClaudeNightlyCleanup'
$TaskWeekly   = 'ClaudeWeeklyDeepClean'

function Write-Step { param([string]$Msg) Write-Host "→ $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }

# ── 1. COPY SCRIPT ───────────────────────────────────────────────────────────
Write-Step "Installing cleanup script to $InstallDir..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir     | Out-Null

if (-not (Test-Path $ScriptSrc)) {
    Write-Host "ERROR: claude-cleanup.ps1 not found at $ScriptSrc" -ForegroundColor Red
    Write-Host "Place install-windows-cleanup.ps1 in the same folder as claude-cleanup.ps1."
    exit 1
}
Copy-Item -Path $ScriptSrc -Destination $ScriptDst -Force
Write-OK "Script installed to $ScriptDst"

# ── 2. EXECUTION POLICY (scope: LocalMachine, only if needed) ─────────────
$policy = Get-ExecutionPolicy -Scope LocalMachine
if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
    Write-Step "Relaxing ExecutionPolicy to RemoteSigned for LocalMachine..."
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
    Write-OK "ExecutionPolicy set to RemoteSigned"
} else {
    Write-OK "ExecutionPolicy already permissive ($policy)"
}

# ── 3. HELPER: create / replace a scheduled task ─────────────────────────────
function Register-CleanupTask {
    param(
        [string]$TaskName,
        [string]$Args,
        [object]$Trigger,
        [string]$Description
    )

    $action  = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptDst`" $Args"

    # SYSTEM account: runs even when no user is logged in; doesn't need a password
    $principal = New-ScheduledTaskPrincipal `
        -UserId 'SYSTEM' `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `         # Run missed jobs when machine comes online
        -DontStopOnIdleEnd `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -MultipleInstances IgnoreNew

    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    Register-ScheduledTask `
        -TaskName    $TaskName `
        -Description $Description `
        -Action      $action `
        -Trigger     $Trigger `
        -Principal   $principal `
        -Settings    $settings `
        -Force | Out-Null
}

# ── 4. NIGHTLY TASK (2am every night) ────────────────────────────────────────
Write-Step "Creating nightly cleanup task ($TaskNightly)..."
$nightlyTrigger = New-ScheduledTaskTrigger -Daily -At '02:00'
Register-CleanupTask `
    -TaskName    $TaskNightly `
    -Args        '' `
    -Trigger     $nightlyTrigger `
    -Description 'Claude nightly cache + process cleanup (2am daily)'
Write-OK "Task created: $TaskNightly"

# ── 5. WEEKLY DEEP-CLEAN TASK (Sunday 3am) ────────────────────────────────────
Write-Step "Creating weekly deep-clean task ($TaskWeekly)..."
$weeklyTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '03:00'
Register-CleanupTask `
    -TaskName    $TaskWeekly `
    -Args        '-Deep' `
    -Trigger     $weeklyTrigger `
    -Description 'Claude weekly deep clean: GPU cache, Code Cache, Session Storage (Sunday 3am)'
Write-OK "Task created: $TaskWeekly"

# ── 6. DESKTOP SHORTCUT ───────────────────────────────────────────────────────
Write-Step "Creating desktop shortcut..."
$desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
$shortcutPath = Join-Path $desktopPath 'Run Claude Cleanup Now.lnk'

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = 'powershell.exe'
$shortcut.Arguments        = "-NonInteractive -WindowStyle Normal -ExecutionPolicy Bypass -File `"$ScriptDst`""
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Description      = 'Run Claude cleanup immediately'
$shortcut.IconLocation     = '%SystemRoot%\System32\cleanmgr.exe,0'
$shortcut.Save()

Write-OK "Shortcut created: $shortcutPath"

# ── 7. SMOKE TEST ─────────────────────────────────────────────────────────────
Write-Step "Running smoke test (nightly mode)..."
try {
    & powershell.exe -NonInteractive -ExecutionPolicy Bypass -File $ScriptDst
    Write-OK "Smoke test passed — check $LogDir for output"
} catch {
    Write-Warn "Smoke test failed: $_"
    Write-Warn "Check $LogDir for details"
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════" -ForegroundColor White
Write-Host "  Install complete" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════" -ForegroundColor White
Write-Host "Scheduled tasks:"
Write-Host "  $TaskNightly  — 2am nightly"
Write-Host "  $TaskWeekly   — Sunday 3am"
Write-Host ""
Write-Host "Script:  $ScriptDst"
Write-Host "Logs:    $LogDir"
Write-Host "Shortcut: Desktop → 'Run Claude Cleanup Now'"
Write-Host ""
Write-Host "Done. No further action needed on this machine." -ForegroundColor Green
