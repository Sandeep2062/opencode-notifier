# OpenCode Notifier

Native desktop banners and original soft chimes when **OpenCode needs your answer**, requests permission, finishes work, or encounters an error—even when the terminal is in the background.

Targets **OpenCode V2**, Windows 10/11, macOS, Linux, and WSL/Git Bash. Legacy question/event adapters remain, but full V1 compatibility is not verified. Windows tests and Linux command-stub tests run automatically; actual macOS/Linux desktop delivery requires verification on those platforms.

## What triggers an alert?

| Event | Alert | Sound |
| --- | --- | --- |
| `form.created` (current V2 question/option picker) | Answer required | Soft two-tone attention chime |
| `question.asked` (compatibility input) | Answer required | Attention chime |
| `permission.asked` | Permission required | Attention chime |
| `session.execution.succeeded` / `session.idle` | Task finished | Completion chime |
| `session.execution.failed`, `session.step.failed`, `session.error` | Error | Warning chime |

Answers, cancelled forms, ordinary tool activity, and questions written only in assistant text do not trigger alerts. Repeated event/request deliveries are deduplicated without merging separate question IDs. Question/form summaries and a few option labels appear in the banner.

The included subsecond PCM WAV cues are original, reproducibly generated sounds—not Google's proprietary Antigravity audio. There is no speech synthesis, modal dialog, or notification library dependency.

## Install or upgrade

### Windows

```powershell
git clone https://github.com/Sandeep2062/opencode-notifier.git
cd opencode-notifier
.\install.ps1
```

Use `.\install.ps1 -SkipTest` to skip the real banner/audio test.

### macOS, Linux, WSL, or Git Bash

```bash
git clone https://github.com/Sandeep2062/opencode-notifier.git
cd opencode-notifier
bash install.sh
```

Use `bash install.sh --skip-test` for silent installation.

Installers deploy:

```text
~/.config/opencode/
  plugins/opencode-notifier/
    package.json
    notify.js
    notification-core.js
    delivery-claim.js
  opencode-notify.ps1
  opencode-notify.sh
  notifier-sounds/{attention,complete,error}.wav
  notifier-backups/<timestamp>/
  notifier-cache/  # short-lived cross-instance deduplication claims
```

If `XDG_CONFIG_HOME` is set, its `opencode/` directory is used instead. Existing known notifier files are backed up before replacement. Recognized legacy `plugin/notify.js` copies are removed only after backup to prevent duplicate loading. Unrelated plugins, configuration, and existing shortcuts are preserved. Windows registers a separate `OpenCode Notifier` shortcut when necessary.

**No service restart is performed.** OpenCode reloads watched plugins; use `/reload` if the update has not appeared. Check with `opencode plugin list`.

For npm/Git package loading, the package exports the same plugin and includes its helpers/audio. Keep the plugin on a local interactive machine: a remote/headless OpenCode server cannot present a notification on a different computer.

## Change the sound

Use a local **PCM WAV** (preferably short). The override applies to all alert types:

```powershell
$env:OPENCODE_NOTIFIER_SOUND = 'C:\Sounds\my-chime.wav'
# Set the variable in the environment used to launch the OpenCode service.
```

```bash
export OPENCODE_NOTIFIER_SOUND="$HOME/Sounds/my-chime.wav"
```

An already-running background service does not inherit new terminal environment variables. For an immediate test, pass the sound directly to the helper; no service restart is needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.config\opencode\opencode-notify.ps1" -Type question -SoundPath 'C:\Sounds\my-chime.wav'
```

```bash
bash "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode-notify.sh" question 'Choose an option' 'OpenCode - Answer Required' "$HOME/Sounds/my-chime.wav"
```

Missing or invalid custom audio falls back to bundled audio and then system audio. Windows uses SoundPlayer; macOS uses `afplay`; Linux selects `paplay`, `pw-play`, `aplay`, or `ffplay`. WSL/Git Bash bridges to Windows PowerShell using converted paths.

## Test and diagnose

Real desktop/audio test:

```powershell
npm run test:windows
```

```bash
npm run test:unix
```

Windows silent dry-run (validates XML/normalization and lists candidate sound paths):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/opencode-notify.ps1 -Type form.created -Title 'Choose & confirm' -Message 'Select <one>' -DryRun
```

Automated tests use mocks/dry-runs and do not intentionally send notifications or play audio:

```bash
npm test
npm run sounds:generate
```

Diagnostics record dispatch, missing helper files, spawn/exit failures, toast/fallback results, and audio playback results. They do not log question/answer contents. Logs rotate at about 1 MiB on Windows/the plugin; Unix writes bounded individual lines.

```powershell
Get-Content "$HOME\.config\opencode\notify.log" -Tail 30
```

```bash
tail -n 30 "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/notify.log"
```

### No banner or sound?

1. Check `opencode plugin list` for `audio-visual-notifications`. After an upgrade, use `/reload` if necessary.
2. Trigger a helper self-test. If the helper works but an option picker does not, inspect the log for `Dispatch form.created -> question`.
   On Windows this should be followed by `Helper started`, a toast/fallback result, and an audio result. A process exit of `0` without helper records is not evidence of delivery. Windows launches stay hidden and asynchronous but are not detached, because detached PowerShell can exit before executing its script.
3. On Windows, enable **Settings → System → Notifications**, allow banners for OpenCode Notifier/PowerShell, and check **Do Not Disturb**. The plugin cannot override these settings.
4. Check volume, muted app audio, and the selected output device. A successful playback call does not prove the sound was audible.
5. On Linux, install `notify-send` (`libnotify-bin` on Debian/Ubuntu) separately from an audio player. A desktop session and its D-Bus connection must be available.
6. On macOS, allow terminal/AppleScript notifications. On WSL, Windows interop and `wslpath` must be available; Git Bash uses `cygpath`.

Windows tries a dedicated toast AppID, then PowerShell, then a tray balloon when the APIs fail. Visual delivery and sound are attempted independently. An accepted notification API call does **not** guarantee that Windows displayed a banner.

## Uninstall

```powershell
.\uninstall.ps1
```

```bash
bash uninstall.sh
```

Removes known installed notifier files, preserving logs, backups, custom audio, shortcuts, and unrelated plugins. No service restart; use `/reload` if needed. Legacy scripts installed directly in the home directory are left untouched to avoid deleting potentially customized files.

## License

MIT © [Sandeep Khadka](https://github.com/Sandeep2062). Bundled sounds are original project assets under the same license.
