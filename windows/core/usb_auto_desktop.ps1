$env:SDL_MOUSE_FOCUS_CLICKTHROUGH = "1"
$env:SDL_IME_SHOW_UI = "1"
$coreDir = $PSScriptRoot
$adb = Join-Path $coreDir "adb.exe"
$scrcpy = Join-Path $coreDir "scrcpy.exe"
$helperJar = Join-Path $coreDir "screen_off_helper.jar"
$daemonSh = Join-Path $coreDir "auto_screen_off.sh"
$wasConnected = $false
$proc = $null

while ($true) {
    try {
        $out = & $adb devices 2>$null
        $devs = $out | Select-String -Pattern '\tdevice\s*$'
        if ($devs) {
            $disconnectedAbnormally = ($null -ne $proc) -and $proc.HasExited -and ($proc.ExitCode -ne 0)
            if ((-not $wasConnected) -or $disconnectedAbnormally) {
                $wasConnected = $true
                & $adb shell settings put global adb_allowed_connection_time 0 2>$null
                & $adb shell settings put secure selected-proj-mode 1 2>$null
                if (Test-Path $helperJar) { & $adb push $helperJar /data/local/tmp/screen_off_helper.jar 2>$null | Out-Null }
                if (Test-Path $daemonSh) {
                    & $adb push $daemonSh /data/local/tmp/auto_screen_off.sh 2>$null | Out-Null
                    & $adb shell "chmod 755 /data/local/tmp/auto_screen_off.sh; ps -ef | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)" 2>$null
                }
                $running = Get-Process scrcpy -ErrorAction SilentlyContinue
                if (-not $running) {
                    $proc = Start-Process -FilePath $scrcpy -ArgumentList "--new-display=1920x1080/160","--turn-screen-off","--no-audio","--no-mouse-hover","--window-title=Honor_PC_Mode" -WorkingDirectory $coreDir -WindowStyle Normal -PassThru
                }
            }
        } else {
            $wasConnected = $false
        }
    } catch {}
    Start-Sleep -Seconds 1
}
