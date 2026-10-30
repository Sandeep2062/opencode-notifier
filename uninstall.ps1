param([string]$ConfigDir = '')
$ErrorActionPreference = 'Stop'
if (-not $ConfigDir) {
    $root = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    $ConfigDir = Join-Path $root 'opencode'
}
$package = Join-Path $ConfigDir 'plugins\opencode-notifier'
foreach ($name in @('notify.js', 'notification-core.js', 'delivery-claim.js', 'package.json')) {
    $file = Join-Path $package $name
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
}
foreach ($relative in @('opencode-notify.ps1', 'opencode-notify.sh', 'notifier-sounds\attention.wav', 'notifier-sounds\complete.wav', 'notifier-sounds\error.wav')) {
    $file = Join-Path $ConfigDir $relative
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
}
foreach ($relative in @('plugin\notify.js', 'plugins\notify.js')) {
    $file = Join-Path $ConfigDir $relative
    if ((Test-Path -LiteralPath $file) -and ((Get-Content -LiteralPath $file -Raw) -match 'audio-visual-notifications')) { Remove-Item -LiteralPath $file -Force }
}
Write-Host 'Notifier removed. Logs, backups, custom audio, shortcuts, and unrelated plugins preserved. Use /reload if needed; service was not restarted.' -ForegroundColor Green
