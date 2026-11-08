#!/usr/bin/env bash
# ==============================================================================
# BeeCount 自动记账 URL Scheme 本地 ADB 联调与自动化测试脚本 (macOS / Linux)
# ==============================================================================

set -e

echo "========================================================"
echo "    BeeCount 自动记账协议 (URL Scheme) 自动化联调工具   "
echo "========================================================"

# 检查 adb 命令
if ! command -v adb &> /dev/null; then
    echo "❌ 错误: 未检测到 adb 命令，请确保已安装 Android SDK 并加入 PATH。"
    exit 1
fi

# 检查设备连接
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "⚠️ 警告: 未检测到已连接的 Android 设备或模拟器，请先连接手机并开启 USB 调试。"
    exit 1
fi

# 自动检测设备上安装的 BeeCount 包名（正式版或开发版）
PKG="com.tntlikely.beecount"
if adb shell pm list packages | grep -q "com.tntlikely.beecount.dev"; then
    PKG="com.tntlikely.beecount.dev"
fi

echo "✅ 检测到目标记账应用包名: $PKG，准备发起测试..."
echo ""

# 1. 测试标准消费支出（静默记账）
echo "▶ [测试 1/4] 发送支出账单 (¥26.50, 餐饮, 微信零钱, 瑞幸咖啡)..."
adb shell am start -a android.intent.action.VIEW -p "$PKG" -d "beecount://publicapi/addbill?money=26.50\&type=0\&cate_name=%E9%A4%90%E9%A5%AE\&account_name=%E5%BE%AE%E4%BF%A1%E9%9B%B6%E9%92%B1\&remark=%E7%91%9E%E5%B9%B8%E5%92%96%E5%95%A1\&auto_save=1"
sleep 1

# 2. 测试工资收入
echo "▶ [测试 2/4] 发送收入账单 (¥12000.00, 工资, 工商银行卡)..."
adb shell am start -a android.intent.action.VIEW -p "$PKG" -d "beecount://publicapi/addbill?money=12000.00\&type=1\&cate_name=%E5%B7%A5%E8%B5%84\&account_name=%E5%B7%A5%E5%95%86%E9%93%B6%E8%A1%8C%E5%8D%A1\&remark=10%E6%9C%88%E5%B7%A5%E8%B5%84\&auto_save=1"
sleep 1

# 3. 测试内部转账
echo "▶ [测试 3/4] 发送转账账单 (¥800.00, 微信零钱 -> 招商银行卡)..."
adb shell am start -a android.intent.action.VIEW -p "$PKG" -d "beecount://publicapi/addbill?money=800.00\&type=2\&account_name=%E5%BE%AE%E4%BF%A1%E9%9B%B6%E9%92%B1\&target_account=%E6%8B%9B%E5%95%86%E9%93%B6%E8%A1%8C%E5%8D%A1\&remark=%E9%9B%B6%E9%92%B1%E6%8F%90%E7%8E%B0\&auto_save=1"
sleep 1

# 4. 测试原生协议 (beecount://add)
echo "▶ [测试 4/4] 发送原生协议账单 (¥15.00, 交通, 支付宝余额, 地铁出行)..."
adb shell am start -a android.intent.action.VIEW -p "$PKG" -d "beecount://add?amount=15.00\&type=expense\&category=%E4%BA%A4%E9%80%9A\&account=%E6%94%AF%E4%BB%98%E5%AE%9D%E4%BD%99%E9%A2%9D\&note=%E5%9C%B0%E9%93%81%E5%87%BA%E8%A1%8C\&silent=1"

echo ""
echo "========================================================"
echo "🎉 测试调用全部发送完成！请打开 BeeCount 检查交易列表是否已入库。"
echo "========================================================"
