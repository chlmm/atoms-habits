#!/usr/bin/env bash
# ============================================================
# Atoms App 停止脚本
# 仅停止 Flutter 程序，不动 VNC
# 用法: ./scripts/stop_atoms.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

STOPPED=0

# ── 1. 停止 atoms 二进制 ─────────────────────────────────
ATOMS_PID=$(pgrep -f "intermediates_do_not_run/atoms" 2>/dev/null || pgrep -x atoms 2>/dev/null || true)
if [ -n "$ATOMS_PID" ]; then
    log_info "停止 Atoms (PID $ATOMS_PID)…"
    kill -TERM "$ATOMS_PID" 2>/dev/null || true
    sleep 1
    if kill -0 "$ATOMS_PID" 2>/dev/null; then
        log_warn "优雅退出失败，强制终止…"
        kill -KILL "$ATOMS_PID" 2>/dev/null || true
    fi
    STOPPED=1
fi

# ── 2. 停止 flutter run 进程 ─────────────────────────────
FLUTTER_PID=$(pgrep -f "flutter_tools.*run" 2>/dev/null || true)
if [ -n "$FLUTTER_PID" ]; then
    log_info "停止 flutter run (PID $FLUTTER_PID)…"
    kill -TERM "$FLUTTER_PID" 2>/dev/null || true
    sleep 1
    kill -KILL "$FLUTTER_PID" 2>/dev/null || true
    STOPPED=1
fi

# ── 3. 停止残留 dart 进程 ────────────────────────────────
DART_PIDS=$(pgrep -f "dart.*atoms" 2>/dev/null || true)
if [ -n "$DART_PIDS" ]; then
    log_info "停止残留 Dart 进程…"
    echo "$DART_PIDS" | xargs kill -TERM 2>/dev/null || true
    sleep 1
    echo "$DART_PIDS" | xargs kill -KILL 2>/dev/null || true
    STOPPED=1
fi

echo ""
if [ $STOPPED -eq 1 ]; then
    log_info "Atoms 已停止"
else
    log_warn "没有找到运行中的 Atoms 进程"
fi

# VNC 和 openbox 不受影响，继续保持运行
log_info "VNC 仍在运行，桌面保持可用"
