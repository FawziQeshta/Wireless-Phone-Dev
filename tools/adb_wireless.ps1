#Requires -Version 5.1
<#
.SYNOPSIS
  Wireless ADB helper for Flutter / Android Studio / VS Code.
.PARAMETER Action
  connect   - First time: USB -> tcpip 5555 -> connect (then unplug)
  reconnect - Use saved IP (no cable)
  live      - Open scrcpy live screen
  status    - List devices
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('connect', 'reconnect', 'live', 'status')]
  [string]$Action,

  [string]$Ip,
  [int]$Port = 5555
)

$ErrorActionPreference = 'Stop'
$StateFile = Join-Path $PSScriptRoot 'last_device.json'

function Find-Adb {
  $candidates = @()
  if ($env:ANDROID_HOME) {
    $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe')
  }
  if ($env:ANDROID_SDK_ROOT) {
    $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe')
  }
  $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
  $candidates += (Join-Path $PSScriptRoot 'platform-tools\adb.exe')

  foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { return $c }
  }
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw 'ADB not found. Install Android SDK platform-tools and set ANDROID_HOME.'
}

function Find-Scrcpy {
  $candidates = @(
    (Join-Path $PSScriptRoot 'scrcpy\scrcpy.exe'),
    (Join-Path $PSScriptRoot 'scrcpy.exe'),
    (Join-Path $env:LOCALAPPDATA 'scrcpy\scrcpy.exe')
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  $cmd = Get-Command scrcpy -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Save-State($ip, $port, $model) {
  @{ ip = $ip; port = $port; model = $model; savedAt = (Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
}

function Load-State {
  if (-not (Test-Path $StateFile)) { return $null }
  return Get-Content $StateFile -Raw | ConvertFrom-Json
}

function Get-UsbSerial([string]$Adb) {
  $lines = @(& $Adb devices -l | Select-Object -Skip 1)
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = @(($line -split '\s+') | Where-Object { $_ })
    if ($parts.Count -lt 2) { continue }
    $id = $parts[0]
    $state = $parts[1]
    if ($state -ne 'device') { continue }
    if ($id -match '^\d+\.\d+\.\d+\.\d+:') { continue }
    return $id
  }
  return $null
}

function Get-TextFromAdbOutput($out) {
  if ($null -eq $out) { return '' }
  return (@($out) | ForEach-Object { "$_" }) -join "`n"
}

function Get-DeviceIp([string]$Adb, [string]$Serial) {
  # IMPORTANT: adb often returns a string[]. In PowerShell, array -match filters
  # lines and does NOT populate $Matches — that caused "Cannot index into a null array".
  foreach ($iface in @('wlan0', 'wlan1', 'eth0')) {
    $out = Get-TextFromAdbOutput (& $Adb -s $Serial shell ip -f inet addr show $iface 2>&1)
    if ($out -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') { return $Matches[1] }
  }

  $route = Get-TextFromAdbOutput (& $Adb -s $Serial shell ip route get 8.8.8.8 2>&1)
  if ($route -match 'src\s+(\d+\.\d+\.\d+\.\d+)') { return $Matches[1] }

  $ifconfig = Get-TextFromAdbOutput (& $Adb -s $Serial shell ifconfig wlan0 2>&1)
  if ($ifconfig -match 'inet addr:(\d+\.\d+\.\d+\.\d+)') { return $Matches[1] }
  if ($ifconfig -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') { return $Matches[1] }

  $prop = (Get-TextFromAdbOutput (& $Adb -s $Serial shell getprop dhcp.wlan0.ipaddress 2>&1)).Trim()
  if ($prop -match '^\d+\.\d+\.\d+\.\d+$') { return $prop }

  return $null
}

$adb = Find-Adb
Write-Host "ADB: $adb" -ForegroundColor DarkCyan
& $adb start-server | Out-Null

switch ($Action) {
  'status' {
    & $adb devices -l
  }

  'connect' {
    Write-Host ""
    Write-Host "=== First-time wireless connect ===" -ForegroundColor Cyan
    Write-Host "1) Phone on same Wi-Fi as PC"
    Write-Host "2) USB cable plugged in"
    Write-Host "3) USB debugging ON"
    Write-Host ""

    $serial = Get-UsbSerial $adb
    if (-not $serial) {
      Write-Host "No USB device found. Check cable / Allow USB debugging." -ForegroundColor Red
      exit 1
    }
    Write-Host "USB device: $serial" -ForegroundColor Green

    $phoneIp = Get-DeviceIp $adb $serial
    if (-not $phoneIp) {
      Write-Host "Could not read Wi-Fi IP. Connect phone to Wi-Fi." -ForegroundColor Red
      exit 1
    }
    Write-Host "Phone IP: $phoneIp" -ForegroundColor Green

    & $adb -s $serial tcpip $Port
    Start-Sleep -Milliseconds 1200
    $endpoint = "${phoneIp}:$Port"
    $out = & $adb connect $endpoint 2>&1 | Out-String
    Write-Host $out

    if ($out -match 'connected|already') {
      Save-State $phoneIp $Port $null
      Write-Host ""
      Write-Host "SUCCESS - unplug the cable. Use flutter run / Hot Reload wirelessly." -ForegroundColor Green
      Write-Host "Saved $endpoint for Reconnect.bat" -ForegroundColor DarkGreen
      exit 0
    }
    Write-Host "Connect failed for $endpoint" -ForegroundColor Red
    exit 1
  }

  'reconnect' {
    Write-Host ""
    Write-Host "=== Wireless reconnect (no cable) ===" -ForegroundColor Cyan
    $state = Load-State
    if (-not $Ip -and $state) { $Ip = $state.ip; $Port = [int]$state.port }
    if (-not $Ip) {
      Write-Host "No saved IP. Run Connect.bat once with USB first." -ForegroundColor Red
      exit 1
    }
    $endpoint = "${Ip}:$Port"
    Write-Host "Connecting to $endpoint ..."
    & $adb disconnect $endpoint 2>$null | Out-Null
    $out = & $adb connect $endpoint 2>&1 | Out-String
    Write-Host $out
    if ($out -match 'connected|already') {
      Save-State $Ip $Port $(if ($state) { $state.model } else { $null })
      Write-Host ""
      Write-Host "Reconnected. You are free to debug." -ForegroundColor Green
      exit 0
    }
    Write-Host "Failed. Phone on same Wi-Fi? Or re-run Connect.bat with USB." -ForegroundColor Red
    exit 1
  }

  'live' {
    $scrcpy = Find-Scrcpy
    if (-not $scrcpy) {
      Write-Host "scrcpy not found. Run: powershell -File tools\setup_scrcpy.ps1" -ForegroundColor Yellow
      exit 1
    }
    Write-Host "Launching live screen: $scrcpy" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "If mouse/keyboard do nothing (common on Xiaomi/Redmi/POCO):" -ForegroundColor Yellow
    Write-Host "  Phone -> Settings -> Additional settings -> Developer options"
    Write-Host "  Enable: USB debugging (Security settings)"
    Write-Host "  Then REBOOT the phone, run Reconnect.bat, and open Live Screen again."
    Write-Host ""
    $dir = Split-Path $scrcpy
    # Do NOT use --stay-awake: it needs WRITE_SECURE_SETTINGS and fails on Xiaomi/MIUI.
    # --mouse=sdk --keyboard=sdk inject via Android APIs (needs Security settings on Xiaomi).
    # Quote title — Start-Process splits on spaces inside ArgumentList.
    $argLine = '--mouse=sdk --keyboard=sdk --max-size 1024 --window-title "Wireless Phone Live"'
    Start-Process -FilePath $scrcpy -WorkingDirectory $dir -ArgumentList $argLine
  }
}
