param(
    [switch]$ForceReplace,
    [switch]$NoAutoStart
)

$ErrorActionPreference = "Continue"
$RootDir = $PSScriptRoot
$BinDir = Join-Path $RootDir "bin"
$WinDir = Join-Path $RootDir "windows"
$CoreDir = Join-Path $WinDir "core"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  荣耀手机电脑模式与超清投屏套件 - Windows 智能命令行安装程序" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Step 1: 检测并对比系统中已有的 scrcpy / adb 环境（非破坏性共存）
Write-Host "`n[1/5] 正在检测电脑上已有的投屏/ADB相关环境..." -ForegroundColor Yellow
$ExistingScrcpy = Get-Command scrcpy.exe -ErrorAction SilentlyContinue
$ExistingAdb = Get-Command adb.exe -ErrorAction SilentlyContinue

if ($ExistingScrcpy) {
    $verOut = & $ExistingScrcpy.Source --version 2>$null | Select-Object -First 1
    Write-Host "  -> 检测到系统已安装 scrcpy: $($ExistingScrcpy.Source) ($verOut)" -ForegroundColor Gray
    Write-Host "  -> [对比与取舍策略]: 原版 scrcpy-server 未解锁荣耀 CastPlusDisplay 电脑模式且不支持拼音直接输入汉字。" -ForegroundColor Gray
    Write-Host "     为保护您原有的 scrcpy 环境，本套件采用独立目录与 SCRCPY_SERVER_PATH 环境变量隔离运行，绝不覆盖您原有的系统文件！" -ForegroundColor Green
} else {
    Write-Host "  -> 未检测到全局 scrcpy，将直接使用本套件内置的 scrcpy v3.1 增强版内核。" -ForegroundColor Green
}

if ($ExistingAdb) {
    Write-Host "  -> 检测到系统已有 ADB: $($ExistingAdb.Source)，本套件将与之共享 ~/.android 授权密钥池，互不冲突。" -ForegroundColor Green
}

# Step 2: 对比并安全处理 ~/.android/adbkey 密钥（绝不盲目覆盖已有授权）
Write-Host "`n[2/5] 正在检查 ADB 预授权密钥 (~/.android/adbkey)..." -ForegroundColor Yellow
$AndroidDir = Join-Path $env:USERPROFILE ".android"
if (-not (Test-Path $AndroidDir)) { New-Item -ItemType Directory -Path $AndroidDir | Out-Null }
$UserKey = Join-Path $AndroidDir "adbkey"
$PkgKey = Join-Path $CoreDir "adbkey"

if (Test-Path $UserKey) {
    Write-Host "  -> 检测到当前电脑已存在 ADB 授权密钥 ($UserKey)。" -ForegroundColor Gray
    if ($ForceReplace -and (Test-Path $PkgKey)) {
        $BakKey = "$UserKey.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $UserKey $BakKey -Force
        Copy-Item "$UserKey.pub" "$BakKey.pub" -Force -ErrorAction SilentlyContinue
        Copy-Item $PkgKey $UserKey -Force
        Copy-Item "$PkgKey.pub" "$UserKey.pub" -Force
        Write-Host "  -> [取舍]: 已将原密钥备份至 $BakKey，并替换为套件预授权密钥。" -ForegroundColor Green
    } else {
        Write-Host "  -> [取舍]: 保留当前电脑已有的 ADB 密钥（防止您已授权的其它手机失效）。" -ForegroundColor Green
    }
} elseif (Test-Path $PkgKey) {
    Copy-Item $PkgKey $UserKey -Force
    Copy-Item "$PkgKey.pub" "$UserKey.pub" -Force
    Write-Host "  -> 当前电脑无 ADB 密钥，已自动导入套件内置预授权密钥（支持碎屏免触控直连）。" -ForegroundColor Green
}

# Step 3: 注册命令行工具 `honor-cast` 到用户 PATH
Write-Host "`n[3/5] 正在配置命令行工具 (honor-cast)..." -ForegroundColor Yellow
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
    $env:Path = "$env:Path;$BinDir"
    Write-Host "  -> 已将 $BinDir 添加到用户环境变量 PATH，可在任意终端直接运行 `honor-cast` 命令！" -ForegroundColor Green
} else {
    Write-Host "  -> 环境变量 PATH 中已包含 $BinDir，无需重复添加。" -ForegroundColor Green
}

# Step 4: 在桌面创建【荣耀电脑模式】与【荣耀手机投屏】快捷图标
Write-Host "`n[4/5] 正在桌面创建快捷启动图标..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [Environment]::GetFolderPath("Desktop")
$IconPath = Join-Path $CoreDir "scrcpy.exe"

$Shortcuts = @(
    @{ Name = "荣耀电脑模式 (主机桌面).lnk"; Target = Join-Path $WinDir "1_启动电脑模式(主机桌面).bat"; Desc = "手机变电脑主机，1920x1080独立桌面，手机自动黑屏" },
    @{ Name = "荣耀手机投屏 (1比1镜像).lnk"; Target = Join-Path $WinDir "2_启动正常手机投屏(1比1镜像).bat"; Desc = "1:1正常手机屏幕镜像，手机自动黑屏" }
)
foreach ($sc in $Shortcuts) {
    $lnkPath = Join-Path $Desktop $sc.Name
    $shortcut = $WshShell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $sc.Target
    $shortcut.WorkingDirectory = $WinDir
    $shortcut.IconLocation = "$IconPath,0"
    $shortcut.Description = $sc.Desc
    $shortcut.Save()
    Write-Host "  -> 已生成桌面图标: $($sc.Name)" -ForegroundColor Green
}

# Step 5: 配置开机自启与后台 USB 插线自动投屏守护进程
Write-Host "`n[5/5] 正在配置 USB 插线自动进入电脑模式守护进程..." -ForegroundColor Yellow
if (-not $NoAutoStart) {
    $StartupDir = [Environment]::GetFolderPath("Startup")
    $StartupLnk = Join-Path $StartupDir "Honor_USB_Auto_Desktop.lnk"
    $pyw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
    $shortcut = $WshShell.CreateShortcut($StartupLnk)
    if ($pyw) {
        $shortcut.TargetPath = $pyw
        $shortcut.Arguments = "`"$(Join-Path $CoreDir 'usb_auto_desktop.pyw')`""
    } else {
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $CoreDir 'usb_auto_desktop.ps1')`""
    }
    $shortcut.WorkingDirectory = $CoreDir
    $shortcut.IconLocation = "$IconPath,0"
    $shortcut.Save()
    & (Join-Path $BinDir "honor-cast.ps1") daemon
    Write-Host "  -> 已开启开机自启与 USB 插线自动弹出电脑模式（支持 Ctrl+Alt+D 全局热键唤起）！" -ForegroundColor Green
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "✅ 安装完成！您现在可以：" -ForegroundColor Green
Write-Host "  1. 直接插上手机数据线 -> 自动弹出荣耀电脑模式窗口且手机自动黑屏"
Write-Host "  2. 点击桌面图标【荣耀电脑模式 (主机桌面)】或【荣耀手机投屏 (1比1镜像)】"
Write-Host "  3. 在任意终端输入命令: honor-cast desktop 或 honor-cast mirror"
Write-Host "================================================================" -ForegroundColor Cyan
