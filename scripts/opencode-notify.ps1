param(
    [string]$Type = 'permission',
    [string]$Title = '',
    [string]$Message = '',
    [string]$SoundPath = $env:OPENCODE_NOTIFIER_SOUND,
    [string]$LogPath = '',
    [switch]$DryRun
)

function Get-ToastXml([string]$ToastTitle, [string]$ToastMessage) {
    $safeTitle = [Security.SecurityElement]::Escape(($ToastTitle -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''))
    $safeMessage = [Security.SecurityElement]::Escape(($ToastMessage -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''))
    return "<toast><visual><binding template=`"ToastGeneric`"><text>$safeTitle</text><text>$safeMessage</text></binding></visual><audio silent=`"true`" /></toast>"
}

function Write-NotifyLog([string]$Line) {
    try {
        $directory = Split-Path -Parent $script:LogPath
        if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
        if ((Test-Path -LiteralPath $script:LogPath) -and (Get-Item -LiteralPath $script:LogPath).Length -gt 1MB) {
            Move-Item -LiteralPath $script:LogPath -Destination "$script:LogPath.previous" -Force
        }
        $line = $Line -replace '[\r\n]', ' '
        if ($line.Length -gt 1000) { $line = $line.Substring(0, 1000) }
        Add-Content -LiteralPath $script:LogPath -Value "[$([DateTime]::UtcNow.ToString('o'))] Windows: $line" -Encoding UTF8
    } catch { }
}

function Invoke-VisualNotification([string]$Xml, [scriptblock]$ToastAction, [scriptblock]$BalloonAction, [scriptblock]$LogAction) {
    foreach ($appId in @('OpenCode.Notifier', '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe')) {
        try { & $ToastAction $appId $Xml; & $LogAction "Toast API accepted app=$appId (visibility depends on Windows settings)"; return $true }
        catch { & $LogAction "Toast failed app=$appId : $($_.Exception.Message)" }
    }
    try { & $BalloonAction; & $LogAction 'Balloon fallback attempted'; return $true }
    catch { & $LogAction "Balloon fallback failed: $($_.Exception.Message)"; return $false }
}

# Dot-sourcing is for silent function tests, never for dispatch.
if ($MyInvocation.InvocationName -eq '.') { return }
$ErrorActionPreference = 'Stop'
$configRoot = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
$configDir = Join-Path $configRoot 'opencode'
if (-not $LogPath) { $LogPath = Join-Path $configDir 'notify.log' }
$script:LogPath = $LogPath

switch ($Type.ToLowerInvariant()) {
    { $_ -in @('question', 'form.created', 'question.asked') } { $Type = 'question' }
    'permission.asked' { $Type = 'permission' }
    { $_ -in @('session.idle', 'session.execution.succeeded') } { $Type = 'idle' }
    { $_ -in @('session.error', 'session.execution.failed', 'session.step.failed') } { $Type = 'error' }
}
$defaults = @{
    question = @('OpenCode - Answer Required', 'OpenCode needs your response. Answer the question or choose an option.', 'attention.wav')
    permission = @('OpenCode - Permission Required', 'OpenCode is waiting for your permission.', 'attention.wav')
    idle = @('OpenCode - Task Finished', 'OpenCode completed the task and is waiting for your input.', 'complete.wav')
    error = @('OpenCode - Error', 'An error occurred in OpenCode.', 'error.wav')
}
$settings = $defaults[$Type]
if (-not $settings) { $settings = @('OpenCode', 'OpenCode needs your attention.', 'attention.wav') }
if (-not $Title) { $Title = $settings[0] }
if (-not $Message) { $Message = $settings[1] }
if ($Title.Length -gt 120) { $Title = $Title.Substring(0, 120) }
if ($Message.Length -gt 300) { $Message = $Message.Substring(0, 300) }
$xmlTemplate = Get-ToastXml $Title $Message
$media = Join-Path $env:WINDIR 'Media'
$soundCandidates = @()
if ($SoundPath) { $soundCandidates += $SoundPath }
$soundCandidates += @((Join-Path (Split-Path -Parent $PSScriptRoot) "sounds\$($settings[2])"), (Join-Path $configDir "notifier-sounds\$($settings[2])"), (Join-Path $media 'Windows Notify System Generic.wav'), (Join-Path $media 'Windows Notify.wav'))
if ($DryRun) {
    # Native PowerShell otherwise encodes redirected output in the OEM code page.
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    @{ type = $Type; xml = $xmlTemplate; sounds = @($soundCandidates); log = $LogPath } | ConvertTo-Json -Depth 4
    return
}
Write-NotifyLog "Helper started type=$Type pid=$PID"

$visual = Invoke-VisualNotification $xmlTemplate {
    param($appId, $xmlText)
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
    $setting = $notifier.Setting
    # Some PowerShell/WinRT projections do not expose Setting. Still try Show.
    if ($null -ne $setting -and $setting.ToString() -ne 'Enabled') { throw "Notifications blocked: $setting. Check Settings > System > Notifications." }
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlText)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $notifier.Show($toast)
} {
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    try {
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        # Keep the short-lived process and tray icon alive while the balloon is shown.
        $until = [DateTime]::UtcNow.AddSeconds(5)
        while ([DateTime]::UtcNow -lt $until) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
    } finally { $notify.Visible = $false; $notify.Dispose() }
} { param($line) Write-NotifyLog $line }

$audio = $false
foreach ($candidate in ($soundCandidates | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        if ($candidate -eq $SoundPath) { Write-NotifyLog 'Custom sound missing; using fallback' }
        continue
    }
    $player = $null
    try {
        $player = New-Object System.Media.SoundPlayer $candidate
        $player.Load(); $player.PlaySync()
        $audio = $true
        Write-NotifyLog "Audio playback completed: $([IO.Path]::GetFileName($candidate)) (audibility depends on volume/output)"
        break
    } catch { Write-NotifyLog "Audio failed: $($_.Exception.Message)" }
    finally { if ($player) { $player.Dispose() } }
}
if (-not $audio) {
    try { [System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 700; $audio = $true; Write-NotifyLog 'System sound fallback attempted' }
    catch { Write-NotifyLog "System sound failed: $($_.Exception.Message)" }
}
if (-not $visual -and -not $audio) { exit 1 }
