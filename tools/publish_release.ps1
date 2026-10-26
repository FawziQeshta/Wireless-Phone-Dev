#Requires -Version 5.1
<#
  Builds (optional), bundles scrcpy next to the exe, and uploads
  WirelessPhoneDev-windows-x64.zip to GitHub Releases.
  Prerequisites: gh auth login   AND   Flutter SDK (only if rebuilding)
#>
param(
  [string]$Tag = 'v1.0.2',
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

# Ensure scrcpy exists in the repo tools folder, then bundle beside the exe
$scrcpySrc = Join-Path $PSScriptRoot 'scrcpy\scrcpy.exe'
if (-not (Test-Path $scrcpySrc)) {
  Write-Host 'scrcpy missing — running setup_scrcpy.ps1 ...' -ForegroundColor Yellow
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'setup_scrcpy.ps1')
}
if (-not (Test-Path $scrcpySrc)) {
  throw 'scrcpy.exe still missing after setup. Cannot ship Live Screen.'
}

$scrcpyDest = Join-Path $releaseDir 'tools\scrcpy'
Write-Host "Bundling scrcpy into $scrcpyDest" -ForegroundColor Cyan
if (Test-Path $scrcpyDest) { Remove-Item $scrcpyDest -Recurse -Force }
New-Item -ItemType Directory -Force -Path $scrcpyDest | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'scrcpy\*') -Destination $scrcpyDest -Recurse -Force

$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist 'WirelessPhoneDev-windows-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zip -Force
Write-Host "Packaged: $zip" -ForegroundColor Green

$notes = @"
## Wireless Phone Dev $Tag

Windows desktop GUI for wireless ADB + live screen.
**Native Android and Flutter / React Native (Android)** — no Flutter SDK needed to run the exe (you still need ``adb``).

### Quick start
1. Unzip and run ``wireless_phone_dev.exe``
2. Live Screen: scrcpy is **bundled** in ``tools\scrcpy\`` (or auto-downloads on first use)
3. Or use repo scripts: ``tools\Connect.bat`` / ``Reconnect.bat`` / ``LiveScreen.bat``

### Live Screen mouse & keyboard (Xiaomi / Redmi / POCO)
``Developer options → USB debugging (Security settings) → ON → reboot → Reconnect → Live Screen``

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
