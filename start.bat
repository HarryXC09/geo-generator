@echo off
chcp 65001 >nul
title 宠可灵 GEO 文案系统 (隧道模式)

echo ============================================
echo  宠可灵 GEO 文案生成系统 — 启动中...
echo  模式: 局域网 + Cloudflare 公网隧道
echo ============================================
echo.

cd /d "%~dp0"

:: ── 清理旧进程 ──
echo [..] 清理旧进程...
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im node.exe >nul 2>&1
taskkill /f /im cloudflared.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: ── 检测 Python ──
set PYTHON_CMD=python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    py --version >nul 2>&1
    if %ERRORLEVEL% equ 0 ( set PYTHON_CMD=py ) else (
        echo [错误] 未找到可用的 Python，请安装 Python 3.10+
        echo 下载: https://www.python.org/downloads/
        pause
        exit /b 1
    )
)
echo [..] 使用 %PYTHON_CMD%

:: ── 安装后端依赖 ──
echo [1/4] 检查 Python 依赖...
%PYTHON_CMD% -c "import fastapi, uvicorn, litellm, tenacity" 2>nul
if %ERRORLEVEL% neq 0 (
    echo [..] 安装依赖中...
    %PYTHON_CMD% -m pip install -r "%~dp0requirements.txt"
)

:: ── 安装前端依赖 ──
echo [2/4] 检查前端依赖...
if not exist "%~dp0frontend\node_modules\.package-lock.json" (
    echo [..] 安装前端依赖...
    cd /d "%~dp0frontend" && npm install
    cd /d "%~dp0"
)

:: ── 构建前端 ──
if not exist "%~dp0frontend\.next\BUILD_ID" (
    echo [..] 构建前端...
    cd /d "%~dp0frontend" && npx next build
    cd /d "%~dp0"
)

:: ── 设置 API Key ──
:: 从 https://platform.deepseek.com/api_keys 获取
set DEEPSEEK_API_KEY=sk-6b1b2e51bc284d2c8b2b419cb6dcc619
set LLM_MODEL=deepseek/deepseek-chat
set APP_HOST=127.0.0.1

:: ── 启动后端 ──
echo [3/4] 启动后端服务 (127.0.0.1:8000)...
start "petcare-backend" /B cmd /c "%PYTHON_CMD% -m uvicorn main:app --host 127.0.0.1 --port 8000 2>>backend_err.log"

echo [..] 等待后端就绪（最多30秒）...
set WAIT_COUNT=0
:wait_backend
timeout /t 2 /nobreak >nul
%PYTHON_CMD% -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)" 2>nul
if %ERRORLEVEL% equ 0 goto backend_ready
set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 15 (
    echo [错误] 后端启动超时！请检查 backend_err.log
    type backend_err.log 2>nul
    pause
    exit /b 1
)
goto wait_backend
:backend_ready
echo [..] 后端就绪 ✓

:: ── 启动前端 ──
echo [4/4] 启动前端服务 (0.0.0.0:3000)...
start "petcare-frontend" /B cmd /c "cd /d "%~dp0frontend" && npx next start --port 3000 --hostname 0.0.0.0"

echo [..] 等待前端就绪（最多30秒）...
set WAIT_COUNT=0
:wait_frontend
timeout /t 2 /nobreak >nul
%PYTHON_CMD% -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:3000/login', timeout=2)" 2>nul
if %ERRORLEVEL% equ 0 goto frontend_ready
set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 15 (
    echo [错误] 前端启动超时！
    pause
    exit /b 1
)
goto wait_frontend
:frontend_ready
echo [..] 前端就绪 ✓

:: ── 启动 Cloudflare 隧道（如果存在 cloudflared.exe） ──
if exist cloudflared.exe (
    echo.
    echo ============================================
    echo  正在新窗口中启动 Cloudflare 隧道...
    echo  请查看新窗口中的 URL
    echo ============================================
    start "petcare-tunnel" /MIN cmd /c "cloudflared.exe tunnel --url http://127.0.0.1:3000 --edge-ip-version 4 --logfile tunnel.log & pause"
)

echo.
echo ============================================
echo  系统启动完毕！
echo.
echo  本地访问:   http://localhost:3000
echo  访问密码:   leilingbio888
echo.
echo  隧道窗口:   查看 "宠可灵 - Cloudflare 隧道" 窗口获取公网 URL
echo ============================================
echo.
echo 按任意键关闭所有服务...
pause >nul

taskkill /fi "WINDOWTITLE eq petcare-backend" /f >nul 2>&1
taskkill /fi "WINDOWTITLE eq petcare-frontend" /f >nul 2>&1
taskkill /fi "WINDOWTITLE eq petcare-tunnel" /f >nul 2>&1
taskkill /f /im cloudflared.exe >nul 2>&1
echo 已关闭所有服务。
pause
