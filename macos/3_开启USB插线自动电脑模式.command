#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DAEMON_SH="$DIR/mac_usb_daemon.sh"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/com.honor.autodesktop.plist"

chmod +x "$DAEMON_SH" "$DIR/../bin/honor-cast"
mkdir -p "$PLIST_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.honor.autodesktop</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DAEMON_SH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/honor_autodesktop.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/honor_autodesktop.err</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load -w "$PLIST_PATH"
echo "✅ 已开启 macOS USB 插线自动启动电脑模式守护服务 (LaunchAgent)！"
echo "   现在只要将手机通过 USB 插入 Mac，就会像 Windows 一样自动弹出电脑模式且手机自动黑屏！"
