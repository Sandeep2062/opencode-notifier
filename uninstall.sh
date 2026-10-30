#!/usr/bin/env bash
set -e
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
for file in notify.js notification-core.js delivery-claim.js package.json; do rm -f "$CONFIG_DIR/plugins/opencode-notifier/$file"; done
for cue in attention complete error; do rm -f "$CONFIG_DIR/notifier-sounds/$cue.wav"; done
rm -f "$CONFIG_DIR/opencode-notify.ps1" "$CONFIG_DIR/opencode-notify.sh"
for file in "$CONFIG_DIR/plugin/notify.js" "$CONFIG_DIR/plugins/notify.js"; do
    if [[ -f "$file" ]] && grep -q 'audio-visual-notifications' "$file"; then rm -f "$file"; fi
done
echo 'Notifier removed. Logs, backups, custom audio, shortcuts, and unrelated plugins preserved. Use /reload if needed.'
