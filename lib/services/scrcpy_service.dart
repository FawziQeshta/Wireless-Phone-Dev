import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Launches [scrcpy](https://github.com/Genymobile/scrcpy) for wireless
/// live screen + mouse/keyboard control — no Vysor, no heavy installs.
class ScrcpyService {
  String? _resolved;

  /// Folder next to the .exe — used by Release builds.
  String get bundledScrcpyDir =>
      p.join(File(Platform.resolvedExecutable).parent.path, 'tools', 'scrcpy');

  Future<String?> resolveScrcpyPath() async {
    if (_resolved != null) return _resolved;

    final candidates = <String>[];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;

    for (final root in [exeDir, cwd, p.dirname(exeDir), p.dirname(cwd)]) {
      candidates.add(p.join(root, 'tools', 'scrcpy', 'scrcpy.exe'));
      candidates.add(p.join(root, 'tools', 'scrcpy.exe'));
      candidates.add(p.join(root, 'scrcpy', 'scrcpy.exe'));
      candidates.add(p.join(root, 'scrcpy.exe'));
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      candidates.add(p.join(localAppData, 'scrcpy', 'scrcpy.exe'));
    }

    final programFiles = Platform.environment['ProgramFiles'];
    if (programFiles != null) {
      candidates.add(p.join(programFiles, 'scrcpy', 'scrcpy.exe'));
    }

    for (final path in candidates.toSet()) {
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

  /// Resolves scrcpy, or downloads the official Windows build next to the exe.
  Future<({bool success, String message, String? path})> ensureScrcpy({
    void Function(String status)? onStatus,
  }) async {
    final existing = await resolveScrcpyPath();
    if (existing != null) {
      return (success: true, message: 'scrcpy ready', path: existing);
    }

    if (!Platform.isWindows) {
      return (
        success: false,
        message: 'Auto-install of scrcpy is only supported on Windows.',
        path: null,
      );
    }

    try {
      onStatus?.call('Downloading scrcpy…');
      final destDir = bundledScrcpyDir;
      await Directory(destDir).create(recursive: true);

      final client = HttpClient();
      client.userAgent = 'WirelessPhoneDev';

      final apiReq = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/Genymobile/scrcpy/releases/latest',
        ),
      );
      apiReq.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final apiRes = await apiReq.close();
      final apiBody = await apiRes.transform(utf8.decoder).join();
      if (apiRes.statusCode != 200) {
        client.close(force: true);
        return (
          success: false,
          message:
              'Could not fetch scrcpy release list (HTTP ${apiRes.statusCode}). '
              'Run tools\\setup_scrcpy.ps1 or check your network.',
          path: null,
        );
      }

      final json = jsonDecode(apiBody) as Map<String, dynamic>;
      final assets = (json['assets'] as List<dynamic>?) ?? const [];
      String? zipUrl;
      String? zipName;
      for (final asset in assets) {
        final map = asset as Map<String, dynamic>;
        final name = '${map['name'] ?? ''}';
        if (RegExp(r'win64.*\.zip$', caseSensitive: false).hasMatch(name)) {
          zipUrl = map['browser_download_url'] as String?;
          zipName = name;
          break;
        }
      }
      if (zipUrl == null) {
        client.close(force: true);
        return (
          success: false,
          message: 'No win64 scrcpy zip found in latest release.',
          path: null,
        );
      }

      onStatus?.call('Downloading $zipName…');
      final zipPath = p.join(
        Directory.systemTemp.path,
        zipName ?? 'scrcpy-win64.zip',
      );
      final zipReq = await client.getUrl(Uri.parse(zipUrl));
      final zipRes = await zipReq.close();
      if (zipRes.statusCode != 200) {
        client.close(force: true);
        return (
          success: false,
          message: 'scrcpy download failed (HTTP ${zipRes.statusCode}).',
          path: null,
        );
      }
      final sink = File(zipPath).openWrite();
      await zipRes.pipe(sink);
      await sink.close();
      client.close();

      onStatus?.call('Extracting scrcpy…');
      // Wipe previous partial install
      if (await Directory(destDir).exists()) {
        await Directory(destDir).delete(recursive: true);
      }
      await Directory(destDir).create(recursive: true);

      final zipEsc = zipPath.replaceAll("'", "''");
      final destEsc = destDir.replaceAll("'", "''");
      final expand = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          "Expand-Archive -LiteralPath '$zipEsc' -DestinationPath '$destEsc' -Force",
        ],
      );
      if (expand.exitCode != 0) {
        return (
          success: false,
          message: 'Failed to extract scrcpy: ${expand.stderr}'.trim(),
          path: null,
        );
      }

      // Flatten nested folder (scrcpy-win64-vX.Y.Z\…)
      final nested = Directory(destDir)
          .listSync()
          .whereType<Directory>()
          .where((d) => File(p.join(d.path, 'scrcpy.exe')).existsSync())
          .toList();
      if (nested.isNotEmpty) {
        for (final entity in nested.first.listSync()) {
          final name = p.basename(entity.path);
          final target = p.join(destDir, name);
          if (entity is File) {
            await entity.copy(target);
          } else if (entity is Directory) {
            await _copyDir(entity.path, target);
          }
        }
        await nested.first.delete(recursive: true);
      }

      try {
        await File(zipPath).delete();
      } catch (_) {}

      _resolved = null;
      final path = await resolveScrcpyPath();
      if (path == null) {
        return (
          success: false,
          message:
              'scrcpy extracted but scrcpy.exe not found under $destDir',
          path: null,
        );
      }
      onStatus?.call('scrcpy installed');
      return (success: true, message: 'scrcpy downloaded and ready.', path: path);
    } on Exception catch (e) {
      return (
        success: false,
        message:
            'Auto-install failed: $e — run tools\\setup_scrcpy.ps1 manually.',
        path: null,
      );
    }
  }

  Future<void> _copyDir(String from, String to) async {
    await Directory(to).create(recursive: true);
    await for (final entity in Directory(from).list(recursive: false)) {
      final name = p.basename(entity.path);
      final dest = p.join(to, name);
      if (entity is File) {
        await entity.copy(dest);
      } else if (entity is Directory) {
        await _copyDir(entity.path, dest);
      }
    }
  }

  /// Opens a live mirror window. Prefer [serial] when multiple devices exist.
  ///
  /// [stayAwake] defaults to false — `--stay-awake` writes secure settings and
  /// throws on many Xiaomi/MIUI devices without WRITE_SECURE_SETTINGS.
  Future<({bool success, String message})> startLiveScreen({
    String? serial,
    bool stayAwake = false,
    bool turnScreenOff = false,
    int maxSize = 1024,
    void Function(String status)? onStatus,
  }) async {
    final ensured = await ensureScrcpy(onStatus: onStatus);
    final scrcpy = ensured.path;
    if (!ensured.success || scrcpy == null) {
      return (
        success: false,
        message: ensured.message,
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
