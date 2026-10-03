#!/bin/bash
PLIST_PATH="$HOME/Library/LaunchAgents/com.honor.autodesktop.plist"
if [ -f "$PLIST_PATH" ]; then
    launchctl unload -w "$PLIST_PATH" 2>/dev/null
    rm -f "$PLIST_PATH"
fi
pkill -f "mac_usb_daemon.sh" 2>/dev/null
echo "🛑 已关闭 macOS USB 插线自动电脑模式守护服务。"
