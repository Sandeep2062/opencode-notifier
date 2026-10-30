<#
.SYNOPSIS
    Uninstalls OpenCode Audio & Visual Notification Plugin on Windows.
#>

$ConfigDir = Join-Path $HOME ".config\opencode"
$PluginFile = Join-Path $ConfigDir "plugin\notify.js"
$PsScript1 = Join-Path $ConfigDir "opencode-notify.ps1"
$PsScript2 = Join-Path $HOME "opencode-notify.ps1"
$ShScript = Join-Path $HOME "opencode-notify.sh"
$LogFile = Join-Path $ConfigDir "notify.log"

Write-Host "Uninstalling OpenCode Audio & Visual Notification Plugin..." -ForegroundColor Yellow

$files = @($PluginFile, $PsScript1, $PsScript2, $ShScript, $LogFile)
foreach ($file in $files) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        Write-Host "  -> Removed: $file" -ForegroundColor Gray
    }
}

if (Get-Command opencode -ErrorAction SilentlyContinue) {
    try {
        & opencode service restart | Out-Null
        Write-Host "  -> OpenCode service reloaded." -ForegroundColor Green
    } catch {}
}

Write-Host "Uninstallation completed." -ForegroundColor Green
