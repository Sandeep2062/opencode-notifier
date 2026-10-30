#!/usr/bin/env bash
# OpenCode Audio & Visual Notification Plugin Installer (Linux / macOS / WSL)
set -e

echo "=========================================================="
echo "  OpenCode Audio & Visual Notification Plugin Installer   "
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/opencode"
PLUGIN_DIR="$CONFIG_DIR/plugin"

# 1. Create directories
echo "[1/5] Creating configuration directories..."
mkdir -p "$PLUGIN_DIR"
echo "  -> Target: $PLUGIN_DIR"

# 2. Copy Plugin file
echo "[2/5] Installing OpenCode plugin..."
cp "$SCRIPT_DIR/plugin/notify.js" "$PLUGIN_DIR/notify.js"
echo "  -> Installed notify.js"

# 3. Copy Notification Scripts
echo "[3/5] Installing notification engines..."
cp "$SCRIPT_DIR/scripts/opencode-notify.sh" "$HOME/opencode-notify.sh"
chmod +x "$HOME/opencode-notify.sh"

# Also install PowerShell engine if running on WSL / Windows
mkdir -p "$CONFIG_DIR"
cp "$SCRIPT_DIR/scripts/opencode-notify.ps1" "$CONFIG_DIR/opencode-notify.ps1"
echo "  -> Installed opencode-notify.sh and opencode-notify.ps1"

# 4. Restart OpenCode Service (if available)
echo "[4/5] Checking OpenCode service status..."
if command -v opencode &> /dev/null; then
    if opencode service restart &> /dev/null; then
        echo "  -> OpenCode background service restarted successfully!"
    else
        echo "  -> Note: Run 'opencode service restart' manually if needed."
    fi
else
    echo "  -> Note: 'opencode' command not found in PATH."
fi

# 5. Self-Test
echo "[5/5] Testing notifications..."
if [ "${1:-}" != "--skip-test" ]; then
    "$HOME/opencode-notify.sh" "permission" "OpenCode notifications installed successfully!" "OpenCode Setup Test"
    echo "  -> Notification triggered!"
else
    echo "  -> Test skipped."
fi

echo ""
echo "Installation Completed Successfully! 🎉"
echo "Supported Events:"
echo "  1. permission.asked -> Attention chime + desktop notification"
echo "  2. session.idle     -> Completion chime + desktop notification"
echo "  3. session.error    -> Warning sound + desktop notification"
echo ""
