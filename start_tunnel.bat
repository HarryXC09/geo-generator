@echo off
chcp 65001 >nul
title 宠可灵 — Cloudflare 隧道

cd /d "%~dp0"

echo ============================================
echo  宠可灵 Cloudflare 隧道启动器
echo  要求: 后端和前端已在运行
echo ============================================
echo.

:: 检查端口
echo [..] 检查前端是否运行...
curl -s -o nul http://127.0.0.1:3000/login
if %ERRORLEVEL% neq 0 (
    echo [错误] 前端未运行，请先双击 start_lan.bat
    pause
    exit /b 1
)
echo [..] 前端已运行 ✓

:: 检查 cloudflared
if not exist cloudflared.exe (
    echo [错误] 未找到 cloudflared.exe
    echo 请从 https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
    echo 下载 cloudflared-windows-amd64.exe 并重命名为 cloudflared.exe 放到此目录
    pause
    exit /b 1
)

echo.
echo  正在启动 Cloudflare 快速隧道...
echo  首次运行会打开浏览器让您登录 Cloudflare 账号
echo  登录后隧道会自动创建
echo.
echo  请勿关闭此窗口 — URL 会显示在下方
echo.
echo ============================================

cloudflared.exe tunnel --url http://127.0.0.1:3000 --edge-ip-version 4 --logfile tunnel.log

echo.
echo 隧道已关闭。
pause
