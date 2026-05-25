@echo off
chcp 65001 >nul
echo 正在移除开机自启...
del "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\petcare_geo.vbs" 2>nul
del "%USERPROFILE%\Desktop\宠可灵-启动服务.lnk" 2>nul
echo 已移除。按任意键退出。
pause >nul
