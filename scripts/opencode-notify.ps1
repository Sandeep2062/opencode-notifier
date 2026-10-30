param(
    [string]$Type = "permission",
    [string]$Title = "",
    [string]$Message = "",
    [switch]$Voice,
    [string]$WavFile = ""
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

$defaultWav = ""
$soundEvent = "Notification.Default"

switch ($Type.ToLower()) {
    "permission" {
        if (-not $Title)   { $Title = "OpenCode - Permission Required" }
        if (-not $Message) { $Message = "OpenCode is waiting for your permission to proceed." }
        $defaultWav = "C:\Windows\Media\notify.wav"
        if (-not (Test-Path $defaultWav)) { $defaultWav = "C:\Windows\Media\Windows Notify.wav" }
        $soundEvent = "Notification.Reminder"
        $voiceText = "OpenCode needs your permission"
    }
    "idle" {
        if (-not $Title)   { $Title = "OpenCode - Task Finished" }
        if (-not $Message) { $Message = "OpenCode has completed and is waiting for your input." }
        $defaultWav = "C:\Windows\Media\chimes.wav"
        if (-not (Test-Path $defaultWav)) { $defaultWav = "C:\Windows\Media\tada.wav" }
        $soundEvent = "Notification.Default"
        $voiceText = "OpenCode task completed"
    }
    "error" {
        if (-not $Title)   { $Title = "OpenCode - Error" }
        if (-not $Message) { $Message = "An error occurred in OpenCode." }
        $defaultWav = "C:\Windows\Media\chord.wav"
        if (-not (Test-Path $defaultWav)) { $defaultWav = "C:\Windows\Media\Windows Foreground.wav" }
        $soundEvent = "Notification.Critical"
        $voiceText = "OpenCode encountered an error"
    }
    default {
        if (-not $Title)   { $Title = "OpenCode Notification" }
        if (-not $Message) { $Message = "Notification event: $Type" }
        $defaultWav = "C:\Windows\Media\chimes.wav"
        $soundEvent = "Notification.Default"
        $voiceText = "OpenCode notification"
    }
}

# 1. Play Audio via SoundPlayer (plays at normal media volume, bypassing muted system sounds)
$audioPlayed = $false
$targetWav = if ($WavFile -and (Test-Path $WavFile)) { $WavFile } else { $defaultWav }

if ($targetWav -and (Test-Path $targetWav)) {
    try {
        $player = New-Object System.Media.SoundPlayer $targetWav
        $player.PlaySync()
        $audioPlayed = $true
    } catch {}
}

# Fallback to system sounds if wav player failed
if (-not $audioPlayed) {
    try {
        switch ($Type.ToLower()) {
            "permission" { [System.Media.SystemSounds]::Exclamation.Play() }
            "error"      { [System.Media.SystemSounds]::Hand.Play() }
            default      { [System.Media.SystemSounds]::Asterisk.Play() }
        }
        Start-Sleep -Milliseconds 600
    } catch {}
}

# Optional Voice (TTS) Announcement
if ($Voice) {
    try {
        Add-Type -AssemblyName System.Speech
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $synth.SpeakAsync($voiceText) | Out-Null
    } catch {}
}

# 2. Display Windows Toast Notification
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
    <audio src="ms-winsoundevent:$soundEvent" />
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
        $notify.ShowBalloonTip(4000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {}
}
