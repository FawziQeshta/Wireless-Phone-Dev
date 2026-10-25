import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device_info.dart';
import '../services/adb_service.dart';
import '../services/device_prefs.dart';
import '../services/scrcpy_service.dart';
import '../theme/app_theme.dart';
import '../widgets/log_panel.dart';
import '../widgets/status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _adb = AdbService();
  final _scrcpy = ScrcpyService();
  final _prefs = DevicePrefs();
  final _ipController = TextEditingController();

  List<DeviceInfo> _devices = [];
  SavedDevice? _saved;
  bool _busy = false;
  bool _adbOk = false;
  bool _scrcpyOk = false;
  String? _statusMessage;
  bool _statusOk = true;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_refreshTools(), _loadSaved(), _refreshDevices()]);
  }

  Future<void> _refreshTools() async {
    final adb = await _adb.isAvailable();
    final scrcpy = await _scrcpy.isAvailable();
    if (!mounted) return;
    setState(() {
      _adbOk = adb;
      _scrcpyOk = scrcpy;
    });
  }

  Future<void> _loadSaved() async {
    final saved = await _prefs.load();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      if (saved != null) {
        _ipController.text = saved.ip;
      }
    });
  }

  Future<void> _refreshDevices() async {
    final devices = await _adb.listDevices();
    if (!mounted) return;
    setState(() => _devices = devices);
  }

  void _appendLogs(List<String> lines) {
    setState(() {
      _logs.addAll(lines.map((l) => '[${_ts()}] $l'));
      if (_logs.length > 200) {
        _logs.removeRange(0, _logs.length - 200);
      }
    });
  }

  String _ts() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refreshDevices();
    }
  }

  Future<void> _connectFirstTime() async {
    await _runAction(() async {
      _appendLogs(['Starting first-time wireless setup…']);
      final result = await _adb.enableWireless();
      _appendLogs(result.logs);
      _appendLogs([result.message]);
      setState(() {
        _statusMessage = result.message;
        _statusOk = result.success;
      });
      if (result.success && result.ip != null) {
        String? model;
        for (final d in _devices.where((d) => d.isReady)) {
          if (d.model != null) {
            model = d.model;
            break;
          }
        }
        await _prefs.save(ip: result.ip!, port: result.port, model: model);
        await _loadSaved();
        _ipController.text = result.ip!;
      }
    });
  }

  Future<void> _reconnect() async {
    final ip = _ipController.text.trim().isNotEmpty
        ? _ipController.text.trim()
        : _saved?.ip;
    if (ip == null || ip.isEmpty) {
      setState(() {
        _statusMessage =
            'No saved IP. Use “Connect (USB → Wireless)” once first.';
        _statusOk = false;
      });
      return;
    }

    await _runAction(() async {
      _appendLogs(['Reconnecting to $ip:5555 …']);
      final result = await _adb.reconnect(ip, port: _saved?.port ?? 5555);
      _appendLogs(result.logs);
      _appendLogs([result.message]);
      setState(() {
        _statusMessage = result.message;
        _statusOk = result.success;
      });
      if (result.success && result.ip != null) {
        await _prefs.save(
          ip: result.ip!,
          port: result.port,
          model: _saved?.model,
        );
        await _loadSaved();
      }
    });
  }

  Future<void> _openLiveScreen() async {
    await _runAction(() async {
      await _refreshDevices();
      final wireless =
          _devices.where((d) => d.isReady && d.isWireless).toList();
      final any = _devices.where((d) => d.isReady).toList();
      final target =
          wireless.isNotEmpty ? wireless.first : (any.isNotEmpty ? any.first : null);

      if (target == null) {
        setState(() {
          _statusMessage =
              'No device connected. Reconnect wirelessly or plug in USB first.';
          _statusOk = false;
        });
        _appendLogs([_statusMessage!]);
        return;
      }

      final result = await _scrcpy.startLiveScreen(serial: target.id);
      _appendLogs([result.message]);
      setState(() {
        _statusMessage = result.message;
        _statusOk = result.success;
      });
    });
  }

  Future<void> _disconnect() async {
    await _runAction(() async {
      final result = await _adb.disconnectAllWireless();
      _appendLogs(result.logs);
      setState(() {
        _statusMessage = result.message;
        _statusOk = true;
      });
    });
  }

  DeviceInfo? get _primaryDevice {
    final wireless = _devices.where((d) => d.isReady && d.isWireless);
    if (wireless.isNotEmpty) return wireless.first;
    final usb = _devices.where((d) => d.isReady && !d.isWireless);
    if (usb.isNotEmpty) return usb.first;
    return _devices.isNotEmpty ? _devices.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final device = _primaryDevice;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1215),
              Color(0xFF0E1A1C),
              Color(0xFF0B1418),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildDeviceCard(device),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 20),
                  _buildIpRow(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildStatusBanner(),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Log',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LogPanel(lines: _logs),
                  const SizedBox(height: 24),
                  _buildFooterHints(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wireless Phone Dev',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ADB wireless · Flutter / Android Studio / VS Code · live screen',
                style: TextStyle(
                  color: AppTheme.muted.withValues(alpha: 0.95),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh devices',
          onPressed: _busy
              ? null
              : () async {
                  await _refreshTools();
                  await _refreshDevices();
                  _appendLogs(['Refreshed device list']);
                },
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(DeviceInfo? device) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Device',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (!_adbOk)
                StatusChip.offline('ADB missing')
              else if (device == null)
                StatusChip.offline('No device')
              else if (device.isWireless)
                StatusChip.online('Wireless')
              else if (device.isReady)
                StatusChip.usb('USB')
              else
                StatusChip.offline(device.state),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            device?.displayName ?? 'Waiting for a phone…',
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            device?.id ??
                (_saved != null
                    ? 'Last known: ${_saved!.endpoint}'
                    : 'Plug in USB for first setup, or Reconnect if already paired'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontFamily: 'Consolas',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toolBadge('ADB', _adbOk),
              _toolBadge('scrcpy (live)', _scrcpyOk),
              if (_saved != null)
                StatusChip(
                  label: 'Saved ${_saved!.ip}',
                  color: AppTheme.accent,
                  icon: Icons.bookmark_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolBadge(String label, bool ok) {
    return StatusChip(
      label: label,
      color: ok ? AppTheme.accent : AppTheme.warn,
      icon: ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _connectFirstTime,
                icon: const Icon(Icons.cable_rounded),
                label: const Text('Connect (USB → Wireless)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceAlt,
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accentDim),
                ),
                onPressed: _busy ? null : _reconnect,
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('Reconnect'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openLiveScreen,
                icon: const Icon(Icons.desktop_windows_rounded),
                label: const Text('Live Screen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _disconnect,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Disconnect'),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceAlt,
            minHeight: 3,
          ),
        ],
      ],
    );
  }

  Widget _buildIpRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ipController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone IP',
              hintText: '192.168.x.x',
              prefixIcon: Icon(Icons.lan_rounded, color: AppTheme.muted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final ip = _ipController.text.trim();
                  if (ip.isEmpty) return;
                  await _prefs.save(ip: ip, model: _saved?.model);
                  await _loadSaved();
                  _appendLogs(['Saved IP $ip']);
                  setState(() {
                    _statusMessage = 'Saved $ip for next Reconnect.';
                    _statusOk = true;
                  });
                },
          child: const Text('Save IP'),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final color = _statusOk ? AppTheme.accent : AppTheme.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, height: 1.35),
      ),
    );
  }

  Widget _buildFooterHints() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick flow',
            style: TextStyle(
              color: AppTheme.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '1. USB + same Wi‑Fi → Connect (USB → Wireless) → unplug cable\n'
            '2. Next day → Reconnect (no cable) → flutter run / Hot Reload\n'
            '3. Live Screen → mouse & keyboard control (scrcpy)\n'
            '4. Double-click tools\\Connect.bat or tools\\Reconnect.bat anytime',
            style: TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
