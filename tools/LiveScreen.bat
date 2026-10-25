@echo off
title Wireless Phone Dev - Live Screen
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adb_wireless.ps1" -Action live
if errorlevel 1 pause
