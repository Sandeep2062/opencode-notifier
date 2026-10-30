#!/usr/bin/env bash
# Short-lived native notification helper. Text is always passed as data.
TYPE="${1:-permission}"
MESSAGE="${2:-}"
TITLE="${3:-}"
CUSTOM_SOUND="${4:-${OPENCODE_NOTIFIER_SOUND:-}}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR='.'

log() {
    command -v mkdir >/dev/null 2>&1 && mkdir -p "$CONFIG_DIR" 2>/dev/null
    local line="${1//$'\n'/ }"
    printf '[Unix] %s\n' "${line:0:1000}" >> "$CONFIG_DIR/notify.log" 2>/dev/null || true
}
case "$TYPE" in
    question|form.created|question.asked) TYPE=question; DEFAULT_TITLE='OpenCode - Answer Required'; DEFAULT_MESSAGE='OpenCode needs your response. Answer the question or choose an option.'; CUE=attention ;;
    permission|permission.asked) TYPE=permission; DEFAULT_TITLE='OpenCode - Permission Required'; DEFAULT_MESSAGE='OpenCode is waiting for your permission.'; CUE=attention ;;
    error|session.error|session.execution.failed|session.step.failed) TYPE=error; DEFAULT_TITLE='OpenCode - Error'; DEFAULT_MESSAGE='An error occurred in OpenCode.'; CUE=error ;;
    *) TYPE=idle; DEFAULT_TITLE='OpenCode - Task Finished'; DEFAULT_MESSAGE='OpenCode completed the task.'; CUE=complete ;;
esac
TITLE="${TITLE:-$DEFAULT_TITLE}"
MESSAGE="${MESSAGE:-$DEFAULT_MESSAGE}"
TITLE="${TITLE:0:120}"; MESSAGE="${MESSAGE:0:300}"

# WSL/Git Bash use Windows banners/audio. Convert Linux paths before -File.
if command -v powershell.exe >/dev/null 2>&1; then
    HELPER="$CONFIG_DIR/opencode-notify.ps1"
    if [[ -f "$HELPER" ]]; then
        if command -v wslpath >/dev/null 2>&1; then HELPER="$(wslpath -w "$HELPER")"
        elif command -v cygpath >/dev/null 2>&1; then HELPER="$(cygpath -w "$HELPER")"
        else log 'Cannot convert PowerShell helper path; install wslpath or cygpath'; exit 1; fi
    else
        HELPER="$(powershell.exe -NoProfile -Command 'Join-Path (Join-Path $HOME ".config\opencode") "opencode-notify.ps1"' 2>/dev/null)"
        HELPER="${HELPER//$'\r'/}"; HELPER="${HELPER//$'\n'/}"
    fi
    args=(-NoProfile -ExecutionPolicy Bypass -File "$HELPER" -Type "$TYPE" -Title "$TITLE" -Message "$MESSAGE")
    if [[ -n "$CUSTOM_SOUND" ]]; then
        if [[ -f "$CUSTOM_SOUND" ]]; then
            if command -v wslpath >/dev/null 2>&1; then CUSTOM_SOUND="$(wslpath -w "$CUSTOM_SOUND")"
            elif command -v cygpath >/dev/null 2>&1; then CUSTOM_SOUND="$(cygpath -w "$CUSTOM_SOUND")"; fi
        fi
        args+=(-SoundPath "$CUSTOM_SOUND")
    fi
    powershell.exe "${args[@]}" 2>/dev/null
    status=$?; log "Windows bridge exit=$status"; exit "$status"
fi

visual=1
if command -v osascript >/dev/null 2>&1; then
    osascript - "$TITLE" "$MESSAGE" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
    visual=$?
elif command -v notify-send >/dev/null 2>&1; then
    urgency=normal; [[ "$TYPE" == error ]] && urgency=critical
    notify-send --app-name=OpenCode --urgency="$urgency" -- "$TITLE" "$MESSAGE" >/dev/null 2>&1
    visual=$?
else log 'No desktop notification tool available (install notify-send on Linux)'; fi
log "Desktop notification API exit=$visual (visibility depends on OS settings)"

audio=1
player=''
for candidate in afplay paplay pw-play aplay ffplay; do
    if command -v "$candidate" >/dev/null 2>&1; then player="$candidate"; break; fi
done
if [[ -n "$player" ]]; then
    for sound in "$CUSTOM_SOUND" "$SCRIPT_DIR/../sounds/$CUE.wav" "$CONFIG_DIR/notifier-sounds/$CUE.wav" /System/Library/Sounds/Glass.aiff /usr/share/sounds/freedesktop/stereo/complete.oga; do
        [[ -n "$sound" && -f "$sound" ]] || continue
        [[ "$player" == aplay && "$sound" != *.wav ]] && continue
        if [[ "$player" == ffplay ]]; then "$player" -nodisp -autoexit -loglevel quiet "$sound" >/dev/null 2>&1
        else "$player" "$sound" >/dev/null 2>&1; fi
        audio=$?; [[ "$audio" == 0 ]] && break
    done
else log 'No audio player available (install paplay, pw-play, or aplay)'; fi
log "Audio playback exit=$audio (audibility depends on volume/output)"
[[ "$visual" == 0 || "$audio" == 0 ]]
