class ConnectionResult {
  const ConnectionResult({
    required this.success,
    required this.message,
    this.ip,
    this.port = 5555,
    this.logs = const [],
  });

  final bool success;
  final String message;
  final String? ip;
  final int port;
  final List<String> logs;

  String get endpoint => ip == null ? '' : '$ip:$port';
}
