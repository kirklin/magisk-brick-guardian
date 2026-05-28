#!/system/bin/sh
# Copyright (C) 2024-2026 Kirk Lin
#
# This module is part of Brick Guardian
# Version: 260529
#
# Action 脚本 - 用户在管理器中点击 Action 按钮时执行

# 模块基础配置
MODDIR=${0%/*}

# 加载公共函数库
. "$MODDIR/common.sh"
setup_path

MODID=${MODDIR##*/}
MODULE_INFO=$MODDIR/module.prop
DEBUG_LOG=$MODDIR/brick_guardian.log
RESCUE_LOG=$MODDIR/rescue_count.log
START_LOG=$MODDIR/startup_count.log
WHITELIST_FILE=$MODDIR/白名单.conf

# 显示模块信息
echo "====================================="
echo "   Brick Guardian 状态信息"
echo "====================================="

# 显示模块版本信息
if [ -f "$MODULE_INFO" ]; then
    name=$(grep "^name=" "$MODULE_INFO" | cut -d= -f2)
    version=$(grep "^version=" "$MODULE_INFO" | cut -d= -f2)
    author=$(grep "^author=" "$MODULE_INFO" | cut -d= -f2)

    echo "模块名称: $name"
    echo "版本: $version"
    echo "作者: $author"
else
    echo "无法读取模块信息！"
fi

echo "-------------------------------------"
echo "模块状态:"

# 检查模块是否启用
if [ -d "/data/adb/modules/$MODID" ] && [ ! -f "/data/adb/modules/$MODID/disable" ]; then
    echo "✓ 模块已启用并正常运行"
else
    echo "✗ 模块已禁用"
fi

# 检查救砖脚本
if [ -f "$MODDIR/brick_guardian_early.sh" ] && [ -f "$MODDIR/brick_guardian_late.sh" ]; then
    echo "✓ 救砖脚本存在"
else
    echo "✗ 救砖脚本缺失"
fi

# 检查公共函数库
if [ -f "$MODDIR/common.sh" ]; then
    echo "✓ 公共函数库存在"
else
    echo "✗ 公共函数库缺失"
fi

# 检查白名单
if [ -f "$WHITELIST_FILE" ]; then
    count=$(grep -v "^#" "$WHITELIST_FILE" | grep -v "^$" | wc -l)
    echo "✓ 白名单存在 ($count 个模块)"
else
    echo "! 白名单不存在"
fi

# 显示救砖统计
if [ -f "$RESCUE_LOG" ]; then
    rescue_count=$(cat "$RESCUE_LOG" 2>/dev/null || echo "0")
    echo "ℹ 已救砖次数: $rescue_count"
else
    echo "ℹ 已救砖次数: 0"
fi

# 显示启动次数
if [ -f "$START_LOG" ]; then
    start_count=$(cat "$START_LOG" 2>/dev/null || echo "0")
    echo "ℹ 启动次数: $start_count"
else
    echo "ℹ 启动次数: 0"
fi

echo "-------------------------------------"
echo "系统信息:"
echo "Android 版本: $(getprop ro.build.version.release)"
echo "SDK 版本: $(getprop ro.build.version.sdk)"
echo "设备型号: $(getprop ro.product.model)"
echo "Root 方案: $ROOT_MANAGER $ROOT_VER"
echo "-------------------------------------"

# 显示最近的日志
if [ -f "$DEBUG_LOG" ]; then
    echo "最近的日志 (最后5行):"
    tail -n 5 "$DEBUG_LOG"
else
    echo "日志文件不存在"
fi

echo "====================================="
echo "  感谢使用 Brick Guardian！"
echo "====================================="

exit 0
