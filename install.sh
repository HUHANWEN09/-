#!/bin/bash
# 荣耀手机电脑模式与超清投屏套件 - macOS 智能命令行安装程序 (支持一键在线安装与本地安装)
set -e

REPO_URL="https://github.com/HUHANWEN09/-.git"
INSTALL_TARGET="$HOME/honor-cast"

# 检测是否是通过 curl | bash 在线运行，或者缺少仓库文件
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    IS_STANDALONE=1
else
    DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
    if [ ! -d "$DIR/macos" ] || [ ! -d "$DIR/bin" ]; then
        IS_STANDALONE=1
    else
        IS_STANDALONE=0
        ROOT_DIR="$DIR"
    fi
fi

# 如果是在线运行，自动克隆仓库到 ~/honor-cast
if [ "$IS_STANDALONE" -eq 1 ]; then
    echo "================================================================"
    echo "  荣耀手机电脑模式与超清投屏套件 - macOS 一键在线安装"
    echo "================================================================"
    echo "[下载] 正在自动从 GitHub 克隆完整套件到: $INSTALL_TARGET ..."
    if [ -d "$INSTALL_TARGET/.git" ]; then
        echo "  -> 检测到已存在安装目录，正在拉取最新代码..."
        cd "$INSTALL_TARGET" && git pull origin main || true
    else
        rm -rf "$INSTALL_TARGET"
        git clone "$REPO_URL" "$INSTALL_TARGET"
    fi
    cd "$INSTALL_TARGET"
    chmod +x install.sh
    exec bash "$INSTALL_TARGET/install.sh"
    exit 0
fi

BIN_DIR="$ROOT_DIR/bin"
MAC_DIR="$ROOT_DIR/macos"
CORE_DIR="$MAC_DIR/core"

echo "================================================================"
echo "  荣耀手机电脑模式与超清投屏套件 - macOS 智能命令行安装程序"
echo "================================================================"

chmod +x "$BIN_DIR/honor-cast" "$MAC_DIR/"*.command "$MAC_DIR/"*.sh

# Step 1: 检测并对比 Mac 上已有的 scrcpy / adb 环境
echo ""
echo "[1/5] 正在检测并对比 Mac 上已有的 scrcpy / adb 环境..."
if command -v scrcpy >/dev/null 2>&1; then
    SCRCPY_VER="$(scrcpy --version | head -n 1)"
    echo "  -> 检测到系统已安装: $SCRCPY_VER ($(command -v scrcpy))"
    MAJOR_VER="$(echo "$SCRCPY_VER" | awk '{print $2}' | cut -d. -f1)"
    if [ "${MAJOR_VER:-0}" -lt 3 ]; then
        echo "  -> [对比与取舍]: 当前 scrcpy 版本低于 3.0，不支持 --new-display 独立虚拟桌面电脑模式。"
        echo "     正在通过 Homebrew 升级 scrcpy 至最新版..."
        brew upgrade scrcpy || brew install scrcpy
    else
        echo "  -> [对比与取舍]: 版本满足 >= 3.0 要求！将直接复用系统 scrcpy 客户端二进制，"
        echo "     并通过 SCRCPY_SERVER_PATH 环境变量挂载本套件增强版 scrcpy-server，绝不覆盖 Homebrew 原有文件！"
    fi
else
    echo "  -> 未检测到 scrcpy，正在通过 Homebrew 安装 scrcpy 与 android-platform-tools..."
    if ! command -v brew >/dev/null 2>&1; then
        echo "❌ 未检测到 Homebrew，请先在终端执行以下命令安装 Homebrew 后再试:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install scrcpy android-platform-tools
fi

if ! command -v adb >/dev/null 2>&1; then
    brew install --cask android-platform-tools || brew install android-platform-tools
fi

# Step 2: 检查并保护 ~/.android/adbkey 密钥
echo ""
echo "[2/5] 正在检查 ADB 授权密钥 (~/.android/adbkey)..."
mkdir -p ~/.android
if [ -f ~/.android/adbkey ]; then
    echo "  -> [对比与取舍]: 检测到当前 Mac 已存在 ~/.android/adbkey，已完整保留（防止您已授权的其它设备失效）。"
elif [ -f "$CORE_DIR/adbkey" ]; then
    cp "$CORE_DIR/adbkey" ~/.android/adbkey
    cp "$CORE_DIR/adbkey.pub" ~/.android/adbkey.pub
    chmod 600 ~/.android/adbkey
    chmod 644 ~/.android/adbkey.pub
    echo "  -> 已导入预授权密钥至 ~/.android/adbkey。"
fi

# Step 3: 注册命令行工具 `honor-cast`
echo ""
echo "[3/5] 正在注册命令行工具 (honor-cast)..."
if [ -w "/opt/homebrew/bin" ]; then
    ln -sf "$BIN_DIR/honor-cast" /opt/homebrew/bin/honor-cast
    echo "  -> 已创建软链接: /opt/homebrew/bin/honor-cast"
elif [ -w "/usr/local/bin" ]; then
    ln -sf "$BIN_DIR/honor-cast" /usr/local/bin/honor-cast
    echo "  -> 已创建软链接: /usr/local/bin/honor-cast"
else
    mkdir -p "$HOME/.local/bin"
    ln -sf "$BIN_DIR/honor-cast" "$HOME/.local/bin/honor-cast"
    if ! grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    echo "  -> 已创建软链接: ~/.local/bin/honor-cast (已加入 ~/.zshrc)"
fi

# Step 4: 在 Mac 桌面与应用程序目录生成可直接点击的 .app 图标
echo ""
echo "[4/5] 正在生成 macOS 桌面与应用程序 (.app) 图标..."
bash "$MAC_DIR/create_mac_apps.sh"

# Step 5: 开启 macOS USB 插线即投屏 LaunchAgent 守护服务
echo ""
echo "[5/5] 正在开启 macOS USB 插线自动进入电脑模式守护服务..."
bash "$MAC_DIR/3_开启USB插线自动电脑模式.command"

echo ""
echo "================================================================"
echo "✅ macOS 安装全部完成！您现在可以："
echo "  1. 直接将手机通过 USB 插入 Mac -> 自动弹出荣耀电脑模式且手机自动黑屏"
echo "  2. 直接点击桌面或启动台中的【荣耀电脑模式.app】或【荣耀手机投屏.app】图标"
echo "  3. 在终端随时运行命令: honor-cast desktop 或 honor-cast mirror"
echo "================================================================"
