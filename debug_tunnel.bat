@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo 当前目录: %CD%
echo 检查文件...
if exist cloudflared.exe (
    echo cloudflared.exe 存在
    dir cloudflared.exe
) else (
    echo [错误] 找不到 cloudflared.exe
    pause
    exit /b 1
)

echo.
echo 尝试运行 cloudflared --version...
cloudflared.exe --version
echo.
echo exit code: %ERRORLEVEL%
echo.
echo 如果上面没有显示版本号，说明:
echo 1. 文件被 Windows 安全机制拦截
echo 2. 请右键 cloudflared.exe → 属性 → 如果底部有"解除锁定"则勾选 → 确定
echo 3. 或者尝试以管理员身份运行此脚本
echo.
pause
