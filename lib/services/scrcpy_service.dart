import 'dart:io';

import 'package:path/path.dart' as p;

/// Launches [scrcpy](https://github.com/Genymobile/scrcpy) for wireless
/// live screen + mouse/keyboard control — no Vysor, no heavy installs.
class ScrcpyService {
  String? _resolved;

  Future<String?> resolveScrcpyPath() async {
    if (_resolved != null) return _resolved;

    final candidates = <String>[];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;

    for (final root in [cwd, exeDir, p.dirname(exeDir)]) {
      candidates.add(p.join(root, 'tools', 'scrcpy', 'scrcpy.exe'));
      candidates.add(p.join(root, 'tools', 'scrcpy.exe'));
      candidates.add(p.join(root, 'scrcpy', 'scrcpy.exe'));
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      candidates.add(p.join(localAppData, 'scrcpy', 'scrcpy.exe'));
    }

    final programFiles = Platform.environment['ProgramFiles'];
    if (programFiles != null) {
      candidates.add(p.join(programFiles, 'scrcpy', 'scrcpy.exe'));
    }

    for (final path in candidates) {
      if (await File(path).exists()) {
        return _resolved = path;
      }
    }

    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['scrcpy'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final line = (result.stdout as String)
            .split(RegExp(r'\r?\n'))
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
        if (line.isNotEmpty && await File(line.trim()).exists()) {
          return _resolved = line.trim();
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> isAvailable() async => (await resolveScrcpyPath()) != null;

  /// Opens a live mirror window. Prefer [serial] when multiple devices exist.
  ///
  /// [stayAwake] defaults to false — `--stay-awake` writes secure settings and
  /// throws on many Xiaomi/MIUI devices without WRITE_SECURE_SETTINGS.
  Future<({bool success, String message})> startLiveScreen({
    String? serial,
    bool stayAwake = false,
    bool turnScreenOff = false,
    int maxSize = 1024,
  }) async {
    final scrcpy = await resolveScrcpyPath();
    if (scrcpy == null) {
      return (
        success: false,
        message:
            'scrcpy not found. Run tools\\setup_scrcpy.ps1 once (or place scrcpy.exe in tools\\scrcpy\\).',
      );
    }

    final args = <String>[
      if (serial != null && serial.isNotEmpty) ...['--serial', serial],
      if (stayAwake) '--stay-awake',
      if (turnScreenOff) '--turn-screen-off',
      // SDK injection works over Wi-Fi; Xiaomi also needs
      // "USB debugging (Security settings)" + reboot.
      '--mouse=sdk',
      '--keyboard=sdk',
      '--max-size',
      '$maxSize',
      '--window-title',
      'Wireless Phone Live',
    ];

    try {
      await Process.start(
        scrcpy,
        args,
        mode: ProcessStartMode.detached,
        workingDirectory: p.dirname(scrcpy),
      );
      return (
        success: true,
        message:
            'Live screen opened. If clicks/keys do nothing on Xiaomi: enable '
            'Developer options → USB debugging (Security settings), reboot, '
            'Reconnect, then try again.',
      );
    } on Exception catch (e) {
      return (success: false, message: 'Failed to start scrcpy: $e');
    }
  }
}
