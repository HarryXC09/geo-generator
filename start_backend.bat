@echo off
cd /d "%~dp0"

:: 检测 Python
set PYTHON_CMD=python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    py --version >nul 2>&1
    if %ERRORLEVEL% equ 0 ( set PYTHON_CMD=py ) else (
        echo [错误] 未找到 Python
        pause
        exit /b 1
    )
)

:: ── 填写你的 API Key ──
:: 从 DeepSeek 控制台获取: https://platform.deepseek.com/api_keys
set DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
set LLM_MODEL=deepseek/deepseek-chat
set APP_HOST=127.0.0.1
%PYTHON_CMD% -m uvicorn main:app --host 127.0.0.1 --port 8000
