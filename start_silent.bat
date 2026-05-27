@echo off
cd /d "G:\petcare-geo-copy\"
taskkill /f /im python.exe >nul 2>>nul
taskkill /f /im node.exe >nul 2>>nul

set DEEPSEEK_API_KEY=sk-6b1b2e51bc284d2c8b2b419cb6dcc619
set LLM_MODEL=deepseek/deepseek-chat
set APP_HOST=127.0.0.1

start "" /B python -m uvicorn main:app --host 127.0.0.1 --port 8000

:wait
timeout /t 2 /nobreak >nul
python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)" 2>nul
if %ERRORLEVEL% neq 0 goto wait

cd /d "G:\petcare-geo-copy\frontend"
start "" /B npx next start --port 3000 --hostname 0.0.0.0
