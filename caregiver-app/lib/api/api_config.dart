import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL of the FastAPI backend.
///
/// * Android emulator → `10.0.2.2` is the loopback to the host machine.
/// * iOS simulator / desktop / web → `localhost` works.
/// * Physical phone on Wi-Fi → override with your PC's LAN IP, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000`
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }
}
