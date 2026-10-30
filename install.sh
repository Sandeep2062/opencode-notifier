#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
PLUGIN_DIR="$CONFIG_DIR/plugins/opencode-notifier"
BACKUP_DIR="$CONFIG_DIR/notifier-backups/$(date -u +%Y%m%d-%H%M%S)-$$"
known=(plugins/opencode-notifier/notify.js plugins/opencode-notifier/notification-core.js plugins/opencode-notifier/delivery-claim.js plugins/opencode-notifier/package.json opencode-notify.ps1 opencode-notify.sh notifier-sounds/attention.wav notifier-sounds/complete.wav notifier-sounds/error.wav)
legacy=(plugin/notify.js plugins/notify.js)
for relative in "${known[@]}" "${legacy[@]}"; do
    file="$CONFIG_DIR/$relative"
    [[ -f "$file" ]] || continue
    if [[ "$relative" == plugin/notify.js || "$relative" == plugins/notify.js ]]; then
        grep -q 'audio-visual-notifications' "$file" || { echo "Preserving unrecognized plugin: $file"; continue; }
    fi
    mkdir -p "$(dirname "$BACKUP_DIR/$relative")"
    cp "$file" "$BACKUP_DIR/$relative"
done
mkdir -p "$PLUGIN_DIR" "$CONFIG_DIR/notifier-sounds"
cp "$SCRIPT_DIR/scripts/opencode-notify.ps1" "$CONFIG_DIR/opencode-notify.ps1"
cp "$SCRIPT_DIR/scripts/opencode-notify.sh" "$CONFIG_DIR/opencode-notify.sh"
chmod +x "$CONFIG_DIR/opencode-notify.sh"
for cue in attention complete error; do cp "$SCRIPT_DIR/sounds/$cue.wav" "$CONFIG_DIR/notifier-sounds/$cue.wav"; done
for file in notification-core.js delivery-claim.js package.json notify.js; do cp "$SCRIPT_DIR/plugin/$file" "$PLUGIN_DIR/$file"; done
for relative in "${legacy[@]}"; do
    [[ -f "$BACKUP_DIR/$relative" ]] && rm -f "$CONFIG_DIR/$relative"
done
echo "Installed: $PLUGIN_DIR"
[[ -d "$BACKUP_DIR" ]] && echo "Backup: $BACKUP_DIR"
echo 'No service restart. OpenCode reloads watched plugins; use /reload if needed.'
if [[ "${1:-}" != --skip-test ]]; then
    echo 'Sending one banner/chime test; verify it is visible and audible.'
    bash "$CONFIG_DIR/opencode-notify.sh" question 'Answer-required notifications are ready.' 'OpenCode Setup Test' || echo 'Test failed; check notify.log and platform prerequisites.'
fi
