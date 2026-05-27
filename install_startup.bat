@echo off
chcp 65001 >nul
title 宠可灵 — 安装开机自启服务
cd /d "%~dp0"

echo ============================================
echo  安装宠可灵 GEO 文案系统 — 开机自启
echo ============================================
echo.
echo  将会安装：
echo   1. 开机自动启动后端 (Python) — 静默后台运行
echo   2. 开机自动启动前端 (Next.js) — 静默后台运行
echo   3. 桌面快捷方式"宠可灵-启动服务"
echo.
echo  注意：使用后台模式后，要关闭服务请运行 stop.bat
echo.

:: ── 生成静默启动脚本 ──
echo [..] 生成后台启动文件...

(
echo @echo off
echo cd /d "%~dp0"
echo taskkill /f /im python.exe ^>nul 2^>^>nul
echo taskkill /f /im node.exe ^>nul 2^>^>nul
echo.
echo set DEEPSEEK_API_KEY=sk-6b1b2e51bc284d2c8b2b419cb6dcc619
echo set LLM_MODEL=deepseek/deepseek-chat
echo set APP_HOST=127.0.0.1
echo.
echo start "" /B python -m uvicorn main:app --host 127.0.0.1 --port 8000
echo.
echo :wait
echo timeout /t 2 /nobreak ^>nul
echo python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)" 2^>nul
echo if %%ERRORLEVEL%% neq 0 goto wait
echo.
echo cd /d "%~dp0frontend"
echo start "" /B npx next start --port 3000 --hostname 0.0.0.0
) > "%~dp0start_silent.bat"

:: ── 创建 VBS 启动器（完全隐藏窗口） ──
(
echo Set WshShell = CreateObject("WScript.Shell")
echo WshShell.Run "%~dp0start_silent.bat", 0, False
) > "%~dp0start_silent.vbs"

:: ── 安装到启动项 ──
echo [..] 安装到开机启动项...
copy "%~dp0start_silent.vbs" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\petcare_geo.vbs" /y >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [..] ✓ 已安装到开机启动项
) else (
    echo [警告] 无法安装启动项，请以管理员身份运行
)

:: ── 创建桌面快捷方式 ──
echo [..] 创建桌面快捷方式...
set SHORTCUT_PATH=%USERPROFILE%\Desktop\宠可灵-启动服务.lnk
(
echo Set WshShell = CreateObject("WScript.Shell")
echo Set Shortcut = WshShell.CreateShortcut("%SHORTCUT_PATH%")
echo Shortcut.TargetPath = "%~dp0start_silent.vbs"
echo Shortcut.WorkingDirectory = "%~dp0"
echo Shortcut.Description = "宠可灵 GEO 文案系统（后台静默启动）"
echo Shortcut.WindowStyle = 7
echo Shortcut.Save()
) > "%TEMP%\petcare_shortcut.vbs"
cscript //nologo "%TEMP%\petcare_shortcut.vbs" >nul 2>&1
del "%TEMP%\petcare_shortcut.vbs"

echo [..] ✓ 桌面快捷方式已创建

:: ── 生成卸载脚本 ──
(
echo @echo off
echo chcp 65001 ^>nul
echo echo 正在移除开机自启...
echo del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\petcare_geo.vbs" 2^>nul
echo del "%%USERPROFILE%%\Desktop\宠可灵-启动服务.lnk" 2^>nul
echo echo 已移除。按任意键退出。
echo pause ^>nul
) > "%~dp0remove_startup.bat"

echo.
echo ============================================
echo  安装完成！
echo.
echo  ◆ 开机自启：已安装
echo  ◆ 桌面快捷："宠可灵-启动服务"
echo  ◆ 停止服务：运行 stop.bat
echo  ◆ 卸载自启：运行 remove_startup.bat
echo.
echo  ◆ 公网隧道：每次重启后双击 start_tunnel.bat
echo.
echo  按任意键退出...
echo ============================================
pause >nul
