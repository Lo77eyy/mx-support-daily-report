#!/usr/bin/env bash
# ============================================================
#  MX Support Daily Report — 环境初始化脚本 (Linux/macOS)
#
#  功能：
#    1. 下载 dws CLI（钉钉工作区命令行工具）
#    2. 安装 Python 依赖（openpyxl, requests）
#    3. 验证环境配置
#
#  用法：
#    bash setup.sh              — 完整安装
#    bash setup.sh --check      — 仅检查环境（不安装）
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/bin"

CHECK_ONLY=0
[ "$1" = "--check" ] && CHECK_ONLY=1

echo "============================================================"
echo " MX Support Daily Report — 环境初始化"
echo "============================================================"
echo

# ── 检测操作系统 ──
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
esac

# ============================================================
#  Step 1: 检查 Python
# ============================================================
echo "[Step 1/3] 检查 Python 环境..."

PYTHON_EXE=""
if command -v python3 &>/dev/null; then
    PYTHON_EXE="python3"
elif command -v python &>/dev/null; then
    PYTHON_EXE="python"
fi

if [ -z "$PYTHON_EXE" ]; then
    if [ "$CHECK_ONLY" = "1" ]; then
        echo "[WARN] 未找到 Python 3.10+"
    else
        echo "[ERROR] 未找到 Python，请安装 Python 3.10+"
        exit 1
    fi
else
    echo "[OK] Python: $PYTHON_EXE ($($PYTHON_EXE --version 2>&1))"
fi

# ============================================================
#  Step 2: 安装 Python 依赖
# ============================================================
if [ "$CHECK_ONLY" = "1" ]; then
    echo
    echo "[Step 2/3] 跳过（--check 模式）"
else
    echo
    echo "[Step 2/3] 安装 Python 依赖..."
    $PYTHON_EXE -m pip install openpyxl requests --quiet 2>/dev/null || \
    $PYTHON_EXE -m pip install openpyxl requests --user --quiet
    echo "[OK] Python 依赖已安装 (openpyxl, requests)"
fi

# ============================================================
#  Step 3: 检查/下载 dws CLI
# ============================================================
echo
echo "[Step 3/3] 检查 dws CLI..."

# 确定 dws 可执行文件名
if [ "$OS" = "Darwin" ]; then
    DWS_BIN="dws-darwin-$ARCH"
    DWS_EXE="dws"
elif [ "$OS" = "Linux" ]; then
    DWS_BIN="dws-linux-$ARCH"
    DWS_EXE="dws"
else
    echo "[ERROR] 不支持的操作系统: $OS"
    exit 1
fi

# 检查项目自带的 dws
if [ -f "$BIN_DIR/$DWS_EXE" ]; then
    echo "[OK] dws CLI 已存在: $BIN_DIR/$DWS_EXE"
elif [ "$CHECK_ONLY" = "1" ]; then
    echo "[WARN] dws CLI 未找到（$BIN_DIR/$DWS_EXE）"
else
    # 下载 dws
    echo "[INFO] 正在下载 dws CLI..."
    mkdir -p "$BIN_DIR"

    DWS_URL="https://github.com/DingTalk-Real-AI/dingtalk-workspace-cli/releases/latest/download/${DWS_BIN}.tar.gz"
    DWS_TAR="/tmp/${DWS_BIN}.tar.gz"

    echo "[INFO] 从 $DWS_URL 下载..."
    if command -v curl &>/dev/null; then
        curl -sL -o "$DWS_TAR" "$DWS_URL"
    elif command -v wget &>/dev/null; then
        wget -q -O "$DWS_TAR" "$DWS_URL"
    else
        echo "[ERROR] 需要 curl 或 wget 来下载文件"
        exit 1
    fi

    if [ ! -f "$DWS_TAR" ]; then
        echo "[ERROR] 下载失败，请手动下载:"
        echo "        https://github.com/DingTalk-Real-AI/dingtalk-workspace-cli/releases"
        echo "        将 dws 放入: $BIN_DIR/"
        exit 1
    fi

    # 解压
    echo "[INFO] 解压 dws..."
    tar -xzf "$DWS_TAR" -C "$BIN_DIR"
    chmod +x "$BIN_DIR/$DWS_EXE"

    if [ -f "$BIN_DIR/$DWS_EXE" ]; then
        echo "[OK] dws CLI 已安装到: $BIN_DIR/$DWS_EXE"
    else
        echo "[ERROR] 解压失败，请手动下载并放入: $BIN_DIR/"
    fi

    rm -f "$DWS_TAR"
fi

# ============================================================
#  验证环境
# ============================================================
echo
echo "============================================================"
echo " 环境检查"
echo "============================================================"

if [ -n "$PYTHON_EXE" ]; then
    echo "[OK] Python: $PYTHON_EXE"
else
    echo "[!!] Python: 未找到"
fi

if [ -f "$BIN_DIR/$DWS_EXE" ]; then
    echo "[OK] dws CLI: $BIN_DIR/$DWS_EXE"
    "$BIN_DIR/$DWS_EXE" --version 2>/dev/null || true
else
    echo "[!!] dws CLI: 未找到"
fi

echo
if [ -n "$FRESHDESK_API_KEY" ]; then
    echo "[OK] FRESHDESK_API_KEY: 已设置"
else
    echo "[!!] FRESHDESK_API_KEY: 未设置（拉取 Freshdesk 数据需要）"
fi

if [ -n "$FRESHDESK_DOMAIN" ]; then
    echo "[OK] FRESHDESK_DOMAIN: $FRESHDESK_DOMAIN"
else
    echo "[!!] FRESHDESK_DOMAIN: 未设置（拉取 Freshdesk 数据需要）"
fi

echo
echo "============================================================"
echo " 设置说明"
echo "============================================================"
echo
echo " 环境变量（添加到 ~/.bashrc 或 ~/.zshrc）:"
echo "   export FRESHDESK_API_KEY='你的API密钥'"
echo "   export FRESHDESK_DOMAIN='glinetservice.freshdesk.com'"
echo
echo " 钉钉授权（首次运行同步时需要在浏览器中授权）"
echo
echo "============================================================"
