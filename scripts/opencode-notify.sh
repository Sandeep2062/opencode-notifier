#!/usr/bin/env bash
# OpenCode Notification Script (macOS / Linux / WSL / Windows Git Bash)
TYPE="${1:-permission}"
MESSAGE="${2:-}"
TITLE="${3:-}"

# Windows (native, Git Bash, or WSL)
if command -v powershell.exe &> /dev/null; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME/.config/opencode/opencode-notify.ps1" -Type "$TYPE" -Message "$MESSAGE" -Title "$TITLE" 2>/dev/null
# macOS
elif command -v afplay &> /dev/null; then
    case "$TYPE" in
        "permission"|"permission.asked")
            afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
            osascript -e "display notification \"${MESSAGE:-OpenCode needs permission}\" with title \"${TITLE:-OpenCode - Permission Required}\"" 2>/dev/null &
            ;;
        "idle"|"session.idle")
            afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
            osascript -e "display notification \"${MESSAGE:-Task completed}\" with title \"${TITLE:-OpenCode - Finished}\"" 2>/dev/null &
            ;;
        "error"|"session.error")
            afplay /System/Library/Sounds/Basso.aiff 2>/dev/null &
            osascript -e "display notification \"${MESSAGE:-An error occurred}\" with title \"${TITLE:-OpenCode - Error}\"" 2>/dev/null &
            ;;
        *)
            afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
            ;;
    esac
# Linux (ALSA / notify-send)
elif command -v aplay &> /dev/null; then
    case "$TYPE" in
        "permission"|"permission.asked")
            aplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
            ;;
        "error"|"session.error")
            aplay /usr/share/sounds/freedesktop/stereo/dialog-warning.oga 2>/dev/null &
            ;;
        *)
            aplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
            ;;
    esac
    if command -v notify-send &> /dev/null; then
        notify-send "${TITLE:-OpenCode}" "${MESSAGE:-Notification}" 2>/dev/null &
    fi
fi
