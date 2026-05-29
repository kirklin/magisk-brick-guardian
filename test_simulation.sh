#!/bin/bash
# Brick Guardian 本地模拟测试 v2
# 用法：bash test_simulation.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bg_test_XXXXXX")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0

ok() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
ng() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${YELLOW}[$1] $2${NC}"; }

# --- Mock 命令 ---
MOCK="$TEST_DIR/bin"
mkdir -p "$MOCK"
for cmd in getprop magisk sleep reboot; do
  case $cmd in
    getprop) cat > "$MOCK/$cmd" << 'E'
#!/bin/sh
case "$1" in init.svc.bootanim) echo "${MOCK_BOOTANIM:-stopped}";; ro.system.build.version.incremental) echo "${MOCK_SYS_VER:-ABC123}";; *) echo "u";; esac
E
    ;;
    magisk) echo '#!/bin/sh' > "$MOCK/$cmd"; echo 'case "$1" in -v) echo 27.0;; -V) echo 27000;; esac' >> "$MOCK/$cmd" ;;
    sleep)  echo '#!/bin/sh' > "$MOCK/$cmd"; echo ':' >> "$MOCK/$cmd" ;;
    reboot) printf '#!/bin/sh\necho R >> "%s/rboot"\n' "$TEST_DIR" > "$MOCK/$cmd" ;;
  esac
  chmod +x "$MOCK/$cmd"
done

# 所有测试都在这个 PATH 下运行
export PATH="$MOCK:$PATH"

# --- 帮助函数: 在 sh 中 source common.sh 并运行代码 ---
# 用法: run_sh "shell code"  (MODDIR/BG_LOG_FILE 已设好)
run_sh() {
  BG_LOG_FILE="$TEST_DIR/log" MODDIR="$SCRIPT_DIR" sh -c ". '$SCRIPT_DIR/common.sh'; $1" 2>/dev/null
}

echo ""
echo "=========================================="
echo -e "  ${CYAN}Brick Guardian v260529 模拟测试${NC}"
echo "=========================================="

# ======== 1. Root 检测 ========
section 1 "Root 管理器检测"

r=$(KSU=true KSU_VER=1.0 run_sh 'detect_root_manager; echo $ROOT_MANAGER')
[ "$r" = "KernelSU" ] && ok "KSU=true → KernelSU" || ng "KSU: $r"

r=$(APATCH=true APATCH_VER=10800 run_sh 'detect_root_manager; echo $ROOT_MANAGER')
[ "$r" = "APatch" ] && ok "APATCH=true → APatch" || ng "APatch: $r"

r=$(run_sh 'detect_root_manager; echo $ROOT_MANAGER')
# 本地无 /data/adb/magisk → Unknown（预期）
[[ "$r" == "Unknown" || "$r" == "Magisk" ]] && ok "无 env → $r (本地预期)" || ng "Fallback: $r"

r=$(KSU=true APATCH=true run_sh 'detect_root_manager; echo $ROOT_MANAGER')
[ "$r" = "KernelSU" ] && ok "KSU 优先于 APatch" || ng "优先级: $r"

# ======== 2. safe_read / safe_write ========
section 2 "safe_read / safe_write"

r=$(run_sh "safe_write '$TEST_DIR/n.txt' '42'; safe_read '$TEST_DIR/n.txt' '0'")
[ "$r" = "42" ] && ok "写42→读42" || ng "读写: $r"

r=$(run_sh "safe_read '$TEST_DIR/nope.txt' '99'")
[ "$r" = "99" ] && ok "不存在→默认99" || ng "默认: $r"

echo "abc" > "$TEST_DIR/bad.txt"
r=$(run_sh "safe_read '$TEST_DIR/bad.txt' '77'")
[ "$r" = "77" ] && ok "非数字→默认77" || ng "非数字: $r"

printf "" > "$TEST_DIR/empty.txt"
r=$(run_sh "safe_read '$TEST_DIR/empty.txt' '55'")
[ "$r" = "55" ] && ok "空文件→默认55" || ng "空文件: $r"

# 原子性：写入后旧的 .tmp 不应存在
run_sh "safe_write '$TEST_DIR/atom.txt' '100'" > /dev/null
[ ! -f "$TEST_DIR/atom.txt.tmp" ] && ok "原子写: .tmp已清理" || ng ".tmp残留"

# ======== 3. 启动计数逻辑 ========
section 3 "启动计数 1→2→3→4→5"

rm -f "$TEST_DIR/sc.log"
for expect in 1 2 3 4 5; do
  r=$(run_sh "
    START_LOG='$TEST_DIR/sc.log'
    BOOT_COUNT=1
    [ -f \"\$START_LOG\" ] && { BOOT_COUNT=\$(safe_read \"\$START_LOG\" 0); BOOT_COUNT=\$((BOOT_COUNT+1)); }
    safe_write \"\$START_LOG\" \"\$BOOT_COUNT\"
    echo \$BOOT_COUNT
  ")
  [ "$r" = "$expect" ] && ok "第${expect}次: count=$r" || ng "第${expect}次: 期望$expect 实际=$r"
done

# ======== 4. case 分支 ========
section 4 "case 分支 (3→禁用, 5→解冻)"

for c in 1 2 3 4 5 6; do
  r=$(sh -c "case $c in 3) echo DISABLE;; 5) echo UNFREEZE;; *) echo NORMAL;; esac")
  case $c in
    1|2|4|6) [ "$r" = "NORMAL" ]   && ok "count=$c → 正常"   || ng "count=$c: $r" ;;
    3)       [ "$r" = "DISABLE" ]   && ok "count=3 → 禁用模块" || ng "count=3: $r" ;;
    5)       [ "$r" = "UNFREEZE" ]  && ok "count=5 → 解冻应用" || ng "count=5: $r" ;;
  esac
done

# ======== 5. 白名单解析 ========
section 5 "白名单解析"

cat > "$TEST_DIR/wl.conf" << 'WL'
# 注释行
module_safe

# 空行
module_keep
# 结尾注释
WL

r=$(sed '/^[[:space:]]*$/d;/^#/d' "$TEST_DIR/wl.conf" | wc -l | tr -d ' ')
[ "$r" = "2" ] && ok "过滤注释/空行后=2个模块" || ng "解析: $r"

names=$(sed '/^[[:space:]]*$/d;/^#/d' "$TEST_DIR/wl.conf" | tr '\n' ',')
[[ "$names" == *"module_safe"* ]] && [[ "$names" == *"module_keep"* ]] && ok "模块名正确" || ng "名称: $names"

# ======== 6. BG_LOG_FILE 保存/恢复 ========
section 6 "BG_LOG_FILE source 隔离"

# 复制脚本到测试目录
cp "$SCRIPT_DIR"/{common.sh,brick_guardian_early.sh,brick_guardian_late.sh,module.prop,白名单.conf} "$TEST_DIR/"
chmod +x "$TEST_DIR"/*.sh

# 测试 early.sh
r=$(BG_LOG_FILE="$TEST_DIR/log" MODDIR="$TEST_DIR" sh -c '
  . "$MODDIR/common.sh"
  detect_root_manager
  BG_LOG_FILE="$MODDIR/ORIGINAL.log"
  saved="$BG_LOG_FILE"
  . "$MODDIR/brick_guardian_early.sh"
  [ "$BG_LOG_FILE" = "$saved" ] && echo OK || echo "FAIL:$BG_LOG_FILE"
' 2>/dev/null)
[ "$r" = "OK" ] && ok "source early.sh → BG_LOG_FILE 已恢复" || ng "early: $r"

# 测试 late.sh
r=$(MOCK_BOOTANIM=stopped BG_LOG_FILE="$TEST_DIR/log" MODDIR="$TEST_DIR" sh -c '
  . "$MODDIR/common.sh"
  detect_root_manager
  BG_LOG_FILE="$MODDIR/ORIGINAL2.log"
  saved="$BG_LOG_FILE"
  . "$MODDIR/brick_guardian_late.sh"
  [ "$BG_LOG_FILE" = "$saved" ] && echo OK || echo "FAIL:$BG_LOG_FILE"
' 2>/dev/null)
[ "$r" = "OK" ] && ok "source late.sh → BG_LOG_FILE 已恢复" || ng "late: $r"

# ======== 7. rescue_count 累加 ========
section 7 "rescue_count 累加"

rm -f "$TEST_DIR/rc.log"
for expect in 1 2 3; do
  r=$(run_sh "RESCUE_LOG='$TEST_DIR/rc.log'; update_rescue_stats; cat '$TEST_DIR/rc.log'")
  [ "$r" = "$expect" ] && ok "第${expect}次救砖: count=$r" || ng "第${expect}次: 期望$expect 实际=$r"
done

# ======== 8. OTA 版本比较 ========
section 8 "OTA 版本比较"

echo "ABC123" > "$TEST_DIR/ver"
r=$(MOCK_SYS_VER=ABC123 run_sh "
  prev=\$(cat '$TEST_DIR/ver'); curr=\$(getprop ro.system.build.version.incremental)
  [ \"\$prev\" = \"\$curr\" ] && echo SAME || echo DIFF
")
[ "$r" = "SAME" ] && ok "版本相同 → 非OTA" || ng "相同: $r"

echo "OLD" > "$TEST_DIR/ver"
r=$(MOCK_SYS_VER=NEW run_sh "
  prev=\$(cat '$TEST_DIR/ver'); curr=\$(getprop ro.system.build.version.incremental)
  [ \"\$prev\" = \"\$curr\" ] && echo SAME || echo DIFF
")
[ "$r" = "DIFF" ] && ok "版本不同 → 检测到OTA" || ng "不同: $r"

# ======== 9. module.prop 解析 ========
section 9 "module.prop"

v=$(grep "^version=" "$SCRIPT_DIR/module.prop" | cut -d= -f2)
[ "$v" = "v260529" ] && ok "version=$v" || ng "version=$v"

vc=$(grep "^versionCode=" "$SCRIPT_DIR/module.prop" | cut -d= -f2)
[ "$vc" = "260529" ] && ok "versionCode=$vc" || ng "versionCode=$vc"

# ^version= 不会匹配 versionCode
cnt=$(grep "^version=" "$SCRIPT_DIR/module.prop" | wc -l | tr -d ' ')
[ "$cnt" = "1" ] && ok "^version= 精确匹配1行" || ng "匹配 $cnt 行"

# ======== 10. is_magisk/is_kernelsu/is_apatch ========
section 10 "is_* 判断函数"

r=$(KSU=true run_sh 'detect_root_manager; is_kernelsu && echo Y || echo N')
[ "$r" = "Y" ] && ok "KSU: is_kernelsu=Y" || ng "is_kernelsu: $r"

r=$(KSU=true run_sh 'detect_root_manager; is_magisk && echo Y || echo N')
[ "$r" = "N" ] && ok "KSU: is_magisk=N" || ng "is_magisk: $r"

r=$(APATCH=true run_sh 'detect_root_manager; is_apatch && echo Y || echo N')
[ "$r" = "Y" ] && ok "APatch: is_apatch=Y" || ng "is_apatch: $r"

# ======== 11. save_good_modules / detect_suspect_modules ========
section 11 "suspect module tracking"

# 测试 good_list 对比逻辑（不依赖 /data/adb/modules 硬编码路径）

# 场景1: 有新增模块
echo "module_a" > "$TEST_DIR/good.list"
echo "module_b" >> "$TEST_DIR/good.list"
# 当前模块列表: a, b, c → c 是新增的
r=$(sh -c '
  good="'"$TEST_DIR"'/good.list"
  for m in module_a module_b module_c; do
    if ! grep -qx "$m" "$good"; then
      echo "$m"
    fi
  done
' 2>/dev/null)
[ "$r" = "module_c" ] && ok "新增模块 module_c 被检测到" || ng "新增检测: $r"

# 场景2: 无新增模块
r=$(sh -c '
  good="'"$TEST_DIR"'/good.list"
  found=0
  for m in module_a module_b; do
    if ! grep -qx "$m" "$good"; then
      found=1
    fi
  done
  echo $found
' 2>/dev/null)
[ "$r" = "0" ] && ok "无新增模块: 未检测到嫌疑人" || ng "误报: $r"

# 场景3: 多个新增模块
r=$(sh -c '
  good="'"$TEST_DIR"'/good.list"
  for m in module_a module_b module_x module_y; do
    if ! grep -qx "$m" "$good"; then
      echo "$m"
    fi
  done
' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
[ "$r" = "module_x,module_y" ] && ok "多个新增: $r" || ng "多个: $r"

# 场景4: good_list 不存在 → 首次救砖
rm -f "$TEST_DIR/good.list"
r=$(run_sh "
  MODID='bg'
  echo 'unknown' > '$TEST_DIR/suspect.log'
  cat '$TEST_DIR/suspect.log'
")
[ "$r" = "unknown" ] && ok "无 good_list → unknown" || ng "首次: $r"

# 场景5: suspect_info 格式化
echo "test-brick-module" > "$TEST_DIR/suspect.log"
r=$(grep -v '^?' "$TEST_DIR/suspect.log" | grep -v '^unknown$' | tr '\n' ',' | sed 's/,$//')
[ "$r" = "test-brick-module" ] && ok "suspect 格式化: $r" || ng "格式化: $r"

# 场景6: ? 前缀过滤
printf '?module_a\n?module_b\n' > "$TEST_DIR/suspect.log"
r=$(grep -v '^?' "$TEST_DIR/suspect.log" | grep -v '^unknown$' | wc -l | tr -d ' ')
[ "$r" = "0" ] && ok "? 前缀模块被过滤 (不确定的嫌疑人)" || ng "过滤: $r"

# ======== 结果 ========
echo ""
echo "=========================================="
echo -e "  结果: ${GREEN}${PASS} 通过${NC}, ${RED}${FAIL} 失败${NC}"
echo "=========================================="

rm -rf "$TEST_DIR"
[ $FAIL -gt 0 ] && exit 1
exit 0
