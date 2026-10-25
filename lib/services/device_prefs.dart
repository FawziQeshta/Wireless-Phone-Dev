import 'package:shared_preferences/shared_preferences.dart';

class SavedDevice {
  const SavedDevice({
    required this.ip,
    this.port = 5555,
    this.model,
    this.lastConnected,
  });

  final String ip;
  final int port;
  final String? model;
  final DateTime? lastConnected;

  String get endpoint => '$ip:$port';
}

class DevicePrefs {
  static const _ipKey = 'saved_ip';
  static const _portKey = 'saved_port';
  static const _modelKey = 'saved_model';
  static const _lastKey = 'last_connected';

  Future<SavedDevice?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_ipKey);
    if (ip == null || ip.isEmpty) return null;
    final millis = prefs.getInt(_lastKey);
    return SavedDevice(
      ip: ip,
      port: prefs.getInt(_portKey) ?? 5555,
      model: prefs.getString(_modelKey),
      lastConnected:
          millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  Future<void> save({
    required String ip,
    int port = 5555,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
    await prefs.setInt(_portKey, port);
    if (model != null) await prefs.setString(_modelKey, model);
    await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipKey);
    await prefs.remove(_portKey);
    await prefs.remove(_modelKey);
    await prefs.remove(_lastKey);
  }
}
