import 'package:flutter/foundation.dart';

/// Server address. Override with: flutter run --dart-define=API_URL=http://192.168.1.10:8000
class AppConfig {
  static const String _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    // Android emulator reaches the host machine via 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
