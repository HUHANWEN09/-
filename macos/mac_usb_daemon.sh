#!/bin/bash
# macOS USB 插线即投屏（电脑模式 + 手机自动黑屏）后台守护核心脚本
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORE_DIR="$DIR/core"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export SCRCPY_SERVER_PATH="$CORE_DIR/scrcpy-server"
export SDL_MOUSE_FOCUS_CLICKTHROUGH=1
export SDL_IME_SHOW_UI=1

WAS_CONNECTED=0
while true; do
    if adb get-state 1>/dev/null 2>&1; then
        # 检查是否已有 scrcpy 电脑模式窗口在运行
        if ! pgrep -x "scrcpy" >/dev/null 2>&1; then
            if [ $WAS_CONNECTED -eq 0 ]; then
                WAS_CONNECTED=1
                adb shell settings put global adb_allowed_connection_time 0 >/dev/null 2>&1
                adb shell settings put secure selected-proj-mode 1 >/dev/null 2>&1
                if [ -f "$CORE_DIR/screen_off_helper.jar" ]; then
                    adb push "$CORE_DIR/screen_off_helper.jar" /data/local/tmp/screen_off_helper.jar >/dev/null 2>&1
                fi
                if [ -f "$CORE_DIR/auto_screen_off.sh" ]; then
                    adb push "$CORE_DIR/auto_screen_off.sh" /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1
                    adb shell "chmod 755 /data/local/tmp/auto_screen_off.sh; ps -ef | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)" >/dev/null 2>&1
                fi
                scrcpy --new-display=1920x1080/160 --turn-screen-off --no-audio --no-mouse-hover --window-title="Honor_PC_Mode" >/dev/null 2>&1 &
            fi
        else
            WAS_CONNECTED=1
        fi
    else
        WAS_CONNECTED=0
    fi
    sleep 1
done
