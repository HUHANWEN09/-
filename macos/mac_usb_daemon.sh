#!/bin/bash
# macOS USB 插线即投屏（多机型自适应适配 + 独立电脑模式 + 智能容灾降级 + 手机自动黑屏）后台守护脚本
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORE_DIR="$DIR/core"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export SCRCPY_SERVER_PATH="$CORE_DIR/scrcpy-server"
export SDL_MOUSE_FOCUS_CLICKTHROUGH=1
export SDL_IME_SHOW_UI=1

WAS_CONNECTED=0
while true; do
    if adb get-state 1>/dev/null 2>&1; then
        if ! pgrep -x "scrcpy" >/dev/null 2>&1; then
            if [ $WAS_CONNECTED -eq 0 ]; then
                WAS_CONNECTED=1
                
                # 读取机型信息
                BRAND=$(adb shell getprop ro.product.brand 2>/dev/null | tr -d '\r\n')
                MANU=$(adb shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r\n')
                SDK_STR=$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r\n')
                SDK=$(echo "$SDK_STR" | grep -o '[0-9]*' | head -n 1)
                [ -z "$SDK" ] && SDK=30

                # 通用安卓设置 (关闭授权倒计时、副屏桌面、自由多任务)
                adb shell settings put global adb_allowed_connection_time 0 >/dev/null 2>&1
                adb shell settings put global force_desktop_mode_on_external_displays 1 >/dev/null 2>&1
                adb shell settings put global enable_freeform_support 1 >/dev/null 2>&1

                # 荣耀 / 华为 EMUI / MagicOS
                COMBINED=$(echo "$BRAND $MANU" | tr '[:upper:]' '[:lower:]')
                if echo "$COMBINED" | grep -E -q "honor|huawei"; then
                    adb shell settings put secure selected-proj-mode 1 >/dev/null 2>&1
                fi

                # 推送通用自动黑屏守护
                if [ -f "$CORE_DIR/screen_off_helper.jar" ]; then
                    adb push "$CORE_DIR/screen_off_helper.jar" /data/local/tmp/screen_off_helper.jar >/dev/null 2>&1
                fi
                if [ -f "$CORE_DIR/auto_screen_off.sh" ]; then
                    adb push "$CORE_DIR/auto_screen_off.sh" /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1
                    adb shell "chmod 755 /data/local/tmp/auto_screen_off.sh; (ps -ef 2>/dev/null || ps 2>/dev/null) | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)" >/dev/null 2>&1
                fi

                if [ "$SDK" -ge 29 ]; then
                    # 尝试启动电脑模式
                    scrcpy --new-display=1920x1080/160 --turn-screen-off --no-audio --no-mouse-hover --window-title="PC_Mode" >/dev/null 2>&1 &
                    SCRCPY_PID=$!
                    sleep 2.5
                    # 检查是否因机型 ROM 限制退出
                    if ! kill -0 $SCRCPY_PID >/dev/null 2>&1; then
                        # 触发自动容灾降级，启动 1:1 镜像
                        scrcpy --turn-screen-off --stay-awake --no-audio --window-title="Phone_Mirror" >/dev/null 2>&1 &
                    fi
                else
                    # Android 10 以下无虚拟副屏，直接启动 1:1 超清镜像
                    scrcpy --turn-screen-off --stay-awake --no-audio --window-title="Phone_Mirror" >/dev/null 2>&1 &
                fi
            fi
        else
            WAS_CONNECTED=1
        fi
    else
        WAS_CONNECTED=0
    fi
    sleep 1
done
