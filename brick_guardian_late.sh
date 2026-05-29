#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# This module is part of Brick Guardian
# Version: 260529
#
# 后期救砖脚本 - 在 late_start service 阶段被 source 执行
# 等待系统启动完成，检查 bootanim 状态来判断是否启动成功

# 模块基础配置（MODDIR 和 common.sh 已由调用方 service.sh 加载）
MODID=${MODDIR##*/}
MODULE_INFO=$MODDIR/module.prop
START_LOG=$MODDIR/startup_count.log
RESCUE_LOG=$MODDIR/rescue_count.log
VERSION_FILE=$MODDIR/now_version
WHITELIST_FILE=$MODDIR/白名单.conf
BOOT_WAIT_TIME=1.5
BG_LOG_FILE_SAVED="$BG_LOG_FILE"
BG_LOG_FILE=$MODDIR/brick_guardian_late_debug.log

# 更新模块描述（显示救砖次数和嫌疑模块）
update_module_description() {
    local rescue_count=$1
    bg_log_info "更新模块描述，当前救砖次数: $rescue_count"

    # 读取嫌疑模块信息
    local suspect_info=""
    local suspect_log="$MODDIR/suspect_modules.log"
    if [ -f "$suspect_log" ]; then
        local suspects
        # 过滤 ? 前缀（仅显示确定的嫌疑人）
        suspects=$(grep -v '^?' "$suspect_log" | grep -v '^unknown$' | tr '\n' ',' | sed 's/,$//')
        if [ -n "$suspects" ]; then
            suspect_info=" 上次救砖嫌疑模块: ${suspects}。"
        fi
    fi

    local description="渐进式救砖：第3次重启精准禁用嫌疑模块→第5次禁用全部模块→卡开机界面${BOOT_WAIT_TIME}分钟也会触发救砖(OTA后延长至15分钟)→第7次执行APP解冻。模块目录/白名单.conf可添加跳过白名单。GitHub: https://github.com/kirklin/magisk-brick-guardian 已为您自动救砖：${rescue_count}次。${suspect_info}"

    local temp_file="${MODULE_INFO}.tmp"
    if ! sed "/^description=/c description=$description" "$MODULE_INFO" > "$temp_file"; then
        bg_log_error "生成新的模块描述失败"
        rm -f "$temp_file"
        return 1
    fi

    if ! mv -f "$temp_file" "$MODULE_INFO"; then
        bg_log_error "更新模块描述失败"
        rm -f "$temp_file"
        return 1
    fi

    sync
    bg_log_info "模块描述更新成功"
    return 0
}

# 后期救砖主逻辑
late_main() {
    bg_log_info "=== Brick Guardian Late Script Started ==="
    bg_log_info "当前目录: $MODDIR"
    bg_log_info "Root 管理器: $ROOT_MANAGER ($ROOT_VER)"

    # 恢复模块信息备份
    if [ -f "${MODULE_INFO}.bak" ]; then
        bg_log_info "正在恢复模块信息备份..."
        if mv -f "${MODULE_INFO}.bak" "$MODULE_INFO"; then
            bg_log_info "模块信息备份恢复成功"
            sync
        else
            bg_log_error "模块信息备份恢复失败"
        fi
    fi

    # 等待系统启动
    bg_log_info "等待系统启动 ${BOOT_WAIT_TIME} 分钟..."
    sleep "${BOOT_WAIT_TIME}m"

    # 检查系统是否成功启动
    local boot_status=$(getprop init.svc.bootanim)
    bg_log_info "系统启动状态: $boot_status"

    if [ "$boot_status" = "stopped" ]; then
        # 系统已正常启动
        bg_log_info "系统已正常启动"

        rm -f "$START_LOG" 2>/dev/null
        bg_log_info "已清除启动计数"
        sync

        # 更新救砖统计和描述
        if [ -f "$RESCUE_LOG" ]; then
            local rescue_count
            rescue_count=$(safe_read "$RESCUE_LOG" "0")
            bg_log_info "读取到救砖统计: $rescue_count"
            update_module_description "$rescue_count"
        else
            bg_log_info "未找到救砖统计文件"
        fi

        # 更新系统版本记录
        local current_version
        current_version=$(getprop ro.system.build.version.incremental)
        if ! safe_write "$VERSION_FILE" "$current_version"; then
            bg_log_error "更新系统版本记录失败"
        else
            bg_log_info "系统版本记录已更新: $current_version"
        fi

        # 保存当前模块列表为"已知正常"
        save_good_modules
    else
        # 系统未能正常启动
        bg_log_warning "系统未能正常启动，准备执行救砖操作"
        detect_suspect_modules
        update_rescue_stats
        disable_all_modules "后期"
    fi

    bg_log_info "=== Late Script execution completed ==="
}

# 执行后期救砖逻辑
late_main

# 恢复调用方的日志文件路径
BG_LOG_FILE="$BG_LOG_FILE_SAVED"
