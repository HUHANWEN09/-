param(
    [Parameter(Position=0)]
    [string]$Command = "desktop",
    [Parameter(Position=1)]
    [string]$Arg1 = ""
)

$ErrorActionPreference = "SilentlyContinue"
$RootDir = Split-Path -Parent $PSScriptRoot
$CoreDir = Join-Path $RootDir "windows\core"
$Adb = Join-Path $CoreDir "adb.exe"
$Scrcpy = Join-Path $CoreDir "scrcpy.exe"
$HelperJar = Join-Path $CoreDir "screen_off_helper.jar"
$DaemonSh = Join-Path $CoreDir "auto_screen_off.sh"
$PywScript = Join-Path $CoreDir "usb_auto_desktop.pyw"
$Ps1Script = Join-Path $CoreDir "usb_auto_desktop.ps1"

$env:SDL_MOUSE_FOCUS_CLICKTHROUGH = "1"
$env:SDL_IME_SHOW_UI = "1"
$env:SCRCPY_SERVER_PATH = Join-Path $CoreDir "scrcpy-server"

function Initialize-Phone {
    Write-Host "[配置] 正在检测并自动初始化手机底层环境（免手动调试）..." -ForegroundColor Cyan
    & $Adb wait-for-device
    & $Adb shell settings put global adb_allowed_connection_time 0 2>$null
    & $Adb shell settings put secure selected-proj-mode 1 2>$null
    if (Test-Path $HelperJar) {
        & $Adb push $HelperJar /data/local/tmp/screen_off_helper.jar 2>$null | Out-Null
    }
    if (Test-Path $DaemonSh) {
        & $Adb push $DaemonSh /data/local/tmp/auto_screen_off.sh 2>$null | Out-Null
        & $Adb shell "chmod 755 /data/local/tmp/auto_screen_off.sh; ps -ef | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)" 2>$null
    }
    Write-Host "[完成] 手机已开启永久授权、原生电脑模式、投屏自动黑屏与亮屏10秒无触控再黑屏守护！" -ForegroundColor Green
}

switch ($Command.ToLower()) {
    { $_ -in @("desktop", "pc", "电脑模式") } {
        Initialize-Phone
        Write-Host "[启动] 正在打开【荣耀原生电脑模式 (1920x1080)】(手机自动黑屏)..." -ForegroundColor Green
        Start-Process -FilePath $Scrcpy -ArgumentList "--new-display=1920x1080/160","--turn-screen-off","--no-audio","--no-mouse-hover","--window-title=Honor_PC_Mode" -WorkingDirectory $CoreDir
    }
    { $_ -in @("mirror", "phone", "手机投屏", "镜像") } {
        Initialize-Phone
        Write-Host "[启动] 正在打开【正常手机屏幕投屏 (1:1 超清镜像)】(手机自动黑屏)..." -ForegroundColor Green
        Start-Process -FilePath $Scrcpy -ArgumentList "--turn-screen-off","--stay-awake","--no-audio","--window-title=Honor_Phone_Mirror" -WorkingDirectory $CoreDir
    }
    { $_ -in @("daemon", "auto", "开启自启") } {
        Get-Process pythonw -ErrorAction SilentlyContinue | Stop-Process -Force
        $pyw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
        if ($pyw -and (Test-Path $PywScript)) {
            Start-Process -FilePath $pyw -ArgumentList "`"$PywScript`"" -WorkingDirectory $CoreDir
            Write-Host "[守护] 已启动 Windows 后台 USB 插线自动电脑模式守护进程 (支持 Ctrl+Alt+D 随时唤起)！" -ForegroundColor Green
        } else {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Ps1Script`"" -WorkingDirectory $CoreDir
            Write-Host "[守护] 已启动 PowerShell 后台 USB 插线自动电脑模式守护进程！" -ForegroundColor Green
        }
    }
    { $_ -in @("stop", "关闭自启") } {
        Get-Process pythonw, scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host "[停止] 已关闭后台守护进程与投屏窗口。" -ForegroundColor Yellow
    }
    { $_ -in @("init-phone", "初始化手机") } {
        Initialize-Phone
    }
    { $_ -in @("status", "状态") } {
        Write-Host "=== 已连接手机设备 ===" -ForegroundColor Cyan
        & $Adb devices -l
        Write-Host "=== 电脑端运行状态 ===" -ForegroundColor Cyan
        Get-Process pythonw, scrcpy -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, SessionId | Format-Table
    }
    default {
        Write-Host @"
用法: honor-cast <命令>

可用命令:
  honor-cast desktop     启动【电脑模式投屏】(手机变电脑主机，1920x1080 独立桌面，手机自动黑屏)
  honor-cast mirror      启动【正常手机投屏】(1:1 手机屏幕镜像，手机自动黑屏)
  honor-cast daemon      开启【USB 插线自动进入电脑模式】后台守护进程
  honor-cast stop        关闭后台守护进程及投屏窗口
  honor-cast init-phone  一键自动配置新接入的手机（免手动调试）
  honor-cast status      查看当前设备连接与守护进程状态
"@ -ForegroundColor White
    }
}
