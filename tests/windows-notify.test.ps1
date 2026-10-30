$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\scripts\opencode-notify.ps1"

[xml]$xml = Get-ToastXml 'A & B' 'Choose <one> "option"'
if ($xml.toast.visual.binding.text[0] -ne 'A & B') { throw 'Title escaped incorrectly' }
if ($xml.toast.visual.binding.text[1] -ne 'Choose <one> "option"') { throw 'Message escaped incorrectly' }
[xml]$clean = Get-ToastXml 'Unicode: café' ("Control" + [char]1 + 'text')
if ($clean.toast.visual.binding.text[1] -ne 'Controltext') { throw 'Invalid control character was not removed' }

$script:attempts = [Collections.Generic.List[string]]::new()
$result = Invoke-VisualNotification '<toast/>' { param($id, $xml) $script:attempts.Add($id); throw 'Mock failure' } { $script:attempts.Add('balloon') } { param($line) }
if ($script:attempts.Count -ne 3 -or -not $result) { throw 'Balloon fallback not reached' }
$script:attempts.Clear()
$result = Invoke-VisualNotification '<toast/>' { param($id, $xml) $script:attempts.Add($id) } { throw 'Unexpected balloon' } { param($line) }
if ($script:attempts.Count -ne 1 -or -not $result) { throw 'Successful toast should not duplicate' }

$dry = & "$PSScriptRoot\..\scripts\opencode-notify.ps1" -Type form.created -Title 'Choose & confirm' -Message '<one>' -DryRun | ConvertFrom-Json
if ($dry.type -ne 'question' -or $dry.sounds.Count -lt 1) { throw 'Question dry-run normalization failed' }
Write-Output 'Windows XML, fallback, and dry-run tests passed (no notifications emitted).'
