#!/usr/bin/env bash
# ============================================================
# Atoms VNC 推流 — 启动 VNC 桌面并输出访问地址
# 用法:
#   ./vnc_push.sh               # 桌面模式 1280x720
#   ./vnc_push.sh --phone       # 手机模式 390x844
#   ./vnc_push.sh --web-phone   # 手机Web模式 320x693 (浏览器占用补偿)
# ============================================================

set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-1}"
VNC_DEPTH="${VNC_DEPTH:-24}"
VNC_PORT=$((5900 + DISPLAY_NUM))

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 分辨率 ───────────────────────────────────────────────
case "${1:-}" in
    --web-phone)
        VNC_GEOMETRY="320x693"
        MODE_LABEL="手机Web模式"
        ;;
    --phone)
        VNC_GEOMETRY="390x844"
        MODE_LABEL="手机模式"
        ;;
    *)
        VNC_GEOMETRY="${VNC_GEOMETRY:-1280x720}"
        MODE_LABEL="桌面模式"
        ;;
esac

# ── 获取本机 IP ──────────────────────────────────────────
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "127.0.0.1")
fi

echo ""
echo "======================================"
echo "  Atoms VNC 远程桌面"
echo "  ${MODE_LABEL} | ${VNC_GEOMETRY}"
echo "======================================"
echo ""

# ── 清理旧进程 ───────────────────────────────────────────
if pgrep -f "Xtigervnc.*:${DISPLAY_NUM}" > /dev/null 2>&1; then
    log_info "停止旧的 VNC :${DISPLAY_NUM}…"
    vncserver -kill ":${DISPLAY_NUM}" 2>/dev/null || true
    sleep 1
fi

# ── 启动 VNC (无密码) ────────────────────────────────────
log_info "启动 VNC (${MODE_LABEL}, ${VNC_GEOMETRY}, 无密码)…"
vncserver ":${DISPLAY_NUM}" \
    -localhost no \
    -geometry "${VNC_GEOMETRY}" \
    -depth "${VNC_DEPTH}" \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE \
    > /tmp/atoms_vnc.log 2>&1

sleep 2

if ! pgrep -f "Xtigervnc.*:${DISPLAY_NUM}" > /dev/null 2>&1; then
    log_error "VNC 启动失败，查看: /tmp/atoms_vnc.log"
    exit 1
fi
log_info "VNC 桌面已就绪 → :${DISPLAY_NUM} (端口 ${VNC_PORT})"

# ── 输出访问方式 ─────────────────────────────────────────
echo ""
echo "======================================"
echo "  访问方式"
echo "======================================"
echo ""
echo "  VNC 客户端:"
echo "    地址: ${HOST_IP}:${VNC_PORT}"
echo "    密码: 无（直连）"
echo ""
echo "  停止:    ./scripts/stop_atoms.sh"
echo "  启动 App: ./scripts/start_atoms.sh"
echo ""
echo "======================================"
echo ""

# 阻塞等待
trap_handler() {
    log_info "正在停止 VNC…"
    vncserver -kill ":${DISPLAY_NUM}" 2>/dev/null || true
    exit 0
}
trap trap_handler INT TERM

log_info "VNC 运行中，按 Ctrl+C 退出…"
wait
