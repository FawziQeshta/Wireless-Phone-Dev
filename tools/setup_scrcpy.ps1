#Requires -Version 5.1
<#
  Downloads the official scrcpy Windows release into tools\scrcpy\
  (~10 MB — lightweight live screen + mouse/keyboard, no Vysor).
#>
$ErrorActionPreference = 'Stop'
$Dest = Join-Path $PSScriptRoot 'scrcpy'
$Zip = Join-Path $env:TEMP 'scrcpy-win64.zip'

Write-Host "Fetching latest scrcpy Windows build…" -ForegroundColor Cyan

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Genymobile/scrcpy/releases/latest' -Headers @{
  'User-Agent' = 'WirelessPhoneDev'
}
$asset = $release.assets | Where-Object { $_.name -match 'win64.*\.zip$' } | Select-Object -First 1
if (-not $asset) {
  throw 'Could not find win64 zip in latest scrcpy release.'
}

Write-Host "Downloading $($asset.name) …"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $Zip -UseBasicParsing

if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
New-Item -ItemType Directory -Path $Dest | Out-Null

Expand-Archive -Path $Zip -DestinationPath $Dest -Force

# Flatten if nested folder
$nested = Get-ChildItem $Dest -Directory | Select-Object -First 1
if ($nested -and (Test-Path (Join-Path $nested.FullName 'scrcpy.exe'))) {
  Get-ChildItem $nested.FullName | Move-Item -Destination $Dest -Force
  Remove-Item $nested.FullName -Recurse -Force
}

Remove-Item $Zip -Force -ErrorAction SilentlyContinue

if (-not (Test-Path (Join-Path $Dest 'scrcpy.exe'))) {
  throw 'scrcpy.exe missing after extract.'
}

Write-Host "`nReady: $Dest\scrcpy.exe" -ForegroundColor Green
Write-Host "Double-click LiveScreen.bat or use Live Screen in the app." -ForegroundColor DarkGreen
