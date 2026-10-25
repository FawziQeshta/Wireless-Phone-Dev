@echo off
title Wireless Phone Dev - Connect
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adb_wireless.ps1" -Action connect
echo.
pause
