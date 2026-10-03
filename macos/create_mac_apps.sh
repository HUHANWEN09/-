#!/bin/bash
# 在 macOS 桌面与 ~/Applications 生成可直接点击的原生 .app 图标
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HONOR_CAST="$DIR/../bin/honor-cast"

create_app_bundle() {
    local APP_NAME="$1"
    local SUBCMD="$2"
    local TARGET_DIR="$3"
    local APP_PATH="$TARGET_DIR/${APP_NAME}.app"
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"

    cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.honor.cast.${SUBCMD}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

    cat > "$APP_PATH/Contents/MacOS/launcher" <<EOF
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH"
exec "$HONOR_CAST" $SUBCMD
EOF
    chmod +x "$APP_PATH/Contents/MacOS/launcher"
}

for DEST in "$HOME/Desktop" "$HOME/Applications"; do
    mkdir -p "$DEST"
    create_app_bundle "荣耀电脑模式" "desktop" "$DEST"
    create_app_bundle "荣耀手机投屏" "mirror" "$DEST"
done
echo "✅ 已在 Mac 桌面 (Desktop) 与应用程序 (~/Applications) 创建【荣耀电脑模式.app】与【荣耀手机投屏.app】图标！"
