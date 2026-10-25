# Wireless Phone Dev

Lightweight Flutter + ADB toolkit for **wireless Android debugging** and a **live phone screen** on your laptop — mouse & keyboard control, no cable after the first setup, no Vysor.

Works with **Flutter**, **Android Studio**, and **VS Code**.

## What you get

| Action | What it does |
|--------|----------------|
| **Connect (USB → Wireless)** | Reads the phone IP, opens port `5555`, connects over Wi‑Fi. Then unplug. |
| **Reconnect** | Next day / after reboot: double‑click and you’re back online in ~2 seconds. No cable. |
| **Live Screen** | Mirrors the phone on the PC and lets you control it with mouse & keyboard ([scrcpy](https://github.com/Genymobile/scrcpy)). |
| **Hot Reload / Debug** | Same as USB: `flutter run`, breakpoints, DevTools — over Wi‑Fi. |

## Prerequisites

1. **Android SDK platform-tools** (`adb`) — usually via Android Studio  
   - Default path: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
2. Phone and PC on the **same Wi‑Fi**
3. **USB debugging** enabled (Developer options)
4. For Live Screen: run once  
   `powershell -ExecutionPolicy Bypass -File tools\setup_scrcpy.ps1`

## Fast path (double‑click — no Flutter build needed)

```
tools\Connect.bat      ← first time, cable plugged in
tools\Reconnect.bat    ← every later session, no cable
tools\LiveScreen.bat   ← wireless mirror + mouse/keyboard
tools\Status.bat       ← adb devices
```

After **Connect**, unplug the USB cable. Run / debug / Hot Reload as usual:

```bash
flutter devices
flutter run -d <your-ip>:5555
```

## Flutter desktop app

```bash
cd WirelessPhoneDev
flutter pub get
flutter run -d windows
```

Or build a standalone exe:

```bash
flutter build windows
```

Output: `build\windows\x64\runner\Release\wireless_phone_dev.exe`

## Typical day‑two flow

1. Phone unlocked, Wi‑Fi on (same network as PC)  
2. Double‑click **Reconnect.bat** (or tap Reconnect in the app)  
3. `flutter run` / Hot Reload  
4. Optional: **Live Screen** for full remote control  

If reconnect fails (phone sleep policies / wireless debugging reset), plug USB once and run **Connect** again.

## Project layout

```
lib/                 Flutter Windows UI
tools/
  Connect.bat
  Reconnect.bat
  LiveScreen.bat
  adb_wireless.ps1   Core ADB automation
  setup_scrcpy.ps1   Download official scrcpy (~10 MB)
  scrcpy/            Place scrcpy.exe here (or use setup script)
```

## Notes

- Port **5555** is the standard ADB-over-TCP port.
- Firewall: allow ADB/outbound to the phone on your LAN.
- Some OEMs reset `tcpip` mode after reboot — **Reconnect** usually still works if the daemon stayed in TCP mode; otherwise one USB **Connect** restores it.
- scrcpy is free, open source, and far lighter than commercial mirroring apps.

## License

Use freely for your own development workflow. scrcpy is copyright Genymobile (Apache-2.0).
