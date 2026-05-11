#Requires -Version 5.1
<#
.SYNOPSIS
    Nightly cleanup for Claude Desktop on Windows staff machines.

.DESCRIPTION
    Kills bloated Claude Helper renderer processes, clears Claude's cache dirs,
    trims session logs and temp files, and logs everything with MB reclaimed.
    Safe: never kills Claude.exe (the main process), only renderer helpers
    that have been running >30 min with >800MB RAM.

.PARAMETER Deep
    Weekly deep mode: also clears GPU shader cache, Code Cache, and larger
    Session Storage accumulations. Run as: claude-cleanup.ps1 -Deep

.EXAMPLE
    .\claude-cleanup.ps1
    .\claude-cleanup.ps1 -Deep
#>
[CmdletBinding()]
param(
    [switch]$Deep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Log errors, don't abort

# ── CONFIG ──────────────────────────────────────────────────────────────────
$LogDir    = "$env:ProgramData\ClaudeCleanup\logs"
$LogDate   = Get-Date -Format 'yyyy-MM-dd'
$LogFile   = "$LogDir\cleanup-$LogDate.log"
$TotalMB   = 0
$Reaped    = 0

# Helper renderer kill thresholds
$MIN_RAM_MB   = 800   # Only kill helpers consuming more than this
$MIN_UPTIME_M = 30    # Only kill helpers running longer than this (minutes)

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Add-Freed {
    param([double]$MB, [string]$Label)
    $script:TotalMB += $MB
    if ($MB -gt 0) {
        Write-Log ("  ✓ {0}: freed {1:F1}MB" -f $Label, $MB)
    }
}

function Get-DirSizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $bytes = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($bytes / 1MB, 2)
    } catch { return 0 }
}

function Remove-OldFiles {
    param([string]$Path, [int]$OlderThanDays, [string]$Filter = '*')
    if (-not (Test-Path $Path)) { return 0 }
    $before = Get-DirSizeMB $Path
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    Get-ChildItem -Path $Path -Filter $Filter -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $after = Get-DirSizeMB $Path
    return [math]::Max(0, $before - $after)
}

function Clear-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $before = Get-DirSizeMB $Path
    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $after = Get-DirSizeMB $Path
    return [math]::Max(0, $before - $after)
}

# ── START ────────────────────────────────────────────────────────────────────
$mode = if ($Deep) { "DEEP" } else { "nightly" }
Write-Log "=== Claude Cleanup START ($mode) ==="

# ── 1. KILL BLOATED CLAUDE HELPER (RENDERER) PROCESSES ──────────────────────
Write-Log "→ Checking for bloated Claude renderer processes..."

$helpers = Get-Process -Name 'Claude Helper (Renderer)' -ErrorAction SilentlyContinue
if (-not $helpers) {
    $helpers = Get-Process -Name 'Claude Helper' -ErrorAction SilentlyContinue |
               Where-Object { $_.MainWindowTitle -eq '' }
}

foreach ($proc in $helpers) {
    try {
        $ramMB    = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        $startTime = $proc.StartTime
        $uptimeMin = (New-TimeSpan -Start $startTime -End (Get-Date)).TotalMinutes

        if ($ramMB -gt $MIN_RAM_MB -and $uptimeMin -gt $MIN_UPTIME_M) {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            $Reaped++
            Write-Log ("  ✓ Killed PID {0} ({1}MB, {2:F0}min uptime)" -f $proc.Id, $ramMB, $uptimeMin)
        } else {
            Write-Log ("  · Skipped PID {0} ({1}MB, {2:F0}min — under threshold)" -f $proc.Id, $ramMB, $uptimeMin)
        }
    } catch {
        Write-Log ("  ⚠ Could not kill PID {0}: $_" -f $proc.Id)
    }
}

if ($Reaped -eq 0) {
    Write-Log "  · No bloated helpers found"
}

# Trim working sets of remaining Claude processes (frees compressed memory pages
# without killing anything — Windows releases them back to the available pool)
Write-Log "→ Trimming working sets on Claude processes..."
$claudeProcs = Get-Process -Name 'Claude*' -ErrorAction SilentlyContinue
foreach ($proc in $claudeProcs) {
    try {
        $signature = @'
[DllImport("kernel32.dll")]
public static extern bool SetProcessWorkingSetSize(
    IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);
'@
        $type = Add-Type -MemberDefinition $signature -Name WinAPI -Namespace WS -PassThru -ErrorAction SilentlyContinue
        $type::SetProcessWorkingSetSize($proc.Handle, [IntPtr](-1), [IntPtr](-1)) | Out-Null
    } catch { <# best-effort #> }
}
Write-Log "  · Working set trim complete"

# ── 2. CLAUDE DESKTOP CACHE DIRS ─────────────────────────────────────────────
Write-Log "→ Cleaning Claude Desktop renderer cache..."
$cacheDirs = @(
    "$env:AppData\Claude\Cache",
    "$env:LocalAppData\Claude\Cache"
)
$cacheMB = 0
foreach ($dir in $cacheDirs) {
    $cacheMB += Clear-Dir $dir
}
Add-Freed $cacheMB "Claude renderer cache"

# ── 3. SESSION LOGS (>7 days) ─────────────────────────────────────────────────
Write-Log "→ Trimming session logs older than 7 days..."
$sessionDirs = @(
    "$env:AppData\Claude\logs",
    "$env:AppData\Claude\Session Storage",
    "$env:LocalAppData\Claude\logs"
)
$logMB = 0
foreach ($dir in $sessionDirs) {
    $logMB += Remove-OldFiles $dir -OlderThanDays 7
}
Add-Freed $logMB "session logs >7 days"

# ── 4. TEMP FILES ─────────────────────────────────────────────────────────────
Write-Log "→ Cleaning Claude temp files..."
$tempMB = 0
if (Test-Path $env:TEMP) {
    $beforeTemp = Get-DirSizeMB $env:TEMP
    Get-ChildItem -Path $env:TEMP -Filter 'claude-*' -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter 'Claude*' -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $afterTemp = Get-DirSizeMB $env:TEMP
    $tempMB = [math]::Max(0, $beforeTemp - $afterTemp)
}
Add-Freed $tempMB "Claude temp files"

# ── 5. DEEP CLEAN ─────────────────────────────────────────────────────────────
if ($Deep) {
    Write-Log "→ [DEEP] Cleaning GPU shader cache..."
    $gpuMB = 0
    $gpuDirs = @(
        "$env:AppData\Claude\GPUCache",
        "$env:LocalAppData\Claude\GPUCache"
    )
    foreach ($dir in $gpuDirs) {
        $gpuMB += Clear-Dir $dir
    }
    Add-Freed $gpuMB "GPU shader cache"

    Write-Log "→ [DEEP] Cleaning JS Code Cache..."
    $codeCacheMB = 0
    $codeCacheDirs = @(
        "$env:AppData\Claude\Code Cache",
        "$env:LocalAppData\Claude\Code Cache"
    )
    foreach ($dir in $codeCacheDirs) {
        $codeCacheMB += Clear-Dir $dir
    }
    Add-Freed $codeCacheMB "JS Code Cache"

    Write-Log "→ [DEEP] Trimming large Session Storage files (>30 days)..."
    $storageMB = 0
    $storageDirs = @(
        "$env:AppData\Claude\Session Storage",
        "$env:LocalAppData\Claude\Session Storage"
    )
    foreach ($dir in $storageDirs) {
        $storageMB += Remove-OldFiles $dir -OlderThanDays 30
    }
    Add-Freed $storageMB "Session Storage >30 days"

    # Alert if reclaimed a lot (may indicate runaway growth)
    if ($TotalMB -gt 5120) {
        Write-Log "⚠ WARNING: Freed ${TotalMB}MB — this is unusually high. Investigate root cause."
    }
}

# ── SUMMARY ──────────────────────────────────────────────────────────────────
Write-Log ("=== Claude Cleanup DONE — Total freed: ~{0:F0}MB, {1} process(es) reaped ===" -f $TotalMB, $Reaped)
Write-Host "`n✅ Cleanup complete. Freed ~$([math]::Round($TotalMB,0))MB. Log: $LogFile"
