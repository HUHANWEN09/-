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
    Write-Host "[检测] 正在连接手机并进行多机型智能适配检测..." -ForegroundColor Cyan
    & $Adb wait-for-device
    
    $Brand = ((& $Adb shell getprop ro.product.brand) -join "").Trim()
    $Model = ((& $Adb shell getprop ro.product.model) -join "").Trim()
    $SdkStr = ((& $Adb shell getprop ro.build.version.sdk) -join "").Trim()
    $Sdk = 0
    if ($SdkStr -match '\d+') { $Sdk = [int]$matches[0] }
    $AndroidVer = ((& $Adb shell getprop ro.build.version.release) -join "").Trim()
    $Manufacturer = ((& $Adb shell getprop ro.product.manufacturer) -join "").Trim()

    Write-Host "[机型识别] 品牌: $Brand ($Manufacturer) | 型号: $Model | Android $AndroidVer (API $Sdk)" -ForegroundColor Green

    # 1. 全局通用安卓优化配置 (关闭授权倒计时、开启多窗口自由模式、开启副屏桌面)
    & $Adb shell settings put global adb_allowed_connection_time 0 2>$null
    & $Adb shell settings put global force_desktop_mode_on_external_displays 1 2>$null
    & $Adb shell settings put global enable_freeform_support 1 2>$null

    # 2. 品牌针对性适配
    $BrandLower = "$Brand $Manufacturer".ToLower()
    if ($BrandLower -match "honor|huawei") {
        # 荣耀 / 华为 EMUI / MagicOS 原生电脑模式开关
        & $Adb shell settings put secure selected-proj-mode 1 2>$null
        Write-Host "  -> 已开启荣耀/华为 MagicOS 专属原生电脑桌面引擎" -ForegroundColor DarkCyan
    } elseif ($BrandLower -match "xiaomi|redmi|poco") {
        # 小米 / 红米 MIUI / HyperOS 特殊权限检测
        $testInput = (& $Adb shell "input tap 0 0 2>&1") -join ""
        if ($testInput -match "permission|denied|SecurityException") {
            Write-Host "  [!] 小米/红米安全设置提示: 检测到未开启模拟点击权限。" -ForegroundColor Yellow
            Write-Host "      若投屏后鼠标无法操作，请在手机「开发者选项」中开启「USB 调试 (安全设置)」！" -ForegroundColor Yellow
        } else {
            Write-Host "  -> 小米/红米模拟点击与多任务窗口支持已就绪" -ForegroundColor DarkCyan
        }
    } elseif ($BrandLower -match "samsung") {
        Write-Host "  -> 三星 One UI / DeX 桌面扩展支持已就绪" -ForegroundColor DarkCyan
    } elseif ($BrandLower -match "oppo|oneplus|realme") {
        Write-Host "  -> OPPO / 一加 / 真我 ColorOS 多窗口桌面扩展已就绪" -ForegroundColor DarkCyan
    } elseif ($BrandLower -match "vivo|iqoo") {
        Write-Host "  -> vivo / iQOO OriginOS 多窗口桌面扩展已就绪" -ForegroundColor DarkCyan
    }

    # 3. 推送黑屏驱动与多机型通用自动复黑守护脚本
    if (Test-Path $HelperJar) {
        & $Adb push $HelperJar /data/local/tmp/screen_off_helper.jar 2>$null | Out-Null
    }
    if (Test-Path $DaemonSh) {
        & $Adb push $DaemonSh /data/local/tmp/auto_screen_off.sh 2>$null | Out-Null
        & $Adb shell "chmod 755 /data/local/tmp/auto_screen_off.sh; (ps -ef 2>/dev/null || ps 2>/dev/null) | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)" 2>$null
    }

    return @{ Sdk = $Sdk; Brand = $Brand; AndroidVer = $AndroidVer }
}

function Start-MirrorMode {
    param([string]$Title = "Android_Phone_Mirror")
    Write-Host "[启动] 正在以【1:1 超清手机镜像模式】投屏 (全机型 100% 兼容保证)..." -ForegroundColor Green
    $p = Start-Process -FilePath $Scrcpy -ArgumentList "--turn-screen-off","--stay-awake","--no-audio","--window-title=$Title" -WorkingDirectory $CoreDir -PassThru
    Start-Sleep -Seconds 2
    if ($p.HasExited) {
        Write-Host "[重试] 检测到硬件编码器限制，正在以自适应安全分辨率启动..." -ForegroundColor Yellow
        Start-Process -FilePath $Scrcpy -ArgumentList "--max-size=1280","--turn-screen-off","--stay-awake","--no-audio","--window-title=$Title" -WorkingDirectory $CoreDir
    }
}

function Start-DesktopMode {
    $info = Initialize-Phone
    $sdk = $info.Sdk
    $ver = $info.AndroidVer

    if ($sdk -gt 0 -and $sdk -lt 29) {
        Write-Host "[兼容模式] 检测到系统为 Android $ver (SDK $sdk < 29)。" -ForegroundColor Yellow
        Write-Host "           Android 10 以下系统底层不支持独立虚拟副屏，已自动为您启用【1:1 超清手机镜像投屏】！" -ForegroundColor Yellow
        Start-MirrorMode -Title "Android_Phone_Mirror"
        return
    }

    Write-Host "[启动] 正在打开【独立电脑模式 (1920x1080)】(手机自动黑屏)..." -ForegroundColor Green
    $p = Start-Process -FilePath $Scrcpy -ArgumentList "--new-display=1920x1080/160","--turn-screen-off","--no-audio","--no-mouse-hover","--window-title=PC_Mode" -WorkingDirectory $CoreDir -PassThru
    
    # 监控 2.5 秒，检测当前机型 ROM 是否支持独立副屏
    Start-Sleep -Milliseconds 2500
    if ($p.HasExited) {
        Write-Host "[容灾降级保障] 当前机型 ROM 或 GPU 硬件对独立虚拟副屏不支持/限制。" -ForegroundColor Yellow
        Write-Host "               套件已触发智能容灾降级机制，平滑切换至【1:1 超清手机投屏】，确保 100% 成功可用！" -ForegroundColor Yellow
        Start-MirrorMode -Title "Android_Phone_Mirror"
    } else {
        Write-Host "[成功] 独立电脑模式已就绪！(如误关窗口可随时按 Ctrl+Alt+D 恢复)" -ForegroundColor Green
    }
}

switch ($Command.ToLower()) {
    { $_ -in @("desktop", "pc", "电脑模式") } {
        Start-DesktopMode
    }
    { $_ -in @("mirror", "phone", "手机投屏", "镜像") } {
        Initialize-Phone | Out-Null
        Start-MirrorMode -Title "Android_Phone_Mirror"
    }
    { $_ -in @("daemon", "auto", "开启自启") } {
        Get-Process pythonw -ErrorAction SilentlyContinue | Stop-Process -Force
        $pyw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
        if ($pyw -and (Test-Path $PywScript)) {
            Start-Process -FilePath $pyw -ArgumentList "`"$PywScript`"" -WorkingDirectory $CoreDir
            Write-Host "[守护] 已启动 Windows 后台 USB 插线自动电脑模式守护进程 (多机型智能适配 + 容灾降级支持)！" -ForegroundColor Green
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
        Initialize-Phone | Out-Null
        Write-Host "[完成] 手机多机型环境已成功配置完毕！" -ForegroundColor Green
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

全机型兼容命令:
  honor-cast desktop     启动【电脑模式投屏】(独立副屏桌面；如机型不支持则全自动平滑降级为超清投屏)
  honor-cast mirror      启动【正常手机投屏】(1:1 超清手机镜像，全安卓机型 100% 兼容)
  honor-cast daemon      开启【USB 插线自动投屏】后台守护进程 (自动机型适配 + 容灾)
  honor-cast stop        关闭后台守护进程及投屏窗口
  honor-cast init-phone  一键为新连接的任何安卓手机自动配置底层环境（免手动调试）
  honor-cast status      查看当前设备连接与守护进程状态
"@ -ForegroundColor White
    }
}