param(
    [string]$Type = "permission",
    [string]$Title = "",
    [string]$Message = ""
)

# Normalize event type
switch ($Type.ToLower()) {
    "permission.asked" { $Type = "permission" }
    "session.idle"     { $Type = "idle" }
    "session.error"    { $Type = "error" }
}

# Select appropriate sound and default messages
switch ($Type.ToLower()) {
    "permission" {
        if (-not $Title)   { $Title = "OpenCode - Permission Required" }
        if (-not $Message) { $Message = "OpenCode is waiting for your permission to proceed." }
        [System.Media.SystemSounds]::Exclamation.Play()
    }
    "idle" {
        if (-not $Title)   { $Title = "OpenCode - Task Finished" }
        if (-not $Message) { $Message = "OpenCode has completed and is waiting for your input." }
        [System.Media.SystemSounds]::Asterisk.Play()
    }
    "error" {
        if (-not $Title)   { $Title = "OpenCode - Error" }
        if (-not $Message) { $Message = "An error occurred in OpenCode." }
        [System.Media.SystemSounds]::Hand.Play()
    }
    default {
        if (-not $Title)   { $Title = "OpenCode Notification" }
        if (-not $Message) { $Message = "Notification event: $Type" }
        [System.Media.SystemSounds]::Asterisk.Play()
    }
}

# Display Windows Toast Notification
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $textNodes = $template.GetElementsByTagName("text")
    $textNodes.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
    $textNodes.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OpenCode").Show($toast)
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
