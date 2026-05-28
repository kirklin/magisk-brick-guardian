#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# This module is part of Brick Guardian
# Version: 260529
#
# post-fs-data 阶段入口脚本
# 处理 Magisk modules_update 目录，然后 source 早期救砖脚本

# 加载公共函数库
MODDIR=${0%/*}
. "$MODDIR/common.sh"
setup_path

# 模块基础配置
BG_LOG_FILE=$MODDIR/post_fs_data.log

# 处理modules_update目录（仅 Magisk 环境使用）
# Magisk 在 modules_update 中暂存待更新的模块
# 我们先备份它以防止更新导致变砖
handle_modules_update() {
    if [ -d "/data/adb/modules_update" ]; then
        bg_log_info "检测到modules_update目录，准备备份..."
        if mv -f /data/adb/modules_update /data/adb/modules_update.bak; then
            bg_log_info "modules_update目录备份成功"
            sync
            return 0
        else
            bg_log_error "modules_update目录备份失败"
            return 1
        fi
    fi
    return 0
}

# 处理modules_update.bak目录（仅 Magisk 环境使用）
# 在下次启动时把备份的模块逐个移到 modules/ 下
# 返回 0 = 无需重启, 返回 1 = 已处理需要重启
handle_modules_update_bak() {
    if [ ! -d "/data/adb/modules_update.bak" ]; then
        return 0
    fi

    bg_log_info "检测到modules_update.bak目录，准备处理..."

    if [ ! -d "/data/adb/modules" ]; then
        mkdir -p /data/adb/modules
        chmod 755 /data/adb/modules
    fi

    for module_dir in /data/adb/modules_update.bak/*; do
        [ -d "$module_dir" ] || continue
        local module_name=$(basename "$module_dir")
        bg_log_info "处理模块: $module_name"

        if [ -d "/data/adb/modules/$module_name" ]; then
            rm -rf "/data/adb/modules/$module_name"
        fi

        if mv -f "$module_dir" "/data/adb/modules/"; then
            bg_log_info "模块 $module_name 更新成功"
        else
            bg_log_error "模块 $module_name 更新失败"
        fi
    done

    rm -rf /data/adb/modules_update.bak
    sync

    # 返回 1 表示已处理，需要重启
    return 1
}

# 主函数
main() {
    bg_log_info "=== Brick Guardian Post-fs-data Started ==="
    bg_log_info "当前目录: $MODDIR"
    bg_log_info "Root 管理器: $ROOT_MANAGER ($ROOT_VER)"

    # modules_update 是 Magisk 特有的模块更新机制
    # KernelSU 和 APatch 使用 OverlayFS，不使用此目录
    if is_magisk; then
        if handle_modules_update; then
            bg_log_info "modules_update处理完成"
        else
            bg_log_error "modules_update处理失败"
        fi

        if handle_modules_update_bak; then
            bg_log_info "modules_update.bak处理完成，无需重启"
        else
            bg_log_info "modules_update.bak处理完成，准备重启..."
            sync
            reboot
            exit 0
        fi
    else
        bg_log_info "非 Magisk 环境，跳过 modules_update 处理"
    fi

    # 确保modules目录存在
    if [ ! -d "/data/adb/modules" ]; then
        bg_log_info "创建modules目录..."
        if ! mkdir -p /data/adb/modules || ! chmod 755 /data/adb/modules; then
            bg_log_error "modules目录创建失败，退出"
            exit 1
        fi
    fi

    # source 早期救砖脚本（不是用 sh 启动子进程）
    # 这样可以继承当前 shell 的所有环境变量（ROOT_MANAGER 等）
    local RESCUE_SCRIPT=$MODDIR/brick_guardian_early.sh
    if check_script "$RESCUE_SCRIPT"; then
        bg_log_info "执行早期救砖脚本..."
        . "$RESCUE_SCRIPT"
    else
        bg_log_error "救砖脚本检查失败"
        exit 1
    fi

    bg_log_info "=== Post-fs-data execution completed ==="
}

# 执行主函数
main
