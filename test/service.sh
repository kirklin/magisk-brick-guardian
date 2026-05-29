#!/system/bin/sh
# ⚠️ 测试用变砖模块 - 模拟 reboot 循环
# 用于测试 Brick Guardian 的自动救砖功能
#
# 原理：在 late_start service 阶段等待 10 秒后执行 reboot，
# 模拟一个"导致手机反复重启"的问题模块。
#
# Brick Guardian 的防护时间线：
#   post-fs-data 阶段 → early.sh 记录启动计数（每次+1）
#   late_start 阶段   → 本模块在 10 秒后 reboot
#   early.sh case 3)  → 第3次启动时禁用所有模块
#
# 预期结果：
#   第1次启动 → 启动计数=1，10秒后被本模块 reboot
#   第2次启动 → 启动计数=2，10秒后被本模块 reboot
#   第3次启动 → 启动计数=3，Brick Guardian 禁用所有模块（包括本模块）→ reboot
#   第4次启动 → 本模块已被禁用，系统正常启动 ✅

MODDIR=${0%/*}
LOG="$MODDIR/test_brick.log"

echo "=== Test Brick Module ===" >> "$LOG"
echo "$(date): service.sh started, will reboot in 10 seconds..." >> "$LOG"

# 等 10 秒后 reboot（给 Brick Guardian 的 early.sh 足够时间先运行）
sleep 10

echo "$(date): executing reboot now!" >> "$LOG"
sync

reboot
