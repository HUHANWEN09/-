#!/system/bin/sh
# Universal Auto Screen-Off & 10s Idle Re-Black-Screen Daemon for All Android Brands
# Supports: Huawei, Honor, Xiaomi, Redmi, OPPO, vivo, OnePlus, Realme, Samsung, Meizu, Pixel, etc.

is_scrcpy_running() {
    (ps -ef 2>/dev/null || ps 2>/dev/null) | grep -v grep | grep -q "com.genymobile.scrcpy.Server"
}

get_scrcpy_pid() {
    (ps -ef 2>/dev/null || ps 2>/dev/null) | grep "com.genymobile.scrcpy.Server" | grep -v grep | awk '{print $2}' | head -n 1
}

is_screen_on() {
    # Method 1: dumpsys power
    if dumpsys power 2>/dev/null | grep -E -q "mWakefulness=Awake|Display Power: state=ON"; then
        return 0
    fi
    # Method 2: dumpsys display
    if dumpsys display 2>/dev/null | grep -E -q "mState=ON|state=ON"; then
        return 0
    fi
    # Method 3: dumpsys window policy
    if dumpsys window policy 2>/dev/null | grep -q "screenState=SCREEN_STATE_ON"; then
        return 0
    fi
    # Method 4: dumpsys SurfaceFlinger (Honor/Huawei specific)
    if dumpsys SurfaceFlinger 2>/dev/null | grep -q "isEnabled=true isSecure=true"; then
        return 0
    fi
    return 1
}

turn_off_screen() {
    if [ -f /data/local/tmp/screen_off_helper.jar ]; then
        CLASSPATH=/data/local/tmp/screen_off_helper.jar app_process / com.genymobile.scrcpy.CleanUp >/dev/null 2>&1
    fi
    # Universal fallback for standard Android
    input keyevent 223 >/dev/null 2>&1
}

LAST_PID=""

while true; do
    if is_scrcpy_running; then
        PID=$(get_scrcpy_pid)
        if [ -n "$PID" ] && [ "$PID" != "$LAST_PID" ]; then
            LAST_PID="$PID"
            sleep 1
            turn_off_screen
        fi

        if is_screen_on; then
            # Phone screen was turned on (e.g. user pressed physical power button)
            # Wait for 10 seconds of touch idle
            while is_screen_on; do
                if timeout 10 getevent -c 1 >/dev/null 2>&1; then
                    # Physical touch detected, user is actively touching the phone screen
                    sleep 1
                else
                    # 10s idle without physical touch! Re-black screen automatically
                    if is_scrcpy_running; then
                        turn_off_screen
                    fi
                    break
                fi
            done
        else
            # Screen is currently off, check occasionally
            timeout 5 getevent -c 1 >/dev/null 2>&1
            sleep 1
        fi
    else
        LAST_PID=""
        sleep 2
    fi
done
