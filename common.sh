#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# Brick Guardian - 公共函数库
# Version: 260529
# 被所有模块脚本 source 使用

# 检测当前 Root 管理器
# 基于官方文档的环境变量：
#   KernelSU: $KSU=true (kernelsu.org)
#   APatch:   $APATCH=true (apatch.dev)
#   Magisk:   检查 /data/adb/magisk 目录
detect_root_manager() {
    if [ "$KSU" = "true" ]; then
        ROOT_MANAGER="KernelSU"
        ROOT_VER="${KSU_VER:-unknown}"
        ROOT_VER_CODE="${KSU_VER_CODE:-0}"
        BUSYBOX_PATH="/data/adb/ksu/bin/busybox"
    elif [ "$APATCH" = "true" ]; then
        ROOT_MANAGER="APatch"
        ROOT_VER="${APATCH_VER:-unknown}"
        ROOT_VER_CODE="${APATCH_VER_CODE:-0}"
        BUSYBOX_PATH="/data/adb/ap/bin/busybox"
    elif [ -d "/data/adb/magisk" ]; then
        ROOT_MANAGER="Magisk"
        ROOT_VER="$(magisk -v 2>/dev/null || echo 'unknown')"
        ROOT_VER_CODE="$(magisk -V 2>/dev/null || echo '0')"
        BUSYBOX_PATH="/data/adb/magisk/busybox"
    else
        ROOT_MANAGER="Unknown"
        ROOT_VER="unknown"
        ROOT_VER_CODE="0"
        BUSYBOX_PATH=""
    fi
}

# 设置 PATH，包含检测到的 BusyBox 路径
setup_path() {
    detect_root_manager
    local base_path="/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin"
    if [ -n "$BUSYBOX_PATH" ] && [ -f "$BUSYBOX_PATH" ]; then
        export PATH="${base_path}:$(dirname "$BUSYBOX_PATH")"
    else
        export PATH="$base_path"
    fi
}

# 检查是否为 Magisk 环境（用于 Magisk 特有逻辑）
is_magisk() {
    [ "$ROOT_MANAGER" = "Magisk" ]
}

# 检查是否为 KernelSU 环境（含 KSU Next）
is_kernelsu() {
    [ "$ROOT_MANAGER" = "KernelSU" ]
}

# 检查是否为 APatch 环境
is_apatch() {
    [ "$ROOT_MANAGER" = "APatch" ]
}

# 禁用所有脚本目录中的脚本（兼容所有管理器）
disable_script_dirs() {
    # Magisk / KSU / APatch 共有
    chmod 000 /data/adb/service.d/* 2>/dev/null
    chmod 000 /data/adb/post-fs-data.d/* 2>/dev/null
    # KernelSU / APatch 额外支持的目录
    chmod 000 /data/adb/post-mount.d/* 2>/dev/null
    chmod 000 /data/adb/boot-completed.d/* 2>/dev/null
}

# ==================== 日志函数 ====================

# 初始化日志（调用方需先设置 BG_LOG_FILE 变量）
# 用法：BG_LOG_FILE=$MODDIR/xxx.log
bg_log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1" >> "$BG_LOG_FILE"
}

bg_log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$BG_LOG_FILE"
}

bg_log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$BG_LOG_FILE"
}

bg_log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$BG_LOG_FILE"
}

# ==================== 安全文件 I/O ====================

# 安全写入文件（原子写入：先写临时文件再 mv）
# 用法：safe_write "/path/to/file" "content"
safe_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp"

    mkdir -p "$(dirname "$file")" 2>/dev/null

    if ! echo "$content" > "$temp_file"; then
        bg_log_error "写入临时文件失败: $temp_file"
        rm -f "$temp_file"
        return 1
    fi

    chmod 644 "$temp_file"

    if ! mv -f "$temp_file" "$file"; then
        bg_log_error "移动文件失败: $temp_file -> $file"
        rm -f "$temp_file"
        return 1
    fi

    sync
    return 0
}

# 安全读取数字文件
# 用法：count=$(safe_read "/path/to/file" "default_value")
safe_read() {
    local file="$1"
    local default="$2"
    local content

    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        echo "$default"
        return 0
    fi

    content=$(cat "$file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        bg_log_error "读取文件失败: $file"
        echo "$default"
        return 1
    fi

    if ! echo "$content" | grep -q '^[0-9][0-9]*$'; then
        bg_log_error "文件内容无效(非数字): $file (content: $content)"
        echo "$default"
        return 1
    fi

    echo "$content"
    return 0
}

# ==================== 模块操作 ====================

# 禁用所有模块（跳过自身，然后恢复白名单）
# 需要调用方已设置: MODID, WHITELIST_FILE
disable_all_modules() {
    local caller_stage="${1:-unknown}"
    bg_log_info "开始禁用模块操作（${caller_stage}阶段）..."
    local module
    local disabled_count=0
    local success=0

    if [ ! -d "/data/adb/modules" ]; then
        bg_log_error "modules目录不存在"
        return 1
    fi

    for module_dir in /data/adb/modules/*; do
        [ -d "$module_dir" ] || continue
        module=$(basename "$module_dir")

        if [ "$module" = "$MODID" ]; then
            bg_log_debug "跳过当前模块: $module"
            continue
        fi

        if touch "/data/adb/modules/$module/disable" 2>/dev/null; then
            bg_log_info "已禁用模块: $module"
            disabled_count=$((disabled_count + 1))
        else
            bg_log_error "无法禁用模块: $module"
            success=1
        fi
    done

    bg_log_info "模块禁用操作完成，共禁用 $disabled_count 个模块"

    if ! handle_whitelist; then
        success=1
    fi

    sync
    if [ $success -eq 0 ]; then
        bg_log_info "准备重启系统..."
        reboot
    else
        bg_log_error "模块禁用过程中出现错误，尝试强制重启..."
        reboot -f
    fi
}

# 处理白名单：将白名单中的模块重新启用
# 需要调用方已设置: WHITELIST_FILE
handle_whitelist() {
    bg_log_info "开始处理白名单..."
    if [ ! -f "$WHITELIST_FILE" ]; then
        bg_log_warning "白名单文件不存在"
        return 0
    fi

    local enabled_count=0
    local success=0
    local module
    local temp_whitelist="${WHITELIST_FILE}.tmp"

    if ! sed '/^[[:space:]]*$/d;/^#/d' "$WHITELIST_FILE" > "$temp_whitelist"; then
        bg_log_error "处理白名单文件失败"
        rm -f "$temp_whitelist"
        return 1
    fi

    while read module; do
        if [ -d "/data/adb/modules/$module" ]; then
            if rm -f "/data/adb/modules/$module/disable" 2>/dev/null; then
                bg_log_info "已启用白名单模块: $module"
                enabled_count=$((enabled_count + 1))
            else
                bg_log_error "无法启用白名单模块: $module"
                success=1
            fi
        else
            bg_log_warning "白名单模块不存在: $module"
        fi
    done < "$temp_whitelist"

    rm -f "$temp_whitelist"
    bg_log_info "白名单处理完成，共启用 $enabled_count 个模块"
    return $success
}

# 更新救砖统计
# 需要调用方已设置: RESCUE_LOG
update_rescue_stats() {
    bg_log_info "更新救砖统计..."
    local count=1

    if [ -f "$RESCUE_LOG" ]; then
        count=$(safe_read "$RESCUE_LOG" "0")
        count=$((count + 1))
    fi

    if ! safe_write "$RESCUE_LOG" "$count"; then
        bg_log_error "更新救砖统计失败"
        return 1
    fi

    bg_log_info "当前救砖次数: $count"
    return 0
}

# 仅禁用嫌疑模块（精准救砖）
# 检测新增/新启用的模块并仅禁用它们
# 返回 0 = 成功执行了精准禁用, 返回 1 = 无法识别嫌疑人（需 fallback 全禁用）
# 需要调用方已设置: MODDIR, MODID, WHITELIST_FILE
disable_suspect_only() {
    local suspect_log="$MODDIR/suspect_modules.log"

    detect_suspect_modules

    if [ ! -f "$suspect_log" ]; then
        bg_log_warning "嫌疑模块检测失败"
        return 1
    fi

    # 读取确定的嫌疑人（不含 ? 前缀和 unknown）
    local suspects
    suspects=$(grep -v '^?' "$suspect_log" | grep -v '^unknown$' 2>/dev/null)

    if [ -z "$suspects" ]; then
        bg_log_info "未识别到明确嫌疑模块，需要全部禁用"
        return 1
    fi

    local disabled_count=0
    echo "$suspects" | while read module; do
        [ -z "$module" ] && continue
        if [ -d "/data/adb/modules/$module" ]; then
            if touch "/data/adb/modules/$module/disable" 2>/dev/null; then
                bg_log_info "已精准禁用嫌疑模块: $module"
                disabled_count=$((disabled_count + 1))
            else
                bg_log_error "无法禁用嫌疑模块: $module"
            fi
        fi
    done

    bg_log_info "精准禁用完成，共禁用嫌疑模块"
    sync
    bg_log_info "准备重启系统（精准救砖）..."
    reboot
    return 0
}

# ==================== 嫌疑模块追踪 ====================

# 保存当前模块列表为"已知正常"（每次成功开机后调用）
# 需要调用方已设置: MODDIR
save_good_modules() {
    local good_list="$MODDIR/good_modules.list"
    bg_log_info "保存已知正常模块列表..."

    if [ ! -d "/data/adb/modules" ]; then
        bg_log_warning "modules目录不存在，跳过保存"
        return 1
    fi

    # 列出所有已启用的模块ID（排除被禁用的）
    local temp_list="${good_list}.tmp"
    rm -f "$temp_list"
    for module_dir in /data/adb/modules/*; do
        [ -d "$module_dir" ] || continue
        [ -f "$module_dir/disable" ] && continue
        basename "$module_dir" >> "$temp_list"
    done

    if [ -f "$temp_list" ]; then
        mv -f "$temp_list" "$good_list"
        sync
        local count
        count=$(wc -l < "$good_list" | tr -d ' ')
        bg_log_info "已保存 $count 个正常模块"
    else
        # 没有模块，写空文件
        > "$good_list"
        sync
        bg_log_info "已保存空模块列表"
    fi
    return 0
}

# 检测嫌疑模块：对比当前模块列表和上次成功启动时的列表
# 结果写入 $MODDIR/suspect_modules.log
# 需要调用方已设置: MODDIR, MODID
detect_suspect_modules() {
    local good_list="$MODDIR/good_modules.list"
    local suspect_log="$MODDIR/suspect_modules.log"
    bg_log_info "开始检测嫌疑模块..."

    rm -f "$suspect_log"

    if [ ! -f "$good_list" ]; then
        bg_log_warning "无历史模块列表，无法对比（首次救砖）"
        echo "unknown" > "$suspect_log"
        return 1
    fi

    local suspect_count=0
    for module_dir in /data/adb/modules/*; do
        [ -d "$module_dir" ] || continue
        local module
        module=$(basename "$module_dir")
        [ "$module" = "$MODID" ] && continue

        # 如果模块不在 good_list 里，它就是嫌疑人
        if ! grep -qx "$module" "$good_list"; then
            bg_log_warning "🔍 嫌疑模块（新增）: $module"
            echo "$module" >> "$suspect_log"
            suspect_count=$((suspect_count + 1))
        fi
    done

    if [ $suspect_count -eq 0 ]; then
        bg_log_info "未检测到新增模块，可能是已有模块更新导致"
        # 列出所有非自身模块作为参考
        for module_dir in /data/adb/modules/*; do
            [ -d "$module_dir" ] || continue
            local module
            module=$(basename "$module_dir")
            [ "$module" = "$MODID" ] && continue
            echo "?$module" >> "$suspect_log"
        done
        bg_log_info "已将所有模块列为参考（带 ? 前缀）"
    else
        bg_log_info "共检测到 $suspect_count 个嫌疑模块"
    fi

    return 0
}

# ==================== 脚本检查 ====================

# 检查脚本文件是否存在、可执行、非空
check_script() {
    local script=$1
    bg_log_info "检查脚本: $script"

    if [ ! -f "$script" ]; then
        bg_log_error "脚本文件不存在: $script"
        return 1
    fi

    if [ ! -x "$script" ]; then
        bg_log_warning "脚本没有执行权限，尝试添加: $script"
        chmod 755 "$script"
        if [ ! -x "$script" ]; then
            bg_log_error "无法设置脚本执行权限: $script"
            return 1
        fi
    fi

    if [ ! -s "$script" ]; then
        bg_log_error "脚本文件为空: $script"
        return 1
    fi

    bg_log_info "脚本检查通过: $script"
    return 0
}
