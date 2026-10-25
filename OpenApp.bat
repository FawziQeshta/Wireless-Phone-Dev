@echo off
title Wireless Phone Dev
cd /d "%~dp0"

if exist "build\windows\x64\runner\Release\wireless_phone_dev.exe" (
  start "" "build\windows\x64\runner\Release\wireless_phone_dev.exe"
  exit /b 0
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter not in PATH. Use tools\Connect.bat / Reconnect.bat instead.
  pause
  exit /b 1
)

echo Launching Flutter Windows app...
flutter run -d windows
