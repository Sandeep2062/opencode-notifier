# 🔔 OpenCode Notifier

> **Cross-Platform Audio & Visual Notification Plugin for [OpenCode CLI](https://opencode.ai)**  
> Get alerted acoustically and visually when OpenCode asks for permission, finishes a task, or encounters an error — even when your terminal is running in the background.

Compatible with **Windows 10/11**, **macOS**, **Linux**, and **WSL2**. Supports both **OpenCode v2** and **OpenCode v1**.

---

## ⚡ Features

- 🔊 **Distinct Audio Cues:**
  - ✋ **Permission Needed (`permission.asked`)**: High-priority alert chime (`Exclamation` / `Ping` / `message.oga`).
  - ✅ **Task Finished (`session.idle`)**: Pleasant completion sound (`Asterisk` / `Glass` / `complete.oga`).
  - ❌ **Execution Error (`session.error`)**: Critical warning sound (`Hand` / `Basso` / `dialog-warning.oga`).
- 🪟 **Native Desktop Notifications:**
  - **Windows**: Interactive Windows Toast Notifications via `Windows.UI.Notifications` (falls back to System Tray balloon).
  - **macOS**: Native Notification Center banners via AppleScript (`display notification`).
  - **Linux**: Desktop notifications via `notify-send`.
- 🚀 **Non-Blocking & Silent Execution**: Dispatches notification processes asynchronously and detached with hidden windows (`windowsHide: true`), preventing any terminal lag or flickering console popups.
- 🔄 **Unified v1 & v2 Engine**: Works seamlessly across OpenCode versions (`setup(ctx)` lifecycle with `ctx.event.subscribe()` for v2+, and `server()` / `NotificationPlugin` exports for v1).

---

## 📦 Automated 1-Click Installation

Clone the repository and run the setup script for your platform:

### Windows (PowerShell)
Open PowerShell (no admin rights required) and run:
```powershell
git clone https://github.com/Sandeep2062/opencode-notifier.git
cd opencode-notifier
.\install.ps1
```

### macOS & Linux (Bash)
Open terminal and run:
```bash
git clone https://github.com/Sandeep2062/opencode-notifier.git
cd opencode-notifier
chmod +x install.sh
./install.sh
```

The installer will:
1. Create `~/.config/opencode/plugin/` if it doesn't exist.
2. Install `notify.js` into your global plugins directory.
3. Install the background notification engines (`opencode-notify.ps1` / `opencode-notify.sh`).
4. Automatically reload the OpenCode service (`opencode service restart`).
5. Trigger a quick self-test sound and notification banner.

---

## 🛠️ Manual Installation

If you prefer to configure the files manually:

### Step 1: Create Plugin Directory
```bash
# Windows (PowerShell)
New-Item -ItemType Directory -Path "$HOME\.config\opencode\plugin" -Force

# macOS / Linux
mkdir -p ~/.config/opencode/plugin
```

### Step 2: Install Notification Script

#### For Windows:
Place [`scripts/opencode-notify.ps1`](scripts/opencode-notify.ps1) at:
`C:\Users\<YourUser>\.config\opencode\opencode-notify.ps1` (and `C:\Users\<YourUser>\opencode-notify.ps1`).

Test it in PowerShell:
```powershell
powershell.exe -File "$HOME\.config\opencode\opencode-notify.ps1" -Type permission
```

#### For macOS / Linux:
Place [`scripts/opencode-notify.sh`](scripts/opencode-notify.sh) at:
`~/opencode-notify.sh` and make it executable:
```bash
chmod +x ~/opencode-notify.sh
~/opencode-notify.sh permission
```

### Step 3: Install the Plugin
Copy [`plugin/notify.js`](plugin/notify.js) into your global config directory:
```
~/.config/opencode/plugin/notify.js
```

### Step 4: Restart OpenCode
Restart OpenCode or reload the background service:
```bash
opencode service restart
```

---

## 🔍 How It Works

OpenCode emits lifecycle and permission events over its internal event bus:

```
[OpenCode Event Bus]
       │
       ├──> event: permission.asked ──> [notify.js] ──> Sound: Exclamation + Toast: "Permission Required"
       ├──> event: session.idle     ──> [notify.js] ──> Sound: Asterisk    + Toast: "Task Completed"
       └──> event: session.error    ──> [notify.js] ──> Sound: Hand        + Toast: "Execution Error"
```

1. **`permission.asked`**: Fires when an action (e.g. bash execution, external file edits, or network calls) is configured to require manual approval in `opencode.json`.
2. **`session.idle`**: Fires when an agent completes reasoning/tool-execution loops and enters an idle state waiting for new input.
3. **`session.error`**: Fires when unhandled model errors, provider rate limits, or tool exceptions occur.

---

## 🎛️ Customization

### Changing Sounds on Windows
In `opencode-notify.ps1`, you can replace the system sounds:
```powershell
# Built-in System Sounds
[System.Media.SystemSounds]::Exclamation.Play()
[System.Media.SystemSounds]::Asterisk.Play()
[System.Media.SystemSounds]::Hand.Play()
[System.Media.SystemSounds]::Beep.Play()

# Custom WAV file
[System.Media.SoundPlayer]::new("C:\Windows\Media\chimes.wav").Play()
```

### Adding Speech Synthesis (Voice)
To have Windows speak out loud when attention is needed, add to `opencode-notify.ps1`:
```powershell
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SpeakAsync("OpenCode needs your attention")
```

On macOS, add to `opencode-notify.sh`:
```bash
say -v "Zarvox" "OpenCode needs your permission"
```

### Modal Message Box (Popup Dialog)
If you want an unavoidable pop-up window that halts until clicked:
```powershell
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("OpenCode needs your permission", "OpenCode Alert")
```

---

## 🔧 Troubleshooting

### Verify Plugin Loaded
Run:
```bash
opencode plugin list
```
You should see:
```text
ID  VERSION  SOURCE
-   local    ~/.config/opencode/plugin/notify.js
```

### Check Activity Logs
The plugin records all received lifecycle events and notifications:
```bash
# Windows (PowerShell)
Get-Content "$HOME\.config\opencode\notify.log" -Tail 20

# macOS / Linux
tail -n 20 ~/.config/opencode/notify.log
```

### Service Not Picking Up Changes?
If you edit `notify.js`, restart the background server:
```bash
opencode service restart
```

---

## 🗑️ Uninstallation

Run the uninstaller script:
```powershell
# Windows
.\uninstall.ps1

# macOS / Linux
./uninstall.sh
```

---

## 📄 License
MIT © [Sandeep Khadka](https://github.com/Sandeep2062)
