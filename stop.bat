@echo off
chcp 65001 >nul
title 宠可灵 — 关闭服务

echo 正在关闭所有服务...
taskkill /fi "WINDOWTITLE eq petcare-backend" /f >nul 2>&1
taskkill /fi "WINDOWTITLE eq petcare-frontend" /f >nul 2>&1
taskkill /fi "WINDOWTITLE eq petcare-tunnel" /f >nul 2>&1
taskkill /f /im cloudflared.exe >nul 2>&1
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im node.exe >nul 2>&1

echo 所有服务已关闭。
pause
