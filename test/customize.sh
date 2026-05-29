##########################################################################################
#
# Test Brick Module - 安装脚本 (customize.sh)
# ⚠️ 仅用于测试 Brick Guardian 的救砖功能
#
##########################################################################################

# 系统文件替换列表（空，不替换任何系统文件）
REPLACE=""

ui_print "*******************************"
ui_print "   ⚠️ Test Brick Module"
ui_print "   测试用变砖模块 v2.0.0"
ui_print "*******************************"
ui_print " "
ui_print "此模块会在 service.sh 阶段"
ui_print "每次启动后 10 秒触发 reboot"
ui_print "模拟变砖（重启循环）场景"
ui_print " "
ui_print "预期结果："
ui_print "- 手机会重启 2~3 次"
ui_print "- Brick Guardian 在第3次启动时"
ui_print "  自动禁用本模块并恢复正常"
ui_print " "
ui_print "⚠️ 请确保已安装 Brick Guardian！"
ui_print "*******************************"

# 设置权限
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
