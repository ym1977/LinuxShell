#!/usr/bin/env bash

# switch2gl.sh —— 从局部放电检测(A) 切换到 气体泄漏检测(B)，全程带可视进度与结果提示
# 依赖 zenity（无则自动降级为 notify-send）。后端以 systemd 服务方式启停。

set -u

# ===================== 配置区：按你的环境修改 =====================
# 变量USE_SYSTEMCTL为后端启停方式：
# (1) true  : 用 systemctl（需桌面用户有管理这两个服务的权限）；
# (2) false : 直接调用内部脚本（填下方脚本绝对路径）
#
USE_SYSTEMCTL=true
PD_SERVICE="pddevice.service"     # A 后台 systemd 服务（已开机自启）
GL_SERVICE="gldevice.service"     # B 后台 systemd 服务（未开机自启）

# 仅当 USE_SYSTEMCTL=false 时使用（可用 readlink -f ~/Desktop/jf_stop.sh 查真实路径）
JF_STOP_SCRIPT="/opt/pd/jf_stop.sh"
GL_START_SCRIPT="/opt/gl/gl_start.sh"

GL_UI_SCRIPT="/opt/gl/gl_ui.sh"   # B 前台启动脚本（必须直接跑，非服务）—— 填真实绝对路径

# 进程关键字（用于确认/等待，建议用二进制名，足够唯一）
JF_UI_PROC="jf_ui"                # A 前台 Qt 应用
JF_BACKEND="jf_recv jf_alg jf_save"   # A 后台应用（确认已停）
GL_BACKEND="gl_recv gl_alg gl_save"   # B 后台应用（确认已起）
GL_ALG_PROC="gl_alg"              # B 就绪主判据
GL_UI_PROC="gl_ui"                # B 前台 Qt 应用

MAX_WAIT=45                       # 等待 gl_alg 就绪的最大秒数（你原等 30s，放宽到 45）
LOG="/var/log/switch_to_gl.log"
# =================================================================

log() { echo "[$(date '+%F %T')] $*" >>"$LOG" 2>&1; }

proc_up()   { pgrep -f "$1" >/dev/null 2>&1; }
proc_down() { ! proc_up "$1"; }

stop_pd() {
    if [ "$USE_SYSTEMCTL" = true ]; then
        if systemctl is-active --quiet "$PD_SERVICE"; then
            systemctl stop "$PD_SERVICE" 2>>"$LOG" && log "$PD_SERVICE 已停止" || log "$PD_SERVICE 停止失败"
        else
            log "$PD_SERVICE 未运行，跳过"
        fi
    else
        bash "$JF_STOP_SCRIPT" >>"$LOG" 2>&1 && log "jf_stop.sh 执行完成" || log "jf_stop.sh 执行异常"
    fi
}

start_gl() {
    if [ "$USE_SYSTEMCTL" = true ]; then
        if systemctl is-active --quiet "$GL_SERVICE"; then
            log "$GL_SERVICE 已在运行"
        else
            systemctl start "$GL_SERVICE" 2>>"$LOG" && log "$GL_SERVICE 已启动" || log "$GL_SERVICE 启动失败"
        fi
    else
        bash "$GL_START_SCRIPT" >>"$LOG" 2>&1 && log "gl_start.sh 执行完成" || log "gl_start.sh 执行异常"
    fi
}

wait_proc() {                     # 等待 $1 进程出现，最多 MAX_WAIT 秒
    local p="$1" i=0
    while [ "$i" -lt "$MAX_WAIT" ]; do
        proc_up "$p" && return 0
        sleep 1; i=$((i+1))
    done
    return 1
}

# ---------- 切换前：确认 jf_ui 已关闭（避免强杀未保存状态） ----------
if proc_up "$JF_UI_PROC"; then
    if command -v zenity >/dev/null 2>&1; then
        zenity --question --title="切换确认" \
            --text="检测到局部放电前台(jf_ui)仍在运行，是否先关闭它再切换？\n（建议先手动点右上角 X 关闭）" 2>/dev/null
        if [ $? -eq 0 ]; then
            pkill -f "$JF_UI_PROC" 2>/dev/null && log "已关闭 jf_ui" || log "关闭 jf_ui 失败"
            sleep 1
        else
            zenity --info --text="已取消切换。" 2>/dev/null
            exit 0
        fi
    else
        pkill -f "$JF_UI_PROC" 2>/dev/null && log "已关闭 jf_ui（无图形界面，直接关闭）"
        sleep 1
    fi
fi

# ---------- 主流程（进度条）；log 只写文件，避免污染 zenity 管道 ----------
run_steps() {
    echo "10";  echo "# 正在停止局部放电后台($PD_SERVICE)…"
    stop_pd
    sleep 2
    # 兜底：若 A 后台仍有残留，强制结束（权限允许时）
    for p in $JF_BACKEND; do
        if proc_up "$p"; then pkill -9 -f "$p" 2>/dev/null; log "强制结束残留 $p"; fi
    done

    echo "35";  echo "# 正在启动气体泄漏后台($GL_SERVICE)…"
    start_gl

    echo "60";  echo "# 等待 gl_alg 就绪（最多 ${MAX_WAIT}s）…"
    if wait_proc "$GL_ALG_PROC"; then
        echo "85"; echo "# gl_alg 已就绪，正在启动气体泄漏前台(gl_ui)…"
        if [ -x "$GL_UI_SCRIPT" ]; then bash "$GL_UI_SCRIPT"; else log "警告：gl_ui.sh 不可执行：$GL_UI_SCRIPT"; fi
        sleep 2
        if proc_up "$GL_UI_PROC"; then
            echo "100"; echo "# 切换完成"
        else
            echo "100"; echo "# 警告：gl_ui.sh 已执行但未检测到 gl_ui"
        fi
    else
        echo "100"; echo "# 错误：gl_alg 在 ${MAX_WAIT}s 内未就绪"
    fi
}

if command -v zenity >/dev/null 2>&1; then
    run_steps | zenity --progress \
        --title="系统切换：局部放电 → 气体泄漏" \
        --text="准备中…" \
        --percentage=0 \
        --auto-close --no-cancel 2>/dev/null
else
    run_steps >/dev/null
fi

# ---------- 终态提示：直接查实际状态，不依赖管道退出码 ----------
GL_UI_OK=$(proc_up "$GL_UI_PROC" && echo yes || echo no)
GL_BE_OK=yes
for p in $GL_BACKEND; do proc_up "$p" || GL_BE_OK=no; done

if [ "$GL_UI_OK" = yes ] && [ "$GL_BE_OK" = yes ]; then
    if command -v zenity >/dev/null 2>&1; then
        zenity --info --title="切换完成" --text="气体泄漏检测(B) 已成功运行：\n• 后台 gl_recv/gl_alg/gl_save 在线\n• 前台 gl_ui 已启动" 2>/dev/null
    else
        notify-send "系统切换" "气体泄漏检测(B) 已成功运行" 2>/dev/null
    fi
    log "切换成功：gl_ui 与后台均在线"
else
    MSG="气体泄漏检测(B) 未完全就绪：\n• 前台 gl_ui：$GL_UI_OK\n• 后台($GL_BACKEND)：$GL_BE_OK\n请查看日志 $LOG"
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="切换未完成" --text="$MSG" 2>/dev/null
    else
        notify-send -u critical "系统切换失败" "详见 $LOG" 2>/dev/null
    fi
    log "切换失败：gl_ui=$GL_UI_OK 后台=$GL_BE_OK"
fi

