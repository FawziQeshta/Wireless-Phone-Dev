import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/connection_result.dart';
import '../models/device_info.dart';

class AdbService {
  AdbService({String? adbPath}) : _adbPathOverride = adbPath;

  final String? _adbPathOverride;
  String? _resolvedAdb;

  Future<String?> resolveAdbPath() async {
    if (_resolvedAdb != null) return _resolvedAdb;
    final override = _adbPathOverride;
    if (override != null && await File(override).exists()) {
      return _resolvedAdb = override;
    }

    final candidates = <String>[];

    final androidHome = Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (androidHome != null && androidHome.isNotEmpty) {
      candidates.add(p.join(androidHome, 'platform-tools', 'adb.exe'));
      candidates.add(p.join(androidHome, 'platform-tools', 'adb'));
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      candidates.add(
        p.join(localAppData, 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
      );
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      candidates.add(
        p.join(userProfile, 'AppData', 'Local', 'Android', 'Sdk',
            'platform-tools', 'adb.exe'),
      );
    }

    // Bundled / tools folder next to the app or project
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(p.join(exeDir, 'tools', 'platform-tools', 'adb.exe'));
    candidates.add(p.join(Directory.current.path, 'tools', 'platform-tools',
        'adb.exe'));

    for (final path in candidates) {
      if (await File(path).exists()) {
        return _resolvedAdb = path;
      }
    }

    // Fall back to PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['adb'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final line = (result.stdout as String)
            .split(RegExp(r'\r?\n'))
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
        if (line.isNotEmpty && await File(line.trim()).exists()) {
          return _resolvedAdb = line.trim();
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> isAvailable() async => (await resolveAdbPath()) != null;

  Future<_CmdResult> _run(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final adb = await resolveAdbPath();
    if (adb == null) {
      return const _CmdResult(
        exitCode: -1,
        stdout: '',
        stderr: 'ADB not found. Install Android SDK platform-tools.',
      );
    }

    try {
      final result = await Process.run(
        adb,
        args,
        runInShell: false,
      ).timeout(timeout);
      return _CmdResult(
        exitCode: result.exitCode,
        stdout: (result.stdout as String? ?? '').trim(),
        stderr: (result.stderr as String? ?? '').trim(),
      );
    } on Exception catch (e) {
      return _CmdResult(exitCode: -1, stdout: '', stderr: e.toString());
    }
  }

  Future<List<DeviceInfo>> listDevices() async {
    final result = await _run(['devices', '-l']);
    if (result.exitCode != 0) return [];

    final devices = <DeviceInfo>[];
    for (final line in result.stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('List of devices')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final id = parts[0];
      final state = parts[1];
      String? model;
      String? product;
      for (final part in parts.skip(2)) {
        if (part.startsWith('model:')) {
          model = part.substring(6).replaceAll('_', ' ');
        } else if (part.startsWith('product:')) {
          product = part.substring(8);
        }
      }
      devices.add(DeviceInfo(
        id: id,
        state: state,
        model: model,
        product: product,
      ));
    }
    return devices;
  }

  Future<String?> getDeviceIp(String serial) async {
    // Prefer wlan0 — most common Wi‑Fi interface
    final interfaces = ['wlan0', 'wlan1', 'eth0', 'rmnet_data0'];
    for (final iface in interfaces) {
      final result = await _run(
        ['-s', serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show', iface],
      );
      final match =
          RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(result.stdout);
      if (match != null) return match.group(1);
    }

    // Fallback: parse ip route / ifconfig-style output
    final route = await _run([
      '-s',
      serial,
      'shell',
      'ip',
      'route',
      'get',
      '8.8.8.8',
    ]);
    final src = RegExp(r'src\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(route.stdout);
    if (src != null) return src.group(1);

    final getprop = await _run([
      '-s',
      serial,
      'shell',
      'getprop',
      'dhcp.wlan0.ipaddress',
    ]);
    final propIp = getprop.stdout.trim();
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(propIp)) return propIp;

    return null;
  }

  /// First-time setup: USB → tcpip 5555 → wireless connect.
  Future<ConnectionResult> enableWireless({int port = 5555}) async {
    final logs = <String>[];

    void log(String msg) => logs.add(msg);

    final adb = await resolveAdbPath();
    if (adb == null) {
      return ConnectionResult(
        success: false,
        message: 'ADB not found. Install Android Studio / SDK platform-tools.',
        logs: logs..add('ADB missing'),
      );
    }
    log('Using ADB: $adb');

    await _run(['start-server']);
    log('ADB server started');

    final devices = await listDevices();
    final usb = devices.where((d) => d.isReady && !d.isWireless).toList();
    final alreadyWireless =
        devices.where((d) => d.isReady && d.isWireless).toList();

    if (usb.isEmpty) {
      if (alreadyWireless.isNotEmpty) {
        final d = alreadyWireless.first;
        final ip = d.id.split(':').first;
        final p = int.tryParse(d.id.split(':').last) ?? port;
        return ConnectionResult(
          success: true,
          message: 'Already connected wirelessly at ${d.id}',
          ip: ip,
          port: p,
          logs: logs..add('Found wireless device ${d.id}'),
        );
      }
      return ConnectionResult(
        success: false,
        message:
            'No USB phone found. Plug in the cable, enable USB debugging, and tap Allow.',
        logs: logs..add('No USB device. Devices: ${devices.map((d) => d.id).join(', ')}'),
      );
    }

    final device = usb.first;
    log('USB device: ${device.displayName} (${device.id})');

    final ip = await getDeviceIp(device.id);
    if (ip == null) {
      return ConnectionResult(
        success: false,
        message:
            'Could not read phone Wi‑Fi IP. Connect the phone to the same Wi‑Fi as this PC.',
        logs: logs..add('IP lookup failed'),
      );
    }
    log('Phone IP: $ip');

    final tcpip = await _run(['-s', device.id, 'tcpip', '$port']);
    log('tcpip $port → ${tcpip.stdout} ${tcpip.stderr}'.trim());
    if (tcpip.exitCode != 0) {
      return ConnectionResult(
        success: false,
        message: 'Failed to open port $port on the phone.',
        logs: logs,
      );
    }

    // Brief pause so the daemon can restart in TCP mode
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final endpoint = '$ip:$port';
    final connect = await _run(['connect', endpoint]);
    log('connect $endpoint → ${connect.stdout} ${connect.stderr}'.trim());

    final ok = connect.stdout.toLowerCase().contains('connected') ||
        connect.stdout.toLowerCase().contains('already');

    if (!ok) {
      return ConnectionResult(
        success: false,
        message: 'ADB connect failed for $endpoint. Check Wi‑Fi / firewall.',
        ip: ip,
        port: port,
        logs: logs,
      );
    }

    return ConnectionResult(
      success: true,
      message:
          'Wireless ready at $endpoint — you can unplug the cable and debug freely.',
      ip: ip,
      port: port,
      logs: logs,
    );
  }

  /// Reconnect using a saved IP (no cable).
  Future<ConnectionResult> reconnect(String ip, {int port = 5555}) async {
    final logs = <String>[];
    void log(String msg) => logs.add(msg);

    if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(ip)) {
      return ConnectionResult(
        success: false,
        message: 'Invalid IP address: $ip',
        logs: logs,
      );
    }

    final adb = await resolveAdbPath();
    if (adb == null) {
      return ConnectionResult(
        success: false,
        message: 'ADB not found.',
        logs: logs,
      );
    }

    await _run(['start-server']);
    final endpoint = '$ip:$port';
    log('Connecting to $endpoint …');

    // Drop stale connection first for a clean reconnect
    await _run(['disconnect', endpoint]);
    final connect = await _run(['connect', endpoint]);
    log('${connect.stdout} ${connect.stderr}'.trim());

    final ok = connect.stdout.toLowerCase().contains('connected') ||
        connect.stdout.toLowerCase().contains('already');

    if (!ok) {
      return ConnectionResult(
        success: false,
        message:
            'Could not reach $endpoint. Is the phone on the same Wi‑Fi? '
            'If wireless debugging was reset, use Connect once with USB.',
        ip: ip,
        port: port,
        logs: logs,
      );
    }

    return ConnectionResult(
      success: true,
      message: 'Reconnected to $endpoint in a flash.',
      ip: ip,
      port: port,
      logs: logs,
    );
  }

  Future<ConnectionResult> disconnectAllWireless() async {
    final devices = await listDevices();
    final logs = <String>[];
    for (final d in devices.where((d) => d.isWireless)) {
      final r = await _run(['disconnect', d.id]);
      logs.add('disconnect ${d.id}: ${r.stdout} ${r.stderr}'.trim());
    }
    return ConnectionResult(
      success: true,
      message: 'Disconnected wireless devices.',
      logs: logs,
    );
  }
}

class _CmdResult {
  const _CmdResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
