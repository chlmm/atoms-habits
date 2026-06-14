#!/usr/bin/env bash
# ============================================================
# TigerVNC 服务端安装脚本
# 适用于 Ubuntu/Debian (无图形界面环境)
# 用法:
#   chmod +x install_tigervnc.sh
#   sudo ./install_tigervnc.sh          # 最小安装 (仅 VNC)
#   sudo ./install_tigervnc.sh --novnc  # 带 noVNC Web 代理 (通过浏览器访问)
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

INSTALL_NOVNC=false
if [ "${1:-}" = "--novnc" ]; then
    INSTALL_NOVNC=true
fi

# ── 1. 安装必要组件 ──────────────────────────────────────
log_info "更新包列表…"
apt-get update -qq

PACKAGES=(
    tigervnc-standalone-server
    tigervnc-common
    openbox                        # ← 窗口管理器：允许拖拽、缩放、管理窗口
    dbus-x11
    x11-utils
    x11-xserver-utils
    xterm
)

if $INSTALL_NOVNC; then
    log_info "安装 VNC 服务端 + openbox + noVNC…"
    PACKAGES+=(
        novnc
        websockify
    )
else
    log_info "安装 VNC 服务端 + openbox（最小安装）…"
fi

apt-get install -y -qq "${PACKAGES[@]}"

# ── 2. VNC 无密码模式 ────────────────────────────────────
VNC_PASSWD_DIR="$HOME/.vnc"
mkdir -p "$VNC_PASSWD_DIR"
rm -f "$VNC_PASSWD_DIR/passwd"
log_info "VNC 设为无密码模式（直连）"

# ── 3. 创建 xstartup（使用 openbox 做窗口管理器）─────────
log_info "创建 ~/.vnc/xstartup (窗口管理器: openbox)…"
cat > "$VNC_PASSWD_DIR/xstartup" << 'XSTARTUP'
#!/bin/bash
# VNC xstartup — 轻量桌面环境 (openbox)
# openbox 提供窗口边框、拖拽、缩放等基础窗口管理功能

export XDG_SESSION_TYPE=x11

# 设置背景色（灰色桌面）
xsetroot -solid "#2e2e2e" &

# 启动 dbus + openbox（openbox 保持在前台，VNC 会话不会退出）
dbus-launch --exit-with-session openbox
XSTARTUP
chmod +x "$VNC_PASSWD_DIR/xstartup"

# ── 4. 创建 openbox 基础配置（可选）──────────────────────
OPENBOX_DIR="$HOME/.config/openbox"
mkdir -p "$OPENBOX_DIR"

# 留空 autostart，以后可以在这里加开机启动项
if [ ! -f "$OPENBOX_DIR/autostart" ]; then
    touch "$OPENBOX_DIR/autostart"
fi

# ── 5. 验证安装 ──────────────────────────────────────────
echo ""
log_info "=============================="
log_info "  安装完成！"
log_info "=============================="
log_info "VNC 密码: 无（直连）"
log_info "窗口管理器: openbox"
log_info "显示编号: :1 (端口 5901)"
echo ""

if $INSTALL_NOVNC; then
    log_info "noVNC 已安装 → 可通过浏览器访问"
else
    log_info "noVNC 未安装 → 需用 VNC 客户端连接"
    log_info "  如需浏览器访问，重新运行: sudo ./install_tigervnc.sh --novnc"
fi

echo ""
log_info "手动命令:"
log_info "  启动: vncserver :1 -localhost no -geometry 1280x720"
log_info "  停止: vncserver -kill :1"
echo ""
