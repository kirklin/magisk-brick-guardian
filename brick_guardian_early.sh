#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# This module is part of Brick Guardian
# Version: 260529
#
# 早期救砖脚本 - 在 post-fs-data 阶段被 source 执行
# 检查启动计数，在连续启动失败时禁用模块或解冻应用

# 模块基础配置（MODDIR 和 common.sh 已由调用方 post-fs-data.sh 加载）
MODID=${MODDIR##*/}
MODULE_INFO=$MODDIR/module.prop
START_LOG=$MODDIR/startup_count.log
RESCUE_LOG=$MODDIR/rescue_count.log
WHITELIST_FILE=$MODDIR/白名单.conf
BG_LOG_FILE_SAVED="$BG_LOG_FILE"
BG_LOG_FILE=$MODDIR/brick_guardian_early_debug.log

# 解冻应用
unfreeze_apps() {
    bg_log_info "开始解冻应用..."

    # 检查文件是否存在
    if [ ! -f "/data/system/users/0/package-restrictions.xml" ]; then
        bg_log_info "应用限制文件不存在，无需解冻"
        return 0
    fi

    # 删除应用限制文件
    if rm -f /data/system/users/0/package-restrictions.xml; then
        bg_log_info "成功删除应用限制文件"
        sync
    else
        bg_log_error "删除应用限制文件失败"
        return 1
    fi

    bg_log_info "应用解冻完成"
    return 0
}

# 早期救砖主逻辑
early_main() {
    bg_log_info "=== Brick Guardian Early Script Started ==="
    bg_log_info "当前目录: $MODDIR"
    bg_log_info "Root 管理器: $ROOT_MANAGER ($ROOT_VER)"

    # 检查启动次数
    local BOOT_COUNT=1

    if [ -f "$START_LOG" ]; then
        BOOT_COUNT=$(safe_read "$START_LOG" "0")
        BOOT_COUNT=$((BOOT_COUNT + 1))
    fi

    if ! safe_write "$START_LOG" "$BOOT_COUNT"; then
        bg_log_error "更新启动次数失败"
        BOOT_COUNT=1
    fi

    bg_log_info "当前启动次数: $BOOT_COUNT"

    # 根据启动次数执行不同操作（渐进式救砖）
    # 第3次: 精准禁用嫌疑模块（新装/新启用的）
    # 第4次: 等待精准禁用生效（disable 文件需下次启动才生效）
    # 第5次: 全部禁用（精准禁用确认未能解决问题）
    # 第7次: 解冻所有APP（最后手段）
    case $BOOT_COUNT in
        3)
            bg_log_warning "第三次启动：尝试精准禁用嫌疑模块"
            update_rescue_stats
            if disable_suspect_only; then
                # 精准禁用成功（已 reboot）
                :
            else
                # 无法识别嫌疑人，直接全部禁用
                bg_log_warning "无法精准定位，升级为全部禁用"
                disable_script_dirs
                disable_all_modules "早期"
            fi
            ;;
        5)
            bg_log_warning "第五次启动：精准禁用未奏效，禁用所有模块"
            disable_script_dirs
            update_rescue_stats
            disable_all_modules "早期"
            ;;
        7)
            bg_log_warning "第七次启动：准备解冻所有应用"
            rm -f "$START_LOG"
            sync
            update_rescue_stats
            if unfreeze_apps; then
                bg_log_info "准备重启系统..."
                reboot
            else
                bg_log_error "解冻失败，尝试强制重启..."
                reboot -f
            fi
            ;;
        *)
            bg_log_info "正常启动，无需特殊处理"
            ;;
    esac

    bg_log_info "=== Early Script execution completed ==="
}

# 执行早期救砖逻辑
early_main

# 恢复调用方的日志文件路径
BG_LOG_FILE="$BG_LOG_FILE_SAVED"
