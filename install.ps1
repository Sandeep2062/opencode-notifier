<#
.SYNOPSIS
    Installs OpenCode Audio & Visual Notification Plugin on Windows.
.DESCRIPTION
    Automates plugin setup, copies notification scripts, runs a quick self-test,
    and restarts the OpenCode background service.
#>

[CmdletBinding()]
param(
    [switch]$SkipTest
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  OpenCode Audio & Visual Notification Plugin Installer   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigDir = Join-Path $HOME ".config\opencode"
$PluginDir = Join-Path $ConfigDir "plugin"

# 1. Ensure target directories exist
Write-Host "[1/5] Creating configuration directories..." -ForegroundColor Yellow
if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
}
Write-Host "  -> Target: $PluginDir" -ForegroundColor Green

# 2. Copy Plugin file
Write-Host "[2/5] Installing OpenCode plugin..." -ForegroundColor Yellow
$SourcePlugin = Join-Path $ScriptDir "plugin\notify.js"
$DestPlugin = Join-Path $PluginDir "notify.js"
Copy-Item -Path $SourcePlugin -Destination $DestPlugin -Force
Write-Host "  -> Installed notify.js" -ForegroundColor Green

# 3. Copy Notification Scripts
Write-Host "[3/5] Installing notification engines..." -ForegroundColor Yellow
$SourcePs = Join-Path $ScriptDir "scripts\opencode-notify.ps1"
$SourceSh = Join-Path $ScriptDir "scripts\opencode-notify.sh"

Copy-Item -Path $SourcePs -Destination (Join-Path $ConfigDir "opencode-notify.ps1") -Force
Copy-Item -Path $SourcePs -Destination (Join-Path $HOME "opencode-notify.ps1") -Force
Copy-Item -Path $SourceSh -Destination (Join-Path $HOME "opencode-notify.sh") -Force
Write-Host "  -> Installed opencode-notify.ps1 and opencode-notify.sh" -ForegroundColor Green

# 4. Restart OpenCode Service (if available)
Write-Host "[4/5] Checking OpenCode service status..." -ForegroundColor Yellow
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    try {
        & opencode service restart | Out-Null
        Write-Host "  -> OpenCode background service restarted successfully!" -ForegroundColor Green
    } catch {
        Write-Host "  -> Note: OpenCode service could not be restarted automatically. Run 'opencode service restart' manually." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  -> Note: 'opencode' command not found in PATH. Install OpenCode CLI to use." -ForegroundColor DarkYellow
}

# 5. Self-Test
Write-Host "[5/5] Testing notifications..." -ForegroundColor Yellow
if (-not $SkipTest) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ConfigDir "opencode-notify.ps1") -Type "permission" -Title "OpenCode Setup Test" -Message "OpenCode notifications installed successfully!"
    Write-Host "  -> Notification sound and desktop toast sent!" -ForegroundColor Green
} else {
    Write-Host "  -> Test skipped." -ForegroundColor Gray
}

Write-Host "`nInstallation Completed Successfully! 🎉" -ForegroundColor Cyan
Write-Host "Supported Events:" -ForegroundColor White
Write-Host "  1. permission.asked -> Exclamation alert sound + Windows Toast" -ForegroundColor Gray
Write-Host "  2. session.idle     -> Asterisk chime + Windows Toast" -ForegroundColor Gray
Write-Host "  3. session.error    -> Hand warning sound + Windows Toast`n" -ForegroundColor Gray
