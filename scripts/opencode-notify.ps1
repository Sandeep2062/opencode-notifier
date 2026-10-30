param(
    [string]$Type = "permission",
    [string]$Title = "",
    [string]$Message = ""
)

# Normalize event type
switch ($Type.ToLower()) {
    "permission.asked"            { $Type = "permission" }
    "session.idle"                { $Type = "idle" }
    "session.execution.succeeded" { $Type = "idle" }
    "session.error"               { $Type = "error" }
    "session.execution.failed"    { $Type = "error" }
    "session.step.failed"         { $Type = "error" }
}

# Modern standard Windows notification sound (same as Google Antigravity / Windows 11)
$soundFile = "C:\Windows\Media\Windows Notify System Generic.wav"
if (-not (Test-Path $soundFile)) {
    $soundFile = "C:\Windows\Media\Windows Notify.wav"
}

switch ($Type.ToLower()) {
    "permission" {
        if (-not $Title)   { $Title = "OpenCode - Permission Required" }
        if (-not $Message) { $Message = "OpenCode is waiting for your permission to proceed." }
        $soundFile = "C:\Windows\Media\Windows Notify.wav"
        if (-not (Test-Path $soundFile)) { $soundFile = "C:\Windows\Media\Windows Notify System Generic.wav" }
    }
    "idle" {
        if (-not $Title)   { $Title = "OpenCode - Task Finished" }
        if (-not $Message) { $Message = "OpenCode has completed and is waiting for your input." }
        $soundFile = "C:\Windows\Media\Windows Notify System Generic.wav"
    }
    "error" {
        if (-not $Title)   { $Title = "OpenCode - Error" }
        if (-not $Message) { $Message = "An error occurred in OpenCode." }
        $soundFile = "C:\Windows\Media\Windows Foreground.wav"
    }
    default {
        if (-not $Title)   { $Title = "OpenCode Notification" }
        if (-not $Message) { $Message = "Notification event: $Type" }
        $soundFile = "C:\Windows\Media\Windows Notify System Generic.wav"
    }
}

# 1. Display Windows Toast Notification (clean standard notification, matching Antigravity)
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $xmlTemplate = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <audio silent="true" />
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlTemplate)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

    # Try OpenCode AppId first, fallback to PowerShell AppId
    $shown = $false
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OpenCode").Show($toast)
        $shown = $true
    } catch {
        try {
            $psAppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($psAppId).Show($toast)
            $shown = $true
        } catch {}
    }
} catch {
    # Fallback to system tray balloon notification
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.Visible = $true
        $notify.ShowBalloonTip(3000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {}
}

# 2. Play standard Windows notification sound via SoundPlayer
if ($soundFile -and (Test-Path $soundFile)) {
    try {
        $player = New-Object System.Media.SoundPlayer $soundFile
        $player.PlaySync()
    } catch {
        [System.Media.SystemSounds]::Asterisk.Play()
    }
} else {
    [System.Media.SystemSounds]::Asterisk.Play()
}
