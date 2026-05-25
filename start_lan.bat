@echo off
chcp 65001 >nul
title 宠可灵 GEO 文案系统 (局域网模式)

echo ============================================
echo  宠可灵 GEO 文案生成系统 — 局域网模式
echo ============================================
echo.

cd /d "%~dp0"

:: ── 清理旧进程 ──
echo [..] 清理旧进程...
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im node.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: ── 检测 Python ──
set PYTHON_CMD=
python --version >nul 2>&1
if %ERRORLEVEL% equ 0 ( set PYTHON_CMD=python )

if "%PYTHON_CMD%"=="" (
    py --version >nul 2>&1
    if %ERRORLEVEL% equ 0 ( set PYTHON_CMD=py )
)

if "%PYTHON_CMD%"=="" (
    where python3 2>nul
    if %ERRORLEVEL% equ 0 ( set PYTHON_CMD=python3 )
)

:: 搜索常见安装路径
if "%PYTHON_CMD%"=="" (
    for /d %%i in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
        if exist "%%i\python.exe" set "PYTHON_CMD=%%i\python.exe"
    )
)

if "%PYTHON_CMD%"=="" (
    for /d %%i in ("%PROGRAMFILES%\Python3*") do (
        if exist "%%i\python.exe" set "PYTHON_CMD=%%i\python.exe"
    )
)

if "%PYTHON_CMD%"=="" (
    if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" (
        set "PYTHON_CMD=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    )
)

if "%PYTHON_CMD%"=="" (
    echo [错误] 未找到可用的 Python，请安装 Python 3.10+
    echo 下载: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo [..] 使用 %PYTHON_CMD%

:: ── 安装依赖 ──
%PYTHON_CMD% -c "import fastapi, uvicorn, litellm, tenacity" 2>nul || %PYTHON_CMD% -m pip install -r requirements.txt
if not exist "%~dp0frontend\node_modules\.package-lock.json" (
    cd /d "%~dp0frontend" && npm install && cd /d "%~dp0"
)
if not exist "%~dp0frontend\.next\BUILD_ID" (
    cd /d "%~dp0frontend" && npx next build && cd /d "%~dp0"
)

:: ── 启动后端 ──
echo [..] 启动后端...
:: ── 填写你的 API Key ──
:: 从 DeepSeek 控制台获取: https://platform.deepseek.com/api_keys
set DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
set LLM_MODEL=deepseek/deepseek-chat
set APP_HOST=127.0.0.1
start "petcare-backend" /B cmd /c "%PYTHON_CMD% -m uvicorn main:app --host 127.0.0.1 --port 8000 2>>backend_err.log"

echo [..] 等待后端就绪（最多30秒）...
set WAIT_COUNT=0
:wait
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
goto wait
:backend_ready
echo [..] 后端就绪 ✓

:: ── 启动前端 ──
start "petcare-frontend" /B cmd /c "cd /d "%~dp0frontend" && npx next start --port 3000 --hostname 0.0.0.0"

echo [..] 等待前端就绪（最多30秒）...
set WAIT_COUNT=0
:wait2
timeout /t 2 /nobreak >nul
%PYTHON_CMD% -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:3000/login', timeout=2)" 2>nul
if %ERRORLEVEL% equ 0 goto frontend_ready
set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 15 (
    echo [错误] 前端启动超时！请检查 frontend 控制台输出
    pause
    exit /b 1
)
goto wait2
:frontend_ready
echo [..] 前端就绪 ✓

echo.
echo ============================================
echo  启动完毕！
echo.
echo  本地访问:   http://localhost:3000
echo  访问密码:   YOUR_PASSWORD
echo.
echo  按任意键关闭所有服务...
echo ============================================

pause >nul

taskkill /fi "WINDOWTITLE eq petcare-backend" /f >nul 2>&1
taskkill /fi "WINDOWTITLE eq petcare-frontend" /f >nul 2>&1
echo 已关闭。
pause
