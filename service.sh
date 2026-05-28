#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# This module is part of Brick Guardian
# Version: 260529
#
# late_start service 阶段入口脚本
# 检查 OTA 升级，然后 source 后期救砖脚本

# 模块基础配置
MODDIR=${0%/*}

# 加载公共函数库
. "$MODDIR/common.sh"
setup_path

# 配置文件路径
VERSION_FILE=$MODDIR/now_version
BG_LOG_FILE=$MODDIR/brick_guardian.log

# OTA升级后等待时间（分钟）
OTA_WAIT_TIME=15

# 检查系统版本变化
check_system_version() {
    if [ ! -f "$VERSION_FILE" ]; then
        bg_log_warning "版本文件不存在，可能是首次运行"
        return 1
    fi

    local prev_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    local curr_version=$(getprop ro.system.build.version.incremental)

    bg_log_info "Previous system version: $prev_version"
    bg_log_info "Current system version: $curr_version"

    if [ "$prev_version" != "$curr_version" ]; then
        bg_log_warning "检测到系统升级，等待 $OTA_WAIT_TIME 分钟..."
        sleep "${OTA_WAIT_TIME}m"
        bg_log_info "OTA等待期结束"
        return 0
    fi
    return 1
}

# 主函数
main() {
    bg_log_info "=== Brick Guardian Service Started ==="
    bg_log_info "当前目录: $MODDIR"
    bg_log_info "Root 管理器: $ROOT_MANAGER ($ROOT_VER)"
    bg_log_info "Android: $(getprop ro.build.version.release) | SDK: $(getprop ro.build.version.sdk) | Device: $(getprop ro.product.model)"

    # 检查系统版本
    bg_log_info "检查系统版本..."
    if check_system_version; then
        bg_log_info "系统版本检查完成，继续执行..."
    fi

    # source 后期救砖脚本（不是用 sh 启动子进程）
    local RESCUE_SCRIPT=$MODDIR/brick_guardian_late.sh
    if check_script "$RESCUE_SCRIPT"; then
        bg_log_info "执行后期救砖脚本..."
        . "$RESCUE_SCRIPT"
    else
        bg_log_error "救砖脚本检查失败"
        exit 1
    fi

    bg_log_info "=== Service execution completed ==="
}

# 执行主函数
main
