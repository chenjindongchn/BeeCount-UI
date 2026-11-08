@echo off
chcp 65001 >nul
echo ========================================================
echo     BeeCount 自动记账协议 (URL Scheme) 调试工具 (Windows)
echo ========================================================

where adb >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 adb 命令，请确保已安装 Android SDK 并加入系统 PATH。
    pause
    exit /b 1
)

set PKG=com.tntlikely.beecount
adb shell pm list packages | findstr "com.tntlikely.beecount.dev" >nul
if %errorlevel% equ 0 (
    set PKG=com.tntlikely.beecount.dev
)

echo 检测到包名: %PKG%
echo [1/3] 发送支出测试 (¥26.50, 餐饮, 微信零钱)...
adb shell am start -a android.intent.action.VIEW -p %PKG% -d "beecount://publicapi/addbill?money=26.50^&type=0^&cate_name=餐饮^&account_name=微信零钱^&remark=测试支出^&auto_save=1"
timeout /t 2 >nul

echo [2/3] 发送收入测试 (¥10000.00, 工资, 工商银行卡)...
adb shell am start -a android.intent.action.VIEW -p %PKG% -d "beecount://publicapi/addbill?money=10000.00^&type=1^&cate_name=工资^&account_name=工商银行卡^&remark=测试工资^&auto_save=1"
timeout /t 2 >nul

echo [3/3] 发送转账测试 (¥500.00, 微信零钱 -^> 招商银行卡)...
adb shell am start -a android.intent.action.VIEW -p %PKG% -d "beecount://publicapi/addbill?money=500.00^&type=2^&account_name=微信零钱^&target_account=招商银行卡^&remark=测试转账^&auto_save=1"

echo.
echo ========================================================
echo 测试完成！请在手机 BeeCount 中查看账单。
echo ========================================================
pause
