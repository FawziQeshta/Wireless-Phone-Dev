@echo off
title Wireless Phone Dev - Status
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adb_wireless.ps1" -Action status
echo.
pause
