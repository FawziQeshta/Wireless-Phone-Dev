# Wireless Phone Dev

Wireless Android debugging + live phone screen on your PC — **no cable after first setup**, no Vysor.

**For both:**

| Who | What you need | How to use |
|-----|----------------|------------|
| **Android native** (Android Studio / Kotlin / Java) | `adb` only — **no Flutter** | Double‑click `tools\*.bat` or download the Release `.zip` |
| **Flutter** | `adb` (+ Flutter for your apps) | Same tools + wireless `flutter run` / Hot Reload |

Works with **Android Studio**, **VS Code**, and **Flutter**.

---

## Option A — Double‑click scripts (recommended for everyone)

Clone the repo (or download ZIP). **No Flutter SDK required.**

### Prerequisites

1. **Android SDK platform-tools** (`adb`) — comes with Android Studio  
   - Typical path: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
2. Phone + PC on the **same Wi‑Fi**
3. **USB debugging** ON (Developer options)
4. Live Screen only — run once:

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup_scrcpy.ps1
```

### Commands

```
tools\Connect.bat      ← first time (USB cable plugged in)
tools\Reconnect.bat    ← next day / every session (no cable)
tools\LiveScreen.bat   ← mirror + mouse & keyboard
tools\Status.bat       ← list adb devices
```

**First time**

1. Plug USB → run `Connect.bat` → unplug  
2. Debug as usual over Wi‑Fi  

**Android Studio / native:** pick the `ip:5555` device in the device list, Run / Debug.  
**Flutter:** `flutter devices` then `flutter run -d <ip>:5555` (Hot Reload works).

**Next day**

1. Same Wi‑Fi, phone unlocked  
2. Double‑click `Reconnect.bat` (~2 seconds)  
3. Run / Debug again — no cable  

---

## Option B — Desktop app (GitHub Release)

Prebuilt Windows GUI — **no Flutter SDK to use it**.

1. Open [Releases](https://github.com/FawziQeshta/Wireless-Phone-Dev/releases)
2. Download `WirelessPhoneDev-windows-x64.zip`
3. Unzip and run `wireless_phone_dev.exe`
4. Still need `adb` on the machine (Android Studio / SDK)

Buttons in the app: **Connect**, **Reconnect**, **Live Screen**, **Disconnect**.

---

## Option C — Build the GUI from source (Flutter developers)

```bash
flutter pub get
flutter run -d windows
# or
flutter build windows
```

Output folder: `build\windows\x64\runner\Release\`

---

## What each action does

| Action | What it does |
|--------|----------------|
| **Connect (USB → Wireless)** | Reads phone IP, opens port `5555`, connects over Wi‑Fi. Then unplug. |
| **Reconnect** | Uses saved IP — back online in ~2 seconds, no cable. |
| **Live Screen** | Full mirror + mouse/keyboard via [scrcpy](https://github.com/Genymobile/scrcpy). |
| **Debug / Hot Reload** | Same as USB — Android Studio Run, or `flutter run`. |

---

## Day‑two checklist

1. Phone unlocked, Wi‑Fi on (same network as PC)  
2. `Reconnect.bat` (or Reconnect in the app)  
3. Run your app from Android Studio or Flutter  
4. Optional: `LiveScreen.bat` for remote control  

If reconnect fails (OEM reset TCP mode), plug USB once and run **Connect** again.

---

## Project layout

```
tools/                 ← use this if you are native Android (no Flutter)
  Connect.bat
  Reconnect.bat
  LiveScreen.bat
  Status.bat
  adb_wireless.ps1
  setup_scrcpy.ps1
lib/                   ← Flutter Windows GUI source
```

---

## Notes

- Port **5555** is standard ADB-over-TCP.
- Allow LAN access in Windows Firewall if connect fails.
- Some OEMs reset wireless ADB after reboot — one USB **Connect** restores it.
- scrcpy is free/open source (~10 MB), much lighter than commercial mirroring apps.

## License

Use freely for your development workflow. scrcpy © Genymobile (Apache-2.0).
