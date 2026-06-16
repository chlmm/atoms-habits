#!/usr/bin/env bash
# ============================================================
# Atoms App 启动脚本
# 编译 + 在 VNC :1 上启动
# 用法: ./scripts/start_atoms.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

DISPLAY_TARGET="${DISPLAY_TARGET:-:1}"
FLUTTER_BIN="$HOME/flutter/bin"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

export PATH="$PATH:$FLUTTER_BIN"
export DISPLAY="$DISPLAY_TARGET"

BIN="$PROJECT_DIR/build/linux/x64/debug/bundle/atoms_habits"
DATA_DIR="$(dirname "$BIN")/data"
FLUTTER_ASSETS="$PROJECT_DIR/build/flutter_assets"
ICU_DAT="$PROJECT_DIR/linux/flutter/ephemeral/icudtl.dat"

# ── 检查 VNC 是否在运行 ──────────────────────────────────
if ! pgrep -f "Xtigervnc.*:${DISPLAY_TARGET#:}" > /dev/null 2>&1; then
    log_error "VNC :${DISPLAY_TARGET#:} 未运行，请先启动 VNC"
    log_error "  ./scripts/vnc_push.sh            # 桌面模式"
    log_error "  ./scripts/vnc_push.sh --phone     # 手机模式"
    log_error "  ./scripts/vnc_push.sh --web-phone # 手机Web模式"
    exit 1
fi

# ── 1. 准备数据目录 ──────────────────────────────────────
mkdir -p "$DATA_DIR"
ln -sfn "$FLUTTER_ASSETS" "$DATA_DIR/flutter_assets"
cp -f "$ICU_DAT" "$DATA_DIR/icudtl.dat"

# ── 2. 编译（仅二进制不存在时） ──────────────────────────
if [ ! -f "$BIN" ]; then
    log_info "二进制不存在，编译中…"
    cd "$PROJECT_DIR"

    CPLUS_INCLUDE_PATH="/usr/include/x86_64-linux-gnu/c++/14:/usr/include/x86_64-linux-gnu" \
        flutter build linux --debug 2>&1 | grep -E "Built|Error" || true

    if [ ! -f "$BIN" ]; then
        log_error "编译失败"
        exit 1
    fi
    log_info "编译完成"
else
    log_info "使用已有二进制（如需重新编译请先 flutter build linux --debug）"
fi

# ── 3. 杀掉所有旧 atoms_habits 进程 ──────────────────────────────
OLD_PIDS=$(pgrep -f "/atoms_habits" 2>/dev/null || true)
if [ -n "$OLD_PIDS" ]; then
    log_info "停止旧进程…"
    echo "$OLD_PIDS" | xargs kill 2>/dev/null || true
    sleep 1
    # 确保都死了
    echo "$OLD_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
fi
# 释放 CliBridge 端口
fuser -k 9999/tcp 2>/dev/null || true
sleep 1

# ── 4. 启动 ──────────────────────────────────────────────
log_info "启动 Atoms…"

cd "$(dirname "$BIN")"
nohup env LIBGL_ALWAYS_SOFTWARE=true GALLIUM_DRIVER=llvmpipe \
    ./atoms_habits </dev/null &>/dev/null &

ATOMS_PID=$!
sleep 2

if kill -0 "$ATOMS_PID" 2>/dev/null; then
    log_info "Atoms 已启动 (PID $ATOMS_PID)"
    log_info "在 VNC 桌面中应该能看到窗口了"
else
    log_error "启动失败"
    exit 1
fi
