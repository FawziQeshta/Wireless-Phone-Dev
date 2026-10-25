enum DeviceTransport { usb, wireless, offline, unauthorized, unknown }

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.state,
    this.model,
    this.product,
  });

  final String id;
  final String state;
  final String? model;
  final String? product;

  bool get isReady => state == 'device';

  bool get isWireless {
    final host = id.split(':').first;
    return id.contains(':') &&
        RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  }

  DeviceTransport get transport {
    if (state == 'offline') return DeviceTransport.offline;
    if (state == 'unauthorized') return DeviceTransport.unauthorized;
    if (isWireless) return DeviceTransport.wireless;
    if (isReady) return DeviceTransport.usb;
    return DeviceTransport.unknown;
  }

  String get displayName {
    final label = model ?? product ?? id;
    return label;
  }

  String get shortId {
    if (isWireless) return id;
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }
}
