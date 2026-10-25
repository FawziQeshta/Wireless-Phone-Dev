@echo off
title Wireless Phone Dev - Reconnect
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adb_wireless.ps1" -Action reconnect
echo.
pause
