#Requires -Version 5.1
<#
  Builds (optional) and uploads WirelessPhoneDev-windows-x64.zip to GitHub Releases.
  Prerequisites: gh auth login   AND   Flutter SDK (only if rebuilding)
#>
param(
  [string]$Tag = 'v1.0.0',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
  [System.Environment]::GetEnvironmentVariable('Path', 'User')

gh auth status
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Run: gh auth login' -ForegroundColor Yellow
  exit 1
}

if (-not $SkipBuild) {
  Write-Host 'Building Windows Release...' -ForegroundColor Cyan
  flutter build windows --release
}

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'wireless_phone_dev.exe'
if (-not (Test-Path $exe)) {
  throw "Missing $exe - build first or omit -SkipBuild only after a successful build."
}

$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist 'WirelessPhoneDev-windows-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zip -Force
Write-Host "Packaged: $zip" -ForegroundColor Green

$notes = @"
## Wireless Phone Dev $Tag

Desktop GUI for wireless ADB + live screen. **Native Android and Flutter developers** can use this — no Flutter SDK needed to run the exe (you still need ``adb`` from Android Studio / SDK).

### Quick start
1. Unzip and run ``wireless_phone_dev.exe``
2. Or use repo scripts (no Flutter): ``tools\Connect.bat`` / ``Reconnect.bat`` / ``LiveScreen.bat``
3. For Live Screen: ``powershell -ExecutionPolicy Bypass -File tools\setup_scrcpy.ps1`` once

### Requirements
- Windows x64
- Android SDK platform-tools (``adb``)
- Phone + PC on same Wi-Fi
"@

gh release create $Tag $zip `
  --title "Wireless Phone Dev $Tag" `
  --notes $notes `
  --latest

Write-Host "Published: https://github.com/FawziQeshta/Wireless-Phone-Dev/releases/tag/$Tag" -ForegroundColor Green
