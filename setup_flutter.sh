#!/usr/bin/env bash
# ============================================================
# Flutter + Dart 开发环境安装脚本
# 支持: Ubuntu/Debian (x86_64)
# 用途: 可重复运行，幂等安全
# 用法: chmod +x setup_flutter.sh && ./setup_flutter.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 可配置变量 ──────────────────────────────────────────
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
FLUTTER_REPO="https://github.com/flutter/flutter.git"
FLUTTER_BRANCH="stable"
# ─────────────────────────────────────────────────────────

# ── 1. 系统依赖安装 ─────────────────────────────────────
log_info "安装 Linux 桌面构建依赖…"

PACKAGES=(
    curl
    git
    unzip
    xz-utils
    zip
    clang
    cmake
    ninja-build
    pkg-config
    libgtk-3-dev
    liblzma-dev
    libstdc++-12-dev
    libstdc++-14-dev
)

sudo apt-get update -qq
sudo apt-get install -y -qq "${PACKAGES[@]}"
log_info "系统依赖安装完成"

# ── 2. Flutter SDK 安装 ─────────────────────────────────
if [ -d "$FLUTTER_HOME/.git" ]; then
    log_info "Flutter SDK 已存在，更新到最新版本…"
    cd "$FLUTTER_HOME"
    git fetch origin
    git checkout "$FLUTTER_BRANCH"
    git pull origin "$FLUTTER_BRANCH"
else
    log_info "克隆 Flutter SDK (约 1.5 GB，请耐心等待)…"
    git clone "$FLUTTER_REPO" -b "$FLUTTER_BRANCH" "$FLUTTER_HOME"
fi

# ── 3. 环境变量配置 ─────────────────────────────────────
SHELL_RC=""
case "$SHELL" in
    */zsh)  SHELL_RC="$HOME/.zshrc"  ;;
    */bash) SHELL_RC="$HOME/.bashrc" ;;
    *)      SHELL_RC="$HOME/.profile" ;;
esac

FLUTTER_PATH_LINE="export PATH=\"\$PATH:$FLUTTER_HOME/bin\""

if grep -qF "$FLUTTER_PATH_LINE" "$SHELL_RC" 2>/dev/null; then
    log_info "PATH 已配置，跳过"
else
    echo "" >> "$SHELL_RC"
    echo "# Flutter SDK" >> "$SHELL_RC"
    echo "$FLUTTER_PATH_LINE" >> "$SHELL_RC"
    log_info "已写入 $SHELL_RC"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"

# ── 4. Dart SDK (随 Flutter 自带) ───────────────────────
log_info "Dart SDK 已随 Flutter 安装:"
dart --version 2>&1 || log_warn "Dart 未找到，请重新打开终端"

# ── 5. Flutter 自检 ─────────────────────────────────────
log_info "启用 Linux 桌面支持…"
flutter config --enable-linux-desktop 2>/dev/null || true

log_info "预下载开发工具…"
flutter precache --linux 2>/dev/null || true

log_info "运行 flutter doctor…"
flutter doctor -v 2>&1 || true

# ── 6. 验证 ─────────────────────────────────────────────
echo ""
log_info "=============================="
log_info "  安装完成！"
log_info "=============================="
echo ""
log_info "Flutter: $(flutter --version 2>/dev/null | head -1 || echo '请重新打开终端')"
log_info "Dart:    $(dart --version 2>/dev/null || echo '请重新打开终端')"
echo ""
log_info "安装目录: $FLUTTER_HOME"
log_info "如需手动加载环境变量: source $SHELL_RC"
echo ""
