#!/usr/bin/env bash
# OpenCode Audio & Visual Notification Plugin Uninstaller

CONFIG_DIR="$HOME/.config/opencode"

echo "Uninstalling OpenCode Audio & Visual Notification Plugin..."

rm -f "$CONFIG_DIR/plugin/notify.js"
rm -f "$CONFIG_DIR/opencode-notify.ps1"
rm -f "$HOME/opencode-notify.ps1"
rm -f "$HOME/opencode-notify.sh"
rm -f "$CONFIG_DIR/notify.log"

if command -v opencode &> /dev/null; then
    opencode service restart &> /dev/null || true
    echo "  -> OpenCode service reloaded."
fi

echo "Uninstallation completed."
