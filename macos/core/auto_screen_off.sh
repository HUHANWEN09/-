#!/system/bin/sh
# Honor Phone - Auto Screen-Off on Projection & 10s Idle Re-Screen-Off Daemon
LAST_PID=""
while true; do
    PID=$(ps -ef | grep "com.genymobile.scrcpy.Server" | grep -v grep | awk '{print $2}' | head -n 1)
    if [ -n "$PID" ]; then
        if [ "$PID" != "$LAST_PID" ]; then
            LAST_PID="$PID"
            sleep 1
            CLASSPATH=/data/local/tmp/screen_off_helper.jar app_process / com.genymobile.scrcpy.CleanUp >/dev/null 2>&1
        fi
        if dumpsys SurfaceFlinger | grep -q "isEnabled=true isSecure=true"; then
            while dumpsys SurfaceFlinger | grep -q "isEnabled=true isSecure=true"; do
                if timeout 10 getevent -c 1 >/dev/null 2>&1; then
                    sleep 1
                else
                    if ps -ef | grep -v grep | grep -q "com.genymobile.scrcpy.Server"; then
                        CLASSPATH=/data/local/tmp/screen_off_helper.jar app_process / com.genymobile.scrcpy.CleanUp >/dev/null 2>&1
                    fi
                    break
                fi
            done
        else
            timeout 5 getevent -c 1 >/dev/null 2>&1
            sleep 1
        fi
    else
        LAST_PID=""
        sleep 2
    fi
done
